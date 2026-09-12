# OpenLyceum Accessibility Convention

This document defines the **single, shared accessibility pattern** every OpenLyceum
SceneryStack simulation must follow, so that all sims behave the same way internally and
present the same experience to assistive-technology users. It is built on SceneryStack's
accessibility toolkit — see https://scenerystack.org/accessibility/a11y_guides.

The canonical reference implementation lives in **`SceneryStackTemplate`**. When in doubt,
copy from the template. New sims are forked from it and therefore start accessible by
default.

> **Scope:** every active SceneryStack TypeScript simulation in
> [`structure/repos.json`](structure/repos.json) (`isSimulation` + `framework: SceneryStack`)
> plus `SceneryStackTemplate`. As of 2026-09-12 that is 41 sims including ACPhasor,
> BasicCoordinatesAndSeasons, CarnotHeatEngine, HabitableZones, LightPropagation, MotionsOfTheSun,
> Oscilloscope, Precession, SpecialRelativity, SternGerlach, and Zenith.
>
> **Fleet status:** structural Layer 1–2 coverage and Layer-3 keyboard drag for play-area
> objects are expected on every active sim (verified weekly by the
> [`fleet-health`](.github/workflows/fleet-health.yml) workflow). Layer-3 keyboard drag is
> required for **play-area objects and
> primary secondary controls** (`RichDragListener` / `KeyboardDragListener` /
> `KeyboardListener`). Pointer-only **chrome** (palette drag previews, axis-resize handles,
> video scrubbers, decorative hit-targets) may stay mouse/touch-only when an equivalent
> keyboard path already exists elsewhere (sliders, toolbar pan, hotkeys).

## The three required layers (this phase)

Voicing / sonification is deferred to a later phase. Every sim must implement these three:

### 1. PDOM names & help text

Every **interactive** node (button, slider, combo box, checkbox, draggable object) has an
`accessibleName`, and an `accessibleHelpText` where a hint adds value. Strings come from
`StringManager` (never hard-coded English). Reuse a control's existing visible label string
for its `accessibleName` where one exists.

```ts
new SomeButton( {
  accessibleName: a11y.controls.startNameStringProperty,
  accessibleHelpText: a11y.controls.startHelpTextStringProperty,
} );
```

### 2. Screen summary

Each `ScreenView` registers a `*ScreenSummaryContent` (extends `ScreenSummaryContent`,
`scenerystack/sim`) via the `screenSummaryContent` option in its `super(...)` call. It
supplies four regions:

- `playAreaContent` — what the play area contains
- `controlAreaContent` — what the controls do
- `currentDetailsContent` — a **live** `DerivedProperty` over model state
- `interactionHintContent` — how to get started

Reference: `SceneryStackTemplate/src/sim-screen/view/SimScreenSummaryContent.ts` (static
details) and `LunarLander/src/lunar-lander/view/LunarLanderScreenSummaryContent.ts` (live
details derived from model Properties).

### 3. Keyboard navigation & help

- Each `ScreenView` establishes an explicit traversal order, interactive nodes in order
  with Reset All last. **`ScreenView` throws if you set `pdomOrder` on itself.** Use either:
  (a) a lightweight wrapper `Node` child whose `pdomOrder` "borrows" the interactive nodes
  (`this.addChild( new Node( { pdomOrder: [ … ] } ) )`, as in the template, TheRamp, TrackLab); or
  (b) the protected `pdomPlayAreaNode` / `pdomControlAreaNode` — add interactive nodes to them
  directly (the PhET-idiomatic structure, as in OscillationsAndChaos). Pick one per sim.
- Every draggable object is operable from the keyboard via `KeyboardDragListener`
  (or `KeyboardListener` for discrete controls).
- Each screen provides a `*KeyboardHelpContent` (extends `TwoColumnKeyboardHelpContent`)
  wired through `createKeyboardHelpNode` in the `Screen`, starting from a
  `BasicActionsKeyboardHelpSection` plus sim-specific sections.

## Required file & string structure (mirror the template)

```
src/
  i18n/
    StringManager.ts          → add getA11yStrings() returning stringProperties.a11y
    strings_en.json           → add an "a11y" group (see below)
    strings_fr.json           → same keys, translated  (build fails otherwise)
    strings_es.json           → same keys, translated
  <screen>/view/
    <Sim>ScreenView.ts        → screenSummaryContent + pdomOrder + accessibleName on controls
    <Sim>ScreenSummaryContent.ts
    <Sim>KeyboardHelpContent.ts
```

The `a11y` string group, at minimum:

```json
"a11y": {
  "screenSummary": {
    "playArea": "...",
    "controlArea": "...",
    "interactionHint": "..."
  },
  "currentDetails": "...",
  "controls": { "<name>Name": "...", "<name>HelpText": "..." }
}
```

The compile-time `satisfies` parity checks in `StringManager.ts` guarantee no locale is
missing an `a11y` key — a missing translation is a **build error**, not a silent gap.

## Per-sim checklist (PR sign-off gate)

Copy this into each sim's accessibility PR and tick every box:

- [ ] `a11y` string group added to `StringManager` and **all** locale JSON files; build is green.
- [ ] Every interactive node has an `accessibleName` (and `accessibleHelpText` where useful).
- [ ] A `*ScreenSummaryContent` exists for each screen and is registered via `screenSummaryContent`.
- [ ] `currentDetailsContent` is a live `DerivedProperty` over model state (not static) where the sim has state.
- [ ] Each `ScreenView` sets an explicit `pdomOrder`.
- [ ] Every draggable object has a `KeyboardDragListener`/`KeyboardListener`.
- [ ] `*KeyboardHelpContent` reflects the sim's actual interactions.
- [ ] Manual check: screen summary reads, all controls are named, Tab order matches `pdomOrder`, `?` dialog is correct.

## Verification

- **Build / parity:** `npm run check` (or `tsc --noEmit`) — fails if any locale lacks an `a11y` key.
- **Manual PDOM:** run `npm run dev`, inspect the parallel DOM in devtools (or SceneryStack's
  a11y view): confirm summary, names, and Tab order.
- **Keyboard:** Tab through all controls, arrow-drag draggable objects, open the `?` help dialog.
- **Consistency:** a sim's `*ScreenSummaryContent` / `*KeyboardHelpContent` should be
  structurally identical to the template's — that structural sameness *is* the synchronicity goal.
