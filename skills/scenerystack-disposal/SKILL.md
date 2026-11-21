---
name: scenerystack-disposal
description: Use when creating short-lived nodes, listeners, or Properties, or chasing a soak heap climb — dispose() vs disposeSubtree(), disposeEmitter, unlink, DerivedProperty/Multilink teardown, leak patterns found across the fleet, and heap-snapshot retainer tracing.
---

# SceneryStack Disposal & Memory

The #1 source of sim bugs is **leaked listeners**: an object subscribes to a Property that outlives it, so it is never garbage-collected and keeps reacting after it should be gone. Anything created dynamically (per particle, per wave, per game round) must clean up everything it created in `dispose()`. Objects that live for the whole sim (the model, the single ScreenView) generally never dispose.

## The rule of ownership

> If you `link`/`addListener`/`addInputListener` to something you **did not create**, you must undo it in `dispose()`. If you created the Property/Emitter yourself, disposing *it* is enough.

A `link` from a long-lived Property to a short-lived node is a leak waiting to happen — the Property holds the node alive.

## The `dispose` pattern

PhET style: capture all teardown in one `dispose…` closure built in the constructor, then call it from `dispose()` before `super.dispose()`.

```typescript
import { Node } from "scenerystack/scenery";

export class ParticleNode extends Node {
  private readonly disposeParticleNode: () => void;

  public constructor(particle: Particle, modelViewTransform: ModelViewTransform2) {
    super();

    // links to a Property this node does NOT own → must be undone
    const positionListener = (p: Vector2) => { this.translation = modelViewTransform.modelToViewPosition(p); };
    particle.positionProperty.link(positionListener);

    const colorMultilink = Multilink.multilink(
      [particle.chargeProperty, ParticleColors.positiveColorProperty],
      (charge, color) => { this.fill = charge > 0 ? color : ParticleColors.negativeColorProperty.value; },
    );

    this.disposeParticleNode = () => {
      particle.positionProperty.unlink(positionListener);
      colorMultilink.dispose();
    };
  }

  public override dispose(): void {
    this.disposeParticleNode();
    super.dispose();
  }
}
```

## DerivedProperty, Multilink, Emitter

`DerivedProperty` and `Multilink` subscribe to their dependencies, so they leak if their dependencies outlive them. Dispose them (or build them with owned dependencies):

```typescript
const speedProperty = new DerivedProperty([particle.velocityProperty], (v) => v.magnitude);
// ...later, when the owner goes away:
speedProperty.dispose();   // unlinks from velocityProperty for you
```

For a node tied 1:1 to a model element, link cleanup to the model element's own removal Emitter instead of writing manual bookkeeping.

## Owned node trees and asynchronous resources

Removing or disposing a parent is not evidence that every owned child, trace, tool, or derived accessibility Property was disposed. Inspect ownership explicitly. Unlink repaint listeners on global color Properties as well as model Properties, and dispose owned children that subscribe externally. When both are disposable, tear down views before models so unlinking still has live dependencies.

For asynchronous acquisition (microphone, sensor, device), invalidate the current request on Stop, reset, screen deactivation, or disposal. A generation/token check after each await, including audio resume, prevents an obsolete completion from updating status or replacing a newer error. Release resources returned by stale requests without tearing down a newer session. Record ownership as soon as each resource is created so partial startup failures can stop tracks, disconnect nodes, and close owned contexts.

## What a rebuilt node actually leaks

When a node rebuilds its children, the leaks usually come from localized string
Properties (`StringProperty`, `PatternStringProperty`, a `DerivedProperty` over strings)
and accessible-name Properties: a `Text`, label or `accessibleName` links to them for as
long as it exists. A color Property passed as `fill` or `stroke` is different. The node
subscribes to it only while drawn on a `Display` and releases it on removal, even without
`dispose()`. (A color Property you `link` yourself is a manual listener and still needs
an `unlink`.)

In memory-leak tests, assert listener counts on the string and accessible-name
Properties. Color-Property counts only reveal a leak if the test attaches the node to a
`Display`.

## Leak sources found in the fleet (headless soak, November 2026)

Each pattern below leaked memory in a real sim. Check for them first when the soak
reports a heap climb, and when reviewing any view that redraws.

1. **`Node.dispose()` does not dispose children.** Disposing a row, an `HBox`, a
   panel or a custom wrapper `Node` leaves every button, `Text` and `Path` inside it
   alive. Use `node.disposeSubtree()` to dispose a node together with everything under
   it. This was the most common cause, found in TransitHunter answer rows, the
   ColliderLab detector tracks, the ParticleZoo equation tokens, the SimplifiedMRI
   nucleus glyphs and the LewisStructures board.
2. **Redraw by replacing children.** `layer.children = […]`, `grid.rows = […]` and
   `removeAllChildren()` throw the old nodes away without disposing them. If any of them
   reads a string Property, an accessible-name Property or a model Property, it stays
   alive. Dispose the old children first:
   `for (const child of layer.children) { child.disposeSubtree(); }`. Better still,
   build the nodes once and update them in place: a pool of nodes you toggle `visible`
   on, or a single `Path` whose `shape` you change. Found in ColliderLab charts,
   StandingWaves node-marker captions and ParticleZoo plots and panels.
3. **Short-lived nodes that own a Property.** A
   `new PatternStringProperty(…)` or `DerivedProperty` passed as `accessibleName`
   or `string` is not disposed when the node is. Dispose it from the node:
   `node.disposeEmitter.addListener(() => nameProperty.dispose())`.
4. **Library components that link to a Property you pass in.** scenery-phet's
   `GridNode` links to its transform Property and never unlinks. Bamboo's `LinePlot`
   listens to its `ChartTransform` until disposed. Building a new one against a
   long-lived Property on every change keeps every old instance alive. OpticsLab now
   rebuilds the shape of one `Path` instead of creating new GridNodes. TrackLab now
   disposes each `LinePlot` when its track is removed.
5. **Rebuilding a control because its range changed.** `Slider` accepts
   `TReadOnlyProperty<Range>`; `HSlider`'s type allows only a fixed `Range`. Pass
   `numberProperty.rangeProperty` to `Slider`, which is horizontal by default, and build
   the slider once. AcceleratedMotion rebuilt its frame slider on every clip change, and
   each old slider's thumb, track and focus highlight survived.
6. **Pools that only grow.** A pool sized to the busiest moment never shrinks. Release
   it in the view's `reset()` (SimplifiedMRI photon pools).
7. **Shared closure context.** V8 gives every closure in a scope one shared context. A
   single undisposed `DerivedProperty` whose derivation is created in the same scope as
   a node's children keeps all of those children alive. The vegas
   `LevelCompletedNode` (SceneryStack 3.0.0) does this through
   `string_vegas_label_level_StringProperty`. Every Level Completed panel stays alive,
   even after `disposeSubtree()`. The bug is upstream, not in the sim.
8. **Mutable loop variables captured by listeners.** A listener that reads a shared
   `let` (`press: () => slewTo(cycle, event)`) sees whatever value the variable holds
   when the listener fires, not the value at the time the node was created. This is a
   correctness bug rather than a leak, and it often appears alongside one. Store the
   values on the pooled entry instead (SolarSystemModels timeline).

`RichText` and `disposeSubtree()` work together.
`RichText.dispose()` returns its pooled leaves to the pool before the recursion reaches
its children. A helper that first collects every descendant and then disposes each
one does corrupt the pool. Skip `RichText` internals in a helper like that.

## Finding a leak from a heap climb

1. **Rule out JIT warm-up.** Compiled-code growth can look like a leak. Take
   `v8.writeHeapSnapshot()` after `gc()` at 3 and 8 soak rounds, then diff the object
   counts by constructor. If the growth is `code:`, `TrustedByteArray`, Vite module
   strings and plain arrays, it is warm-up. SpectroscopyLab's failure was this kind of
   false positive. If a scenery or axon class (`Text`, `Path`, `GridNode`,
   `BooleanProperty`, `StarNode`) grows by a fixed amount each round, that class is
   leaking.
2. **Find the retaining path.** Run a breadth-first search from the snapshot's GC
   roots, skipping weak edges, and print the chain to the newest instances, which have
   the highest node `id`. The long-lived root at the top of the chain is the cause, for
   example a `LocalizedStringProperty`, a Colors Property, `stepTimer` or a model
   Property. Nodes that are still in the scene graph appear under `ScreenView._view` and
   are not leaks.
3. **Don't trust a plausible cause without checking it.** In TrackLab and
   LewisStructures, the first explanation (missing disposals) was reasonable, and
   fixing it changed nothing. The retaining path showed the real causes: the soak never
   stepped `stepTimer`, and the vegas closure.
4. **The soak must emit `stepTimer`.** Every keyboard `PressListener.click()` schedules
   its release with `stepTimer.setTimeout`. A harness that steps only the model and
   view never fires those timeouts, which keeps every clicked button alive. A running
   `Sim` emits `stepTimer` every frame, and the template harness now does the same.

## Dynamic collections

When the view mirrors a model `createObservableArray()` of unique particles, keep one node
per particle. Seed the view from existing items, then register one add listener and one
remove listener. If the view is disposed first, unregister both listeners before disposing
the remaining nodes.

```typescript
const particleNodes = new Map<Particle, ParticleNode>();
const addParticle = (particle: Particle): void => {
  const node = new ParticleNode(particle, modelViewTransform);
  particleNodes.set(particle, node);
  this.particleLayer.addChild(node);
};
const removeParticle = (particle: Particle): void => {
  const node = particleNodes.get(particle);
  if (node) {
    particleNodes.delete(particle);
    this.particleLayer.removeChild(node);
    node.dispose();
  }
};

model.particles.forEach(addParticle);
model.particles.addItemAddedListener(addParticle);
model.particles.addItemRemovedListener(removeParticle);

// In the constructor. Call this closure from dispose() before super.dispose().
this.disposeParticleCollection = () => {
  model.particles.removeItemAddedListener(addParticle);
  model.particles.removeItemRemovedListener(removeParticle);
  for (const particle of particleNodes.keys()) {
    removeParticle(particle);
  }
};
```

Test item removal and view disposal with items still present. Keep the model alive while
checking cleanup. See [the testing skill](../scenerystack-testing/SKILL.md#memory-leak-suite).

## Rules

- A node that is created and removed at runtime **must** override `dispose()` and undo every external `link`/`addInputListener` it made.
- Disposing a `DerivedProperty`/`Multilink`/`Emitter` you created unlinks it from its dependencies — prefer that to manual unlink bookkeeping.
- Remove a child from the scene graph **and** dispose it; `removeChild` alone does not dispose. Use `child.disposeSubtree()` when it has children of its own, since `dispose()` leaves them.
- Long-lived singletons (model, root ScreenView) don't need disposal — but anything they spawn per-object does.
- Mark a class that must never be disposed with `isDisposable: false` so an accidental `dispose()` throws instead of silently half-tearing-down.
- Owned children still require their own teardown when they subscribe externally; scene-graph ownership alone does not release global/model listeners.

## Common mistakes

- `someExternalProperty.link(listener)` in a dynamic node with no matching `unlink` in `dispose()` → classic leak; the node is retained forever.
- `removeChild(node)` without `node.dispose()` → the node's own listeners still fire.
- A `DerivedProperty` built on model Properties, created per dynamic object, never disposed.
- Leaving array listeners registered after the owning view is disposed, so later mutations still reach the view.
- Relying on Reset All to "clean up" — reset restores values, it does not dispose nodes.
- `container.dispose()` on a row or panel, expecting it to dispose the buttons inside it (use `disposeSubtree()`).
- `layer.children = newNodes` or `grid.rows = newRows` on every model change, with no dispose of the old ones.

Related skills: scenerystack-model, scenerystack-axon, scenerystack-testing,
scenerystack-drag-listener, scenerystack-code-review.
