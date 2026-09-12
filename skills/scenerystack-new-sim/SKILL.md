---
name: scenerystack-new-sim
description: Use when creating a new OpenLyceum SceneryStack simulation from SceneryStackTemplate — forking via create-sim.sh or rename + scaffold-screens, fixing post-rename residue, filling keyboard-help stubs, and onboarding into the fleet catalog. Covers the two-step rename/scaffold flow, stray Sim* type aliases, and common bootstrap gotchas.
---

# SceneryStack New Sim

New sims start from [`SceneryStackTemplate`](https://github.com/OpenLyceum/SceneryStackTemplate).
Prefer **`Baton/scripts/create-sim.sh`** — it creates the repo (or adopts `--existing` /
`--local-only`), runs rename + scaffold, `npm run fix`, and `npm run check`. Fleet
onboarding (catalog, screenshot, Pages) is documented in
[`Baton/doc/add-simulation.md`](../../doc/add-simulation.md); this skill covers the
**code** bootstrap and the residue that `tsc`/Biome miss.

## Preferred path

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

Omit `--screens` for a single screen named after `--name`. `--onboard` enables GitHub
Pages and security defaults; `--pr` opens the Baton / OpenLyceum catalog PRs.

## Manual two-step flow

If you used GitHub **Use this template** instead of `create-sim.sh`:

```bash
npm install
npm run rename -- --id my-new-sim --name "My New Sim"   # sim-level rename only
npm run scaffold-screens -- --screens Intro,Lab         # optional --shared-model
npm run fix                                             # required — see below
npm run check && npm run build && npm test
```

`rename` rewrites package metadata / prefixes. `scaffold-screens` emits `src/<kebab>/`
packages from `src/sim-screen/`, writes `common/{Prefix}ScreenIcons.ts`, rewrites
`main.ts` + `StringManager` + locale JSON, then **deletes** the prototype. It is
**one-shot** — a second run exits with "No prototype screen package found". Growing
screens later is by hand (`SceneryStackTemplate/doc/multi-screen.md`).

## Post-rename residue `tsc` will not catch

`rename-sim.ts` renames files and classes, but exported **type aliases** can keep the
`Sim` prefix. Grep and fix by hand:

```bash
grep -rn '\bSim[A-Z_]' src
```

Typical survivors (confirmed across forks):

- `SimA11yStrings` / `SimPreferenceStrings` in `src/i18n/StringManager.ts`
- `SimPanelOptions` in `src/common/<Prefix>Panel.ts`

Also check `package.json` `keywords` (often still the generic template list) and that
`description` / `repository.url` match the new repo.

## Keyboard help is a stub

The scaffolded `*KeyboardHelpContent.ts` documents nothing beyond Tab/Esc and will
pass compliance unchanged — see scenerystack-keyboard-help-dialog for why and how to
fix it. Do this **right after scaffold**, not at release time: it's easy to forget
once the file exists and `tsc`/Biome go green.

## Rules

- Prefer `create-sim.sh` over the manual path; it runs `npm run fix` so Biome
  `organizeImports` noise from rename/scaffold does not land red.
- Always `npm run fix` after a manual rename/scaffold — `check` alone is not enough.
- Run `npm ci` (or `npm install`) in the new tree — do **not** rsync the template's
  `node_modules` (partial tree → `tsx: not found`).
- `git init` the sim **before** `npm install` if starting from a bare copy — the
  template `prepare` script sets `core.hooksPath` and will otherwise write into a
  parent repo's git config.
- Screen folders are concept-named (`horizon-system`, not `*-screen`); classes are
  `<Name>Screen`. Import `TModel` from `scenerystack/joist`, not `scenerystack/sim`
  (see scenerystack-model).
- Wire prefs/query-params under `src/preferences/` as scaffolded (see
  scenerystack-preferences / scenerystack-query-parameters).

## Common mistakes

- Running only `npm run check` after rename → 3–6 Biome import-order failures.
- Leaving `Sim*` type aliases → compiles clean, fails CRC / human rename audit.
- Shipping the keyboard-help stub unchanged → compliance green, dialog useless.
- Calling `scaffold-screens` twice → prototype already deleted; add screens by hand.
- Forgetting fleet onboarding (`repos.json`, screenshot, Pages) → sim invisible to
  bootstrap / landing page (follow `doc/add-simulation.md`, not this skill alone).

Related skills: scenerystack-screen-view, scenerystack-keyboard-help-dialog,
scenerystack-preferences, scenerystack-query-parameters, scenerystack-model,
scenerystack-code-review.
