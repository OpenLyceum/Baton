---
name: scenerystack-accessibility
description: Use when making a sim usable with keyboard and screen reader — accessibleName, help text, announcements, KeyboardListener/HotkeyData, interactive highlights. Covers PDOM naming and the InteractiveHighlighting mixin.
---

# SceneryStack Accessibility

SceneryStack sims are built to be fully usable by keyboard and screen reader. Every interactive node lives in the **Parallel DOM (PDOM)** — an accessible HTML representation of the scene — and dynamic changes are spoken via **accessible responses**. This skill covers the four pillars: naming/describing, responding, keyboard input, and highlights. (The Keyboard Shortcuts dialog has its own skill: scenerystack-keyboard-help-dialog.)

## 1. Names, help text, and descriptions (PDOM)

Give every focusable/interactive node an accessible name; add help text and paragraphs for context. All values are localized `StringProperty`s (see scenerystack-strings) so the screen reader follows the locale.

```typescript
new Panel(content, {
  accessibleName: a11yStrings.controlPanelStringProperty,      // the element's label
  accessibleHelpText: a11yStrings.controlPanelHelpStringProperty, // supplementary hint
});

// static descriptive prose in the PDOM (not tied to a control)
new Node({ accessibleParagraph: a11yStrings.levelCompleteStringProperty });

// low-level PDOM shaping when needed
new Node({ tagName: "div", labelTagName: "h3", ariaRole: "application" });
```

Reading order in the PDOM is controlled with `pdomOrder` (independent of visual/z-order). A **`ScreenView` throws if you set `pdomOrder` on itself**, so use one of the two sanctioned patterns (pick one per sim — see [ACCESSIBILITY.md §3](../../ACCESSIBILITY.md)):

```typescript
// (a) a lightweight wrapper Node that "borrows" the interactive nodes (template default)
this.addChild(new Node({ pdomOrder: [playArea, controlPanel, resetAllButton] }));

// (b) the protected pdomPlayAreaNode / pdomControlAreaNode (PhET-idiomatic)
this.pdomPlayAreaNode.pdomOrder = [playArea];
this.pdomControlAreaNode.pdomOrder = [controlPanel, resetAllButton];
```

A **screen summary** describes the whole screen at the top of the PDOM. Each `ScreenView` registers a `*ScreenSummaryContent` (extends `ScreenSummaryContent` from `scenerystack/sim`) through the **`screenSummaryContent` option in its `super(...)` call** — not by overriding a method — so every sim wires it the same way:

```typescript
import { ScreenSummaryContent } from "scenerystack/sim";

super({
  screenSummaryContent: new SimScreenSummaryContent(model),
  // ...other ScreenView options
});
```

`ScreenSummaryContent` supplies four regions: `playAreaContent` (what the play area holds), `controlAreaContent` (what the controls do), `currentDetailsContent` (a **live** `DerivedProperty` over model state), and `interactionHintContent` (how to start). See the shared [ACCESSIBILITY.md](../../ACCESSIBILITY.md) convention and `SceneryStackTemplate/src/sim-screen/view/SimScreenSummaryContent.ts` for the canonical pattern.

## 2. Accessible responses (announcing change)

When model state changes, speak it by queuing an accessible response on a node in the PDOM. Pass a `StringProperty` for simple alerts, or an `Utterance` when you need de-duplication / priority / delay:

```typescript
import { Utterance } from "scenerystack/utterance-queue";

// simple, one-off alert
descriptionAlertNode.addAccessibleResponse(a11yStrings.collisionAlertStringProperty);

// reusable Utterance — repeated changes won't spam the queue
this.levelChangedUtterance = new Utterance({ alert: a11yStrings.levelChangedStringProperty });
descriptionAlertNode.addAccessibleResponse(this.levelChangedUtterance);
```

Centralize this in a small "describer" class that links model Properties → responses, keeping description logic out of the visual nodes.

## 3. Alternative (keyboard) input

Interactive objects must be operable without a mouse. For dragging, use `RichDragListener`/`KeyboardDragListener` (see scenerystack-drag-listener). For discrete key actions, use `KeyboardListener`, and **derive its keys from a shared `HotkeyData`** so behavior and the help dialog stay in sync:

```typescript
import { HotkeyData, KeyboardListener } from "scenerystack/scenery";

const HotkeyData_MOVE = new HotkeyData({
  keys: ["arrowLeft", "arrowRight", "arrowUp", "arrowDown", "a", "d", "w", "s"],
  repoName: "maze-game",
  global: true,
  binderName: "Move Particle",
});

const listener = new KeyboardListener({
  keys: [...HotkeyData_MOVE.keys],
  fireOnHold: true,
  fire: (event, keysPressed) => { /* act on keysPressed */ },
});
node.addInputListener(listener);
```

A node that handles keys must be focusable and named: give it a `tagName` (e.g. `"div"` or `"button"`) and an `accessibleName`, or it won't be reachable in the PDOM.

**Global hotkeys** (active regardless of focus) use `KeyboardListener.createGlobal` or a `HotkeyData` with `global: true`:

```typescript
const globalListener = KeyboardListener.createGlobal(targetNode, {
  keys: ["space"],
  fire: () => model.togglePause(),
});
```

Always dispose listeners you create dynamically (`removeInputListener` + `listener.dispose()` in the node's `dispose()`).

## 4. Interactive highlights

Interactive Highlights draw a focus outline when the **mouse** hovers an interactive object (not just on keyboard focus), helping switch/low-vision users. Mix `InteractiveHighlighting` into the node's class:

```typescript
import { InteractiveHighlighting, Path } from "scenerystack/scenery";

// mixin applied to a base type
const hitPath = new (InteractiveHighlighting(Path))(shape, { /* options */ });
```

Built-in components (buttons, sliders, drag handles via `RichDragListener`) already include highlighting. Enable the user toggle with `supportsInteractiveHighlights: true` in `PreferencesModel` (see scenerystack-preferences). Set a custom `focusHighlight` shape when the default bounds outline is misleading.

## Rules

- Every interactive/focusable node has an `accessibleName`. No silent controls.
- All a11y text is a localized `StringProperty` from `StringManager`, grouped in an a11y-strings getter.
- Derive `KeyboardListener` keys and keyboard-help rows from one shared `HotkeyData` — never duplicate key lists.
- Announce meaningful state changes with `addAccessibleResponse`; use an `Utterance` for anything that repeats.
- Control PDOM reading order with `pdomOrder`; don't rely on child order.
- Put description logic in a describer/summary class, not scattered through visual nodes.
- Dispose dynamically-created listeners.

## Common mistakes

- A draggable/clickable node with no `tagName`/`accessibleName` → invisible to keyboard and screen reader.
- Hardcoded English alert text → not localized; use a `StringProperty`.
- Firing a fresh response on every frame → floods the queue; reuse an `Utterance`.
- Duplicating key bindings between the `KeyboardListener` and the help dialog → they drift; share `HotkeyData`.
- Enabling `supportsInteractiveHighlights` but building custom nodes that don't mix in `InteractiveHighlighting` → those objects show no hover highlight.

Related skills: scenerystack-keyboard-help-dialog, scenerystack-drag-listener, scenerystack-strings, scenerystack-preferences, scenerystack-i18n.
