# Adding a simulation to the fleet

Checklist for bringing a new SceneryStack sim into OpenLyceum end-to-end: GitHub repo,
[`structure/repos.json`](../structure/repos.json) catalog entry, screenshots, and the org
landing page at [openlyceum.github.io/Baton](https://openlyceum.github.io/Baton/).

> **Two different lists.** The org **landing page** in Baton (`docs/index.html`) is
> **generated** from `repos.json` plus committed screenshots — no hand-edited card
> Markdown. Separately, the **workspace bootstrapper** repo
> [`OpenLyceum/README.md`](https://github.com/OpenLyceum/OpenLyceum/blob/main/README.md)
> has a **hand-edited** sim list in its `## Layout` table; that file is *not* generated
> from the catalog and must be updated by hand when you add a sim (see §7).

---

## 1. Create the simulation repository

**Preferred — Baton create-sim** (creates the GitHub repo from the template, renames,
scaffolds screens, runs check):

```bash
# From the OpenLyceum workspace (Baton sibling to sims)
Baton/scripts/create-sim.sh \
  --repo MyNewSim \
  --name "My New Sim" \
  --screens Intro,Lab \
  --topics "optics,interference" \
  --shared-model \
  --onboard \
  --pr
```

Omit `--screens` for a single screen named after `--name`. `--shared-model` scaffolds
`src/common/model/SharedModel.ts` (fleet-style composition). `--onboard` inserts the catalog row, captures a
screenshot, builds the WebP card, regenerates `docs/index.html`, and updates the
OpenLyceum README Layout table; `--pr` opens Baton + OpenLyceum PRs.
Pass `--local-only` to bootstrap from a local `SceneryStackTemplate` checkout without
creating a GitHub repo.

**Or — GitHub UI:** open [SceneryStackTemplate](https://github.com/OpenLyceum/SceneryStackTemplate),
click **Use this template**, then in the new clone:

```bash
npm install
npm run rename -- --id my-new-sim --name "My New Sim"
npm run scaffold-screens -- --screens Intro,Lab
npm run check
```

Then confirm:
- `.github/workflows/ci.yml` calls `OpenLyceum/Baton/.../ci.yml@main`
- `.github/workflows/deploy.yml` (or equivalent) calls Baton's reusable Pages deploy and allows `workflow_dispatch`
- README follows the six-section outline (enforced by compliance — see
  [`CONVENTIONS.md`](../CONVENTIONS.md))

In the GitHub repo settings, enable **Pages → Source: GitHub Actions**, then merge a
green `main` build so `https://openlyceum.github.io/<SimName>/` goes live.

---

## 2. Add the catalog entry

Edit [`structure/repos.json`](../structure/repos.json). Insert a new object in `repos`
(keep the list alphabetized by `name` when practical). Active SceneryStack sims look like:

```json
{
  "name": "MyNewSim",
  "displayName": "My New Sim",
  "type": "simulation",
  "isSimulation": true,
  "lineage": "original",
  "upstream": null,
  "language": ["TypeScript"],
  "framework": "SceneryStack",
  "description": "One or two sentences for the landing-page card (can be longer than GitHub’s 350-char About limit).",
  "shortDescription": "Optional shorter blurb used for the GitHub About sidebar (≤350 chars).",
  "deployedUrl": "https://openlyceum.github.io/MyNewSim",
  "physicsTopics": ["topic-a", "topic-b"],
  "githubTopics": ["optional-extra-topic"],
  "screens": [
    { "id": "intro", "title": "Intro" },
    { "id": "lab", "title": "Lab" }
  ],
  "status": "active"
}
```

| Field | Notes |
|---|---|
| `name` | Must match the GitHub repo name (and the sibling folder name in the workspace). |
| `displayName` | Human title on the landing-page card (and for docs). |
| `lineage` | Landing-page bucket: `"original"`, `"phet"`, or `"naap"`. Non-simulations use `null`. |
| `upstream` | For `phet` / `naap` ports: `{ "org", "name", "url" }` pointing at the source lab. Otherwise `null`. |
| `description` | Full blurb on the Pages card. |
| `shortDescription` | Optional. GitHub About text (≤350 chars). When omitted, metadata sync uses `description` (truncated if needed). |
| `deployedUrl` | Canonical Pages URL with lowercase `openlyceum` host (trailing slash optional). |
| `physicsTopics` | Required for simulations (non-empty). Up to three tags are shown on the card; all are slugified into GitHub topics. |
| `githubTopics` | Optional extra kebab-case GitHub topics (e.g. `game`, `pwa`) beyond the base set + `physicsTopics`. |
| `screens` | Required for simulations: `{ "id", "title" }` objects. `id` is kebab-case (usually `src/<id>/`). |
| `status` | `"active"` appears on the landing page and in fleet health. Also: `"draft"` / `"wip"` (in catalog, not shipped), `"archived"` (retained, skipped by Pages/health), `"template"` (seed repo). |

Validate locally:

```bash
scripts/check-repos-catalog.sh
scripts/parse-repos.sh names --simulation | grep MyNewSim
```

---

## 3. Pull the repo into the workspace

From the OpenLyceum workspace root (sibling of `Baton`):

```bash
./bootstrap.sh --update
# or: Baton/scripts/clone-fleet.sh --update
```

Confirm `../MyNewSim` (or `$FLEET_WORKSPACE/MyNewSim`) exists beside `Baton`.

---

## 4. Screenshot → thumbnail → landing page

Asset pipeline (all paths relative to the `Baton` repo):

| Stage | Path | Role |
|---|---|---|
| Sim-owned capture | `<Sim>/assets/screenshot.png` | Fleet-standard capture in the **sim** repo (commit it; all active sims keep one). |
| Baton full-size | `screenshots/<Sim>.png` | Ground truth **in Baton** for the org page. |
| Card thumbnail | `docs/assets/<Sim>.webp` | Lightweight image served by the landing page. |
| Page | `docs/index.html` | Generated HTML (cards come from `repos.json` + thumbnails). |

### Option A — Local (best when the sim is checked out)

From `Baton/` after `npm install` (and `npx playwright install chromium` once):

```bash
# 1. Capture into the sibling sim (builds dist/ if needed)
scripts/generate-screenshots.sh --build MyNewSim

# 2. Copy sibling shot → screenshots/, build WebP under docs/assets/
npm run thumbnails -- MyNewSim
# same as: node scripts/make-thumbnails.mjs MyNewSim

# 3. Regenerate the HTML index from repos.json
npm run pages
# same as: scripts/generate-pages-index.sh
```

`make-thumbnails.mjs` copies `../MyNewSim/assets/screenshot.png` → `screenshots/MyNewSim.png`
when the sibling file exists, then writes `docs/assets/MyNewSim.webp`. Open
`docs/index.html` in a browser to sanity-check the new card (placeholder monogram means the
WebP is still missing).

Commit in the **sim** repo:

- `assets/screenshot.png` (from `generate-screenshots.sh`)

Commit in **Baton** at least:

- `structure/repos.json`
- `screenshots/MyNewSim.png`
- `docs/assets/MyNewSim.webp`
- `docs/index.html` (if your change regenerates it — keep it in sync with the catalog)

### Option B — After Pages is live (CI)

Once `https://openlyceum.github.io/MyNewSim/` deploys, run the
[`refresh-screenshots.yml`](../.github/workflows/refresh-screenshots.yml) workflow
(workflow_dispatch; optional `repos: MyNewSim` input). It captures live Pages, regenerates
WebPs + `docs/index.html`, and opens a PR. Useful for refresh; for a brand-new sim, Option A
is usually faster so the catalog PR can include the card image in one shot.

Pushing `screenshots/**` to `main` also triggers
[`optimize-assets.yml`](../.github/workflows/optimize-assets.yml) to refresh WebPs.

---

## 5. Sync GitHub metadata and fleet config

```bash
# Repository feature flags + security baseline (wiki/projects off, Dependabot,
# secret scanning, private vulnerability reporting, Pages = GitHub Actions).
# Source of truth: config/github-repo-baseline.json — see doc/github-repo-settings.md
scripts/sync-github-settings.sh --apply --repo MyNewSim

# Description + Website + topics on the GitHub repo page
# (simulations: shortDescription or description; physics/scenerystack/simulation
#  + kebab-case physicsTopics + optional githubTopics)
scripts/sync-github-metadata.sh --repo MyNewSim

# Dependabot + Claude settings (operate on every matching local checkout;
# after clone-fleet, your new sim is included automatically)
scripts/sync-dependabot.sh
scripts/sync-claude-settings.sh
```

Open a PR in the **sim** repo for any files those sync scripts change (or commit
directly on a setup branch before the sim’s first release).

---

## 6. Compliance and health

```bash
scripts/check-repo-compliance.sh ../MyNewSim
```

Must print `Compliance check passed`. After merge, the next
[`fleet-health.yml`](../.github/workflows/fleet-health.yml) / compliance matrix run will pick
the sim up automatically from the catalog (no workflow edit required).

---

## 7. Update the workspace README (hand-edited)

The [`OpenLyceum`](https://github.com/OpenLyceum/OpenLyceum) superproject README is **not**
generated. Its `## Layout` table lists every repo type in prose — simulations appear as a
comma-separated row of backtick names:

```markdown
| `BasicCoordinatesAndSeasons`, `DopplerEffect`, … , `Zenith` | simulation | SceneryStack TypeScript simulations. |
```

When you add a sim:

1. Open `OpenLyceum/README.md` on `main`.
2. Append `` `MyNewSim` `` to that simulation row (keep **alphabetical** order with the
   other names).
3. Open a PR in **OpenLyceum** (separate from the Baton catalog PR).

`bootstrap.sh` / `clone-fleet.sh` read `repos.json`, not this README — the table is for
humans cloning the workspace, not for tooling. If you skip this step the sim still clones and
appears on the Baton landing page, but the workspace README will be stale.

---

## 8. Manual counts and prose tallies

Some places still carry a **hand-maintained number** or sim list. Others are **computed from
`repos.json`** when a script or workflow runs — do not edit those by hand.

### Get current counts from the catalog

Run from `Baton/`:

```bash
# Active SceneryStack sims (excludes SceneryStackTemplate, cd48, etc.)
jq '[.repos[] | select(.isSimulation==true and .status=="active")] | length' structure/repos.json

# Landing-page buckets (must match lineage on each row)
jq '[.repos[] | select(.isSimulation==true and .status=="active" and .lineage=="original")] | length' structure/repos.json
jq '[.repos[] | select(.isSimulation==true and .status=="active" and .lineage=="phet")] | length' structure/repos.json
jq '[.repos[] | select(.isSimulation==true and .status=="active" and .lineage=="naap")] | length' structure/repos.json
```

*(As of 2026-09-12 the fleet has **41** active sims: **26** original, **8** PhET, **7** NAAP.)*

### Auto-generated — no manual count edit

| Location | What updates |
|---|---|
| [`docs/index.html`](../docs/index.html) footer | `"N live simulations"` — from [`generate-pages-index.sh`](../scripts/generate-pages-index.sh) (`total_count`) |
| Same file, section headings | Per-bucket counts (`new_count`, `phet_count`, `naap_count`) — same script |
| [`fleet-health.yml`](../.github/workflows/fleet-health.yml) matrix | One job per catalog sim — driven by `repos.json` |
| [`shared-compliance-check.yml`](../.github/workflows/shared-compliance-check.yml) matrix | Same |

Regenerate the landing page after catalog changes: `npm run pages` (see §4).

### Hand-edited when you add a sim

| Location | Repo | What to update |
|---|---|---|
| [`OpenLyceum/README.md`](https://github.com/OpenLyceum/OpenLyceum/blob/main/README.md) `## Layout` | OpenLyceum | Comma-separated sim names (§7) — **no total count** in that file |
| [`.github/profile/README.md`](https://github.com/OpenLyceum/.github/blob/main/profile/README.md) | `.github` | Top stats row `` **N** simulations ``; add a table row under **NAAP**, **PhET**, or **Other simulations** (match `lineage`) |
| [`CONVENTIONS.md`](../CONVENTIONS.md) scope blockquote | Baton | `` As of YYYY-MM-DD that is N sims … `` — bump **N**, date, and example names if you use them |
| [`ACCESSIBILITY.md`](../ACCESSIBILITY.md) scope blockquote | Baton | Same pattern as CONVENTIONS |

The org **profile README** is what visitors see on github.com/OpenLyceum — it is separate from
the Baton landing page and from the workspace bootstrapper README. All three can drift
independently.

---

## Minimal PR checklist

**Sim repo**

- [ ] Created from `SceneryStackTemplate` via `create-sim.sh` or Use this template + rename + scaffold-screens
- [ ] CI + Pages deploy wired; first deploy succeeded
- [ ] `assets/screenshot.png` committed (via `Baton/scripts/generate-screenshots.sh`)
- [ ] `scripts/check-repo-compliance.sh` passes

**Baton**

- [ ] Row added to `structure/repos.json` (`status: "active"`, correct `lineage` / `upstream`, `displayName`, non-empty `screens`)
- [ ] `screenshots/<Sim>.png` committed
- [ ] `docs/assets/<Sim>.webp` committed (or produced by optimize-assets / refresh-screenshots)
- [ ] `docs/index.html` regenerated (`npm run pages`) and committed if it changed
- [ ] `scripts/sync-github-settings.sh --apply --repo <Sim>` applied
- [ ] `scripts/sync-github-metadata.sh --repo <Sim>` applied

**OpenLyceum** (hand-edited — separate PR)

- [ ] `` `MyNewSim` `` added to the simulation row in `OpenLyceum/README.md` `## Layout`

**`.github` org profile** (hand-edited — separate PR)

- [ ] `` **N** simulations `` count updated in `.github/profile/README.md`
- [ ] Table row added under the correct section (NAAP / PhET / Other)

**Baton prose** (optional but recommended when the public count matters)

- [ ] Scope blockquote in `CONVENTIONS.md` and `ACCESSIBILITY.md` (`N sims`, date)

**Verify**

- [ ] Card appears under the right section on a local `docs/index.html` preview
- [ ] After Baton `main` deploy, card appears on https://openlyceum.github.io/Baton/
- [ ] Card links to https://openlyceum.github.io/\<Sim\>/
