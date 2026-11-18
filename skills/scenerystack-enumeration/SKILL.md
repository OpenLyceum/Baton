---
name: scenerystack-enumeration
description: Use when a fixed named choice is bound to radios/combo or EnumerationProperty — EnumerationValue pattern. Prefer string unions for local/non-Property choices; see scenerystack-coding-conventions.
---

# SceneryStack Enumeration

When a **Property-backed** choice is "one of a fixed set" (mode = wave | particle, tool =
ruler | timer | none) and binds to radios/combo boxes, model it with the
**`EnumerationValue` class pattern** from `scenerystack/phet-core` and an
**`EnumerationProperty`** from `scenerystack/axon`. The enum carries real instances, so a
`Property` of it works cleanly with controls and `Multilink`.

**String-literal unions** remain fine for local/non-Property choices (function args,
narrow internals, one-off switches). Prefer `EnumerationValue` when the value is model
state behind a Property or needs rich instance methods — aligned with
scenerystack-coding-conventions.

## The pattern

A class extends `EnumerationValue`, declares its members as `static readonly` instances, and exposes a `static enumeration`:

```typescript
import { Enumeration, EnumerationValue } from "scenerystack/phet-core";

export class SourceMode extends EnumerationValue {
  public static readonly CONTINUOUS = new SourceMode();
  public static readonly PULSE = new SourceMode();
  public static readonly SINGLE = new SourceMode();

  // MUST be last — registers the members above for name/value lookup
  public static readonly enumeration = new Enumeration(SourceMode);
}
```

The `enumeration` field must be the **last** static — it reflects over the already-defined members.

## Backing it with a Property

```typescript
import { EnumerationProperty } from "scenerystack/axon";

this.sourceModeProperty = new EnumerationProperty(SourceMode.CONTINUOUS);

// react to it
this.sourceModeProperty.link((mode) => {
  if (mode === SourceMode.PULSE) { /* … */ }
});
```

Iterate members via `SourceMode.enumeration.values`, and switch on identity (`=== SourceMode.PULSE`).

## Binding to controls

`EnumerationProperty` drops straight into radio/combo controls (see scenerystack-ui-controls):

```typescript
new AquaRadioButtonGroup(model.sourceModeProperty, [
  { value: SourceMode.CONTINUOUS, createNode: () => new Text(continuousStringProperty) },
  { value: SourceMode.PULSE,      createNode: () => new Text(pulseStringProperty) },
  { value: SourceMode.SINGLE,     createNode: () => new Text(singleStringProperty) },
]);
```

## Rules

- Use `EnumerationValue` + `EnumerationProperty` for Property-backed named choices bound to radios/combo (or when members need methods).
- Prefer a string-literal union (optionally `as const` + `StringUnionProperty`) for local/non-Property choices.
- The `static enumeration = new Enumeration(ThisClass)` line goes **last**, after every member.
- Reset the `EnumerationProperty` in the model's `reset()` like any other Property (see scenerystack-model).
- Compare by identity (`mode === SourceMode.PULSE`) — members are singletons.
- Provide user-visible labels at the control via localized `*StringProperty`s (see scenerystack-strings), not on the enum.
- Use `Enumeration`/`EnumerationValue` from `phet-core`, not the deprecated `EnumerationDeprecated`.

## Common mistakes

- Magic numbers instead of an enum or string union → weak typing and awkward radio groups.
- Using a string union for a Property bound to radios/combo when `EnumerationProperty` would be clearer.
- Declaring `static enumeration` before the members → it can't see them; it must be last.
- Forgetting to reset the `EnumerationProperty` in `reset()` → mode survives Reset All.
- Comparing with deep equality instead of `===` — members are unique instances.
- Reaching for `EnumerationDeprecated` in new code.

Related skills: scenerystack-model, scenerystack-ui-controls, scenerystack-strings,
scenerystack-coding-conventions, scenerystack-axon.
