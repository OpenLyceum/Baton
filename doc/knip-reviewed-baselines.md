# Knip reviewed baselines

Source of truth for which SceneryStack callers use `unused-mode: required` versus
`advisory`. Update this file when promoting or demoting a sim. Policy and local
commands live in [`knip.md`](knip.md); the 2026-11-15 inventory snapshot is
[`knip-rollout.md`](knip-rollout.md) (historical — do not treat it as the live
promotion list).

Callers match `SceneryStackTemplate`: `unused-mode: required` after both default and
production Knip reports are reviewed and cleared, with lint, typecheck, tests,
architecture checks, and build still green. A sim that remains on `advisory` must
document that deviation under `## Compliance carve-outs` in its `AGENTS.md`.

## Required (`unused-mode: required`)

48 checkouts (47 simulations + SceneryStackTemplate), as of 2026-11-17 local CI callers:

- ACPhasor
- BackwardAcceleration
- BasicCoordinatesAndSeasons
- BiomechanicsArm
- CalorimetryLab
- CapacitorLab
- CarnotHeatEngine
- CartCollisions
- ColliderLab
- CrystalLattice
- DataLab
- DiffractionLab
- DopplerEffect
- ElectricFieldMapper
- ElectricFieldOfDreams
- Electrochemistry
- ElectronConfiguration
- EquilibriumLab
- ExoplanetsDatabase
- ExtrasolarPlanets
- FieldBoundary
- FluidDynamics
- FluidPressureAndFlow
- HRDiagram
- HabitabilityLab
- HabitableZones
- HeatTransfer
- InterferometryLab
- LadyBug
- Lasers
- LewisStructures
- LightAndAtoms
- LightPropagation
- LunarLander
- MazeGame
- MercuryElongations
- MolScope
- MotionMatch
- MotionSensor
- MotionsOfTheSun
- MovingMan
- NuclideChart
- OscillationsAndChaos
- Oscilloscope
- PeriodicTrends
- RadioactivityAndStatistics
- SceneryStackTemplate
- WaveComposer

## Advisory (`unused-mode: advisory`)

27 simulations still on advisory CI. Each must keep an AGENTS carve-out naming
`.github/workflows/ci.yml` and the pending Knip review:

- OpticsLab
- ParticleZoo
- PhotonInteractions
- PlanetaryConfigurations
- PlateTectonics
- Precession
- QuantumAtom3D
- QuantumPotential
- QubitSketch
- RadioWaves
- RelativisticDynamics
- Resonance
- RotatingSky
- SimplifiedMRI
- SolarSystemModels
- SpecialRelativity
- SpectroscopyLab
- StandingWaves
- StellarWobble
- SternGerlach
- TheRamp
- TitrationLab
- TrackLab
- TransitHunter
- VariableStarPhotometry
- VernierScales
- Zenith

## 2026-11-17 promotions: DataLab and PeriodicTrends

Both default and production Knip 6.45.1 reports are empty with exit code 0 under
Node v26.13.0. No source cleanup, configuration changes, or suppression tags were
needed. Both CI callers now use `unused-mode: required`, and their obsolete
advisory carve-outs were removed.

Validation uses isolated copies of committed DataLab `c5316870` and PeriodicTrends
`e19bfbb6`, with only the CI and AGENTS promotion edits applied and the existing
installed dependencies. Lint, app/scripts/test type checks, production builds,
and architecture checks pass. DataLab passes 134 unit tests; PeriodicTrends
passes 109. Each also passes 46 architecture/Biome tooling regression tests.
The tooling tests require execution outside the sandbox because it denies their
child-process calls. Each repo also passes both pointer and keyboard Chromium
fuzz smoke tests (10 seconds of activity per mode); these require local-server
access outside the sandbox.

The working checkouts also contain unrelated, uncommitted memory-test changes.
Those changes were preserved and excluded from the isolated validation. Full
working-tree lint currently fails on formatting in `tests/helpers/memoryLeak.ts`,
and type checking fails on `Page.metrics` in `tests/browser/memory-soak.spec.ts`
in both repos. Both Knip modes also pass against these working trees; this
promotion does not claim that their unrelated work in progress passes every check.

Local validation logs: `/tmp/knip-promotion-validation-clean/`; initial working-tree
Knip reports: `/tmp/knip-promotions-20261117-datalab-initial/` (DataLab) and
`/tmp/knip-promotions-20261117-initial/` (PeriodicTrends). Validation was local;
hosted CI and branch-protection settings were not verified.
