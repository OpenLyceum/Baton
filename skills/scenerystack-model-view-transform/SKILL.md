---
name: scenerystack-model-view-transform
description: Use when converting model↔view coordinates or scaling physical quantities to pixels — ModelViewTransform2 factories and the model-vs-view coordinate convention.
---

# SceneryStack ModelViewTransform2

The model thinks in **physical units** (meters, radians, SI). The view thinks in **pixels**. A `ModelViewTransform2` is the single bridge between them. Create it once in the `ScreenView` constructor, store it, and pass it to any node that draws model objects. **Never multiply by a raw scale factor by hand** — go through the transform so the whole sim stays consistent.

## Creating the transform

Pick the factory that matches your coordinate convention. Two screen-space conventions dominate:

```typescript
import { ModelViewTransform2 } from "scenerystack/phetcommon"; // also re-exported from "scenerystack"
import { Vector2 } from "scenerystack/dot";

// Physics convention: model +y points UP, origin at screen center.
this.modelViewTransform = ModelViewTransform2.createSinglePointScaleInvertedYMapping(
  Vector2.ZERO,                 // model origin
  this.layoutBounds.center,     // where the model origin lands in the view
  SCALE.MODEL_VIEW,             // pixels per model unit
);

// Screen convention: model +y points DOWN (matches pixel space), no inversion.
const modelViewTransform = ModelViewTransform2.createSinglePointScaleMapping(
  Vector2.ZERO,
  new Vector2(centerX, centerY),
  scale,
);

// Map a model rectangle onto a view rectangle (inverts y).
this.modelViewTransform = ModelViewTransform2.createRectangleInvertedYMapping(
  modelBounds,        // Bounds2 in model space
  this.playAreaViewBounds, // Bounds2 in view space
);
```

Choose `InvertedY` when the model uses the standard math/physics convention (y increases upward). Choose the plain mapping when the model already works in screen-down coordinates (e.g. a ported sim whose tuned motion presets assume +y is down).

## Using the transform

```typescript
// position
const viewPoint  = mvt.modelToViewPosition(model.positionProperty.value);
const modelPoint = mvt.viewToModelPosition(node.center);

// scalars / deltas (use Delta variants — they ignore translation)
const radiusPx   = mvt.modelToViewDeltaX(model.radius);
const dyModel    = mvt.viewToModelDeltaY(dragDeltaY);

// xy convenience
const m = mvt.viewToModelXY(px, py);
```

Keep a node positioned by linking it to the model property through the transform:

```typescript
model.positionProperty.link((position) => {
  this.translation = mvt.modelToViewPosition(position);
});
```

## Rules

- One transform per screen, built in the `ScreenView` and **passed down** to child nodes (constructor arg, often typed `ModelViewTransform2` or `type ModelViewTransform2`).
- Convert **deltas/sizes** with the `Delta` methods, **points** with the `Position` methods. Mixing them is the #1 source of "everything is offset by half the screen" bugs.
- Define the pixels-per-unit scale as a named constant (e.g. `SCALE.MODEL_VIEW` in `SimConstants.ts`), not a magic number at the call site.
- For drag input, convert the pointer with the same transform — see scenerystack-drag-listener.

## Common mistakes

- Inverting y twice (model already screen-down **and** using an `InvertedY` factory) → motion looks upside down.
- Using `modelToViewPosition` for a width/height → the translation term corrupts the size; use `modelToViewDeltaX/Y`.
- Recomputing a hand-rolled `value * scale` in one node while the rest of the sim uses the transform → subtle drift.

Related skills: scenerystack-drag-listener, scenerystack-layout, scenerystack-model.
