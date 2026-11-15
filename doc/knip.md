# Finding unused code with Knip

Every SceneryStack simulation and SceneryStackTemplate provides `npm run knip`.
Run it inside the member repo after `npm ci`, using the fleet's Node 26 runtime.
It reports unused files, exports, types, and dependencies across the project.
TypeScript and Biome remain responsible for their existing checks.

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

`knip.json` defines the project files to analyze. Built-in Vite, Vitest,
Playwright, and package-script discovery identifies application, test, config,
and script entry points. Keep application modules out of `entry` unless they
are actually loaded independently; making every source file an entry hides
unused files. Add explicit entry points for custom loaders that Knip cannot see.
DataLab and BasicCoordinatesAndSeasons list their directly invoked data generators
as entries. Astronomy sims with optional Java-based Flash decompilers list `java`
in `ignoreBinaries`, because it is a system prerequisite rather than an npm package.
RadioactivityAndStatistics lists the standalone USB probe server and browser script
as entries. TrackLab retains `@techstark/opencv-js` in `ignoreDependencies`: its Vite
plugin serves/copies the file from `node_modules` by path instead of importing it.

Review findings before deleting code or dependencies. Runtime lookups, shell
commands, generated assets, and optional template toolkit files can require
context. For example, a new template can report unused `SimPanel.ts`,
`SimControlOptions.ts`, and `PANEL_CORNER_RADIUS` until those tools are used.
An unused export may only need its `export` keyword removed. Intentional shared
toolkit exports can use the existing `@public` annotations. Avoid blanket ignores
or automatic `--fix` cleanup across the fleet.

The template owns the base configuration and dependency/script versions.
`config/template-manifest.json` allows sims to extend project/entry patterns and
specific ignores for documented local needs. Update the template first when
changing the shared configuration, then propagate it to the simulations.

After a reviewed cleanup, run the sim's lint, type checks, tests, and build.
Consider mandatory CI enforcement only after the existing findings have been
reviewed and each simulation has an agreed clean baseline.

Reference: [Knip documentation](https://knip.dev/overview/getting-started).
