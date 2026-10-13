---
name: scenerystack-ui-controls
description: Use when adding standard UI controls to a simulation — sliders, number spinners, checkboxes, radio buttons, combo boxes, push buttons, the Reset All button, playback controls, or themed Panel/Dialog chrome. Covers the sun and scenery-phet component libraries, the Property-backed value pattern, and wiring controls to model state.
---

# SceneryStack UI Controls

Sims build their controls from two ready-made component libraries — **`scenerystack/sun`** (generic widgets) and **`scenerystack/scenery-phet`** (sim-flavoured widgets) — rather than hand-rolling interactive nodes. Every control is **value-backed by a `Property`**: you hand it a model Property and the control reads/writes it. Don't poll or push values imperatively.

## Where each control lives

| Control | Module | Use for |
|---|---|---|
| `Slider` / `HSlider` / `VSlider` | `sun` | a continuous `NumberProperty` over a `Range` |
| `NumberControl` | `scenery-phet` | a slider **plus** title, tweaker arrows, and a numeric readout — the usual choice for a labelled quantity |
| `Checkbox` | `sun` | a `BooleanProperty` toggle with a label node |
| `AquaRadioButtonGroup` / `RectangularRadioButtonGroup` | `sun` | pick one value of an enumeration |
| `ComboBox` | `sun` | pick one value from a longer list (dropdown) |
| `ABSwitch` / `ToggleSwitch` | `sun` | a two-state switch |
| `RectangularPushButton` / `TextPushButton` | `sun` | fire an action |
| `ResetAllButton` | `scenery-phet` | reset the whole sim |
| `TimeControlNode` / `PlayPauseButton` / `StepForwardButton` | `scenery-phet` | playback |
| `NumberDisplay` | `scenery-phet` | read-only numeric readout |

## NumberControl — the workhorse

For a labelled numeric quantity, `NumberControl` beats a bare slider: it bundles the title, slider, tweaker buttons, and a formatted readout, all driven by one `NumberProperty`.

```typescript
import { NumberControl } from "scenerystack/scenery-phet";

const frequencyControl = new NumberControl(
  StringManager.getInstance().frequencyStringProperty,  // localized title (see scenerystack-strings)
  model.frequencyProperty,                              // NumberProperty
  model.frequencyProperty.range,                        // the Property's Range
  {
    delta: 0.1,                                         // tweaker step
    numberDisplayOptions: { decimalPlaces: 1, valuePattern: hzPatternStringProperty },
    sliderOptions: { majorTicks: [ { value: 0, label: new Text("0") } ] },
  },
);
```

## Checkbox, radio, combo — pick-a-value

```typescript
import { Checkbox, AquaRadioButtonGroup, ComboBox } from "scenerystack/sun";

const showGrid = new Checkbox(model.gridVisibleProperty, new Text(gridStringProperty), { boxWidth: 18 });

// one value of an enumeration (see scenerystack-enumeration)
const modeButtons = new AquaRadioButtonGroup(model.modeProperty, [
  { value: Mode.WAVE, createNode: () => new Text(waveStringProperty) },
  { value: Mode.PARTICLE, createNode: () => new Text(particleStringProperty) },
]);

// ComboBox needs a listbox parent (usually the ScreenView) so the popup isn't clipped
const unitsCombo = new ComboBox(model.unitsProperty, items, this /* listParent */);
```

## Reset All and playback

```typescript
import { ResetAllButton, TimeControlNode } from "scenerystack/scenery-phet";

const resetAll = new ResetAllButton({
  listener: () => { this.interruptSubtreeInput(); model.reset(); this.reset(); },
  right: this.layoutBounds.maxX - MARGIN,
  bottom: this.layoutBounds.maxY - MARGIN,
});

const timeControl = new TimeControlNode(model.isPlayingProperty, {
  playPauseStepButtonOptions: { stepForwardButtonOptions: { listener: () => model.stepOnce() } },
});
```

`stepOnce()` above is a sim-owned method, not a framework API: implement it to advance one configured interval while retaining pause, or use the model's existing forced-step path. Verify the actual button callback advances time and state while ordinary paused frames do not. Transport enablement follows retained-history and duration bounds.

Preset/harmonic actions must establish the state their result requires (for example enable the driver before setting a driven steady state). Test from a conflicting initial mode rather than only from the default.

## Themed Panel and Dialog

Don't style raw `Panel` / `Dialog` with one-off fills in every call site. Fork
`SceneryStackTemplate`'s `SimPanel` into `<Prefix>Panel` (and `<Prefix>Dialog` when the sim has
modals) under `src/common/`, wiring fill/stroke from `*Colors.ts` so projector mode follows
automatically:

```typescript
import type { Node } from "scenerystack/scenery";
import type { PanelOptions } from "scenerystack/sun";
import { Panel } from "scenerystack/sun";
import SimColors from "../SimColors.js";
import { PANEL_CORNER_RADIUS } from "../SimConstants.js";

export class SimPanel extends Panel {
  public constructor(content: Node, providedOptions?: PanelOptions) {
    super(content, {
      fill: SimColors.panelBackgroundColorProperty,
      stroke: SimColors.panelBorderColorProperty,
      cornerRadius: PANEL_CORNER_RADIUS,
      xMargin: 12,
      yMargin: 10,
      ...providedOptions,
    });
  }
}
```

Same idea for dialogs (`Dialog` / `DialogOptions` from `scenerystack/sim`, plus
`closeButtonColor: …textColorProperty`). Prefer `<Prefix>Panel` / `<Prefix>Dialog` for every
sim-owned chrome surface; leave the framework Preferences dialog on its own light chrome.
Title `Text` nodes still need an explicit `fill` from `textColorProperty`.

## Rules

- Bind every control to a model `Property`; the control is the view of that state, not a second copy. After `model.reset()` the controls follow automatically.
- `ResetAllButton`'s listener should `interruptSubtreeInput()` first, then reset the model **and** any view-only state.
- Pass localized `*StringProperty`s for all labels — never literal strings (see scenerystack-strings).
- Style via `optionize` defaults and `*Constants`/`*Colors`, not inline literals (see scenerystack-optionize, scenerystack-color-profiles). Use the themed `<Prefix>Panel` / `<Prefix>Dialog`, not ad-hoc `new Panel(...)` fills.
- `ComboBox` and other popups need a `listParent` Node high in the tree (commonly the `ScreenView`) so the open list isn't clipped by a panel.
- Lay controls out with `VBox`/`HBox`/`Panel` (see scenerystack-layout); don't hand-place each one.
- These controls are keyboard-accessible out of the box — keep that by giving groups `accessibleName`/help text (see scenerystack-accessibility) and documenting them in the keyboard-help dialog.

## Common mistakes

- Re-implementing a slider/checkbox with raw `Rectangle` + `DragListener` instead of using `sun` — loses accessibility, theming, and tweakers.
- Reaching for a bare `HSlider` when the quantity needs a title and readout — `NumberControl` already bundles them.
- Forgetting the `ComboBox` list parent → the dropdown is clipped inside a panel.
- A `ResetAllButton` that resets the model but leaves view-only Properties (e.g. a "show ruler" toggle) stale.
- `new Panel(content, { fill: "#fff" })` instead of `<Prefix>Panel` → breaks projector mode and duplicates chrome.
- Leaving Checkbox / ComboBox item labels / `NumberControl` title+`numberDisplayOptions` on framework black/white defaults → low contrast on dark default panels (projector mode usually looks fine). Theme them from `*Colors.ts` — see scenerystack-color-profiles.

Related skills: scenerystack-layout, scenerystack-optionize, scenerystack-strings, scenerystack-enumeration, scenerystack-accessibility, scenerystack-color-profiles.
