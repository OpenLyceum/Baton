#!/usr/bin/env bash
# Create a new simulation from SceneryStackTemplate.
#
# Uses the GitHub template repository (Use this template) when creating a remote,
# then runs npm rename + scaffold-screens so single- or multi-screen sims share
# one entrypoint. Optional --onboard finishes fleet landing-page assets and the
# workspace README; --pr opens follow-up PRs in Baton / the superproject.
#
# Examples:
#   scripts/create-sim.sh --repo Friction --name "Friction" --topics "friction,forces" --onboard --pr
#   scripts/create-sim.sh --repo Friction --name "Friction" --screens Intro,Lab --topics "friction" --shared-model
#   scripts/create-sim.sh --repo Friction --name "Friction" --local-only --topics "friction" --onboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/repos.sh
source "$SCRIPT_DIR/lib/repos.sh"

ORG="${FLEET_ORG:-${OPENPHYSICS_ORG:-$(repos_org)}}"
TEMPLATE_REPO="${TEMPLATE_REPO:-$ORG/SceneryStackTemplate}"
# The superproject repo is named after the org by convention.
SUPERPROJECT="${FLEET_SUPERPROJECT:-$ORG}"
PAGES_BASE="$(repos_pages_base)"
WORKSPACE="$(repos_workspace_root)"
BATON_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO=""
SIM_ID=""
SIM_NAME=""
SCREENS=""
TOPICS=""
GITHUB_TOPICS=""
TARGET_PATH=""
LOCAL_ONLY=0
NO_PUSH=0
CATALOG=0
ONBOARD=0
OPEN_PR=0
SHARED_MODEL=0
EXISTING=0
DESCRIPTION=""
SHORT_DESCRIPTION=""

usage() {
  cat <<'EOF'
Usage: create-sim.sh --repo <PascalCase> --name "<Display Name>" [options]

Bootstrap a new SceneryStack simulation from SceneryStackTemplate.

Required:
  --repo NAME          GitHub / folder name (PascalCase), e.g. Friction
  --name "TITLE"       Display title, e.g. "Friction" or "Wave Interference"

Options:
  --id <kebab>         Package id (default: kebab-case of --repo)
  --screens LIST       Comma-separated screen titles, or kebab:Title pairs.
                       Default: one screen named after --name.
                       Catalog stores {id, title} (id from kebab: or slug of title).
  --topics LIST        Comma-separated physicsTopics (required with --catalog/--onboard)
  --github-topics LIST Optional extra GitHub topics (kebab-case), e.g. game,pwa
  --shared-model       Scaffold src/common/model/SharedModel.ts; each screen composes it
  --path DIR           Checkout path (default: $FLEET_WORKSPACE/<repo>)
  --description TEXT   Full catalog / Pages card description
  --short-description TEXT  Optional GitHub About blurb (≤350 chars)
  --local-only         Copy local SceneryStackTemplate; do not create a GitHub repo
  --no-push            Do not git push the sim (default: no auto-push unless --pr)
  --catalog            Insert a repos.json entry in Baton (no commit)
  --onboard            Full fleet onboarding: catalog + screenshot + WebP + Pages
                       index + GitHub baseline + superproject README Layout row
                       (implies --catalog)
  --existing           Adopt a repo already on GitHub (cloned if absent locally)
                       instead of creating it from the template. Skip rename /
                       scaffold / install. Requires --catalog or --onboard.
  --pr                 After --onboard, commit/push and open PRs in Baton and
                       the superproject (and push the sim bootstrap if not --local-only)
  -h, --help           Show this help

Requires: gh (unless --local-only), jq, npm, Node 24+.
  --onboard also needs Baton npm deps + Playwright Chromium for screenshots.
EOF
}

pascal_to_kebab() {
  # Friction → friction; WaveInterference → wave-interference
  sed -E 's/([a-z0-9])([A-Z])/\1-\2/g; s/([A-Z]+)([A-Z][a-z])/\1-\2/g' <<<"$1" | tr '[:upper:]' '[:lower:]'
}

insert_catalog_entry() {
  local catalog_path="$1"
  local entry="$2"
  if jq -e --arg name "$REPO" '.repos[] | select(.name == $name)' "$catalog_path" >/dev/null; then
    echo "  catalog: $REPO already present — leaving row unchanged"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  jq --argjson entry "$entry" \
    '.repos = ((.repos + [$entry]) | sort_by(.name | ascii_downcase))' \
    "$catalog_path" >"$tmp"
  mv "$tmp" "$catalog_path"
  echo "  catalog: inserted $REPO into structure/repos.json"
}

update_workspace_readme() {
  local readme="$WORKSPACE/README.md"
  if [[ ! -f "$readme" ]]; then
    echo "warning: superproject README not found at $readme — skip Layout update" >&2
    return 0
  fi
  python3 - "$readme" "$REPO" <<'PY'
import re, sys
path, repo = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
# Simulation row: | `A`, `B`, ... | simulation | ...
pat = re.compile(
    r"(^\| )(`[^`]+`(?:, `[^`]+`)*)( \| simulation \|)",
    re.MULTILINE,
)
m = pat.search(text)
if not m:
    sys.stderr.write("warning: could not find simulation Layout row in README\n")
    sys.exit(0)
names = re.findall(r"`([^`]+)`", m.group(2))
if repo in names:
    print(f"  readme: {repo} already listed")
    sys.exit(0)
names.append(repo)
names.sort(key=str.lower)
new_list = ", ".join(f"`{n}`" for n in names)
text = text[: m.start(2)] + new_list + text[m.end(2) :]
open(path, "w", encoding="utf-8").write(text)
print(f"  readme: inserted `{repo}` into superproject README Layout (alphabetical)")
PY
}

ensure_baton_npm() {
  if [[ ! -d "$BATON_ROOT/node_modules" ]]; then
    echo "npm install (Baton)..."
    (cd "$BATON_ROOT" && npm install)
  fi
}

run_onboard_assets() {
  echo ""
  echo "Onboarding assets (screenshot → WebP → Pages)..."
  ensure_baton_npm
  if ! (cd "$BATON_ROOT" && npx playwright install chromium >/dev/null 2>&1); then
    echo "warning: playwright chromium install failed; screenshot may fail" >&2
  fi
  "$SCRIPT_DIR/generate-screenshots.sh" --build "$REPO"
  (cd "$BATON_ROOT" && npm run thumbnails -- "$REPO")
  (cd "$BATON_ROOT" && npm run pages)
  echo "  assets: screenshot + WebP + docs/index.html ready"
}

run_onboard_github() {
  # The GitHub-side baseline: repo feature flags + security, description +
  # homepage, Dependabot config, and the Claude Code plugin settings. Without
  # this step a freshly "onboarded" sim still carries GitHub's defaults (wiki
  # and Projects on, no secret scanning, no Dependabot) — the exact drift the
  # settings baseline exists to prevent. Live API calls + files in the sim tree.
  echo ""
  echo "Applying GitHub baseline (settings + metadata + dependabot + claude)..."
  "$SCRIPT_DIR/sync-github-settings.sh" --apply --repo "$REPO" \
    || echo "  warning: settings sync reported failures (see above)" >&2
  "$SCRIPT_DIR/sync-github-metadata.sh" --repo "$REPO" \
    || echo "  warning: metadata sync failed" >&2
  # dependabot + claude write into the sim checkout; they become part of the
  # bootstrap commit when --pr runs.
  "$SCRIPT_DIR/sync-dependabot.sh" "$REPO" \
    || echo "  warning: dependabot sync failed" >&2
  "$SCRIPT_DIR/sync-claude-settings.sh" "$REPO" \
    || echo "  warning: claude settings sync failed" >&2
}

open_onboard_prs() {
  local branch="add/${REPO}"
  local baton_pr=""
  local op_pr=""

  # ── Sim repo ──────────────────────────────────────────────────────────────
  if [[ "$LOCAL_ONLY" -eq 0 ]]; then
    echo ""
    echo "Committing sim bootstrap..."
    (
      cd "$TARGET_PATH"
      git add -A
      if git diff --cached --quiet; then
        echo "  sim: nothing to commit"
      else
        if [[ "$EXISTING" -eq 1 ]]; then
          git commit -m "$(cat <<EOF
chore: add fleet onboarding files

Dependabot config and Claude Code plugin settings from the canonical templates.
EOF
)"
        else
          git commit -m "$(cat <<EOF
chore: bootstrap from SceneryStackTemplate

Rename, scaffold screens, and capture the landing-page screenshot.
EOF
)"
        fi
      fi
      if [[ "$NO_PUSH" -eq 0 ]]; then
        git push -u origin HEAD
      fi
    )
  fi

  # ── Baton PR ──────────────────────────────────────────────────────────────
  echo ""
  echo "Opening Baton onboarding PR..."
  (
    cd "$BATON_ROOT"
    git fetch origin main >/dev/null 2>&1 || true
    git checkout -B "$branch" origin/main 2>/dev/null || git checkout -B "$branch"
    git add structure/repos.json "screenshots/${REPO}.png" "docs/assets/${REPO}.webp" docs/index.html 2>/dev/null || true
    # Also stage if screenshots path differs
    git add structure/repos.json screenshots docs 2>/dev/null || true
    if git diff --cached --quiet; then
      echo "  baton: nothing to commit (already on branch?)"
    else
      git commit -m "$(cat <<EOF
chore: onboard ${REPO} to the fleet catalog

Add catalog row, screenshot, WebP card, and regenerate the Pages index.
EOF
)"
    fi
    if [[ "$NO_PUSH" -eq 0 ]]; then
      git push -u origin "$branch"
      baton_pr="$(gh pr create --repo "$ORG/Baton" --base main --head "$branch" \
        --title "chore: onboard ${REPO}" \
        --body "$(cat <<EOF
## Summary
- Add \`${REPO}\` to \`structure/repos.json\`
- Landing-page screenshot + WebP thumbnail
- Regenerate \`docs/index.html\`

## Test plan
- [ ] Card appears under New/original on local \`docs/index.html\`
- [ ] Card links to ${PAGES_BASE}/${REPO}/
- [ ] \`scripts/parse-repos.sh names --simulation | grep ${REPO}\`

EOF
)" 2>/dev/null || true)"
      if [[ -n "$baton_pr" ]]; then
        echo "  baton PR: $baton_pr"
      else
        echo "  baton: branch pushed ($branch); create/update the PR manually if needed"
      fi
    fi
  )

  # ── Superproject PR ───────────────────────────────────────────────────────
  if [[ -d "$WORKSPACE/.git" ]]; then
    echo ""
    echo "Opening superproject README PR..."
    (
      cd "$WORKSPACE"
      git fetch origin main >/dev/null 2>&1 || true
      op_branch="docs/add-${REPO}"
      git checkout -B "$op_branch" origin/main 2>/dev/null || git checkout -B "$op_branch"
      git add README.md
      if git diff --cached --quiet; then
        echo "  superproject: nothing to commit"
      else
        git commit -m "$(cat <<EOF
docs: add ${REPO} to the Layout simulation list

EOF
)"
      fi
      if [[ "$NO_PUSH" -eq 0 ]]; then
        git push -u origin "$op_branch"
        op_pr="$(gh pr create --repo "$ORG/$SUPERPROJECT" --base main --head "$op_branch" \
          --title "docs: add ${REPO} to Layout" \
          --body "$(cat <<EOF
## Summary
- Add \`${REPO}\` to the simulation row in \`README.md\` \`## Layout\` (alphabetical)

## Test plan
- [ ] Name appears in the Layout table in alphabetical order

EOF
)" 2>/dev/null || true)"
        if [[ -n "$op_pr" ]]; then
          echo "  superproject PR: $op_pr"
        else
          echo "  superproject: branch pushed ($op_branch); create/update the PR manually if needed"
        fi
      fi
    )
  else
    echo "warning: superproject is not a git checkout — skip README PR" >&2
  fi
}

# ── Executable section ────────────────────────────────────────────────────────
# Everything above is definitions only, so tests can source this file to exercise
# the helpers (pascal_to_kebab, insert_catalog_entry, …) without bootstrapping a
# simulation. Running the script normally falls straight through.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:?Missing value for --repo}"
      shift 2
      ;;
    --id)
      SIM_ID="${2:?Missing value for --id}"
      shift 2
      ;;
    --name)
      SIM_NAME="${2:?Missing value for --name}"
      shift 2
      ;;
    --screens)
      SCREENS="${2:?Missing value for --screens}"
      shift 2
      ;;
    --topics)
      TOPICS="${2:?Missing value for --topics}"
      shift 2
      ;;
    --github-topics)
      GITHUB_TOPICS="${2:?Missing value for --github-topics}"
      shift 2
      ;;
    --path)
      TARGET_PATH="${2:?Missing value for --path}"
      shift 2
      ;;
    --description)
      DESCRIPTION="${2:?Missing value for --description}"
      shift 2
      ;;
    --short-description)
      SHORT_DESCRIPTION="${2:?Missing value for --short-description}"
      shift 2
      ;;
    --local-only)
      LOCAL_ONLY=1
      shift
      ;;
    --no-push)
      NO_PUSH=1
      shift
      ;;
    --catalog)
      CATALOG=1
      shift
      ;;
    --onboard)
      ONBOARD=1
      CATALOG=1
      shift
      ;;
    --pr)
      OPEN_PR=1
      shift
      ;;
    --shared-model)
      SHARED_MODEL=1
      shift
      ;;
    --existing)
      EXISTING=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$REPO" || -z "$SIM_NAME" ]]; then
  echo "error: --repo and --name are required" >&2
  usage >&2
  exit 2
fi

if [[ "$OPEN_PR" -eq 1 && "$ONBOARD" -eq 0 ]]; then
  echo "error: --pr requires --onboard" >&2
  exit 2
fi

if [[ "$EXISTING" -eq 1 && "$CATALOG" -eq 0 ]]; then
  echo "error: --existing needs --catalog or --onboard (nothing to adopt otherwise)" >&2
  exit 2
fi

if [[ -z "$SIM_ID" ]]; then
  SIM_ID="$(pascal_to_kebab "$REPO")"
fi

if [[ -z "$TARGET_PATH" ]]; then
  TARGET_PATH="$WORKSPACE/$REPO"
fi

if [[ "$EXISTING" -eq 0 && -e "$TARGET_PATH" ]]; then
  echo "error: path already exists: $TARGET_PATH" >&2
  exit 1
fi

if [[ -z "$DESCRIPTION" ]]; then
  DESCRIPTION="A SceneryStack simulation: ${SIM_NAME}."
fi

if [[ "$LOCAL_ONLY" -eq 0 ]] && ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI is required (or pass --local-only)" >&2
  exit 1
fi

repos_require_jq

SCREEN_ARGS=()
if [[ -n "$SCREENS" ]]; then
  SCREEN_ARGS=(--screens "$SCREENS")
fi
if [[ "$SHARED_MODEL" -eq 1 ]]; then
  SCREEN_ARGS+=(--shared-model)
fi

# Structured screen list for catalog: [{id, title}, ...]
catalog_screens_json='[]'
if [[ -n "$SCREENS" ]]; then
  catalog_screens_json="$(
    python3 - "$SCREENS" <<'PY'
import json, re, sys

def kebab(s: str) -> str:
    s = s.strip().lower().replace("&", " and ")
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s

raw = sys.argv[1]
parts, cur, q = [], "", False
for ch in raw:
    if ch == '"':
        q = not q
        continue
    if ch == "," and not q:
        if cur.strip():
            parts.append(cur.strip())
        cur = ""
        continue
    cur += ch
if cur.strip():
    parts.append(cur.strip())

screens = []
for part in parts:
    if ":" in part:
        sid, title = part.split(":", 1)
        sid, title = sid.strip(), title.strip()
    else:
        title = part.strip()
        sid = kebab(title)
    if not sid or not title:
        raise SystemExit(f"invalid --screens entry: {part!r}")
    screens.append({"id": sid, "title": title})
print(json.dumps(screens))
PY
  )"
else
  catalog_screens_json="$(
    python3 - "$SIM_NAME" <<'PY'
import json, re, sys
title = sys.argv[1]
sid = re.sub(r"[^a-z0-9]+", "-", title.strip().lower()).strip("-")
print(json.dumps([{"id": sid, "title": title}]))
PY
  )"
fi

catalog_topics_json='[]'
if [[ -n "$TOPICS" ]]; then
  catalog_topics_json="$(
    python3 - "$TOPICS" <<'PY'
import json, sys
parts = [p.strip() for p in sys.argv[1].split(",") if p.strip()]
if not parts:
    raise SystemExit("--topics must list at least one topic")
print(json.dumps(parts))
PY
  )"
fi

catalog_github_topics_json='[]'
if [[ -n "$GITHUB_TOPICS" ]]; then
  catalog_github_topics_json="$(
    python3 - "$GITHUB_TOPICS" <<'PY'
import json, re, sys
parts = []
for p in sys.argv[1].split(","):
    t = p.strip().lower()
    if not t:
        continue
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", t):
        raise SystemExit(f"invalid --github-topics entry (want kebab-case): {p!r}")
    parts.append(t)
print(json.dumps(parts))
PY
  )"
fi

if [[ "$CATALOG" -eq 1 || "$ONBOARD" -eq 1 ]]; then
  if [[ "$catalog_topics_json" == "[]" ]]; then
    echo "error: --topics is required when using --catalog or --onboard" >&2
    echo "  example: --topics \"optics,interference,coherence\"" >&2
    exit 1
  fi
fi

if [[ -n "$SHORT_DESCRIPTION" && ${#SHORT_DESCRIPTION} -gt 350 ]]; then
  echo "error: --short-description must be ≤350 characters (got ${#SHORT_DESCRIPTION})" >&2
  exit 1
fi

echo "Creating simulation $REPO"
echo "  id:       $SIM_ID"
echo "  name:     $SIM_NAME"
echo "  path:     $TARGET_PATH"
echo "  screens:  ${SCREENS:-"(default: $SIM_NAME)"}"
echo "  topics:   ${TOPICS:-"(none)"}"
echo "  shared:   $([[ "$SHARED_MODEL" -eq 1 ]] && echo yes || echo no)"
echo "  onboard:  $([[ "$ONBOARD" -eq 1 ]] && echo yes || echo no)"
echo "  existing: $([[ "$EXISTING" -eq 1 ]] && echo "yes (adopt already-on-GitHub repo)" || echo "no (create from template)")"
echo "  template: $TEMPLATE_REPO"
echo ""

PARENT="$(dirname "$TARGET_PATH")"
mkdir -p "$PARENT"

if [[ "$EXISTING" -eq 1 ]]; then
  # Adopt a repo that already lives on GitHub (created outside this script).
  # Skip the template / rename / scaffold / install dance — just make sure it is
  # checked out, then fall through to catalog + assets + GitHub baseline.
  if [[ ! -d "$TARGET_PATH/.git" ]]; then
    if [[ "$LOCAL_ONLY" -eq 1 ]]; then
      echo "error: --existing --local-only needs the checkout to already exist at $TARGET_PATH" >&2
      exit 1
    fi
    echo "Cloning existing repo $ORG/$REPO → $TARGET_PATH..."
    git clone "git@github.com:${ORG}/${REPO}.git" "$TARGET_PATH" 2>/dev/null \
      || git clone "https://github.com/${ORG}/${REPO}.git" "$TARGET_PATH"
  else
    echo "Adopting existing checkout: $TARGET_PATH"
  fi
else
if [[ "$LOCAL_ONLY" -eq 1 ]]; then
  SRC_TEMPLATE="$WORKSPACE/SceneryStackTemplate"
  if [[ ! -d "$SRC_TEMPLATE" ]]; then
    echo "error: local template not found at $SRC_TEMPLATE" >&2
    echo "  clone it first, or omit --local-only to use gh --template" >&2
    exit 1
  fi
  echo "Copying local template → $TARGET_PATH"
  rsync -a \
    --exclude node_modules \
    --exclude dist \
    --exclude .git \
    --exclude .cache \
    --exclude .vite \
    "$SRC_TEMPLATE/" "$TARGET_PATH/"
  git -C "$TARGET_PATH" init -b main
  git -C "$TARGET_PATH" add -A
  git -C "$TARGET_PATH" commit -m "chore: copy SceneryStackTemplate" >/dev/null
else
  echo "Creating GitHub repo from template..."
  (
    cd "$PARENT"
    gh repo create "$ORG/$REPO" \
      --public \
      --template "$TEMPLATE_REPO" \
      --description "$DESCRIPTION" \
      --homepage "${PAGES_BASE}/${REPO}" \
      --clone
  )
  if [[ "$(basename "$TARGET_PATH")" != "$REPO" ]]; then
    mv "$PARENT/$REPO" "$TARGET_PATH"
  fi
fi

cd "$TARGET_PATH"

echo ""
echo "npm install..."
npm install

echo ""
echo "npm run rename..."
npm run rename -- --id "$SIM_ID" --name "$SIM_NAME"

echo ""
echo "npm run scaffold-screens..."
npm run scaffold-screens -- "${SCREEN_ARGS[@]}"

# Keep package.json repository URL aligned with the new repo.
if [[ -f package.json ]]; then
  tmp="$(mktemp)"
  jq --arg url "https://github.com/${ORG}/${REPO}.git" \
    --arg desc "$DESCRIPTION" \
    '.repository.url = $url | .description = $desc' \
    package.json >"$tmp"
  mv "$tmp" package.json
fi

echo ""
echo "npm run fix..."
npm run fix

echo ""
echo "npm run check..."
npm run check

# rename/scaffold-screens are one-shot template tools: --fix drops them (and their
# scripts) so the new sim starts with zero template drift; anything left fails here.
echo ""
echo "check-template-drift --fix..."
TEMPLATE_DIR="$(repos_workspace_root)/SceneryStackTemplate"
if [[ -f "$TEMPLATE_DIR/package.json" ]]; then
  node "$SCRIPT_DIR/check-template-drift.mjs" --fix --dir "$PWD" --name "$REPO" --template "$TEMPLATE_DIR"
else
  echo "warning: no local SceneryStackTemplate at $TEMPLATE_DIR; run check-template-drift.sh --fix $REPO later" >&2
fi
fi  # end of the create-from-template branch (--existing skips it)

CATALOG_PATH="$(repos_catalog_path)"
entry="$(jq -n \
  --arg name "$REPO" \
  --arg display "$SIM_NAME" \
  --arg desc "$DESCRIPTION" \
  --arg short "$SHORT_DESCRIPTION" \
  --arg url "${PAGES_BASE}/${REPO}" \
  --argjson screens "$catalog_screens_json" \
  --argjson topics "$catalog_topics_json" \
  --argjson githubTopics "$catalog_github_topics_json" \
  '
    {
      name: $name,
      displayName: $display,
      type: "simulation",
      isSimulation: true,
      lineage: "original",
      upstream: null,
      language: ["TypeScript"],
      framework: "SceneryStack",
      description: $desc,
      deployedUrl: $url,
      physicsTopics: $topics,
      screens: $screens,
      status: "active"
    }
    + (if ($short | length) > 0 then {shortDescription: $short} else {} end)
    + (if ($githubTopics | length) > 0 then {githubTopics: $githubTopics} else {} end)
  ')"

if [[ "$CATALOG" -eq 1 ]]; then
  echo ""
  echo "Catalog..."
  insert_catalog_entry "$CATALOG_PATH" "$entry"
fi

if [[ "$ONBOARD" -eq 1 ]]; then
  run_onboard_assets
  echo ""
  echo "Workspace README..."
  update_workspace_readme
  run_onboard_github
fi

if [[ "$OPEN_PR" -eq 1 ]]; then
  open_onboard_prs
fi

echo ""
echo "Bootstrap complete: $TARGET_PATH"
echo ""
if [[ "$ONBOARD" -eq 1 ]]; then
  echo "Onboarded:"
  echo "  - Baton structure/repos.json"
  echo "  - ${REPO}/assets/screenshot.png"
  echo "  - Baton screenshots/${REPO}.png + docs/assets/${REPO}.webp"
  echo "  - Baton docs/index.html"
  echo "  - GitHub settings + metadata + Dependabot + Claude plugin applied"
  echo "  - superproject README Layout row"
  if [[ "$OPEN_PR" -eq 1 ]]; then
    echo "  - follow-up PRs opened (see above)"
  else
    echo "  Review and commit; pass --pr next time to open Baton + superproject PRs."
  fi
else
  echo "Next steps (see Baton/doc/add-simulation.md):"
  echo "  1. Review: cd $TARGET_PATH && git status && git diff --stat"
  echo "  2. Commit bootstrap changes and push (unless --local-only / --no-push)."
  echo "  3. Apply GitHub settings baseline: (cd \"$BATON_ROOT\" && scripts/sync-github-settings.sh --apply --repo $REPO && scripts/sync-github-metadata.sh --repo $REPO)"
  if [[ "$EXISTING" -eq 1 ]]; then
    echo "  (Adopted an existing repo — --onboard would also capture screenshot + Pages + README.)"
  elif [[ "$CATALOG" -eq 0 ]]; then
    echo "  4. Re-run with --onboard (or --catalog) to finish fleet landing-page assets."
  else
    echo "  4. Re-run with --onboard to capture screenshot/WebP/Pages + README."
  fi
fi
