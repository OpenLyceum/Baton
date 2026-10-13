---
name: scenerystack-numerics
description: Use when writing the numerical core of a model — integrating motion over dt, choosing a stable time step, clamping or mapping values, or using the dot math utilities. Covers fixed vs. variable time steps, Euler vs. higher-order integration, Utils/LinearFunction/dotRandom, toFixed (never Number.toFixed), and keeping physics deterministic.
---

# SceneryStack Numerics

Physics models advance state in `step(dt)` (see scenerystack-model). The two recurring numerical concerns are **integration stability** (does the simulation blow up or drift at large `dt`?) and **using the shared math helpers** in `scenerystack/dot` instead of hand-rolling. Keep all of this in the model, in SI units.

## Fixed vs. variable time step

A raw frame `dt` varies (tab backgrounded, slow device) and large steps destabilize stiff systems (springs, orbits). The fix is a **fixed-timestep accumulator**: subdivide the frame into constant sub-steps so the integrator always sees a small, stable `dt`.

```typescript
private accumulator = 0;
private static readonly FIXED_DT = 1 / 120;   // s — in *Constants.ts, not inline

public step(dt: number): void {
  if (!this.isRunningProperty.value || !Number.isFinite(dt) || dt <= 0) return;
  // clamp a huge dt (e.g. returning to a backgrounded tab) so we don't spiral
  this.accumulator += Math.min(dt, 0.1);
  while (this.accumulator >= SimModel.FIXED_DT) {
    this.integrate(SimModel.FIXED_DT);
    this.accumulator -= SimModel.FIXED_DT;
  }
}
```

## Duration and boundary contracts

Reject nonfinite durations before integration. A forward-only advance treats zero and negative durations as no-ops; do not force a minimum substep. A separate paused refresh may recompute dirty derived fields without changing time. If an API intentionally supports signed integration, subdivide by `abs(dt)` and apply the sign to each substep; keep that distinct from history-based rewind.

Define what happens to excess frame time when catch-up is capped. Reset any residual accumulator for a fresh run. Include equality in event/recording-limit crossings so an event exactly at a frame endpoint is handled once rather than skipped.

Keep input bounds distinct from integration bounds: a slider/drag range need not clamp solver state. If a physical wall is enabled while an object is outside it, resolve the contact immediately. Collision tests include all domain edges and out-of-domain positions, not only cells inside the grid.

## Choosing an integrator

- **Semi-implicit (symplectic) Euler** — update velocity, then position with the *new* velocity. Cheap and energy-stable for oscillators; the usual default.
- **RK4** — fourth-order; use when accuracy matters (orbits, sensitive trajectories) and the extra force evaluations are affordable.
- **Forward (explicit) Euler** — simplest but gains energy on oscillators; avoid for springs/orbits.

```typescript
private integrate(dt: number): void {
  const a = this.netForce() / this.mass;
  this.velocity = this.velocity.plusXY(0, a * dt);          // v first
  this.position = this.position.plus(this.velocity.timesScalar(dt));  // then x with new v
}
```

## Solver and equation checks

Preserve the state-vector layout used by every solver and mapper (for example interleaved position/velocity pairs). Splitting integrators such as PEFRL assume separable position/velocity dynamics; damping or velocity-dependent coupling may require an RK fallback. Check compatibility when parameters change, and keep the fallback on the selected timestep.

Validate derivatives against an independent calculation, such as finite differences of position at zero and nonzero drive amplitude. Check analytical energy expressions independently of the force implementation. For grading discrete measurements, compare the unrounded answer to the expected tick with a small conversion tolerance; rounding to a tick first can award credit to invalid answers.

## dot utilities — don't reinvent

`scenerystack/dot` carries the math you'd otherwise rewrite:

```typescript
import {
  Utils, LinearFunction, dotRandom, Range,
  toFixed, toFixedNumber,
} from "scenerystack/dot";

const clamped = Utils.clamp(value, range.min, range.max);
const label   = toFixed(value, 2);                          // string, cross-browser rounding
const rounded = toFixedNumber(value, 2);                    // numeric round to N places
const mapped  = new LinearFunction(0, 100, 0, 343)(percent); // linear remap, with clamp option
const jitter  = dotRandom.nextDoubleBetween(-1, 1);          // seedable RNG — deterministic fuzz
```

Prefer the named `toFixed` / `toFixedNumber` exports (or `Utils.toFixed` /
`Utils.toFixedNumber`) — **never** JavaScript's `Number.prototype.toFixed`, which has
cross-browser rounding inconsistencies. For RTL readouts in i18n-sensitive UI, use
`StringUtils.toFixedLTR` / `toFixedNumberLTR` instead (see scenerystack-i18n).

Use `dotRandom` (seedable) rather than `Math.random()` so fuzz runs and replays are reproducible. `Vector2`/`Matrix3`/`Range` provide the vector and interval algebra.

## Rules

- Subdivide unstable physics with a fixed sub-step; clamp the incoming frame `dt` so a long pause can't inject a giant step.
- Keep `step(dt)` in **real seconds**; apply slow-motion / time-speed as an explicit multiplier, never baked into constants (echoes scenerystack-model).
- Put `FIXED_DT`, tolerances, and physical constants in `*Constants.ts` in SI units (see scenerystack-constants).
- Prefer `Utils.clamp`/`LinearFunction`/`Vector2` math over open-coded arithmetic — clearer and tested.
- Format displayed numbers with `toFixed` / `toFixedNumber` from `scenerystack/dot`, not `Number.toFixed`.
- Use `dotRandom`, not `Math.random()`, anywhere randomness must be reproducible.
- For oscillators/orbits use semi-implicit Euler or RK4; reserve forward Euler for non-stiff, non-conservative motion.

## Common mistakes

- Integrating directly with the raw frame `dt` → instability/jitter on slow frames or after the tab is backgrounded.
- Baking a time-scale factor into a constant so "real seconds" no longer means seconds.
- Forward Euler on a spring/orbit → energy creeps up and the sim visibly drifts.
- `Math.random()` in model code → non-reproducible fuzz failures you can't replay.
- Re-implementing clamp/lerp/round inline instead of `Utils`/`LinearFunction`.
- `value.toFixed(2)` (native) in a readout or a11y string → use `toFixed(value, 2)` from `scenerystack/dot`.

Related skills: scenerystack-model, scenerystack-constants, scenerystack-testing.
