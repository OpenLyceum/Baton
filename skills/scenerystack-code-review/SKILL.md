---
name: scenerystack-code-review
description: Use when asked to code review, do a CRC, pre-release review, or audit a SceneryStack sim against project standards. Covers build/fuzz, memory leaks, i18n, structure, conventions, and accessibility checklist.
---

# SceneryStack Code Review (CRC)

A Code Review is the pre-release audit of an OpenLyceum sim against project standards. Our sims are
**Vite + TypeScript + Biome** projects forked from `SceneryStackTemplate` (`npm run rename`), so
this checklist is tailored to that layout (`src/`, `doc/`, `public/`, `biome.json`) — **not** the classic
PhET `js/`/grunt layout.

## How to run a review

Choose the requested scope: a targeted functional review follows the relevant model/control paths; a full pre-release CRC uses the checklist below. Read [Functional review checks](references/functional-review.md) when reviewing time controls, recordings, state transitions, numerical solvers, or resource lifecycles.

For a review-only request, report findings, validation, and limitations in the response. Write a report in `doc/` when the requested deliverable calls for one. Create or update GitHub review or companion issues only when the user requests that workflow. For a release CRC, track missing designer, performance, or accessibility sign-offs as release gaps and continue independent source analysis.

Use the existing scripts for lint, app/scripts/test type checks, tests, build, and applicable compliance checks. A failing prerequisite limits what can be validated: investigate/report it, and continue independent source analysis when useful. Distinguish pre-existing failures from regressions. When the user asks for fixes, keep them within the requested scope, preserve unrelated working-tree changes, and add focused regressions where they demonstrate the failure.

Checked checklist boxes mean the item was reviewed; report any finding separately. Distinguish local compliance from unavailable remote security probes. Record actual Node version and any mismatch with the repository requirement (Node 26 and TypeScript 7 fleet-wide). Dependency/security/configuration maintenance does not count as a functional review of physics or controls.

---

## Checklist

### Specific Instructions

*Known failing items, files to skip, incomplete code, shared/common code that also needs review, etc.
Delete if none.*

### Companion Issues

For a full release CRC, track these companion deliverables and their sign-offs. Missing deliverables are release gaps; targeted functional reviews need only the relevant evidence.

- [ ] `doc/model.md` — {{ISSUE}}. Describes the model for educators; reviewed by the sim designer.
- [ ] `doc/implementation-notes.md` — {{ISSUE}}. Useful overview for future maintainers.
- [ ] Memory-test results — {{ISSUE}}.
- [ ] Performance testing and sign-off — {{ISSUE}}.
- [ ] Pointer-area review — {{ISSUE}}.
- [ ] If accessibility is included: description review and sign-off — {{ISSUE}}.
- [ ] Credits — {{ISSUE}} (usually finished after release-candidate testing).

### Build & Run

*Report failing prerequisites and their effect on validation; continue independent source review where possible.*

- [ ] `npm run check` passes (`tsc --noEmit` for app, scripts, and tests) with no type errors.
- [ ] `npm run lint` (Biome, `--error-on-warnings`, including the template's
  `biome-plugins/*.grit` rules) reports no errors.
- [ ] `npm test` (Vitest) passes.
- [ ] `npm run test:architecture` and `npm run check:architecture` (dependency-cruiser
  boundaries; see [`Baton/doc/dependency-cruiser.md`](../../doc/dependency-cruiser.md)) pass.
- [ ] `npm run check:unused` (Knip) passes; Knip is `unused-mode: required` fleet-wide
  ([`Baton/doc/knip.md`](../../doc/knip.md)).
- [ ] `npm run build` (`tsc && vite build`) completes without warnings/errors and emits `dist/`.
- [ ] The `dist/` bundle size is reasonable versus comparable sims.
- [ ] The sim starts in both dev (`npm start`) and built (`npm run preview`) modes.
- [ ] No assertion failures with `?ea`.
- [ ] Passes a scenery fuzz test: `?fuzz&ea`.
- [ ] Behaves correctly under shuffled listener order: `?ea&listenerOrder=random` and
  `?ea&listenerOrder=random&fuzz`.
- [ ] No deprecation warnings with `?deprecationWarnings`; no deprecated APIs in new code.

### Memory Leaks

- [ ] `tests/memory-leak.test.ts` passes under `npm test` and hands the sim's **real**
  disposables (models, and view nodes that link to longer-lived Properties) to
  `describeDisposalLeaks()` from the template-owned `tests/helpers/memoryLeak.ts`. Prefer
  `keepAlive` for external Properties and `expectNoListenerGrowth` for non-disposable owners.
  Empty lists need `{ emptyOk }` plus custom coverage — hollow / TimeModel-only suites fail
  compliance. Inventory gaps are WARN (`Baton/scripts/check-memory-leak-coverage.sh`); list
  missing `dispose()` classes or carve out `` `memory-leak:<Class>` ``.
  `idempotentDispose: true` appears only on objects that promise it. Extra leak tests pass
  their `WeakRef`(s) to `forceGC` (see scenerystack-testing).
- [ ] `npm run test:soak` (template-owned headless + browser leak soaks) for CRC / leak hunts —
  not Fleet Health fuzz. Check the headless coverage line reaches the screen's controls. Optionally also a Chrome DevTools heap comparison with mangling disabled
  (e.g. `vite build --minify false`).
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
- [ ] No string concatenation for user-visible text, and no hand-rolled
  `.replace("{{x}}", …)`. Use `PatternStringProperty` for displayed text and
  `StringUtils.fillIn` for strings built on demand (see scenerystack-i18n).
- [ ] Named placeholders (`"{{value}} {{units}}"`), not numbered (`"{0} {1}"`).
- [ ] String keys in `strings_en.json` follow project key conventions; keys are hard to change after
  publication.
- [ ] If previously released, no original string keys changed without deliberate discussion.

### Repository Structure

Run the automated gates first — do not re-derive file layout by hand. Treat failures as CRC
findings. Full auto/manual split:
[`CONVENTIONS.md`](../../CONVENTIONS.md) §"Per-sim checklist".

- [ ] `bash ../Baton/scripts/check-repo-compliance.sh <SimDir>` prints `Compliance check
  passed`. Report failures; distinguish local checks from unavailable remote probes.
- [ ] `bash ../Baton/scripts/check-template-drift.sh <SimDir>` reports no drift in
  template-owned files or `package.json` scripts, dependencies, and key order. Use
  `--fix` only when the requested fixes include template synchronization.
  A deliberate deviation needs a `**Template drift**` entry under `AGENTS.md`
  ## Compliance carve-outs; prose that merely mentions the file does not count.
- [ ] `node ../Baton/scripts/check-skill-conformance.mjs <Sim>` (sim name) reports no unapproved
  gaps (`--strict` also fails on `warn` probes). Approved deviations are
  `` `skill:<name>` `` bullets under `AGENTS.md` ## Compliance carve-outs.

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
- [ ] Colors go through `<Prefix>Colors.ts` `ProfileColorProperty`s, including canvas
  `fillStyle`/`addColorStop` theme chrome. Raw hex in a view fails the projector/dark
  profile (see scenerystack-color-profiles). The gate only *warns* on hardcoded colors.
- [ ] Public-facing query parameters are marked `public: true`; debug-only ones are not (see
  scenerystack-query-parameters).
- [ ] Any nested topical constants files (beyond the root `{Prefix}Constants.ts`) are
  documented in `AGENTS.md` (see scenerystack-constants).
- [ ] GPU-only field state lives under a documented `gpu/` carve-out with parameters in
  `model/` (see scenerystack-webgpu).
- [ ] `package.json` has no unused dependencies; no dev-only relaxations left in
  `tsconfig*`/`vite.config.ts`/`vitest.config.ts`/`biome.json` (disabled lint rules, loosened
  `strict`/type checks, debug flags).
- [ ] No stale branches that should be deleted.

### Coding Conventions

- [ ] Code generally follows SceneryStack/PhET conventions and the repo's AGENTS.md guidance. Confirm
  it meets project standards — no need to check every item exhaustively.
- [ ] Numbers are formatted with `toFixed`/`toFixedNumber` from `scenerystack/dot` (never
  JavaScript's native `Number.toFixed` — cross-browser rounding inconsistencies). See
  scenerystack-numerics. The template's `no-native-tofixed` Biome plugin flags native calls in
  `src/`; each `biome-ignore lint/plugin/no-native-tofixed` needs a reason. The same goes for the
  `no-math-random`, `no-hardcoded-text` and `no-inline-color` plugins.
- [ ] `npm run lint` verifies formatting and import order without writing files. It runs with
  `--error-on-warnings`, so a `"warn"` rule fails the same as an error. Every `biome-ignore` states a
  specific reason.
- [ ] Text uses `PhetFont` (or a shared font constant), not CSS font strings such as
  `"16px sans-serif"`. Canvas `ctx.font` strings are the exception.
- [ ] No `!` non-null assertions in `src/` without a comment (Biome warns); prefer a narrowing
  check or a throwing helper (see scenerystack-coding-conventions).
- [ ] Sim preferences reach models and views through constructor/screen options, not a
  `getInstance()` singleton or module-level getter (see scenerystack-preferences).

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
- [ ] Flag unresolved `TODO`, `FIXME`, and `REVIEW` comments that affect release readiness.
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
- [ ] Traversal order uses one approved pattern from
  [`ACCESSIBILITY.md`](../../ACCESSIBILITY.md) / scenerystack-accessibility — either a
  wrapper `Node` with `pdomOrder` (template default) **or**
  `pdomPlayAreaNode` / `pdomControlAreaNode`. Never set `pdomOrder` on `ScreenView` itself.
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

## Rules

- Run compliance + template-drift before eyeballing structure; do not duplicate their checklists.
- Report scope, findings, validation, and limitations. Apply fixes only when requested and distinguish pre-existing failures from regressions.
- Checked boxes mean reviewed; report findings separately.
- For time/recording/solver behavior, also read [functional-review.md](references/functional-review.md).

## Common mistakes

- Requiring only `pdomPlayAreaNode`/`pdomControlAreaNode` and failing template-style wrapper `pdomOrder`.
- Re-deriving compliance rules in prose instead of running `check-repo-compliance.sh`.
- Shipping keyboard-help stub content that the gate does not catch.
- Treating a NumberProperty-only memory-leak suite as full coverage (see scenerystack-testing).

---

*PhET-iO is not used in OpenLyceum template sims; if a sim adds it, review against the upstream PhET-iO
instrumentation guide separately.*

Related skills: scenerystack-coding-conventions, scenerystack-testing, scenerystack-disposal,
scenerystack-accessibility, scenerystack-ui-controls, scenerystack-new-sim,
scenerystack-keyboard-help-dialog, scenerystack-webgpu.
