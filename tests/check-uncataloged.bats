#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  mkdir "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo list") printf '%s\n' "$TEST_REPOS" ;;
  "api orgs/OpenLyceum") jq '[.[] | select(.isPrivate)] | length' <<< "$TEST_REPOS" ;;
  *) exit 1 ;;
esac
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  unset UNCATALOGED_ALLOWLIST UNCATALOGED_ALLOWLIST_FILE FLEET_ORG
  export FLEET_CATALOG="$BATON_ROOT/structure/repos.json"
}

@test "intentional private simulations pass the catalog audit" {
  export TEST_REPOS='[{"name":"ImpulseTheorem","isPrivate":true},{"name":"QuantumScattering","isPrivate":true}]'
  run "$BATON_ROOT/scripts/check-uncataloged.sh"
  assert_success
}

@test "a formerly private simulation still needs cataloging if it becomes public" {
  export TEST_REPOS='[{"name":"QuantumScattering","isPrivate":false}]'
  run "$BATON_ROOT/scripts/check-uncataloged.sh"
  assert_failure
  assert_output --partial "  - QuantumScattering"
}

@test "an unknown private simulation still needs a catalog decision" {
  export TEST_REPOS='[{"name":"OtherSim","isPrivate":true}]'
  run "$BATON_ROOT/scripts/check-uncataloged.sh"
  assert_failure
  assert_output --partial "  - OtherSim"
}
