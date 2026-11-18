---
name: scenerystack-testing
description: Use when adding unit, memory-leak, fuzz, or browser tests — tests/ layout (CONVENTIONS §5), describeDisposalLeaks, test:fuzz vs tests/browser, test:soak. WebGPU Playwright flags: scenerystack-webgpu.
---

# SceneryStack Testing

**Layout authority:** [CONVENTIONS.md](../../CONVENTIONS.md) §5. This skill is harness
idioms, what to test, and common mistakes — not a second copy of the folder gate.

Every OpenLyceum SceneryStack sim ships Vitest unit tests under root `tests/` and a
`test` script in `package.json`. CI runs `npm test` when that script is present. Prefer
testing the **model** (pure logic, physics, math) — not Scenery rendering.

`tests/fuzz/` → `npm run test:fuzz` (Fleet Health smoke). `tests/browser/` → sim-specific
Playwright (engines, focus, screenshots) plus template `test:soak`. Do not put browser
specs under `fuzz/`.

Algorithm-heavy sims carry denser suites; PhET ports often start with smoke + reset and
grow. SceneryStackTemplate is the layout reference.

## The standardized layout

```
tests/
  setup.ts                 template-owned: Canvas/WebGPU-safe getContext, AudioContext and
                           no-op Worker mocks, init({ name })
  helpers/memoryLeak.ts    template-owned leak harness (forceGC, keepAlive,
                           expectNoListenerGrowth, describeDisposalLeaks)
  memory-leak.test.ts      lists the sim's disposables (fleet pattern)
  **/*.test.ts             Vitest unit tests, mirroring the source tree under tests/
  fuzz/fuzz.spec.ts        template-owned Playwright fuzz smoke (npm run test:fuzz)
  browser/memory-soak.spec.ts  template-owned Reset-All heap soak (npm run test:soak)
  browser/*.spec.ts        sim-specific Playwright specs (engine, focus, screenshots)
vitest.config.ts           template-owned: environment: "happy-dom"; include: ["tests/**/*.test.ts"];
                           setupFiles: ["./tests/setup.ts"]; execArgv: ["--expose-gc"]; drift guards
```

**Drift guards** (template-owned, fleet-wide):

- `expect.requireAssertions`: a test with no `expect()` fails. A check that only calls
  `expect.fail` inside an `if` asserts nothing when it passes. Assert the result instead,
  e.g. `expect(leakedKeys, "not collected").toEqual([])`.
- `sequence.shuffle` (files and tests): order-dependent tests surface. Seed shared randomness
  (`dotRandom.setSeed(1)` in `beforeEach`) rather than relying on run order. Reproduce an order
  with `npx vitest run --sequence.seed=<seed>`.
- `restoreMocks` / `unstubGlobals` / `unstubEnvs`: spies and stubs end with their test.
- `retry: 0`: fix flaky tests; never add retries.
- `tests/setup.ts` fails a test that writes `console.error` / `console.warn`. When the warning
  is the behaviour under test, spy and assert it:
  `const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);` then
  `expect(warn).toHaveBeenCalledWith(...)`. (`() => {}` fails Biome's empty-block rule.)

Tests live **only** under root `tests/`. Never co-locate them next to source or use
`__tests__/`; the compliance gate fails both. Mirror the source path: a test for
`src/optics-lab/model/Lens.ts` is `tests/optics-lab/model/Lens.test.ts`.

Every sim runs Vitest under happy-dom with the shared `tests/setup.ts`; `jsdom` is no longer
a fleet dependency. `setup.ts`, `helpers/memoryLeak.ts` and `fuzz/fuzz.spec.ts` are
template-owned. Change them in SceneryStackTemplate and sync, never per sim
(`Baton/scripts/check-template-drift.sh <Sim>` flags local edits). Biome allows `!` and
skips `useExplicitType` under `tests/**`.

## A model unit test

Test physics or geometry directly with an independent expected value. This example adapts
the arc geometry test in OpticsLab's `tests/common/model/optics/curved-geometry.test.ts`:

```typescript
import { describe, expect, it } from "vitest";
import { ArcMirror } from "../../../../src/common/model/mirrors/ArcMirror.js";
import { point } from "../../../../src/common/model/optics/Geometry.js";

describe("ArcMirror arc geometry", () => {
  it.each([-1, 1])("preserves curvature side %i when changing radius", (side) => {
    const element = new ArcMirror(point(-1, 0), point(1, 0), point(0, side));
    element.setRadius(2);
    expect(element.p3.x).toBe(0);
    expect(element.p3.y).toBeCloseTo(side * (2 - Math.sqrt(3)), 12);
    expect(element.getRadius()).toBeCloseTo(2, 12);
    element.dispose();
  });
});
```

## Memory-leak suite

`tests/memory-leak.test.ts` lists the sim's disposables and hands them to the shared harness.
Do not copy a private `forceGC`; the compliance gate fails a suite that bypasses
`tests/helpers/memoryLeak.ts`. Hollow suites also fail: `describeDisposalLeaks([])`
without `{ emptyOk }` + custom coverage, or a TimeModel/NumberProperty-only list with no
other `forceGC` / `expectNoListenerGrowth` tests. Missing disposal inventory entries produce
a warning. Cover classes that define `dispose()` (in their own body, or inherited from a
same-sim parent) in the suite file or document an exception as `` `memory-leak:<Class>` ``
under `## Compliance carve-outs`. The inventory check skips `*ScreenView`, `*Screen`, and
`*Sim` classes, and warns on carve-outs it no longer needs.

"Cover" means the suite uses the class: a value import, `new Foo()`, passing `Foo` to a
helper, or a `name: "Foo …"` case. A name that only appears in an import path, a string or
a prose comment does not count, and `import type` alone does not count. An abstract base is
covered by a covered subclass. Factory probes that never name the class declare it:

```typescript
// memory-leak-covers-subclasses: BaseElement (every element via createDefaultElement(ALL_KEYS))
// memory-leak-covers: DetectorChartPanel (owned by DetectorView), RayPropagationView
```

```typescript
import { NumberProperty } from "scenerystack/axon";
import { ResistorNode } from "../src/common/view/ResistorNode.js";
import { LabModel } from "../src/lab/model/LabModel.js";
import { LabPreferencesModel } from "../src/preferences/LabPreferencesModel.js";
import { describeDisposalLeaks, expectNoListenerGrowth } from "./helpers/memoryLeak.js";

// Outlives every case, like model state outlives a node.
const resistanceProperty = new NumberProperty(100);

describeDisposalLeaks([
  { name: "LabModel", create: () => new LabModel(new LabPreferencesModel()) },
  {
    name: "ResistorNode",
    create: () => new ResistorNode(resistanceProperty),
    keepAlive: () => [resistanceProperty],
  },
]);

// Non-disposable owners: assert listener counts stay flat across exercise/reset.
```

For each case the harness checks the instance is collected after `dispose()` and that
repeated create/dispose cycles leave no survivors. With `keepAlive`, sentinels stay
strongly referenced through the WeakRef check so a forgotten unlink fails.

- **List real objects.** Include every model or view class that defines `dispose()`, links
  Properties, adds listeners, or owns child nodes. Prefer `keepAlive` for external
  Properties the node linked to.
- **`idempotentDispose` is opt-in.** axon Properties and `Disposable` throw on a second
  `dispose()` by design. Set `idempotentDispose: true` only for objects that promise it
  (the template's `TimeModel`).
- **Empty lists:** `describeDisposalLeaks([], { emptyOk: "…" })` plus custom
  `forceGC` / `expectNoListenerGrowth` coverage in the same file. Empty-without-`emptyOk`
  fails the suite and compliance.
- **Sim-specific leak tests** go below the `describeDisposalLeaks` call and use
  `forceGC(ref)` / `expectNoListenerGrowth(properties, exercise)`. Always pass WeakRefs
  to `forceGC`. Allocate inside a **function** (not a block) so V8 can collect the locals.
- If the sim deleted the template's unused `TimeModel`, delete its `TimeModel` case and
  `tests/TimeModel.test.ts` too. A suite that only disposes a stand-alone `NumberProperty`
  proves the harness runs, nothing more — compliance fails that as hollow.
- Dynamic sims that add/remove nodes at runtime should expand the suite like OpticsLab.
- **Browser soak:** `npm run test:soak` (template-owned `tests/browser/memory-soak.spec.ts`).
  Keep it out of Fleet Health fuzz; use it in CRC / nightly.

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

Launch flags, no-adapter paths, and GPU carve-outs: **scenerystack-webgpu**. Keep GPU
engine suites out of default `npm test`; document skip conditions in the sim's `AGENTS.md`.

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
- Assuming WebGPU works in Playwright without scenerystack-webgpu launch flags → adapter is `null`.
- A diagnostic `console.warn` that fires on normal input (e.g. "found fewer states than requested" when the request is only a ceiling) → every test touching it fails the console guard; fix the condition, don't silence it.

Related skills: scenerystack-model, scenerystack-code-review, scenerystack-disposal,
scenerystack-numerics, scenerystack-webgpu, scenerystack-axon.
