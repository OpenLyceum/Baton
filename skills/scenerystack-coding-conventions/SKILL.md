---
name: scenerystack-coding-conventions
description: Use when writing or reviewing TypeScript in an OpenLyceum SceneryStack sim — naming, constructor signatures (positional params + options object), documentation style, access modifiers, type inference, enumerations, optionize, TReadOnlyProperty annotations, assertions, non-null assertions, excess-property checking, and read-vs-write Property APIs. Trigger when deciding how to structure a class/method or when a review flags a style/convention issue.
---

# SceneryStack TypeScript Coding Conventions

How TypeScript is written in OpenLyceum SceneryStack sims (SceneryStack template: Vite + TypeScript +
**Biome**, source under `src/`). Adapted from PhET's coding conventions and trimmed to what applies here.
Formatting and import ordering are enforced by `biome.json` (`npm run lint` / `npm run fix`) — this skill
covers the judgment calls Biome can't make. Related skills: scenerystack-optionize,
scenerystack-constants, scenerystack-color-profiles, scenerystack-strings, scenerystack-accessibility.

## General style

- **Descriptive, specific names** — no non-standard abbreviations.

  ```ts
  const numPart = 100;            // ❌
  const numberOfParticles = 100;  // ✅
  const width = 150;              // ❌ (of what?)
  const beakerWidth = 150;        // ✅
  ```

- **Constructors: positional params for required no-default values, an options object for everything
  with a default.** Removes order-dependence and makes call sites readable. Pass options through with
  `optionize` (see scenerystack-optionize).

  ```ts
  type BallNodeOptions = { fill?: TColor; lineWidth?: number } & NodeOptions;

  class BallNode extends Node {
    public constructor( ball: Ball, visibleProperty: TReadOnlyProperty<boolean>,
                        providedOptions?: BallNodeOptions ) {
      const options = optionize<BallNodeOptions, SelfOptions, NodeOptions>()(
        { fill: "white", lineWidth: 1 }, providedOptions );
      super( options );
    }
  }
  ```

- **No `self = this`.** Use arrow functions — they capture `this` lexically.

  ```ts
  someProperty.link( () => { this.doSomething(); } );  // ✅
  ```

- Keep lines within **120 columns**; break long statements/comments.
- Invoke functions with the dot operator, not bracket notation — use a ternary or `if`/`else`:

  ```ts
  this[ isSmile ? "smile" : "frown" ]();        // ❌
  isSmile ? this.smile() : this.frown();        // ✅
  ```

- Short-circuit and ternary with parentheses for readability; single-item expressions may drop them:

  ```ts
  ( foo && bar ) ? fooBar() : fooCat();
  assert && assert( happy, "Why aren't you happy?" );
  ```

- **Every `Property` instance name ends in `Property`** (`visibleProperty`, not `visible`). Use the
  type-specific subclass (`BooleanProperty`, `NumberProperty`, `StringProperty`) or document why not.
- **Filenames:** `CapitalizedCamelCase.ts` for a class/constructor export (name must match the class);
  `lowerCamelCase.ts` for a singleton or utility export.
- **No frame-rate assumptions** in model/view. The max `dt` is capped by the screen; there is no minimum
  `dt`, so handle arbitrarily small time steps. Step from the model's `step(dt)` chain (see
  scenerystack-model), never `setTimeout`/`setInterval`.
- Enumerations are **deeply immutable**; mutable enum values signal a design problem.
- **Fonts are `PhetFont`** (`new PhetFont( 16 )`, `new PhetFont( { size: 14, weight: "bold" } )`), usually
  held in `<Prefix>Constants.ts`. Never pass CSS font strings such as `"16px sans-serif"` to scenery
  nodes. Only a raw Canvas `ctx.font` takes a string; read it from the `PhetFont` (`font.toCSS()`).

## Documentation

Enough for a developer moderately familiar with SceneryStack to understand purpose and usage quickly.

- Document all classes, methods, and properties. Each source file opens with an overview comment of its
  purpose and responsibilities; for subclasses, state what is added or overridden.
- Distinguish `Property` (an Axon reactive type) from a plain object **field**. Prefer "field" in prose
  when you mean a plain property.
- Precede line comments with a blank line; put a space after `//`.
- Conditionals: a comment above the first `if` describes the **whole** conditional; comments about a
  single block go just inside it, with a blank line below; don't interrupt `if`/`else if`/`else`.
- Keep `@author` annotations accurate.

## TypeScript

### Access modifiers

Prefer the built-in modifiers over JSDoc visibility tags. `public` = public API; `protected` =
subclasses only; `private` = within the class; `readonly` = set once (usually in the constructor).
TSDoc comments may still document intent (e.g. `// scenery-internal`).

### Formatting & lint

Formatting, import ordering, and many mechanical rules are enforced by **Biome** (`biome.json`), not
ESLint. Run `npm run lint` before submitting; `npm run fix` auto-applies safe fixes. (PhET's
`@typescript-eslint`/`phet` plugin rules do not apply to this repo.)

### Philosophy

Per the [TypeScript Design Goals](https://github.com/Microsoft/TypeScript/wiki/TypeScript-Design-Goals),
strike a balance between correctness and productivity — TypeScript serves the project. Prefer readable
solutions over type gymnastics.

### Leverage type inference

Annotate **function/method signatures** and **public return types** (use explicit `void` for no return);
let TypeScript infer **local variables**. Same for generic params.

```ts
const x = 7;                         // ✅ inferred
const x: number = 7;                 // ❌ redundant
const x = volatileExpression();      // annotate only if the type is unclear/unstable
new Property( new Laser() );         // ✅ inferred
new Property<Laser>( new Laser() );  // ❌ redundant
```

### Enumerations

- **String-literal unions are the default** — idiomatic and lightweight.
- `as const` on a `string[]` exposes both the union and runtime values; pairs with `StringUnionProperty`.
- Use `EnumerationValue` + `EnumerationProperty` only when you need rich instance methods.

### Parameter types

Be **liberal in what you accept** — type parameters as generally as the implementation allows.

```ts
function computeHabitat( animal: Animal ): Habitat { ... }  // ✅ not Dog, if bark() is unused
```

### Prefer `TReadOnlyProperty` for annotations

Type constructor params and fields as `TReadOnlyProperty<T>` rather than a concrete `DerivedProperty<...>`
to minimize coupling.

```ts
constructor( halfLifeProperty: TReadOnlyProperty<number>,
             isStableProperty: TReadOnlyProperty<boolean> ) { ... }
```

### Options and optionize

**Always use `optionize` (from `scenerystack/phet-core`), never `merge`.** Full pattern in
scenerystack-optionize:

```ts
type SelfOptions = { fill?: TColor };
type BallNodeOptions = SelfOptions & NodeOptions;

const options = optionize<BallNodeOptions, SelfOptions, NodeOptions>()(
  { fill: "white" }, providedOptions );
```

### Instance & static properties

Initialize instance properties at the declaration site, in the constructor body, or as parameter
properties — be consistent within a class. Document a property at its **declaration**; add notes at the
**assignment** site when the assigned value needs explaining. Short statics read well grouped at the top
of the class; long multi-line statics may go at the bottom.

### Exports and imports

**Classes use named exports** — never `export default class` (the compliance gate fails it).
Default exports are reserved for the template's singleton objects: `<Prefix>Namespace`,
`<Prefix>Colors`, and `<prefix>QueryParameters`.

Because the project transpiles per-file (`isolatedModules`), **export types separately** with
`export type` (either at the declaration or at end of file). For **imports, combine** all names — values
and types — from one file into a single statement, and end relative paths in `.js`:

```ts
export type BallNodeOptions = SelfOptions & NodeOptions;
export class BallNode extends Node { ... }

import { BallNode, type BallNodeOptions } from "./BallNode.js";  // ✅ one statement
```

### Assertions

Assert **runtime invariants the type checker can't see** — not things TypeScript already guarantees.
Guard assertions with `assert && assert( ... )` (the project's `src/assert.ts` wiring keeps them out of
production builds).

```ts
assert && assert( particles.length > 0, "must have at least one particle" );  // ✅
assert && assert( typeof count === "number" );                                 // ❌ already typed
```

### TSDoc

Don't duplicate type info in TSDoc and the signature. If you document one `@param`, document **all** of
them (and `@returns`); otherwise omit them entirely.

### Non-null assertion (`!`)

Biome's `noNonNullAssertion` warns on `!` in `src/` (QuantumPotential raises it to an error); the
template turns it off only for `tests/**`.
Prefer values that can't be null in the first place, then narrow with a check that fails loudly. Under
`noUncheckedIndexedAccess`, array reads are `T | undefined`; a small throwing helper (QuantumPotential's
`defined()`) keeps hot loops readable without `!`. Factor out a variable instead of repeating the check.

```ts
// activeParticle is always set before this runs — see initializeRound().
const particle = this.activeParticle;
assert && assert( particle !== null, "initializeRound() must run first" );
if ( particle ) { particle.reset(); }

const energy = defined( energies[ n ] );   // throws on a missing element instead of `energies[ n ]!`
```

When `!` is genuinely needed, comment why it's safe; a sim that silences the rule for dense numeric
kernels says so in its `AGENTS.md`.

### Excess property checking

TypeScript flags excess properties only on **object literals assigned directly** to a typed target.
**Pass option objects as inline literals** at the call site so typos in option keys are caught.

```ts
const p: PersonOptions = { name: "Martin", agee: 42 };  // ✅ error: 'agee'
const obj = { name: "Martin", agee: 42 };
const p2: PersonOptions = obj;                           // ❌ typo slips through
```

### Read vs write Property APIs

When a field is publicly readable but only internally writable, pick one pattern below — **never** a
writable public field with a "don't write this" comment.

**Pattern 1 — dual references** (preferred when the Property itself must be public): a `public readonly`
`TReadOnlyProperty<T>` and a `private readonly` (underscore-prefixed) writable `Property<T>` pointing at
the same instance. Use `protected` if subclasses must write.

```ts
public readonly positionProperty: TReadOnlyProperty<Vector2>;
private readonly _positionProperty: Property<Vector2>;
// constructor: this._positionProperty = new Vector2Property( ... ); this.positionProperty = this._positionProperty;
```

**Pattern 2 — getter for the value** (callers need only the current value):

```ts
public get position(): Vector2 { return this.positionProperty.value; }
```

**Pattern 3 — getter for the Property as read-only** (callers observe reactively); back it with an
underscore-prefixed field:

```ts
public get positionProperty(): TReadOnlyProperty<Vector2> { return this._positionProperty; }
```

Patterns 1 and 3 suit reactive observers; Pattern 2 suits value-only access.

## Further reading

- scenerystack-optionize, scenerystack-constants, scenerystack-color-profiles, scenerystack-strings
- [TypeScript Design Goals](https://github.com/Microsoft/TypeScript/wiki/TypeScript-Design-Goals)
- *Effective TypeScript* — Dan Vanderkam (Items 11, 19, 29)
