# Architecture checks with dependency-cruiser

Every SceneryStack simulation and SceneryStackTemplate provides
`npm run check:architecture` (`depcruise src`). Run it inside the member repo after
`npm ci`, using the fleet's Node 26 runtime.

It validates import boundaries that Biome and TypeScript do not enforce:

| Rule | Severity | Meaning |
|---|---|---|
| `no-circular` | error | Circular dependencies are prohibited |
| `no-model-to-view` | error | Code under `model/` must not import `view/` |
| `no-common-to-screen` | error | `src/common/` must not import screen packages |
| `no-preferences-to-screen` | error | `src/preferences/` must not import screen packages |
| `no-i18n-to-screen` | error | `src/i18n/` must not import screen packages |
| `no-assets-to-app` | error | `src/assets/` must not import application modules |
| `no-cross-screen` | error | Screen packages must not import other screen packages (share via `common/`) |
| `no-model-to-preferences-view` | error | `model/` may use `*PreferencesModel`, not `*PreferencesNode` |
| `no-src-to-tests` | error | `src/` must not import `tests/` |
| `not-to-dev-dep` | error | `src/` must not value-import npm `devDependencies` |
| `no-model-to-ui-packages` | warn | `model/` must not value-import `scenerystack/scenery` or `scenerystack/sun` (type-only allowed; `scenery-phet` units/`TimeSpeed` OK) |
| `no-orphans` | warn | Modules under `src/` with no incoming or outgoing dependencies |

Shared roots treated as non-screens: `common`, `preferences`, `i18n`, `assets`.

dependency-cruiser is a **manual check** during adoption. A finding produces a nonzero
exit status, but the command is not part of shared CI, release scripts, or git hooks.
Review reports before rearranging modules. Warnings (`no-model-to-ui-packages`,
`no-orphans`) also fail the command while severity stays advisory in spirit — fix or
document before treating a sim as clean.

```bash
npm run check:architecture
npm run check:architecture -- -T dot > /tmp/deps.dot   # graphviz
npm run check:architecture -- -T mermaid               # mermaid text
```

## TypeScript 7 and SWC

The fleet uses TypeScript 7. dependency-cruiser's TypeScript compiler bridge still
targets `<7`, so the shared config sets `parser: "swc"` and depends on `@swc/core`.
`tsPreCompilationDeps` stays off for that reason.

If SWC/dependency-cruiser cannot walk a rare syntax construct, exclude that file in a
sim-local overlay rather than weakening the fleet rules.

## Local overlays

The template owns `.dependency-cruiser.cjs` (exact match in
`config/template-manifest.json`). A sim may commit `.dependency-cruiser.local.cjs`:

```js
/** @type {import("dependency-cruiser").IConfiguration} */
module.exports = {
  options: {
    // Example: skip a file the walker cannot parse yet
    exclude: { path: "^src/webcam\\.ts$" },
  },
};
```

Document the overlay under the sim's `## Compliance carve-outs` when it changes
template-owned behavior in a lasting way. Prefer fixing structure over permanent
excludes.

## Related

- Unused files/exports: [`doc/knip.md`](knip.md) (`npm run check:unused`)
- Model/view conventions: [CONVENTIONS.md](../CONVENTIONS.md), `.github/AGENTS.md`

Reference: [dependency-cruiser documentation](https://github.com/sverweij/dependency-cruiser).
