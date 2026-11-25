#!/usr/bin/env node
/**
 * screenshot.mjs — capture a SceneryStack simulation's screen as a PNG.
 *
 * It serves a built `dist/` directory over a local ephemeral port, opens it in
 * headless Chromium (via Playwright), waits for the sim to finish constructing,
 * then asks the sim to render ITSELF using its own `ScreenshotGenerator` — the
 * exact code path behind the in-app camera button (Help menu → "Save a
 * screenshot"). The result is a clean PNG at the sim's nominal layout, not a
 * raw viewport grab.
 *
 * Multi-screen sims are forced onto a single screen with `?screens=N`, so the
 * capture is the requested screen's play area (no home-screen selector).
 *
 * Usage:
 *   node screenshot.mjs --dist <dir> --out <file.png> [options]
 *
 * Options:
 *   --dist <dir>      Built sim directory to serve (must contain index.html).
 *   --out <file>      Output PNG path.
 *   --screen <n>      1-based screen index to show (default: 1).
 *   --width <px>      Viewport width  (default: 1154, matches existing assets).
 *   --height <px>     Viewport height (default: 753).
 *   --timeout <ms>    Max wait for the sim to be ready (default: 60000).
 *   --settle <ms>     Extra wait after ready, lets layout settle (default: 1500).
 *
 * Env:
 *   PLAYWRIGHT_CHROMIUM_EXECUTABLE   Override the Chromium binary to launch.
 *
 * Exit codes: 0 ok, 1 capture/launch failure, 2 bad arguments.
 */

import { chromium } from "playwright";
import { existsSync, readdirSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { homedir } from "node:os";
import { startDistServer } from "./lib/serve-dist.mjs";

// ── argument parsing ─────────────────────────────────────────────────────────
function parseArgs(argv) {
  const out = {
    screen: 1,
    width: 1154,
    height: 753,
    timeout: 60000,
    settle: 1500,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    switch (a) {
      case "--dist": out.dist = next(); break;
      case "--out": out.out = next(); break;
      case "--screen": out.screen = Number(next()); break;
      case "--width": out.width = Number(next()); break;
      case "--height": out.height = Number(next()); break;
      case "--timeout": out.timeout = Number(next()); break;
      case "--settle": out.settle = Number(next()); break;
      case "-h": case "--help": out.help = true; break;
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }
  return out;
}

// ── locate a usable Chromium binary ──────────────────────────────────────────
// Playwright pins a browser build per release; a system may only have a nearby
// cached build. Launching by executablePath bypasses the strict version check.
function findChromium() {
  const override = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE;
  if (override && existsSync(override)) return override;

  const bundled = (() => {
    try { return chromium.executablePath(); } catch { return null; }
  })();
  if (bundled && existsSync(bundled)) return null; // let Playwright use its own

  // Fall back to the newest cached Playwright Chromium build.
  const cacheRoot = join(homedir(), ".cache", "ms-playwright");
  if (existsSync(cacheRoot)) {
    const builds = readdirSync(cacheRoot)
      .filter((d) => d.startsWith("chromium-"))
      .map((d) => ({ d, n: Number(d.split("-")[1]) || 0 }))
      .sort((a, b) => b.n - a.n);
    for (const { d } of builds) {
      for (const sub of ["chrome-linux64/chrome", "chrome-linux/chrome"]) {
        const p = join(cacheRoot, d, sub);
        if (existsSync(p)) return p;
      }
    }
  }

  // Last resort: a system Chromium/Chrome.
  for (const p of ["/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome"]) {
    if (existsSync(p)) return p;
  }
  return null;
}

// ── main ─────────────────────────────────────────────────────────────────────
async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    console.log("Usage: node screenshot.mjs --dist <dir> --out <file.png> [--screen N] [--width W --height H]");
    return 0;
  }
  if (!opts.dist || !opts.out) {
    console.error("error: --dist and --out are required");
    return 2;
  }
  if (!existsSync(join(opts.dist, "index.html"))) {
    console.error(`error: ${opts.dist}/index.html not found (build the sim first)`);
    return 2;
  }

  const { server, port } = await startDistServer(opts.dist, { crossOrigin: true });
  const executablePath = findChromium();
  const browser = await chromium.launch({
    ...(executablePath ? { executablePath } : {}),
    args: ["--no-sandbox", "--disable-gpu", "--use-gl=swiftshader"],
  });

  let exitCode = 0;
  try {
    const page = await browser.newPage({
      viewport: { width: opts.width, height: opts.height },
      deviceScaleFactor: 1,
    });
    const pageErrors = [];
    page.on("pageerror", (e) => pageErrors.push(String(e)));

    const url = `http://127.0.0.1:${port}/?screens=${opts.screen}`;
    await page.goto(url, { waitUntil: "load", timeout: opts.timeout });

    // Wait until the sim is fully constructed and the screenshot API exists.
    await page.waitForFunction(
      () => {
        const sim = globalThis.phet?.joist?.sim;
        return !!(
          sim &&
          sim.isConstructionCompleteProperty?.value &&
          globalThis.phet?.joist?.ScreenshotGenerator
        );
      },
      null,
      { timeout: opts.timeout },
    );

    // Let layout/animation settle for a clean frame.
    await page.waitForTimeout(opts.settle);

    const dataUrl = await page.evaluate(() =>
      globalThis.phet.joist.ScreenshotGenerator.generateScreenshot(
        globalThis.phet.joist.sim,
        "image/png",
      ),
    );
    if (!dataUrl?.startsWith("data:image/png")) {
      throw new Error("ScreenshotGenerator returned no PNG data");
    }

    await writeFile(opts.out, Buffer.from(dataUrl.split(",")[1], "base64"));
    console.log(
      `ok  ${opts.out}  (${opts.width}x${opts.height}, screen ${opts.screen}` +
        (pageErrors.length ? `, ${pageErrors.length} page error(s)` : "") +
        ")",
    );
    if (pageErrors.length) {
      console.log("    first error:", pageErrors[0].split("\n")[0]);
    }
  } catch (err) {
    console.error("FAIL", opts.out, "-", err.message);
    exitCode = 1;
  } finally {
    await browser.close();
    server.close();
  }
  return exitCode;
}

main().then((code) => process.exit(code));
