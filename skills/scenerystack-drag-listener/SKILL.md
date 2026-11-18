---
name: scenerystack-drag-listener
description: Use whenever a node must be draggable by mouse, touch, or keyboard — DragListener, KeyboardDragListener, RichDragListener, positionProperty+transform, drag bounds, dual-input a11y.
---

# SceneryStack Drag Listeners

Dragging is added by attaching an input listener to a node with `node.addInputListener(listener)`. Three listeners cover the cases:

| Listener | Input | Use when |
|---|---|---|
| `DragListener` | mouse + touch | pointer dragging |
| `KeyboardDragListener` | arrow keys / WASD | keyboard accessibility for the same object |
| `RichDragListener` | **both** mouse/touch **and** keyboard | the normal choice — one listener, accessible by default |

All three import from `scenerystack/scenery`. Prefer **`RichDragListener`** for new draggable objects so the object is keyboard-accessible without extra wiring — but first check what already owns the arrow keys (next section).

## Before adding keyboard drag: find out what already owns the arrows

`RichDragListener` binds the arrow keys. If something else on the same node already binds them, **both handlers fire on every press** — there is no conflict detection. Check for all three before reaching for it:

- **An existing `HotkeyData`-derived `KeyboardListener`.** Many sims already nudge the model with arrows and document that binding in the keyboard help dialog. Adding a drag listener double-binds *and* orphans the `HotkeyData` (see scenerystack-keyboard-help-dialog).
- **An `AccessibleSlider` / `AccessibleValueHandler` mixin.** These own arrows, Home/End, and Page Up/Down. A node built on `AccessibleSlider` should stay on a plain `DragListener`.
- **A global `KeyboardListener.createGlobal`.** It fires regardless of focus, so it collides with anything focus-scoped.

When the keyboard path already exists, use a plain `DragListener` for the pointer and say why:

```typescript
// Pointer-only: arrows already nudge the model via FooHotkeyData.MOVE_THING, which is the
// binding the keyboard help renders. A RichDragListener would bind the same keys twice.
node.addInputListener(new DragListener({ drag: (event) => { /* ... */ } }));
```

## Put the keyboard half on the node that takes focus

`hotkeyManager` only activates a listener's hotkeys when the **listener's node is in the focus trail** — the root→focused-node path. A listener on a *descendant* of the focused node is never reached, so arrow keys silently do nothing. No assertion, no type error, no lint warning.

This bites whenever the grab target and the focusable node differ (a thin handle inside a focusable panel, a 3D event target inside a focusable view). `RichDragListener` exposes both halves so you can split them:

```typescript
const drag = new RichDragListener({
  dragListenerOptions: { /* pointer */ },
  keyboardDragListenerOptions: { dragDelta: STEP, shiftDragDelta: FINE_STEP, drag: (_e, l) => { /* ... */ } },
});
handle.addInputListener(drag.dragListener);          // pointer grabs the small handle
container.addInputListener(drag.keyboardDragListener); // keyboard lives on the focusable node
```

`drag.dispose()` still tears down both. Remember to `removeInputListener` from *both* nodes.

## The idiomatic pattern: `positionProperty` + `transform`

Let the listener own the model↔view conversion. Give it the model `positionProperty`, the `ModelViewTransform2`, and optional `dragBoundsProperty` (in model coordinates). The listener writes model coordinates straight back into the property; your node updates because it already links to that property.

```typescript
import { DragListener, KeyboardDragListener, RichDragListener } from "scenerystack/scenery";

// node follows the model
model.positionProperty.link((position) => {
  this.translation = modelViewTransform.modelToViewPosition(position);
});

const dragListener = new DragListener({
  targetNode: this,
  positionProperty: model.positionProperty,   // updated in MODEL coords
  transform: modelViewTransform,
  dragBoundsProperty: model.dragBoundsProperty,
});
this.addInputListener(dragListener);

// keyboard equivalent — same property + transform
const keyboardDragListener = new KeyboardDragListener({
  positionProperty: model.positionProperty,
  transform: modelViewTransform,
  dragBoundsProperty: model.dragBoundsProperty,
  dragSpeed: 100,        // px/s
  shiftDragSpeed: 50,    // px/s with Shift held (fine control)
});
this.addInputListener(keyboardDragListener);
```

`RichDragListener` combines the two and also exposes model-space deltas in its `drag` callback:

```typescript
const drag = new RichDragListener({
  transform: modelViewTransform,
  start: () => { /* grab */ },
  drag: (_event, listener) => {
    const { x: dx, y: dy } = listener.modelDelta; // already in model units
    setPoint(getPoint().x + dx, getPoint().y + dy);
  },
  end: () => { /* commit / record history */ },
});
handle.addInputListener(drag);
```

## `dragDelta` vs `dragSpeed`, and never discard `modelDelta`'s magnitude

The keyboard half runs in one of two modes, and picking the wrong one changes how often `drag` fires:

| Option pair | Mode | `drag` fires |
|---|---|---|
| `dragDelta` / `shiftDragDelta` | discrete step per key press | once per press |
| `dragSpeed` / `shiftDragSpeed` | continuous, px per second | **every animation frame while held** (driven by `stepTimer`) |

The two pairs are **mutually exclusive** — the listener asserts if you pass both. Use `dragDelta` when one press should mean one step of a quantity (a date, a detent, a coordinate nudge); use `dragSpeed` only when the object should glide.

Whichever you pick, apply `listener.modelDelta` **with its magnitude**. Reducing it to a direction breaks both options at once:

```typescript
// WRONG — shiftDragDelta becomes a no-op (both magnitudes sign to ±1), and under dragSpeed
// this steps once per frame (~60 steps/second) regardless of the speed you configured.
raProperty.value += Math.sign(listener.modelDelta.x) * RA_STEP_HOURS;

// RIGHT — express the deltas in model units and scale by them.
// dragDelta: RA_STEP_HOURS, shiftDragDelta: RA_STEP_HOURS / 4
raProperty.value += listener.modelDelta.x;
```

When one listener drives two axes with different units, keep the deltas in abstract "steps" (`dragDelta: 1`, `shiftDragDelta: 0.25`) and multiply per axis — `modelDelta.x * RA_STEP_HOURS`, `modelDelta.y * DEC_STEP_DEG`. Both approaches keep Shift meaningful.

## When you can't use `positionProperty` (custom mapping)

Some objects don't move 1:1 with the pointer (e.g. a velocity vector set from the drag direction). Use the raw callbacks and convert manually through the transform:

```typescript
new DragListener({
  targetNode,
  dragBoundsProperty: new Property(dragBounds),
  start: (event) => {
    const viewPos = modelViewTransform.modelToViewPosition(positionProperty.value);
    this.dragOffset = viewPos.minus(event.pointer.point); // pointer → object offset
  },
  drag: (event) => {
    const viewPoint = event.pointer.point.plus(this.dragOffset);
    positionProperty.value = modelViewTransform.viewToModelPosition(viewPoint);
  },
});
```

## Rules

- Convert coordinates **only** through the screen's `ModelViewTransform2` (see scenerystack-model-view-transform). Never hand-roll `* scale`.
- Every pointer-draggable object that matters for interaction needs *a* keyboard path — but only *one*. Reach for `RichDragListener` when the object has no keyboard path yet; leave a plain `DragListener` when an existing `HotkeyData` listener or an `AccessibleSlider` mixin already owns the arrows.
- `dragBoundsProperty` is in **model** coordinates when you pass a `transform`. Keep it on the model so physics and view agree.
- **Don't pass `allowTouchSnag: true` — it is already `DragListener`'s default.** Pass it only to turn snagging *off* (`false`), e.g. when a parent needs the touch stream.
- A focusable draggable node needs `tagName` **and** `accessibleName`. Setting `focusable = true` without a `tagName` is a silent no-op: with no PDOM element there is nothing to focus, so the node never enters the tab order.
- One listener **instance** per node. A `DragListener` carries per-press state and a `pressedTrail`; adding the same object to two nodes makes them share it. Construct a second listener instead.
- Dispose listeners you create dynamically: keep the reference, call `removeInputListener(listener)` and `listener.dispose()` in the node's `dispose()`. A `KeyboardDragListener`'s hotkeys keep a disposed node reachable otherwise — remove *before* disposing.

## Common mistakes

- Writing **view** pixels into a model `positionProperty` (forgot the `transform`) → object jumps and bounds break.
- Mouse-only `DragListener` with no keyboard path anywhere → fails accessibility; reach for `RichDragListener`.
- Recreating the offset math when `positionProperty` + `transform` would have done it for free.
- Putting the keyboard half on a descendant of the focusable node → arrows silently do nothing, and nothing catches it.
- Adding `RichDragListener` to a node whose arrows are already claimed → two handlers fire per press, usually with different step sizes.
- `Math.sign(listener.modelDelta.…)` → kills Shift's fine step and, under `dragSpeed`, steps once per frame.

## Verifying it works

None of the failures above produce a type error or a lint warning, and they survive a build. Check the keyboard path by hand or in a test: focus the node, press an arrow, and assert the model Property actually changed. If you moved a listener between nodes, tab to the object first — if it never receives focus, the listener is on the wrong node.

Related skills: scenerystack-model-view-transform, scenerystack-model, scenerystack-accessibility, scenerystack-keyboard-help-dialog.
