#!/usr/bin/env node
/**
 * heap-snapshot-retainers.mjs
 *
 * Prints what keeps objects alive: the shortest strong path from the GC roots to the
 * newest instances (highest node id) of a constructor in a V8 heap snapshot. The
 * long-lived object near the top of each chain (a LocalizedStringProperty, a Colors
 * Property, stepTimer, a model Property) is the leak's root. Chains through
 * ScreenView._view are nodes still in the scene graph, not leaks.
 *
 * Usage:
 *   node --max-old-space-size=5500 scripts/heap-snapshot-retainers.mjs <snapshot> <ConstructorName> [howMany=4]
 *
 * Weak and shortcut edges are skipped. Chains are printed leaf first, root last.
 */
import { readFileSync } from "node:fs";

const [, , file, target, howManyArg] = process.argv;
if (!file || !target) {
  console.error("usage: heap-snapshot-retainers.mjs <snapshot> <ConstructorName> [howMany]");
  process.exit(2);
}
const howMany = Number(howManyArg ?? 4);
const snap = JSON.parse(readFileSync(file, "utf8"));
const meta = snap.snapshot.meta;
const NF = meta.node_fields.length;
const EF = meta.edge_fields.length;
const nType = meta.node_fields.indexOf("type");
const nName = meta.node_fields.indexOf("name");
const nId = meta.node_fields.indexOf("id");
const nEdges = meta.node_fields.indexOf("edge_count");
const eType = meta.edge_fields.indexOf("type");
const eName = meta.edge_fields.indexOf("name_or_index");
const eTo = meta.edge_fields.indexOf("to_node");
const nodeTypes = meta.node_types[0];
const edgeTypes = meta.edge_types[0];
const { nodes, edges, strings } = snap;
const count = nodes.length / NF;

const firstEdge = new Uint32Array(count + 1);
for (let i = 0, e = 0; i < count; i++) {
  firstEdge[i] = e;
  e += nodes[i * NF + nEdges] * EF;
  firstEdge[i + 1] = e;
}

// Breadth-first from the synthetic root (node 0): parent[] then gives shortest paths.
const parent = new Int32Array(count).fill(-1);
const parentEdge = new Int32Array(count).fill(-1);
const queue = new Uint32Array(count);
let head = 0;
let tail = 0;
parent[0] = 0;
queue[tail++] = 0;
while (head < tail) {
  const node = queue[head++];
  for (let e = firstEdge[node]; e < firstEdge[node + 1]; e += EF) {
    const type = edgeTypes[edges[e + eType]];
    if (type === "weak" || type === "shortcut") {
      continue;
    }
    const to = edges[e + eTo] / NF;
    if (parent[to] === -1) {
      parent[to] = node;
      parentEdge[to] = e;
      queue[tail++] = to;
    }
  }
}

const label = (n) => `${nodeTypes[nodes[n * NF + nType]]}:${strings[nodes[n * NF + nName]].slice(0, 50)}`;
const edgeLabel = (e) => {
  const type = edgeTypes[edges[e + eType]];
  const value = edges[e + eName];
  return type === "element" || type === "hidden" ? `[${value}]` : String(strings[value]);
};

const hits = [];
for (let i = 0; i < count; i++) {
  if (strings[nodes[i * NF + nName]] === target && nodeTypes[nodes[i * NF + nType]] === "object") {
    hits.push(i);
  }
}
hits.sort((a, b) => nodes[b * NF + nId] - nodes[a * NF + nId]);
console.log(`${hits.length} × ${target}; newest ${Math.min(howMany, hits.length)}:`);
for (const hit of hits.slice(0, howMany)) {
  if (parent[hit] === -1) {
    console.log("---\n  (unreachable: garbage awaiting collection)");
    continue;
  }
  const chain = [];
  for (let n = hit; n !== 0; n = parent[n]) {
    chain.push(`${label(n)} ←.${edgeLabel(parentEdge[n])}`);
  }
  console.log(`---\n  ${chain.slice(0, 40).join("\n  ")}`);
}
