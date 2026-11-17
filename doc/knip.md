# Finding unused code with Knip

Every SceneryStack simulation and SceneryStackTemplate provides `npm run check:unused`
(alias: `npm run knip`).
Run it inside the member repo after `npm ci`, using the fleet's Node 26 runtime.
It reports unused files, exports, types, dependencies, and circular dependencies across
the project. TypeScript and Biome remain responsible for their existing checks.

Knip runs in a separate CI job with `unused-mode: required` for every SceneryStack
simulation and SceneryStackTemplate (see [`knip-reviewed-baselines.md`](knip-reviewed-baselines.md)).
Both default and production reports, stderr, and exit codes are uploaded as the
`knip-reports` artifact. The reusable workflow still accepts `advisory` for exceptional
carve-outs, but none are in use. Knip is not part of release scripts or git hooks.

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

The application project pattern is `src/**/*.ts!`: the trailing `!` includes
source files in production mode as well as the default run. Tests, scripts, and
root configuration patterns stay unmarked. The Vite plugin discovers `src/main.ts`
through `index.html` in both modes, so no redundant explicit application entry is
needed. When adding a custom independently loaded runtime entry, mark that entry
and its production project patterns with `!` too. Tooling entries stay unmarked.
Check `npm run knip -- --production --debug` after changing entry discovery.

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
- `vite!` in `ignoreBinaries`: production-only exception for `start: vite`.
  These applications deploy static build output, but Knip treats the `start`
  script as production while excluding devDependencies (where Vite belongs).
  Normal mode still checks Vite's dependency/binary declaration. Keep Vite in
  devDependencies; do not ignore it in both modes or move build tooling into
  runtime dependencies merely to satisfy production analysis.

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
context. The template's `SimPanel.ts`, `SimControlOptions.ts`, and `TimeModel.ts`
are documented starter toolkit entries; its panel constant is an intentional
public toolkit export. Forks must use or remove unused starters instead of
inheriting template-only entry exemptions.

When Knip reports an unused export, choose deliberately:

| Situation | Action |
| --- | --- |
| Nothing should import it (app-local dead export) | Remove the `export` keyword (or delete the symbol). |
| Intentional shared toolkit API that some forks skip | Keep the export and tag it `/** @public */` so Knip leaves it alone. |
| Deliberate export exists only so tests can reach an implementation helper | Explain the testing need and tag `/** @internal */`. Production mode ignores that export; do not use `@public` for test-only seams. |

Review production findings **before** adding `@internal`. Broadly tagging everything
used only by tests would conceal the dead production API this mode is meant to find.
Prefer tests through an existing application API when direct helper access adds no
useful coverage. Do not retain an entire unused implementation merely because tests
exercise it. Side-effect modules with no consumers of their exported value should
keep the side-effect import and remove the unnecessary export.

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
`templateOnly.jsonArrayValues` in the manifest keeps the template's three starter
entry patterns out of that required base. The drift checker accepts those entries
in the template, rejects inheriting them verbatim in a sim, and still requires
production source coverage and all other shared configuration.

## Inventory and CI rollout

From Baton, with Node 26 on PATH and dependencies already installed in member repos:

```bash
python3 scripts/inventory-knip.py --output /tmp/knip-inventory-$(date +%Y%m%d-%H%M%S)
# A single repo, or a different workspace/runtime:
python3 scripts/inventory-knip.py --only ACPhasor --workspace .. \
  --node /path/to/node26 --output /tmp/knip-acphasor
```

The inventory reads the catalog (simulations plus template), uses at most three
concurrent processes by default (`--jobs`), and never installs, fixes, commits, or
pushes. It preserves each mode's raw JSON and stderr, exit codes, Knip version,
config/lock hashes, checkout HEAD and dirty state, plus `summary.json`. Use a new
output directory each time. Findings are data; missing tools, malformed output,
timeouts, and execution failures produce inventory exit code 2. Config hints can
fail a run even when its JSON issue list is empty; inspect stderr and exit codes.
Warning-only issues also prevent classification as a clean baseline.

`fleet-exec.sh` is for proposing changes in temporary clones, not a local findings
inventory. Its dry-run executes the command but only previews the commit/push/PR
stage. Use the inventory script to retain reports from installed local checkouts.

The reusable CI input `unused-mode` accepts `off` (default for other callers),
`advisory`, or `required`. Every SceneryStack simulation and SceneryStackTemplate
already uses `required`. The job runs separately from the existing build job.
New sims should ship with `unused-mode: required` after both Knip modes, lint, type
checks, tests, architecture checks, and build are green. A temporary `advisory`
caller must document remaining adoption work under AGENTS compliance carve-outs.
Required mode fails CI if either run fails; repository branch protection must
require the job if merge enforcement is desired. Do not promote a sim merely because
its normal-mode report is empty.

The initial rollout and reviewed pilot are recorded in
[`knip-rollout.md`](knip-rollout.md); current validation and promotion decisions are in
[`knip-reviewed-baselines.md`](knip-reviewed-baselines.md). Keep both modes active after promotion.

Reference: [Knip documentation](https://knip.dev/overview/getting-started).
