---
name: scenerystack-model
description: Use when creating or changing a model — TModel, step(dt)/reset(), Properties, model/view separation. Trigger on model/ folders. GPU-only solvers: scenerystack-webgpu; Property APIs: scenerystack-axon.
---

# SceneryStack Model

The **model** holds the simulation's state and physics in pure model units (SI). It must not know the view exists. Views observe the model through reactive `Property`s and the per-frame `step(dt)`; the model never reaches into Scenery nodes.

## The `TModel` contract

A screen's top-level model implements `TModel` from `scenerystack/joist`, which requires `step(dt)` and `reset()`:

```typescript
import type { TModel } from "scenerystack/joist";
import { BooleanProperty, NumberProperty } from "scenerystack/axon";
import { Range, Vector2, Vector2Property } from "scenerystack/dot";

export class SimModel implements TModel {
  public readonly positionProperty: Vector2Property;
  public readonly speedProperty: NumberProperty;
  public readonly isRunningProperty: BooleanProperty;

  public constructor() {
    this.positionProperty = new Vector2Property(new Vector2(0, 0));
    this.speedProperty = new NumberProperty(0, { range: new Range(0, 343) });
    this.isRunningProperty = new BooleanProperty(true);
  }

  // advance the physics by dt seconds (real, unscaled time)
  public step(dt: number): void {
    if (!this.isRunningProperty.value) return;
    const p = this.positionProperty.value;
    this.positionProperty.value = p.plusXY(this.speedProperty.value * dt, 0);
  }

  // restore every Property to its initial value
  public reset(): void {
    this.positionProperty.reset();
    this.speedProperty.reset();
    this.isRunningProperty.reset();
  }
}
```

## State lives in Properties

Model state is a set of axon `Property`s, with derived quantities as `DerivedProperty`.
Expose read-only state as `TReadOnlyProperty<T>`. Patterns, Multilink, and read-vs-write
APIs: scenerystack-axon. Use `createObservableArray()` for collections the view mirrors.

## The frame loop

Joist calls the active screen model's `step(dt)` before the view's `step(dt)`, with elapsed **seconds**. Keep physics and playback gating here; subdivide inside the model when needed (see scenerystack-numerics). A view must not also advance that screen model.

Expose an explicit manual-step path that bypasses the playback gate while preserving pause, such as `stepOnce()` or an existing force-step argument. Calling the ordinary gated `step()` from a paused Step button does nothing. Avoid toggling playback temporarily: listeners may start unrelated work.

## State transitions, sampling, and history

Recording, seek/resume, samplers, and strategy edits are **review** concerns — see
[functional-review.md](../scenerystack-code-review/references/functional-review.md)
(and run a CRC with scenerystack-code-review). Do not treat that checklist as a general
model primer.

## GPU-only state

When the field lives only on the GPU, keep parameters in `model/` and the solver under a
documented `gpu/` carve-out — full pattern in scenerystack-webgpu.

## Rules

- **Model never imports from `view/`.** The dependency points one way: view → model. If a model file imports a Node, that logic belongs in the view.
- Every piece of mutable state is a `Property`; reset each one in `reset()`. A field you forget to reset is a Reset-All bug.
- Compute, don't cache: prefer `DerivedProperty` over manually updating a plain field in `step` (see scenerystack-axon).
- Keep physical constants in a `*Constants.ts` module in SI units (see scenerystack-constants); the model imports them.
- `step(dt)` works in real seconds; apply any "time speed" / slow-motion scaling explicitly, don't bake it into constants.
- Import `TModel` from `scenerystack/joist`, not `scenerystack/sim`.
- If state exists only on the GPU, follow scenerystack-webgpu — do not invent a fake CPU twin just to satisfy folder layout.

## Common mistakes

- A model class with `import { ... } from ".../view/..."` → inverts the architecture; move the code to the view.
- New `Property` added but not reset in `reset()` → Reset All leaves stale state.
- Doing layout math (pixels, `ModelViewTransform2`) in the model → coordinates are the view's job; the model is unit-only.
- Mutating a `DerivedProperty` by hand → it's computed; change its dependencies instead.
- Importing `TModel` from `scenerystack/sim` → wrong module; use `scenerystack/joist`.
- Stuffing WGSL/engine code into `model/` "because physics" → use scenerystack-webgpu.

Related skills: scenerystack-axon, scenerystack-constants, scenerystack-model-view-transform,
scenerystack-numerics, scenerystack-webgpu, scenerystack-testing.
