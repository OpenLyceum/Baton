---
name: scenerystack-animation
description: Use when something must move smoothly independent of physics step — panel slide, fade, ease-to-target, view transitions. Covers twixt Animation, Easing, chaining/looping, and animate vs integrate in step.
---

# SceneryStack Animation

Use **`scenerystack/twixt`** `Animation` for **view-level, time-based tweening**: smoothly interpolating a value (opacity, position, scale, a readout) from A to B over a duration with an easing curve. This is distinct from **physics**, which belongs in the model's `step(dt)` (see scenerystack-model). Rule of thumb: if it has units and obeys equations, integrate it in the model; if it's a presentational flourish, animate it with twixt.

## A basic tween

```typescript
import { Animation, Easing } from "scenerystack/twixt";

const fadeIn = new Animation({
  duration: 0.4,                       // seconds
  targets: [ {
    object: panel,
    attribute: "opacity",
    from: 0,
    to: 1,
  } ],
  easing: Easing.QUADRATIC_IN_OUT,
});
fadeIn.start();
```

`Animation` self-drives off the global clock once started — you don't tick it from `step`. It exposes `finishEmitter`, `stopEmitter`, and `endedEmitter` to react when it completes.

## Animating a Property

To ease a `Property` toward a value (e.g. a smoothed readout), target the Property directly:

```typescript
const slide = new Animation({
  duration: 0.3,
  property: cameraOffsetProperty,
  to: targetOffset,
  easing: Easing.CUBIC_OUT,
} );
slide.start();
```

## Chaining and interrupting

`then()` chains a follow-up animation; keep a reference so a new gesture can `stop()` an in-flight one before starting a fresh tween:

```typescript
this.activeAnimation?.stop();
this.activeAnimation = new Animation({ /* … */ });
this.activeAnimation.finishEmitter.addListener(() => { this.activeAnimation = null; });
this.activeAnimation.start();
```

## Rules

- Animate **presentation** (opacity, slide-in, highlight pulse), not physics. Forces, velocities, and anything with SI units integrate in the model `step(dt)`.
- An `Animation` runs on the global clock after `start()` — never call its private tick from your own `step`.
- Keep a reference to any animation that can be retriggered, and `stop()` the old one first so two tweens don't fight over the same target.
- Choose `Easing` by feel (`*_IN_OUT` for symmetric moves, `*_OUT` for "settling"); put durations in `*Constants.ts`, not inline.
- Respect Reset All: `stop()` running animations and snap targets to their reset values so a reset isn't visually "chased" by a tween.
- Dispose animations created for dynamic objects, or stop them when the owner goes away (see scenerystack-disposal).

## Common mistakes

- Driving game/physics motion through `Animation` instead of the model step → breaks pause/step, time-scaling, and determinism.
- Starting a new `Animation` on every drag/hover without stopping the previous one → stutter as overlapping tweens write the same attribute.
- Manually `step()`-ing an `Animation` from the ScreenView — it already runs on the global clock.
- Hardcoding durations/easings at each call site instead of a constants module.

Related skills: scenerystack-model, scenerystack-screen-view, scenerystack-constants, scenerystack-disposal.
