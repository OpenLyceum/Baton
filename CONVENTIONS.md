# OpenLyceum Codebase Convention

This document defines the **single, shared codebase structure** every OpenLyceum
SceneryStack simulation must follow, so that any contributor (or AI assistant) can move
between sims and find everything in the same place. It is the structural companion to
[ACCESSIBILITY.md](ACCESSIBILITY.md) (which governs the a11y pattern) and to the shared
coding guidance in [.github/CLAUDE.md](https://github.com/OpenLyceum/.github/blob/main/CLAUDE.md).

The canonical reference implementation lives in **`SceneryStackTemplate`**. When in doubt,
copy from the template. New sims are forked from it via `npm run rename`, so they start
conformant by default.

> **Scope:** every active SceneryStack TypeScript simulation in
> [`structure/repos.json`](structure/repos.json) (`isSimulation` + `framework: SceneryStack`)
> plus `SceneryStackTemplate`. As of 2026-09-12 that is 41 sims including ACPhasor,
> BasicCoordinatesAndSeasons, CarnotHeatEngine, HabitableZones, LightPropagation, MotionsOfTheSun,
> Oscilloscope, Precession, SpecialRelativity, SternGerlach, and Zenith. Orchestration (`Baton`)
> and community-health (`.github`) repos follow their own conventions.

## 1. Bootstrap chain

`src/main.ts` must have `import "./brand.js"` as its **very first import**. Never reorder.
See [.github/CLAUDE.md §"Bootstrap import chain"](https://github.com/OpenLyceum/.github/blob/main/CLAUDE.md)
for the full explanation. Every sim has all five bootstrap files:

```
src/init.ts  src/assert.ts  src/splash.ts  src/brand.ts  src/main.ts
```

## 2. Source layout & naming

```
src/
  init.ts assert.ts splash.ts brand.ts main.ts
  <Prefix>Colors.ts          ProfileColorProperty entries (never hardcode color in views)
  <Prefix>Constants.ts       named layout/physics constants
  <Prefix>Namespace.ts       new Namespace("<kebab-id>")  ← MUST be at src/ root
  i18n/                      see §4
  preferences/               see §3
  <screen-name>/             kebab-case; one folder per screen
    <Screen>Screen.ts
    model/                   state, step(dt), reset() — must NOT import from view/
    view/                    Scenery nodes, layout, input
  common/                    shared code for multi-screen sims only
```

- `<Prefix>` is the sim's class prefix (e.g. `DopplerEffect`, `LunarLander`). `<kebab-id>`
  is its kebab-case id (e.g. `doppler-effect`).
- `<Prefix>Namespace.ts` lives at **`src/` root** — not in `common/`.
- Screen folders are **kebab-case** (`single-oscillator/`, `more-features/`). Single-screen
  sims still use a screen folder (e.g. `doppler-effect/`).
- There is **no top-level `src/model/` or `src/view/`** — `model/`/`view/` live inside a
  screen folder (or `common/`).
- Sim-specific extra root files are allowed when justified (e.g. `<Prefix>Icons.ts`,
  `<Prefix>Strings.ts`); note them in the sim's `CLAUDE.md`.
- **Constants placement:** the default is a single `<Prefix>Constants.ts` at `src/` root.
  A sim may instead keep constants nested (split into topical files under `common/`, or a
  per-screen `model/`) when the domain warrants it — this is a documented-as-allowed
  variation: note the layout in the sim's `CLAUDE.md` (as TheRamp, MazeGame,
  OscillationsAndChaos, and RadioWaves do; VariableStarPhotometry's root file with grouped
  `as const` objects is the same kind of documented variation). Constants must exist
  somewhere under `src/` — no magic numbers inline in model or view code.

## 3. Preferences

```
src/preferences/
  <Prefix>PreferencesModel.ts
  <Prefix>PreferencesNode.ts        the preferences-dialog UI
  <prefix>QueryParameters.ts        camelCase, lowercase first letter
```

The query-parameters file is **lowercase-first camelCase** (`dopplerEffectQueryParameters.ts`),
matching its exported object. **Multi-tab pattern:** a sim with more than one preferences-dialog
tab may split the UI into `<Prefix><Tab>PreferencesNode.ts` files instead of a single
`<Prefix>PreferencesNode.ts` — e.g. OscillationsAndChaos uses
`OscillationsAndChaosSimulationPreferencesNode.ts` + `OscillationsAndChaosAudioPreferencesNode.ts`.
At least one `*PreferencesNode.ts` must exist.

## 4. Internationalization

```
src/i18n/
  StringManager.ts          singleton accessor + compile-time locale-parity checks
  strings_en.json  strings_es.json  strings_fr.json
```

All three locales ship in every sim; a missing key in any locale is a **build error**
(enforced by `satisfies` parity checks in `StringManager.ts`). Never hardcode display text in
views. Accessibility strings live under an `a11y` group — see [ACCESSIBILITY.md](ACCESSIBILITY.md).

## 5. Tests (fleet-standard)

Every SceneryStack sim ships Vitest unit tests under root `tests/` and a `test` script in
`package.json` (CI runs it). Prefer testing the **model** (pure logic, physics, math) — not
Scenery rendering. Algorithm-heavy sims carry denser suites; PhET/NAAP ports often start with
smoke + reset + a memory-leak harness and grow physics invariants over time.

Layout (match the template):

```
tests/
  setup.ts                  vitest setup (Canvas/Audio mocks + init) — see carve-out below
  memory-leak.test.ts       WeakRef + --expose-gc dispose regression (fleet pattern)
  **/*.test.ts              unit tests (mirror the source tree under tests/)
  **/*.spec.ts              Playwright specs, if any (e.g. tests/fuzz/)
vitest.config.ts            root; include: ["tests/**/*.test.ts"];
                            execArgv: ["--expose-gc"] when a memory-leak suite is present
tsconfig.test.json          extends tsconfig.json; include: ["tests"];
                            types: ["node", "vite/client", "vitest/globals"]
```

- `npm run check` typechecks app, scripts, and tests:
  `tsc --noEmit && tsc -p tsconfig.scripts.json --noEmit && tsc -p tsconfig.test.json --noEmit`.
- Tests live **only** under root `tests/`. Do **not** co-locate `*.test.ts` next to source and
  do **not** use `__tests__/` directories.
- The setup file is `tests/setup.ts` (not a root `vitest.setup.ts`). Happy-dom sims wire it via
  `setupFiles: ["./tests/setup.ts"]`.
- The vitest `environment` may vary by sim's needs (`happy-dom` is the template default;
  `jsdom` or `node` are acceptable where justified) — document the choice in the sim's `CLAUDE.md`.
- **Documented carve-out:** pure-math suites that alias `scenerystack` → `scenerystack/dot`
  (jsdom) or run under `node` (no DOM) may omit `tests/setup.ts` / `setupFiles` when no Canvas
  or `init()` is needed — note that in the sim's `CLAUDE.md` (DopplerEffect, VariableStarPhotometry,
  WaveComposer).
- **Memory-leak suite:** every sim ships `tests/memory-leak.test.ts` modeled on
  `SceneryStackTemplate` / `QubitSketch` (dispose in a function boundary → `WeakRef` → `forceGC`).
  Dynamic sims that add/remove nodes at runtime should expand it like `OpticsLab`.

## 6. Documentation

```
doc/model.md                physics, math, behavior (filled, not a stub)
doc/implementation-notes.md  architecture, design decisions (filled)
README.md                   six-section outline (Baton enforces order)
CLAUDE.md                   sim-specific AI/contributor context only
```

`README.md` uses the fixed outline `## Features / Quick Start / Scripts / Tech Stack /
License / Contributing` (enforced by Baton's compliance check). Do **not** add a per-repo
`CONTRIBUTING.md` or `LICENSE` — org defaults apply. `CREDITS.md` is optional.

## 7. Configuration baseline

| File | Standard |
|---|---|
| `biome.json` | versioned `biomejs.dev` `$schema` matching the pinned `@biomejs/biome`; 2-space indent, 120-char width, double quotes, semicolons |
| `tsconfig.json` / `tsconfig.scripts.json` / `tsconfig.test.json` | shared template versions (TS7, `erasableSyntaxOnly`, `verbatimModuleSyntax`); `check` runs `tsc` on all three |
| `package.json` | `scenerystack ^3`, `vite ^8`, `typescript ^7`, `@biomejs/biome ^2.5`, `vitest ^4`; standard `scripts` block |
| `.githooks/{pre-commit,pre-push}` | present; activated via `prepare` script on `npm install` |
| `.github/workflows/ci.yml` | calls `OpenLyceum/Baton` reusable CI + shared security workflows |
| `.github/workflows/deploy.yml` | calls `OpenLyceum/Baton` reusable Pages deploy; `on: push` to `main` **and** `workflow_dispatch` |
| `.github/dependabot.yml` | present (synced from `Baton/config/dependabot-npm.yml`) |

**PWA** (`vite-plugin-pwa`) is fleet-standard. Copy the template's `VitePWA({…})` block, `scripts/generate-icons.ts`, and `index.html` meta; only `id` / `name` / `short_name` / `description` / `theme_color` / screenshot `label` change per sim.

```
scripts/generate-icons.ts
public/favicon.ico
public/icons/icon.svg  icon-192.png  icon-512.png  apple-touch-icon.png
public/screenshots/wide.png  narrow.png   ← 1280×720 and 720×1280; placeholders from `npm run icons`
```

| Piece | Standard |
|---|---|
| `package.json` | `vite-plugin-pwa ^1`, `sharp` + `png-to-ico` + `tsx`, `"pwa"` in `keywords`, `icons` script runs `tsx scripts/generate-icons.ts` (a `generate-svg-icon &&` prefix is allowed) |
| `vite.config.ts` | `registerType: "autoUpdate"`; `includeAssets: ["favicon.ico", "icons/apple-touch-icon.png"]`; manifest `id` (= `package.json` `name`), `categories: ["education", "science"]`, `display: "standalone"`, `display_override: ["window-controls-overlay", "standalone"]`, **no** `orientation`; PNG 192/512 + SVG `purpose: "maskable"`; `screenshots` wide + narrow; Workbox `maximumFileSizeToCacheInBytes` + `globPatterns` including `js,css,html,svg,png,woff2` |
| `index.html` | `mobile-web-app-capable`, `apple-mobile-web-app-capable`, `theme-color` (must match `theme_color`), `description`, Open Graph + Twitter meta (`og:image` / `twitter:image` → `./icons/icon-512.png`), favicon + SVG icon + apple-touch-icon |
| Single-file mode | `vite build --mode single` skips `VitePWA` (inlines into one HTML file). Omit this only when the bundle cannot be self-contained (document in `CLAUDE.md`) |

`theme_color` / icon art may be sim-specific. `background_color` is `#000000` unless the play area is light (document it). Extra Workbox `globPatterns` (audio) or `globIgnores` / `runtimeCaching` (large WASM) are allowed when documented.

**Documented-as-allowed variations** (not violations — note each in the sim's `CLAUDE.md`):
sim-specific `vite.config.ts` plugins (e.g. TrackLab's OpenCV/video serving), `biome.json` /
`.gitignore` additions for vendored binaries or local references, extra `package.json` scripts
(`release` / `serve` / `watch` / domain checks), PWA extras listed above, and the a11y traversal choice (`pdomOrder`
wrapper-Node *or* `pdomPlayAreaNode`/`pdomControlAreaNode`, per
[ACCESSIBILITY.md §3](ACCESSIBILITY.md)).

## 8. Constructor options

Two option styles coexist across the fleet and **both are acceptable** — pick by the shape of the
class rather than converting working code:

- **Explicit params + optional options object.** Leaf classes (and most ScreenViews/models) take a
  typed `options?: <Name>Options` and apply defaults inline (`options?.foo ?? default`), forwarding the
  object to `super`. Simple and the most common — e.g. `BaseScreenView` in OscillationsAndChaos.
- **`optionize`.** When subclassing a SceneryStack type whose `ParentOptions` must be merged with your
  own defaults and forwarded, use
  `optionize<<Name>Options, SelfOptions, ParentOptions>()( { …defaults }, providedOptions )` with the
  `SelfOptions` type declared above the class — e.g. MazeGame's panels and screens.

**`Screen` subclasses are standardized on `optionize`** — the template's `SimScreen`
and every sim follow it, so **don't** hand-spread `{ …defaults, ...options }` into `super(...)`. A
screen that adds no options of its own passes its screen-default block (`backgroundColorProperty`,
`createKeyboardHelpNode`, icons, …) as the defaults and the constructor `options` as the provided arg:
`optionize<<Name>ScreenOptions, EmptySelfOptions, ScreenOptions>()( { …screen defaults }, options )`.
The param stays named `options` here (not `providedOptions`) because the model/view factories read it
directly; extra dependencies carried on the options bag (`preferences`, `viewProperties`, …) flow
through unchanged.

Either way, declare the `SelfOptions` (or `EmptySelfOptions`) and `<Name>Options = SelfOptions &
ParentOptions` types above the class, and **never** use lodash `merge` / `_.extend`. With `optionize`
the incoming parameter is normally named `providedOptions` (the merged result is `options`); the
explicit style names it `options` directly.

## Per-sim checklist (PR sign-off gate)

Most of these are checked automatically by Baton's compliance gate (see Verification); the
rest are a quick manual scan.

- [ ] Bootstrap: `src/{init,assert,splash,brand,main}.ts` exist; `main.ts`'s first import is `./brand.js`. *(auto)*
- [ ] `<Prefix>Namespace.ts` is at `src/` root, not in `common/`. *(auto)*
- [ ] `<Prefix>Colors.ts` exists at `src/` root; constants exist (root file or documented nested layout); no hardcoded colors/magic pixels in views. *(partly manual)*
- [ ] Screen folders are kebab-case with `model/` + `view/`; no top-level `src/model/` or `src/view/`. *(auto warn)*
- [ ] `src/preferences/` has `<Prefix>PreferencesModel.ts`, `<prefix>QueryParameters.ts`, and ≥1 `*PreferencesNode.ts`. *(auto)*
- [ ] `src/i18n/` has `StringManager.ts` + `strings_{en,es,fr}.json`; `npm run check` is green. *(auto)*
- [ ] Any tests live only under root `tests/` with `tests/setup.ts`; no co-located / `__tests__/`. *(auto)*
- [ ] `tests/memory-leak.test.ts` exists and `vitest.config.ts` enables `--expose-gc`. *(auto)*
- [ ] `*KeyboardHelpContent.ts` exists under `src/` (Keyboard Shortcuts dialog). *(auto)*
- [ ] `.githooks/{pre-commit,pre-push}` present; `prepare` sets `core.hooksPath`. *(auto)*
- [ ] `.github/workflows/deploy.yml` calls Baton's reusable Pages deploy and allows `workflow_dispatch`. *(auto)*
- [ ] PWA: `VitePWA` manifest has `id`, `categories`, `display_override`, screenshots, no `orientation`; `public/icons/` + `public/screenshots/{wide,narrow}.png` exist; `index.html` has theme-color + OG/Twitter. *(auto)*
- [ ] `doc/model.md` + `doc/implementation-notes.md` exist and are filled. *(auto presence; manual content)*
- [ ] `README.md` follows the six-section outline; no local `CONTRIBUTING.md` / `LICENSE`. *(auto)*
- [ ] `biome.json` `$schema` matches the pinned `@biomejs/biome` (resync with `npx @biomejs/biome migrate --write`); `npm run lint` is green. *(auto)*
- [ ] Any deliberate deviation is documented in the sim's `CLAUDE.md`. *(manual)*

## Verification

- **Automated gate:** `bash ../Baton/scripts/check-repo-compliance.sh <SimDir>` — run from the
  superproject root, this enforces the structural and config rules above (it also runs in CI via
  `Baton/.github/workflows/shared-compliance-check.yml`). It must print `Compliance check passed`.
- **Per sim:** `npm run lint && npm run check && npm run build`, plus `npm test` where tests exist.
- **New sims:** `Baton/scripts/create-sim.sh` (or Use this template + `npm run rename` +
  `npm run scaffold-screens`) produces a sim that passes the
  gate unchanged — that is the regression guarantee.
