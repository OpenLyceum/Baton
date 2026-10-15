---
name: scenerystack-testing
description: Use when adding or changing unit tests for a simulation — writing vitest specs for model/physics code, listing disposables in the memory-leak suite, or adding fuzz/Playwright specs. Covers the standardized tests/ layout, the template-owned setup and describeDisposalLeaks harness (idempotentDispose, forceGC early-exit), what is worth testing, pointer + keyboard fuzz, tests/browser specs, and WebGPU launch flags for GPU sims.
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
  setup.ts                 template-owned: Canvas/WebGPU-safe getContext, AudioContext and
                           no-op Worker mocks, init({ name })
  helpers/memoryLeak.ts    template-owned leak harness (forceGC, describeDisposalLeaks)
  memory-leak.test.ts      lists the sim's disposables (fleet pattern)
  **/*.test.ts             Vitest unit tests, mirroring the source tree under tests/
  fuzz/fuzz.spec.ts        template-owned Playwright fuzz smoke (npm run test:fuzz)
  browser/*.spec.ts        sim-specific Playwright specs (engine, focus, screenshots)
vitest.config.ts           environment: "happy-dom"; include: ["tests/**/*.test.ts"];
                           setupFiles: ["./tests/setup.ts"]; execArgv: ["--expose-gc"]
```

Tests live **only** under root `tests/`. Never co-locate them next to source or use
`__tests__/`; the compliance gate fails both. Mirror the source path: a test for
`src/optics-lab/model/Lens.ts` is `tests/optics-lab/model/Lens.test.ts`.

Every sim runs Vitest under happy-dom with the shared `tests/setup.ts`; `jsdom` is no longer
a fleet dependency. `setup.ts`, `helpers/memoryLeak.ts` and `fuzz/fuzz.spec.ts` are
template-owned. Change them in SceneryStackTemplate and sync, never per sim
(`Baton/scripts/check-template-drift.sh <Sim>` flags local edits). Biome allows `!` and
skips `useExplicitType` under `tests/**`.

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

`tests/memory-leak.test.ts` lists the sim's disposables and hands them to the shared harness.
Do not copy a private `forceGC`; the compliance gate fails a suite that bypasses
`tests/helpers/memoryLeak.ts`.

```typescript
import { NumberProperty } from "scenerystack/axon";
import { ResistorNode } from "../src/common/view/ResistorNode.js";
import { LabModel } from "../src/lab/model/LabModel.js";
import { LabPreferencesModel } from "../src/preferences/LabPreferencesModel.js";
import { describeDisposalLeaks } from "./helpers/memoryLeak.js";

// Outlives every case, like model state outlives a node.
const resistanceProperty = new NumberProperty(100);

describeDisposalLeaks([
  { name: "LabModel", create: () => new LabModel(new LabPreferencesModel()) },
  { name: "ResistorNode", create: () => new ResistorNode(resistanceProperty) },
]);
```

For each case the harness checks the instance is collected after `dispose()` and that
repeated create/dispose cycles leave no survivors.

- **List real objects.** Include every model or view class that links Properties, adds
  listeners, or owns child nodes. Pass long-lived Properties in from outside, as the screen
  would, so the test proves the object unlinks from state that outlives it.
- **`idempotentDispose` is opt-in.** axon Properties and `Disposable` throw on a second
  `dispose()` by design. Set `idempotentDispose: true` only for objects that promise it
  (the template's `TimeModel`).
- **Sim-specific leak tests** go below the `describeDisposalLeaks` call in the same file and
  use the harness's exported `forceGC(ref)`. Always pass the `WeakRef`(s). Without them
  `forceGC` runs every GC pass and can exceed Vitest's `testTimeout`. Allocate inside a
  **function** (not a block) so V8 can collect the locals.
- If the sim deleted the template's unused `TimeModel`, delete its `TimeModel` case and
  `tests/TimeModel.test.ts` too. A suite that only disposes a stand-alone `NumberProperty`
  proves the harness runs, nothing more. Record that gap.
- Dynamic sims that add/remove nodes at runtime should expand the suite like OpticsLab.

## What to test

- **Physics / math:** closed-form results, conservation laws, edge cases (zero, `Range`
  boundaries, sign flips).
- **`reset()` completeness:** after mutating state, `reset()` restores initial values.
- **Derived quantities:** `DerivedProperty` recomputes when dependencies change.
- **Rendering/layout:** use targeted browser tests when behavior depends on focus, input routing, or rendering; a build and random fuzz alone do not establish correctness.

## Regressions from functional reviews

Exercise the failing transition, not just a helper in isolation: paused Step, first recording snapshot after input edits, a final partial interval, duration shortened before backward Step, changed sample interval on resume, reset/release after sampling, or a mode switch with queued edits. Where practical, confirm the regression fails with the old behavior and passes after the fix.

Use independent expected values (analytic formulas, finite differences, reference sampling) for numerical checks. Include zero/invalid dt and exact event endpoints. For cancellation, control promises so Stop/disposal happens during both acquisition and resume; then resolve/reject the old request while a newer one is active.

Focus the actual PDOM target and press a key to prove a keyboard listener is reachable. For disposal, collect the real node/helper against still-live global/model Properties and repeat create/dispose cycles; collecting a stand-alone NumberProperty only validates the harness.

Keep validation claims proportional to evidence: mocked sensor tests do not test hardware; shader/binding checks do not establish GPU solver accuracy; short fuzz does not replace deterministic transport or keyboard regressions. Record skipped integration checks and the runtime used.

If running multiple browser suites concurrently, use distinct `FUZZ_PORT` values supported by the harness. Investigate resource-contention failures and repeat the affected suite in isolation rather than weakening timeouts or assertions without evidence.

## Playwright fuzz and browser specs

SceneryStackTemplate ships `tests/fuzz/fuzz.spec.ts` + `playwright.config.ts` +
`scripts/test-fuzz.ts` with `npm run test:fuzz` / `test:fuzz:quick` / `test:fuzz:long`.
The spec runs two modes: pointer fuzz (`?fuzz&ea`) and keyboard fuzz through the PDOM
(`?fuzzBoard&ea`). Each fails on a console error, a `pageerror`, or an assertion. Fleet
Health runs `test:fuzz:quick` for every sim, so a fuzz failure is a fleet-visible red, not
an optional extra. The Playwright config also fixes a geolocation and enables WebGPU so
sims that need either run deterministically.

`test:fuzz` runs **only** `tests/fuzz/`. Put any other browser spec (WebGPU engines,
focus routing, screenshot checks) in `tests/browser/` and run it with `npx playwright test
tests/browser`. Keep it out of the fuzz smoke so a slow engine suite cannot time out Fleet
Health.

Duration is **30 seconds** by default. Change it without editing the spec:

```bash
npm run test:fuzz                 # 30s
npm run test:fuzz:quick           # 10s
npm run test:fuzz:long            # 300s
npm run test:fuzz -- 90           # 90s
npm run test:fuzz -- --duration 90
FUZZ_DURATION=90 npm run test:fuzz
FUZZ_PORT=5181 npm run test:fuzz  # parallel runs need distinct dev-server ports
```

`scripts/test-fuzz.ts` forwards extra Playwright args (`npm run test:fuzz -- 60 --headed`).
The Playwright test timeout is `FUZZ_DURATION + 120s` so a long run is not killed by the
default 5-minute cap. Always include `&ea` in a fuzz URL; without it assertions are silent.
A CSP error in the console fails fuzz too. The template's `script-src-attr` hashes exist for
exactly that reason (see its `vite.config.ts`).

## WebGPU / GPU sims in Playwright

Headless Chromium often returns `null` from `navigator.gpu.requestAdapter()` unless
launched with WebGPU enabled. For engine / screenshot suites in `tests/browser/` (e.g. the FluidDynamics engine spec):

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
- Prefer model tests for math/state; use browser interaction tests for focus and control wiring, and targeted view lifecycle tests for external listener cleanup.
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
- A private `forceGC` copy in `memory-leak.test.ts` instead of `describeDisposalLeaks` → compliance failure.
- `idempotentDispose: true` on an axon-backed object → the second `dispose()` throws by design.
- A browser spec under `tests/fuzz/` → it runs inside every `test:fuzz` and Fleet Health smoke.
- Editing `tests/setup.ts` or `tests/helpers/memoryLeak.ts` in one sim → template drift; change the template.
- Assuming WebGPU works in Playwright without the launch flags above → adapter is `null`.

Related skills: scenerystack-model, scenerystack-code-review, scenerystack-disposal,
scenerystack-numerics.
