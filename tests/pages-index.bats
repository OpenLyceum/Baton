#!/usr/bin/env bats
#
# Behavioural tests for scripts/generate-pages-index.sh.
#
# The generator turns structure/repos.json into the org landing page. A golden
# file pins the whole rendered output so any change to the page — markup, CSS,
# card layout — has to be deliberate; the targeted tests around it name the
# individual transformations so a failure says what broke, not just "diff".
#
# Regenerate the golden after an intended change:
#   UPDATE_GOLDEN=1 npm test

setup() {
  load 'helpers/common'

  CATALOG="$BATS_TEST_DIRNAME/fixtures/pages-catalog.json"
  GOLDEN="$BATS_TEST_DIRNAME/fixtures/golden/pages-index.html"

  DOCS="$BATS_TEST_TMPDIR/docs"
  SHOTS="$BATS_TEST_TMPDIR/screenshots"
  mkdir -p "$DOCS/assets" "$SHOTS"

  # Only these two sims have a card thumbnail; the rest must fall back to the
  # monogram placeholder. Content is irrelevant — the generator only tests -f.
  : >"$DOCS/assets/betaWave.webp"
  : >"$DOCS/assets/GammaRay.webp"
}

run_pages() {
  # LC_ALL=C keeps the card sort order independent of the developer's locale, so
  # the golden file means the same thing locally and in CI.
  run env LC_ALL=C \
    FLEET_CATALOG="$CATALOG" \
    FLEET_DOCS_DIR="$DOCS" \
    FLEET_SCREENSHOTS_DIR="$SHOTS" \
    "$BATON_ROOT/scripts/generate-pages-index.sh"
}

# Read the generated page (call after run_pages).
page() {
  cat "$DOCS/index.html"
}

@test "generates a page from the fixture catalog" {
  run_pages
  assert_success
  assert_output --partial "Wrote $DOCS/index.html"
  [ -f "$DOCS/index.html" ]
}

@test "output matches the golden page" {
  run_pages
  assert_success

  if [ -n "${UPDATE_GOLDEN:-}" ]; then
    mkdir -p "$(dirname "$GOLDEN")"
    cp "$DOCS/index.html" "$GOLDEN"
    skip "golden regenerated"
  fi

  run diff -u "$GOLDEN" "$DOCS/index.html"
  assert_success
}

@test "does not touch the repo's own docs/ when the output tree is overridden" {
  local before
  before="$(md5sum "$BATON_ROOT/docs/index.html")"
  run_pages
  assert_success
  run md5sum "$BATON_ROOT/docs/index.html"
  assert_output "$before"
}

# ── Row selection ─────────────────────────────────────────────────────────────

@test "buckets simulations by lineage with matching counts" {
  run_pages
  # 3 original, 1 phet, 1 naap out of 8 catalog rows.
  assert_equal "$(page | grep -c 'class="card"')" "5"
  run bash -c "grep -A2 'Core Simulations' '$DOCS/index.html' | grep -o '<span class=\"count\">[0-9]*'"
  assert_output --partial ">3"
  run bash -c "grep -A2 'PhET Ports' '$DOCS/index.html' | grep -o '<span class=\"count\">[0-9]*'"
  assert_output --partial ">1"
  run bash -c "grep -A2 'NAAP Astronomy' '$DOCS/index.html' | grep -o '<span class=\"count\">[0-9]*'"
  assert_output --partial ">1"
}

@test "excludes non-active and non-simulation rows" {
  run_pages
  refute_output --partial "Epsilon Draft"
  page | grep -qv "Epsilon Draft"
  run page
  refute_output --partial "Epsilon Draft"
  refute_output --partial "Zeta Tool"
}

@test "footer reports the total across all three buckets" {
  run_pages
  run page
  assert_output --partial "5 live simulations"
}

# ── Card rendering ────────────────────────────────────────────────────────────

@test "escapes HTML metacharacters in descriptions" {
  run_pages
  run page
  assert_output --partial "Fields, waves &amp; &lt;particles&gt; in one place."
  refute_output --partial "<particles>"
}

@test "caps the rendered topic tags at three" {
  run_pages
  # AlphaSim declares four topics; the fourth must not render.
  run page
  assert_output --partial '<span class="tag">alpha</span>'
  assert_output --partial '<span class="tag">gamma</span>'
  refute_output --partial '<span class="tag">delta</span>'
}

@test "falls back to the repo name when displayName is absent" {
  run_pages
  run page
  assert_output --partial "<h3>omegasim</h3>"
}

@test "derives the card link from deployedUrl, lowercasing the host and dropping the trailing slash" {
  run_pages
  run page
  assert_output --partial 'href="https://exampleorg.github.io/GammaRay/"'
  refute_output --partial "ExampleOrg.github.io"
}

@test "falls back to the conventional Pages URL when deployedUrl is null" {
  run_pages
  run page
  assert_output --partial 'href="https://exampleorg.github.io/AlphaSim/"'
}

@test "renders a thumbnail when the WebP exists" {
  run_pages
  run page
  assert_output --partial 'src="assets/GammaRay.webp"'
  assert_output --partial 'alt="Gamma Ray simulation screenshot"'
}

@test "renders the monogram placeholder when no WebP exists" {
  run_pages
  run page
  # AlphaSim has no asset: placeholder tile carrying its initials.
  assert_output --partial '<div class="thumb placeholder"><span>AS</span></div>'
}

@test "builds the monogram from the first two characters when the name has no capitals" {
  run_pages
  run page
  assert_output --partial "<span>OM</span>"
}

# ── Failure modes ─────────────────────────────────────────────────────────────

@test "fails when the catalog is missing" {
  CATALOG="$BATS_TEST_TMPDIR/nope.json"
  run_pages
  assert_failure
}

@test "fails when the catalog is not valid JSON" {
  CATALOG="$BATS_TEST_TMPDIR/broken.json"
  echo "{ not json" >"$CATALOG"
  run_pages
  assert_failure
}
