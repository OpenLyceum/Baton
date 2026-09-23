---
name: scenerystack-custom-drawing
description: Use when rendering custom graphics that the standard nodes don't cover — drawing a curve, a filled region, an arrow, a dynamic path, choosing a renderer for performance, or painting dense fields (fringes, fluids) via CanvasNode / WebGL / WebGPU. Covers Path + kite Shape, scenery-phet helpers, renderer hints, and spectral colour (CIE XYZ vs VisibleColor).
---

# SceneryStack Custom Drawing

Most visuals are built from ready-made nodes (`Rectangle`, `Circle`, `Line`, `Text`, `Image` in `scenerystack/scenery`; `ArrowNode` and friends in `scenerystack/scenery-phet`). When you need an arbitrary outline or filled region — a wave trace, a field line, a swept area — draw a **`Path`** whose geometry is a **kite `Shape`**. Geometry comes from `scenerystack/kite`; the node from `scenerystack/scenery`.

## Path + Shape

```typescript
import { Path } from "scenerystack/scenery";
import { Shape } from "scenerystack/kite";

const shape = new Shape()
  .moveTo(0, 0)
  .lineTo(50, -20)
  .quadraticCurveTo(80, -40, 120, 0)
  .close();

const curve = new Path(shape, {
  stroke: WaveColors.traceProperty,   // ProfileColorProperty, not a literal (see scenerystack-color-profiles)
  lineWidth: 2,
  fill: null,
});
```

## Redrawing a dynamic curve

For a trace that changes each frame, rebuild the `Shape` and assign it — don't mutate points in place. Build view-space points through the `ModelViewTransform2` (see scenerystack-model-view-transform):

```typescript
model.samplesProperty.link((samples) => {
  const shape = new Shape();
  samples.forEach((sample, i) => {
    const v = modelViewTransform.modelToViewPosition(sample);
    i === 0 ? shape.moveTo(v.x, v.y) : shape.lineTo(v.x, v.y);
  });
  this.curve.shape = shape;          // reassign; scenery re-renders the Path
});
```

Reassigning `shape` each frame is fine for typical sample counts. If profiling shows it's hot, give the `Path` a `canvas`/`webgl` renderer hint (below) before reaching for anything exotic.

## Ready-made drawing helpers

Prefer these over re-deriving the geometry:

- `ArrowNode` (`scenery-phet`) — vectors/forces, with configurable head/tail.
- `Line` (`scenery`) — a single straight segment.
- `DashedLineNode`, `BracketNode`, `LaserPointerNode`, `MeasuringTapeNode`, `RulerNode` (`scenery-phet`) — common physics overlays.

## Renderer hints & performance

Scenery picks SVG by default. For many frequently-changing nodes or large fills, hint a different renderer on the node (or a container) via options:

```typescript
new Path(shape, { renderer: "canvas" });   // or "webgl" for many sprite-like nodes
```

Apply hints **only after profiling** — premature renderer switches often hurt. Batch dynamic graphics under one parent and hint the parent rather than each child.

## Dense fields: CanvasNode vs WebGL / WebGPU

When every pixel is an intensity (interferograms, fluid dye, spectrograms), a `Path` is the
wrong tool. Prefer, in order:

1. **`CanvasNode`** (`scenerystack/scenery`) — paint into the scenery canvas callback. Keeps
   physics in testable TypeScript (no GLSL twin), stays in the scene graph / layout /
   a11y tree. InterferometryLab's `FringePatternNode` is the fleet reference.
2. **WebGL** (e.g. Resonance particle renderer) — many sprites / particles where a CPU
   buffer cannot keep up.
3. **WebGPU compute** (e.g. FluidDynamics) — the field *is* GPU state; there is no CPU
   model to step. Document the `src/common/gpu/` carve-out in the sim's `AGENTS.md`
   (see scenerystack-model).

Do **not** open a bare `<canvas>` / `CanvasRenderingContext2D` outside scenery — that
escapes layout and accessibility. `CanvasNode` is the supported escape hatch.

## Spectral colour: do not average sRGB

`scenery-phet`'s `VisibleColor` is fine for **single-wavelength** chrome (laser pointers,
wavelength sliders). It is wrong for **sums** of wavelengths (white-light interferograms,
broadband spectra): averaging per-λ sRGB yields yellow-green, not white.

Sum in **linear light via CIE XYZ**, then encode to sRGB (InterferometryLab
`spectralColor.ts` — Wyman/Sloan/Shirley CMF fits + equal-energy white balance). Keep
optical path lengths / wavelengths in the model; convert units at the view boundary.

## Rules

- Geometry is a kite `Shape`; the node is a scenery `Path`. For dense pixel fields use
  `CanvasNode` (or a documented WebGL/WebGPU renderer) — not a raw DOM canvas.
- Convert model points to view space through the screen's `ModelViewTransform2` — never multiply by a scale by hand (see scenerystack-model-view-transform).
- Color/stroke from `*Colors.ts` `ProfileColorProperty`s so projector mode and theming work (see scenerystack-color-profiles). Canvas `fillStyle` / `addColorStop` values that represent **theme chrome** still belong in `*Colors.ts`; spectral physics colours are computed, not profiled.
- Rebuild and reassign `path.shape` for dynamic curves; keep `lineWidth`/sample counts in `*Constants.ts`.
- Reach for an existing `scenery-phet` node (`ArrowNode`, `RulerNode`, …) before hand-drawing the same thing.
- Treat `renderer: "canvas"/"webgl"` as a profiling-driven optimization, not a default.
- Prefer CPU/`CanvasNode` when the field is still cheap enough to stay in one testable TS module; move to WebGL/WebGPU only when measured necessary or when state lives only on the GPU.

## Common mistakes

- Drawing to a bare HTML canvas/`CanvasRenderingContext2D` instead of a scenery `Path` or `CanvasNode` → escapes the scene graph, layout, and accessibility.
- Hardcoding stroke/fill colors instead of `ProfileColorProperty`.
- Hand-rolling an arrow with `Line`s when `ArrowNode` exists.
- Mutating a `Shape`'s internal points expecting a redraw — assign a new `shape` instead.
- Switching to WebGL "for speed" without profiling → often slower for a handful of paths.
- Averaging `VisibleColor` / sRGB across wavelengths → broadband light looks yellow-green instead of white.
- Putting theme hex/`addColorStop` literals in a canvas painter instead of `*Colors.ts` → projector mode and dark profile break (see RadioWaves CRC).

Related skills: scenerystack-model-view-transform, scenerystack-color-profiles, scenerystack-constants, scenerystack-layout, scenerystack-model.
