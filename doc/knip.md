# Finding unused code with Knip

Every SceneryStack simulation and SceneryStackTemplate provides `npm run check:unused`
(alias: `npm run knip`).
Run it inside the member repo after `npm ci`, using the fleet's Node 26 runtime.
It reports unused files, exports, types, dependencies, and circular dependencies across
the project. TypeScript and Biome remain responsible for their existing checks.

Knip is a **manual check** during adoption. A finding produces a nonzero exit
status, but the command is not part of shared CI, release scripts, or git hooks.
Existing findings can therefore be reviewed without blocking unrelated changes.

```bash
npm run knip
npm run knip -- --production
npm run knip -- --reporter json
```

The default run includes tests and tooling. Production mode helps identify code
that is reachable only through tests. Neither mode proves that every remaining
function or branch is necessary.

## Shared configuration

`knip.json` defines the project files to analyze. Built-in Vite, Vitest,
Playwright, and package-script discovery identifies application, test, config,
and script entry points. Keep application modules out of `entry` unless they
are actually loaded independently; making every source file an entry hides
unused files. Add explicit entry points for custom loaders that Knip cannot see.

The shared config also turns on stricter coverage for these self-contained apps:

- `includeEntryExports: true` — report unused exports (and enum/namespace members)
  in entry files, not only in reachable non-entry modules.
- `include` lists the default issue types **plus** `cycles`, so circular dependencies
  appear alongside unused files/exports/dependencies (complementing
  [`dependency-cruiser.md`](dependency-cruiser.md)).
- `rules.cycles: "error"` — cycles count toward the exit status (Knip’s default for
  cycles is warn-only once enabled).
- `treatConfigHintsAsErrors: true` — configuration hints fail the run instead of
  drifting silently.

## Documented ignores (do not grow casually)

Only add `ignoreDependencies`, `ignoreBinaries`, `ignoreUnresolved`, or
`ignoreFiles` entries with a reason that belongs in this doc (or the sim’s
`## Compliance carve-outs` section). Prefer fixing entry/project patterns or
wiring the reference over silencing findings.

Shared:

- `@swc/core` in `ignoreDependencies`: dependency-cruiser loads it via
  `parser: "swc"` (see [`dependency-cruiser.md`](dependency-cruiser.md)), which Knip
  does not see as an import.
- `./.dependency-cruiser.local.cjs` in `ignoreUnresolved`: the shared
  `.dependency-cruiser.cjs` optionally `require.resolve`s this overlay; the file is
  absent until a sim needs a local carve-out.

Sim carve-outs (allowed via `config/template-manifest.json` extend keys):

- DataLab and BasicCoordinatesAndSeasons list their directly invoked data generators
  as `entry`.
- Astronomy sims with optional Java-based Flash decompilers list `java` in
  `ignoreBinaries` (system prerequisite, not an npm package).
- RadioactivityAndStatistics lists the standalone USB probe server and browser script
  as `entry`.
- TrackLab retains `@techstark/opencv-js` in `ignoreDependencies`: its Vite plugin
  serves/copies the file from `node_modules` by path instead of importing it.

## `@public` vs delete `export` vs `@internal`

Review findings before deleting code or dependencies. Runtime lookups, shell
commands, generated assets, and optional template toolkit files can require
context. For example, a new template can report unused `SimPanel.ts`,
`SimControlOptions.ts`, and `PANEL_CORNER_RADIUS` until those tools are used.

When Knip reports an unused export, choose deliberately:

| Situation | Action |
| --- | --- |
| Nothing should import it (app-local dead export) | Remove the `export` keyword (or delete the symbol). |
| Intentional shared toolkit API that some forks skip | Keep the export and tag it `/** @public */` so Knip leaves it alone. |
| Export exists only so tests can reach it | Tag `/** @internal */`. Production mode ignores `@internal`; prefer this over growing `ignore*` lists. Do not use `@public` for test-only seams. |

Do **not** add `"tags": ["-public"]` in `knip.json` — that would hide toolkit APIs from
the report entirely. Tag individual exports instead.

Avoid blanket ignores or automatic `--fix` cleanup across the fleet.

Keep the preferences trio wired even when empty: `src/preferences/` is required by
compliance (`<Prefix>PreferencesModel`, at least one `*PreferencesNode`, and
`<prefix>QueryParameters`). Empty stubs that nothing imports look unused to Knip,
but deleting them fails compliance. Wire Model/Node from `main.ts` via
`simulationOptions.customPreferences`, and have the Model import the query-parameters
module (side-effect import is enough while it has no parameters) so Knip keeps the
file.

## Propagation

The template owns the base configuration and dependency/script versions.
`config/template-manifest.json` allows sims to extend project/entry patterns and
specific ignores for documented local needs. Update the template first when
changing the shared configuration, then propagate it to the simulations.

After a reviewed cleanup, run the sim's lint, type checks, tests, and build.
Consider mandatory CI enforcement only after the existing findings have been
reviewed and each simulation has an agreed clean baseline.

Reference: [Knip documentation](https://knip.dev/overview/getting-started).
