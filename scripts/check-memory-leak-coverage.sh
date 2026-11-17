#!/usr/bin/env bash
# Inventory dispose() overrides vs tests/memory-leak.test.ts for one sim (or --all).
# Exit 1 if any unlisted dispose() class remains (after carve-outs). Used for local
# sweeps; check-repo-compliance.sh reports the same gap as WARN.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$BATON_ROOT/.." && pwd)"

usage() {
  echo "Usage: $0 <SimDir> | --all" >&2
  exit 2
}

check_one() {
  local dir="$1"
  python3 - "$dir" <<'PY'
import re, sys
from pathlib import Path
sim = Path(sys.argv[1])
suite_path = sim / "tests" / "memory-leak.test.ts"
if not suite_path.exists():
    print(f"{sim.name}: no tests/memory-leak.test.ts")
    sys.exit(1)
suite = suite_path.read_text()
agents = (sim / "AGENTS.md").read_text() if (sim / "AGENTS.md").exists() else ""
carved = set()
for m in re.finditer(r"^## Compliance carve-outs?\s*$([\s\S]*?)(?=^## |\Z)", agents, re.M):
    for bullet in re.split(r"\n(?=\s*[-*] )", m.group(1)):
        lead = re.match(r"\s*[-*] +`([^`\n]+)`", bullet)
        if lead and lead.group(1).startswith("memory-leak:"):
            carved.add(lead.group(1).split(":", 1)[1].strip())

class_re = re.compile(r"(?m)^\s*(?:export\s+)?(?:abstract\s+)?class\s+(\w+)\b")
dispose_re = re.compile(
    r"(?:public|protected|private)\s+(?:override\s+)?dispose\s*\([^;]*\)\s*(?::\s*[^{]+)?\s*\{"
    r"|override\s+dispose\s*\([^;]*\)\s*(?::\s*[^{]+)?\s*\{"
)
missing = []
for path in (sim / "src").rglob("*.ts"):
    if path.name.endswith(".d.ts"):
        continue
    src = path.read_text(errors="ignore")
    for cm in class_re.finditer(src):
        name = cm.group(1)
        if name.endswith(("ScreenView", "Screen", "Sim")) or name == "YourModel":
            continue
        body = src[cm.end() : cm.end() + 12000]
        if not dispose_re.search(body):
            continue
        if name in suite or name in carved:
            continue
        if re.search(rf'name:\s*["\'][^"\']*{re.escape(name)}[^"\']*["\']', suite):
            continue
        missing.append(name)
uniq = sorted(set(missing))
if uniq:
    print(f"{sim.name}: {', '.join(uniq)}")
    sys.exit(1)
print(f"{sim.name}: ok")
sys.exit(0)
PY
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
