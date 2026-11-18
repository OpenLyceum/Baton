#!/usr/bin/env node
/**
 * check-memory-leak-inventory.mjs
 *
 * Disposal inventory for one or more SceneryStack sims: every src/ class that defines
 * dispose() (a method in its own body, or inherited from a parent class in the same sim)
 * must be exercised by tests/memory-leak.test.ts or carved out as `memory-leak:<Class>`
 * under AGENTS.md "## Compliance carve-outs". *ScreenView / *Screen / *Sim / YourModel
 * skip. Classes whose only cleanup is this.disposeEmitter.addListener / this.addDisposable
 * on an external base are listed in --json as disposeEmitterOnly, not flagged.
 *
 * Baton has no TypeScript parser installed (TS 7 ships no JS API), so this uses a small
 * TypeScript-aware lexer — comments, strings, template literals (with nested ${}),
 * regex literals — and brace-matches each class body on that token stream. Members are
 * read from the class's own body only (depth 1), so a neighbouring class's dispose()
 * never leaks in and a dispose() late in a long class is never missed.
 *
 * The suite covers a class when, outside comments and strings, it
 *   - imports it as a value binding (`import type` alone does not count), or
 *   - names it as an identifier (`new Foo()`, `makeFoo(Foo)`, `ns.Foo`), or
 *   - names it in a describeDisposalLeaks case string (`name: "Foo"` / `name: "Foo (x)"`), or
 *   - declares it in a comment for factory probes that never name the class:
 *       // memory-leak-covers: GlassView, DetectorView (owned by DetectorPanel)
 *       // memory-leak-covers-subclasses: BaseElement (every element via createDefaultElement)
 *     (comma-separated; parenthesised notes are ignored; may span lines in one comment;
 *     the -subclasses form covers the named class and every same-sim descendant).
 * A class that only appears in an import path, a string or a prose comment is not covered.
 * An abstract class counts as covered when a concrete subclass in the sim is covered.
 *
 * Carve-outs naming a class that would not be flagged (covered, absent, skipped, or
 * without disposal) are reported as orphaned.
 *
 * Usage:
 *   node scripts/check-memory-leak-inventory.mjs [--json] <SimDir> [<SimDir> …]
 * Text output: "<Sim>: ok" or "<Sim>: A, B", plus "<Sim>: orphaned memory-leak carve-outs: X".
 * Exit status: 1 when any sim has an uncovered class (orphans do not fail), 2 on usage errors.
 */
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";

// ── Lexer ────────────────────────────────────────────────────────────────────

const REGEX_PREFIX_KEYWORDS = new Set([
  "return", "typeof", "instanceof", "in", "of", "new", "delete", "void", "throw", "case",
  "do", "else", "yield", "await",
]);
const PUNCT3 = ["===", "!==", "**=", "...", "<<=", ">>=", "&&=", "||=", "??="];
const PUNCT2 = ["=>", "==", "!=", "<=", ">=", "&&", "||", "??", "?.", "++", "--", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "**", "<<"];

/**
 * Tokenize TypeScript source. Tokens: { t: "id"|"str"|"tpl"|"num"|"re"|"p", v, line }.
 * Template literals emit a "tpl" token per static chunk; `${` and its closing `}` are
 * "p" tokens with v "${" / "}$" so brace matching on "{" / "}" stays balanced.
 * Comments are returned separately as { text, line }.
 */
export function lex(src) {
  const tokens = [];
  const comments = [];
  const stack = []; // "{" for braces, "${" for template expressions
  let i = 0;
  let line = 1;
  const n = src.length;
  const push = (t, v) => tokens.push({ t, v, line });
  const prevAllowsRegex = () => {
    const prev = tokens[tokens.length - 1];
    if (!prev) return true;
    if (prev.t === "id") return REGEX_PREFIX_KEYWORDS.has(prev.v);
    if (prev.t === "p" && prev.v === "!") {
      // Postfix non-null assertion (`x! / y`) vs prefix not (`!/re/.test(s)`).
      const before = tokens[tokens.length - 2];
      return !(before && (before.t === "id" || before.t === "num" || [")", "]"].includes(before.v)));
    }
    if (prev.t === "p") return ![")", "]", "}", "}$"].includes(prev.v);
    return false;
  };
  const countLines = (s) => {
    for (const c of s) if (c === "\n") line++;
  };
  const readTemplate = () => {
    // i is just past the opening backtick or a closing "}" of ${...}
    let chunk = "";
    while (i < n) {
      const c = src[i];
      if (c === "\\") {
        chunk += src.slice(i, i + 2);
        i += 2;
        continue;
      }
      if (c === "`") {
        push("tpl", chunk);
        countLines(chunk);
        i++;
        return;
      }
      if (c === "$" && src[i + 1] === "{") {
        push("tpl", chunk);
        countLines(chunk);
        push("p", "${");
        stack.push("${");
        i += 2;
        return;
      }
      chunk += c;
      i++;
    }
    push("tpl", chunk);
    countLines(chunk);
  };

  while (i < n) {
    const c = src[i];
    if (c === "\n") {
      line++;
      i++;
      continue;
    }
    if (c === " " || c === "\t" || c === "\r" || c === "\f" || c === "\v" || c === "﻿") {
      i++;
      continue;
    }
    if (c === "/" && src[i + 1] === "/") {
      const end = src.indexOf("\n", i);
      const stop = end === -1 ? n : end;
      comments.push({ text: src.slice(i + 2, stop), line });
      i = stop;
      continue;
    }
    if (c === "/" && src[i + 1] === "*") {
      const end = src.indexOf("*/", i + 2);
      const stop = end === -1 ? n : end + 2;
      const text = src.slice(i + 2, end === -1 ? n : end);
      comments.push({ text, line });
      countLines(text);
      i = stop;
      continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      let v = "";
      while (j < n && src[j] !== c && src[j] !== "\n") {
        if (src[j] === "\\") {
          v += src.slice(j, j + 2);
          j += 2;
          continue;
        }
        v += src[j];
        j++;
      }
      push("str", v);
      i = j + 1;
      continue;
    }
    if (c === "`") {
      i++;
      readTemplate();
      continue;
    }
    if (/[A-Za-z_$]/.test(c) || c.charCodeAt(0) > 127) {
      let j = i + 1;
      while (j < n && (/[\w$]/.test(src[j]) || src.charCodeAt(j) > 127)) j++;
      push("id", src.slice(i, j));
      i = j;
      continue;
    }
    if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(src[i + 1] ?? ""))) {
      let j = i + 1;
      while (j < n && /[\w.]/.test(src[j])) j++;
      push("num", src.slice(i, j));
      i = j;
      continue;
    }
    if (c === "/" && prevAllowsRegex()) {
      let j = i + 1;
      let inClass = false;
      while (j < n && src[j] !== "\n") {
        const d = src[j];
        if (d === "\\") {
          j += 2;
          continue;
        }
        if (d === "[") inClass = true;
        else if (d === "]") inClass = false;
        else if (d === "/" && !inClass) break;
        j++;
      }
      j++;
      while (j < n && /[a-z]/i.test(src[j])) j++;
      push("re", src.slice(i, j));
      i = j;
      continue;
    }
    if (c === "{") {
      stack.push("{");
      push("p", "{");
      i++;
      continue;
    }
    if (c === "}") {
      const top = stack.pop();
      if (top === "${") {
        push("p", "}$");
        i++;
        readTemplate();
      } else {
        push("p", "}");
        i++;
      }
      continue;
    }
    const three = src.slice(i, i + 3);
    if (PUNCT3.includes(three)) {
      push("p", three);
      i += 3;
      continue;
    }
    const two = src.slice(i, i + 2);
    if (PUNCT2.includes(two)) {
      push("p", two);
      i += 2;
      continue;
    }
    push("p", c);
    i++;
  }
  return { tokens, comments };
}

// ── Classes ──────────────────────────────────────────────────────────────────

const OPEN = new Set(["{", "(", "[", "${"]);
const CLOSE = new Set(["}", ")", "]", "}$"]);

/** Index of the token closing the bracket opened at `start`. */
function matchClose(tokens, start) {
  let depth = 0;
  for (let k = start; k < tokens.length; k++) {
    const tk = tokens[k];
    if (tk.t !== "p") continue;
    if (OPEN.has(tk.v)) depth++;
    else if (CLOSE.has(tk.v)) {
      depth--;
      if (depth === 0) return k;
    }
  }
  return tokens.length - 1;
}

const isP = (tk, v) => tk && tk.t === "p" && tk.v === v;
const isId = (tk, v) => tk && tk.t === "id" && (v === undefined || tk.v === v);

/** Does the class body [open, close] define dispose() (method with a body, or arrow property) at depth 1? */
function ownDispose(tokens, open, close) {
  let depth = 0;
  for (let k = open + 1; k < close; k++) {
    const tk = tokens[k];
    if (tk.t === "p" && OPEN.has(tk.v)) {
      depth++;
      continue;
    }
    if (tk.t === "p" && CLOSE.has(tk.v)) {
      depth--;
      continue;
    }
    if (depth !== 0 || !isId(tk, "dispose")) continue;
    const prev = tokens[k - 1];
    if (isP(prev, ".") || isP(prev, "?.")) continue;
    let m = k + 1;
    if (isP(tokens[m], "?") || isP(tokens[m], "!")) m++;
    if (isP(tokens[m], "=")) return { line: tk.line };
    if (isP(tokens[m], "<")) {
      while (m < close && !isP(tokens[m], "(")) m++;
    }
    if (!isP(tokens[m], "(")) continue; // dispose: () => void; (declaration only)
    m = matchClose(tokens, m) + 1;
    // Optional return type, then "{" (implementation) vs ";" / next member (overload, abstract).
    let d = 0;
    for (; m < close; m++) {
      const t2 = tokens[m];
      if (d === 0 && isP(t2, "{") && !isP(tokens[m - 1], ":")) return { line: tk.line };
      if (d === 0 && (isP(t2, ";") || isP(t2, "}"))) break;
      if (isP(t2, "(") || isP(t2, "[") || isP(t2, "<")) d++;
      else if (isP(t2, ")") || isP(t2, "]") || isP(t2, ">")) d--;
      else if (isP(t2, "{")) m = matchClose(tokens, m);
      if (d < 0) break;
    }
  }
  return null;
}

/** this.disposeEmitter.addListener(...) / this.addDisposable(...) anywhere in the class body. */
function disposeEmitterCleanup(tokens, open, close) {
  for (let k = open + 1; k < close - 2; k++) {
    if (!isId(tokens[k], "this") || !isP(tokens[k + 1], ".")) continue;
    const name = tokens[k + 2];
    if (isId(name, "addDisposable")) return { line: name.line };
    if (isId(name, "disposeEmitter") && isP(tokens[k + 3], ".") && isId(tokens[k + 4], "addListener")) {
      return { line: name.line };
    }
  }
  return null;
}

/** All named class declarations/expressions in one file. */
export function parseClasses(src) {
  const { tokens } = lex(src);
  const classes = [];
  for (let k = 0; k < tokens.length; k++) {
    if (!isId(tokens[k], "class") || isP(tokens[k - 1], ".")) continue;
    const nameTok = tokens[k + 1];
    if (!isId(nameTok) || ["extends", "implements"].includes(nameTok.v)) continue;
    let abstract = false;
    for (let b = k - 1; b >= 0 && b >= k - 4 && tokens[b].t === "id"; b--) {
      if (tokens[b].v === "abstract") abstract = true;
    }
    // Header: generics / extends / implements, up to the body "{" at angle+paren depth 0.
    let parent = null;
    let angle = 0;
    let paren = 0;
    let m = k + 2;
    for (; m < tokens.length; m++) {
      const tk = tokens[m];
      if (isP(tk, "<")) angle++;
      else if (isP(tk, ">")) angle--;
      else if (isP(tk, "(")) paren++;
      else if (isP(tk, ")")) paren--;
      else if (isP(tk, "{")) {
        if (angle === 0 && paren === 0) break;
        m = matchClose(tokens, m);
      } else if (isId(tk, "extends") && angle === 0 && paren === 0 && parent === null) {
        // extends a.b.Base<T>(…) → last identifier before "<" / "(" / "{" / implements
        let q = m + 1;
        let last = null;
        while (q < tokens.length && (isId(tokens[q]) || isP(tokens[q], "."))) {
          if (isId(tokens[q], "implements")) break;
          if (isId(tokens[q])) last = tokens[q].v;
          q++;
        }
        parent = last;
      }
    }
    if (m >= tokens.length) continue;
    const close = matchClose(tokens, m);
    const own = ownDispose(tokens, m, close);
    const emitter = own ? null : disposeEmitterCleanup(tokens, m, close);
    classes.push({
      name: nameTok.v,
      line: nameTok.line,
      endLine: tokens[close].line,
      abstract,
      parent,
      disposeLine: own?.line ?? null,
      cleanupLine: emitter?.line ?? null,
    });
  }
  return classes;
}

// ── Suite coverage ───────────────────────────────────────────────────────────

const COVERS_RE = /memory-leak-covers(-subclasses)?\s*:/g;

/** Identifiers from one declaration: comma-separated, parenthesised notes dropped. */
function declaredNames(text) {
  let body = text;
  let prev;
  do {
    prev = body;
    body = body.replace(/\([^()]*\)/g, " ");
  } while (body !== prev);
  const names = [];
  for (const piece of body.split(",")) {
    const id = /^[\s*]*([A-Za-z_$][\w$]*)/.exec(piece);
    if (id) names.push(id[1]);
  }
  return names;
}

/** Names the leak suite exercises, per the rules in the header. */
export function suiteCoverage(src) {
  const { tokens, comments } = lex(src);
  const declared = new Set();
  const declaredSubtrees = new Set();
  for (const { text } of comments) {
    const marks = [...text.matchAll(COVERS_RE)];
    marks.forEach((m, idx) => {
      const end = idx + 1 < marks.length ? marks[idx + 1].index : text.length;
      const names = declaredNames(text.slice(m.index + m[0].length, end));
      for (const name of names) (m[1] ? declaredSubtrees : declared).add(name);
    });
  }

  const valueImports = new Set();
  const typeImports = new Set();
  const identifiers = new Set();
  const caseNames = [];
  for (let k = 0; k < tokens.length; k++) {
    const tk = tokens[k];
    if (isId(tk, "import") && !isP(tokens[k - 1], ".") && !isP(tokens[k + 1], "(")) {
      // import [type] Default, { a, type b as c } | * as ns from "path";
      let m = k + 1;
      let typeOnly = false;
      if (isId(tokens[m], "type") && !isId(tokens[m + 1], "from") && !isP(tokens[m + 1], ",")) {
        typeOnly = true;
        m++;
      }
      for (; m < tokens.length && tokens[m].t !== "str"; m++) {
        const t2 = tokens[m];
        if (isP(t2, "{")) {
          const end = matchClose(tokens, m);
          for (let q = m + 1; q < end; q++) {
            if (!isId(tokens[q])) continue;
            const specType = isId(tokens[q], "type") && isId(tokens[q + 1]);
            if (specType) q++;
            let local = tokens[q].v;
            if (isId(tokens[q + 1], "as")) {
              local = tokens[q + 2]?.v ?? local;
              q += 2;
            }
            (typeOnly || specType ? typeImports : valueImports).add(local);
            // Skip to the next comma.
            while (q + 1 < end && !isP(tokens[q + 1], ",")) q++;
          }
          m = end;
        } else if (isId(t2) && !["from", "as", "type"].includes(t2.v)) {
          (typeOnly ? typeImports : valueImports).add(t2.v);
        }
      }
      k = m; // skip the module path string
      continue;
    }
    if (tk.t === "id") identifiers.add(tk.v);
    if (isId(tk, "name") && isP(tokens[k + 1], ":") && ["str", "tpl"].includes(tokens[k + 2]?.t)) {
      caseNames.push(tokens[k + 2].v);
    }
  }
  return {
    declaredSubtrees,
    covers(name) {
      if (declared.has(name) || valueImports.has(name)) return true;
      if (identifiers.has(name) && !typeImports.has(name)) return true;
      const word = new RegExp(`(^|[^\\w$])${name.replace(/\$/g, "\\$")}([^\\w$]|$)`);
      return caseNames.some((s) => word.test(s));
    },
  };
}

// ── Carve-outs ───────────────────────────────────────────────────────────────

export function memoryLeakCarveOuts(agents) {
  const carved = new Map();
  const section = /^## Compliance carve-outs?\s*$([\s\S]*?)(?=^## |(?![\s\S]))/gm;
  for (const m of agents.matchAll(section)) {
    for (const bullet of m[1].split(/\n(?=\s*[-*] )/)) {
      const lead = /^\s*[-*] +`([^`\n]+)`/.exec(bullet);
      if (lead?.[1].startsWith("memory-leak:")) carved.set(lead[1].slice("memory-leak:".length).trim(), true);
    }
  }
  return [...carved.keys()];
}

// ── Inventory ────────────────────────────────────────────────────────────────

const skipped = (name) => /(ScreenView|Screen|Sim)$/.test(name) || name === "YourModel";

function walkTs(dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) walkTs(p, out);
    else if (entry.endsWith(".ts") && !entry.endsWith(".d.ts")) out.push(p);
  }
  return out;
}

export function inventory(simDir) {
  const sim = resolve(simDir);
  const suitePath = join(sim, "tests", "memory-leak.test.ts");
  if (!existsSync(suitePath)) return { sim: basename(sim), error: "no tests/memory-leak.test.ts" };
  const suite = suiteCoverage(readFileSync(suitePath, "utf8"));
  const agentsPath = join(sim, "AGENTS.md");
  const carved = memoryLeakCarveOuts(existsSync(agentsPath) ? readFileSync(agentsPath, "utf8") : "");

  const classes = [];
  for (const file of walkTs(join(sim, "src")).sort()) {
    for (const c of parseClasses(readFileSync(file, "utf8"))) classes.push({ ...c, file: relative(sim, file) });
  }
  const byName = new Map();
  for (const c of classes) {
    if (!byName.has(c.name)) byName.set(c.name, []);
    byName.get(c.name).push(c);
  }
  // Disposal: own dispose(), or one inherited from a same-sim parent. disposeEmitter /
  // addDisposable cleanup on top of an external base (Node, Panel) is reported, not flagged:
  // the convention inventories classes that define dispose().
  const memo = new Map();
  const disposal = (c, seen = new Set()) => {
    if (memo.has(c)) return memo.get(c);
    let why = null;
    if (c.disposeLine) why = `dispose() at ${c.file}:${c.disposeLine}`;
    else if (c.parent && !seen.has(c.parent)) {
      seen.add(c.parent);
      for (const p of byName.get(c.parent) ?? []) {
        if (disposal(p, seen)) {
          why = `inherits dispose() from ${p.name}`;
          break;
        }
      }
    }
    memo.set(c, why);
    return why;
  };
  const ancestors = (c) => {
    const out = [];
    const seen = new Set([c.name]);
    let parent = c.parent;
    while (parent && !seen.has(parent)) {
      seen.add(parent);
      out.push(parent);
      parent = byName.get(parent)?.[0]?.parent ?? null;
    }
    return out;
  };
  const subclasses = (name, seen = new Set()) => {
    const out = [];
    for (const c of classes) {
      if (c.parent === name && !seen.has(c.name)) {
        seen.add(c.name);
        out.push(c.name, ...subclasses(c.name, seen));
      }
    }
    return out;
  };
  const covered = (c) =>
    suite.covers(c.name) ||
    suite.declaredSubtrees.has(c.name) ||
    ancestors(c).some((a) => suite.declaredSubtrees.has(a)) ||
    (c.abstract && subclasses(c.name).some((s) => suite.covers(s)));

  const flagged = new Map(); // name → reason, before carve-outs
  const cleanupOnly = new Set();
  for (const c of classes) {
    if (skipped(c.name)) continue;
    const why = disposal(c);
    if (!why) {
      if (c.cleanupLine && !covered(c)) cleanupOnly.add(c.name);
      continue;
    }
    if (covered(c)) continue;
    if (!flagged.has(c.name)) flagged.set(c.name, why);
  }
  const missing = [...flagged.keys()].filter((n) => !carved.includes(n)).sort();
  const orphaned = carved.filter((n) => !flagged.has(n)).sort();
  return {
    sim: basename(sim),
    missing: missing.map((name) => ({ name, why: flagged.get(name) })),
    orphaned,
    disposeEmitterOnly: [...cleanupOnly].sort(),
  };
}

// ── CLI ──────────────────────────────────────────────────────────────────────

function main(argv) {
  const json = argv.includes("--json");
  const dirs = argv.filter((a) => a !== "--json");
  if (dirs.length === 0 || dirs.some((d) => d.startsWith("--"))) {
    console.error("Usage: check-memory-leak-inventory.mjs [--json] <SimDir> [<SimDir> …]");
    return 2;
  }
  const results = dirs.map(inventory);
  if (json) {
    console.log(JSON.stringify(results, null, 2));
  } else {
    for (const r of results) {
      if (r.error) console.log(`${r.sim}: ${r.error}`);
      else console.log(`${r.sim}: ${r.missing.length ? r.missing.map((m) => m.name).join(", ") : "ok"}`);
      if (r.orphaned?.length) console.log(`${r.sim}: orphaned memory-leak carve-outs: ${r.orphaned.join(", ")}`);
    }
  }
  return results.some((r) => r.error || r.missing.length) ? 1 : 0;
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith("check-memory-leak-inventory.mjs")) {
  process.exitCode = main(process.argv.slice(2));
}
