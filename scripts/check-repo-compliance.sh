#!/usr/bin/env bash
# Compliance checks for the fleet's SceneryStack simulation repositories.
set -euo pipefail

# Resolve before the cd below: BASH_SOURCE may be a relative path, and it stops
# resolving once the working directory moves into the repo under test.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read the org identity and the canonical Claude plugin id from Baton before the
# cd below moves us out of this repo. Everything asserted further down is built
# from these, so renaming the organization or the marketplace is a catalog/config
# edit, never an edit to this script.
BATON_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="${FLEET_CATALOG:-${OPENPHYSICS_CATALOG:-$BATON_ROOT/structure/repos.json}}"
CLAUDE_SETTINGS="$BATON_ROOT/config/claude-settings.json"

ORG="${FLEET_ORG:-${OPENPHYSICS_ORG:-$(jq -r '.organization' "$CATALOG")}}"
ORG_CONFIG_REPO="$ORG/.github"
PLUGIN_ID="$(jq -r '.enabledPlugins | keys[0]' "$CLAUDE_SETTINGS")"

REPO_DIR="${1:?Repository directory required}"
cd "$REPO_DIR"

echo "Checking compliance in: $(pwd)"
FAIL=0
WARN=0

fail() {
  echo "FAIL: $1"
  FAIL=1
}

warn() {
  echo "WARN: $1"
  WARN=1
}

pass() {
  echo "OK: $1"
}

if [ -f CONTRIBUTING.md ]; then
  fail "CONTRIBUTING.md must not exist at repo root (use org default from $ORG_CONFIG_REPO)"
else
  pass "no local CONTRIBUTING.md"
fi

if [ -f LICENSE ]; then
  fail "LICENSE must not exist at repo root (use org default from $ORG_CONFIG_REPO)"
else
  pass "no local LICENSE"
fi

REQUIRED_SECTIONS=(
  "Features"
  "Quick Start"
  "Scripts"
  "Tech Stack"
  "License"
  "Contributing"
)

if [ ! -f README.md ]; then
  fail "README.md is missing"
else
  mapfile -t HEADINGS < <(grep -E '^## ' README.md | sed 's/^## //')
  for heading in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "^## ${heading}" README.md; then
      fail "README.md missing '## ${heading}' section"
    else
      pass "README has ## ${heading}"
    fi
  done

  expected_index=0
  for heading in "${HEADINGS[@]}"; do
    if [ "$expected_index" -ge "${#REQUIRED_SECTIONS[@]}" ]; then
      fail "README.md has unexpected section '## ${heading}' (only standard sections allowed)"
      continue
    fi
    if [ "$heading" != "${REQUIRED_SECTIONS[$expected_index]}" ]; then
      if [ "$expected_index" -eq 0 ] && [ "$heading" = "Screens" ]; then
        fail "README.md must use '## Features' instead of '## Screens'"
      else
        fail "README.md section order wrong: expected '## ${REQUIRED_SECTIONS[$expected_index]}', found '## ${heading}'"
      fi
    else
      ((expected_index++)) || true
    fi
  done

  if [ "$expected_index" -ne "${#REQUIRED_SECTIONS[@]}" ]; then
    fail "README.md is missing one or more required sections after '## Features'"
  else
    pass "README section order matches standard outline"
  fi
fi

if [ ! -f .github/workflows/ci.yml ]; then
  fail ".github/workflows/ci.yml is missing"
elif ! grep -q "$ORG/Baton/.github/workflows/ci.yml@main" .github/workflows/ci.yml; then
  fail "ci.yml must call $ORG/Baton reusable workflow"
else
  pass "ci.yml uses shared reusable workflow"
fi

if ! grep -q "$ORG/Baton/.github/workflows/shared-dependency-review.yml@main" .github/workflows/ci.yml; then
  fail "ci.yml must call shared dependency-review workflow"
elif ! grep -q "$ORG/Baton/.github/workflows/shared-codeql.yml@main" .github/workflows/ci.yml; then
  fail "ci.yml must call shared CodeQL workflow"
else
  pass "ci.yml uses shared security workflows"
fi

if [ -f package.json ]; then
  if [ ! -f .github/dependabot.yml ]; then
    fail ".github/dependabot.yml is missing for npm repository"
  else
    pass "dependabot.yml present"
  fi

  # Node engine / @types/node must track Baton's fleet Node major (ci.yml default).
  # When this script is checked out from Baton (.org-compliance/…), read the major
  # from that tree; otherwise fall back to 24.
  CI_YML="$SCRIPT_DIR/../.github/workflows/ci.yml"
  if [ -f "$CI_YML" ]; then
    EXPECTED_NODE_MAJOR="$(grep -oP 'default:\s*["'\'']\K[0-9]+' "$CI_YML" | head -n1 || true)"
  fi
  EXPECTED_NODE_MAJOR="${EXPECTED_NODE_MAJOR:-24}"

  PKG_META="$(python3 -c "
import json
p = json.load(open('package.json'))
engines = (p.get('engines') or {}).get('node') or ''
types = (p.get('devDependencies') or {}).get('@types/node') or (p.get('dependencies') or {}).get('@types/node') or ''
print(engines + '\t' + types)
")"
  ENGINES_NODE="${PKG_META%%$'\t'*}"
  TYPES_NODE="${PKG_META#*$'\t'}"

  if [ -z "$ENGINES_NODE" ]; then
    fail "package.json engines.node is missing (expected >=${EXPECTED_NODE_MAJOR})"
  elif [[ ! "$ENGINES_NODE" =~ ^\>=${EXPECTED_NODE_MAJOR}(\.0\.0)?$ ]]; then
    fail "engines.node must be >=${EXPECTED_NODE_MAJOR} to match fleet Node (found: $ENGINES_NODE)"
  else
    pass "engines.node is $ENGINES_NODE"
  fi

  if [ -z "$TYPES_NODE" ]; then
    fail "package.json @types/node is missing (expected major ${EXPECTED_NODE_MAJOR})"
  else
    TYPES_MAJOR="$(sed -E 's/^[^0-9]*([0-9]+).*/\1/' <<<"$TYPES_NODE")"
    if [ "$TYPES_MAJOR" != "$EXPECTED_NODE_MAJOR" ]; then
      fail "@types/node major must be ${EXPECTED_NODE_MAJOR} to match fleet Node (found: $TYPES_NODE)"
    else
      pass "@types/node major is $TYPES_MAJOR"
    fi
  fi

  for pinfile in .nvmrc .node-version; do
    if [ -f "$pinfile" ]; then
      PIN="$(tr -d 'v[:space:]' <"$pinfile")"
      PIN_MAJOR="${PIN%%.*}"
      if [ "$PIN_MAJOR" != "$EXPECTED_NODE_MAJOR" ]; then
        fail "$pinfile pins Node $PIN but fleet major is $EXPECTED_NODE_MAJOR (remove it or set to $EXPECTED_NODE_MAJOR)"
      else
        pass "$pinfile matches fleet Node $EXPECTED_NODE_MAJOR"
      fi
    fi
  done
elif [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ]; then
  if [ ! -f .github/dependabot.yml ]; then
    fail ".github/dependabot.yml is missing for python repository"
  else
    pass "dependabot.yml present"
  fi
fi

# ── SceneryStack simulation structure (see Baton/CONVENTIONS.md) ────────────────
# Only applies to sim repos (npm package with a src/main.ts bootstrap entry).
if [ -f package.json ] && [ -f src/main.ts ]; then
  for f in init assert splash brand main; do
    [ -f "src/$f.ts" ] || fail "src/$f.ts is missing (bootstrap chain)"
  done

  first_import="$(grep -m1 -E '^import ' src/main.ts || true)"
  if printf '%s' "$first_import" | grep -q '"\./brand'; then
    pass "main.ts imports ./brand first"
  else
    fail "src/main.ts's first import must be \"./brand.js\""
  fi

  root_ns="$(find src -maxdepth 1 -name '*Namespace.ts')"
  nested_ns="$(find src -mindepth 2 -name '*Namespace.ts')"
  if [ -z "$root_ns" ]; then
    fail "no <Prefix>Namespace.ts at src/ root"
  elif [ -n "$nested_ns" ]; then
    fail "<Prefix>Namespace.ts must be at src/ root, found nested: $(echo "$nested_ns" | tr '\n' ' ')"
  else
    pass "<Prefix>Namespace.ts at src/ root"
  fi

  if compgen -G "src/*Colors.ts" >/dev/null; then
    pass "<Prefix>Colors.ts at src/ root"
  else
    fail "no <Prefix>Colors.ts at src/ root"
  fi

  # Constants: default is a root <Prefix>Constants.ts; a documented nested layout is
  # allowed (CONVENTIONS.md §2), but constants must exist somewhere under src/.
  if compgen -G "src/*Constants.ts" >/dev/null; then
    pass "<Prefix>Constants.ts at src/ root"
  elif [ -n "$(find src -mindepth 2 -name '*Constants.ts' -print -quit)" ]; then
    if [ -f AGENTS.md ] && grep -qE '^## Compliance carve-outs' AGENTS.md && grep -qiE 'nested constants' AGENTS.md; then
      pass "nested *Constants.ts layout documented in AGENTS.md Compliance carve-outs"
    else
      warn "no root <Prefix>Constants.ts — nested constants found; document under AGENTS.md ## Compliance carve-outs"
    fi
  else
    fail "no *Constants.ts anywhere under src/"
  fi

  # The scenerystack Claude Code plugin roll-out (config/claude-settings.json).
  if [ ! -f .claude/settings.json ]; then
    fail ".claude/settings.json is missing (run Baton/scripts/sync-claude-settings.sh)"
  elif grep -q "$PLUGIN_ID" .claude/settings.json; then
    pass ".claude/settings.json enables the scenerystack plugin"
  elif grep -qE 'scenerystack@[A-Za-z0-9_-]+' .claude/settings.json; then
    # Transitional: the marketplace id was renamed off the org name. A repo still
    # carrying the old id is stale, not broken - sync-claude-settings.sh fixes it.
    warn ".claude/settings.json uses a stale plugin id; expected $PLUGIN_ID (run Baton/scripts/sync-claude-settings.sh)"
  else
    fail ".claude/settings.json does not enable the $PLUGIN_ID plugin"
  fi

  # Hardcoded colors in view code (heuristic — ProfileColorProperty entries belong in
  # <Prefix>Colors.ts). Transparent rgba(0,0,0,0) hit-areas and icon/brand palettes are
  # accepted; anything else should be themed or documented as a carve-out in AGENTS.md.
  color_hits="$(grep -rEn '"#[0-9a-fA-F]{3,8}"|rgba?\(' src --include='*.ts' 2>/dev/null \
    | grep -vE 'Colors\.ts|Icon|brand\.ts|rgba\( *0, *0, *0, *0 *\)|rgba\(0,0,0,0\)' || true)"
  if [ -n "$color_hits" ]; then
    if [ -f AGENTS.md ] && grep -qE '^## Compliance carve-outs' AGENTS.md && grep -qiE 'hardcoded colors' AGENTS.md; then
      pass "hardcoded color carve-outs documented in AGENTS.md ($(echo "$color_hits" | wc -l | tr -d ' ') hit(s))"
    else
      warn "possible hardcoded colors outside <Prefix>Colors.ts (theme or document under AGENTS.md ## Compliance carve-outs):"
      echo "$color_hits" | sed 's/^/  /'
    fi
  else
    pass "no hardcoded colors outside <Prefix>Colors.ts"
  fi

  # Screen summaries (ACCESSIBILITY.md layer 2): per-screen *ScreenSummaryContent.ts
  # files (template pattern), an inline createScreenSummaryContent() factory
  # (OscillationsAndChaos pattern), or a direct `new ScreenSummaryContent(...)`
  # — one of the three must exist.
  if [ -n "$(find src -name '*ScreenSummaryContent.ts' -print -quit)" ] \
    || grep -rqE 'createScreenSummaryContent|new ScreenSummaryContent\(' src --include='*.ts'; then
    pass "screen summary content present"
  else
    warn "no *ScreenSummaryContent.ts and no ScreenSummaryContent construction — a11y screen summaries appear unwired (ACCESSIBILITY.md)"
  fi

  # Keyboard help dialog (ACCESSIBILITY.md layer 2): every sim ships a
  # *KeyboardHelpContent.ts wired via createKeyboardHelpNode on each Screen.
  if [ -n "$(find src -name '*KeyboardHelpContent.ts' -print -quit)" ]; then
    pass "*KeyboardHelpContent.ts present"
  else
    fail "no *KeyboardHelpContent.ts under src/ (ACCESSIBILITY.md — Keyboard Shortcuts dialog)"
  fi

  if [ ! -d src/preferences ]; then
    fail "src/preferences/ is missing"
  else
    pref_ok=1
    compgen -G "src/preferences/*PreferencesModel.ts" >/dev/null || { fail "src/preferences/<Prefix>PreferencesModel.ts is missing"; pref_ok=0; }
    compgen -G "src/preferences/*PreferencesNode.ts"  >/dev/null || { fail "src/preferences/ needs at least one *PreferencesNode.ts"; pref_ok=0; }
    compgen -G "src/preferences/*QueryParameters.ts"  >/dev/null || { fail "src/preferences/<prefix>QueryParameters.ts is missing"; pref_ok=0; }
    [ "$pref_ok" -eq 1 ] && pass "src/preferences/ has Model, Node, and QueryParameters"
  fi

  if [ ! -f src/i18n/StringManager.ts ]; then
    fail "src/i18n/StringManager.ts is missing"
  else
    loc_miss=""
    for loc in en es fr; do
      [ -f "src/i18n/strings_$loc.json" ] || loc_miss="$loc_miss strings_$loc.json"
    done
    if [ -n "$loc_miss" ]; then
      fail "src/i18n/ missing locale file(s):$loc_miss"
    else
      pass "src/i18n/ has StringManager + en/es/fr locales"
    fi
  fi

  stray_tests="$(find src \( -name '*.test.ts' -o -name '*.spec.ts' \) 2>/dev/null)"
  stray_testdirs="$(find src -type d -name '__tests__' 2>/dev/null)"
  if [ -n "$stray_tests" ] || [ -n "$stray_testdirs" ]; then
    fail "tests must live under tests/, not in src/ ($(echo "$stray_tests $stray_testdirs" | tr '\n' ' '))"
  else
    pass "no tests co-located under src/"
  fi

  # Memory-leak suite (CONVENTIONS.md §5): fleet-standard WeakRef + --expose-gc
  # dispose regression. Presence is gated here; `npm test` exercises it in CI.
  if [ ! -f tests/memory-leak.test.ts ]; then
    fail "tests/memory-leak.test.ts is missing (fleet-standard dispose regression)"
  elif [ ! -f vitest.config.ts ]; then
    fail "vitest.config.ts is missing (needed for --expose-gc with the memory-leak suite)"
  elif ! grep -q -- '--expose-gc' vitest.config.ts; then
    fail "vitest.config.ts must set execArgv: [\"--expose-gc\"] for tests/memory-leak.test.ts"
  else
    pass "memory-leak suite + vitest --expose-gc"
  fi

  # Git hooks (CONVENTIONS.md §7): pre-commit / pre-push under .githooks/, activated
  # by the prepare script on npm install.
  hooks_ok=1
  if [ ! -d .githooks ]; then
    fail ".githooks/ is missing"
    hooks_ok=0
  else
    for hook in pre-commit pre-push; do
      if [ ! -f ".githooks/$hook" ]; then
        fail ".githooks/$hook is missing"
        hooks_ok=0
      fi
    done
  fi
  if ! grep -qE '"prepare".*core\.hooksPath \.githooks' package.json; then
    fail "package.json prepare script must set core.hooksPath to .githooks"
    hooks_ok=0
  fi
  [ "$hooks_ok" -eq 1 ] && pass ".githooks/ pre-commit + pre-push with prepare activation"

  # Pages deploy (CONVENTIONS.md §7): reusable Baton workflow + manual dispatch,
  # matching Baton's own pages.yml triggers so a missed push can be recovered.
  if [ ! -f .github/workflows/deploy.yml ]; then
    fail ".github/workflows/deploy.yml is missing"
  elif ! grep -q "$ORG/Baton/.github/workflows/deploy.yml@main" .github/workflows/deploy.yml; then
    fail "deploy.yml must call $ORG/Baton reusable deploy workflow"
  elif ! grep -q "workflow_dispatch:" .github/workflows/deploy.yml; then
    fail "deploy.yml must allow workflow_dispatch (manual Pages publish)"
  else
    pass "deploy.yml uses shared reusable workflow with workflow_dispatch"
  fi

  # PWA (CONVENTIONS.md §7): vite-plugin-pwa + generate-icons + public assets + index meta.
  if ! grep -q '"vite-plugin-pwa"' package.json; then
    fail "package.json is missing vite-plugin-pwa"
  else
    pass "vite-plugin-pwa in package.json"
  fi
  if ! grep -qE '"icons":\s*".*scripts/generate-icons\.ts' package.json; then
    fail "package.json icons script must run tsx scripts/generate-icons.ts"
  else
    pass "package.json icons script"
  fi
  if ! grep -qE '"pwa"' package.json; then
    fail "package.json keywords must include \"pwa\""
  else
    pass "package.json keywords include pwa"
  fi

  if [ ! -f vite.config.ts ]; then
    fail "vite.config.ts is missing (PWA plugin lives there)"
  else
    pwa_ok=1
    grep -q 'vite-plugin-pwa' vite.config.ts || { fail "vite.config.ts must import vite-plugin-pwa"; pwa_ok=0; }
    grep -qE 'registerType:\s*"autoUpdate"' vite.config.ts || { fail "VitePWA registerType must be autoUpdate"; pwa_ok=0; }
    grep -qE '^\s*id:\s*"' vite.config.ts || { fail "PWA manifest is missing id"; pwa_ok=0; }
    grep -q 'categories: \["education", "science"\]' vite.config.ts || { fail "PWA manifest categories must be [\"education\", \"science\"]"; pwa_ok=0; }
    grep -q 'display_override' vite.config.ts || { fail "PWA manifest is missing display_override"; pwa_ok=0; }
    grep -q 'screenshots:' vite.config.ts || { fail "PWA manifest is missing screenshots"; pwa_ok=0; }
    if grep -qE 'orientation:\s*"' vite.config.ts; then
      fail "PWA manifest must omit orientation (do not force landscape)"
      pwa_ok=0
    fi
    grep -q 'icons/icon-192.png' vite.config.ts && grep -q 'icons/icon-512.png' vite.config.ts && grep -q 'icons/icon.svg' vite.config.ts || { fail "PWA manifest icons must include icon-192.png, icon-512.png, and icon.svg"; pwa_ok=0; }
    grep -q 'screenshots/wide.png' vite.config.ts && grep -q 'screenshots/narrow.png' vite.config.ts || { fail "PWA manifest screenshots must include wide.png and narrow.png"; pwa_ok=0; }
    [ "$pwa_ok" -eq 1 ] && pass "VitePWA manifest matches fleet pattern"
  fi

  if [ ! -f scripts/generate-icons.ts ]; then
    fail "scripts/generate-icons.ts is missing"
  elif ! grep -q 'screenshots/wide.png' scripts/generate-icons.ts || ! grep -q 'screenshots/narrow.png' scripts/generate-icons.ts; then
    fail "scripts/generate-icons.ts must emit public/screenshots/{wide,narrow}.png"
  else
    pass "generate-icons.ts emits PWA screenshots"
  fi

  pwa_assets_ok=1
  for f in public/favicon.ico public/icons/icon.svg public/icons/icon-192.png public/icons/icon-512.png public/icons/apple-touch-icon.png public/screenshots/wide.png public/screenshots/narrow.png; do
    if [ ! -f "$f" ]; then
      fail "missing PWA asset $f"
      pwa_assets_ok=0
    fi
  done
  [ "$pwa_assets_ok" -eq 1 ] && pass "PWA public icons + screenshots present"

  if [ ! -f index.html ]; then
    fail "index.html is missing"
  else
    html_ok=1
    grep -q 'name="theme-color"' index.html || { fail "index.html is missing theme-color meta"; html_ok=0; }
    grep -q 'name="description"' index.html || { fail "index.html is missing description meta"; html_ok=0; }
    grep -q 'property="og:image"' index.html || { fail "index.html is missing og:image (PWA / share preview)"; html_ok=0; }
    grep -q 'name="twitter:image"' index.html || { fail "index.html is missing twitter:image"; html_ok=0; }
    grep -q 'rel="apple-touch-icon"' index.html || { fail "index.html is missing apple-touch-icon"; html_ok=0; }
    grep -q 'name="apple-mobile-web-app-capable"' index.html || { fail "index.html is missing apple-mobile-web-app-capable"; html_ok=0; }
    [ "$html_ok" -eq 1 ] && pass "index.html PWA / share meta"
  fi

  for d in doc/model.md doc/implementation-notes.md; do
    if [ ! -f "$d" ]; then
      fail "$d is missing"
    else
      # Presence is required (fail above); content is expected to be filled, not a
      # stub. Heuristic: count substantive lines (non-blank, non-heading, no TODO/
      # placeholder marker). A real doc has several; a copied-template stub has ~none.
      # `|| true` because a pure stub filters down to nothing, making grep exit 1;
      # under `set -euo pipefail` that would abort the run instead of warning.
      body_lines=$(grep -vcE '^\s*$|^\s*#|TODO|TBD|FIXME|placeholder|fill in|\.\.\.$' "$d" || true)
      if [ "$body_lines" -lt 5 ]; then
        warn "$d looks like a stub (only $body_lines substantive lines) — fill in the physics/architecture"
      else
        pass "$d is filled ($body_lines content lines)"
      fi
    fi
  done

  # Biome config and CLI must move in lockstep: Dependabot bumps the devDependency
  # but never rewrites $schema, so the two silently drift. Assert equality rather
  # than pinning a version here, so this check survives the next bump untouched.
  # `biome migrate --write` is what resyncs biome.json after a bump.
  if [ -f biome.json ]; then
    biome_schema_ver=$(grep -oE 'biomejs\.dev/schemas/[0-9]+\.[0-9]+\.[0-9]+' biome.json | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    biome_dep_ver=$(grep -oE '"@biomejs/biome"[[:space:]]*:[[:space:]]*"[^"]+"' package.json | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    if [ -z "$biome_schema_ver" ]; then
      fail "biome.json \$schema must be a versioned biomejs.dev/schemas/<x.y.z>/schema.json URL"
    elif [ -z "$biome_dep_ver" ]; then
      fail "package.json must pin @biomejs/biome (biome.json \$schema is $biome_schema_ver)"
    elif [ "$biome_schema_ver" != "$biome_dep_ver" ]; then
      fail "biome.json \$schema ($biome_schema_ver) must match @biomejs/biome ($biome_dep_ver) — run: npx @biomejs/biome migrate --write"
    else
      pass "biome.json \$schema matches pinned @biomejs/biome ($biome_dep_ver)"
    fi
  fi

  # ── Standardization rules (2026-09 fleet sweep) ─────────────────────────────
  # Added as warnings; promoted to failures once the whole fleet passes them.
  # COMPLIANCE_STRICT=1 treats them as failures now (used by Baton's own tests).
  new_rule() {
    if [ "${COMPLIANCE_STRICT:-0}" = 1 ]; then fail "$1"; else warn "$1"; fi
  }
  # carved_out <token>: an explicit AGENTS.md "## Compliance carve-outs" entry — a bullet that
  # starts with `token`, or a "**Template drift**" bullet naming it (same rule as
  # check-template-drift.mjs; a token merely mentioned in prose does not count).
  carved_out() {
    [ -f AGENTS.md ] || return 1
    python3 - "$1" <<'PY'
import re, sys
token = sys.argv[1]
text = open("AGENTS.md").read()
for m in re.finditer(r"^## Compliance carve-outs?\s*$([\s\S]*?)(?=^## |\Z)", text, re.M):
    for bullet in re.split(r"\n(?=\s*[-*] )", m.group(1)):
        lead = re.match(r"\s*[-*] +`([^`\n]+)`", bullet)
        if lead and lead.group(1).strip() == token:
            sys.exit(0)
        if re.match(r"\s*[-*] +\*\*Template drift", bullet, re.I) and f"`{token}`" in bullet:
            sys.exit(0)
sys.exit(1)
PY
  }

  # Fuzz smoke: the template's runner, spec and config (CONVENTIONS.md §5).
  fuzz_ok=1
  for f in tests/fuzz/fuzz.spec.ts playwright.config.ts scripts/test-fuzz.ts; do
    [ -f "$f" ] || { new_rule "$f is missing (fleet fuzz smoke)"; fuzz_ok=0; }
  done
  grep -qE '"test:fuzz":\s*"tsx scripts/test-fuzz\.ts"' package.json || { new_rule "package.json test:fuzz must run tsx scripts/test-fuzz.ts"; fuzz_ok=0; }
  [ -f .fuzz-playwright.config.ts ] && { new_rule ".fuzz-playwright.config.ts is dead — use FUZZ_PORT with playwright.config.ts"; fuzz_ok=0; }
  [ "$fuzz_ok" -eq 1 ] && pass "fuzz smoke: runner, spec, config"

  # Memory-leak suite on the shared harness, not a private forceGC copy (CONVENTIONS.md §5).
  if [ -f tests/memory-leak.test.ts ]; then
    if grep -qE 'function forceGC' tests/memory-leak.test.ts || ! grep -q 'helpers/memoryLeak' tests/memory-leak.test.ts; then
      new_rule "tests/memory-leak.test.ts must use tests/helpers/memoryLeak.ts (describeDisposalLeaks / forceGC), not a local forceGC"
    else
      pass "memory-leak suite uses the shared harness"
    fi
  fi

  # A test script and the shared setup (CONVENTIONS.md §5).
  if ! grep -qE '"test":\s*"' package.json; then
    new_rule "package.json has no test script (CI would skip unit tests silently)"
  elif [ ! -f tests/setup.ts ] && ! carved_out tests/setup.ts; then
    new_rule "tests/setup.ts is missing (template setup) — or document it under AGENTS.md ## Compliance carve-outs"
  else
    pass "test script + tests/setup.ts"
  fi

  # Locale parity: every strings_<xx>.json has a satisfies pair against English.
  if [ -f src/i18n/StringManager.ts ]; then
    parity_missing=""
    for f in src/i18n/strings_*.json; do
      loc="$(basename "$f" .json)"; loc="${loc#strings_}"
      [ "$loc" = en ] && continue
      ident="strings$(printf '%s' "${loc:0:1}" | tr '[:lower:]' '[:upper:]')${loc:1}"
      grep -qE "${ident} satisfies typeof stringsEn" src/i18n/StringManager.ts \
        && grep -qE "stringsEn satisfies typeof ${ident}" src/i18n/StringManager.ts \
        || parity_missing="$parity_missing $loc"
    done
    if [ -n "$parity_missing" ]; then
      new_rule "StringManager.ts lacks the two-way satisfies key-parity check for:$parity_missing"
    else
      pass "StringManager.ts key-parity checks cover every locale"
    fi
  fi

  # Version: init.ts reads it from package.json so releases cannot leave it stale.
  if [ -f src/init.ts ] && ! grep -q 'from "../package.json"' src/init.ts; then
    new_rule "src/init.ts must take version from package.json (import { version } from \"../package.json\")"
  else
    pass "init.ts version comes from package.json"
  fi

  # Template leftovers — placeholder preference/a11y strings and Sim* files (the template itself ships them).
  if grep -q '"name": "scenerystack-template"' package.json; then
    leftovers=""
  else
    leftovers="$(grep -rlE '\b(exampleToggle|exampleControl)\b' src 2>/dev/null || true)"
    leftovers="$leftovers $(find src -name 'Sim*.ts' 2>/dev/null | grep -E '/Sim(Panel|ButtonOptions|ControlOptions|Screen|ScreenView|Model)\.ts$' || true)"
  fi
  if [ -n "$(echo "$leftovers" | tr -d ' ')" ]; then
    new_rule "template placeholders (exampleToggle, exampleControl, Sim*.ts) left in src: $(echo "$leftovers" | xargs)"
  else
    pass "no template placeholders (exampleToggle, Sim*.ts) left"
  fi

  # TS conventions: named exports, .js extensions on relative imports.
  default_classes="$(grep -rlE '^export default (abstract )?class ' src --include='*.ts' 2>/dev/null || true)"
  if [ -n "$default_classes" ]; then
    new_rule "export default class in src (use named exports): $(echo "$default_classes" | head -5 | xargs)$([ "$(echo "$default_classes" | wc -l)" -gt 5 ] && echo ' …')"
  else
    pass "no default-exported classes"
  fi
  bad_imports="$(grep -rnE "(from|import) +['\"]\.\.?/[^'\"]*['\"]" src --include='*.ts' 2>/dev/null \
    | grep -vE "['\"]\.\.?/[^'\"]*\.(js|json|css|svg|png|jpe?g|gif|webp|avif|mp3|wav|ogg|mp4|webm|glsl|wgsl|txt|csv|geojson)(\?[a-z]+)?['\"]" || true)"
  if [ -n "$bad_imports" ]; then
    new_rule "relative imports must end in .js ($(echo "$bad_imports" | wc -l | tr -d ' ') hit(s), e.g. $(echo "$bad_imports" | head -1 | cut -c1-120))"
  else
    pass "relative imports use .js extensions"
  fi

  # Constants register with the namespace like every other module.
  root_constants="$(find src -maxdepth 1 -name '*Constants.ts' | head -1)"
  if [ -n "$root_constants" ] && ! grep -qE '\.register\(' "$root_constants"; then
    new_rule "$root_constants must register with the namespace (<Prefix>Namespace.register(...))"
  elif [ -n "$root_constants" ]; then
    pass "$(basename "$root_constants") registers with the namespace"
  fi

  # index.html theme-color and the manifest agree; manifest has a background_color.
  if [ -f index.html ] && [ -f vite.config.ts ]; then
    html_theme="$(grep -oE 'name="theme-color"[^>]*content="#[0-9a-fA-F]{6}"' index.html | grep -oE '#[0-9a-fA-F]{6}' | head -1 | tr '[:upper:]' '[:lower:]')"
    manifest_theme="$(grep -oE 'theme_color:\s*"#[0-9a-fA-F]{6}"' vite.config.ts | grep -oE '#[0-9a-fA-F]{6}' | head -1 | tr '[:upper:]' '[:lower:]')"
    if [ -z "$manifest_theme" ] || [ "$html_theme" != "$manifest_theme" ]; then
      new_rule "index.html theme-color ($html_theme) must equal the manifest theme_color ($manifest_theme)"
    elif ! grep -qE 'background_color:\s*"' vite.config.ts; then
      new_rule "PWA manifest is missing background_color"
    else
      pass "theme-color matches manifest theme_color"
    fi
  fi

  # README Tech Stack versions must match the package.json majors.
  stale_versions="$(python3 - <<'PY' 2>/dev/null || true
import json, re
pkg = json.load(open("package.json"))
deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
tools = {"SceneryStack": "scenerystack", "Vite": "vite", "TypeScript": "typescript", "Biome": "@biomejs/biome",
         "Vitest": "vitest", "Playwright": "@playwright/test", "vite-plugin-pwa": "vite-plugin-pwa"}
text = open("README.md").read()
m = re.search(r"^## Tech Stack\n(.*?)(?=^## |\Z)", text, re.S | re.M)
out = []
for line in (m.group(1) if m else "").splitlines():
    for name, dep in tools.items():
        if dep not in deps or not re.search(r"(\[|\b)" + re.escape(name) + r"(\]|\b)(?!-)", line):
            continue
        v = re.search(re.escape(name) + r"\]?(?:\([^)]*\))?\s*(?:\|\s*)?\^?~?v?(\d+)", line)
        want = re.search(r"(\d+)", deps[dep]).group(1)
        if v and v.group(1) != want:
            out.append(f"{name} {v.group(1)} (package.json {want})")
print("; ".join(out))
PY
)"
  if [ -n "$stale_versions" ]; then
    new_rule "README Tech Stack versions are stale: $stale_versions"
  else
    pass "README Tech Stack versions match package.json"
  fi

  # Root layout: anything outside the template's set must be carved out in AGENTS.md.
  stray_root=""
  while IFS= read -r entry; do
    case "$entry" in
      .git|.github|.githooks|.claude|.gitignore|.gitattributes|node_modules|dist|src|tests|doc|public|scripts|assets) ;;
      AGENTS.md|README.md|CREDITS.md|SECURITY.md|package.json|package-lock.json|index.html|biome.json) ;;
      tsconfig.json|tsconfig.test.json|tsconfig.scripts.json|vite.config.ts|vitest.config.ts|playwright.config.ts) ;;
      playwright-report|test-results|coverage|.vite|.cache) ;;
      *) carved_out "$entry" || carved_out "$entry/" || stray_root="$stray_root $entry" ;;
    esac
  done < <(git ls-files 2>/dev/null | cut -d/ -f1 | sort -u)
  if [ -n "$stray_root" ]; then
    warn "root entries outside the template layout (move, delete, or list under AGENTS.md ## Compliance carve-outs):$stray_root"
  else
    pass "root layout matches the template"
  fi

  for d in src/model src/view; do
    [ -d "$d" ] && warn "$d exists at src/ root — model/ and view/ belong inside a screen folder"
  done
fi

REPO_NAME=""
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
  REPO_NAME="${GITHUB_REPOSITORY##*/}"
fi
if [ -z "$REPO_NAME" ]; then
  REPO_NAME="$(basename "$REPO_DIR")"
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  VULN_ALERTS=$(gh api graphql -f query='query($o:String!,$n:String!){ repository(owner:$o,name:$n){ hasVulnerabilityAlertsEnabled isPrivate } }' -f o="$ORG" -f n="$REPO_NAME" --jq '.data.repository.hasVulnerabilityAlertsEnabled' 2>/dev/null || echo "")
  if [ "$VULN_ALERTS" = "true" ]; then
    pass "Dependabot vulnerability alerts enabled"
  elif [ -n "$VULN_ALERTS" ]; then
    fail "Dependabot vulnerability alerts are not enabled on GitHub"
  else
    warn "Could not verify GitHub vulnerability alerts (gh query failed)"
  fi

  SEC_JSON=$(gh api "repos/$ORG/$REPO_NAME" --jq '.security_and_analysis // {}' 2>/dev/null || echo "{}")
  IS_PRIVATE=$(gh api "repos/$ORG/$REPO_NAME" --jq '.private' 2>/dev/null || echo "false")
  if [ -n "$SEC_JSON" ] && [ "$SEC_JSON" != "{}" ] && [ "$SEC_JSON" != "null" ]; then
    DEP_UPDATES=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("dependabot_security_updates",{}).get("status","unknown"))' <<<"$SEC_JSON")
    if [ "$DEP_UPDATES" = "enabled" ]; then
      pass "Dependabot security updates enabled"
    else
      fail "Dependabot security updates are not enabled on GitHub"
    fi

    if [ "$IS_PRIVATE" != "true" ]; then
      SECRET_SCAN=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("secret_scanning",{}).get("status","unknown"))' <<<"$SEC_JSON")
      if [ "$SECRET_SCAN" = "enabled" ]; then
        pass "secret scanning enabled"
      else
        fail "Secret scanning is not enabled on GitHub"
      fi
    else
      pass "private repo: secret scanning check skipped"
    fi
  elif [ "$IS_PRIVATE" = "true" ]; then
    pass "private repo: dependabot security updates assumed enabled when vulnerability alerts are on"
  else
    warn "Could not read security_and_analysis settings from GitHub"
  fi
else
  warn "gh not available; skipping live GitHub security setting checks"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "Compliance check failed."
  exit 1
fi

if [ "$WARN" -ne 0 ]; then
  echo "Compliance check passed with warnings."
else
  echo "Compliance check passed."
fi
