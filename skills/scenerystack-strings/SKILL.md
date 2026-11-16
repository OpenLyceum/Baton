---
name: scenerystack-strings
description: Use whenever a view needs display text, or you add/rename/remove user-visible text. Covers the StringManager singleton, strings_*.json files, LocalizedString.getNestedStringProperties, and consuming *StringProperty in nodes. Trigger on any hardcoded UI string.
---

# SceneryStack Strings (StringManager)

**No user-visible text is ever hardcoded in a view.** Every label, button, title, and readout comes from a localized `StringProperty` exposed by the sim's `StringManager`. Strings live in `src/i18n/strings_<locale>.json`; the view consumes the `*StringProperty` so text updates live when the locale changes. The template's `no-hardcoded-text` Biome plugin flags display words passed as literals to `new Text` / `new RichText` in `src/`; symbols, units and formulas (`"pH"`, `"Hz"`, `"mc²"`) pass.

## The three pieces

1. **`src/i18n/strings_en.json`** (and one file per locale) — the source text, nested by category:

```json
{
  "title": "Doppler Effect",
  "source": "Source",
  "selectedObject": "Selected: {{object}}",
  "controls": {
    "values": "Values",
    "soundSpeed": "Speed of Sound"
  }
}
```

2. **`src/i18n/StringManager.ts`** — a singleton that turns the JSON into nested `StringProperty`s and exposes typed getters:

```typescript
import { LocalizedString } from "scenerystack/chipper";
import stringsEn from "./strings_en.json";
import stringsEs from "./strings_es.json";
import stringsFr from "./strings_fr.json";

// nesting mirrors the JSON; each leaf becomes a <leaf>StringProperty.
// Module-level so getters can reference it directly (canonical template pattern).
const stringProperties = LocalizedString.getNestedStringProperties({
  en: stringsEn,
  es: stringsEs,
  fr: stringsFr,
});

export class StringManager {
  private static instance: StringManager;

  private constructor() {} // obtain via getInstance()

  public static getInstance(): StringManager {
    return (StringManager.instance ??= new StringManager());
  }

  public getControlPanelStrings() {
    return {
      valuesStringProperty: stringProperties.controls.valuesStringProperty,
      soundSpeedStringProperty: stringProperties.controls.soundSpeedStringProperty,
    };
  }

  // accessibility strings live under the a11y group (see ACCESSIBILITY.md)
  public getA11yStrings() {
    return stringProperties.a11y;
  }
}
```

`getNestedStringProperties` appends `StringProperty` to every leaf key: `controls.soundSpeed` → `stringProperties.controls.soundSpeedStringProperty`.

3. **The view** — pull strings from the manager and pass the `Property` straight to the node:

```typescript
const strings = StringManager.getInstance().getControlPanelStrings();
const label = new Text(strings.soundSpeedStringProperty, { font, fill: SimColors.textColorProperty });
```

`Text`, `RichText`, button labels, and `accessibleName` all accept a `TReadOnlyProperty<string>`; they re-render when the locale changes. **Pass the Property, never `.value`.**

## Rules

- Add a key once in **every** `strings_*.json` file (see scenerystack-i18n for the locale-parity contract).
- Expose strings through a `StringManager` getter grouped by consumer (control panel, graphs, a11y…). Views never `import` a JSON file directly.
- Use `{{placeholder}}` for interpolation; render it with a pattern property (see scenerystack-i18n), not string concatenation.
- The screen/title name property is read in `main.ts` from the manager (`stringManager.getTitleStringProperty()`).

## Common mistakes

- `new Text("Speed of Sound")` → hardcoded; move to JSON + StringManager.
- Passing `someStringProperty.value` to a `Text` → text freezes at the launch locale.
- Building sentences with `a + " " + b` → breaks translation word order; use a pattern string.

Related skills: scenerystack-i18n, scenerystack-color-profiles.
