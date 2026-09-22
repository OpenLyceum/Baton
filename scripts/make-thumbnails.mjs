#!/usr/bin/env node
// Regenerate the lightweight WebP card thumbnails served by the GitHub Pages
// landing page. The committed full-size PNGs in screenshots/ are the ground
// truth; each active simulation's screenshot is downscaled to docs/assets/<sim>.webp.
//
// Uses sharp (a declared dev dependency) so resizing is deterministic and needs
// no system binary — unlike the previous ImageMagick dependency. When run from a
// full workspace checkout, originals are first refreshed from the sibling sim repos.
//
// Usage: node scripts/make-thumbnails.mjs [--width N] [sim ...]

import { existsSync, mkdirSync, readFileSync, copyFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SCRIPT_DIR, "..");
const REPOS_JSON = join(REPO_ROOT, "structure", "repos.json");
const SCREENSHOTS_DIR = join(REPO_ROOT, "screenshots");
const ASSETS_DIR = join(REPO_ROOT, "docs", "assets");
// Sibling sim repos live beside this repo in the workspace checkout.
const WORKSPACE = process.env.FLEET_WORKSPACE || process.env.OPENPHYSICS_WORKSPACE || resolve(REPO_ROOT, "..");

// Width of the generated card thumbnails (crisp on ~360px cards at 2x).
const DEFAULT_THUMB_WIDTH = 760;
const THUMB_QUALITY = 80;

function parseArgs(argv) {
  let width = DEFAULT_THUMB_WIDTH;
  const only = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--width") {
      width = Number.parseInt(argv[++i], 10);
    } else {
      only.push(argv[i]);
    }
  }
  return { width, only };
}

const { width, only } = parseArgs(process.argv.slice(2));

mkdirSync(ASSETS_DIR, { recursive: true });
mkdirSync(SCREENSHOTS_DIR, { recursive: true });

const catalog = JSON.parse(readFileSync(REPOS_JSON, "utf8"));
const sims = catalog.repos
  .filter((r) => r.isSimulation === true && r.status === "active")
  .map((r) => r.name)
  .filter((name) => only.length === 0 || only.includes(name));

let made = 0;
const skipped = [];
for (const sim of sims) {
  const original = join(SCREENSHOTS_DIR, `${sim}.png`);
  const sibling = join(WORKSPACE, sim, "assets", "screenshot.png");
  if (existsSync(sibling)) {
    copyFileSync(sibling, original);
  }
  if (!existsSync(original)) {
    skipped.push(sim);
    continue;
  }
  await sharp(original)
    .resize({ width })
    .webp({ quality: THUMB_QUALITY })
    .toFile(join(ASSETS_DIR, `${sim}.webp`));
  made++;
  console.log(`thumbnail: ${sim}.webp`);
}

console.log(`Generated ${made} WebP thumbnail(s) at ${width}px wide.`);
if (skipped.length > 0) {
  console.warn(
    `No screenshot for ${skipped.length} active sim(s) — the Pages card renders a placeholder monogram for these:`,
  );
  for (const sim of skipped) console.warn(`  - ${sim}`);
  console.warn(`Capture them with: npm run screenshots -- ${skipped.join(" ")}`);
}
