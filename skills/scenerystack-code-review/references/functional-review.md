# Functional review checks

Use only the sections relevant to the requested scope. These checks distill the October 2026 fleet reviews; they supplement structural compliance, which cannot prove runtime behavior.

## Time controls and transport

- Trace the framework → model → view step chain. Joist already steps the active model; a view must not advance it twice. Verify a known frame duration advances the clock once.
- Exercise the actual paused Step callback: time and physical state advance while playback stays paused; ordinary paused frames do not advance. Test both screens when they use distinct callbacks.
- For forward integration, test zero, negative, and nonfinite durations. A dirty paused field refresh can recompute samples without advancing time. Signed numerical integration needs an explicit separate contract.
- Hit an event exactly at a frame boundary as well as across it. STOP/PAUSE actions should fire once, including equality.
- Exercise a timer after leaving and returning to its starting position. A run latch resets on retry/reset, not on revisiting a coordinate.

## Recording, playback, and samples

- Edit inputs while paused, start recording via Play and Step, then rewind to zero. The first snapshot must reflect current state/inputs, not the previous integration result; snapshot forces/energy consistently.
- Start playback at a cursor away from the live end state and verify the cursor state is applied immediately. Seek, scrubber handle, and track share a time scale.
- Cross the duration cap with a partial final interval. Capture the endpoint and pause in that frame; repeated Step cannot overrun. Shorten a duration and step backward from the displayed bounded time.
- Rewind dissipative/chaotic motion by restoring history, including physical parameters. Resume discards the abandoned future. Reset/preset clears history at zero as well as at positive time. Graphs and timestamped trails trim on rewind and retain points during pause.
- Resume acquisition after changing interval: two 2-second samples followed by a 1-second sample start at 0, 2, 4 seconds. Check multiple samples appended in one frame and preserve each sample's settings.
- Clear/reset/release after accumulating fractional emission time or derivative/average history. Fresh-run actions reset the relevant accumulator/readout; reset physical state before reseeding position samplers. Update measured rates after appending the latest sample.

## Modes, edits, and constraints

- Switch manual/oscillating strategies after dragging and editing controls. Initialize from current state, clear obsolete pending edits, and reset derivative history where discontinuities require it.
- Edit or undo/redo while inspecting past state. Return to live state or explicitly update the inspection cursor so displays represent the changed model.
- Select a harmonic/preset from a conflicting starting mode, such as driver off. Establish any required drive state before computing a steady response.
- Change a cache dependency while paused, including time, and compare with a freshly computed reference. Invalidation must cover every input, not only physical parameters.
- Enable walls while an object is outside the boundary, and test collisions at all edges/outside the grid. Distinguish interaction limits from solver state limits: do not clamp unbounded spring motion to a drag range.

## Numerical correctness

- Cross-check derivatives against finite differences at zero and varied amplitudes; check derivative-buffer timestamps as well as magnitudes.
- Validate energy and damping against independent equations, especially coupled systems. All solvers/mappers must agree on state-vector ordering.
- Confirm splitting-integrator compatibility when damping/velocity coupling changes and when a fallback solver is selected. Subdivision respects signed integration only where intentionally supported.
- For discrete-answer grading, test values between ticks: roundoff tolerance must not round a wrong answer into a correct tick.

## Input and lifecycle

- Focus the actual PDOM target and press a key; assert the resulting model action. A listener attached to a decorative descendant may be unreachable even though keyboard fuzz passes. See scenerystack-drag-listener.
- Dispose real field/trace nodes with global colors and model Properties still alive. Check owned traces and derived accessibility Properties, then repeat creation/disposal with WeakRef collection. A generic Property GC test is only a harness check.
- Stop/dispose while microphone acquisition and audio resume are pending. Complete or reject the old request after starting a new one: obsolete callbacks must not update status, leak returned streams, or close newer resources. Test partial startup failures too.

## Reporting evidence

Describe the paths reviewed and observable findings, with file locations and impact. Prefer regressions that fail before the fix and independent reference calculations. Record lint/type/test/build results, deterministic browser checks, fuzz mode/duration, actual runtime, and unavailable checks separately.

Short fuzz is smoke evidence; mocks do not validate physical sensors, shader contracts do not prove GPU solver accuracy, and automated source review does not establish educator or manual screen-reader sign-off. If a suite fails under contention, investigate and rerun it in isolation (distinct browser ports or fewer test workers) before diagnosing a product defect.

## Sources and ownership

The source reports are `doc/*review*2026-10-04.md` in ElectricFieldOfDreams, ExtrasolarPlanets, FieldBoundary, FluidDynamics, HeatTransfer, InterferometryLab, LadyBug, LightPropagation, LunarLander, MazeGame, MotionSensor, MotionsOfTheSun, MovingMan, Oscilloscope, Precession, QuantumPotential, QubitSketch, RadioWaves, RadioactivityAndStatistics, RotatingSky, SolarSystemModels, SpecialRelativity, StandingWaves, TheRamp, VernierScales, and WaveComposer. Additional solver/rewind lessons are documented in OscillationsAndChaos `doc/implementation-notes.md` and recent fixes there and in MovingMan.

Maintain implementation guidance in the owning model, numerics, screen-view, UI-controls, disposal, sound, and testing skills. This reference provides review probes rather than duplicating their implementation examples. Source paths identify the October 2026 evidence; the checks remain usable without those repositories installed.
