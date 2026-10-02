# GitHub repository settings baseline

Canonical settings for OpenLyceum **simulations** and `SceneryStackTemplate`.
New GitHub repos inherit defaults (wiki on, Projects on, security features off) —
do **not** reverse-engineer a mature sim by hand. Use the machine-readable baseline
and the apply script in this repo instead.

| Artifact | Role |
|---|---|
| [`config/github-repo-baseline.json`](../config/github-repo-baseline.json) | Source of truth (feature flags + security + Pages) |
| [`scripts/sync-github-settings.sh`](../scripts/sync-github-settings.sh) | `--check` drift / `--apply` via GitHub API |
| [`scripts/sync-github-metadata.sh`](../scripts/sync-github-metadata.sh) | Description + homepage + topics from `structure/repos.json` |

## Quick use

```bash
cd Baton

# After creating a new sim (or anytime you suspect drift)
scripts/sync-github-settings.sh --check --repo MyNewSim
scripts/sync-github-settings.sh --apply --repo MyNewSim

# Description + website + topics from the catalog
scripts/sync-github-metadata.sh --repo MyNewSim

# Whole sim fleet + template
scripts/sync-github-settings.sh --check
scripts/sync-github-settings.sh --apply

# Every public/private catalog repo
scripts/sync-github-settings.sh --check --all
scripts/sync-github-settings.sh --apply --all
```

Requires `gh` authenticated with access to update repository settings (`repo` scope).

## What the baseline requires

### Repository features

| Setting | Value |
|---|---|
| Issues | on |
| Wiki | **off** |
| Projects | **off** |
| Downloads | off |
| Default branch | `main` |
| Squash / merge commit / rebase | all allowed (fleet defaults) |
| Auto-merge / update branch / delete branch on merge | off |
| Web commit signoff | off |

### Security (public repos)

| Setting | Value |
|---|---|
| Dependabot vulnerability alerts | on |
| Dependabot security updates | on |
| Secret scanning | on |
| Secret scanning push protection | on |
| Non-provider patterns / validity checks | off (matches fleet majority) |
| Private vulnerability reporting | on (see the org [`SECURITY.md`](https://github.com/OpenLyceum/.github/blob/main/SECURITY.md)) |

### Pages

For repos with GitHub Pages (simulations with a `deployedUrl` / homepage):

| Setting | Value |
|---|---|
| Build type | `workflow` (Source → GitHub Actions) |

Code scanning **default setup** stays not-configured: sims use Baton’s reusable
[`shared-codeql.yml`](../.github/workflows/shared-codeql.yml) instead.

### Out of scope here

- Branch protection (org/policy)
- Contents of `.github/dependabot.yml` — [`sync-dependabot.sh`](../scripts/sync-dependabot.sh)
- Claude plugin settings — [`sync-claude-settings.sh`](../scripts/sync-claude-settings.sh)

## When to run

1. **New sim** — after `create-sim.sh` / “Use this template”, before first release  
   (also listed in [`add-simulation.md`](add-simulation.md)).
2. **Suspected drift** — especially brand-new org repos that still have GitHub defaults.
3. **Periodic audit** — `scripts/sync-github-settings.sh --check` (or `--check --all`).

## Private repositories

Private catalog repos (e.g. `Baseline`) still get vulnerability alerts and feature flags
(wiki/projects off). Secret scanning and private vulnerability reporting may be unavailable
without GitHub Advanced Security; the checker treats those as out of scope for private repos.
