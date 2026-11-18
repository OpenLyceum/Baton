---
name: scenerystack-new-sim
description: Use when creating a sim from SceneryStackTemplate — create-sim.sh or rename+scaffold-screens, Sim* residue, keyboard-help stubs, fleet catalog onboarding.
---

# SceneryStack New Sim

New sims start from [`SceneryStackTemplate`](https://github.com/OpenLyceum/SceneryStackTemplate).
Prefer **`Baton/scripts/create-sim.sh`**. It stages the sim locally, strips demos,
fixes template drift, and runs lint, typecheck, architecture, Knip, unit tests, and
local compliance before creating its GitHub repository. Optional starters default off.
Fleet onboarding (catalog, screenshot, Pages) is documented in
[`Baton/doc/add-simulation.md`](../../doc/add-simulation.md); this skill covers the
**code** bootstrap and the residue that `tsc`/Biome miss.

## Preferred path

```bash
# From the OpenLyceum workspace (Baton sibling to sims)
Baton/scripts/create-sim.sh \
  --repo MyNewSim \
  --name "My New Sim" \
  --description "Explore how waves overlap and interfere." \
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
# Write a one-sentence description of what the sim models in package.json.
npm run scaffold-screens -- --screens Intro,Lab         # optional --shared-model; starters default off
npm run fix                                             # required — see below
../Baton/scripts/check-template-drift.sh --fix MyNewSim # drop one-shot scripts + template-only docs/tests
npm run lint && npm run check && npm run check:architecture && npm run check:unused && npm test
../Baton/scripts/check-repo-compliance.sh --local .
```

`rename` rewrites package metadata / prefixes. `scaffold-screens` emits `src/<kebab>/`
packages from `src/sim-screen/`, writes `common/{Prefix}ScreenIcons.ts`, rewrites
`main.ts` + `StringManager` + locale JSON, strips template demos on forks (no live
`example*` / `exampleEnabledProperty`; commented `showGrid` preference, accessible-control,
and TimeModel patterns stay to copy), drops unused starters
unless `--with-time-model` / `--with-control-options`, writes short `AGENTS.md` /
`doc/model.md` / `doc/implementation-notes.md`, then **deletes** the prototype. It is
**one-shot** — a second run exits with "No prototype screen package found". Growing
screens later is by hand (see the template's `doc/multi-screen.md`; forks drop that file).

## Post-rename residue `tsc` will not catch

`rename-sim.ts` renames files and classes, but exported **type aliases** can keep the
`Sim` prefix. Grep and fix by hand:

```bash
grep -rn '\bSim[A-Z_]' src
```

Typical survivors (confirmed across forks):

- `SimA11yStrings` / `SimPreferenceStrings` in `src/i18n/StringManager.ts`
- `SimPanelOptions` in `src/common/<Prefix>Panel.ts`

## Template placeholders the gate fails on

`create-sim` / fork `scaffold-screens` already strip demos and unused starters. Re-check
only if you skipped scaffold or opted into starters without using them:

- **Description.** Write one real sentence in `package.json` `description`; the rename
  placeholder fails. `vite.config.ts` fills `index.html` (`%SIM_DESCRIPTION%`, Open Graph,
  Twitter) and the PWA manifest from it. Never edit those copies by hand.
- **`exampleToggle` / `exampleControl`.** Must not remain in `src/` (compliance fails).
  Forks start with an empty preferences shell that carries a commented `showGrid`
  pattern; follow it (and scenerystack-preferences) when adding a real preference.
- **`TimeModel` / `*ControlOptions`.** Default off at create time. If you passed
  `--with-time-model` / `--with-control-options`, compose or delete unused copies and keep
  `tests/memory-leak.test.ts` listing real disposables (see scenerystack-testing).
- **Version.** `src/init.ts` already reads `version` from `package.json`. Bump the version with
  `npm version`, never in `init.ts`.

Also check `package.json` `keywords`. Drop `template`. Keep `simulation`, `SceneryStack`,
`interactive`, `physics`, `education`, and `pwa` with that casing, and add domain keywords
around them. `description` / `repository.url` must match the new repo.

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
  `node_modules` (partial tree → missing dev binaries).
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
- Leaving `exampleToggle`, an unused `TimeModel`, or the placeholder description → compliance red.
- Hand-editing `index.html` / manifest descriptions → they come from `package.json`; edit that.
- Forgetting fleet onboarding (`repos.json`, screenshot, Pages) → sim invisible to
  bootstrap / landing page (follow `doc/add-simulation.md`, not this skill alone).

Related skills: scenerystack-screen-view, scenerystack-keyboard-help-dialog,
scenerystack-preferences, scenerystack-query-parameters, scenerystack-model,
scenerystack-code-review.
