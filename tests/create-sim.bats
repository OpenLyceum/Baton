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

@test "create-sim compliance gate uses --local before onboard" {
  run grep -n 'check-repo-compliance' "$BATON_ROOT/scripts/create-sim.sh"
  assert_success
  assert_output --partial "--local"
  # Gate must appear before onboard/catalog work uses GitHub settings sync.
  # Match the invocation (quoted path may sit between .sh and --local).
  local compliance_line onboard_line
  compliance_line="$(grep -nE 'check-repo-compliance\.sh".*--local|--local.*check-repo-compliance' "$BATON_ROOT/scripts/create-sim.sh" | head -1 | cut -d: -f1)"
  # Call sites after the create-from-template branch, not function definitions.
  onboard_line="$(grep -nE '^[[:space:]]+(run_onboard_github|run_onboard_assets|insert_catalog_entry)\b' "$BATON_ROOT/scripts/create-sim.sh" | head -1 | cut -d: -f1)"
  [[ -n "$compliance_line" && -n "$onboard_line" ]]
  [[ "$compliance_line" -lt "$onboard_line" ]]
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
