---
name: scenerystack-optionize
description: Use whenever a Node/component constructor takes configurable options, or you need to merge caller-provided options with defaults and forward the rest to a superclass. Covers optionize<>(), SelfOptions/Options types, EmptySelfOptions, and combineOptions.
---

# SceneryStack optionize

`optionize` is the type-safe way to merge a component's **own** options with caller-provided options and the **parent class's** options, in one call, with full TypeScript checking. Use it instead of `Object.assign`, spreads, or `||` default chains in any constructor that accepts options.

## The three-type pattern

Declare a `SelfOptions` type (just this component's new options), then an exported `Options` type that combines self + parent options. Call `optionize` with three type params: `<FullOptions, SelfOptions, ParentOptions>`.

```typescript
import { optionize } from "scenerystack/phet-core";
import { Panel, type PanelOptions } from "scenerystack/sun";

type HudNodeSelfOptions = {
  interruptInput?: () => void;   // options unique to this component (usually optional)
};

// public surface = my options + everything Panel accepts
type HudNodeOptions = HudNodeSelfOptions & PanelOptions;

export class HudNode extends Panel {
  public constructor(model: MazeGameModel, providedOptions?: HudNodeOptions) {
    const options = optionize<HudNodeOptions, HudNodeSelfOptions, PanelOptions>()(
      {
        // defaults for SelfOptions AND any parent options you want to set
        interruptInput: () => {},
        fill: MazeGameColors.panelFillProperty,
        cornerRadius: MazeGameConstants.PANEL_CORNER_RADIUS,
        accessibleName: a11yStrings.hudPanelStringProperty,
      },
      providedOptions,
    );

    super(content, options);   // forward the merged options to the superclass
  }
}
```

Note the **double call**: `optionize<...>()( defaults, providedOptions )`. The first (empty) call locks in the type parameters; the second does the merge. Defaults always win where the caller didn't specify; the caller overrides where they did.

## No own options? Use `EmptySelfOptions`

When a component adds no new options of its own and just sets parent defaults:

```typescript
import { optionize, type EmptySelfOptions } from "scenerystack/phet-core";

type MazeGameScreenOptions = ScreenOptions;

optionize<MazeGameScreenOptions, EmptySelfOptions, ScreenOptions>()(
  { backgroundColorProperty: MazeGameColors.backgroundColorProperty },
  providedOptions,
);
```

## `combineOptions` — merge without defaults/types ceremony

When you just need to merge option objects of one known type (no parent-class layering), use `combineOptions<T>`:

```typescript
import { combineOptions } from "scenerystack/phet-core";

const switchOptions = combineOptions<ToggleSwitchOptions>(
  { size: new Dimension2(40, 20) },
  extraOptions,
);
```

## Rules

- Name the types `<Component>SelfOptions` and `<Component>Options`; **export** the public `Options` type so callers can use it.
- Constructor param is `providedOptions?: <Component>Options` (optional when every self option has a default).
- Self options are normally **optional** (`?`) because their defaults live in the `optionize` call. Required self options (no default) are allowed but then the caller must pass them.
- Set parent-class defaults (fill, `tandem`, `accessibleName`…) right in the same defaults object — no separate merge step.
- Destructure only what you need *after* merging (`const { interruptInput } = options;`); forward the whole `options` to `super`.

## Common mistakes

- Forgetting the empty `()` before the arguments: it's `optionize<...>()(defaults, provided)`, not `optionize<...>(defaults, provided)`.
- Putting a default's value inline at the use-site (`options.spacing ?? 10`) instead of in the defaults object — defeats the point.
- Wrong type order — it is `<Full, Self, Parent>`. Mixing Self and Parent produces confusing errors.
- Hand-merging with `{ ...defaults, ...providedOptions }` — loses the type guarantees and nested-option handling.

Related skills: scenerystack-layout, scenerystack-preferences, scenerystack-color-profiles.
