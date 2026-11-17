# Knip rollout — updated 2026-11-17

The local catalog contains **74 simulations plus SceneryStackTemplate**. All 75
installed checkouts were reanalyzed with Node 26.13.0 and Knip 6.45.1 on 2026-11-17.

**75 checkouts are clean in both modes; 0 have findings; 0 failed to execute.**
Default and production modes each report zero unused exports, types, files,
cycles, unresolved references, unlisted binaries, and unused dependencies.
Both modes exited 0 with valid, empty reports in every checkout.

The machine-readable snapshot is [knip-inventory-2026-11-17.json](knip-inventory-2026-11-17.json).
It records exit codes, issue counts, HEAD, local dirty state, and config/lock hashes.
Raw per-repo JSON and stderr are retained locally in
`/tmp/knip-rollout-refresh-20261117/`. Reproduce them with the inventory command in
[knip.md](knip.md#inventory-and-ci-rollout). This is a local working-tree inventory;
hosted CI was not checked, and no fixes or promotions were applied by this scan.

After the 2026-11-17 final advisory promotions, catalog CI callers use **required
mode in every simulation checkout plus the template**. The [reviewed promotion
list](knip-reviewed-baselines.md) also includes QuantumScattering (outside the
catalog), for **76 required checkouts and 0 advisory** across the workspace.
Clean inventory results alone do not promote a caller — the other validation
gates in [`knip.md`](knip.md) still apply when demoting or reviewing a new sim.

The [2026-11-15 snapshot](knip-inventory-2026-11-15.json) recorded 10 clean checkouts
and 65 with findings. Its default mode reported 9 unused exports and 2 unused
files; production reported 401 unused exports, 21 unused types, and 3 unused files.
Those historical counts are superseded by the fresh inventory above.

## Original rollout pilot: ACPhasor (2026-11-15)

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

**Live promotion list:** after this inventory, many callers (including the template)
were promoted to `unused-mode: required`. Do not use this section as the current
required/advisory set — see [`knip-reviewed-baselines.md`](knip-reviewed-baselines.md).

## Original rollout validation (2026-11-15)

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

## Per-repository findings (2026-11-17)

| Repository | Default | Production |
| --- | --- | --- |
| ACPhasor | clean | clean |
| BackwardAcceleration | clean | clean |
| BasicCoordinatesAndSeasons | clean | clean |
| BiomechanicsArm | clean | clean |
| CalorimetryLab | clean | clean |
| CapacitorLab | clean | clean |
| CarnotHeatEngine | clean | clean |
| CartCollisions | clean | clean |
| ColliderLab | clean | clean |
| CrystalLattice | clean | clean |
| DataLab | clean | clean |
| DiffractionLab | clean | clean |
| DopplerEffect | clean | clean |
| ElectricFieldMapper | clean | clean |
| ElectricFieldOfDreams | clean | clean |
| Electrochemistry | clean | clean |
| ElectronConfiguration | clean | clean |
| EquilibriumLab | clean | clean |
| ExoplanetsDatabase | clean | clean |
| ExtrasolarPlanets | clean | clean |
| FieldBoundary | clean | clean |
| FluidDynamics | clean | clean |
| FluidPressureAndFlow | clean | clean |
| HRDiagram | clean | clean |
| HabitabilityLab | clean | clean |
| HabitableZones | clean | clean |
| HeatTransfer | clean | clean |
| InterferometryLab | clean | clean |
| LadyBug | clean | clean |
| Lasers | clean | clean |
| LewisStructures | clean | clean |
| LightAndAtoms | clean | clean |
| LightPropagation | clean | clean |
| LunarLander | clean | clean |
| MazeGame | clean | clean |
| MercuryElongations | clean | clean |
| MolScope | clean | clean |
| MotionMatch | clean | clean |
| MotionSensor | clean | clean |
| MotionsOfTheSun | clean | clean |
| MovingMan | clean | clean |
| NuclideChart | clean | clean |
| OpticsLab | clean | clean |
| OscillationsAndChaos | clean | clean |
| Oscilloscope | clean | clean |
| ParticleZoo | clean | clean |
| PeriodicTrends | clean | clean |
| PhotonInteractions | clean | clean |
| PlanetaryConfigurations | clean | clean |
| PlateTectonics | clean | clean |
| Precession | clean | clean |
| QuantumAtom3D | clean | clean |
| QuantumPotential | clean | clean |
| QubitSketch | clean | clean |
| RadioWaves | clean | clean |
| RadioactivityAndStatistics | clean | clean |
| RelativisticDynamics | clean | clean |
| Resonance | clean | clean |
| RotatingSky | clean | clean |
| SceneryStackTemplate | clean | clean |
| SimplifiedMRI | clean | clean |
| SolarSystemModels | clean | clean |
| SpecialRelativity | clean | clean |
| SpectroscopyLab | clean | clean |
| StandingWaves | clean | clean |
| StellarWobble | clean | clean |
| SternGerlach | clean | clean |
| TheRamp | clean | clean |
| TitrationLab | clean | clean |
| TrackLab | clean | clean |
| TransitHunter | clean | clean |
| VariableStarPhotometry | clean | clean |
| VernierScales | clean | clean |
| WaveComposer | clean | clean |
| Zenith | clean | clean |
