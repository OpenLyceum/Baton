---
name: scenerystack-keyboard-help-dialog
description: Use when documenting a sim's keyboard controls in the Keyboard Shortcuts dialog (? icon). Covers KeyboardHelpSection, KeyboardHelpSectionRow.fromHotkeyData, TwoColumnKeyboardHelpContent, the BasicActions/SliderControls prebuilt sections, and wiring via createKeyboardHelpNode.
---

# SceneryStack Keyboard Help Dialog

Every keyboard-navigable sim ships a Keyboard Shortcuts dialog (opened with the `?` icon). You build its content from `KeyboardHelpSection`s and hand the whole node to the screen via `createKeyboardHelpNode`. The golden rule: **the help dialog is generated from the same `HotkeyData` that drives the actual listeners**, so documentation can't drift from behavior.

## Rows from HotkeyData

Define shortcuts once as `HotkeyData` (see scenerystack-accessibility), then build each help row with `KeyboardHelpSectionRow.fromHotkeyData` — the key icons come straight from the binding:

```typescript
import { KeyboardHelpSection, KeyboardHelpSectionRow } from "scenerystack/scenery-phet";
import MazeGameHotkeyData from "./MazeGameHotkeyData.js";

export class MazeGameKeyboardHelpSection extends KeyboardHelpSection {
  public constructor(strings: KeyboardHelpStrings) {
    const moveRow = KeyboardHelpSectionRow.fromHotkeyData(MazeGameHotkeyData.MOVE_PARTICLE, {
      labelStringProperty: strings.controlParticleStringProperty,        // visible label
      pdomLabelStringProperty: strings.controlParticleDescriptionStringProperty, // screen-reader label
    });
    const stopRow = KeyboardHelpSectionRow.fromHotkeyData(MazeGameHotkeyData.STOP_MOTION, {
      labelStringProperty: strings.stopMotionStringProperty,
      pdomLabelStringProperty: strings.stopMotionDescriptionStringProperty,
    });

    // section title + its rows
    super(strings.particleStringProperty, [moveRow, stopRow]);
  }
}
```

## Assembling the dialog content

Lay sections out in two columns with `TwoColumnKeyboardHelpContent`. Reuse the prebuilt sections for common controls — `BasicActionsKeyboardHelpSection` (Tab/Esc/space), `SliderControlsKeyboardHelpSection` (arrows/page-up-down), and `TimeControlsKeyboardHelpSection` when the screen has playback — alongside your sim-specific sections:

```typescript
import {
  TwoColumnKeyboardHelpContent,
  BasicActionsKeyboardHelpSection,
  SliderControlsKeyboardHelpSection,
  TimeControlsKeyboardHelpSection,
} from "scenerystack/scenery-phet";

class MazeGameKeyboardHelpContent extends TwoColumnKeyboardHelpContent {
  public constructor() {
    const moveSection = new MazeGameKeyboardHelpSection(strings);
    const basicActions = new BasicActionsKeyboardHelpSection();
    const sliderControls = new SliderControlsKeyboardHelpSection();
    const timeControls = new TimeControlsKeyboardHelpSection();
    super(
      [moveSection, sliderControls], // left column
      [timeControls, basicActions],  // right column
    );
  }
}
```

### Do not ship the template stub

`SceneryStackTemplate` ships `*KeyboardHelpContent.ts` with only
`BasicActionsKeyboardHelpSection` and a commented-out right column. The compliance gate
only checks that the file **exists**, so a fresh fork can pass structure checks while
documenting none of its sliders or time controls. Before release (and ideally right after
scaffold), replace the stub with the real sections for every screen — see
scenerystack-new-sim.

## Wiring it to the screen

Pass a factory to the screen's `createKeyboardHelpNode` option (in the `Screen` subclass or in `main.ts`). The framework calls it to populate the dialog:

```typescript
new MazeGameScreen({
  createKeyboardHelpNode: () => new MazeGameKeyboardHelpContent(),
  // ...
});
```

## Drag listeners bind keys outside HotkeyData

`KeyboardDragListener` and `RichDragListener` claim the arrow keys **without** a `HotkeyData` entry. That breaks the one-source guarantee in both directions, so watch for it when editing drag code:

- Replacing a `HotkeyData`-driven `KeyboardListener` with a drag listener leaves its help row rendering a shortcut that no listener implements any more.
- Adding a drag listener *alongside* an existing `HotkeyData` listener double-binds the arrows — the row still looks right, but two handlers now fire per press.

Before swapping a `KeyboardListener` for a drag listener, grep for the `HotkeyData` entry it used and decide deliberately: either keep the `KeyboardListener` (and make the drag listener pointer-only), or delete the now-unbound `HotkeyData` and its row. See scenerystack-drag-listener.

## Rules

- Build rows with `KeyboardHelpSectionRow.fromHotkeyData(hotkeyData, ...)` so icons match the real bindings — never hand-type key names that could fall out of sync.
- A `HotkeyData` entry with no listener behind it is a silent lie. When you remove or re-home a listener, follow its `HotkeyData` to every help row that renders it.
- All labels are `StringProperty`s from `StringManager` (see scenerystack-strings); supply a `pdomLabelStringProperty` so screen-reader users get a spoken description.
- Group with `TwoColumnKeyboardHelpContent`; include `BasicActionsKeyboardHelpSection` for the universal Tab/Esc shortcuts, `SliderControlsKeyboardHelpSection` when the sim has sliders, and `TimeControlsKeyboardHelpSection` when it has playback controls.
- One `createKeyboardHelpNode` per screen; multi-screen sims can return different content per screen.
- If you add or change a `HotkeyData` binding, the help dialog updates for free — keep both deriving from the same source.
- Never leave the template keyboard-help stub as the shipped dialog — compliance will not catch it.

## Common mistakes

- Typing literal key icons/labels instead of `fromHotkeyData` → the dialog lies once a binding changes.
- Hardcoded English in a row label → use a localized `StringProperty`.
- Documenting a shortcut in the dialog that no listener implements (or vice versa) → both must come from one `HotkeyData`.
- Shipping only `BasicActionsKeyboardHelpSection` from the template → sliders/playback undocumented.

Related skills: scenerystack-accessibility, scenerystack-strings, scenerystack-drag-listener,
scenerystack-new-sim.
