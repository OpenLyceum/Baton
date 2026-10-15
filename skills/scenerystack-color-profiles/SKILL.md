---
name: scenerystack-color-profiles
description: Use when adding, changing, or theming colors in a SceneryStack sim — ProfileColorProperty, the per-sim *Colors.ts file, projector mode, or fixing low-contrast UI (checkboxes, combo boxes, NumberDisplay / NumberControl readouts) that look fine in projector mode but fail in the default dark profile.
---

# SceneryStack Color Profiles

Every color a view draws comes from a `ProfileColorProperty` defined in the sim's single `*Colors.ts` file. **Never hardcode `#hex`, `rgb(...)`, or a bare `Color` in a view or node.** Profile colors give you free light/dark theming, projector mode, and runtime-editable colors in the color editor.

## The `*Colors.ts` file

One file per sim (e.g. `DopplerEffectColors.ts`, `SimColors.ts`), exporting a single frozen object of `ProfileColorProperty` instances keyed off the sim namespace.

```typescript
import { Color, ProfileColorProperty } from "scenerystack/scenery";
import DopplerEffectNamespace from "./DopplerEffectNamespace.js";

const BLACK = new Color(0, 0, 0);
const WHITE = new Color(255, 255, 255);

const DopplerEffectColors = {
  backgroundColorProperty: new ProfileColorProperty(DopplerEffectNamespace, "background", {
    default: BLACK,
    projector: WHITE,
  }),
  sourceColorProperty: new ProfileColorProperty(DopplerEffectNamespace, "sourceColor", {
    default: new Color(100, 255, 100),
    projector: new Color(0, 200, 0),
  }),
} as const;

export default DopplerEffectColors;
```

- First arg is the sim **namespace** (`new Namespace("doppler-effect")` — the kebab-case sim id — exported as the default from `*Namespace.ts`, imported with the `.js` extension).
- Second arg is a **unique string key** — this is the name shown in the color editor and used by phet-io. Keep it stable.
- The third arg is a map of named profiles. `default` is required; `projector` enables Projector Mode (high-contrast, light background for classroom projectors).
- Write each entry as an inline `new ProfileColorProperty(Namespace, key, { default, projector })`, as the template does. Do **not** wrap it in a local `profileColor(name, def, projector)` factory; the compliance gate fails that form, and the explicit `default:` / `projector:` labels keep the two profiles from being swapped by position.

## Two color families

Most OpenLyceum sims use a **dark default** profile (dark screen + dark panels, light text) and a **light projector** profile. SceneryStack widget defaults (black checkbox stroke, black `NumberDisplay` text, white combo-box chrome) assume a **light** surface — so they usually look fine in projector mode and fail contrast in default mode. Theme both families in `*Colors.ts`:

| Family | Role | Typical keys | Profile behavior |
|---|---|---|---|
| Panel / scene | Backgrounds, panel chrome, labels drawn **on** the panel fill | `backgroundColorProperty`, `panelBackgroundColorProperty`, `panelBorderColorProperty`, `textColorProperty` | Flip with profile (dark↔light) |
| Light control surfaces | Widgets that stay white chrome in **both** profiles | `controlSurfaceColorProperty`, `controlSurfaceDisabledColorProperty`, `controlSurfaceTextColorProperty` | Same values in both profiles (white fill, near-black text) |

`SceneryStackTemplate` and `OpticsLab` are the reference layouts for this split. Fork the template's "light control surfaces" block into every sim that has combo boxes, flat buttons, editable fields, or Preferences checkboxes.

## Consuming a profile color in a view

Pass the `Property` directly — Scenery nodes accept a `TReadOnlyProperty<Color>` anywhere they accept a color, and re-render automatically when the profile changes.

```typescript
const dot = new Circle(8, { fill: DopplerEffectColors.sourceColorProperty });
const label = new Text(titleStringProperty, { fill: DopplerEffectColors.textColorProperty });
this.setScreenBackgroundColor?.(DopplerEffectColors.backgroundColorProperty); // or screenView background
```

If you need to derive one color from another (e.g. a translucent version), use `DerivedProperty`:

```typescript
const glowProperty = new DerivedProperty(
  [DopplerEffectColors.sourceColorProperty],
  (c) => c.withAlpha(0.3),
);
```

## Turning on Projector Mode

Projector colors only take effect if the sim opts in, in `src/main.ts`:

```typescript
preferencesModel: new PreferencesModel({
  visualOptions: { supportsProjectorMode: true },
}),
```

This adds a **Preferences → Visual → Projector Mode** toggle. Always define a sensible `projector:` value for every color when the sim supports it.

## Contrast gotchas (default profile)

Sun / scenery-phet defaults are light-surface colors. On a dark default panel they disappear; projector mode often hides the bug. Wire every control below to `*Colors.ts` — do not rely on framework defaults.

### Checkbox

`Checkbox` defaults to `checkboxColor: 'black'` and `checkboxColorBackground: 'white'`. On a dark panel the black box is invisible; the label `Text` also needs an explicit fill (Scenery `Text` defaults to black).

**On a sim panel** (dark in default mode) — use panel text / overlay colors that flip with the profile:

```typescript
new Checkbox(model.gridVisibleProperty, new Text(gridStringProperty, {
  fill: SimColors.textColorProperty,
}), {
  checkboxColor: SimColors.textColorProperty,
  checkboxColorBackground: SimColors.panelBackgroundColorProperty, // or a dedicated overlay input fill
});
```

**In the Preferences dialog** — the dialog chrome is always white. Use the light-control-surface colors (dark text), **not** `textColorProperty` (near-white in default mode → invisible on white):

```typescript
new Checkbox(preferencesModel.exampleToggleProperty, new Text(labelStringProperty, {
  fill: SimColors.controlSurfaceTextColorProperty,
}), {
  checkboxColor: SimColors.controlSurfaceTextColorProperty,
  checkboxColorBackground: SimColors.controlSurfaceColorProperty,
});
```

### ComboBox

`ComboBox` defaults to `buttonFill` / `listFill: 'white'`. That light chrome is intentional; the trap is item labels filled with `textColorProperty` (white-on-white in default mode). Use the shared combo options from `<Prefix>ButtonOptions.ts` and dark text for items:

```typescript
import { LIGHT_SURFACE_TEXT_FILL, SIM_COMBO_BOX_OPTIONS } from "../../common/SimButtonOptions.js";

const items = [{
  value: Mode.WAVE,
  createNode: () => new Text(waveStringProperty, { fill: LIGHT_SURFACE_TEXT_FILL }),
}];

new ComboBox(model.modeProperty, items, listParent, { ...SIM_COMBO_BOX_OPTIONS });
```

`SIM_COMBO_BOX_OPTIONS` sets `buttonFill` / `listFill` from `controlSurfaceColorProperty` and strokes from `panelBorderColorProperty`. Never put `textColorProperty` on combo-item labels.

### NumberDisplay / NumberControl readout

The numeric readout beside a slider is a `NumberDisplay` (usually via `NumberControl`'s `numberDisplayOptions`). It defaults to `textOptions.fill: 'black'` on `backgroundFill: 'white'`. Black-on-dark-panel fails when the display background is omitted or made translucent; the title defaults to black too.

Always theme title + readout together:

```typescript
new NumberControl(titleStringProperty, model.valueProperty, model.valueProperty.range, {
  titleNodeOptions: { fill: SimColors.textColorProperty },
  numberDisplayOptions: {
    decimalPlaces: 1,
    textOptions: { fill: SimColors.controlSurfaceTextColorProperty },
    backgroundFill: SimColors.controlSurfaceColorProperty, // or a dedicated overlay input fill
    backgroundStroke: SimColors.panelBorderColorProperty,
  },
});
```

On Preferences (always-white dialog), use `controlSurfaceTextColorProperty` for title and readout text instead of `textColorProperty`.

### RectangularPushButton (flat)

`RectangularPushButton` with `ButtonNode.FlatAppearanceStrategy` defaults to a **light** fill. Labels filled with `textColorProperty` (near-white in default mode) become **near-white on white**. **RotatingSky** is the reference: dark ink on white chrome.

```typescript
new RectangularPushButton({
  ...FLAT_RECTANGULAR_BUTTON_OPTIONS,
  baseColor: SimColors.controlSurfaceColorProperty,
  content: new Text(labelProperty, { fill: LIGHT_SURFACE_TEXT_FILL }),
  listener,
});
```

Never put `textColorProperty` on button content that sits on `controlSurfaceColorProperty`. SternGerlach is the other valid pairing: dark `controlSurfaceColorProperty` with near-white `controlSurfaceTextColorProperty` — fill and label must come from the **same** surface.

### Related defaults that bite the same way

- `TimeControlNode` speed-radio labels default to black → use `TIME_CONTROL_SPEED_RADIO_OPTIONS` (`labelOptions.fill: textColorProperty`).
- Panel title / body `Text` nodes → always pass `fill: textColorProperty`; Scenery text is black by default.

## Rules

- Define **all** colors in `*Colors.ts`. A view that needs a new color adds a key there, it does not invent one inline.
- Name keys after **role**, not appearance (`selectionColorProperty`, not `orangeColorProperty`).
- Reuse shared local `Color` constants (`BLACK`, `WHITE`) inside the file; don't repeat literals.
- Color literals are fine **inside `*Colors.ts`**, nowhere else.
- Keep the **panel** family flipping with profile and the **control-surface** family fixed (white / dark text) so combo boxes, NumberDisplay chrome, and Preferences checkboxes stay readable.
- When adding a Checkbox, ComboBox, or NumberControl, set fills explicitly — assume framework defaults will fail on the dark default profile.
- Verify contrast in **both** profiles (toggle Preferences → Visual → Projector Mode). Projector looking fine is not enough.

## Common mistakes

- `fill: "red"` or `fill: new Color(...)` in a view → move it to `*Colors.ts`.
- A `profileColor(...)` helper inside `*Colors.ts` → compliance failure; declare each `ProfileColorProperty` inline.
- Reading `.value` to get a static `Color` and passing that — you lose reactivity. Pass the `Property` itself.
- Forgetting a `projector:` value when `supportsProjectorMode` is on (projector mode silently falls back to `default`).
- Leaving Checkbox / NumberDisplay / Text on framework black defaults → invisible on dark default panels; projector mode masks the bug.
- Filling ComboBox item labels with `textColorProperty` while the button/list stay white → white-on-white in default mode.
- Using `textColorProperty` (near-white in default) for Preferences dialog labels/checkboxes → invisible on the always-white Preferences chrome; use `controlSurfaceTextColorProperty`.
- Using `textColorProperty` for labels on white push buttons / NumberDisplay chrome → near-white on white in default mode; use `LIGHT_SURFACE_TEXT_FILL` / `controlSurfaceTextColorProperty`.
- Using `controlSurfaceColorProperty` as checkbox background on a dark panel (white floating box); pair tick with `textColorProperty` and fill with `panelBackgroundColorProperty`.
- Theming `NumberControl` title fill but forgetting `numberDisplayOptions.textOptions.fill` (or the reverse) → one of the two stays black.

Related skills: scenerystack-preferences (projector toggle), scenerystack-ui-controls (Checkbox / ComboBox / NumberControl wiring).
