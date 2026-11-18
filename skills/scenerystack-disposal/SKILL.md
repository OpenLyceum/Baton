---
name: scenerystack-disposal
description: Use when creating short-lived nodes, listeners, or Properties — dispose(), disposeEmitter, unlink, DerivedProperty/Multilink teardown, and leak patterns caught by fuzz/memory-leak tests.
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
- Remove a child from the scene graph **and** call `child.dispose()`; `removeChild` alone does not dispose.
- Long-lived singletons (model, root ScreenView) don't need disposal — but anything they spawn per-object does.
- Mark a class that must never be disposed with `isDisposable: false` so an accidental `dispose()` throws instead of silently half-tearing-down.
- Owned children still require their own teardown when they subscribe externally; scene-graph ownership alone does not release global/model listeners.

## Common mistakes

- `someExternalProperty.link(listener)` in a dynamic node with no matching `unlink` in `dispose()` → classic leak; the node is retained forever.
- `removeChild(node)` without `node.dispose()` → the node's own listeners still fire.
- A `DerivedProperty` built on model Properties, created per dynamic object, never disposed.
- Leaving array listeners registered after the owning view is disposed, so later mutations still reach the view.
- Relying on Reset All to "clean up" — reset restores values, it does not dispose nodes.

Related skills: scenerystack-model, scenerystack-axon, scenerystack-testing,
scenerystack-drag-listener, scenerystack-code-review.
