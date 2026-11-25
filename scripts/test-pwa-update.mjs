/** Build two small Vite releases with the template's production PWA options. */
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { waitForBrowserValue } from "./lib/pwa-browser.mjs";
import { startDistServer } from "./lib/serve-dist.mjs";

const require = createRequire(resolve("package.json"));
const { chromium } = require("@playwright/test");
const { build } = await import(pathToFileURL(require.resolve("vite")).href);
const { VitePWA } = await import(pathToFileURL(require.resolve("vite-plugin-pwa")).href);
const { pwaOptions, simMetadataHtml } = await import(pathToFileURL(resolve("scripts/pwa-config.ts")).href);
const root = await mkdtemp(join(tmpdir(), "pwa-update-"));
const mount = "/Example/";
const config = {
  title: "Example",
  shortName: "Example",
  themeColor: "#1a1a2e",
  backgroundColor: "#000000",
  precacheExtensions: [],
};
const description = "PWA update fixture";

async function release(version, name, overrides = {}) {
  const outDir = join(root, version);
  await writeFile(join(root, "package.json"), JSON.stringify({ name, description, version: "1.0.0" }));
  await writeFile(join(root, "index.html"), `
    <!doctype html><html><head><meta name="theme-color" content="%SIM_THEME_COLOR%"></head>
    <body data-build="${version}"><script type="module" src="./main.js"></script></body></html>
  `);
  await writeFile(join(root, "main.js"), 'globalThis.loadFeature = () => import("./feature.js");');
  await writeFile(join(root, "feature.js"), `export const version = "${version}";`);
  await build({
    root,
    base: "./",
    configFile: false,
    logLevel: "warn",
    build: { outDir },
    plugins: [simMetadataHtml(description, config.themeColor), VitePWA(pwaOptions({ ...config, ...overrides }, { name, description }))],
  });
  return outDir;
}

let server;
let browser;
try {
  // Workbox requires an existing public directory to add the manifest to the precache.
  await mkdir(join(root, "public"));
  const previous = await release("v1", "example");
  const next = await release("v2", "renamed-example", { pwaId: "/example" });
  const [previousManifest, nextManifest] = await Promise.all([previous, next].map(async (folder) =>
    JSON.parse(await readFile(join(folder, "manifest.webmanifest"), "utf8"))));
  const originForId = "https://openlyceum.github.io";
  assert.equal(new URL(previousManifest.id, originForId).href, new URL(nextManifest.id, originForId).href,
    "Pinning the previous ID must preserve installed identity after a package rename");

  let current = previous;
  const serving = await startDistServer(() => current, { mount });
  server = serving.server;
  const url = serving.origin + mount;
  browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE });
  const context = await browser.newContext();
  const oldTab = await context.newPage();
  await oldTab.goto(url);
  await waitForBrowserValue(oldTab, async () => (await navigator.serviceWorker.getRegistration())?.active?.state === "activated", undefined, "v1 worker activation");
  await oldTab.reload();
  await oldTab.waitForFunction(() => !!navigator.serviceWorker.controller);
  assert.equal(await oldTab.locator("body").getAttribute("data-build"), "v1");
  await oldTab.evaluate(() => { document.body.dataset.experiment = "in progress"; });

  current = next;
  await oldTab.evaluate(async () => (await navigator.serviceWorker.getRegistration()).update());
  await waitForBrowserValue(oldTab, async () => !!(await navigator.serviceWorker.getRegistration())?.waiting, undefined, "v2 worker to enter the waiting phase");
  assert.equal(await oldTab.locator("body").getAttribute("data-experiment"), "in progress");
  assert.equal(await oldTab.evaluate(async () => (await globalThis.loadFeature()).version), "v1",
    "The active v1 tab must be able to load a v1 chunk after the server switches to v2");

  // Keep polling worker state outside its scope so the probe cannot delay activation.
  const outside = await context.newPage();
  await outside.goto(serving.origin);
  await oldTab.close();
  await waitForBrowserValue(outside, async (scope) => {
    const registration = await navigator.serviceWorker.getRegistration(scope);
    return registration?.active?.state === "activated" && !registration.waiting;
  }, url, "v2 worker activation");

  await context.setOffline(true);
  const updatedTab = await context.newPage();
  await updatedTab.goto(url);
  assert.equal(await updatedTab.locator("body").getAttribute("data-build"), "v2");
  assert.equal(await updatedTab.evaluate(async () => (await globalThis.loadFeature()).version), "v2");
  console.log("PWA update passed: v1 session and lazy chunk survived the deploy, and v2 launched offline after closing v1.");
} finally {
  await browser?.close();
  server?.close();
  await rm(root, { recursive: true, force: true });
}
