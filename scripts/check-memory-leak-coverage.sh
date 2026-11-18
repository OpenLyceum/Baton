#!/usr/bin/env bash
# Inventory dispose() overrides vs tests/memory-leak.test.ts for one sim (or --all).
# Exit 1 if any unlisted dispose() class remains (after carve-outs). Used for local
# sweeps; check-repo-compliance.sh reports the same gap as WARN. The parsing lives in
# check-memory-leak-inventory.mjs (class bodies + suite bindings, not substrings);
# orphaned `memory-leak:<Class>` carve-outs print as an extra line and do not fail.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$BATON_ROOT/.." && pwd)"

usage() {
  echo "Usage: $0 <SimDir> | --all" >&2
  exit 2
}

check_one() {
  node "$SCRIPT_DIR/check-memory-leak-inventory.mjs" "$1"
}

if [[ "${1:-}" == "--all" ]]; then
  fail=0
  for pkg in "$ROOT"/*/package.json; do
    sim="$(dirname "$pkg")"
    name="$(basename "$sim")"
    case "$name" in Baton|Almanach|Baseline) continue ;; esac
    [[ -f "$sim/tests/memory-leak.test.ts" ]] || continue
    check_one "$sim" || fail=1
  done
  exit "$fail"
fi

[[ $# -eq 1 ]] || usage
check_one "$1"
