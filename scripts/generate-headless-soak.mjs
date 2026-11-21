#!/usr/bin/env node
/**
 * generate-headless-soak.mjs
 *
 * Writes a sim's tests/soak/headless.soak.ts from its src/main.ts, so the headless soak
 * builds the screens exactly as the sim does. It copies the statements inside
 * `onReadyToLaunch(() => { … })` that run before `new Sim(…)` into a buildSim() function,
 * keeps only the imports those statements use (paths rebased to ../../src/), and tracks
 * the sim's Colors module plus every object those statements construct (preferences
 * models, shared notebooks, singletons) for listener-count checks.
 *
 * Usage:
 *   node scripts/generate-headless-soak.mjs <SimDir> [--force]
 *
 * Refuses to overwrite an existing tests/soak/headless.soak.ts unless --force is given
 * (the file is sim-owned once written: exclude lists and actions get added by hand).
 * Exit status: 0 written, 1 main.ts shape not recognized, 2 usage error.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, join, resolve } from "node:path";

const args = process.argv.slice(2);
const force = args.includes("--force");
const simArg = args.find((a) => !a.startsWith("--"));
if (!simArg) {
  console.error("usage: generate-headless-soak.mjs <SimDir> [--force]");
  process.exit(2);
}
const simDir = resolve(simArg);
const sim = basename(simDir);
const mainPath = join(simDir, "src", "main.ts");
const outPath = join(simDir, "tests", "soak", "headless.soak.ts");

function fail(message) {
  console.error(`${sim}: ${message}`);
  process.exit(1);
}

if (!existsSync(mainPath)) {
  fail("src/main.ts not found");
}
if (existsSync(outPath) && !force) {
  console.log(`${sim}: tests/soak/headless.soak.ts exists (pass --force to regenerate)`);
  process.exit(0);
}

const main = readFileSync(mainPath, "utf8");

// ── body: statements of the functions enclosing `new Sim(`, before that call ──
// Usually the onReadyToLaunch(() => { … }) callback; some sims call a named launch(), or
// nest a `const launch = () => { … }` inside the callback. Every enclosing function
// contributes the statements before its inner function (or before new Sim, innermost).
const simAt = main.search(/new\s+Sim\s*\(/);
if (simAt < 0) {
  fail("no new Sim(…) in main.ts");
}
const HEAD =
  /onReadyToLaunch\(\s*(?:async\s*)?\(\)\s*=>\s*\{|(?<=^|\n)[ \t]*(?:async\s+)?function\s+\w+\s*\([^)]*\)\s*(?::\s*[\w<>| ]+?\s*)?\{|(?<=^|\n)[ \t]*const\s+\w+\s*=\s*(?:async\s*)?\([^)]*\)\s*(?::\s*[\w<>| ]+?\s*)?=>\s*\{/g;
/** Index of the `}` closing the block whose `{` sits just before `open` (naive brace count). */
function closeOf(open) {
  let depth = 1;
  for (let i = open; i < main.length; i++) {
    if (main[i] === "{") {
      depth++;
    } else if (main[i] === "}" && --depth === 0) {
      return i;
    }
  }
  return main.length;
}
const enclosing = [];
for (const head of main.slice(0, simAt).matchAll(HEAD)) {
  const start = head.index + head[0].length;
  if (closeOf(start) > simAt) {
    enclosing.push({ head: head.index, start });
  }
}
if (enclosing.length === 0) {
  fail("could not find the function that calls new Sim(…)");
}
// Cut before `const sim = `, `let sim: Sim = ` or a bare `sim = ` when the call is assigned.
const assignment = main.slice(0, simAt).search(/(?:(?:const|let)\s+)?[A-Za-z_$][\w$]*\s*(?::[^=;{}]+)?=\s*$/);
const cut = assignment >= 0 ? assignment : simAt;
const ownBody = enclosing
  .map((e, i) => main.slice(e.start, i + 1 < enclosing.length ? enclosing[i + 1].head : cut))
  .join("\n")
  .replace(/\s+$/, "");
const stripComments = (text) => text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:])\/\/[^\n]*/g, "$1");
const mentions = (text, name) => new RegExp(`(^|[^\\w$.])${name.replace(/\$/g, "\\$")}(?![\\w$])`).test(text);
// Module-level const / let declarations (column 0) that the body reads, e.g. a stringManager
// or a `let sim` the screens call back into. Repeat so declarations they read come along too.
const preamble = [];
let changed = true;
while (changed) {
  changed = false;
  const code = stripComments(`${preamble.join("\n")}\n${ownBody}`);
  for (const top of main.slice(0, enclosing[0].head).matchAll(/^(?:const|let)\s+([A-Za-z_$][\w$]*)[^;]*;$/gm)) {
    const text = `  ${top[0]}`;
    if (!preamble.includes(text) && mentions(code, top[1])) {
      preamble.unshift(text);
      changed = true;
    }
  }
}
let body = `${preamble.length ? `${preamble.join("\n")}\n` : ""}${ownBody}`;
// A bare `sim = new Sim(…)` was cut, so its `let sim: Sim | null = null` is never assigned and
// TypeScript would narrow it to null inside callbacks. Keep the declared type via `as`.
const assignedVar = main.slice(cut, simAt).match(/^([A-Za-z_$][\w$]*)\s*=\s*$/)?.[1];
if (assignedVar) {
  body = body.replace(
    new RegExp(`let\\s+${assignedVar}\\s*:\\s*([^=;]+?)\\s*(?:=\\s*(null|undefined)\\s*)?;`),
    (_, type, init) => `let ${assignedVar} = ${init ?? "undefined"} as ${type.trim()};`,
  );
}
const code = stripComments(body);
const simArgs = main.slice(simAt).match(/new\s+Sim\s*\(\s*([\s\S]*?),\s*([A-Za-z_$][\w$]*)\s*[,)]/);
if (!simArgs) {
  fail("could not read the screens argument of new Sim(title, screens, …)");
}
const screensVar = simArgs[2];
if (!new RegExp(`\\b(const|let)\\s+${screensVar}\\b`).test(code)) {
  fail(`screens variable '${screensVar}' is not declared before new Sim(…)`);
}

// ── imports: keep the ones the body uses ─────────────────────────────────────
const used = (name) => mentions(code, name);
const kept = [];
let colorsName = null;
for (const match of main.matchAll(/^import\s+(type\s+)?([\s\S]*?)\s+from\s+["']([^"']+)["'];?/gm)) {
  const [, typeOnly, clause, source] = match;
  const path = source.startsWith("./") ? `../../src/${source.slice(2)}` : source;
  let defaultName = null;
  let named = [];
  const braces = clause.match(/\{([\s\S]*)\}/);
  if (braces) {
    named = braces[1]
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
  }
  const head = clause.replace(/\{[\s\S]*\}/, "").replace(/,\s*$/, "").trim();
  if (head.startsWith("* as ")) {
    const ns = head.slice(5).trim();
    if (used(ns)) {
      kept.push(`import ${typeOnly ?? ""}* as ${ns} from "${path}";`);
    }
    continue;
  }
  if (head) {
    defaultName = head;
  }
  const keepNamed = named.filter((spec) => used(spec.split(/\s+as\s+/).pop().replace(/^type\s+/, "")));
  const keepDefault = defaultName && used(defaultName) ? defaultName : null;
  if (/Colors$/.test(defaultName ?? "") && source.startsWith("./")) {
    colorsName = defaultName;
  }
  const finalDefault = keepDefault ?? (defaultName === colorsName ? colorsName : null);
  if (!finalDefault && keepNamed.length === 0) {
    continue;
  }
  const parts = [finalDefault, keepNamed.length ? `{ ${keepNamed.join(", ")} }` : null].filter(Boolean);
  kept.push(`import ${typeOnly ?? ""}${parts.join(", ")} from "${path}";`);
}

// ── tracked: objects the body constructs, plus the Colors module ─────────────
// Also any constant only the Sim options read (it would be unused here otherwise).
const tracked = [];
for (const decl of code.matchAll(/^\s*const\s+([A-Za-z_$][\w$]*)\s*(?::[^=]+)?=\s*([^;]*)/gm)) {
  const [, name, init] = decl;
  if (name === screensVar || tracked.includes(name)) {
    continue;
  }
  const references = code.match(new RegExp(`(^|[^\\w$.])${name.replace(/\$/g, "\\$")}(?![\\w$])`, "g"))?.length ?? 0;
  if (/^\s*new\s+[A-Z]/.test(init) || /\.getInstance\(\)/.test(init) || references <= 1) {
    tracked.push(name);
  }
}
if (colorsName) {
  tracked.unshift(colorsName);
}

const indented = body
  .split("\n")
  .map((line) => line.replace(/\s+$/, ""))
  .join("\n")
  .replace(/^\n+/, "");

const out = `/**
 * By-hand headless soak: npm run test:soak:headless (never in CI).
 *
 * buildSim() mirrors src/main.ts up to \`new Sim(…)\` (generated by
 * Baton/scripts/generate-headless-soak.mjs; keep it in sync when main.ts changes). The
 * harness in tests/helpers/headlessSoak.ts (template-owned) presses every control, sets
 * every slider, steps, switches screens, flips the color profile and locale, presses
 * Reset All, and fails when listener counts, node counts or retained heap rise after
 * every round.
 *
 * Add \`exclude\` for controls that must not be pressed headless and \`actions\` for what
 * only this sim can do (record/clear, add/remove objects).
 */

${kept.join("\n")}
import { describeHeadlessSoak } from "../helpers/headlessSoak.js";

function buildSim() {
${indented}

  return { ${screensVar === "screens" ? "screens" : `screens: ${screensVar}`}, tracked: { ${tracked.join(", ")} } };
}

let built: ReturnType<typeof buildSim> | undefined;

describeHeadlessSoak({
  screens: () => {
    built = buildSim();
    return built.screens;
  },
  tracked: () => built?.tracked ?? {},
});
`;

mkdirSync(join(simDir, "tests", "soak"), { recursive: true });
writeFileSync(outPath, out, "utf8");
console.log(`${sim}: wrote tests/soak/headless.soak.ts (screens: ${screensVar}; tracked: ${tracked.join(", ") || "none"})`);
