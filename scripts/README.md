# OpenLyceum org scripts

Utilities for reading [`structure/repos.json`](../structure/repos.json) and operating on
OpenLyceum repositories. These scripts are intended for local use and for AI agents working in
the monorepo checkout.

## Prerequisites

- [`jq`](https://jqlang.org/)
- [`gh`](https://cli.github.com/) for GitHub sync commands
- Node.js + `npm install` (in the repo root) for the screenshot and thumbnail scripts — installs Playwright and sharp

## Quick reference

| Script | Purpose |
|---|---|
| [`parse-repos.sh`](parse-repos.sh) | Core parser/CLI for `repos.json` |
| [`list-repos.sh`](list-repos.sh) | Human-friendly listing wrapper |
| [`check-repos-catalog.sh`](check-repos-catalog.sh) | Validate `repos.json` against `structure/repos.schema.json` + fleet invariants |
| [`check-uncataloged.sh`](check-uncataloged.sh) | Detect org repos on GitHub that are missing from `repos.json` (catches un-onboarded repos) |
| [`clone-fleet.sh`](clone-fleet.sh) | Clone/update every catalog repo into the workspace as a sibling |
| [`fleet`](fleet) | Run a git command across every local checkout (`fleet push`, `fleet status -s`, …) |
| [`fleet-exec.sh`](fleet-exec.sh) | Run a command across many repos and open one PR each |
| [`../doc/fleet-git.md`](../doc/fleet-git.md) | Cheat sheet: everyday git across local checkouts (`pull`/`push`/`status` all) |
| [`sync-gitlab-mirror.sh`](sync-gitlab-mirror.sh) | Mirror every catalog repo's git history to a GitLab group (off-GitHub backup) |
| [`../doc/gitlab-mirror.md`](../doc/gitlab-mirror.md) | GitLab backup: setup, initial import, periodic sync, restore |
| [`sync-github-metadata.sh`](sync-github-metadata.sh) | Push description + website + topics to GitHub |
| [`sync-github-settings.sh`](sync-github-settings.sh) | Check/apply GitHub repo settings baseline (security + feature flags) |
| [`../doc/github-repo-settings.md`](../doc/github-repo-settings.md) | Documented GitHub settings baseline for sims |
| [`create-sim.sh`](create-sim.sh) | Bootstrap a new sim from SceneryStackTemplate (rename + N screens; `--onboard` applies the full baseline incl. GitHub settings; `--existing` adopts a repo already on GitHub; `--pr` / `--shared-model`) |
| [`sync-claude-settings.sh`](sync-claude-settings.sh) | Roll the `scenerystack` Claude Code plugin out to sim repos' `.claude/settings.json` |
| [`lib/repos.sh`](lib/repos.sh) | Bash helper functions for other scripts |
| [`check-repo-compliance.sh`](check-repo-compliance.sh) | README/CI/structure compliance (bootstrap, i18n, memory-leak suite, KeyboardHelp, githooks, PWA, …) |
| [`check-template-drift.sh`](check-template-drift.sh) | Content drift of template-owned files / scripts / deps vs SceneryStackTemplate (`--all`, `--fix`); wraps [`check-template-drift.mjs`](check-template-drift.mjs), which reads `config/template-manifest.json` and honours AGENTS.md "Compliance carve-outs" |
| [`check-skills.sh`](check-skills.sh) | Validate the `skills/` collection and its README index (Baton self-check) |
| [`check-node-version.sh`](check-node-version.sh) | Assert fleet Node major agrees across workflows; with sibling checkouts, also engines.node / `@types/node` |
| [`sync-dependabot.sh`](sync-dependabot.sh) | Copy Dependabot configs from `config/` to catalog npm/pip repos (see `structure/repos.json`) |
| [`sync-repo-docs.sh`](sync-repo-docs.sh) | Rewrite org-qualified references in member repos (badges, LICENSE/CONTRIBUTING/SECURITY links, AGENTS.md cross-links, `repository` URLs, Pages URLs, `uses:` calls into Baton) to match the catalog; `--from OldOrg --dry-run` after an org rename |
| [`retrofit-template-hardening.sh`](retrofit-template-hardening.sh) | Run [`retrofit-template-hardening.mjs`](retrofit-template-hardening.mjs) in the current sim (or under `fleet-exec`): idempotently ports hardening from SceneryStackTemplate; `SKIP_NPM_INSTALL`, `SKIP_ICONS`, `SKIP_CHECK` env switches |
| [`generate-pages-index.sh`](generate-pages-index.sh) | Build `docs/index.html` simulation landing page |
| [`make-thumbnails.mjs`](make-thumbnails.mjs) | Downscale `screenshots/*.png` to `docs/assets/*.webp` with sharp |
| [`generate-screenshots.sh`](generate-screenshots.sh) | Capture each sim's screen to `<sim>/assets/screenshot.png` |
| [`refresh-screenshots.sh`](refresh-screenshots.sh) | **One-command full refresh** — chains capture → thumbnails → index (keep the Pages landing page in sync) |
| [`screenshot.mjs`](screenshot.mjs) | Playwright driver behind `generate-screenshots.sh` |
| [`../.github/workflows/refresh-screenshots.yml`](../.github/workflows/refresh-screenshots.yml) | Weekly/manual Pages thumbnail refresh → PR |

## parse-repos.sh

Primary entry point for agents. Reads `structure/repos.json` and adds computed fields:

- `githubHomepage` — normalized Pages URL (`https://openlyceum.github.io/{name}`)
- `localPath` — sibling directory in the workspace checkout
- `localExists` — whether that directory is present locally

```bash
# All repository names
scripts/parse-repos.sh names

# Simulation repos only
scripts/parse-repos.sh names --simulation

# Full JSON with computed fields
scripts/parse-repos.sh list --format json --simulation

# One repo
scripts/parse-repos.sh get DopplerEffect

# Local checkout paths for sims that exist on disk
scripts/parse-repos.sh paths --simulation --require-local

# Run a command per repo (env: REPO_NAME, REPO_DISPLAY_NAME, REPO_LINEAGE, REPO_HOMEPAGE, REPO_PATH, ...)
scripts/parse-repos.sh for-each --simulation -- \
  echo "$REPO_NAME ($REPO_LINEAGE) -> $REPO_HOMEPAGE"

# Catalog summary
scripts/parse-repos.sh summary
```

Filters:

- `--type simulation|template|config|hardware-interface|tool`
- `--status active|template|draft|wip|archived`
- `--lineage original|phet|naap`
- `--simulation` / `--no-simulation`

## clone-fleet.sh

Populate the workspace from the catalog: clone every selected repo as a sibling directory
beside `Baton`. `repos.json` is the single source of truth — there are no submodules, so a
repo appears here the moment it is added to the catalog. Re-runnable and safe: repos already
on disk are skipped unless `--update` is given (which `git pull --ff-only`s them).

The thin [`OpenLyceum` superproject](https://github.com/OpenLyceum/OpenLyceum)'s
`bootstrap.sh` clones `Baton` and then calls this; run it directly once you already have
`Baton`.

```bash
# Clone whatever is missing into the workspace
scripts/clone-fleet.sh

# Only the simulations, and fast-forward any already present
scripts/clone-fleet.sh --simulation --update

# Preview the plan, change nothing (HTTPS instead of SSH)
scripts/clone-fleet.sh --dry-run --https
```

Reuses the same catalog filters as `parse-repos.sh` (`--simulation`, `--type`, `--status`,
`--lineage`, `--only NAME`, `--skip NAME`). Clones over SSH by default; `--https` for
token/anonymous use.

## fleet

Run any git command across every catalog repo already checked out locally:

```bash
# put on PATH once (if ~/.local/bin is already there)
ln -sfn ~/OpenLyceum/Baton/scripts/fleet ~/.local/bin/fleet

fleet push
fleet pull --ff-only
fleet status -s
fleet --simulation log -1 --oneline
```

Same catalog filters as `parse-repos.sh`. Full cheat sheet: [`doc/fleet-git.md`](../doc/fleet-git.md).

## fleet-exec.sh

Fan a change out across the org: clone each selected repo, run a command in it, and
— with `--apply` — push a branch and open one PR per repo. **Dry-run by default** (prints
a diffstat per repo and opens nothing). Reuses the same catalog filters as `parse-repos.sh`.

```bash
# Preview bumping a dependency across every simulation (no PRs):
scripts/fleet-exec.sh --simulation -- npm pkg set dependencies.scenerystack=^3.1.0

# Apply a Biome autofix across all sims and open one PR each:
scripts/fleet-exec.sh --simulation --apply --install \
  --branch chore/biome-fix --title "chore: biome autofix" -- npm run fix
```

Key options: `--apply` (push + open PRs), `--install` (`npm install` before the command,
needed for lint/build codemods), `--branch`, `--title`, `--label`, `--skip NAME`, `--keep`.

Pushing and opening PRs needs a token with **write access to the target repos** — your local
`gh auth`, or an org PAT / GitHub App token as `GH_TOKEN`. The default `GITHUB_TOKEN` only
reaches the repo running a workflow, so the [`fleet-exec.yml`](../.github/workflows/fleet-exec.yml)
dispatch wrapper reads a `FLEET_PAT` secret for `apply=true`.

## sync-gitlab-mirror.sh

Keep an off-GitHub backup of the fleet: push every catalog repo's **git data** — branches,
tags, commits — into a GitLab group. Issues, merge requests, CI, and Pages are not copied,
and are disabled on the projects this script creates. Same command for the first import and
for every later sync; a bare mirror cached per repo makes repeat runs incremental.

```bash
export GITLAB_TOKEN=glpat-…            # api + write_repository scopes

scripts/sync-gitlab-mirror.sh --dry-run    # show the plan, change nothing
scripts/sync-gitlab-mirror.sh              # initial import of the whole fleet
scripts/sync-gitlab-mirror.sh --simulation # later syncs, sims only
scripts/sync-gitlab-mirror.sh --check      # is the backup current? (read-only)
```

Key options: `--group`/`--host` (default `OpenLyceum` on `https://gitlab.com`),
`--visibility private|internal|public` (default private), `--work-dir`, `--fresh`,
`--no-prune`, plus the usual catalog filters. `.github` is mirrored as `dot-github`
(GitLab paths cannot start with a dot).

Runs daily from [`gitlab-mirror.yml`](../.github/workflows/gitlab-mirror.yml) once a
`GITLAB_TOKEN` secret exists on Baton. Setup, verification, and the restore procedure:
[`../doc/gitlab-mirror.md`](../doc/gitlab-mirror.md).

## sync-github-metadata.sh

Updates GitHub **Description**, **Website**, and **topics** from `repos.json`:

```bash
scripts/sync-github-metadata.sh --dry-run
scripts/sync-github-metadata.sh
scripts/sync-github-metadata.sh --repo SceneryStackTemplate
scripts/sync-github-metadata.sh --simulation
```

Simulations get `physics`, `scenerystack`, `simulation`, plus kebab-case slugs of
`physicsTopics` and any `githubTopics` extras (catalog is source of truth; the
topic set is replaced). The template repo also gets `template`. Non-sim /
non-template repos leave topics untouched.

GitHub **Description** prefers `shortDescription` when set, otherwise
`description`. Descriptions longer than 350 characters are truncated with a
warning (GitHub’s API limit). Topics are capped at 20 (GitHub’s limit).

## sync-github-settings.sh

Check or apply the canonical GitHub **repository settings** baseline
([`config/github-repo-baseline.json`](../config/github-repo-baseline.json)): wiki/Projects off,
Dependabot alerts + security updates, secret scanning + push protection, private vulnerability
reporting, and Pages `build_type=workflow`. Full write-up:
[`../doc/github-repo-settings.md`](../doc/github-repo-settings.md).

```bash
scripts/sync-github-settings.sh --check                 # sims + template; exit 1 on drift
scripts/sync-github-settings.sh --apply --repo MyNewSim # fix one repo
scripts/sync-github-settings.sh --apply --all           # every catalog repo
scripts/sync-github-settings.sh --apply --dry-run       # show planned fixes
```

Use this after creating a new sim (GitHub defaults diverge from the fleet) instead of
inspecting a mature sim by hand.

## sync-claude-settings.sh

Roll the [`scenerystack` Claude Code plugin](../.claude-plugin/marketplace.json) out to the
SceneryStack repos by **merging** the canonical keys from
[`config/claude-settings.json`](../config/claude-settings.json) into each repo's
`.claude/settings.json`. It only adds/updates `extraKnownMarketplaces.baton` and
`enabledPlugins["scenerystack@baton"]` — existing keys in a repo's settings are preserved.
Targets every catalog repo whose framework is `SceneryStack`. Writes files only; commit/push (or
fan out as PRs via `fleet-exec.sh`) is left to you.

```bash
scripts/sync-claude-settings.sh --dry-run     # show what would change, write nothing
scripts/sync-claude-settings.sh               # merge into each sibling repo
scripts/sync-claude-settings.sh DopplerEffect # limit to named repo(s)
```

## check-template-drift.sh

Compares sims against the local `SceneryStackTemplate` checkout using
[`config/template-manifest.json`](../config/template-manifest.json):

| Manifest key | Rule |
|---|---|
| `exact` | File identical to the template after substituting the sim's package / repo name |
| `linesSuperset` | Every template line present (`.gitignore`; extra lines allowed) |
| `jsonExtend` | JSON equal to the template except the listed paths, whose arrays may only grow |
| `templateOnly` | Template tooling (`rename`, `scaffold-screens`) must not linger in a sim |
| `forbidden` | Dead or foreign files (`.fuzz-playwright.config.ts`, `CLAUDE.md`, ESLint/Prettier, `.cursor/`) |
| `noTemplateCopies` | Sim docs sharing ≥60% of their lines with the template's copy |
| `packageJson` | Every template script (same command), every template dependency (same version specifier), shared keys in template order with sim-specific entries after, `engines`/`license`/`type`, override keys |

```bash
scripts/check-template-drift.sh --all --quiet     # fleet report, exit 1 on drift
scripts/check-template-drift.sh LadyBug           # one sim
scripts/check-template-drift.sh --fix LadyBug     # copy exact files + scripts, drop template-only/forbidden files
```

A sim approves a deviation by naming the path (or script) in backticks under its
`AGENTS.md` → `## Compliance carve-outs`. **Change template-owned files in the template
first**, then propagate with `--fix`; never hand-edit one in a single sim.

## Self-check scripts

Run by [`baton-selfcheck.yml`](../.github/workflows/baton-selfcheck.yml) on every PR or `main` push that
touches `skills/`, `.claude-plugin/`, `scripts/`, or Baton's own `.github/workflows`/`.github/actions`,
and runnable locally:

```bash
scripts/check-skills.sh         # every skills/<name>/SKILL.md is well-formed and indexed in skills/README.md
scripts/check-node-version.sh   # all setup-node workflows declare the same Node version
```

## Adding a simulation

End-to-end checklist (create repo → `repos.json` → screenshot → WebP → regenerate
`docs/index.html`): [`../doc/add-simulation.md`](../doc/add-simulation.md).

`create-sim.sh --onboard` does the whole thing in one shot — catalog row, screenshot +
WebP + Pages index, **and** the GitHub settings/metadata/Dependabot/Claude baseline.

### Adopting a repo that already exists on GitHub

If the repo was created some other way and just needs fleet onboarding, pass `--existing`
(skip the template/rename/scaffold dance):

```bash
scripts/create-sim.sh --existing --repo HeatTransfer --name "Heat Transfer" --onboard
```

### Catching un-onboarded repos

A repo can exist on GitHub but never make it into `repos.json`, which makes it invisible to
every fleet tool. This check diffs the live org against the catalog (run by `baton-selfcheck`
on PRs touching `scripts/`/`structure/`):

```bash
scripts/check-uncataloged.sh
```

## check-uncataloged.sh

Lists repos under the GitHub org that are missing from `structure/repos.json`, so a
forgotten onboarding can't stay hidden. Intentional non-members (the superproject itself,
the textbook bundle) are kept in an in-script allowlist, extendable via `UNCATALOGED_ALLOWLIST`
or `structure/uncataloged-allowlist.txt`. Requires `gh` (authed) and `jq`; exits 1 if any
uncataloged repo is found.

## generate-screenshots.sh

Captures a screenshot of every SceneryStack simulation into `<sim>/assets/screenshot.png`.
It serves each sim's built `dist/` and renders the requested screen with the sim's **own**
`ScreenshotGenerator` (the same code path as the in-app camera button), so the result is a
clean PNG at the sim's nominal layout — not a raw viewport grab. Multi-screen sims are forced
onto a single screen with `?screens=N`, so the capture is that screen's play area rather than
the home-screen selector.

```bash
# One-time setup: install Playwright (declared in this repo's package.json)
npm install
# If Chromium is not already cached: npx playwright install chromium

# Capture every sim's first screen (reuses dist/ if already built)
npm run screenshots
# or directly:
scripts/generate-screenshots.sh

# Force a rebuild first, capture a specific screen, or limit to some sims
scripts/generate-screenshots.sh --build
scripts/generate-screenshots.sh --screen 2 Resonance OscillationsAndChaos
```

Options: `--build` (force `npm run build`), `--screen N` (default 1),
`--width`/`--height` (default 1154×753, matching existing assets). Trailing positional
arguments limit the run to the named sims.

`screenshot.mjs` is the underlying Playwright driver and can be run on a single dist directory:

```bash
node scripts/screenshot.mjs --dist ../DopplerEffect/dist --out /tmp/shot.png --screen 1
```

It discovers a usable Chromium automatically (Playwright's bundled build, the newest cached
build, or a system Chromium); override with `PLAYWRIGHT_CHROMIUM_EXECUTABLE`.

## refresh-screenshots.sh

One-command, end-to-end refresh of every screenshot and the landing page. It chains the three
pipeline scripts so the step that copies captures into Baton (`make-thumbnails.mjs`) can't be
forgotten — which is otherwise the easy way to leave `https://openlyceum.github.io/Baton/` stale:

1. [`generate-screenshots.sh`](generate-screenshots.sh) — capture `<sim>/assets/screenshot.png`
2. [`make-thumbnails.mjs`](make-thumbnails.mjs) — copy sibling shots → `screenshots/<sim>.png` + `docs/assets/<sim>.webp`
3. [`generate-pages-index.sh`](generate-pages-index.sh) — regenerate `docs/index.html`

```bash
npm run refresh                       # every active sim, screen 1
# or directly:
scripts/refresh-screenshots.sh
scripts/refresh-screenshots.sh --build            # force a rebuild first
scripts/refresh-screenshots.sh Resonance OscillationsAndChaos   # just these sims
```

It accepts the same capture options/positional sims as `generate-screenshots.sh` (`--build`,
`--screen`, `--width`, `--height`) and forwards sim names to both the capture and thumbnail
steps. At the end it prints the exact `git` commands to commit — `assets/screenshot.png` in each
changed sim repo, and `screenshots/` + `docs/` in Baton. Pushing those to `main` auto-deploys:
`screenshots/**` runs [`optimize-assets.yml`](../.github/workflows/optimize-assets.yml) and
`docs/**` runs [`pages.yml`](../.github/workflows/pages.yml).

For a no-human-involved safety net, [`refresh-screenshots.yml`](../.github/workflows/refresh-screenshots.yml)
still runs weekly against live Pages and opens a PR.

## Bash helpers

Source from other scripts:

```bash
source "$(dirname "$0")/lib/repos.sh"
repos_simulation_names | while read -r sim; do
  echo "$sim"
done
```

Or call the CLI directly:

```bash
scripts/parse-repos.sh names --simulation
```

## Workspace layout

Scripts assume the orchestration `Baton` repo lives beside member repos:

```
OpenLyceum/
  Baton/            ← this repo
  DopplerEffect/
  SceneryStackTemplate/
  ...
```

If your checkout differs, set `FLEET_WORKSPACE` or pass `--catalog /path/to/repos.json`.
