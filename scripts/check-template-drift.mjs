#!/usr/bin/env node
/**
 * check-template-drift.mjs
 *
 * Compares SceneryStack sims against SceneryStackTemplate using
 * config/template-manifest.json: template-owned files that must be identical
 * (after substituting the sim's package/repo name), files a sim may only extend,
 * required package.json scripts/dependencies, template-only and forbidden files,
 * and docs that must not be verbatim template copies.
 *
 * A sim approves a deviation by naming the path or script in backticks under its
 * AGENTS.md "## Compliance carve-outs" section, e.g.
 *   - `tests/setup.ts`: adds a WebGPU mock
 *   - `build:single`: custom Vite config has no single-file mode
 *
 * Usage:
 *   node scripts/check-template-drift.mjs <Sim> [<Sim> …]
 *   node scripts/check-template-drift.mjs --all          # every local simulation in the catalog
 *   node scripts/check-template-drift.mjs --fix <Sim>    # copy exact files / scripts, remove forbidden files
 *   options: --json, --quiet (only print sims with drift), --template <dir>
 *
 * Exit status: 0 when no unapproved drift, 1 otherwise, 2 on usage errors.
 */
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const batonRoot = resolve(here, "..");
const workspace = resolve(process.env.FLEET_WORKSPACE || process.env.OPENPHYSICS_WORKSPACE || join(batonRoot, ".."));
const manifestPath = process.env.TEMPLATE_MANIFEST || join(batonRoot, "config", "template-manifest.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

// ── args ──────────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
let fix = false;
let json = false;
let quiet = false;
let all = false;
let templateDir = join(workspace, manifest.template);
const sims = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--fix") fix = true;
  else if (a === "--json") json = true;
  else if (a === "--quiet") quiet = true;
  else if (a === "--all") all = true;
  else if (a === "--template") templateDir = resolve(args[++i] ?? "");
  else if (a === "-h" || a === "--help") {
    console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("*/")[0]);
    process.exit(0);
  } else if (a.startsWith("-")) {
    console.error(`unknown option ${a}`);
    process.exit(2);
  } else sims.push(a);
}
if (all) {
  const catalog = JSON.parse(readFileSync(join(batonRoot, "structure", "repos.json"), "utf8"));
  for (const r of catalog.repos) {
    if (r.isSimulation && r.framework === "SceneryStack" && existsSync(join(workspace, r.name, "package.json"))) {
      sims.push(r.name);
    }
  }
}
if (sims.length === 0) {
  console.error("usage: check-template-drift.mjs [--fix] [--json] [--quiet] (--all | <Sim> …)");
  process.exit(2);
}
if (!existsSync(join(templateDir, "package.json"))) {
  console.error(`template not found at ${templateDir}`);
  process.exit(2);
}

// ── helpers ───────────────────────────────────────────────────────────────────
const readText = (p) => (existsSync(p) && statSync(p).isFile() ? readFileSync(p, "utf8") : null);
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const replaceAll = (text, from, to) => (from && from !== to ? text.replace(new RegExp(escapeRe(from), "g"), to) : text);

/** Map sim-specific names onto the template's so files compare literally. */
const toTemplate = (text, sim) =>
  replaceAll(replaceAll(text, sim.repoName, manifest.tokens.repoName), sim.packageName, manifest.tokens.packageName);
const fromTemplate = (text, sim) =>
  replaceAll(replaceAll(text, manifest.tokens.repoName, sim.repoName), manifest.tokens.packageName, sim.packageName);

const getPath = (obj, path) => path.split(".").reduce((o, k) => (o == null ? undefined : o[k]), obj);
const setPath = (obj, path, value) => {
  const keys = path.split(".");
  const last = keys.pop();
  const parent = keys.reduce((o, k) => (o == null ? undefined : o[k]), obj);
  if (parent && typeof parent === "object") parent[last] = value;
};
const stable = (v) => JSON.stringify(v);

/** Parse backticked tokens in the sim's "## Compliance carve-outs" section(s). */
function carveOuts(simDir) {
  const text = readText(join(simDir, "AGENTS.md")) ?? "";
  const approved = new Set();
  const re = /^## Compliance carve-outs?\s*$([\s\S]*?)(?=^## |(?![\s\S]))/gm;
  for (const m of text.matchAll(re)) {
    for (const t of m[1].matchAll(/`([^`\n]+)`/g)) approved.add(t[1].trim().replace(/^npm run /, ""));
  }
  return approved;
}

/** Fraction of the sim doc's non-blank lines that also appear in the template doc. */
function copyRatio(simText, templateText) {
  const lines = (t) => t.split("\n").map((l) => l.trim()).filter((l) => l.length > 3);
  const simLines = lines(simText);
  if (simLines.length === 0) return 0;
  const tpl = new Set(lines(templateText));
  return simLines.filter((l) => tpl.has(l)).length / simLines.length;
}

function git(simDir, ...a) {
  return execFileSync("git", ["-C", simDir, ...a], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
}

// ── checks ────────────────────────────────────────────────────────────────────
const templatePkg = JSON.parse(readFileSync(join(templateDir, "package.json"), "utf8"));

function checkSim(repoName) {
  const simDir = join(workspace, repoName);
  const issues = [];
  const fixed = [];
  const pkgText = readText(join(simDir, "package.json"));
  if (!pkgText) return { sim: repoName, issues: [{ kind: "missing", path: "package.json", detail: "no package.json" }], fixed };
  const pkg = JSON.parse(pkgText);
  const sim = { repoName, packageName: pkg.name };
  const approved = carveOuts(simDir);
  const isTemplate = repoName === manifest.template;
  const add = (kind, path, detail) => {
    if (!approved.has(path)) issues.push({ kind, path, detail });
  };

  // exact files
  for (const rel of manifest.exact) {
    const tpl = readText(join(templateDir, rel));
    if (tpl === null) continue;
    const cur = readText(join(simDir, rel));
    if (cur !== null && toTemplate(cur, sim) === tpl) continue;
    if (approved.has(rel)) continue;
    if (fix) {
      mkdirSync(dirname(join(simDir, rel)), { recursive: true });
      writeFileSync(join(simDir, rel), fromTemplate(tpl, sim));
      fixed.push(rel);
    } else add(cur === null ? "missing" : "differs", rel, cur === null ? "template-owned file missing" : "differs from template");
  }

  // .gitignore-style files: every template line must be present
  for (const rel of manifest.linesSuperset) {
    const tpl = readText(join(templateDir, rel));
    const cur = readText(join(simDir, rel));
    if (tpl === null) continue;
    const have = new Set((cur ?? "").split("\n").map((l) => l.trim()));
    const missing = tpl.split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#") && !have.has(l));
    if (missing.length === 0) continue;
    if (fix && !approved.has(rel)) {
      writeFileSync(join(simDir, rel), `${(cur ?? "").replace(/\n*$/, "\n")}\n# Template-owned entries\n${missing.join("\n")}\n`);
      fixed.push(rel);
    } else add("differs", rel, `missing template lines: ${missing.join(", ")}`);
  }

  // JSON files a sim may extend only at the listed paths (arrays: superset of template)
  for (const [rel, extendable] of Object.entries(manifest.jsonExtend)) {
    const tplText = readText(join(templateDir, rel));
    const curText = readText(join(simDir, rel));
    if (tplText === null) continue;
    if (curText === null) {
      add("missing", rel, "template-owned file missing");
      continue;
    }
    const tpl = JSON.parse(toTemplate(tplText, sim));
    const cur = JSON.parse(toTemplate(curText, sim));
    const problems = [];
    for (const path of extendable) {
      const t = getPath(tpl, path);
      const c = getPath(cur, path);
      if (Array.isArray(t)) {
        const have = new Set((Array.isArray(c) ? c : []).map(stable));
        const lost = t.filter((x) => !have.has(stable(x)));
        if (lost.length) problems.push(`${path} drops ${lost.map(stable).join(", ").slice(0, 160)}`);
      } else if (t !== undefined && stable(t) !== stable(c)) problems.push(`${path} differs`);
      setPath(tpl, path, null);
      setPath(cur, path, null);
    }
    if (stable(tpl) !== stable(cur)) problems.push("differs outside extendable keys");
    if (problems.length) add("differs", rel, problems.join("; "));
  }

  // package.json
  const pj = manifest.packageJson;
  let pkgChanged = false;
  if (pj.requiredScriptsFromTemplate) {
    for (const [name, cmd] of Object.entries(templatePkg.scripts)) {
      if (manifest.templateOnly.scripts.includes(name)) continue;
      const cur = pkg.scripts?.[name];
      if (cur === cmd || approved.has(name)) continue;
      if (fix) {
        pkg.scripts ??= {};
        pkg.scripts[name] = cmd;
        pkgChanged = true;
        fixed.push(`script ${name}`);
      } else add("script", name, cur === undefined ? `missing script (template: ${cmd})` : `"${cur}" ≠ template "${cmd}"`);
    }
  }
  for (const name of isTemplate ? [] : manifest.templateOnly.scripts) {
    if (pkg.scripts?.[name] === undefined || approved.has(name)) continue;
    if (fix) {
      delete pkg.scripts[name];
      pkgChanged = true;
      fixed.push(`script ${name} (template-only)`);
    } else add("template-only", name, "template-only script in a sim");
  }
  if (pj.requiredDependenciesFromTemplate) {
    const major = (v) => /(\d+)/.exec(v ?? "")?.[1];
    for (const field of ["dependencies", "devDependencies"]) {
      for (const [dep, ver] of Object.entries(templatePkg[field] ?? {})) {
        const cur = pkg.dependencies?.[dep] ?? pkg.devDependencies?.[dep];
        if (cur === undefined) add("dependency", dep, `missing ${field} ${dep}@${ver}`);
        else if (major(cur) !== major(ver)) add("dependency", dep, `${dep}@${cur} major ≠ template ${ver}`);
      }
    }
  }
  for (const key of pj.matchKeys) {
    if (stable(pkg[key]) !== stable(templatePkg[key])) add("package", key, `package.json "${key}" ${stable(pkg[key])} ≠ template ${stable(templatePkg[key])}`);
  }
  if (pj.overridesSuperset) {
    const lost = Object.keys(templatePkg.overrides ?? {}).filter((k) => !(k in (pkg.overrides ?? {})));
    if (lost.length) add("package", "overrides", `missing overrides: ${lost.join(", ")}`);
  }
  if (pkgChanged) writeFileSync(join(simDir, "package.json"), `${JSON.stringify(pkg, null, 2)}\n`);

  // template-only and forbidden files
  for (const rel of [...(isTemplate ? [] : manifest.templateOnly.files), ...manifest.forbidden]) {
    const p = join(simDir, rel);
    if (!existsSync(p) || approved.has(rel)) continue;
    const kind = manifest.templateOnly.files.includes(rel) ? "template-only" : "forbidden";
    if (fix) {
      try {
        git(simDir, "rm", "-rq", "--", rel);
      } catch {
        rmSync(p, { recursive: true, force: true });
      }
      fixed.push(`${rel} removed`);
    } else add(kind, rel, kind === "forbidden" ? "file must not exist in a sim" : "template-only file in a sim");
  }

  // docs that must be sim-specific
  const ntc = manifest.noTemplateCopies;
  for (const rel of isTemplate ? [] : ntc.files) {
    const cur = readText(join(simDir, rel));
    const tpl = readText(join(templateDir, rel));
    if (cur === null || tpl === null) continue;
    const ratio = copyRatio(toTemplate(cur, sim), tpl);
    if (ratio >= ntc.threshold) add("template-copy", rel, `${Math.round(ratio * 100)}% of lines copied from the template`);
  }

  return { sim: repoName, issues, fixed };
}

// ── run ───────────────────────────────────────────────────────────────────────
const results = sims.map(checkSim);
if (json) {
  console.log(JSON.stringify(results, null, 2));
} else {
  for (const r of results) {
    if (r.fixed.length) console.log(`🔧 ${r.sim}: fixed ${r.fixed.join(", ")}`);
    if (r.issues.length === 0) {
      if (!quiet) console.log(`✅ ${r.sim}`);
      continue;
    }
    console.log(`❌ ${r.sim} (${r.issues.length})`);
    for (const i of r.issues) console.log(`   ${i.kind.padEnd(13)} ${i.path} — ${i.detail}`);
  }
  if (results.length > 1) {
    const bad = results.filter((r) => r.issues.length).length;
    console.log(`\n${results.length - bad}/${results.length} sims match the template.`);
  }
}
process.exit(results.some((r) => r.issues.length) ? 1 : 0);
