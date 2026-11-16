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

46 checkouts (45 simulations + SceneryStackTemplate), as of 2026-11-15 evening local CI callers:

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
- RadioactivityAndStatistics
- SceneryStackTemplate
- WaveComposer

## Advisory (`unused-mode: advisory`)

29 simulations still on advisory CI. Each must keep an AGENTS carve-out naming
`.github/workflows/ci.yml` and the pending Knip review:

- DataLab
- OpticsLab
- ParticleZoo
- PeriodicTrends
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
