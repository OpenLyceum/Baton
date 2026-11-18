#!/usr/bin/env node
/**
 * list-carve-outs.mjs
 *
 * Inventory of each sim's AGENTS.md "## Compliance carve-outs" bullets — the approved
 * deviations from the template, the compliance audit, and the skill probes. Carve-outs
 * are cheap to add and easy to forget, so the weekly compliance report shows each sim's
 * count; a count that keeps growing is drift being approved one bullet at a time.
 *
 * A bullet should name what it approves and why (`- \`path\`: reason`). It is
 * "temporary" when it links an issue (#123 or an issues URL) or says pending / until /
 * TODO / temporary / migrate; everything else is treated as a permanent design decision.
 * Bullets with no reason are flagged.
 *
 * Usage:
 *   node scripts/list-carve-outs.mjs <Sim> [<Sim> …]
 *   node scripts/list-carve-outs.mjs --all                  # local SceneryStack sims in the catalog
 *   node scripts/list-carve-outs.mjs --dir <path> [--name <Repo>]
 *   options: --json, --count (print only "<total>" for one sim, for the weekly table)
 *
 * Exit status: 0; 2 on usage errors. Reporting only — never fails a build.
 */
import { existsSync, readFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const batonRoot = resolve(here, "..");
const workspace = resolve(process.env.FLEET_WORKSPACE || process.env.OPENPHYSICS_WORKSPACE || join(batonRoot, ".."));

const args = process.argv.slice(2);
let all = false;
let json = false;
let countOnly = false;
let dirOverride = null;
let nameOverride = null;
const sims = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--all") all = true;
  else if (a === "--json") json = true;
  else if (a === "--count") countOnly = true;
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
    if (r.isSimulation && r.framework === "SceneryStack" && existsSync(join(workspace, r.name))) sims.push(r.name);
  }
}
if (dirOverride) sims.push(nameOverride ?? basename(dirOverride));
if (sims.length === 0) {
  console.error("usage: list-carve-outs.mjs [--json] [--count] (--all | --dir <path> | <Sim> …)");
  process.exit(2);
}

const TEMPORARY = /(^|\s)#\d+\b|\/issues\/\d+|\b(pending|until|todo|temporary|migrate|follow-up)\b/i;

function inventory(simDir) {
  let text = "";
  try {
    text = readFileSync(join(simDir, "AGENTS.md"), "utf8");
  } catch {
    return [];
  }
  const bullets = [];
  const re = /^## Compliance carve-outs?\s*$([\s\S]*?)(?=^## |(?![\s\S]))/gm;
  for (const m of text.matchAll(re)) {
    for (const raw of m[1].split(/\n(?=[-*] )/)) {
      const bullet = raw.trim();
      if (!/^[-*] /.test(bullet)) continue;
      const line = bullet.replace(/\s+/g, " ");
      const reason = line.replace(/^[-*] +(`[^`]+`(,\s*`[^`]+`)*|\*\*[^*]+\*\*)/, "").replace(/^[\s:—–-]+/, "");
      bullets.push({
        text: line.slice(0, 160),
        kind: TEMPORARY.test(line) ? "temporary" : "permanent",
        hasReason: reason.length >= 8,
      });
    }
  }
  return bullets;
}

const results = sims.map((sim) => {
  const dir = dirOverride && sim === (nameOverride ?? basename(dirOverride)) ? dirOverride : join(workspace, sim);
  const bullets = inventory(dir);
  return {
    sim,
    total: bullets.length,
    temporary: bullets.filter((b) => b.kind === "temporary").length,
    missingReason: bullets.filter((b) => !b.hasReason).map((b) => b.text),
    bullets,
  };
});

if (countOnly) {
  for (const r of results) console.log(r.total);
} else if (json) {
  console.log(JSON.stringify(results, null, 2));
} else {
  console.log("| Sim | Carve-outs | Temporary | No reason |");
  console.log("|---|---:|---:|---:|");
  for (const r of [...results].sort((a, b) => b.total - a.total || a.sim.localeCompare(b.sim))) {
    if (r.total) console.log(`| ${r.sim} | ${r.total} | ${r.temporary} | ${r.missingReason.length} |`);
  }
  const total = results.reduce((n, r) => n + r.total, 0);
  console.log(`\n${total} carve-out bullet(s) across ${results.filter((r) => r.total).length} of ${results.length} sim(s).`);
}
