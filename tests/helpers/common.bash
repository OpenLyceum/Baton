# Shared bats helpers for the Baton script tests.
#
# Loaded by every *.bats file via `load helpers/common`.

source "${BATS_TEST_DIRNAME}/../node_modules/bats-support/load.bash"
source "${BATS_TEST_DIRNAME}/../node_modules/bats-assert/load.bash"

BATON_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export BATON_ROOT

# The fleet Node major, read from the same place check-repo-compliance.sh reads it
# (Baton's ci.yml `node-version` default). Fixtures derive their pins from this so
# the suite survives a fleet Node bump; the "wrong major" cases hardcode a value
# that is wrong under any plausible fleet version.
fleet_node_major() {
  grep -oP 'default:\s*["'\'']\K[0-9]+' "$BATON_ROOT/.github/workflows/ci.yml" | head -n1
}

# The org login and the Claude marketplace id, read from the same sources the
# scripts read them from, so the suite survives an organization rename or a
# marketplace rename without touching a single fixture.
fleet_org() {
  jq -r '.organization' "$BATON_ROOT/structure/repos.json"
}

fleet_plugin_id() {
  printf 'scenerystack@%s\n' "$(jq -r '.name' "$BATON_ROOT/.claude-plugin/marketplace.json")"
}

# check-repo-compliance.sh queries live GitHub security settings when `gh` is
# installed and authenticated. Shadow it with a stub that fails `auth status` so
# the suite is hermetic and offline: the script takes its documented
# "gh not available" branch (a warning, not a failure).
stub_gh() {
  STUB_BIN="$BATS_TEST_TMPDIR/stub-bin"
  mkdir -p "$STUB_BIN"
  cat >"$STUB_BIN/gh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
  chmod +x "$STUB_BIN/gh"
}

# Run the compliance checker against a fixture repo with `gh` stubbed out.
run_compliance() {
  run env PATH="$STUB_BIN:$PATH" "$BATON_ROOT/scripts/check-repo-compliance.sh" "$1"
}

# Build a simulation repo fixture that satisfies every compliance rule.
# Individual tests copy this and break exactly one thing, so a rule that stops
# firing shows up as a failing test rather than a silently green audit.
make_compliant_sim() {
  local dir="$1"
  local major
  major="$(fleet_node_major)"

  mkdir -p "$dir"/{.github/workflows,.claude,.githooks,doc,tests,src/{preferences,i18n,intro/{model,view}}}

  cat >"$dir/README.md" <<'EOF'
# Fixture Sim

A compliant SceneryStack simulation fixture.

## Features

- Does physics.

## Quick Start

```sh
npm install
```

## Scripts

- `npm run dev`

## Tech Stack

- SceneryStack

## License

AGPL-3.0.

## Contributing

See the org defaults.
EOF

  local org plugin_id
  org="$(fleet_org)"
  plugin_id="$(fleet_plugin_id)"

  cat >"$dir/.github/workflows/ci.yml" <<EOF
name: CI
on: [push, pull_request]
jobs:
  ci:
    uses: ${org}/Baton/.github/workflows/ci.yml@main
  dependency-review:
    uses: ${org}/Baton/.github/workflows/shared-dependency-review.yml@main
  codeql:
    uses: ${org}/Baton/.github/workflows/shared-codeql.yml@main
EOF

  cat >"$dir/.github/dependabot.yml" <<'EOF'
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
EOF

  # `prepare` must stay on one line: the compliance check matches
  # "prepare".*core\.hooksPath \.githooks within a single line.
  cat >"$dir/package.json" <<EOF
{
  "name": "fixture-sim",
  "version": "1.0.0",
  "description": "Fixture sim.",
  "type": "module",
  "keywords": ["simulation", "pwa"],
  "engines": { "node": ">=${major}" },
  "scripts": {
    "prepare": "git config core.hooksPath .githooks",
    "test": "vitest run",
    "test:fuzz": "tsx scripts/test-fuzz.ts",
    "icons": "tsx scripts/generate-icons.ts"
  },
  "devDependencies": {
    "@types/node": "^${major}.0.0",
    "@biomejs/biome": "2.3.14",
    "vite-plugin-pwa": "^1.0.0"
  }
}
EOF

  cat >"$dir/biome.json" <<'EOF'
{
  "$schema": "https://biomejs.dev/schemas/2.3.14/schema.json"
}
EOF

  cat >"$dir/.claude/settings.json" <<EOF
{
  "extraKnownMarketplaces": {
    "${plugin_id#scenerystack@}": { "source": { "source": "github", "repo": "${org}/Baton" } }
  },
  "enabledPlugins": { "${plugin_id}": true }
}
EOF

  # Bootstrap chain — main.ts must import ./brand.js first.
  cat >"$dir/src/main.ts" <<'EOF'
import "./brand.js";
import "./init.js";
EOF
  for f in assert splash brand; do
    echo "export {};" >"$dir/src/$f.ts"
  done
  cat >"$dir/src/init.ts" <<'EOF'
import { version } from "../package.json";
export const simVersion = version;
EOF

  echo "export default {};" >"$dir/src/FixtureSimNamespace.ts"
  echo "export default {};" >"$dir/src/FixtureSimColors.ts"
  cat >"$dir/src/FixtureSimConstants.ts" <<'EOF'
import { FixtureSimNamespace } from "./FixtureSimNamespace.js";
export const FixtureSimConstants = {};
FixtureSimNamespace.register("FixtureSimConstants", FixtureSimConstants);
EOF
  echo "export default {};" >"$dir/src/FixtureSimKeyboardHelpContent.ts"
  echo "export default {};" >"$dir/src/intro/view/IntroScreenSummaryContent.ts"

  echo "export default {};" >"$dir/src/preferences/FixtureSimPreferencesModel.ts"
  echo "export default {};" >"$dir/src/preferences/FixtureSimPreferencesNode.ts"
  echo "export default {};" >"$dir/src/preferences/fixtureSimQueryParameters.ts"

  cat >"$dir/src/i18n/StringManager.ts" <<'EOF'
void (stringsEs satisfies typeof stringsEn);
void (stringsEn satisfies typeof stringsEs);
void (stringsFr satisfies typeof stringsEn);
void (stringsEn satisfies typeof stringsFr);
EOF
  for loc in en es fr; do
    echo '{}' >"$dir/src/i18n/strings_$loc.json"
  done

  echo 'import { describeDisposalLeaks } from "./helpers/memoryLeak.js";' >"$dir/tests/memory-leak.test.ts"
  echo "// happy-dom mocks + init()" >"$dir/tests/setup.ts"
  mkdir -p "$dir/tests/fuzz" "$dir/scripts"
  echo "// fuzz smoke" >"$dir/tests/fuzz/fuzz.spec.ts"
  echo "export default {};" >"$dir/playwright.config.ts"
  echo "// fuzz runner" >"$dir/scripts/test-fuzz.ts"
  cat >"$dir/vitest.config.ts" <<'EOF'
export default {
  test: { poolOptions: { forks: { execArgv: ["--expose-gc"] } } }
};
EOF

  for hook in pre-commit pre-push; do
    printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/.githooks/$hook"
    chmod +x "$dir/.githooks/$hook"
  done

  cat >"$dir/.github/workflows/deploy.yml" <<EOF
name: Deploy
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  deploy:
    uses: ${org}/Baton/.github/workflows/deploy.yml@main
EOF

  cat >"$dir/vite.config.ts" <<'EOF'
import { VitePWA } from "vite-plugin-pwa";
export default {
  plugins: [
    VitePWA({
      registerType: "autoUpdate",
      manifest: {
        id: "fixture-sim",
        theme_color: "#1a1a2e",
        background_color: "#1a1a2e",
        categories: ["education", "science"],
        display_override: ["standalone"],
        icons: ["icons/icon-192.png", "icons/icon-512.png", "icons/icon.svg"],
        screenshots: ["screenshots/wide.png", "screenshots/narrow.png"],
      },
    }),
  ],
};
EOF

  cat >"$dir/scripts/generate-icons.ts" <<'EOF'
// writes public/screenshots/wide.png and public/screenshots/narrow.png
EOF

  mkdir -p "$dir/public/icons" "$dir/public/screenshots"
  for f in favicon.ico icons/icon.svg icons/icon-192.png icons/icon-512.png icons/apple-touch-icon.png screenshots/wide.png screenshots/narrow.png; do
    : >"$dir/public/$f"
  done

  cat >"$dir/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta name="theme-color" content="#1a1a2e" />
    <meta name="description" content="Fixture sim." />
    <meta property="og:image" content="icons/icon-512.png" />
    <meta name="twitter:image" content="icons/icon-512.png" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <link rel="apple-touch-icon" href="icons/apple-touch-icon.png" />
  </head>
</html>
EOF

  # Docs must read as filled in, not a copied stub: the check counts non-blank,
  # non-heading lines with no TODO/placeholder marker and wants at least five.
  cat >"$dir/doc/model.md" <<'EOF'
# Model

The model tracks a single particle in one dimension.
Position integrates velocity with a fixed timestep.
Velocity integrates the net applied force over mass.
Energy is reported as the sum of kinetic and potential terms.
Reset restores every Property to its initial value.
EOF

  cat >"$dir/doc/implementation-notes.md" <<'EOF'
# Implementation notes

Each screen owns a model and a view, wired in the screen constructor.
The view listens to model Properties and never writes to them directly.
Disposal is explicit: every listener added is removed in dispose.
Colors resolve through FixtureSimColors so both profiles stay themed.
Strings resolve through StringManager for locale switching at runtime.
EOF
}
