#!/usr/bin/env bats
#
# create-sim.sh create-time scaffold: flag threading, compliance gate mode, template-only cleanup.

setup() {
  load 'helpers/common'
  stub_gh
  export PATH="$STUB_BIN:$PATH"
}

@test "create-sim --help documents optional starter flags" {
  run "$BATON_ROOT/scripts/create-sim.sh" --help
  assert_success
  assert_output --partial "--with-time-model"
  assert_output --partial "--with-control-options"
  assert_output --partial "--shared-model"
}

make_remote_fixture() {
  export FLEET_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
  export CREATE_TEST_LOG="$BATS_TEST_TMPDIR/calls"
  export CREATE_TEST_TEMPLATE="$BATS_TEST_TMPDIR/template"
  export CREATE_TEST_NODE="$(command -v node)"
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  git config --file "$GIT_CONFIG_GLOBAL" user.email "tests@example.invalid"
  git config --file "$GIT_CONFIG_GLOBAL" user.name "Baton tests"
  make_compliant_sim "$CREATE_TEST_TEMPLATE"
  git -C "$CREATE_TEST_TEMPLATE" init -qb main
  git -C "$CREATE_TEST_TEMPLATE" add -A
  git -C "$CREATE_TEST_TEMPLATE" commit -qm "Create template fixture"
  touch "$CREATE_TEST_LOG"

  cat >"$STUB_BIN/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >>"$CREATE_TEST_LOG"
case "$1 $2" in
  "repo clone") git clone -q "$CREATE_TEST_TEMPLATE" "$4" ;;
  "repo create") git remote add origin "https://example.invalid/$3" ;;
  *) exit 1 ;;
esac
GH
  cat >"$STUB_BIN/npm" <<'NPM'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >>"$CREATE_TEST_LOG"
[[ "$*" != "run check:unused" || "${CREATE_TEST_FAIL_UNUSED:-0}" != 1 ]]
NPM
  cat >"$STUB_BIN/node" <<'NODE'
#!/usr/bin/env bash
if [[ "$1" == */check-template-drift.mjs ]]; then
  exit 0
fi
exec "$CREATE_TEST_NODE" "$@"
NODE
  chmod +x "$STUB_BIN/"{gh,npm,node}
}

@test "create-sim requires a description before contacting GitHub" {
  make_remote_fixture
  run "$BATON_ROOT/scripts/create-sim.sh" --repo WaveLab --name "Wave Lab"
  assert_failure
  assert_output --partial "error: --description is required"
  [[ ! -s "$CREATE_TEST_LOG" ]]
}

@test "create-sim leaves GitHub untouched when a generated fork fails Knip" {
  make_remote_fixture
  export CREATE_TEST_FAIL_UNUSED=1
  run "$BATON_ROOT/scripts/create-sim.sh" --repo WaveLab --name "Wave Lab" --description "Fixture sim."
  assert_failure
  grep -q '^gh repo clone ' "$CREATE_TEST_LOG"
  grep -q '^npm run check:unused$' "$CREATE_TEST_LOG"
  [[ "$(cat "$CREATE_TEST_LOG")" != *"gh repo create "* ]]
}

@test "create-sim leaves GitHub untouched when local compliance fails" {
  make_remote_fixture
  run "$BATON_ROOT/scripts/create-sim.sh" \
    --repo WaveLab --name "Wave Lab" --description "A SceneryStack simulation: Wave Lab."
  assert_failure
  assert_output --partial "package.json description is the rename-sim placeholder"
  [[ "$(cat "$CREATE_TEST_LOG")" != *"gh repo create "* ]]
}

@test "create-sim creates a GitHub repo after source compliance passes" {
  make_remote_fixture
  run "$BATON_ROOT/scripts/create-sim.sh" --repo WaveLab --name "Wave Lab" --description "Fixture sim."
  assert_success
  [[ "$output" == *"Compliance check passed"*'Creating GitHub repo from the validated checkout'* ]]
  grep -q '^npm run check:architecture$' "$CREATE_TEST_LOG"
  grep -q '^npm run check:unused$' "$CREATE_TEST_LOG"
  grep -q '^npm run test$' "$CREATE_TEST_LOG"
  grep -q '^gh repo create .* --source \. --remote origin$' "$CREATE_TEST_LOG"
  ! grep -Eq '^gh (auth|api) ' "$CREATE_TEST_LOG"
}

@test "create-sim --local-only strips demos, drops template-only files, and passes compliance" {
  # Full npm install is heavy; opt in with CREATE_SIM_E2E=1 (generators.test covers the
  # scaffold path; this guards the create-sim shell pipeline including compliance).
  if [[ "${CREATE_SIM_E2E:-}" != "1" ]]; then
    skip "set CREATE_SIM_E2E=1 to run the full local-only create-sim pipeline"
  fi

  WORK="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$WORK"
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  git config --file "$GIT_CONFIG_GLOBAL" user.email "cursor-agent@example.invalid"
  git config --file "$GIT_CONFIG_GLOBAL" user.name "Cursor Agent"

  rsync -a --exclude node_modules --exclude .git --exclude dist \
    "$BATON_ROOT/../SceneryStackTemplate/" "$WORK/SceneryStackTemplate/"
  git -C "$WORK/SceneryStackTemplate" init -b main >/dev/null
  git -C "$WORK/SceneryStackTemplate" add -A >/dev/null
  git -C "$WORK/SceneryStackTemplate" commit -m 'template fixture' >/dev/null
  export FLEET_WORKSPACE="$WORK"

  run env PATH="$STUB_BIN:$PATH" FLEET_WORKSPACE="$WORK" GIT_CONFIG_GLOBAL="$GIT_CONFIG_GLOBAL" \
    "$BATON_ROOT/scripts/create-sim.sh" \
    --repo WaveLab \
    --id wave-lab \
    --name "Wave Lab" \
    --description "Explore how waves overlap and interfere." \
    --screens Intro,Lab \
    --shared-model \
    --local-only \
    --no-push
  assert_success
  assert_output --partial "check-repo-compliance --local"
  assert_output --partial "Bootstrap complete"

  local sim="$WORK/WaveLab"
  [ -d "$sim" ]
  ! grep -R -E '\b(exampleToggle|exampleControl|exampleEnabledProperty)\b' "$sim/src" >/dev/null
  [ ! -f "$sim/src/common/TimeModel.ts" ]
  [ ! -f "$sim/src/common/WaveLabControlOptions.ts" ]
  [ -f "$sim/src/common/WaveLabPanel.ts" ]
  [ -f "$sim/src/common/model/SharedModel.ts" ]
  [ ! -f "$sim/scripts/rename-sim.ts" ]
  [ ! -f "$sim/scripts/scaffold-screens.ts" ]
  [ ! -f "$sim/tests/generators.test.ts" ]
  [ ! -f "$sim/doc/multi-screen.md" ]
  [ ! -f "$sim/doc/improvement-recommendations.md" ]
  grep -q '## Compliance carve-outs' "$sim/AGENTS.md"
  grep -q 'None yet' "$sim/AGENTS.md"
  [ -f "$sim/doc/model.md" ]
  [ -f "$sim/doc/implementation-notes.md" ]
}
