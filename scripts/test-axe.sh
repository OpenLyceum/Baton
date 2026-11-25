#!/usr/bin/env bash
# Run the shared axe pilot against a local simulation with dependencies installed.
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
  echo "Usage: $0 SIM_DIRECTORY [REPORT_DIRECTORY]" >&2
  exit 2
fi

baton_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sim_dir="$(cd "$1" && pwd)"
report_dir="$(node -p 'require("node:path").resolve(process.argv[1])' "${2:-"$sim_dir/test-results/axe"}")"
axe_module="$(cd "$baton_dir" && node --input-type=module -e 'console.log(import.meta.resolve("@axe-core/playwright"))')"

# Put the spec beside the sim's tests so it resolves the same Playwright module as
# the sim's config and uses that config's web server, browser and fixtures.
test_dir="$(mktemp -d "$sim_dir/tests/axe-pilot.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
cp "$baton_dir/scripts/axe-smoke.spec.ts" "$test_dir/smoke.spec.ts"

cd "$sim_dir"
AXE_PLAYWRIGHT_MODULE="$axe_module" PLAYWRIGHT_HTML_OUTPUT_DIR="$report_dir/html" \
  npx --no-install playwright test --project=chromium --output="$report_dir/results" "${test_dir##*/}/smoke.spec.ts"
