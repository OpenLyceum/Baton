#!/usr/bin/env bash
# Detect org repositories that exist on GitHub but are missing from the catalog
# (structure/repos.json). A repo that is never onboarded is invisible to every
# fleet tool — clone-fleet won't clone it, the Pages index won't list it, and the
# settings/dependabot/claude syncs won't reach it. This catches that drift.
#
# Intentional non-members (the superproject itself, textbook bundles, …) are kept
# in an allowlist so they don't trip the check.
#
#   scripts/check-uncataloged.sh                                  # live org vs catalog
#   FLEET_ORG=SomeOrg scripts/check-uncataloged.sh              # audit another org
#   UNCATALOGED_ALLOWLIST="Foo Bar" scripts/check-uncataloged.sh  # extra allowed names
#
# Requires: gh (authed), jq. Exits 1 if any uncataloged repo is found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="${FLEET_CATALOG:-${OPENPHYSICS_CATALOG:-$REPO_ROOT/structure/repos.json}}"
ALLOWLIST_FILE="${UNCATALOGED_ALLOWLIST_FILE:-$REPO_ROOT/structure/uncataloged-allowlist.txt}"
PRIVATE_SIM_ALLOWLIST_FILE="$REPO_ROOT/structure/private-sim-allowlist.txt"

command -v gh >/dev/null 2>&1 || { echo "gh CLI is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
[[ -f "$CATALOG" ]] || { echo "missing catalog: $CATALOG" >&2; exit 1; }

# Read after the jq/catalog guards above, so a missing tool reports cleanly.
ORG="${FLEET_ORG:-${OPENPHYSICS_ORG:-$(jq -r '.organization' "$CATALOG")}}"

if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated; run: gh auth login" >&2
  exit 1
fi

# Default intentional non-members. Augment via $UNCATALOGED_ALLOWLIST
# (whitespace separated) and/or an allowlist file (one name per line).
default_allow="$ORG osbooks-university-physics-bundle"
allow="$default_allow"
[[ -n "${UNCATALOGED_ALLOWLIST:-}" ]] && allow="$allow ${UNCATALOGED_ALLOWLIST}"
if [[ -f "$ALLOWLIST_FILE" ]]; then
  # One name per line; word-splitting into $allow is intentional.
  # shellcheck disable=SC2046
  allow="$allow $(tr '\n' ' ' <"$ALLOWLIST_FILE")"
fi

catalog_names="$(jq -r '.repos[].name' "$CATALOG" | sort -u)"
# Include visibility so we can detect a public-only token (github.token in Actions
# cannot list private org repos, which would hide uncataloged private sims).
org_json="$(gh repo list "$ORG" --limit 200 --json name,isPrivate)"
org_names="$(printf '%s\n' "$org_json" | jq -r '.[].name' | sort -u)"
listed_private="$(printf '%s\n' "$org_json" | jq '[.[] | select(.isPrivate)] | length')"
# shellcheck disable=SC2086  # intentional word-split: allow is whitespace-separated names
allow_names="$(printf '%s\n' $allow | grep -v '^[[:space:]]*$' | sort -u)"
if [[ -f "$PRIVATE_SIM_ALLOWLIST_FILE" ]]; then
  # An exemption on this list applies only while the simulation is private.
  private_sim_names="$(awk 'NF && $1 !~ /^#/ { print $1 }' "$PRIVATE_SIM_ALLOWLIST_FILE" | sort -u)"
  private_org_names="$(jq -r '.[] | select(.isPrivate) | .name' <<< "$org_json" | sort -u)"
  allow_names="$(
    {
      printf '%s\n' "$allow_names"
      comm -12 <(printf '%s\n' "$private_sim_names") <(printf '%s\n' "$private_org_names")
    } | sort -u
  )"
fi

# Org metadata reports how many private repos exist; a short private listing means
# the token cannot see them (typical for GITHUB_TOKEN). Fail rather than report clean.
org_private_total="$(gh api "orgs/$ORG" --jq '.total_private_repos // 0' 2>/dev/null || echo 0)"
if [[ "$org_private_total" =~ ^[0-9]+$ ]] && (( listed_private < org_private_total )); then
  echo "Incomplete GitHub listing for $ORG: saw $listed_private private repo(s), org reports $org_private_total." >&2
  echo "Use a token that can list private org repos (e.g. FLEET_PAT), not a public-only GITHUB_TOKEN." >&2
  exit 1
fi

# uncataloged = (org − catalog) − allow
uncataloged="$(
  comm -23 \
    <(comm -23 <(printf '%s\n' "$org_names") <(printf '%s\n' "$catalog_names")) \
    <(printf '%s\n' "$allow_names")
)"

org_total="$(printf '%s\n' "$org_names" | grep -c . || true)"
catalog_total="$(printf '%s\n' "$catalog_names" | grep -c . || true)"

if [[ -z "$uncataloged" ]]; then
  echo "No uncataloged repos ($catalog_total cataloged, $org_total on GitHub)."
  exit 0
fi

count="$(printf '%s\n' "$uncataloged" | grep -c . || true)"
echo "Found $count uncataloged repo(s) — on GitHub under $ORG but missing from:"
echo "  $CATALOG"
printf '%s\n' "$uncataloged" | sed 's/^/  - /'
echo
echo "Onboard an existing repo with:"
echo "  scripts/create-sim.sh --existing --repo <Name> --name \"<Display Name>\" --onboard"
exit 1
