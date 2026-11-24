# Fleet TypeScript guarantees audit

Reviewed 91 simulation checkouts from the Baton catalog and SceneryStackTemplate, covering 5,405 TypeScript source files.
The scan covered parsed JSON and storage reads, asserted lookup keys, broad records, definite assignment, and postfix non-null assertions. Candidate expressions were reviewed in context.
The production scan found no remaining class-field definite-assignment assertions or `as keyof` casts in this scope.

## Retained invariants

- OscillationsAndChaos and Resonance retain indexed accesses in documented solver and rendering paths. The solver work arrays are sized to their state vectors, and the renderer loops use the configured grid, palette, or populated instance range.
- TrackLab retains its documented ring-buffer reads. The buffer slots in the active range are written before they are read.
- Runtime dictionaries keep their dynamic keys where the caller can handle a missing entry. Decoders may represent raw objects as `Record<string, unknown>` while validating individual fields.

## Repository disposition

| Repository | TypeScript files | Disposition |
| --- | ---: | --- |
| AcceleratedMotion | 65 | No change identified by this review. |
| ACPhasor | 63 | No change identified by this review. |
| BackwardAcceleration | 54 | No change identified by this review. |
| BasicCoordinatesAndSeasons | 74 | No change identified by this review. |
| BiomechanicsArm | 37 | No change identified by this review. |
| CalorimetryLab | 66 | No change identified by this review. |
| CapacitorLab | 102 | Each concrete circuit initializes its electrical output bundle after setting up its inputs. |
| CarnotHeatEngine | 56 | No change identified by this review. |
| CartCollisions | 68 | No change identified by this review. |
| CentripetalMotion | 64 | No change identified by this review. |
| CirculationLab | 39 | No change identified by this review. |
| ColliderLab | 57 | No change identified by this review. |
| CollisionVideos | 66 | No change identified by this review. |
| ContourExplorer | 21 | No change identified by this review. |
| CrystalLattice | 69 | No change identified by this review. |
| DataLab | 66 | Validate saved sessions and datasets and migrate weighted-linear fits on load. |
| DiffractionLab | 49 | No change identified by this review. |
| DopplerEffect | 39 | No change identified by this review. |
| DoubleIntegralBuilder | 26 | No change identified by this review. |
| ElectricFieldMapper | 36 | No change identified by this review. |
| ElectricFieldOfDreams | 27 | No change identified by this review. |
| Electrochemistry | 51 | Check half-cell and electrolysis name keys against the localized groups. |
| ElectronConfiguration | 47 | No change identified by this review. |
| EnergyTransformations | 67 | No change identified by this review. |
| EquilibriumLab | 71 | Carry typed species IDs from the reaction catalog to localization. |
| ExoplanetsDatabase | 71 | No change identified by this review. |
| ExtrasolarPlanets | 42 | No change identified by this review. |
| FieldBoundary | 52 | No change identified by this review. |
| FluidDynamics | 56 | Construct solver fields and their views as one typed resource bundle. |
| FluidPressureAndFlow | 93 | No change identified by this review. |
| HabitabilityLab | 71 | No change identified by this review. |
| HabitableZones | 43 | No change identified by this review. |
| HarmonicMotion | 55 | No change identified by this review. |
| HeatTransfer | 75 | No change identified by this review. |
| HRDiagram | 59 | No change identified by this review. |
| ImpulseTheorem | 60 | No change identified by this review. |
| InterferometryLab | 64 | No change identified by this review. |
| LadyBug | 36 | No change identified by this review. |
| Lasers | 33 | No change identified by this review. |
| LewisStructures | 71 | No change identified by this review. |
| LightAndAtoms | 65 | No change identified by this review. |
| LightPropagation | 59 | Represent the WebGL scene as an optional, fully constructed bundle. |
| LimitExplorer | 26 | No change identified by this review. |
| LunarLander | 39 | No change identified by this review. |
| MazeGame | 36 | No change identified by this review. |
| MeanValueTheorem | 28 | No change identified by this review. |
| MercuryElongations | 47 | No change identified by this review. |
| MolScope | 70 | Tie console message keys to their formatting arguments. |
| MotionMatch | 51 | Check motion profile IDs against the description group. |
| MotionSensor | 54 | No change identified by this review. |
| MotionsOfTheSun | 75 | Use the zodiac key union for localized sign lookups and the Capricornus alias. |
| MovingMan | 37 | No change identified by this review. |
| NewtonsSecondLaw | 65 | No change identified by this review. |
| NuclideChart | 79 | No change identified by this review. |
| OpticsLab | 142 | Validate scene input, decode typed element fields, and preserve typed edits in command batches. |
| OscillationsAndChaos | 73 | Pair rewind state with its parameters, pair trail samples with times, and check view initialization. |
| Oscilloscope | 52 | No change identified by this review. |
| ParticleZoo | 59 | No change identified by this review. |
| PeriodicTrends | 51 | No change identified by this review. |
| PhotonInteractions | 58 | No change identified by this review. |
| PlanetaryConfigurations | 70 | No change identified by this review. |
| PlateTectonics | 95 | No change identified by this review. |
| Precession | 57 | No change identified by this review. |
| QuantumAtom3D | 111 | No change identified by this review. |
| QuantumPotential | 114 | Initialize chart axes and labels directly in constructors. |
| QuantumScattering | 62 | No change identified by this review. |
| QubitSketch | 51 | Build reverse QASM lookups from typed gate and rotation tables. |
| RadioactivityAndStatistics | 55 | No change identified by this review. |
| RadioWaves | 32 | No change identified by this review. |
| RelatedRates | 36 | No change identified by this review. |
| RelativisticDynamics | 56 | No change identified by this review. |
| Resonance | 95 | Check stored preferences, tighten preset keys, and check renderer and oscillator initialization. |
| RiemannSumBuilder | 26 | No change identified by this review. |
| RootFinding | 35 | No change identified by this review. |
| RotatingSky | 75 | No change identified by this review. |
| RotationalDynamics | 61 | No change identified by this review. |
| SceneryStackTemplate | 21 | No change identified by this review. |
| SimplifiedMRI | 61 | Check tissue and nucleus keys against their localized groups. |
| SolarSystemModels | 50 | Represent the key panel tabs as a nonempty tuple. |
| SpecialRelativity | 55 | No change identified by this review. |
| SpectroscopyLab | 75 | No change identified by this review. |
| StandingWaves | 65 | No change identified by this review. |
| StellarWobble | 63 | No change identified by this review. |
| SternGerlach | 61 | No change identified by this review. |
| TheRamp | 60 | No change identified by this review. |
| TitrationLab | 51 | Check analyte, indicator, color, and method keys against their localized groups. |
| TrackLab | 61 | Retain two bounded ring-buffer reads. The data size and filled slots establish the invariant at each read. |
| TransitHunter | 77 | Check bundled light curve module shapes at compile time and decode the time-system discriminant. |
| VariableStarPhotometry | 45 | No change identified by this review. |
| VernierScales | 56 | No change identified by this review. |
| WaveComposer | 88 | Check group-specific preset localization keys and assign the audio frame-buffer bundle on allocation. |
| Zenith | 58 | Share checked star, body, and constellation labels and preserve the dynamic constellation fallback. |

## Verification

Verification used Node 26.13.1. The table records completed checks for the simulations with source changes. Pending entries were interrupted before a result was recorded.
Separate compiler probes rejected an invalid WaveComposer catalog key (TS2820) and a CapacitorLab subclass without the required electrical-state initializer (TS2515).

| Simulation | Lint | Typecheck | Unit tests | Build | Architecture | Knip default/production | Browser smoke |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CapacitorLab | Passed | Passed | Passed | Passed | Passed | Passed/Passed | Passed against build preview |
| DataLab | Passed | Passed | Failed | Passed | Passed | Passed/Passed | Passed against build preview |
| Electrochemistry | Passed | Passed | Passed | Passed | Passed | Passed/Passed | Passed |
| EquilibriumLab | Passed | Passed | Passed | Passed | Passed | Passed/Passed | Passed built-app smoke |
| FluidDynamics | Passed | Passed | Failed | Passed | Passed | Passed/Passed | Passed built-app smoke |
| LightPropagation | Passed | Passed | Passed | Passed | Passed | Passed/Passed | Passed against build preview |
| MolScope | Passed | Passed | Failed | Passed | Passed | Passed/Passed | Passed built-app smoke |
| MotionMatch | Passed | Passed | Passed | Passed | Passed | Passed/Passed | Failed |
| MotionsOfTheSun | Passed | Passed | Failed | Passed | Passed | Passed/Passed | Passed |
| OpticsLab | Passed | Passed | Failed | Passed | Passed | Passed/Passed | Passed built-app smoke |
| OscillationsAndChaos | Passed | Passed | Pending | Pending | Passed | Passed/Passed | Failed |
| QuantumPotential | Passed | Passed | Pending | Passed | Passed | Passed/Passed | Failed |
| QubitSketch | Passed | Passed | Pending | Passed | Passed | Passed/Passed | Failed |
| Resonance | Passed | Passed | Pending | Passed | Passed | Passed/Passed | Failed |
| SimplifiedMRI | Passed | Passed | Pending | Passed | Passed | Passed/Passed | Failed |
| SolarSystemModels | Passed | Passed | Pending | Pending | Pending | Pending/Pending | Failed |
| TitrationLab | Passed | Pending | Pending | Pending | Pending | Pending/Pending | Failed |
| TransitHunter | Passed | Passed | Pending | Passed | Passed | Passed/Passed | Failed |
| WaveComposer | Passed | Passed | Failed | Passed | Passed | Passed/Passed | Failed |
| Zenith | Passed | Passed | Pending | Passed | Passed | Passed/Passed | Failed |

Several development-server browser runs timed out during navigation or while waiting for the simulation to become visible. A preview pass records a run of the same test suite against the built app. The built-app smoke uses the same 10-second pointer and keyboard modes in a shared Chromium process without video or trace collection.

Several unit suites reported Vitest worker startup or memory-leak timeouts. Browser runs also hit navigation timeouts and an artifact-file collision. The execution environment restarted repeatedly during retries.
