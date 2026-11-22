#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  local fixture="$BATS_TEST_TMPDIR/audit"
  mkdir -p "$BATS_TEST_TMPDIR/bin" "$fixture/scripts" "$fixture/structure"
  cp "$BATON_ROOT/scripts/check-uncataloged.sh" "$fixture/scripts/"
  printf '%s\n' '{"organization":"OpenLyceum","repos":[{"name":"CatalogedSim"}]}' >"$fixture/structure/repos.json"
  printf '%s\n' 'PrivateExample' >"$fixture/structure/private-sim-allowlist.txt"
  AUDIT_SCRIPT="$fixture/scripts/check-uncataloged.sh"
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
  unset FLEET_CATALOG OPENPHYSICS_CATALOG OPENPHYSICS_ORG
}

@test "intentional private simulations pass the catalog audit" {
  export TEST_REPOS='[{"name":"CatalogedSim","isPrivate":true},{"name":"PrivateExample","isPrivate":true}]'
  run "$AUDIT_SCRIPT"
  assert_success
}

@test "a formerly private simulation still needs cataloging if it becomes public" {
  export TEST_REPOS='[{"name":"PrivateExample","isPrivate":false}]'
  run "$AUDIT_SCRIPT"
  assert_failure
  assert_output --partial "  - PrivateExample"
}

@test "an unknown private simulation still needs a catalog decision" {
  export TEST_REPOS='[{"name":"OtherSim","isPrivate":true}]'
  run "$AUDIT_SCRIPT"
  assert_failure
  assert_output --partial "  - OtherSim"
}
