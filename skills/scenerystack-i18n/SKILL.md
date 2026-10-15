---
name: scenerystack-i18n
description: Use when adding or maintaining translations — adding a locale, keeping locale files in sync, interpolating values with PatternStringProperty, formatting units, or enabling the runtime language picker. The localization workflow that sits on top of StringManager.
---

# SceneryStack Internationalization (i18n)

SceneryStack sims are localized from day one. This skill is the **workflow** around translatable text; the StringManager mechanism itself is in scenerystack-strings.

## Locale-file parity is a hard contract

Every sim ships all three locales — `strings_en.json`, `strings_es.json`, and `strings_fr.json` (see [CONVENTIONS.md §4](../../CONVENTIONS.md)). `LocalizedString.getNestedStringProperties({ en, es, fr })` infers its type from the **union of keys**, so when locale files diverge TypeScript errors at `npm run check`. **This is intentional — do not silence it.**

When you add or rename a key:

1. Add it to `strings_en.json` (the source of truth) **and to every other locale file**, even if the translation is a placeholder copy of the English for now.
2. Keep the **nesting and key names identical** across files — only the values differ.
3. Run `npm run check`; a type error means a locale is missing a key.

To add a **locale beyond the standard three** (e.g. German):

```typescript
// StringManager.ts
import stringsDe from "./strings_de.json";
const stringProperties = LocalizedString.getNestedStringProperties({
  en: stringsEn,
  es: stringsEs,
  fr: stringsFr,
  de: stringsDe,   // file must contain every key the others have
});
```

Also register the new locale in `src/init.ts` (`availableLocales`).

## Interpolating values: `PatternStringProperty`, never concatenation

Translations reorder words, so never build sentences with `+`. Put a `{{placeholder}}` in the JSON and fill it with a `PatternStringProperty` (from `scenerystack/axon`). The result is itself a `StringProperty` that re-evaluates when either the locale or the value changes.

```json
{ "units": { "metersPerSecond": "{{value}} m/s" },
  "selectedObject": "Selected: {{object}}" }
```

```typescript
import { PatternStringProperty } from "scenerystack/axon";

// numeric value
const speedLabel = new PatternStringProperty(units.metersPerSecondStringProperty, {
  value: model.speedProperty,          // a Property — label updates as it changes
});

// nested string value
const selectedLabel = new PatternStringProperty(strings.selectedObjectStringProperty, {
  object: model.selectedNameStringProperty,
});

new Text(speedLabel, { fill: SimColors.textColorProperty });
```

Placeholder values may be plain values or `Property`s; mixing is fine.

When the string is built on demand rather than bound to a node — an accessible response, a
description sentence assembled in a listener, a formatter that returns `string` — fill the
current pattern with `StringUtils.fillIn` (from `scenerystack/phetcommon`). Never chain
`.replace("{{month}}", …)`; it skips missing-key checks and breaks on repeated placeholders.

```typescript
import { StringUtils } from "scenerystack/phetcommon";

return StringUtils.fillIn(controls.datePatternStringProperty.value, {
  month: monthName,
  day: String(monthDay.dayOfMonth),
});
```

Reading `.value` is correct here because the result is recomputed each call; use a
`PatternStringProperty` for anything a node displays persistently.

## Units strings

Unit suffixes are localized text — keep them in a `units` block (`{{value}} m/s`, `{{value}} Hz`, `{{value}}m`) and render with `PatternStringProperty`. Do **not** append `" m/s"` in code.

## Runtime language switching

To let users change language without reloading, opt in once in `src/main.ts`:

```typescript
preferencesModel: new PreferencesModel({
  localizationOptions: { supportsDynamicLocale: true },  // adds Preferences → Language
}),
```

This only works if every visible string is a `StringProperty` passed to its node (never `.value`). Concatenated or cached strings won't update — another reason to use `PatternStringProperty`.

## Rules

- Edit **all** locale files together; never let them drift.
- One placeholder syntax: `{{name}}`. Match the names in `PatternStringProperty`.
- New translatable text → JSON in every locale → StringManager getter → node. No shortcuts.
- Locale list registered in `src/init.ts`; the title/screen names also come from StringManager.

## Common mistakes

- Adding a key to `strings_en.json` only → `npm run check` fails (good — fix the other files).
- `` `${value} m/s` `` or `label + unit` → not translatable; use a pattern string.
- `pattern.replace("{{x}}", …)` by hand → use `StringUtils.fillIn` (or `PatternStringProperty`).
- Caching `stringProperty.value` once at construction → text won't follow a locale change.

Related skills: scenerystack-strings, scenerystack-preferences.
