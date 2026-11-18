---
name: scenerystack-layout
description: Use when positioning nodes — layoutBounds, VBox/HBox/GridBox, AlignBox/AlignGroup, struts, Panel. For control widgets themselves see scenerystack-ui-controls.
---

# SceneryStack Layout

Lay out the scene with **layout containers and `layoutBounds`**, not hand-computed pixel coordinates. The two tools you reach for constantly are the screen's `layoutBounds` (for edge/centre placement) and `VBox`/`HBox` (for stacking content).

## `layoutBounds`: the fixed design rectangle

Every `ScreenView` has `this.layoutBounds`, a constant-size rectangle (default 1024×768-ish) that the framework scales to fit the window. Position top-level nodes relative to it so the sim looks right at any window size.

```typescript
// anchor a panel to the top-right with a shared margin
controlPanel.right = this.layoutBounds.maxX - MARGIN;
controlPanel.top   = this.layoutBounds.minY + MARGIN;

// centre something
title.centerX = this.layoutBounds.centerX;

// the model-view transform usually pins the model origin to a layoutBounds point
ModelViewTransform2.createSinglePointScaleInvertedYMapping(
  Vector2.ZERO, this.layoutBounds.center, SCALE,
);
```

Use `this.visibleBounds` (which changes with aspect ratio) only for things that must hug the actual window edge; use `layoutBounds` for the stable design layout.

## Stacking: `VBox` / `HBox`

`VBox` stacks children vertically, `HBox` horizontally. Set `spacing` and `align`; let the box compute positions. These are by far the most common containers in the sims.

```typescript
import { VBox, HBox } from "scenerystack/scenery";

const content = new VBox({
  spacing: LayoutConstants.CONTROL_PANEL_VBOX_SPACING,
  align: "left",                 // "left" | "center" | "right"
  children: [header, tabs, pad],
});

const row = new HBox({ spacing: 8, children: [icon, label] });
```

Boxes re-layout automatically when a child resizes (e.g. a localized label grows). Don't read `.width`/`.bottom` and manually offset siblings — add them to a box.

## Aligning to a common size: `AlignBox` / `AlignGroup`

To make several nodes share one footprint (equal-width buttons, aligned panel rows), wrap each in an `AlignBox` tied to one `AlignGroup`:

```typescript
import { AlignGroup } from "scenerystack/scenery";

const group = new AlignGroup();
const a = group.createBox(nodeA, { xAlign: "left" });
const b = group.createBox(nodeB, { xAlign: "left" }); // a and b now equal width
```

## Spacers and panels

- `HStrut(width)` / `VStrut(height)` — fixed-size invisible spacers inside a box.
- `GridBox` — two-dimensional rows/columns when a single VBox/HBox isn't enough.
- `Panel` (from `scenerystack/sun`) — bordered container for a control group; style its `fill`/`stroke`/`cornerRadius`/`xMargin`/`yMargin` from `*Colors.ts` and layout constants.

## Rules

- Position top-level nodes against `layoutBounds` (or `visibleBounds` for window-hugging); never against hardcoded screen dimensions.
- Stack/align with `VBox`/`HBox`/`AlignGroup` instead of setting each child's `.x`/`.y` by hand.
- Pull spacings, margins, and font sizes from a `*LayoutConstants`/`*Constants` file — **no magic pixel numbers** at the call site.
- Layout must survive a locale change: a translated label may be wider/taller, so rely on boxes (which re-flow) rather than measured offsets.

## Common mistakes

- `node.x = 724` style absolute coordinates → breaks on resize and at other locales.
- Computing `siblingB.top = siblingA.bottom + 10` manually → use a `VBox` with `spacing: 10`.
- Anchoring overlays to `layoutBounds` when they must touch the real window edge → use `visibleBounds` there.
- Repeating the same margin literal in many files → hoist to a layout-constants module.

Related skills: scenerystack-ui-controls, scenerystack-optionize,
scenerystack-model-view-transform, scenerystack-accessibility.
