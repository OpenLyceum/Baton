---
name: scenerystack-preferences
description: Use when configuring the Preferences dialog — enabling projector mode, dynamic locale, sound, interactive highlights, or adding a custom preference control. Covers PreferencesModel options and the customPreferences createContent hook. Wired in src/main.ts.
---

# SceneryStack Preferences

The Preferences dialog (gear icon) is configured by a single `PreferencesModel` passed to `new Sim(...)` in `src/main.ts`. Its built-in tabs (Visual, Audio, Language, Input, Simulation) are turned on with boolean options; sim-specific controls are added through `customPreferences`.

## Built-in options

```typescript
import { onReadyToLaunch, PreferencesModel, Sim } from "scenerystack/sim";

onReadyToLaunch(() => {
  const sim = new Sim(stringManager.getTitleStringProperty(), screens, {
    preferencesModel: new PreferencesModel({
      visualOptions: {
        supportsProjectorMode: true,          // Visual → Projector Mode (uses projector: colors)
        supportsInteractiveHighlights: true,  // Visual → Interactive Highlights
      },
      localizationOptions: {
        supportsDynamicLocale: true,          // Language picker, switch without reload
      },
      audioOptions: {
        supportsSound: true,                  // initializes tambo; also set supportsSound in src/init.ts
      },
    }),
  });
  sim.start();
});
```

Each flag is wired to existing framework behavior:
- `supportsProjectorMode` activates the `projector:` profile in `*Colors.ts` (see scenerystack-color-profiles).
- `supportsDynamicLocale` requires every visible string to be a `StringProperty` (see scenerystack-i18n).
- `supportsInteractiveHighlights` turns on the mouse-hover focus outlines (see scenerystack-accessibility).
- `audioOptions.supportsSound` initializes tambo and shows Audio preferences. It does **not** unmute playback. Also set `supportsSound: true` in `src/init.ts`; that flag is the default of `?supportsSound`, which is the initial value of `soundManager.enabledProperty` and what keeps the navigation-bar speaker enabled. Set both, to the same value. See scenerystack-sound.

## Custom preference controls

For sim-specific settings, add `simulationOptions.customPreferences` — an array of objects whose `createContent(tandem)` returns a `Node` (a control built from `sun`/`scenery-phet`). Back each control with a `Property` on a small preferences model:

```typescript
preferencesModel: new PreferencesModel({
  simulationOptions: {
    customPreferences: [
      { createContent: () => createParticleTracePreference(preferences) },
      { createContent: (tandem) => new TrackLabPreferencesNode(trackLabPreferences) },
    ],
  },
}),
```

A preferences model is a plain class of `Property`s, often persisted to `localStorage`:

```typescript
export class SimPreferences {
  public readonly showTracesProperty = new BooleanProperty(false);
  public readonly rendererTypeProperty = new Property<RendererType>(RendererType.CANVAS);
  // ...load/save to localStorage
}
```

The control's value `Property` is the single source of truth; views and the model `.link()` to it just like any other Property.

## Rules

- The preferences model and dialog UI live in `src/preferences/` as `<Prefix>PreferencesModel.ts` and `<Prefix>PreferencesNode.ts` (a multi-tab sim may split the UI into `<Prefix><Tab>PreferencesNode.ts` files), alongside `<prefix>QueryParameters.ts` — see [CONVENTIONS.md §3](../../CONVENTIONS.md).
- Configure preferences **only** in `src/main.ts` on the `PreferencesModel`. Don't scatter dialog wiring elsewhere.
- Turn a built-in flag on only when the sim actually honors it — `supportsProjectorMode` needs `projector:` colors defined; `supportsDynamicLocale` needs all-Property strings.
- Custom controls are built from `Property`s; persist user choices (commonly `localStorage`) and `.reset()` is generally **not** applied to preferences (they outlive Reset All).
- Use `customPreferences` for a true preference; use a query parameter for a launch-time/debug switch (see scenerystack-query-parameters).

## Common mistakes

- Enabling `supportsDynamicLocale` while some text is hardcoded or uses `.value` → those strings won't update on language change.
- Enabling `supportsProjectorMode` without `projector:` color values → projector mode silently looks identical to default.
- Building a custom control that mutates a local variable instead of a shared `Property` → the model/view can't observe it.

Related skills: scenerystack-color-profiles, scenerystack-i18n, scenerystack-accessibility, scenerystack-query-parameters.
