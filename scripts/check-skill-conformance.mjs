#!/usr/bin/env node
/**
 * check-skill-conformance.mjs
 *
 * Automated form of the skill-conformance probe sheet that used to live (by hand) in the
 * superproject's review-log.md. Each probe is a grep-level check distilled from a
 * Baton/skills/<skill>/SKILL.md. Probes that the compliance audit, Biome plugins or
 * dependency-cruiser already enforce are not repeated here (memory-leak tests,
 * preferences, StringManager/locales, toFixed/Math.random/hardcoded Text/inline colors,
 * model→view imports).
 *
 * Use level "fail" only for probes that identify a specific required convention
 * and can reliably distinguish violations from valid alternatives. Keep heuristic
 * probes at "warn" even when the fleet has zero gaps. A "fail" gap exits 1;
 * --strict also fails on "warn" gaps.
 *
 * A sim approves a deviation with a bullet under its AGENTS.md "## Compliance carve-outs":
 *   - `skill:drag-listener`: the caliper's arrow keys are already owned by the jaw slider
 *
 * Usage:
 *   node scripts/check-skill-conformance.mjs <Sim> [<Sim> …]
 *   node scripts/check-skill-conformance.mjs --all              # every local SceneryStack sim in the catalog
 *   node scripts/check-skill-conformance.mjs --dir <path> [--name <Repo>]
 *   options: --json, --summary (per-probe fleet counts), --strict (also fail on "warn" probes)
 *
 * Exit status: 1 when an unapproved gap exists in a "fail" probe (or any probe with --strict),
 * 0 otherwise; 2 on usage errors.
 */
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const batonRoot = resolve(here, "..");
const workspace = resolve(process.env.FLEET_WORKSPACE || process.env.OPENPHYSICS_WORKSPACE || join(batonRoot, ".."));

// ── args ──────────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
let all = false;
let json = false;
let summary = false;
let strict = false;
let dirOverride = null;
let nameOverride = null;
const sims = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--all") all = true;
  else if (a === "--json") json = true;
  else if (a === "--summary") summary = true;
  else if (a === "--strict") strict = true;
  else if (a === "--dir") dirOverride = resolve(args[++i] ?? "");
  else if (a === "--name") nameOverride = args[++i];
  else if (a.startsWith("--")) {
    console.error(`unknown option ${a}`);
    process.exit(2);
  } else sims.push(a);
}
if (all) {
  const catalog = JSON.parse(readFileSync(join(batonRoot, "structure", "repos.json"), "utf8"));
  for (const r of catalog.repos) {
    if (r.isSimulation && r.framework === "SceneryStack" && existsSync(join(workspace, r.name, "src"))) sims.push(r.name);
  }
}
if (dirOverride) sims.push(nameOverride ?? basename(dirOverride));
if (sims.length === 0) {
  console.error("usage: check-skill-conformance.mjs [--json] [--summary] [--strict] (--all | --dir <path> | <Sim> …)");
  process.exit(2);
}

// ── helpers ───────────────────────────────────────────────────────────────────
function walk(dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === "generated") continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.ts$/.test(name) && !/\.d\.ts$/.test(name)) out.push(p);
  }
  return out;
}

/** Source with comments blanked, so a pattern quoted in a doc comment is not a hit. */
function stripComments(text) {
  return text.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, " ")).replace(/(^|[^:"'`\\])\/\/.*$/gm, "$1");
}

function carveOuts(simDir) {
  let text = "";
  try {
    text = readFileSync(join(simDir, "AGENTS.md"), "utf8");
  } catch {
    return new Set();
  }
  const approved = new Set();
  const re = /^## Compliance carve-outs?\s*$([\s\S]*?)(?=^## |(?![\s\S]))/gm;
  for (const m of text.matchAll(re)) {
    for (const t of m[1].matchAll(/^\s*[-*] +`skill:([a-z-]+)`/gm)) approved.add(t[1]);
  }
  return approved;
}

// ── probes ────────────────────────────────────────────────────────────────────
// Each probe gets the sim's source files ({ rel, code }) and returns:
//   null            — not applicable (feature absent)
//   { ok: true }    — follows the skill
//   { ok: false, path, detail } — gap (one representative path)
const firstHit = (files, re, filter = () => true) => files.find((f) => filter(f.rel) && re.test(f.code));
const anyHit = (files, re, filter) => firstHit(files, re, filter) !== undefined;
const gap = (path, detail) => ({ ok: false, path, detail });
const OK = { ok: true };
const isModel = (rel) => /(^|\/)model\//.test(rel);
const isView = (rel) => /(^|\/)view\//.test(rel) || /View\.ts$|Node\.ts$/.test(rel);

const PROBES = [
  {
    id: "coding-conventions",
    level: "fail",
    skill: "scenerystack-coding-conventions",
    run(files) {
      const hit = firstHit(files, /^\s*(export\s+)?(declare\s+)?(const\s+)?(enum\s+\w+|namespace\s+\w+\s*\{)/m);
      return hit ? gap(hit.rel, "enum or namespace declaration") : OK;
    },
  },
  {
    id: "model-tmodel-import",
    level: "fail",
    skill: "scenerystack-model",
    run(files) {
      const hit = firstHit(files, /import[^;]*\bTModel\b[^;]*from\s+["']scenerystack\/sim["']/);
      return hit ? gap(hit.rel, "TModel imported from scenerystack/sim (use scenerystack/joist)") : OK;
    },
  },
  {
    id: "screen-view",
    level: "fail",
    skill: "scenerystack-screen-view",
    run(files) {
      if (!files.some((f) => f.rel === "src/main.ts")) return gap("src/main.ts", "missing");
      if (!files.some((f) => /Screen\.ts$/.test(f.rel))) return gap("src/", "no *Screen.ts");
      if (!files.some((f) => /ScreenView\.ts$/.test(f.rel))) return gap("src/", "no *ScreenView.ts");
      return OK;
    },
  },
  {
    id: "query-parameters",
    level: "fail",
    skill: "scenerystack-query-parameters",
    run(files) {
      const schema = files.find((f) => /^src\/preferences\/[^/]*QueryParameters\.ts$/.test(f.rel));
      if (!schema || !/QueryStringMachine/.test(schema.code)) {
        return gap(schema?.rel ?? "src/preferences/", "no QueryStringMachine schema");
      }
      const hand = firstHit(files, /\blocation\.search\b|\bnew URLSearchParams\b/);
      return hand ? gap(hand.rel, "hand-parsed query string (location.search / URLSearchParams)") : OK;
    },
  },
  {
    id: "keyboard-help-dialog",
    level: "warn",
    skill: "scenerystack-keyboard-help-dialog",
    run(files) {
      const help = files.filter((f) => /KeyboardHelpContent\.ts$/.test(f.rel));
      if (help.length === 0) return gap("src/", "no *KeyboardHelpContent.ts");
      // Anything beyond the template's BasicActionsKeyboardHelpSection counts as real content.
      const real = help.some((f) =>
        /fromHotkeyData|\w*KeyboardHelpSection(Row)?\b/.test(f.code.replace(/BasicActionsKeyboardHelpSection/g, "")),
      );
      return real ? OK : gap(help[0].rel, "template stub only (BasicActionsKeyboardHelpSection)");
    },
  },
  {
    id: "optionize",
    level: "warn",
    skill: "scenerystack-optionize",
    run(files) {
      return anyHit(files, /\boptionize\b|\bcombineOptions\b/) ? OK : gap("src/", "no optionize/combineOptions call");
    },
  },
  {
    id: "layout",
    level: "warn",
    skill: "scenerystack-layout",
    run(files) {
      return anyHit(files, /\blayoutBounds\b|\bnew [VH]Box\b|\bAlignBox\b|\bGridBox\b/, isView)
        ? OK
        : gap("src/", "no layoutBounds / VBox / HBox in any view");
    },
  },
  {
    id: "ui-controls",
    level: "warn",
    skill: "scenerystack-ui-controls",
    run(files) {
      return anyHit(files, /from\s+["']scenerystack\/sun["']/) ? OK : gap("src/", "no scenerystack/sun import");
    },
  },
  {
    id: "model-view-transform",
    level: "fail",
    skill: "scenerystack-model-view-transform",
    run(files) {
      if (!anyHit(files, /\bModelViewTransform2\b/)) return null;
      const hit = firstHit(files, /\bModelViewTransform2\b/, isModel);
      return hit ? gap(hit.rel, "ModelViewTransform2 used inside model/") : OK;
    },
  },
  {
    id: "drag-listener",
    level: "warn",
    skill: "scenerystack-drag-listener",
    run(files) {
      // Per file, as the skill reads: a plain DragListener is right when something else
      // already owns the keys (a KeyboardListener / HotkeyData, an AccessibleSlider), and the
      // file says so in a "pointer-only" comment naming the keyboard path.
      const drags = files.filter((f) => /\bnew DragListener\b/.test(f.code));
      if (drags.length === 0) return null;
      const keyboard =
        /\b(KeyboardDragListener|RichDragListener|SoundRichDragListener|KeyboardListener|AccessibleSlider|AccessibleValueHandler)\b/;
      const bare = drags.find((f) => !keyboard.test(f.code) && !/pointer-only/i.test(f.raw));
      return bare
        ? gap(bare.rel, "DragListener with no keyboard listener in the file and no 'pointer-only' comment naming the keyboard path")
        : OK;
    },
  },
  {
    id: "custom-drawing",
    level: "warn",
    skill: "scenerystack-custom-drawing",
    run(files) {
      // Offscreen canvases (ImageData buffers, sprites, textures, GPU targets, pixel
      // readback) are fine when the result is painted through CanvasNode / Image / Pattern /
      // Sprites. The skill forbids a canvas *displayed* outside scenery.
      if (!anyHit(files, /\.getContext\(|\bHTMLCanvasElement\b|document\.createElement\(\s*["']canvas["']/)) return null;
      const shown = firstHit(files, /\bnew DOM\(\s*[\w.]*[Cc]anvas\b|\.(appendChild|append|prepend)\(\s*[\w.]*[Cc]anvas\b/);
      return shown ? gap(shown.rel, "canvas displayed through a DOM node or attached to the document (paint it through CanvasNode / Image)") : OK;
    },
  },
  {
    id: "sound",
    level: "warn",
    skill: "scenerystack-sound",
    run(files) {
      const raw = firstHit(files, /\bnew (Audio|AudioContext|webkitAudioContext)\s*\(/);
      if (raw) return gap(raw.rel, "raw Web Audio API (use tambo soundManager)");
      if (!anyHit(files, /\bsoundManager\b/)) return null;
      const init = files.find((f) => f.rel === "src/init.ts");
      return init && /supportsSound\s*:\s*true/.test(init.code)
        ? OK
        : gap("src/init.ts", "soundManager used but init.ts does not set supportsSound: true");
    },
  },
];

// ── run ───────────────────────────────────────────────────────────────────────
const results = [];
for (const sim of sims) {
  const simDir = dirOverride && sim === (nameOverride ?? basename(dirOverride)) ? dirOverride : join(workspace, sim);
  if (!existsSync(join(simDir, "src"))) {
    results.push({ sim, error: "no src/ directory", probes: [] });
    continue;
  }
  const files = walk(join(simDir, "src")).map((p) => ({
    rel: relative(simDir, p).split("\\").join("/"),
    raw: readFileSync(p, "utf8"),
    code: stripComments(readFileSync(p, "utf8")),
  }));
  const approved = carveOuts(simDir);
  const probes = PROBES.map((probe) => {
    const r = probe.run(files);
    const base = { id: probe.id, level: probe.level };
    if (r === null) return { ...base, status: "n/a" };
    if (r.ok) return { ...base, status: "follow" };
    if (approved.has(probe.id)) return { ...base, status: "carved-out", path: r.path, detail: r.detail };
    return { ...base, status: "gap", path: r.path, detail: r.detail };
  });
  results.push({ sim, probes });
}

const gaps = (r) => r.probes.filter((p) => p.status === "gap");
if (json) {
  console.log(JSON.stringify(results, null, 2));
} else if (summary) {
  console.log("| Probe | Level | follow | gap | carved-out | n/a |");
  console.log("|---|---|---:|---:|---:|---:|");
  for (const probe of PROBES) {
    const count = (s) => results.filter((r) => r.probes.some((p) => p.id === probe.id && p.status === s)).length;
    console.log(`| ${probe.id} | ${probe.level} | ${count("follow")} | ${count("gap")} | ${count("carved-out")} | ${count("n/a")} |`);
  }
} else {
  for (const r of results) {
    if (r.error) {
      console.log(`❌ ${r.sim}: ${r.error}`);
      continue;
    }
    const g = gaps(r);
    if (g.length === 0) {
      console.log(`✅ ${r.sim}`);
      continue;
    }
    console.log(`${g.some((p) => p.level === "fail") ? "❌" : "⚠️ "} ${r.sim} (${g.length})`);
    for (const p of g) console.log(`   ${p.level.padEnd(5)} ${p.id.padEnd(22)} ${p.path} — ${p.detail}`);
  }
}
const failing = results.some((r) => r.error || gaps(r).some((p) => strict || p.level === "fail"));
process.exit(failing ? 1 : 0);
