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

For sim-specific settings, add `simulationOptions.customPreferences`: an array of objects whose `createContent(tandem)` returns a `Node` built from `sun`/`scenery-phet`. Each control is backed by a `Property` on the sim's `<Prefix>PreferencesModel`.

The preferences model is a plain class of `Property`s. Each initial value comes from the matching query parameter in `<prefix>QueryParameters.ts`, so a URL can preset it (see scenerystack-query-parameters):

```typescript
export class LabPreferencesModel {
  public readonly showTracesProperty: BooleanProperty;

  public constructor(tandem?: Tandem) {
    this.showTracesProperty = new BooleanProperty(
      labQueryParameters.showTraces,
      tandem ? { tandem: tandem.createTandem("showTracesProperty") } : undefined,
    );
  }

  public reset(): void {
    this.showTracesProperty.reset();
  }
}

LabNamespace.register("LabPreferencesModel", LabPreferencesModel);
```

Build **one** instance in `src/main.ts`. Hand it to the dialog node and to every screen that reads it:

```typescript
const simPreferences = new LabPreferencesModel(Tandem.ROOT.createTandem("preferences"));

const screens = [
  new LabScreen({ /* name, tandem, backgroundColorProperty */ preferences: simPreferences }),
];

preferencesModel: new PreferencesModel({
  simulationOptions: {
    customPreferences: [
      { createContent: (tandem: Tandem) => new LabPreferencesNode(simPreferences, tandem) },
    ],
  },
}),
```

The screen adds `preferences: <Prefix>PreferencesModel` to its options type and passes it to the model factory, which takes it as a constructor parameter (`() => new LabModel(options.preferences)`). Models and views import the preferences class with `import type` only. Do **not** expose a `getInstance()` singleton or a module-level getter. The fleet removed those in September 2026 (LightPropagation, CrystalLattice) because they hide the dependency, make tests share state, and break when a second instance is built.

The control's `Property` is the single source of truth. Views and models `.link()` to it like any other Property. Persisting a choice across sessions (`localStorage`, as Resonance does) is optional; document it in the sim's `AGENTS.md` when you add it.

A sim with no sim-specific preferences still keeps the trio. The model is then empty, but its constructor accepts an optional `tandem` so `main.ts` stays uniform. Remove the template's `exampleToggle` placeholder (property, query parameter, strings, and control): the compliance gate fails on it.

## Rules

- The preferences model and dialog UI live in `src/preferences/` as `<Prefix>PreferencesModel.ts` and `<Prefix>PreferencesNode.ts` (a multi-tab sim may split the UI into `<Prefix><Tab>PreferencesNode.ts` files), alongside `<prefix>QueryParameters.ts` — see [CONVENTIONS.md §3](../../CONVENTIONS.md).
- Configure preferences **only** in `src/main.ts` on the `PreferencesModel`. Don't scatter dialog wiring elsewhere.
- Turn a built-in flag on only when the sim actually honors it — `supportsProjectorMode` needs `projector:` colors defined; `supportsDynamicLocale` needs all-Property strings.
- Custom controls are built from `Property`s. Reset All does **not** call the preferences model's `reset()`; preferences outlive it.
- Use `customPreferences` for a true preference; use a query parameter for a launch-time/debug switch (see scenerystack-query-parameters).

## Common mistakes

- Enabling `supportsDynamicLocale` while some text is hardcoded or uses `.value` → those strings won't update on language change.
- Enabling `supportsProjectorMode` without `projector:` color values → projector mode silently looks identical to default.
- Building a custom control that mutates a local variable instead of a shared `Property` → the model/view can't observe it.
- Reaching for `<Prefix>PreferencesModel.getInstance()` from a model → pass the instance in through the screen options instead.
- Leaving the template's `exampleToggle` preference in place → compliance failure and a meaningless control in the dialog.

Related skills: scenerystack-color-profiles, scenerystack-i18n, scenerystack-accessibility, scenerystack-query-parameters.
