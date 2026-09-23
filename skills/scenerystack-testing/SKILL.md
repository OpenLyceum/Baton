---
name: scenerystack-testing
description: Use when adding or changing unit tests for a simulation — writing vitest specs for model/physics code, setting up the test harness, or adding fuzz/Playwright specs. Covers the standardized tests/ layout, vitest config, memory-leak suites (forceGC early-exit), what is worth testing, optional Playwright fuzz, and WebGPU launch flags for GPU sims.
---

# SceneryStack Testing

Every OpenLyceum SceneryStack sim ships Vitest unit tests under root `tests/` and a
`test` script in `package.json`. CI runs `npm test` when that script is present. Prefer
testing the **model** (pure logic, physics, math) — not Scenery rendering.

Algorithm-heavy sims (OpticsLab, Resonance, WaveComposer, MazeGame, SternGerlach, Zenith,
ExtrasolarPlanets, MotionsOfTheSun, …) carry denser suites; PhET ports often start with a
smoke + reset suite and grow physics invariants over time. SceneryStackTemplate is the layout
reference (CONVENTIONS §5).

## The standardized layout

```
tests/
  setup.ts                 vitest setup (Canvas/Audio mocks, init({ name }))
                           — happy-dom default; see carve-out below
  memory-leak.test.ts      WeakRef + --expose-gc dispose regression (fleet pattern)
  **/*.test.ts             unit tests, mirroring the source tree under tests/
  **/*.spec.ts             Playwright specs, if any (e.g. tests/fuzz/)
vitest.config.ts           include: ["tests/**/*.test.ts"];
                           setupFiles: ["./tests/setup.ts"]  // happy-dom sims
                           execArgv: ["--expose-gc"]         // required with leak suite
```

Tests live **only** under root `tests/` — never co-located next to source, never in
`__tests__/` (the compliance gate fails on those). Mirror the source path: a test for
`src/optics-lab/model/Lens.ts` is `tests/optics-lab/model/Lens.test.ts`.

**Documented carve-out:** pure-math suites that alias `scenerystack` → `scenerystack/dot`
(jsdom) or run under `node` (no DOM) may omit `tests/setup.ts` / `setupFiles` when no Canvas
or `init()` is needed — note that in the sim's `AGENTS.md` (DopplerEffect,
VariableStarPhotometry, WaveComposer). See CONVENTIONS §5.

## A model unit test

Test physics/algorithm code directly — construct the model object, step or call it, assert
on Property values:

```typescript
import { describe, it, expect } from "vitest";
import { Vector2 } from "scenerystack/dot";
import { LensModel } from "../../../src/optics-lab/model/LensModel.js";

describe("LensModel", () => {
  it("forms a real image beyond the focal point (thin-lens equation)", () => {
    const lens = new LensModel({ focalLength: 1 });
    lens.objectPositionProperty.value = new Vector2(-3, 0);

    // 1/f = 1/do + 1/di  ⇒  di = 1.5 for f=1, do=3
    expect(lens.imageDistanceProperty.value).toBeCloseTo(1.5, 6);
    expect(lens.imageTypeProperty.value).toBe("real");
  });

  it("resets every Property", () => {
    const lens = new LensModel({ focalLength: 1 });
    lens.objectPositionProperty.value = new Vector2(-5, 2);
    lens.reset();
    expect(lens.objectPositionProperty.value).toEqual(lens.objectPositionProperty.initialValue);
  });
});
```

## Memory-leak suite

Ship `tests/memory-leak.test.ts` modeled on SceneryStackTemplate / QubitSketch:

- Require `execArgv: ["--expose-gc"]` in `vitest.config.ts`.
- Allocate inside a **function** boundary, call `dispose()`, hold a `WeakRef`, then
  call `forceGC(ref)` (or `forceGC(refs)`) until the ref is cleared.
- **Always pass the `WeakRef`(s) into `forceGC`.** The template helper early-exits once
  every ref is collected. Calling `forceGC()` with no args runs all GC passes and can
  exceed Vitest's `testTimeout` on a slow `gc()`.
- Prefer disposing a real model (`TimeModel`, screen model, or a known disposable helper
  like Resonance `ListenerTracker`). When the sim has no disposable model yet, dispose a
  `NumberProperty` to keep the harness green and document the gap.
- Dynamic sims that add/remove nodes at runtime should expand the suite like OpticsLab.

## What to test

- **Physics / math:** closed-form results, conservation laws, edge cases (zero, `Range`
  boundaries, sign flips).
- **`reset()` completeness:** after mutating state, `reset()` restores initial values.
- **Derived quantities:** `DerivedProperty` recomputes when dependencies change.
- **Not** Scenery layout/rendering — covered by build + optional fuzz.

## Optional Playwright fuzz

SceneryStackTemplate ships `tests/fuzz/fuzz.spec.ts` + `playwright.config.ts` +
`scripts/test-fuzz.ts` with `npm run test:fuzz` / `test:fuzz:quick` / `test:fuzz:long`.
Fuzz uses joist's `?fuzz&ea` query parameters (fuzz plus enable-assertions) and fails on
console/`pageerror` or an assertion failure. Use it for pre-release / CRC stress; it is not
required in the default CI path.

Duration is **30 seconds** by default. Change it without editing the spec:

```bash
npm run test:fuzz                 # 30s
npm run test:fuzz:quick           # 10s
npm run test:fuzz:long            # 300s
npm run test:fuzz -- 90           # 90s
npm run test:fuzz -- --duration 90
FUZZ_DURATION=90 npm run test:fuzz
```

`scripts/test-fuzz.ts` forwards extra Playwright args (`npm run test:fuzz -- 60 --headed`).
The Playwright test timeout is `FUZZ_DURATION + 120s` so a long run is not killed by the
default 5-minute cap. Always include `&ea` in the fuzz URL — without it assertions are silent.

## WebGPU / GPU sims in Playwright

Headless Chromium often returns `null` from `navigator.gpu.requestAdapter()` unless
launched with WebGPU enabled. For engine / screenshot suites (e.g. FluidDynamics
`tests/fuzz/engine.spec.ts`):

```typescript
chromium.launch({
  args: ["--enable-unsafe-webgpu", "--enable-features=Vulkan"],
});
```

To exercise a no-WebGPU fallback path deliberately:

```typescript
chromium.launch({
  args: ["--disable-features=WebGPU,WebGPUService"],
});
```

Absence of `vulkaninfo` on the host is **not** evidence that WebGPU is unavailable —
verify with a real browser launch. GPU engine suites may be slow on software rasterizers;
keep them out of the default `npm test` path and document skip conditions in the sim's
`AGENTS.md`.

## Rules

- Put tests only under root `tests/`, mirroring the source tree; setup file is
  `tests/setup.ts` (CONVENTIONS §5).
- Test the model, not the view.
- Import sim source through the `src/…/*.js` path (`verbatimModuleSyntax`).
- Always include a `reset()` test for any model with state.
- Document the vitest `environment` in the sim's `AGENTS.md`; don't change it casually.
- Run `npm test` plus `npm run check && npm run build` before pushing.

## Common mistakes

- Co-locating `*.test.ts` beside source or using `__tests__/` → fails the compliance gate.
- Testing rendered pixels/layout in a unit test instead of model logic.
- Adding a `vitest.setup.ts` at root instead of `tests/setup.ts`.
- Asserting floating-point physics with `toBe`/`toEqual` instead of `toBeCloseTo`.
- Skipping the `reset()` test — the single highest-value model test.
- Memory-leak helpers that allocate in a block scope (not a function) — V8 won't collect.
- Calling `forceGC()` with no `WeakRef` args → suite times out instead of early-exiting.
- Assuming WebGPU works in Playwright without the launch flags above → adapter is `null`.

Related skills: scenerystack-model, scenerystack-code-review, scenerystack-disposal,
scenerystack-numerics.
