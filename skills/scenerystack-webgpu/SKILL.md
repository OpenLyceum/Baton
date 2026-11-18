---
name: scenerystack-webgpu
description: Use when a sim runs physics or dense fields on the GPU — WebGPU compute (WGSL), WebGL particle renderers, no-adapter UX, or `src/common/gpu/` layout. Covers CPU parameter models vs GPU solvers, bridge nodes, Playwright launch flags, and Canvas/WebGL fallbacks.
---

# SceneryStack WebGPU / GPU fields

Some sims keep parameters on the CPU but run the field solver only on the GPU (WebGPU
compute or WebGL). Fleet references: **FluidDynamics** (`src/common/gpu/`, Stable Fluids
WGSL), **HeatTransfer** (`src/common/field/gpu/`), **Resonance** (WebGL particles).

Structural layout authority for folders and compliance is
[CONVENTIONS.md](../../CONVENTIONS.md); this skill is the GPU carve-out and bridge idiom.

## CPU parameters vs GPU solver

- Keep **parameters** and derived scalars (Reynolds number, regime, …) in a normal
  `*Model` under `model/` — no scenery, no GPU imports, unit-tested.
- Put the solver under `src/common/gpu/` (or a documented peer such as
  `src/common/field/gpu/`) — WGSL, bind layouts, engine — **not** under `model/`.
- One bridge node (e.g. `FluidFieldNode`, `FieldNode`) may touch both worlds.
- Document the carve-out in the sim's `AGENTS.md` so reviewers do not "fix" GPU code
  back into `model/`.

## No-adapter / unavailable GPU

Where WebGPU (or WebGL) is unavailable, show a deliberate message or degraded UI —
do not leave a blank play area. FluidDynamics replaces the field with an explanation;
match that bar for new GPU sims.

## Choosing CanvasNode vs WebGL vs WebGPU

Prefer, in order (also summarized in scenerystack-custom-drawing):

1. **`CanvasNode`** — field still cheap enough for testable TypeScript.
2. **WebGL** — many sprites/particles a CPU buffer cannot keep up with.
3. **WebGPU compute** — the field *is* GPU state; nothing advances without a device.

## Playwright

Headless Chromium often returns `null` from `navigator.gpu.requestAdapter()` unless
launched with WebGPU enabled. In `tests/browser/` engine/screenshot suites:

```ts
args: ["--enable-unsafe-webgpu", "--enable-features=Vulkan"],
```

To exercise a no-WebGPU path deliberately:

```ts
args: ["--disable-features=WebGPU,WebGPUService"],
```

Absence of `vulkaninfo` on the host is not evidence that WebGPU is unavailable in
Chromium. Vitest cannot drive WebGPU — cover the CPU parameter model there; put
adapter/engine checks in Playwright. Details also live in scenerystack-testing.

## Rules

- Parameters stay in `model/`; WGSL/engine stay under a documented `gpu/` carve-out.
- Document the carve-out in `AGENTS.md`; compliance will not invent it for you.
- Ship a no-adapter path (message or degraded UI), never a silent blank field.
- Prefer `CanvasNode` until profiling or GPU-only state forces WebGL/WebGPU.
- Wire Playwright with the WebGPU launch flags above for engine specs.

## Common mistakes

- Stuffing WGSL into `model/` "because physics" → fight the architecture; use `gpu/`.
- Inventing a fake CPU twin of every texture just to satisfy folder layout.
- Assuming WebGPU works in Playwright without launch flags → adapter is `null`.
- Opening a bare `<canvas>` outside scenery instead of a bridge `Node` / `CanvasNode`.

Related skills: scenerystack-model, scenerystack-custom-drawing, scenerystack-testing,
scenerystack-numerics.
