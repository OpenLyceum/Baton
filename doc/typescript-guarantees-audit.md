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

## Follow-up review of fallbacks, options, and review safeguards

The final scan parsed 7,557 TypeScript files, including 5,405 production source files, across all 91 cataloged simulations and SceneryStackTemplate. It covered tracked files and new working-tree tests, along with 369 compiler and lint configuration files. The repository table above lists production coverage. The syntax scan found no parse errors, chained production assertions, asserted `Object.keys` lookups, compiler suppression directives, TypeScript enums, or SceneryStack ambient module shims. Context review focused on contracts that can change model results, hide a visible failure, or let a caller override model or view state.

| Repository | Follow-up change |
| --- | --- |
| AcceleratedMotion, CentripetalMotion, CollisionVideos, EnergyTransformations, HarmonicMotion, ImpulseTheorem, NewtonsSecondLaw, RotationalDynamics | Reject sparse derivative inputs instead of treating a missing sample as zero. The vendored derivative file remains identical across the eight copies. Other existing vendored differences were preserved. |
| CalorimetryLab | Keep each body's heat capacity, temperature, and room conductance together. Validate link endpoints and use checked temperatures and integration stages. Missing source power still means no heat source at that body. |
| CartCollisions | Resolve the plunger setting through one checked lookup shared by the physics and view. |
| ColliderLab | Require a generated track to have a matching particle and a shuffled event position to have an index. |
| DataLab | Give curve model reference fixtures a typed row shape and iterate the model IDs directly. |
| EquilibriumLab | Keep each species, initial concentration, and editable coefficient in one row. Use those rows in calculations and views and publish them before problem listeners run. |
| FluidDynamics | Return an explicit startup result, roll back partial WebGPU initialization, preserve diagnostics, and enumerate bind layouts with an own-key check. |
| InterferometryLab, PlateTectonics, StellarWobble | Derive canvas or node options from the parent and keep computed canvas bounds or owned children under component control. |
| QuantumAtom3D | Check the preset table against the same ordered IDs used by the view. |
| QuantumPotential | Keep typed parameter/property entries and save values in maps. Select the finite-well fallback from the numerical convergence result. |
| QubitSketch | Narrow each decoded row once and keep unvalidated array entries typed as unknown. |
| Resonance | Check the oscillator state vector at the model boundary and destructure its seven named slots. |
| TrackLab | Validate video durations in the model and expose the duration as a read-only property. Use typed kinematic samples for graph axes and preserve missing derivatives as missing values. |

### Review decisions

- Each root TypeScript configuration retains strict mode, unchecked-index checking, erasable syntax, and the existing `skipLibCheck` setting. Disabling `skipLibCheck` in a template compiler invocation exposed errors in the installed SceneryStack declarations. QuantumPotential's existing accuracy-script exclusion has a separate typecheck project and a documented indexed-access exception. OscillationsAndChaos's declaration file references the Vite client types.
- Baton coding and review guidance requires a stated rationale and explicit reviewer approval for TypeScript configuration, Biome configuration, or declaration changes. Approval is a reviewer responsibility under the existing CI workflow.
- Browser and hardware boundary guards, disabled storage handling, and finite-value checks remain where failure or missing data is expected. The final production scan counted 290 postfix assertions across OscillationsAndChaos, Resonance, and TrackLab, concentrated in documented solver, rendering, and ring-buffer paths.
- The test infrastructure keeps assertions used by partial browser capability mocks and SceneryStack inspection helpers. Syntax matches such as default values and option spreads require context. Numerical fitting and generated geometry still have candidates for more focused review.

### Follow-up verification

Verification used Node 26.13.1 and the member repositories’ existing npm scripts.

| Simulation | Lint | Typecheck | Build | Architecture | Knip | Unit suite | Targeted Chromium checks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AcceleratedMotion | Passed | Passed | Passed | Passed | Passed | Passed | — |
| CalorimetryLab | Passed | Passed | Passed | Passed | Passed | Passed | — |
| CartCollisions | Passed | Passed | Passed | Passed | Passed | Passed | — |
| CentripetalMotion | Passed | Passed | Passed | Passed | Passed | Passed | — |
| ColliderLab | Passed | Passed | Passed | Passed | Passed | Passed | — |
| CollisionVideos | Passed | Passed | Passed | Passed | Passed | Passed | — |
| DataLab | Passed | Passed | Passed | Passed | Passed | Passed | — |
| EnergyTransformations | Passed | Passed | Passed | Passed | Passed | Passed | — |
| EquilibriumLab | Passed | Passed | Passed | Passed | Passed | Passed | ICE-table keyboard regression passed |
| FluidDynamics | Passed | Passed | Passed | Passed | Passed | Passed | Unavailable-context and MacCormack transport checks passed |
| HarmonicMotion | Passed | Passed | Passed | Passed | Passed | Passed | — |
| ImpulseTheorem | Passed | Passed | Passed | Passed | Passed | Passed | — |
| InterferometryLab | Passed | Passed | Passed | Passed | Passed | Passed | Fringe rendering and photon-mark smoke passed |
| NewtonsSecondLaw | Passed | Passed | Passed | Passed | Passed | Passed | — |
| PlateTectonics | Passed | Passed | Passed | Passed | Passed | Passed | — |
| QuantumAtom3D | Passed | Passed | Passed | Passed | Passed | Passed | — |
| QuantumPotential | Passed | Passed | Passed | Passed | Passed | Passed on retry | — |
| QubitSketch | Passed | Passed | Passed | Passed | Passed | Passed | — |
| Resonance | Passed | Passed | Passed | Passed | Passed | Passed | — |
| RotationalDynamics | Passed | Passed | Passed | Passed | Passed | Passed | — |
| StellarWobble | Passed | Passed | Passed | Passed | Passed | Passed | — |
| TrackLab | Passed | Passed | Passed | Passed | Passed | Passed | Uploaded WebM metadata and keyboard playback smoke passed |

Baton’s skill validation passed for all 27 skills.
