#!/usr/bin/env node
/**
 * heap-snapshot-diff.mjs
 *
 * Compares two V8 heap snapshots (e.g. after 3 and 8 headless soak rounds) and lists the
 * constructors whose retained count and size grew most. Steady growth of a scenery/axon
 * class (Text, Path, GridNode, BooleanProperty …) marks a leak; growth only in code:,
 * TrustedByteArray, module strings and plain arrays is JIT warm-up.
 *
 * Usage:
 *   node --max-old-space-size=5500 scripts/heap-snapshot-diff.mjs <before.heapsnapshot> <after.heapsnapshot> [rows=45]
 *
 * Taking the snapshots: see skills/scenerystack-disposal/SKILL.md → "Finding a leak from a heap climb".
 */
import { readFileSync } from "node:fs";

function load(path) {
  const snap = JSON.parse(readFileSync(path, "utf8"));
  const fields = snap.snapshot.meta.node_fields;
  const types = snap.snapshot.meta.node_types[0];
  const n = fields.length;
  const ti = fields.indexOf("type");
  const ni = fields.indexOf("name");
  const si = fields.indexOf("self_size");
  const out = new Map();
  for (let i = 0; i < snap.nodes.length; i += n) {
    const key = `${types[snap.nodes[i + ti]]}:${snap.strings[snap.nodes[i + ni]].slice(0, 60)}`;
    const entry = out.get(key) ?? [0, 0];
    entry[0]++;
    entry[1] += snap.nodes[i + si];
    out.set(key, entry);
  }
  return out;
}

const [, , beforePath, afterPath, rowsArg] = process.argv;
if (!beforePath || !afterPath) {
  console.error("usage: heap-snapshot-diff.mjs <before.heapsnapshot> <after.heapsnapshot> [rows]");
  process.exit(2);
}
const before = load(beforePath);
const after = load(afterPath);
const rows = [...after].map(([key, [count, size]]) => [
  key,
  count - (before.get(key)?.[0] ?? 0),
  size - (before.get(key)?.[1] ?? 0),
]);
rows.sort((a, b) => b[2] - a[2]);
for (const [key, count, size] of rows.slice(0, Number(rowsArg ?? 45))) {
  console.log(`${(size / 1048576).toFixed(2).padStart(8)} MiB ${String(count).padStart(9)}  ${key}`);
}
