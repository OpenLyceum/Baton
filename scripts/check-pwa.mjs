import assert from "node:assert/strict";
import { appendFile, readFile, readdir, stat } from "node:fs/promises";
import { createRequire } from "node:module";
import { extname, resolve, sep } from "node:path";
import { parseArgs } from "node:util";
import { waitForBrowserValue } from "./lib/pwa-browser.mjs";
import { startDistServer } from "./lib/serve-dist.mjs";

const { values: args } = parseArgs({
  options: {
    dist: { type: "string", default: "dist" },
    repo: { type: "string" },
    "check-single": { type: "boolean" },
  },
});
assert.match(args.repo ?? "", /^[\w.-]+$/, "Provide --repo with the GitHub repository name");
assert.ok(args.repo !== "." && args.repo !== "..", "Invalid repository name");

const dist = resolve(args.dist);
const packageJson = JSON.parse(await readFile("package.json", "utf8"));
const viteConfig = await readFile("vite.config.ts", "utf8");
const usesSharedPwaOptions = viteConfig.includes("pwaOptions(");
const require = createRequire(resolve("package.json"));
const { chromium } = require("@playwright/test");
const mount = `/${args.repo}/`;
const { server, origin } = await startDistServer(dist, { mount });
const app = new URL(mount, origin);
let browser;

function localFile(url) {
  assert.equal(url.origin, app.origin, `${url.href} must be same-origin`);
  assert.ok(url.pathname.startsWith(mount), `${url.href} must stay under ${mount}`);
  const filename = decodeURIComponent(url.pathname.slice(mount.length)) || "index.html";
  const file = resolve(dist, filename);
  assert.ok(file.startsWith(dist + sep), `${url.href} escapes the build directory`);
  return file;
}

async function fileSize(url) {
  const file = localFile(url);
  const info = await stat(file);
  assert.ok(info.isFile(), `${url.pathname} must point to a built file`);
  return info.size;
}

async function initOpenCv(page) {
  // Send the same initialization message as TrackLab's tracker without needing a camera.
  await page.evaluate(() => new Promise((resolve, reject) => {
    const worker = new Worker("./opencv-worker.js");
    const timeout = setTimeout(() => finish(new Error("OpenCV initialization timed out")), 60_000);
    function finish(error) {
      clearTimeout(timeout);
      worker.terminate();
      if (error) reject(error);
      else resolve();
    }
    worker.onerror = (event) => finish(new Error(event.message));
    worker.onmessage = ({ data }) =>
      finish(data.type === "init-done" ? undefined : new Error(data.message ?? data.type));
    worker.postMessage({
      id: 1,
      type: "init",
      imageData: new ImageData(16, 16),
      region: { x: 2, y: 2, w: 8, h: 8 },
    });
  }));
}

try {
  browser = await chromium.launch({
    executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE,
    args: ["--enable-unsafe-webgpu", "--enable-features=Vulkan"],
  });
  const context = await browser.newContext({
    geolocation: { latitude: 40.8, longitude: -74 },
    permissions: ["geolocation"],
  });
  const page = await context.newPage();
  const appErrors = [];
  page.on("pageerror", (error) => {
    appErrors.push(error.message);
    console.error(`Sim page error: ${error.message}`);
  });
  const response = await page.goto(app.href);
  assert.equal(response.status(), 200, `${app.href} should serve index.html`);

  const metadata = await page.evaluate(() => ({
    manifestUrl: document.querySelector('link[rel="manifest"]')?.href,
    themeColor: document.querySelector('meta[name="theme-color"]')?.content,
  }));
  assert.ok(metadata.manifestUrl, "Built HTML is missing the manifest link");
  const manifestUrl = new URL(metadata.manifestUrl);
  const manifest = JSON.parse(await readFile(localFile(manifestUrl), "utf8"));
  assert.ok(manifest.start_url && manifest.scope && manifest.id, "Manifest must declare start_url, scope and id");
  const startUrl = new URL(manifest.start_url, manifestUrl);
  const id = new URL(manifest.id, startUrl.origin);
  assert.equal(id.origin, startUrl.origin, "Manifest ID must be same-origin");
  const scope = new URL(manifest.scope, manifestUrl);
  assert.equal(scope.href, app.href, "Manifest scope must match the sim's Pages directory");
  await fileSize(startUrl);
  assert.ok(!manifest.orientation, "The manifest must allow device rotation");

  assert.match(manifest.theme_color, /^#[0-9a-f]{6}$/i);
  assert.equal(metadata.themeColor, manifest.theme_color, "HTML theme color must match the manifest");
  assert.match(manifest.background_color, /^#[0-9a-f]{6}$/i);
  for (const list of ["icons", "screenshots"]) {
    assert.ok(Array.isArray(manifest[list]) && manifest[list].length > 0, `Manifest must list ${list}`);
    for (const { src, sizes, type } of manifest[list]) {
      assert.ok(src, `Missing src in manifest ${list}`);
      const url = new URL(src, manifestUrl);
      assert.ok(await fileSize(url) > 0, `Empty manifest asset: ${src}`);
      if (usesSharedPwaOptions && type === "image/png" && /^\d+x\d+$/.test(sizes)) {
        const file = await readFile(localFile(url));
        assert.equal(file.toString("ascii", 12, 16), "IHDR", `${src} must be a PNG`);
        assert.equal(`${file.readUInt32BE(16)}x${file.readUInt32BE(20)}`, sizes, `${src} must match its declared size`);
      }
    }
  }

  // A worker that respects the waiting phase may leave the first page uncontrolled.
  await waitForBrowserValue(page, async () => (await navigator.serviceWorker.getRegistration())?.active?.state === "activated", undefined, "worker activation");
  await page.goto(startUrl.href);
  const workerInfo = await waitForBrowserValue(page, async () => {
    const registration = await navigator.serviceWorker.getRegistration();
    const controller = navigator.serviceWorker.controller;
    return registration && controller && { scope: registration.scope, script: controller.scriptURL };
  }, undefined, "the worker to control the page");
  assert.equal(workerInfo.scope, app.href, "Worker scope must match the sim's Pages directory");
  await fileSize(new URL(workerInfo.script));
  await page.waitForFunction(() => globalThis.phet?.joist?.sim?.isConstructionCompleteProperty?.value === true);

  const cached = await page.evaluate(async () => {
    const names = (await caches.keys()).filter((name) => name.includes("precache"));
    const keys = (await Promise.all(names.map(async (name) => (await caches.open(name)).keys()))).flat();
    return keys.map((key) => key.url);
  });
  const cachedFiles = new Set(cached.map((url) => new URL(url).pathname));
  assert.ok(cachedFiles.has(`${mount}index.html`), "The app shell must be precached");
  assert.ok(cachedFiles.has(manifestUrl.pathname), "The manifest must be precached");
  const bytes = (await Promise.all([...cachedFiles].map((path) => fileSize(new URL(path, app)))))
    .reduce((total, size) => total + size, 0);
  const summary = `PWA precache for ${args.repo}: ${cachedFiles.size} files, ${bytes.toLocaleString("en-US")} bytes (${(bytes / 1024 / 1024).toFixed(2)} MiB uncompressed)`;
  console.log(summary);
  if (process.env.GITHUB_STEP_SUMMARY) await appendFile(process.env.GITHUB_STEP_SUMMARY, `${summary}\n`);

  // Sims may declare extra file types that need to remain available on the first offline launch.
  const simConfig = await readFile("sim.config.json", "utf8").then(JSON.parse, (error) => {
    if (error.code !== "ENOENT") throw error;
    return {};
  });
  const expectedId = simConfig.pwaId ?? packageJson.name;
  assert.equal(id.href, new URL(expectedId, startUrl.origin).href,
    "Manifest ID must use the package name or the pinned pwaId");

  const extensions = new Set(simConfig.precacheExtensions ?? []);
  const extras = (await readdir(dist, { recursive: true, withFileTypes: true }))
    .filter((entry) => entry.isFile() && extensions.has(extname(entry.name).slice(1)))
    .map((entry) => resolve(entry.parentPath, entry.name).slice(dist.length + 1));
  for (const asset of extras) {
    const url = new URL(asset.split(sep).map(encodeURIComponent).join("/"), app);
    assert.ok(cachedFiles.has(url.pathname), `${asset} must be available on the first offline launch`);
  }

  if (usesSharedPwaOptions) {
    for (const { src } of manifest.screenshots) {
      assert.ok(!cachedFiles.has(new URL(src, manifestUrl).pathname), "Install screenshots must stay out of the precache");
    }
  }

  // Older TrackLab builds used a different runtime cache. Gate the new contract after template adoption.
  const isTrackLab = args.repo === "TrackLab" && usesSharedPwaOptions;
  if (isTrackLab) {
    const opencvUrl = new URL("opencv.js", app).href;
    assert.ok(!cachedFiles.has(`${mount}opencv.js`), "OpenCV must be loaded on demand");
    await initOpenCv(page);
    await waitForBrowserValue(page, async (url) => !!(await caches.match(url)), opencvUrl, "OpenCV runtime cache");
  }

  await context.setOffline(true);
  const offline = await page.reload();
  assert.ok(offline?.fromServiceWorker(), "Offline navigation must come from the service worker");
  await page.waitForFunction(() => globalThis.phet?.joist?.sim?.isConstructionCompleteProperty?.value === true);
  const samples = new Map(extras.map((file) => [extname(file), file]));
  for (const [extension, sample] of samples) {
    const asset = sample.split(sep).map(encodeURIComponent).join("/");
    const isAudio = [".ogg", ".wav", ".mp3"].includes(extension);
    const received = await page.evaluate(async ({ path, decodeAudio }) => {
      const response = await fetch(path);
      if (!response.ok) throw new Error(`Offline asset request failed: ${response.status}`);
      const bytes = await response.arrayBuffer();
      const size = bytes.byteLength;
      if (decodeAudio) {
        const audio = await new OfflineAudioContext(1, 1, 44_100).decodeAudioData(bytes);
        if (audio.length === 0) throw new Error("Offline audio contains no samples");
      }
      return size;
    }, { path: asset, decodeAudio: isAudio });
    assert.equal(received, await fileSize(new URL(asset, app)), "Offline media must contain the complete file");
    console.log(`Offline ${extension} sample ${isAudio ? "decoded" : "loaded"} (${received} bytes)`);
  }
  if (isTrackLab) {
    await initOpenCv(page);
    console.log("TrackLab OpenCV initialized on demand, then initialized offline from the runtime cache");
  }
  assert.deepEqual(appErrors, [], "The sim must start without page errors while online and offline");
  console.log("Scoped worker and offline launch passed");

  if (args["check-single"] && packageJson.scripts?.["build:single"]) {
    const single = new URL(`${args.repo}-single.html`, app);
    await fileSize(single);
    assert.ok(!cachedFiles.has(single.pathname), "The single-file build must stay out of the precache");
    await context.setOffline(false);
    const downloadPage = await page.goto(single.href);
    assert.equal(downloadPage.status(), 200, "Single-file build must be reachable");
    assert.ok(!downloadPage.fromServiceWorker(), "Single-file build must bypass the app-shell fallback");
    assert.equal(await downloadPage.text(), await readFile(localFile(single), "utf8"));
    console.log("Single-file navigation passed");
  }
} finally {
  await browser?.close();
  server.close();
}
