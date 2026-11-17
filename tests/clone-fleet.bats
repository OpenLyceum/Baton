#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  CATALOG="$BATS_TEST_TMPDIR/catalog.json"
  export FLEET_WORKSPACE="$BATS_TEST_TMPDIR"
}

@test "rejects a missing catalog" {
  run "$BATON_ROOT/scripts/clone-fleet.sh" --dry-run --catalog "$CATALOG"
  assert_failure
  assert_output --partial "Could not read repository list from $CATALOG."
  refute_output --partial "Summary:"
}

@test "rejects a malformed catalog before planning any clones" {
  printf '%s\n' '{"repos":[{"name":"ExampleSim"}]}' '{' >"$CATALOG"

  run "$BATON_ROOT/scripts/clone-fleet.sh" --dry-run --catalog "$CATALOG"
  assert_failure
  assert_output --partial "Could not read repository list from $CATALOG."
  refute_output --partial "[dry-run] git clone"
}

@test "accepts a valid catalog with no matching repositories" {
  run "$BATON_ROOT/scripts/clone-fleet.sh" --dry-run --only MissingSim
  assert_success
  assert_output --partial "Summary: 0 repo(s)"
}

@test "previews a repository selected from the catalog" {
  run "$BATON_ROOT/scripts/clone-fleet.sh" --dry-run --only DopplerEffect
  assert_success
  assert_output --partial "DopplerEffect.git $FLEET_WORKSPACE/DopplerEffect"
  assert_output --partial "Summary: 1 repo(s)"
}
