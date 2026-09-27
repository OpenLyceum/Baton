#!/usr/bin/env bash
# refresh-screenshots.sh — end-to-end screenshot + landing-page refresh.
#
# Chains the three screenshot-pipeline scripts so a single command regenerates
# every sim's capture AND the Baton landing-page assets that depend on them:
#
#   1. generate-screenshots.sh  — capture <sim>/assets/screenshot.png (builds dist/ if needed)
#   2. make-thumbnails.mjs      — copy sibling shots → screenshots/<sim>.png + docs/assets/<sim>.webp
#   3. generate-pages-index.sh  — regenerate docs/index.html from structure/repos.json
#
# Running this is the way to keep the org Pages landing page in sync with
# the sim captures. After it finishes, commit the changed screenshot.png in each
# sim repo and the screenshots/ + docs/ changes in Baton — the script prints the
# exact commands at the end.
#
# For a passive safety net, .github/workflows/refresh-screenshots.yml still runs
# weekly (Monday 08:00 UTC) against live Pages and opens a PR; and pushing
# screenshots/** to main auto-runs optimize-assets.yml, while docs/** changes
# auto-deploy via pages.yml.
#
# Usage:
#   scripts/refresh-screenshots.sh [options] [SIM ...]
#   npm run refresh -- [options] [SIM ...]
#
# Options (forwarded to generate-screenshots.sh):
#   --build         Force `npm run build` even if dist/ already exists.
#   --screen N      Screen index to capture (default: 1).
#   --width N       Capture viewport width (default: 1154).
#   --height N      Capture viewport height (default: 753).
#   -h, --help      Show this help.
#
# Positional SIM args limit the run to the named sims (forwarded to both the
# capture and thumbnail steps); omit to do all active sims.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CAPTURE_ARGS=()
SIMS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) CAPTURE_ARGS+=("$1"); shift ;;
    --screen|--width|--height)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
      CAPTURE_ARGS+=("$1" "$2"); shift 2 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) SIMS+=("$1"); CAPTURE_ARGS+=("$1"); shift ;;
  esac
done

# 1. Capture each sim's screenshot into <sim>/assets/screenshot.png.
echo "── 1/3  capture sim screenshots ─────────────────────"
if bash "$SCRIPT_DIR/generate-screenshots.sh" "${CAPTURE_ARGS[@]}"; then
  capture_ok=1
else
  capture_ok=0
  echo "warning: capture step reported one or more failures (see above);" >&2
  echo "         continuing with thumbnails/index for the sims that succeeded." >&2
fi

# 2. Refresh Baton ground-truth PNGs + WebP thumbnails from the sibling sims.
echo
echo "── 2/3  refresh Baton screenshots/ + docs/assets/ ───"
node "$SCRIPT_DIR/make-thumbnails.mjs" "${SIMS[@]}"

# 3. Regenerate the landing-page index from the catalog.
echo
echo "── 3/3  regenerate docs/index.html ──────────────────"
bash "$SCRIPT_DIR/generate-pages-index.sh"

# ── what to commit ────────────────────────────────────────────────────────────
WORKSPACE="${FLEET_WORKSPACE:-${OPENPHYSICS_WORKSPACE:-$(cd "$REPO_ROOT/.." && pwd)}}"

if [[ ${#SIMS[@]} -gt 0 ]]; then
  candidates=("${SIMS[@]}")
else
  candidates=()
  while IFS= read -r s; do candidates+=("$s"); done \
    < <("$SCRIPT_DIR/parse-repos.sh" names --simulation --status active 2>/dev/null || true)
fi

changed_sims=()
for sim in "${candidates[@]}"; do
  d="$WORKSPACE/$sim"
  [[ -d "$d" ]] || continue
  if [[ -n "$(git -C "$d" status --porcelain -- assets/screenshot.png 2>/dev/null)" ]]; then
    changed_sims+=("$sim")
    # Keep the PWA install screenshots in step with the new capture (template
    # generate-icons.ts --screenshots-from-assets); skipped for sims on an older
    # generator that lacks the flag.
    if grep -q -- '--screenshots-from-assets' "$d/scripts/generate-icons.ts" 2>/dev/null; then
      ( cd "$d" && npm run icons -- --screenshots-from-assets >/dev/null ) \
        || echo "warning: $sim: could not rebuild public/screenshots from the capture" >&2
    fi
  fi
done

echo
echo "── next steps ──────────────────────────────────────"
if [[ ${#changed_sims[@]} -gt 0 ]]; then
  echo "Changed screenshot.png — commit in each sim repo (and push):"
  for sim in "${changed_sims[@]}"; do
    printf '  ( cd "%s/%s" && git add assets/screenshot.png public/screenshots \\\n        && git commit -m "chore: refresh the landing-page and PWA screenshots" && git push )\n' "$WORKSPACE" "$sim"
  done
else
  echo "No sim-repo screenshot.png changes detected."
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- screenshots docs 2>/dev/null || true)" ]]; then
  echo
  echo "Baton landing-page assets changed — committing pushes the Pages deploy:"
  printf '  ( cd "%s" && git add screenshots docs \\\n        && git commit -m "chore: refresh Pages screenshot thumbnails" && git push )\n' "$REPO_ROOT"
  echo "  (pushing screenshots/** auto-runs optimize-assets.yml; docs/** auto-runs pages.yml)"
else
  echo
  echo "No Baton screenshots/ or docs/ changes detected."
fi

[[ $capture_ok -eq 1 ]]
