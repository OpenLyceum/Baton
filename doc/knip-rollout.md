# Knip rollout — 2026-11-15

The local catalog contains **74 simulations plus SceneryStackTemplate**. All 75
installed checkouts were analyzed with Node 26 and Knip 6.45.1 after propagating
`src/**/*.ts!` and the documented production-only `vite!` exception. Local
project entries and Java/OpenCV carve-outs were retained.

**10 checkouts are clean in both modes; 65 have findings; none failed to execute.**
Normal mode found 9 unused exports and 2 unused files. Production mode found
401 unused exports, 21 unused types, and 3 unused files. There were no reported
cycles, unresolved references, unlisted binaries, or unused dependencies in either
mode. These are findings to review, not declarations that every symbol is safe to
delete. No fleet-wide auto-fix or blanket tag changes were applied.

The machine-readable snapshot is [knip-inventory-2026-11-15.json](knip-inventory-2026-11-15.json).
It records exit codes, issue counts, HEAD, local dirty state, and config/lock hashes.
Reproduce the raw per-repo JSON and stderr with the inventory command in
[knip.md](knip.md#inventory-and-ci-rollout). This snapshot is an inventory, never
an allowlist that suppresses new or existing findings.

## Reviewed required pilot: ACPhasor

- Vite discovers `src/main.ts` in both modes; production includes the application
  source and excludes test/tooling project patterns. No explicit application entry
  was added.
- A temporary export in a reachable source module consumed only by a test was
  absent from normal findings and present in production findings. Adding `@internal`
  suppressed that deliberate test seam. The fixture was removed after validation.
- Removed the unused query-parameter default export; retained its side-effect import
  and registration. Kept `resonantAngularFrequency` exported for direct mathematical
  unit tests, with an explanatory `@internal` tag; runtime callers use
  `resonantFrequency`. No implementation code was deleted.
- Both Knip runs exit 0 with empty issue lists. Lint, app/scripts/tests type checks,
  architecture checks, production build, and all 179 tests pass.
- Its CI caller uses `unused-mode: required`, documented in AGENTS carve-outs.
  All other sims and the template use `advisory`. Remote execution begins after
  publishing Baton's reusable workflow, then the caller changes. Requiring the
  resulting job in branch protection is a separate repository setting.

Other clean candidates (not yet promoted): DopplerEffect, ElectricFieldOfDreams,
LunarLander, MazeGame, OpticsLab, OscillationsAndChaos, QubitSketch, RadioWaves,
and TrackLab. Review their intentional APIs and run their full validation before
promotion. The template's optional starter modules remain advisory findings.

## Rollout validation

- The inventory runner's seven regression tests cover empty/malformed output,
  warning-only findings, configuration-hint exit codes, timeouts, and preservation
  of partial output and diagnostics. Baton's self-check runs these tests.
- CI report collection was exercised with clean reports, a failing default run,
  and invalid JSON with a zero command exit. Both modes are collected in every
  case; malformed output fails validation without overwriting the command's exit code.
- The template passed lint, type checks, production build, and all 13 tests.
  Its generator tests needed an unsandboxed rerun to execute child processes.
- Production patterns and CI rollout inputs were verified in all 75 checkouts.
  The template-drift checker reports no drift for `knip.json` or the CI callers;
  it still reports existing Biome config/version and dependency order/version
  differences elsewhere. Those were not changed by this rollout.
- ACPhasor's compliance audit passed with warnings about unavailable remote
  GitHub security queries. No hosted CI runs or branch-protection changes were made.

## Per-repository findings

| Repository | Default | Production |
| --- | --- | --- |
| ACPhasor | clean | clean |
| BackwardAcceleration | clean | 1 exports |
| BasicCoordinatesAndSeasons | clean | 9 exports, 3 types |
| BiomechanicsArm | clean | 3 exports |
| CalorimetryLab | clean | 5 exports, 2 types |
| CapacitorLab | 1 exports | 1 exports |
| CarnotHeatEngine | clean | 4 exports |
| CartCollisions | clean | 4 exports |
| ColliderLab | clean | 6 exports |
| CrystalLattice | clean | 31 exports, 2 types |
| DataLab | clean | 1 exports |
| DiffractionLab | clean | 7 exports |
| DopplerEffect | clean | clean |
| ElectricFieldMapper | clean | 4 exports |
| ElectricFieldOfDreams | clean | clean |
| Electrochemistry | clean | 4 exports |
| ElectronConfiguration | clean | 3 exports |
| EquilibriumLab | clean | 2 exports |
| ExoplanetsDatabase | clean | 2 exports |
| ExtrasolarPlanets | 1 exports | 15 exports, 1 types |
| FieldBoundary | 1 exports | 10 exports |
| FluidDynamics | 1 exports | 8 exports |
| FluidPressureAndFlow | clean | 6 exports |
| HRDiagram | clean | 3 exports |
| HabitabilityLab | clean | 6 exports |
| HabitableZones | 1 exports | 1 exports |
| HeatTransfer | clean | 5 exports, 1 types |
| InterferometryLab | clean | 8 exports |
| LadyBug | clean | 1 exports |
| Lasers | 1 exports | 1 exports |
| LewisStructures | clean | 2 exports, 1 types |
| LightAndAtoms | clean | 6 exports |
| LightPropagation | clean | 4 exports, 1 types |
| LunarLander | clean | clean |
| MazeGame | clean | clean |
| MercuryElongations | clean | 2 exports |
| MolScope | clean | 3 exports |
| MotionMatch | clean | 3 exports |
| MotionSensor | clean | 6 exports |
| MotionsOfTheSun | clean | 8 exports, 2 types |
| MovingMan | clean | 2 exports |
| NuclideChart | clean | 12 exports, 2 types |
| OpticsLab | clean | clean |
| OscillationsAndChaos | clean | clean |
| Oscilloscope | clean | 2 exports |
| ParticleZoo | clean | 6 exports |
| PeriodicTrends | clean | 1 exports |
| PhotonInteractions | clean | 10 exports |
| PlanetaryConfigurations | clean | 2 exports |
| PlateTectonics | clean | 29 exports, 1 types |
| Precession | 1 exports | 7 exports |
| QuantumAtom3D | clean | 10 exports, 1 types |
| QuantumPotential | clean | 11 exports |
| QubitSketch | clean | clean |
| RadioWaves | clean | clean |
| RadioactivityAndStatistics | clean | 10 exports |
| RelativisticDynamics | clean | 9 exports |
| Resonance | clean | 4 exports, 1 types |
| RotatingSky | clean | 3 exports, 1 types |
| SceneryStackTemplate | 1 exports, 2 files | 1 exports, 3 files |
| SimplifiedMRI | clean | 3 exports |
| SolarSystemModels | 1 exports | 1 exports |
| SpecialRelativity | clean | 10 exports |
| SpectroscopyLab | clean | 15 exports, 1 types |
| StandingWaves | clean | 3 exports |
| StellarWobble | clean | 3 exports |
| SternGerlach | clean | 2 exports |
| TheRamp | clean | 1 exports |
| TitrationLab | clean | 11 exports |
| TrackLab | clean | clean |
| TransitHunter | clean | 12 exports, 1 types |
| VariableStarPhotometry | clean | 1 exports |
| VernierScales | clean | 18 exports |
| WaveComposer | clean | 4 exports |
| Zenith | clean | 13 exports |
