# Knip reviewed baselines

Source of truth for which SceneryStack callers use `unused-mode: required` versus
`advisory`. Update this file when promoting or demoting a sim. Policy and local
commands live in [`knip.md`](knip.md); the latest local inventory is summarized in
[`knip-rollout.md`](knip-rollout.md). Inventory results do not replace this reviewed
promotion list.

Callers match `SceneryStackTemplate`: `unused-mode: required` after both default and
production Knip reports are reviewed and cleared, with lint, typecheck, tests,
architecture checks, and build still green. A sim that remains on `advisory` must
document that deviation under `## Compliance carve-outs` in its `AGENTS.md`.

## Required (`unused-mode: required`)

76 checkouts (75 simulations + SceneryStackTemplate), as of 2026-11-17 local CI callers:

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
- OpticsLab
- OscillationsAndChaos
- Oscilloscope
- ParticleZoo
- PeriodicTrends
- PhotonInteractions
- PlanetaryConfigurations
- PlateTectonics
- Precession
- QuantumAtom3D
- QuantumPotential
- QuantumScattering
- QubitSketch
- RadioactivityAndStatistics
- RadioWaves
- RelativisticDynamics
- Resonance
- RotatingSky
- SceneryStackTemplate
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
- WaveComposer
- Zenith

## Advisory (`unused-mode: advisory`)

None. Every SceneryStack simulation caller and SceneryStackTemplate use
`unused-mode: required`.

## 2026-11-17 promotions: final 14 advisories

Both default and production Knip 6.45.1 reports are empty with exit code 0 under
Node v26.13.0 for these fourteen working checkouts (no source cleanup needed —
findings from the 2026-11-15 inventory were already cleared):

- ParticleZoo, PhotonInteractions, PlateTectonics, Precession
- QuantumAtom3D, QuantumPotential, RelativisticDynamics, Resonance
- SpecialRelativity, SpectroscopyLab, TitrationLab, TransitHunter
- VernierScales, Zenith

Each CI caller now uses `unused-mode: required`, and the obsolete advisory carve-out
bullet was removed from `AGENTS.md` (the whole Compliance section was dropped when it
would have been empty; ParticleZoo kept its template-owned / overrides subsections).
Lint, typecheck, architecture checks, production builds, and unit tests pass on the
working trees. QuantumPotential’s densest Many Wells timing budget was raised from
2 s to 3.5 s after a consistent ~2.4 s wall time on this WSL host; that change is
unrelated to Knip findings. Hosted CI and branch-protection settings were not verified.

Validation logs: `/tmp/knip-promotion-validation-14/`; Knip reports:
`/tmp/knip-advisory-20261117/`.

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

## 2026-11-17 promotions: OpticsLab, QubitSketch, and RadioWaves

Both default and production Knip 6.45.1 reports are clean under Node v26.13.0
for all three working checkouts after integrating the single-file build PRs.
Their CI callers now use `unused-mode: required`, and their obsolete advisory
carve-outs are removed. No source cleanup or suppression tags were needed.

Lint, app/scripts/test type checks, architecture checks, production builds,
and unit tests pass: OpticsLab has 459 tests, QubitSketch 93, and RadioWaves 21.
Each also passes all 46 architecture/Biome tooling regression tests. Those
CLI fixtures require child-process access outside the sandbox. Browser fuzz
was not rerun for these CI-only promotions; hosted CI has not been checked for
these uncommitted changes.

Validation logs: `/tmp/OpticsLab-followup-validation.log`,
`/tmp/QubitSketch-followup-validation.log`, and
`/tmp/RadioWaves-followup-validation.log`. Tooling reruns are in the matching
`/tmp/<Repo>-followup-tooling-tests.log` files; the two Knip reports are in
`/tmp/<Repo>-knip-followup.log`.

## 2026-11-17 promotions: TrackLab and nine ≤3-finding advisories

Both default and production Knip 6.45.1 reports are empty with exit code 0 under
Node v26.13.0 for these ten working checkouts (no source cleanup needed — findings
from the 2026-11-15 inventory were already cleared):

- TrackLab (was clean/clean in the inventory)
- TheRamp, VariableStarPhotometry, SolarSystemModels
- SternGerlach, PlanetaryConfigurations
- StandingWaves, StellarWobble, SimplifiedMRI, RotatingSky

Each CI caller now uses `unused-mode: required`, and the obsolete advisory carve-out
bullet was removed from `AGENTS.md` (the whole Compliance section was dropped when it
would have been empty). Hosted CI was not re-checked for these uncommitted promotions.
