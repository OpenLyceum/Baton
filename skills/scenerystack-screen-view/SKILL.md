---
name: scenerystack-screen-view
description: Use when wiring a simulation's entry point — creating the Sim, defining a Screen, building a ScreenView, setting screen icons and background, or connecting a screen's model to its view. Covers the joist Sim/Screen/ScreenView trio (imported via scenerystack/sim), the model factory pattern, and the per-frame step hand-off.
---

# SceneryStack Screen & Sim Setup

`scenerystack/sim` (joist) defines the three-layer entry point every sim shares: a **`Sim`**
owns one or more **`Screen`**s; each `Screen` is a factory pairing a model with a `ScreenView`.
This is the view-side counterpart to scenerystack-model — the model holds physics, the
`ScreenView` is the root `Node` of everything the user sees.

## The launch chain

`src/main.ts` (after the bootstrap imports — see CONVENTIONS §1) constructs the screens and the `Sim`, then launches:

```typescript
import "./brand.js"; // MUST be first — see CONVENTIONS §1

import { onReadyToLaunch, PreferencesModel, Sim } from "scenerystack/sim";
import { Tandem } from "scenerystack/tandem";
import { DopplerEffectScreen } from "./doppler-effect/DopplerEffectScreen.js";

onReadyToLaunch(() => {
  const sim = new Sim(titleStringProperty, [ new DopplerEffectScreen({ tandem: Tandem.ROOT.createTandem("screen") }) ], {
    credits: { leadDesign: "…" },
    preferencesModel: new PreferencesModel({ /* see scenerystack-preferences */ }),
  });
  sim.start();
});
```

## A Screen is a model + view factory

`Screen`'s constructor takes a **model factory**, a **view factory** (given the model), and options (icon, background, name). The factories defer construction until the framework is ready.

```typescript
import { optionize, type EmptySelfOptions } from "scenerystack/phet-core";
import { Screen, type ScreenOptions } from "scenerystack/sim";

type DopplerEffectScreenOptions = ScreenOptions;

export class DopplerEffectScreen extends Screen<DopplerEffectModel, DopplerEffectScreenView> {
  public constructor(providedOptions?: DopplerEffectScreenOptions) {
    const options = optionize<DopplerEffectScreenOptions, EmptySelfOptions, ScreenOptions>()(
      {
        name: StringManager.getInstance().screenNameStringProperty,
        backgroundColorProperty: DopplerEffectColors.backgroundProperty,
        // homeScreenIcon: createIntroIcon(),  // multi-screen — see below
      },
      providedOptions,
    );

    super(
      () => new DopplerEffectModel(),                  // model factory
      (model) => new DopplerEffectScreenView(model),   // view factory
      options,
    );
  }
}
```

A single-screen sim still has exactly one `Screen` (the home-screen selector is skipped automatically).

## The ScreenView

`ScreenView` is the root node. Build the scene graph in its constructor, position against `layoutBounds` (see scenerystack-layout), and use `step(dt)` for view-only updates. Joist steps the active screen model before its view; do not advance it again here:

```typescript
import { ScreenView, type ScreenViewOptions } from "scenerystack/sim";

export class DopplerEffectScreenView extends ScreenView {
  public constructor(private readonly model: DopplerEffectModel, providedOptions?: ScreenViewOptions) {
    super(providedOptions);

    // … add child nodes, controls, ResetAllButton (see scenerystack-ui-controls) …
  }

  // Joist already advanced the model. Update rendering/tools here if needed.
  public override step(_dt: number): void {
    // View-only animation updates.
  }

  public reset(): void { /* reset view-only state; model.reset() is called by ResetAllButton */ }
}
```

## Screen icons (multi-screen)

Multi-screen sims need a `homeScreenIcon` on each `Screen` (and usually a `navigationBarIcon`).
Put shared `create*Icon()` factories in `src/common/<Prefix>ScreenIcons.ts` (see
`SceneryStackTemplate/doc/multi-screen.md` and the NAAP ports — BasicCoordinatesAndSeasons,
MotionsOfTheSun):

```typescript
import { ScreenIcon } from "scenerystack/sim";
import { Node, Rectangle } from "scenerystack/scenery";
import SimColors from "../SimColors.js";

const W = 548; // PhET standard icon canvas
const H = 373;

function iconFrom(content: Node): ScreenIcon {
  return new ScreenIcon(content, {
    maxIconWidthProportion: 1,
    maxIconHeightProportion: 1,
    fill: SimColors.backgroundColorProperty,
  });
}

export function createIntroIcon(): ScreenIcon {
  const root = new Node();
  root.addChild(new Rectangle(0, 0, W, H, { fill: SimColors.backgroundColorProperty }));
  // … scenery primitives using *Colors, not hardcoded hex …
  return iconFrom(root);
}
```

Wire each screen with `homeScreenIcon: createIntroIcon()`. Draw icons from scenery primitives
on the profile colors so projector mode stays consistent — don't ship static PNGs that drift
from the SVG brand icon (app icons still come from `npm run icons`).

## Rules

- Import `Sim` / `Screen` / `ScreenView` / `ScreenIcon` / `onReadyToLaunch` from
  **`scenerystack/sim`** (not a hand-rolled `joist` path).
- The `Screen` constructor takes **factories** (`() => model`, `(model) => view`), not pre-built instances — let joist call them.
- Joist calls the active screen model's `step(dt)` and then the view's `step(dt)`. Gate playback in the model; never add a second model advance in the view (see scenerystack-model).
- Graphs, trails, and simulation stopwatches follow changes in model time, including forced paused steps. Paused rendering frames add no samples; rewind trims samples from the abandoned future.
- Set `backgroundColorProperty` from `*Colors.ts` so projector mode works (see scenerystack-color-profiles).
- Use `optionize` with `ScreenOptions`/`ScreenViewOptions` as the parent type (see scenerystack-optionize).
- Keep `main.ts`'s bootstrap import order intact — `./brand.js` first (CONVENTIONS §1).
- One screen folder per `Screen`, kebab-case, with `model/` and `view/` inside it (CONVENTIONS §2).
- Multi-screen icons live in `src/common/<Prefix>ScreenIcons.ts`, one `create*Icon()` per screen.

## Common mistakes

- Passing `new Model()` / `new View()` instances to `Screen` instead of factory functions.
- Calling `model.step(dt)` from the ScreenView when joist already steps it → physics advances twice per frame.
- Hardcoding the background color instead of a `ProfileColorProperty`.
- Putting physics in `ScreenView.step` — it belongs in the model; the view updates presentation and tools.
- Reordering `main.ts` imports so `brand.js` is no longer first → breaks the bootstrap chain.
- Multi-screen sims with no `homeScreenIcon` / hardcoded bitmap icons that ignore `*Colors`.

Related skills: scenerystack-model, scenerystack-layout, scenerystack-ui-controls, scenerystack-color-profiles, scenerystack-optionize, scenerystack-preferences.
