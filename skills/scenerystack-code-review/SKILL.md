---
name: scenerystack-code-review
description: Use to run a pre-release Code Review (CRC) on an OpenLyceum SceneryStack sim built from the SceneryStack template — build/run/fuzz checks, memory-leak audit, performance, usability, i18n, repo-structure conformance, coding conventions, math libraries, maintainability, and accessibility. Trigger when asked to "code review", "do a CRC", "pre-release review", or audit a sim against project standards.
---

# SceneryStack Code Review (CRC)

A Code Review is the pre-release audit of an OpenLyceum sim against project standards. Our sims are
**Vite + TypeScript + Biome** projects forked from `SceneryStackTemplate` (`npm run rename`), so
this checklist is tailored to that layout (`src/`, `doc/`, `public/`, `biome.json`) — **not** the classic
PhET `js/`/grunt layout. Related skills: scenerystack-new-sim, scenerystack-accessibility,
scenerystack-i18n, scenerystack-color-profiles, scenerystack-constants,
scenerystack-query-parameters, scenerystack-preferences, scenerystack-keyboard-help-dialog,
scenerystack-testing.

## How to run a review

1. Create a GitHub issue titled **"Code Review"** labeled `dev:code-review`, assigned to the reviewer.
2. Paste the **Checklist** section below into it (drop this skill's heading/intro).
3. Fill in or delete **Specific Instructions**; replace each `{{ISSUE}}` with a real issue link.
4. Delete or ~~strike through~~ items and whole sections that don't apply (e.g. the sim has no sounds).
5. A checked box means **"reviewed"**, not "no problem here". File problems as side issues that
   reference the review, or as `// REVIEW` comments in the code.

When running this as an automated pass, work top-down: stop at the first **Build & Run** failure and
report it, since later items assume a building sim.

---

## Checklist

### Specific Instructions

*Known failing items, files to skip, incomplete code, shared/common code that also needs review, etc.
Delete if none.*

### Companion Issues

These standard issues should exist and be complete. If any are missing, pause the review.

- [ ] `doc/model.md` — {{ISSUE}}. Describes the model for educators; reviewed by the sim designer.
- [ ] `doc/implementation-notes.md` — {{ISSUE}}. Useful overview for future maintainers.
- [ ] Memory-test results — {{ISSUE}}.
- [ ] Performance testing and sign-off — {{ISSUE}}.
- [ ] Pointer-area review — {{ISSUE}}.
- [ ] If accessibility is included: description review and sign-off — {{ISSUE}}.
- [ ] Credits — {{ISSUE}} (usually finished after release-candidate testing).

### Build & Run

*If any item here fails, pause the review.*

- [ ] `npm run check` passes (`tsc --noEmit` for app, scripts, and tests) with no type errors.
- [ ] `npm run lint` (Biome) reports no errors.
- [ ] `npm test` (Vitest) passes.
- [ ] `npm run build` (`tsc && vite build`) completes without warnings/errors and emits `dist/`.
- [ ] The `dist/` bundle size is reasonable versus comparable sims.
- [ ] The sim starts in both dev (`npm start`) and built (`npm run preview`) modes.
- [ ] No assertion failures with `?ea`.
- [ ] Passes a scenery fuzz test: `?fuzz&ea`.
- [ ] Behaves correctly under shuffled listener order: `?ea&listenerOrder=random` and
  `?ea&listenerOrder=random&fuzz`.
- [ ] No deprecation warnings with `?deprecationWarnings`; no deprecated APIs in new code.

### Memory Leaks

- [ ] `tests/memory-leak.test.ts` exists and passes under `npm test` (WeakRef +
  `execArgv: ["--expose-gc"]` in `vitest.config.ts` — see scenerystack-testing / CONVENTIONS §5).
  Confirm `forceGC` is called **with** the `WeakRef`(s) so the helper early-exits (bare
  `forceGC()` can hit Vitest's timeout).
- [ ] A Chrome DevTools heap comparison shows no leak. Build with mangling disabled for readable names
  (e.g. `vite build --minify false`). Compare against the responsible dev's results: {{ISSUE}}.
- [ ] Every SceneryStack component that registers internal observers/listeners is `dispose()`d where
  needed. Disposal may be unnecessary for a node that lives in a `ScreenView` never removed from the
  scene graph — document that reasoning when relying on it.
- [ ] Registrations are paired with cleanup unless documented otherwise:
  - `Property.link` / `lazyLink` ↔ `unlink`.
  - `Multilink.multilink` ↔ `unmultilink`; `new Multilink(...)` ↔ `.dispose()`.
  - `new DerivedProperty(...)` ↔ `.dispose()`.
  - `Emitter.addListener` ↔ `removeListener` (including `ObservableArray` element emitters).
  - `Node.addInputListener` ↔ `removeInputListener`.
- [ ] Every class needing teardown has a `dispose()`. Acceptable patterns: a private
  `this.dispose{{ClassName}}()` callback invoked from `dispose()`; `Disposable` / `disposeEmitter`; or
  direct `super.dispose()` + `child.dispose()`.
- [ ] Classes that intentionally don't clean up set `isDisposable: false` or call
  `Disposable.assertNotDisposable()`, so a stray `dispose()` can't silently leak.

### Performance

- [ ] Play through the sim; note any obvious issues (animation slowing with object count, GC hitches).
- [ ] If WebGL is used, there is a Canvas/SVG fallback that performs acceptably (`?webgl=false`).
- [ ] If WebGPU is used, the no-adapter path is deliberate (message / degraded UI) and any
  Playwright engine suite documents the required Chromium launch flags (see scenerystack-testing).

### Usability

- [ ] Continuous controls (sliders especially) feel responsive.
- [ ] Pointer areas are optimized for touch (`?showPointerAreas`).
- [ ] Pointer areas don't overlap inappropriately (`?showPointerAreas`). Overlap may be fine given
  z-ordering and whether objects move.

### Internationalization

See scenerystack-i18n and scenerystack-strings. Strings live in `src/i18n/strings_en.json` and are
accessed through `src/i18n/StringManager.ts`.

- [ ] Dynamic layout survives runtime locale switching: `?stringTest=dynamic`, then left/right arrows.
- [ ] All user-visible strings are externalized; layout handles short strings (`?stringTest=X` shows
  only `X`s).
- [ ] Layout handles long strings (`?stringTest=double` and `?stringTest=long`).
- [ ] Negative numbers render correctly in RTL (`?stringTest=rtl`); use `StringUtils.toFixedLTR` /
  `toFixedNumberLTR` where needed.
- [ ] No external redirect on `?stringTest=xss` (a crash/failed start is acceptable; a redirect is not).
- [ ] No string concatenation for user-visible text — use `StringUtils.fillIn` with a pattern.
- [ ] Named placeholders (`"{{value}} {{units}}"`), not numbered (`"{0} {1}"`).
- [ ] String keys in `strings_en.json` follow project key conventions; keys are hard to change after
  publication.
- [ ] If previously released, no original string keys changed without deliberate discussion.

### Repository Structure

Run the automated gate first — it already covers most of this, so don't re-derive file layout
by hand:

- [ ] `bash ../Baton/scripts/check-repo-compliance.sh <SimDir>` prints `Compliance check
  passed`. On its own this verifies: no root `LICENSE`/`CONTRIBUTING.md`; the `README.md`
  six-section outline; CI/deploy workflow wiring and Dependabot; the bootstrap chain
  (`src/{init,assert,splash,brand,main}.ts`, `main.ts` importing `./brand.js` first);
  `<Prefix>Namespace.ts` / `<Prefix>Colors.ts` / `*Constants.ts` at `src/` root;
  `src/preferences/` and `src/i18n/` file presence plus locale parity; `tests/` layout, the
  memory-leak suite, and `--expose-gc`; `.githooks/`; the PWA manifest, assets, and
  `index.html` meta; the `biome.json` schema pin; and repo security settings. If it fails,
  fix that first — see [`CONVENTIONS.md`](../../CONVENTIONS.md) §"Per-sim checklist" for the
  full auto/manual split.

What the gate can't judge — check these by eye:

- [ ] Repo name matches the sim title (e.g. "The Ramp" → `TheRamp`).
- [ ] No stray `Sim*` **filenames, class names, or exported type aliases** survive
  `rename`/`scaffold-screens` (`grep -rn '\bSim[A-Z_]' src`) — `tsc`/Biome won't flag
  `SimA11yStrings` / `SimPreferenceStrings` / `SimPanelOptions` (see scenerystack-new-sim).
- [ ] Each screen's `*KeyboardHelpContent.ts` is filled in, not the template stub — the gate
  only checks the file exists (see scenerystack-keyboard-help-dialog).
- [ ] Filenames use one consistent prefix (full name or an all-uppercase abbreviation unique
  across repos) — never mixed forms like `TheRampConstants` and `TRColors` in one repo.
- [ ] Icons are generated from `public/icons/icon.svg` via `npm run icons`, not hand-edited
  PNGs that drift from the source.
- [ ] Colors go through `SimColors.ts` `ProfileColorProperty`s, including canvas
  `fillStyle`/`addColorStop` theme chrome — raw hex in a view fails projector/dark profile
  (see scenerystack-color-profiles).
- [ ] Public-facing query parameters are marked `public: true`; debug-only ones are not (see
  scenerystack-query-parameters).
- [ ] Any nested topical constants files (beyond the root `{Prefix}Constants.ts`) are
  documented in `CLAUDE.md` (see scenerystack-constants).
- [ ] GPU-only field state lives under a documented `src/common/gpu/` carve-out with
  parameters in `model/` (see scenerystack-model).
- [ ] `package.json` has no unused dependencies; no dev-only relaxations left in
  `tsconfig*`/`vite.config.ts`/`vitest.config.ts`/`biome.json` (disabled lint rules, loosened
  `strict`/type checks, debug flags).
- [ ] No stale branches that should be deleted.

### Coding Conventions

- [ ] Code generally follows SceneryStack/PhET conventions and the repo's CLAUDE.md guidance. Confirm
  it meets project standards — no need to check every item exhaustively.
- [ ] `npm run fix` (Biome) introduces no changes, i.e. formatting and import ordering are already
  clean.
- [ ] Numbers are formatted with `toFixed`/`toFixedNumber` from `scenerystack/dot` (never
  JavaScript's native `Number.toFixed` — cross-browser rounding inconsistencies). See
  scenerystack-numerics.

### Organization, Readability & Maintainability

- [ ] Code organization makes sense; model/view contain the expected types; code names match UI names.
- [ ] Appropriate design patterns are used; favor composition over inheritance where it fits; the type
  hierarchy is sensible.
- [ ] No unnecessary coupling — pass only what's needed. Narrow constructor APIs with separate params
  or TypeScript `Pick<>`:

  ```ts
  class MyNode {
    public constructor(
      tickMarksVisibleProperty: Property<boolean>,
      model: Pick<MyModel, "changeWaterLevel">, // only the slice we need
      providedOptions?: MyNodeOptions
    ) {}
  }
  ```

- [ ] No unnecessary decoupling — pass an object instead of all its fields when that reads clearer.
- [ ] Source files are reasonably sized; flag large multi-responsibility files. Find them with:

  ```sh
  cd src && wc -l $(find . -name "*.ts") | sort -n
  ```

- [ ] No significant duplicated blocks; anything reusable is lifted into `src/common/` or shared code.
- [ ] No leftover `TODO` / `FIXME` / `REVIEW` comments — resolve them or promote to GitHub issues.
- [ ] No undocumented magic numbers; extract them as named, documented constants.
- [ ] Constants shared across files are centralized in `src/{Prefix}Constants.ts` (plus any
  documented nested extras); the sim doesn't silently break when plausible constant values change.
- [ ] `PhetColorScheme` is used for standardized colors rather than re-inventing them; note any colors
  worth contributing upstream.
- [ ] Dependent Properties are `DerivedProperty`, not hand-synced plain `Property`s.
- [ ] All time-stepping runs through the sim's `step(dt)` chain — no `window.setTimeout` /
  `setInterval` for model time. Real-time / DOM / Web-Audio teardown timers are fine when
  documented; prefer `stepTimer.setTimeout` for sim-clock-aligned delays.
- [ ] Broadband / multi-wavelength colour sums use linear light (CIE XYZ), not averaged
  `VisibleColor` / sRGB (see scenerystack-custom-drawing).

### Accessibility

*Omit if the sim has no accessibility instrumentation; skip subsections that don't apply.* See
scenerystack-accessibility and the repo's `SimScreenSummaryContent.ts` / `SimKeyboardHelpContent.ts`.

**General**

- [ ] A11y uses maintainable SceneryStack patterns (PDOM naming, accessible responses, screen summary).

**Alternative Input**

- [ ] Passes the keyboard fuzz test: `?fuzzBoard&ea`.
- [ ] Traversal order is set via `ScreenView.pdomPlayAreaNode.pdomOrder` and
  `pdomControlAreaNode.pdomOrder`.
- [ ] `KeyboardListener` keys are defined with `HotkeyData`, shared between the listener and the
  keyboard-help dialog so each binding lives in one place.
- [ ] Keyboard-help content documents the controls users actually have (not the template stub).
- [ ] No sim shortcuts collide with global SceneryStack shortcuts.

**Interactive Description**

- [ ] axe DevTools reports no accessibility violations.
- [ ] Resetting the sim also resets the PDOM.
- [ ] Accessibility strings avoid ASCII-only transforms like `toUpperCase()` (they will be translated).
- [ ] Accessibility strings have no leading space before a terminal period (some screen readers read
  ` .` as "dot").

---

*PhET-iO is not used in OpenLyceum template sims; if a sim adds it, review against the upstream PhET-iO
instrumentation guide separately.*
