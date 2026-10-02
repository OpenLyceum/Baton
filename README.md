# OpenLyceum `Baton`

Orchestration repository for the [OpenLyceum](https://github.com/OpenLyceum) organization. Baton owns
the **operational** side of the org: the reusable CI/CD workflows every simulation calls, the cross-repo
automation scripts, the Dependabot templates, the machine-readable repository catalog, and the GitHub
Pages simulation landing page.

> Community-health defaults (license, contributing, code of conduct, security policy, issue/PR templates,
> org profile) live in [OpenLyceum/.github](https://github.com/OpenLyceum/.github) — GitHub requires those
> in the special `.github` repo so they are inherited org-wide.

## Contents

| Path | Purpose |
|---|---|
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | Reusable CI workflow (audit, lint, type-check, test, build) |
| [`.github/actions/security-audit/action.yml`](.github/actions/security-audit/action.yml) | Composite action used by `ci.yml`: `npm audit` summary, blocks only on high/critical in direct deps |
| [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) | Reusable GitHub Pages deploy workflow |
| [`.github/workflows/shared-codeql.yml`](.github/workflows/shared-codeql.yml) | Reusable CodeQL analysis ([`doc/codeql.md`](doc/codeql.md)) |
| [`.github/workflows/shared-dependency-review.yml`](.github/workflows/shared-dependency-review.yml) | Reusable dependency review |
| [`.github/workflows/shared-compliance-check.yml`](.github/workflows/shared-compliance-check.yml) | README and repo-structure compliance audit; the weekly fleet run covers `active`, `draft` and `wip` sims, since structure rules apply from a sim's first commit |
| [`.github/workflows/pages.yml`](.github/workflows/pages.yml) | Build and deploy the org simulation index to GitHub Pages |
| [`.github/workflows/optimize-assets.yml`](.github/workflows/optimize-assets.yml) | Regenerate WebP card thumbnails from screenshots and commit them back |
| [`.github/workflows/refresh-screenshots.yml`](.github/workflows/refresh-screenshots.yml) | Weekly/manual refresh of card screenshots from live Pages → WebP thumbnails + `docs/index.html` (opens a PR) |
| [`.github/workflows/fleet-exec.yml`](.github/workflows/fleet-exec.yml) | Fan a command across many repos and open one PR each (manual dispatch) |
| [`.github/workflows/fleet-health.yml`](.github/workflows/fleet-health.yml) | Weekly lint / type-check / build / test of every `active` simulation, reported as a table |
| [`.github/workflows/gitlab-mirror.yml`](.github/workflows/gitlab-mirror.yml) | Daily push of every repo's git history to the GitLab backup group |
| [`.github/workflows/sync-dependabot.yml`](.github/workflows/sync-dependabot.yml) | Validate the Dependabot templates |
| [`.github/workflows/baton-selfcheck.yml`](.github/workflows/baton-selfcheck.yml) | Validate Baton's own invariants (skills, catalog schema, Node-version sync, script syntax) |
| [`.github/dependabot.yml`](.github/dependabot.yml) | Dependabot for Baton itself (npm + Actions) |
| [`scripts/`](scripts/) | Repo catalog tools, compliance checks, Dependabot/metadata sync, screenshots |
| [`tests/`](tests/) | Bats tests for the scripts (`npx bats tests/`; run by `baton-selfcheck.yml`) |
| [`screenshots/`](screenshots/) | Full-size sim screenshots the landing-page thumbnails are made from |
| [`config/`](config/) | Canonical Dependabot, Claude-settings, and GitHub-repo-settings baselines |
| [`structure/repos.json`](structure/repos.json) | Machine-readable catalog of org repositories |
| [`structure/repos.schema.json`](structure/repos.schema.json) | JSON Schema for the catalog (`schemaVersion` 1.3.0) |
| [`CONVENTIONS.md`](CONVENTIONS.md) | Shared codebase structure every SceneryStack sim must follow |
| [`ACCESSIBILITY.md`](ACCESSIBILITY.md) | Shared accessibility pattern for SceneryStack sims |
| [`skills/`](skills/) | SceneryStack development reference docs for AI assistants |
| [`.claude-plugin/`](.claude-plugin/) | Marketplace + plugin manifests that package `skills/` as the `scenerystack@baton` Claude Code plugin |
| [`docs/`](docs/) | Generated landing page ([openlyceum.github.io/Baton](https://openlyceum.github.io/Baton/)) |
| [`doc/add-simulation.md`](doc/add-simulation.md) | Checklist for adding a sim to the catalog and landing page |
| [`doc/github-repo-settings.md`](doc/github-repo-settings.md) | GitHub settings/security baseline for sims + apply/check script |
| [`doc/fleet-git.md`](doc/fleet-git.md) | Cheat sheet: everyday git across local checkouts (`pull`/`push`/`status` all) |
| [`doc/fleet-auth.md`](doc/fleet-auth.md) | Setting up the `FLEET_PAT` / GitHub App that lets `fleet-exec` open PRs |
| [`doc/gitlab-mirror.md`](doc/gitlab-mirror.md) | GitLab backup mirror: setup, initial import, periodic sync, restore |

## Claude Code plugin

This repo doubles as a Claude Code [marketplace](.claude-plugin/marketplace.json). It publishes one
plugin, **`scenerystack`**, that bundles the [`skills/`](skills/) reference docs so any sim repo can
load them as a unit instead of vendoring copies. The repo root *is* the plugin
([`.claude-plugin/plugin.json`](.claude-plugin/plugin.json)); its `skills/` are auto-discovered.

Member repos enable it from their `.claude/settings.json` (the canonical keys live in
[`config/claude-settings.json`](config/claude-settings.json)):

```json
{
  "extraKnownMarketplaces": {
    "baton": { "source": { "source": "github", "repo": "OpenLyceum/Baton" } }
  },
  "enabledPlugins": { "scenerystack@baton": true }
}
```

Or interactively: `claude plugin marketplace add OpenLyceum/Baton` then
`claude plugin install scenerystack@baton`. Validate manifest changes with
`claude plugin validate .claude-plugin/marketplace.json`.

Roll it out across the fleet with [`scripts/sync-claude-settings.sh`](scripts/sync-claude-settings.sh),
which merges those keys into every SceneryStack repo's settings without clobbering existing config.

## Shared CI

Each simulation's `.github/workflows/ci.yml` calls the reusable workflows from this repo:

```yaml
jobs:
  ci:
    uses: OpenLyceum/Baton/.github/workflows/ci.yml@main
  dependency-review:
    if: github.event_name == 'pull_request'
    uses: OpenLyceum/Baton/.github/workflows/shared-dependency-review.yml@main
  codeql:
    uses: OpenLyceum/Baton/.github/workflows/shared-codeql.yml@main
```

Optional compliance checking:

```yaml
  compliance:
    uses: OpenLyceum/Baton/.github/workflows/shared-compliance-check.yml@main
    with:
      repo-name: ${{ github.event.repository.name }}
```

`ci.yml` runs the test step automatically when the caller defines a `test` npm script — no per-repo
flag needed. Pass `run-tests: "true"` to force it on (e.g. before a test script exists) or
`run-tests: "false"` to opt out.

Pages deploy (sims that publish to GitHub Pages). Callers use `push` to `main` **and**
`workflow_dispatch`, so a site can be published without waiting for a push (same pair of
triggers as this repo's [`pages.yml`](.github/workflows/pages.yml)):

```yaml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: OpenLyceum/Baton/.github/workflows/deploy.yml@main
    permissions:
      contents: read
      pages: write
      id-token: write
```

## Compliance workflow

[`shared-compliance-check.yml`](.github/workflows/shared-compliance-check.yml) runs weekly (Mondays 06:00 UTC)
and on manual dispatch. It reads [`structure/repos.json`](structure/repos.json), clones each simulation repo,
and runs [`scripts/check-repo-compliance.sh`](scripts/check-repo-compliance.sh). The gate enforces (FAIL
unless marked *(warn)*):

- **Legal & README** — no root `CONTRIBUTING.md` / `LICENSE` (org defaults from `OpenLyceum/.github`);
  `README.md` has the six sections in order with no extras (**Features → Quick Start → Scripts → Tech
  Stack → License → Contributing**).
- **CI wiring** — `.github/workflows/ci.yml` calls this repo's reusable `ci.yml` plus
  [`shared-dependency-review.yml`](.github/workflows/shared-dependency-review.yml) and
  [`shared-codeql.yml`](.github/workflows/shared-codeql.yml); `.github/workflows/deploy.yml`
  calls the reusable Pages deploy and allows `workflow_dispatch`; `.github/dependabot.yml` present.
- **Node pins** — `engines.node` is `>=24` and `@types/node` major is `24` (matching the fleet Node
  version); a `.nvmrc` / `.node-version`, if present, agrees.
- **SceneryStack structure** (sims only) — the five-file bootstrap chain with `main.ts` importing
  `./brand.js` first; `<Prefix>Namespace.ts`, `<Prefix>Colors.ts`, and `*Constants.ts` at the `src/`
  root; the `preferences/` trio; `i18n/` with `StringManager.ts` + `en`/`es`/`fr` locales; a
  `*KeyboardHelpContent.ts`; `.claude/settings.json` enabling the `scenerystack` plugin; no tests
  co-located under `src/`; no top-level `src/model` or `src/view` *(warn)*.
- **Tests, hooks & PWA** — `tests/memory-leak.test.ts` + a `vitest.config.ts` that sets `--expose-gc`;
  `.githooks/{pre-commit,pre-push}` activated via the `prepare` script; `package.json` keywords include
  `simulation`, `SceneryStack`, `interactive`, `physics`, `education`, and `pwa`; `vite-plugin-pwa` manifest
  (`id`, `categories`, `display_override`, screenshots, no `orientation`), `scripts/generate-icons.ts`,
  `public/icons/` + `public/screenshots/{wide,narrow}.png`, and `index.html` theme/OG meta.
- **Docs & tooling** — `doc/model.md` + `doc/implementation-notes.md` present and filled
  *(warn if stub)*; `biome.json` `$schema` version matches the pinned `@biomejs/biome`.
- **GitHub security** (when `gh` is authenticated) — Dependabot vulnerability alerts + security
  updates, and secret scanning on public repos. Fleet-wide feature flags and security settings are
  defined in [`config/github-repo-baseline.json`](config/github-repo-baseline.json); check/apply with
  [`scripts/sync-github-settings.sh`](scripts/sync-github-settings.sh) (see
  [`doc/github-repo-settings.md`](doc/github-repo-settings.md)).

Simulation READMEs use the fixed six-section outline above. Items marked *(warn)* — plus hardcoded
colors and nested constants — surface as **warnings**, not failures: document each as a carve-out
under `## Compliance carve-outs` in the sim's `AGENTS.md`.

Run locally against a checkout:

```bash
scripts/check-repo-compliance.sh /path/to/sim-repo
```

## Repository catalog

[`structure/repos.json`](structure/repos.json) lists all OpenLyceum repositories with metadata
(`displayName`, `lineage`, `upstream`, framework, deployed URL, physics topics,
structured `screens`, optional `githubTopics` / `shortDescription`, `status`, etc.).
Schema: [`structure/repos.schema.json`](structure/repos.schema.json) (validated by
[`scripts/check-repos-catalog.sh`](scripts/check-repos-catalog.sh)). The compliance workflow,
Pages landing page, and the catalog scripts consume this file. Ground-truth upstream references
for sims live in the sibling [`Baseline`](https://github.com/OpenLyceum/Baseline) repo (also
listed here as `type: tool`). See
[`scripts/README.md`](scripts/README.md) for the tooling:

```bash
scripts/check-repos-catalog.sh
scripts/parse-repos.sh names --simulation
scripts/parse-repos.sh names --lineage phet
scripts/list-repos.sh --json
scripts/sync-github-metadata.sh --dry-run
scripts/sync-github-settings.sh --check
```

**Adding a new simulation** (create from template, catalog, screenshot, WebP, Pages,
OpenLyceum README): run
[`scripts/create-sim.sh --onboard`](scripts/create-sim.sh) (add `--pr` to open PRs), then
see [`doc/add-simulation.md`](doc/add-simulation.md) for any remaining hand edits
(`.github` profile tallies). The webpage is generated from `repos.json` + `screenshots/` —
there is no separate Markdown card list to edit.

Scripts assume the `Baton` repo lives beside member repos in a shared workspace; set
`FLEET_WORKSPACE` or pass `--catalog /path/to/repos.json` if your checkout differs.

## Fleet operations

Cross-repo automation, all driven from the catalog:

- **Batch changes** — [`scripts/fleet-exec.sh`](scripts/fleet-exec.sh) clones each selected
  repo, runs a command, and (with `--apply`) opens one PR per repo. Dry-run by default. The
  [`fleet-exec.yml`](.github/workflows/fleet-exec.yml) workflow exposes it as a manual dispatch
  (e.g. bump a shared dependency, run `npm run fix`, apply a codemod). Opening PRs in other
  repos needs a `FLEET_PAT` secret with write access — the default `GITHUB_TOKEN` is scoped to
  Baton only. Setup steps (fine-grained PAT or GitHub App): [`doc/fleet-auth.md`](doc/fleet-auth.md).
- **Health report** — [`fleet-health.yml`](.github/workflows/fleet-health.yml) runs weekly,
  fanning out one matrix job per active simulation (npm download cache reused across runs) to run
  lint, type-check, build, and test, then publishing a pass/fail table to the job summary.
  Read-only; surfaces sims broken by a shared-workflow or dependency change.
- **Compliance audit** — [`shared-compliance-check.yml`](.github/workflows/shared-compliance-check.yml)
  audits README structure and CI wiring across the org. The dispatch/schedule run fans out one
  matrix job per sim and aggregates a single pass/fail table (see above).
- **Everyday git fan-out** — [`doc/fleet-git.md`](doc/fleet-git.md) is a cheat sheet for running
  git across your local checkouts (`pull all`, `push all`, `status all`), built on
  `parse-repos.sh paths`. Use it for ad-hoc local work; use `fleet-exec.sh` to land the same
  change as PRs.
- **Off-GitHub backup** — [`scripts/sync-gitlab-mirror.sh`](scripts/sync-gitlab-mirror.sh) pushes
  every catalog repo's git history (branches, tags, commits — no issues, PRs, CI, or Pages) into a
  GitLab group. The same command does the first import and each later sync;
  [`gitlab-mirror.yml`](.github/workflows/gitlab-mirror.yml) runs it daily once a `GITLAB_TOKEN`
  secret exists, and `--check` verifies the backup is current. Setup and restore procedure:
  [`doc/gitlab-mirror.md`](doc/gitlab-mirror.md).
- **Add a simulation** — [`scripts/create-sim.sh`](scripts/create-sim.sh) bootstraps from
  SceneryStackTemplate; [`doc/add-simulation.md`](doc/add-simulation.md) covers catalog entry,
  screenshot capture, WebP thumbnails, and regenerating the Pages index.

## Node version

The default Node version for the fleet is **`"24"`**, declared in every Baton workflow that
runs `setup-node` — bump them together:

- [`.github/workflows/ci.yml`](.github/workflows/ci.yml) — `node-version` input default
- [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) — `node-version` input default
- [`.github/workflows/fleet-health.yml`](.github/workflows/fleet-health.yml) — `setup-node` step
- [`.github/workflows/fleet-exec.yml`](.github/workflows/fleet-exec.yml) — `setup-node` step
- [`.github/workflows/optimize-assets.yml`](.github/workflows/optimize-assets.yml) — `setup-node` step
- [`.github/workflows/refresh-screenshots.yml`](.github/workflows/refresh-screenshots.yml) — `setup-node` step
- [`.github/workflows/baton-selfcheck.yml`](.github/workflows/baton-selfcheck.yml) — `setup-node` step
- [`.github/workflows/shared-compliance-check.yml`](.github/workflows/shared-compliance-check.yml) — `setup-node` steps (template drift)

[`scripts/check-node-version.sh`](scripts/check-node-version.sh) enforces that they stay in
sync (run in CI by [`baton-selfcheck.yml`](.github/workflows/baton-selfcheck.yml)), so a half-done
bump fails fast instead of drifting silently. When sibling member checkouts are present (local
OpenLyceum workspace), it also asserts each `package.json` matches the same major.

Member repos must keep:

- `engines.node`: `>=24` (floor matching the workflow major)
- `@types/node`: major **24** (Dependabot ignores `@types/node` major bumps — bump
  SceneryStackTemplate and repos together when CI `node-version` changes; see `config/dependabot-npm.yml`)

[`scripts/check-repo-compliance.sh`](scripts/check-repo-compliance.sh) fails a sim if those pins
drift. Prefer no `.nvmrc` / `.node-version`; if present, the major must match the fleet.
