#!/usr/bin/env bats
#
# Behavioural tests for scripts/check-repo-compliance.sh.
#
# The failure mode this guards against is a compliance rule that quietly stops
# firing: the audit still exits 0, so the fleet reads as green while the rule is
# dead. Every test below starts from a fixture that passes cleanly, breaks
# exactly one rule, and asserts the audit fails with that rule's message.

setup() {
  load 'helpers/common'
  stub_gh
  SIM="$BATS_TEST_TMPDIR/sim"
  make_compliant_sim "$SIM"
}

# ── Baseline ──────────────────────────────────────────────────────────────────

@test "compliant fixture passes" {
  run_compliance "$SIM"
  assert_success
  refute_output --partial "FAIL:"
  assert_output --partial "Compliance check passed"
}

@test "compliant fixture warns only about the stubbed gh, not about content" {
  # Guards against fixture rot: a fixture that quietly starts warning would mask
  # the warn-level rules asserted further down.
  run_compliance "$SIM"
  assert_success
  local warnings
  warnings="$(printf '%s\n' "$output" | grep -c '^WARN:' || true)"
  [ "$warnings" -eq 1 ]
  assert_output --partial "WARN: gh not available"
}

# ── Legal / README ────────────────────────────────────────────────────────────

@test "root CONTRIBUTING.md fails" {
  touch "$SIM/CONTRIBUTING.md"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "FAIL: CONTRIBUTING.md must not exist"
}

@test "root LICENSE fails" {
  touch "$SIM/LICENSE"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "FAIL: LICENSE must not exist"
}

@test "missing README.md fails" {
  rm "$SIM/README.md"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "FAIL: README.md is missing"
}

@test "README missing a required section fails" {
  sed -i 's/^## Tech Stack$/## Stack/' "$SIM/README.md"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "FAIL: README.md missing '## Tech Stack' section"
}

@test "README with sections out of order fails" {
  # Swap Features and Quick Start.
  sed -i '0,/^## Features$/s//## PLACEHOLDER/' "$SIM/README.md"
  sed -i '0,/^## Quick Start$/s//## Features/' "$SIM/README.md"
  sed -i '0,/^## PLACEHOLDER$/s//## Quick Start/' "$SIM/README.md"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "FAIL: README.md section order wrong"
}

@test "README with an extra section fails" {
  printf '\n## Acknowledgements\n\nThanks.\n' >>"$SIM/README.md"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "unexpected section '## Acknowledgements'"
}

@test "README using '## Screens' instead of '## Features' fails with the targeted hint" {
  sed -i 's/^## Features$/## Screens/' "$SIM/README.md"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "must use '## Features' instead of '## Screens'"
}

# ── CI wiring ─────────────────────────────────────────────────────────────────

@test "missing ci.yml fails" {
  rm "$SIM/.github/workflows/ci.yml"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "FAIL: .github/workflows/ci.yml is missing"
}

@test "ci.yml not calling the shared reusable workflow fails" {
  sed -i "s|$(fleet_org)/Baton/.github/workflows/ci.yml@main|some/other/workflow.yml@main|" "$SIM/.github/workflows/ci.yml"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "ci.yml must call $(fleet_org)/Baton reusable workflow"
}

@test "ci.yml without the shared dependency-review workflow fails" {
  sed -i '/shared-dependency-review/d' "$SIM/.github/workflows/ci.yml"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "ci.yml must call shared dependency-review workflow"
}

@test "ci.yml without the shared CodeQL workflow fails" {
  sed -i '/shared-codeql/d' "$SIM/.github/workflows/ci.yml"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "ci.yml must call shared CodeQL workflow"
}

@test "missing dependabot.yml fails for an npm repo" {
  rm "$SIM/.github/dependabot.yml"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "dependabot.yml is missing for npm repository"
}

# ── Node pins ─────────────────────────────────────────────────────────────────

@test "missing engines.node fails" {
  local major
  major="$(fleet_node_major)"
  sed -i "/\"engines\"/d" "$SIM/package.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "engines.node is missing (expected >=${major})"
}

@test "engines.node below the fleet major fails" {
  sed -i 's/">=[0-9]*"/">=18"/' "$SIM/package.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "engines.node must be >="
}

@test "missing @types/node fails" {
  sed -i '/@types\/node/d' "$SIM/package.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "@types/node is missing"
}

@test "@types/node on the wrong major fails" {
  sed -i 's|"@types/node": "^[0-9]*|"@types/node": "^18|' "$SIM/package.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "@types/node major must be"
}

@test ".nvmrc disagreeing with the fleet major fails" {
  echo "18.20.0" >"$SIM/.nvmrc"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial ".nvmrc pins Node 18"
}

@test ".nvmrc agreeing with the fleet major passes" {
  fleet_node_major >"$SIM/.nvmrc"
  run_compliance "$SIM"
  assert_success
  assert_output --partial ".nvmrc matches fleet Node"
}

# ── SceneryStack bootstrap chain ──────────────────────────────────────────────

@test "missing bootstrap file fails" {
  rm "$SIM/src/splash.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "src/splash.ts is missing"
}

@test "main.ts not importing ./brand first fails" {
  printf 'import "./init.js";\nimport "./brand.js";\n' >"$SIM/src/main.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial 'first import must be "./brand.js"'
}

@test "missing root Namespace.ts fails" {
  rm "$SIM/src/FixtureSimNamespace.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "no <Prefix>Namespace.ts at src/ root"
}

@test "nested Namespace.ts fails even when a root one exists" {
  echo "export default {};" >"$SIM/src/intro/IntroNamespace.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "must be at src/ root, found nested"
}

@test "missing Colors.ts fails" {
  rm "$SIM/src/FixtureSimColors.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "no <Prefix>Colors.ts at src/ root"
}

@test "no Constants.ts anywhere fails" {
  rm "$SIM/src/FixtureSimConstants.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "no *Constants.ts anywhere under src/"
}

@test "nested Constants.ts warns without an AGENTS.md carve-out" {
  rm "$SIM/src/FixtureSimConstants.ts"
  echo "export default {};" >"$SIM/src/intro/IntroConstants.ts"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "WARN: no root <Prefix>Constants.ts"
}

@test "nested Constants.ts passes with a documented carve-out" {
  rm "$SIM/src/FixtureSimConstants.ts"
  echo "export default {};" >"$SIM/src/intro/IntroConstants.ts"
  printf '# AGENTS\n\n## Compliance carve-outs\n\nUses nested constants per screen.\n' >"$SIM/AGENTS.md"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "nested *Constants.ts layout documented"
}

# ── Plugin wiring ─────────────────────────────────────────────────────────────

@test "missing .claude/settings.json fails" {
  rm "$SIM/.claude/settings.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial ".claude/settings.json is missing"
}

@test ".claude/settings.json without the scenerystack plugin fails" {
  echo '{"enabledPlugins": {}}' >"$SIM/.claude/settings.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "does not enable the $(fleet_plugin_id) plugin"
}

# ── Colors ────────────────────────────────────────────────────────────────────

@test "hardcoded color outside Colors.ts warns" {
  echo 'const c = "#ff0000";' >"$SIM/src/intro/view/IntroNode.ts"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "WARN: possible hardcoded colors"
}

@test "hardcoded color passes with a documented carve-out" {
  echo 'const c = "#ff0000";' >"$SIM/src/intro/view/IntroNode.ts"
  printf '# AGENTS\n\n## Compliance carve-outs\n\nHardcoded colors in the brand icon.\n' >"$SIM/AGENTS.md"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "hardcoded color carve-outs documented"
}

@test "transparent rgba hit-area is not treated as a hardcoded color" {
  echo 'const hit = "rgba(0,0,0,0)";' >"$SIM/src/intro/view/IntroNode.ts"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "no hardcoded colors outside"
}

# ── Accessibility ─────────────────────────────────────────────────────────────

@test "no screen summary content warns" {
  rm "$SIM/src/intro/view/IntroScreenSummaryContent.ts"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "a11y screen summaries appear unwired"
}

@test "inline createScreenSummaryContent satisfies the screen summary rule" {
  rm "$SIM/src/intro/view/IntroScreenSummaryContent.ts"
  echo 'export function createScreenSummaryContent() {}' >"$SIM/src/intro/view/IntroScreenView.ts"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "screen summary content present"
}

@test "missing KeyboardHelpContent fails" {
  rm "$SIM/src/FixtureSimKeyboardHelpContent.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "no *KeyboardHelpContent.ts under src/"
}

# ── Preferences / i18n ────────────────────────────────────────────────────────

@test "missing preferences directory fails" {
  rm -r "$SIM/src/preferences"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "src/preferences/ is missing"
}

@test "missing PreferencesModel fails" {
  rm "$SIM/src/preferences/FixtureSimPreferencesModel.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "<Prefix>PreferencesModel.ts is missing"
}

@test "missing QueryParameters fails" {
  rm "$SIM/src/preferences/fixtureSimQueryParameters.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "QueryParameters.ts is missing"
}

@test "missing StringManager fails" {
  rm "$SIM/src/i18n/StringManager.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "src/i18n/StringManager.ts is missing"
}

@test "missing locale file fails" {
  rm "$SIM/src/i18n/strings_fr.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "missing locale file(s): strings_fr.json"
}

# ── Tests / hooks ─────────────────────────────────────────────────────────────

@test "test co-located under src/ fails" {
  echo "// test" >"$SIM/src/intro/model/IntroModel.test.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "tests must live under tests/"
}

@test "__tests__ directory under src/ fails" {
  mkdir -p "$SIM/src/intro/__tests__"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "tests must live under tests/"
}

@test "missing memory-leak suite fails" {
  rm "$SIM/tests/memory-leak.test.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "tests/memory-leak.test.ts is missing"
}

@test "vitest.config.ts without --expose-gc fails" {
  echo "export default {};" >"$SIM/vitest.config.ts"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial 'must set execArgv: ["--expose-gc"]'
}

@test "missing pre-push hook fails" {
  rm "$SIM/.githooks/pre-push"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial ".githooks/pre-push is missing"
}

@test "prepare script not setting core.hooksPath fails" {
  sed -i 's|"prepare": "git config core.hooksPath .githooks"|"prepare": "echo noop"|' "$SIM/package.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "prepare script must set core.hooksPath"
}

# ── Docs / tooling ────────────────────────────────────────────────────────────

@test "missing doc/model.md fails" {
  rm "$SIM/doc/model.md"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "doc/model.md is missing"
}

@test "stub doc warns" {
  printf '# Model\n\nTODO\n' >"$SIM/doc/model.md"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "doc/model.md looks like a stub"
}

@test "biome.json \$schema drifting from the pinned CLI fails" {
  sed -i 's|schemas/2.3.14/|schemas/2.2.0/|' "$SIM/biome.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "must match @biomejs/biome"
}

@test "unversioned biome.json \$schema fails" {
  echo '{"$schema": "https://biomejs.dev/schemas/schema.json"}' >"$SIM/biome.json"
  run_compliance "$SIM"
  assert_failure
  assert_output --partial "must be a versioned biomejs.dev/schemas"
}

@test "src/model at the src root warns" {
  mkdir -p "$SIM/src/model"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "src/model exists at src/ root"
}

# ── Standardization rules (warn by default, fail under COMPLIANCE_STRICT=1) ──

strict_compliance() {
  run env COMPLIANCE_STRICT=1 PATH="$STUB_BIN:$PATH" "$BATON_ROOT/scripts/check-repo-compliance.sh" "$1"
}

@test "compliant fixture passes the standardization rules in strict mode" {
  strict_compliance "$SIM"
  assert_success
  refute_output --partial "FAIL:"
}

@test "standardization rules only warn outside strict mode" {
  rm "$SIM/scripts/test-fuzz.ts"
  run_compliance "$SIM"
  assert_success
  assert_output --partial "WARN: scripts/test-fuzz.ts is missing"
}

@test "missing fuzz runner fails in strict mode" {
  rm "$SIM/scripts/test-fuzz.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "scripts/test-fuzz.ts is missing"
}

@test "old-style test:fuzz script fails in strict mode" {
  sed -i 's|"tsx scripts/test-fuzz.ts"|"playwright test --project=chromium"|' "$SIM/package.json"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "test:fuzz must run tsx scripts/test-fuzz.ts"
}

@test "dead .fuzz-playwright.config.ts fails in strict mode" {
  touch "$SIM/.fuzz-playwright.config.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial ".fuzz-playwright.config.ts is dead"
}

@test "missing tests/setup.ts fails in strict mode" {
  rm "$SIM/tests/setup.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "tests/setup.ts is missing"
}

@test "missing tests/setup.ts passes with a documented carve-out" {
  rm "$SIM/tests/setup.ts"
  printf '## Compliance carve-outs\n\n- `tests/setup.ts`: node environment, no DOM\n' >"$SIM/AGENTS.md"
  strict_compliance "$SIM"
  assert_success
}

@test "missing es key-parity check fails in strict mode" {
  sed -i '/stringsEs/d' "$SIM/src/i18n/StringManager.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "key-parity check for: es"
}

@test "hardcoded init.ts version fails in strict mode" {
  echo 'export const v = { version: "1.0.0" };' >"$SIM/src/init.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "must take version from package.json"
}

@test "leftover exampleToggle fails in strict mode" {
  echo 'export const exampleToggle = true;' >>"$SIM/src/preferences/fixtureSimQueryParameters.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "left in src: src/preferences/fixtureSimQueryParameters.ts"
}

@test "leftover exampleControl a11y string fails in strict mode" {
  echo '{"a11y":{"controls":{"exampleControl":"Example control"}}}' >"$SIM/src/i18n/strings_en.json"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "left in src: src/i18n/strings_en.json"
}

@test "export default class fails in strict mode" {
  echo 'export default class Foo {}' >"$SIM/src/intro/model/Foo.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "export default class in src"
}

@test "extension-less relative import fails in strict mode" {
  echo 'import { FixtureSimNamespace } from "./FixtureSimNamespace";' >"$SIM/src/Bad.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "relative imports must end in .js"
}

@test "unregistered constants fail in strict mode" {
  echo 'export const FixtureSimConstants = {};' >"$SIM/src/FixtureSimConstants.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "must register with the namespace"
}

@test "theme-color disagreeing with the manifest fails in strict mode" {
  sed -i 's|theme_color: "#1a1a2e"|theme_color: "#ffffff"|' "$SIM/vite.config.ts"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "must equal the manifest theme_color"
}

@test "stale README Tech Stack version fails in strict mode" {
  sed -i 's|^- SceneryStack$|- Biome 1|' "$SIM/README.md"
  strict_compliance "$SIM"
  assert_failure
  assert_output --partial "README Tech Stack versions are stale: Biome 1 (package.json 2)"
}

@test "stray root file warns unless carved out" {
  git -C "$SIM" init -q
  touch "$SIM/home.png"
  git -C "$SIM" add -A
  run_compliance "$SIM"
  assert_output --partial "Compliance carve-outs): home.png"
  printf '## Compliance carve-outs\n\n- `home.png`: store listing art\n' >"$SIM/AGENTS.md"
  run_compliance "$SIM"
  refute_output --partial "root entries outside the template layout"
}

# ── Non-simulation repos ──────────────────────────────────────────────────────

@test "npm repo without src/main.ts skips the simulation structure rules" {
  rm -r "$SIM/src" "$SIM/tests" "$SIM/.githooks" "$SIM/doc" "$SIM/.claude"
  run_compliance "$SIM"
  assert_success
  refute_output --partial "bootstrap chain"
  refute_output --partial "src/preferences/ is missing"
}
