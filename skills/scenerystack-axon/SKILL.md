---
name: scenerystack-axon
description: Use when wiring reactive state with axon — Property, NumberProperty, BooleanProperty, DerivedProperty, Multilink, TReadOnlyProperty, link/unlink, or read-vs-write Property APIs. Covers ownership, derived quantities, and exposing read-only Properties to the view.
---

# SceneryStack Axon (Properties)

Axon `Property`s are the reactive state bus between model and view. Prefer type-specific
subclasses (`NumberProperty`, `BooleanProperty`, `Vector2Property`, `EnumerationProperty`,
`StringProperty`) over a bare `Property<T>` unless the value type has no subclass.

Deep disposal / leak patterns: scenerystack-disposal. Model `step`/`reset` ownership:
scenerystack-model. TypeScript style around Properties: scenerystack-coding-conventions.

## Create and observe

```typescript
import { NumberProperty, DerivedProperty } from "scenerystack/axon";
import { Range } from "scenerystack/dot";

const massProperty = new NumberProperty(0.25, { range: new Range(0.1, 2) });
massProperty.link((value) => { /* react */ });

const frequencyProperty = new DerivedProperty(
  [massProperty, springConstantProperty],
  (m, k) => Math.sqrt(k / m) / (2 * Math.PI),
);
```

- Every `Property` instance name ends in `Property` (`visibleProperty`, not `visible`).
- Annotate constructor params and public fields as `TReadOnlyProperty<T>` when the
  caller must not write.
- Prefer `DerivedProperty` over hand-syncing a plain `Property` in `step`.
- `Multilink.multilink([...], callback)` (or `new Multilink(...)`) when several
  dependencies must update together — dispose / `unmultilink` if you do not own them.

## Read vs write Property APIs

When a field is publicly readable but only internally writable, pick one pattern —
**never** a writable public field with a "don't write this" comment.

**Pattern 1 — dual references** (preferred when the Property itself must be public):

```ts
public readonly positionProperty: TReadOnlyProperty<Vector2>;
private readonly _positionProperty: Property<Vector2>;
// constructor: this._positionProperty = new Vector2Property(...);
//              this.positionProperty = this._positionProperty;
```

**Pattern 2 — getter for the value** (callers need only the current value):

```ts
public get position(): Vector2 { return this.positionProperty.value; }
```

**Pattern 3 — getter for the Property as read-only**:

```ts
public get positionProperty(): TReadOnlyProperty<Vector2> {
  return this._positionProperty;
}
```

## Rules

- Mutable model/view state lives in Properties; reset each owned Property in `reset()`.
- Type outward APIs as `TReadOnlyProperty<T>`; keep the writable `Property` private/protected.
- Compute with `DerivedProperty` / `Multilink`; do not mutate a `DerivedProperty` by hand.
- If you `link` to a Property you did not create, `unlink` in `dispose()` (see
  scenerystack-disposal).
- Name every Property instance `*Property`.

## Common mistakes

- Hand-updating a plain field in `step` that should be a `DerivedProperty`.
- Exposing a writable `Property` publicly with a comment saying "view must not write".
- Forgetting to `reset()` a new Property → Reset All leaves stale state.
- Linking a short-lived node to a long-lived Property without `unlink` → leak.

Related skills: scenerystack-model, scenerystack-disposal, scenerystack-enumeration,
scenerystack-coding-conventions, scenerystack-testing.
