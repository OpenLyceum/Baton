---
name: scenerystack-sound
description: Use when adding sound to a simulation — UI feedback sounds, sonification of a changing quantity, or an audio Preferences tab. Covers the tambo library, soundManager, SoundClip, registering generators, gating on the sound-enabled Property, and importing audio assets.
---

# SceneryStack Sound

Sound is handled by **`scenerystack/tambo`**. You register `SoundGenerator`s (most often a `SoundClip` wrapping an audio file) with the global `soundManager`; tambo plays them through the shared audio graph and respects the user's master sound toggle and the Preferences "Sound" control automatically. Never create raw `AudioContext`/`Audio` objects.

## Turn sound on in both places

A sim with sound sets `supportsSound: true` in **both** `src/init.ts` and `PreferencesModel` `audioOptions` in `src/main.ts`. The two flags do different jobs, and either one alone leaves sound silent or the navigation-bar speaker disabled:

- **`init({ supportsSound: true })`** writes `simFeatures.supportsSound`, which is the default of the `?supportsSound` query parameter. That value is the initial state of `soundManager.enabledProperty`. It is also what keeps the navigation-bar speaker enabled (`audioManager.anySubcomponentEnabledProperty` stays false while that Property is false, and the speaker button disables itself).
- **`audioOptions.supportsSound: true`** is what makes `Sim` call `soundManager.initialize()` and offer Audio preferences. It defaults from the same query parameter, so an `init`-only sim still initializes tambo — but a `main.ts`-only sim starts muted, because `enabledProperty` never leaves `false` and the speaker button is disabled. When sound is the only audio feature, the Preferences sound toggle is hidden too, so there is no in-sim control that can unmute it.

```typescript
// src/init.ts
init({
  supportsSound: true, // unmutes playback; pair with audioOptions in main.ts
});

// src/main.ts
preferencesModel: new PreferencesModel({
  audioOptions: {
    supportsSound: true, // initializes tambo; pair with init.ts
  },
}),
```

A sim with no sound sets neither flag. `false` is the default; do not write `supportsSound: false` unless `audioOptions` is already present for another reason (voicing or custom audio controls) and sonification should stay off. In that case set `audioOptions.supportsSound: false` and leave `init` unset.

## Play a clip on an event

```typescript
import { SoundClip, soundManager } from "scenerystack/tambo";
import collisionSound from "../../sounds/collision_mp3.js";   // tambo's asset import shape

const collisionClip = new SoundClip(collisionSound, { initialOutputLevel: 0.5 });
soundManager.addSoundGenerator(collisionClip);

// later, in response to a model event:
model.collisionEmitter.addListener(() => collisionClip.play());
```

Audio assets are imported as pre-decoded buffers (the `*_mp3.js`/`*_wav.js` modules generated for the sim), not as URLs. Keep them under a `sounds/` folder following the sim's existing layout.

## Sonify a changing value

To map a continuous quantity to pitch/volume, drive a clip's playback rate from a Property and play on change. A `SoundClip` set to loop can track a value continuously:

```typescript
const pitchClip = new SoundClip(toneSound, { loop: true, initialOutputLevel: 0.3 });
soundManager.addSoundGenerator(pitchClip);

model.frequencyProperty.link((frequency) => {
  pitchClip.setPlaybackRate(frequencyToPlaybackRate(frequency));   // map Hz → rate
});

model.isPlayingProperty.link((playing) => { playing ? pitchClip.play() : pitchClip.stop(); });
```

For richer continuous sonification, subclass `SoundGenerator`; for one-shot feedback, `SoundClip` is enough.

## The audio Preferences tab

A sim that ships sound exposes it through the Preferences dialog's **Audio** tab. The master sound toggle is built in; add sim-specific sound controls in an `*AudioPreferencesNode.ts` (see the multi-tab split in scenerystack-preferences — e.g. OscillationsAndChaos uses a dedicated `…AudioPreferencesNode.ts`). Gate optional generators on their own `BooleanProperty` from the preferences model:

```typescript
soundManager.addSoundGenerator(uiClick, { associatedViewNode: someNode });
preferences.uiSoundsEnabledProperty.link((enabled) => uiClick.setOutputLevel(enabled ? 0.5 : 0));
```

## Rules

- Set `supportsSound: true` in both `src/init.ts` and `audioOptions`. One flag does not cover the other.
- Register every generator with `soundManager.addSoundGenerator(...)`; don't touch the Web Audio API directly.
- Sound is an enhancement, never required for understanding — the sim must be fully usable muted.
- Import audio as the generated buffer module (`name_mp3.js`), not a file path or `<audio>` URL.
- Reuse one `SoundClip` instance and call `play()` repeatedly; don't construct a clip per event.
- A generator created for a dynamic object must be removed with `soundManager.removeSoundGenerator(...)` and disposed (see scenerystack-disposal).
- Keep mappings (value → playback rate, output levels) in `*Constants.ts`, not inline magic numbers.

## Common mistakes

- Setting only `audioOptions.supportsSound` or only `init({ supportsSound })` → the sim launches, but clips stay muted or the navigation-bar speaker is disabled.
- Newing up `new Audio(...)` / `AudioContext` instead of going through tambo → bypasses the master toggle and the audio graph.
- A looping `SoundClip` that is `play()`ed but never `stop()`ped when the sim pauses → drone that ignores play/pause.
- Creating a new clip on every collision → GC churn and overlapping voices; reuse one clip.
- Sim-critical information conveyed by sound only → fails accessibility.
- Per-object generators that are never removed from `soundManager` → leak (see scenerystack-disposal).

Related skills: scenerystack-preferences, scenerystack-disposal, scenerystack-model.
