# Architecture checks with dependency-cruiser

Every SceneryStack simulation and SceneryStackTemplate provides
`npm run check:architecture` (`depcruise src`). Run it inside the member repo after
`npm ci`, using the fleet's Node 26 runtime.

It validates import boundaries that Biome and TypeScript do not enforce:

| Rule | Severity | Meaning |
|---|---|---|
| `no-unresolved` | error | Imports must resolve; catches invented packages and stale file paths |
| `no-undeclared-packages` | error | Runtime packages must be direct dependencies, not accidental transitive installs |
| `no-duplicate-dep-types` | error | Imported packages must not appear in multiple dependency categories |
| `not-to-deprecated` | warn | Installed package metadata must not mark imports deprecated |
| `no-node-builtins` | error | Browser code must not value-import Node built-ins |
| `no-src-to-tooling` | error | App code must not import scripts, configs or sibling checkouts (`package.json` metadata and static images in root `assets/` are allowed) |
| `no-app-to-bootstrap` | error | Only bootstrap modules may import the bootstrap chain |
| `no-model-to-view-transitive` | error | Model code must not reach views or preferences nodes through helpers or barrels |
| `no-circular` | error | Runtime circular dependencies are prohibited |
| `no-model-to-view` | error | Code under `model/` must not import `view/` |
| `no-common-to-screen` | error | `src/common/` must not import screen packages |
| `no-preferences-to-screen` | error | `src/preferences/` must not import screen packages |
| `no-i18n-to-screen` | error | `src/i18n/` must not import screen packages |
| `no-assets-to-app` | error | `src/assets/` must not import application modules |
| `no-cross-screen` | error | Screen packages must not import other screen packages (share via `common/`) |
| `no-model-to-preferences-view` | error | `model/` may use `*PreferencesModel`, not `*PreferencesNode` |
| `no-src-to-tests` | error | `src/` must not import `tests/` |
| `not-to-dev-dep` | error | `src/` must not value-import npm `devDependencies` |
| `no-model-to-ui-packages` | error | `model/` must not value-import `scenerystack/scenery` or `scenerystack/sun` (type-only allowed; `scenery-phet` units/`TimeSpeed` OK) |
| `no-model-to-colors` | error | Models must not value-import `*Colors.ts`; views map domain state to colors |
| `no-unreachable-from-entry` | error | Every source module must be reachable from `src/main.ts` (ambient declarations excepted) |
| `no-orphans` | error | Modules under `src/` with no incoming or outgoing dependencies |

Shared roots treated as non-screens: `common`, `preferences`, `i18n`, `assets`.

Resolution targets browser packages: import/browser/module conditions, browser aliases,
and browser/module/main entry fields (with type metadata fallbacks). Node-specific
conditional exports are not selected for browser application code.

Reachability includes literal dynamic imports and type-only edges. Entry modules are
exempt from their own reachability check, as are ambient `.d.ts`, `.d.cts` and `.d.mts`
declarations. Only the template package additionally treats `src/common/SimControlOptions.ts`,
`SimPanel.ts` and `TimeModel.ts` as public starter entry points. Forks must use or remove
unused starter components; this exception does not propagate to renamed sims. Keep
reference implementations used only by tests under `tests/`, outside application source.
Computed dynamic imports still need explicit review; the parser cannot infer every target.

The deprecation warning uses installed package metadata, not a live npm registry lookup.

SceneryStack sims and the template enforce architecture checks in **pre-push**,
**release**, and **CI**. Each sim's reusable Baton CI caller sets
`run-architecture: true`. The reusable input defaults to false for other callers
and repos that have not yet adopted this infrastructure.

For a new sim or older checkout, adopt the template config, hook, regression fixtures,
package scripts and CI caller together. Deploy the reusable Baton workflow before
merging callers that use the new input. Keep these files synchronized through
`config/template-manifest.json`; review fixes from `check-template-drift.sh --fix <Sim>`.

`npm run test:architecture` runs CLI regression fixtures for forbidden imports, legitimate
imports, and overlay failures. CI runs these before checking the application graph.
The default error reporter fails on errors (including orphans). JSON and graph
reporters are for inspection and do not provide the same failing exit status.
Keep the default reporter in enforcement commands.

```bash
npm run check:architecture
npm run test:architecture
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

Overlays fail closed: syntax errors, missing dependencies inside the overlay, invalid
shapes, unknown keys and duplicate rule names stop the check. Only `options.exclude`
may be customized; parser, resolver and graph traversal options stay fleet-owned.
Exclusions must be nonempty regexes that do not match the empty string.

Every exclusion needs a bullet under `AGENTS.md` → `## Compliance carve-outs`:

```markdown
- `.dependency-cruiser.local.cjs`: excludes a specific file until the parser supports it.
```

`forbidden` may add uniquely named rules. `omitRules` may remove a known fleet rule
only when that exact rule name has its own carve-out bullet with a reason, for example:

```markdown
- `no-cross-screen`: pedagogy screen temporarily composes another screen's model; extract a shared API in `common/` before dropping this.
```

Prefer extracting shared interfaces over omitting a boundary rule. These checks make
exceptions explicit and reviewable; they are not a security boundary against editing
configuration or inventing a carve-out. No sim currently omits a fleet rule.

## What this prevents

The rules catch dependency drift: models acquiring view dependencies, screen coupling,
tooling leaking into browser code, and imports of nonexistent or undeclared packages.
They cannot assess physics correctness, duplicated algorithms, hardcoded text or colors,
bootstrap import order, or computed dynamic imports that the parser cannot resolve.
Keep TypeScript, Biome, compliance checks and domain tests alongside this check.

## Related

- Unused files/exports: [`doc/knip.md`](knip.md) (`npm run check:unused`)
- Model/view conventions: [CONVENTIONS.md](../CONVENTIONS.md), `.github/AGENTS.md`

Reference: [dependency-cruiser documentation](https://github.com/sverweij/dependency-cruiser).
