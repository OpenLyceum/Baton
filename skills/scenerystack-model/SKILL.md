---
name: scenerystack-model
description: Use when creating or changing a simulation's model — state, physics, the step(dt)/reset() loop, and reactive Properties. Covers the TModel contract, the model/view separation, GPU-only state carve-outs (common/gpu/), and how view code observes model state. Trigger on anything in a model/ folder.
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

Model state is a set of `Property`s (`NumberProperty`, `BooleanProperty`, `Vector2Property`, `EnumerationProperty`, `Property<T>`), with **derived** quantities as `DerivedProperty` so they recompute automatically:

```typescript
import { DerivedProperty } from "scenerystack/axon";

this.frequencyProperty = new DerivedProperty(
  [this.springConstantProperty, this.massProperty],
  (k, m) => Math.sqrt(k / m) / (2 * Math.PI),
);
```

Expose read-only state to the view as `TReadOnlyProperty<T>` so the view can observe but not assign it. Use `createObservableArray()` for collections of model objects (waves, particles) that the view mirrors.

## The frame loop

Joist calls the active screen model's `step(dt)` before the view's `step(dt)`, with elapsed **seconds**. Keep physics and playback gating here; subdivide inside the model when needed (see scenerystack-numerics). A view must not also advance that screen model.

Expose an explicit manual-step path that bypasses the playback gate while preserving pause, such as `stepOnce()` or an existing force-step argument. Calling the ordinary gated `step()` from a paused Step button does nothing. Avoid toggling playback temporarily: listeners may start unrelated work.

## State transitions, sampling, and history

- Reset the physical state before reseeding samplers. Clear fractional integration/emission accumulators, derivative buffers, cached averages, measured rates, and pending strategy edits when the action starts a fresh run. Presets and Clear Counts need their own documented scope; do not reset unrelated preferences or tools.
- On strategy changes, initialize from the current position and controls, then discard obsolete queued updates. Edits, undo, and redo must invalidate inspection cursors and caches that would otherwise show an old state.
- A sampled readout updates after the newest sample is appended. Derived velocities/accelerations need timestamps consistent with their stencil. Cache invalidation includes clock changes, even while paused; refreshing a dirty field with `step(0)` must not advance physics.
- Recording captures the current state at time zero before the first advance, including paused input edits and runs started by Step. Playback/seek applies the cursor state immediately and uses recorded state rather than a stale live-model end state.
- Clamp the last recording interval to the remaining duration, capture the endpoint, and pause immediately. Step/seek stays within retained history. Use one time scale for scrubber track, handle, and pointer mapping; navigation starts from the displayed bounded time after duration changes.
- Rewind of dissipative or chaotic motion restores saved state and physical parameters. Resuming branches history by discarding the old future. Reset/preset clears history even if time was already zero; timestamped trails trim on rewind and remain during pause.
- Resumed acquisition uses each previous sample's end time, not sample count times the current interval. Capture per-sample settings so rate changes do not rewrite old timestamps.

## GPU-only state (documented carve-out)

Fleet convention: physics lives under `src/**/model/` and the view never integrates it.
Some sims have **no CPU-side field to model** — velocity / pressure / dye exist only as
GPU textures, and nothing advances without a `GPUDevice`. In that case:

- Keep **parameters** and derived scalars (Reynolds number, regime, …) in a normal
  `*Model` under `model/` — no scenery, no GPU imports, unit-tested.
- Put the solver under `src/common/gpu/` (WGSL, bind layouts, engine), not
  `src/common/model/`.
- One bridge node (e.g. `FluidFieldNode`) is allowed to touch both worlds.
- Document the carve-out in the sim's `AGENTS.md` so compliance reviewers do not
  "fix" it back into `model/`.

References: FluidDynamics (WebGPU Stable Fluids), Resonance `WebGLParticleRenderer`.
For Playwright WebGPU flags see scenerystack-testing; for choosing CanvasNode vs GPU
see scenerystack-custom-drawing.

## Rules

- **Model never imports from `view/`.** The dependency points one way: view → model. If a model file imports a Node, that logic belongs in the view.
- Every piece of mutable state is a `Property`; reset each one in `reset()`. A field you forget to reset is a Reset-All bug.
- Compute, don't cache: prefer `DerivedProperty` over manually updating a plain field in `step`.
- Keep physical constants in a `*Constants.ts` module in SI units (see scenerystack-constants); the model imports them.
- `step(dt)` works in real seconds; apply any "time speed" / slow-motion scaling explicitly, don't bake it into constants.
- Import `TModel` from `scenerystack/joist`, not `scenerystack/sim`.
- If state exists only on the GPU, use the `common/gpu/` carve-out above and document it — do not invent a fake CPU twin just to satisfy folder layout.

## Common mistakes

- A model class with `import { ... } from ".../view/..."` → inverts the architecture; move the code to the view.
- New `Property` added but not reset in `reset()` → Reset All leaves stale state.
- Doing layout math (pixels, `ModelViewTransform2`) in the model → coordinates are the view's job; the model is unit-only.
- Mutating a `DerivedProperty` by hand → it's computed; change its dependencies instead.
- Importing `TModel` from `scenerystack/sim` → wrong module; use `scenerystack/joist`.
- Stuffing WGSL/engine code into `model/` "because physics" when there is no CPU state → fight the architecture; use `common/gpu/` and document it.

Related skills: scenerystack-constants, scenerystack-model-view-transform, scenerystack-numerics,
scenerystack-custom-drawing, scenerystack-testing.
