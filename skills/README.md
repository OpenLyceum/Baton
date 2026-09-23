# SceneryStack skills

Focused, single-topic reference docs for building OpenLyceum SceneryStack simulations. Each
skill is a folder containing a `SKILL.md` in the standard Claude Code layout —
[YAML frontmatter](https://code.claude.com/docs/en/skills) (`name` + `description`) describing
**when** it applies, followed by the patterns, code, and common mistakes for that topic. An AI
assistant loads the one whose `description` matches the task at hand; a human can read them as
topic guides.

These complement, not replace, the broader docs:

- [`.github/AGENTS.md`](https://github.com/OpenLyceum/.github/blob/main/AGENTS.md) — the org-wide AI guide (tech stack, bootstrap chain, commands). Start there.
- [`../CONVENTIONS.md`](../CONVENTIONS.md) — the structural convention (file layout, naming, the `preferences/` trio, tests).
- [`../ACCESSIBILITY.md`](../ACCESSIBILITY.md) — the shared accessibility pattern.

The skills go one level deeper than `AGENTS.md`: API specifics, idioms, and pitfalls for a
single subsystem. When a skill is not specific enough, grep
`Almanach/docs/public/llms.txt` (or `llms-full.txt`) in the local Almanach checkout.

New skills follow [`TEMPLATE.md`](TEMPLATE.md) and must be added to the index below;
[`../scripts/check-skills.sh`](../scripts/check-skills.sh) (run in CI by
[`baton-selfcheck.yml`](../.github/workflows/baton-selfcheck.yml)) enforces that every
folder is well-formed and listed here.

## Index

### Coding & review

| Skill | Use when |
|---|---|
| [`scenerystack-coding-conventions`](scenerystack-coding-conventions/SKILL.md) | Writing/reviewing TypeScript — naming, constructor signatures, optionize, access modifiers, type inference, assertions, read-vs-write Property APIs. |
| [`scenerystack-code-review`](scenerystack-code-review/SKILL.md) | Running a pre-release Code Review (CRC) on a sim — build/fuzz, memory leaks, performance, i18n, structure conformance, rename residue, keyboard-help stubs, accessibility. |
| [`scenerystack-testing`](scenerystack-testing/SKILL.md) | Adding/changing unit tests — `vitest` specs for model/physics code, the fleet-standard `tests/` layout + memory-leak suite (`forceGC` early-exit), optional Playwright fuzz, WebGPU launch flags. |

### Model & math

| Skill | Use when |
|---|---|
| [`scenerystack-model`](scenerystack-model/SKILL.md) | Creating/changing a model — state, physics, the `step(dt)`/`reset()` loop, reactive Properties, the `TModel` contract, model/view separation, GPU-only `common/gpu/` carve-outs. |
| [`scenerystack-model-view-transform`](scenerystack-model-view-transform/SKILL.md) | Converting between model and view coordinates or scaling physical quantities to pixels — `ModelViewTransform2`. |
| [`scenerystack-constants`](scenerystack-constants/SKILL.md) | A number, size, or physical parameter appears in code — define it in root `*Constants.ts` (plus documented nested extras) instead of inlining a magic value. |
| [`scenerystack-numerics`](scenerystack-numerics/SKILL.md) | Writing a model's numerical core — integrating motion over `dt`, stable time steps, Euler vs. higher-order integration, `Utils`/`LinearFunction`/`dotRandom`, `toFixed` (never `Number.toFixed`), determinism. |
| [`scenerystack-enumeration`](scenerystack-enumeration/SKILL.md) | A model/view needs a fixed set of named choices (mode, state, tool) — `EnumerationValue`, `EnumerationProperty`, and why to prefer it over string unions or numeric constants. |

### View & layout

| Skill | Use when |
|---|---|
| [`scenerystack-layout`](scenerystack-layout/SKILL.md) | Positioning nodes — `layoutBounds`, `VBox`/`HBox`/`GridBox`, `AlignBox`/`AlignGroup`, struts, `Panel`. |
| [`scenerystack-color-profiles`](scenerystack-color-profiles/SKILL.md) | Adding/theming colors — `ProfileColorProperty`, the per-sim `*Colors.ts`, projector mode, and contrast gotchas (Checkbox, ComboBox, NumberDisplay) that fail in the dark default profile. |
| [`scenerystack-drag-listener`](scenerystack-drag-listener/SKILL.md) | Making a node draggable by mouse, touch, or keyboard — `DragListener`, `KeyboardDragListener`, `RichDragListener`, drag bounds. |
| [`scenerystack-optionize`](scenerystack-optionize/SKILL.md) | A constructor takes configurable options — `optionize<>()`, `SelfOptions`/`Options`, `EmptySelfOptions`, `combineOptions`. |
| [`scenerystack-ui-controls`](scenerystack-ui-controls/SKILL.md) | Adding standard controls — sliders, spinners, checkboxes, radio buttons, combo boxes, buttons, Reset All, themed `<Prefix>Panel`/`Dialog` — from `sun`/`scenery-phet`, wired to model Properties. |
| [`scenerystack-custom-drawing`](scenerystack-custom-drawing/SKILL.md) | Rendering custom graphics the standard nodes don't cover — curves, filled regions, arrows, dynamic paths, dense fields via `CanvasNode`/WebGL/WebGPU, spectral CIE XYZ colour. |
| [`scenerystack-animation`](scenerystack-animation/SKILL.md) | Something must move or change smoothly over time, independent of the physics step — the twixt `Animation` class, `Easing`, chaining/looping, animate vs. integrate. |

### Text & localization

| Skill | Use when |
|---|---|
| [`scenerystack-strings`](scenerystack-strings/SKILL.md) | A view needs display text, or you add/rename user-visible text — `StringManager`, `strings_*.json`, consuming `*StringProperty`. |
| [`scenerystack-i18n`](scenerystack-i18n/SKILL.md) | Adding a locale, keeping locale files in sync, interpolating with `PatternStringProperty`, or enabling the runtime language picker. |

### App structure & lifecycle

| Skill | Use when |
|---|---|
| [`scenerystack-new-sim`](scenerystack-new-sim/SKILL.md) | Creating a new sim from `SceneryStackTemplate` — `create-sim.sh` or rename + scaffold-screens, post-rename `Sim*` residue, keyboard-help stubs, bootstrap gotchas. |
| [`scenerystack-screen-view`](scenerystack-screen-view/SKILL.md) | Wiring a sim's entry point — the `scenerystack/sim` `Sim`/`Screen`/`ScreenView` trio, multi-screen `*ScreenIcons.ts`, the model factory, screen icons/background, the per-frame `step` hand-off. |
| [`scenerystack-disposal`](scenerystack-disposal/SKILL.md) | Creating nodes/listeners/Properties that don't live for the whole sim — `dispose()`, `disposeEmitter`, unlinking, tearing down `DerivedProperty`/`Multilink`, avoiding leaks. |

### Configuration & accessibility

| Skill | Use when |
|---|---|
| [`scenerystack-preferences`](scenerystack-preferences/SKILL.md) | Configuring the Preferences dialog — projector mode, dynamic locale, sound, interactive highlights, custom controls. |
| [`scenerystack-query-parameters`](scenerystack-query-parameters/SKILL.md) | Adding a URL-configurable startup option or debug flag — a typed `QueryStringMachine` schema. |
| [`scenerystack-keyboard-help-dialog`](scenerystack-keyboard-help-dialog/SKILL.md) | Documenting keyboard controls in the `?` dialog — `KeyboardHelpSection`, `TwoColumnKeyboardHelpContent`, `createKeyboardHelpNode`; do not ship the template stub. |
| [`scenerystack-accessibility`](scenerystack-accessibility/SKILL.md) | Making a sim usable with a keyboard and screen reader — `accessibleName`, help text, dynamic announcements, keyboard listeners, interactive highlights. |
| [`scenerystack-sound`](scenerystack-sound/SKILL.md) | Adding sound — UI feedback, sonification of a changing quantity, or an audio Preferences tab — `tambo`, `soundManager`, `SoundClip`, gating on the sound-enabled Property. |
