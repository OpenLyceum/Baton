#!/usr/bin/env bats
#
# create-sim.sh create-time scaffold: flag threading, template-only cleanup, compliance gate.

setup() {
  load 'helpers/common'
  stub_gh
  WORK="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$WORK"
  # Isolate git identity for disposable repos without touching the real ~/.gitconfig.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  git config --file "$HOME/.gitconfig" user.email "cursor-agent@example.invalid"
  git config --file "$HOME/.gitconfig" user.name "Cursor Agent"
  # Disposable local template snapshot (no node_modules — create-sim will npm install).
  rsync -a --exclude node_modules --exclude .git --exclude dist \
    "$BATON_ROOT/../SceneryStackTemplate/" "$WORK/SceneryStackTemplate/"
  git -C "$WORK/SceneryStackTemplate" init -b main >/dev/null
  git -C "$WORK/SceneryStackTemplate" add -A >/dev/null
  git -C "$WORK/SceneryStackTemplate" commit -m 'template fixture' >/dev/null
  export FLEET_WORKSPACE="$WORK"
  export PATH="$STUB_BIN:$PATH"
}

@test "create-sim --help documents optional starter flags" {
  run "$BATON_ROOT/scripts/create-sim.sh" --help
  assert_success
  assert_output --partial "--with-time-model"
  assert_output --partial "--with-control-options"
  assert_output --partial "--shared-model"
}

@test "create-sim --local-only strips demos, drops template-only files, and passes compliance" {
  # Full npm install is heavy; opt in with CREATE_SIM_E2E=1 (generators.test covers the
  # scaffold path; this guards the create-sim shell pipeline including compliance).
  if [[ "${CREATE_SIM_E2E:-}" != "1" ]]; then
    skip "set CREATE_SIM_E2E=1 to run the full local-only create-sim pipeline"
  fi
  run env PATH="$STUB_BIN:$PATH" FLEET_WORKSPACE="$WORK" \
    "$BATON_ROOT/scripts/create-sim.sh" \
    --repo WaveLab \
    --id wave-lab \
    --name "Wave Lab" \
    --screens Intro,Lab \
    --shared-model \
    --local-only \
    --no-push
  assert_success
  assert_output --partial "check-repo-compliance"
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
