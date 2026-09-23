---
name: scenerystack-constants
description: Use when a number, size, color-independent magnitude, or physical parameter appears in code — define it in a *Constants.ts module instead of inlining a magic value. Covers the SI-unit constants pattern, layout constants, root vs documented nested extras, and as const grouping.
---

# SceneryStack Constants

Magic numbers don't belong in the body of a model or view. Each sim collects its fixed values into one or more `*Constants.ts` modules — physical parameters in **SI units**, layout values in pixels — so they're named, documented, and changed in one place.

## Physics / model constants (SI units)

Group related constants into frozen `as const` objects, with a file header documenting the unit convention and a unit comment on each value:

```typescript
/**
 * Units: distances in meters (m), velocities in m/s, frequencies in Hz,
 * time in seconds (s), angles in radians (rad).
 */
import { Vector2 } from "scenerystack/dot";

export const PHYSICS = {
  SOUND_SPEED: 343.0,      // speed of sound in air (m/s)
  EMITTED_FREQ: 4,         // base emitted frequency (Hz)
  MAX_SPEED_FACTOR: 0.9,   // cap on source speed relative to sound speed (dimensionless)
} as const;

export const INITIAL_POSITIONS = {
  SOURCE: new Vector2(-1000, 0),   // (m)
  OBSERVER: new Vector2(1000, 0),  // (m)
} as const;
```

`as const` makes the values readonly and gives each a literal type. The model and physics code import these; nobody writes `343.0` inline.

## Layout constants (pixels)

Keep spacing, margins, font sizes, and corner radii in a `*LayoutConstants.ts` / `*Constants.ts` used by the view (see scenerystack-layout):

```typescript
export const PANEL_CORNER_RADIUS = 8;
export const PANEL_X_MARGIN = 10;
export const CONTROL_PANEL_VBOX_SPACING = 6;
```

## Where constants live

Two layouts are accepted (CONVENTIONS.md §2); match the sim's existing choice and note any
non-default layout in `AGENTS.md`:

- **Single root file (the template default).** All sim-wide values in
  `src/<Prefix>Constants.ts`. Larger domains group inside that one file with frozen
  `as const` objects — e.g. VariableStarPhotometry (`FIELD`, `APERTURE`, `TIME`, `LAYOUT`,
  `FONT_SIZE`) or ExtrasolarPlanets (layout + SI physics + slider ranges + presets).
- **Root primary + documented nested extras.** The **primary** sim constants module lives
  at `src/<Prefix>Constants.ts`. Additional topical files are allowed when the domain
  warrants it and `AGENTS.md` says so — e.g. MazeGame's `maze-game/MazeGameLayoutConstants.ts`,
  TheRamp's `common/model/RampPhysicsConstants.ts`, Resonance's
  `chladni-patterns/model/ChladniConstants.ts`, OpticsLab's optics/light-source constants,
  or OscillationsAndChaos' topical `common/view/*Constants.ts` files.

Do **not** put the primary `<Prefix>Constants.ts` under `model/` or `common/` — that was
an older layout; the fleet moved primary modules to `src/` root. Don't invent a second
constants file when an existing one already covers the area.

## Rules

- A literal number with meaning (a length, speed, frequency, margin, duration, threshold) goes in a constants module with a name and a unit comment.
- State the units. SI throughout the model; the unit convention belongs in the file header and per-value comments.
- Use `as const` on grouped objects so values are immutable and well-typed.
- Constants are plain values, not `Property`s. Mutable state belongs in the model as a `Property` (see scenerystack-model); constants never change at runtime.
- `Color` literals are the exception — those live in `*Colors.ts` as `ProfileColorProperty` (see scenerystack-color-profiles), not in a constants file.
- Display strings are **not** constants — they go in `strings_*.json` (see scenerystack-strings).

## Common mistakes

- `if (speed > 343)` inline → name it `PHYSICS.SOUND_SPEED`.
- Repeating `10` as a margin across several nodes → one `PANEL_X_MARGIN`.
- Putting a hex color or a UI label in a constants file → those have dedicated homes (`*Colors.ts`, `strings_*.json`).
- Omitting units on a physical constant → ambiguous; always annotate.

Related skills: scenerystack-model, scenerystack-layout, scenerystack-color-profiles, scenerystack-query-parameters.
