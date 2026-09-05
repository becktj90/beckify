# New Glenn Runner storage keys

The Phaser 4 runner owns settings, NG-n unlocks, and personal bests.

| Key | Engine | Notes |
| --- | --- | --- |
| `newGlennRunnerSettingsV2` | Canvas (legacy) | Early settings blob. Read once, never written. |
| `newGlennRunnerStateV3` | Canvas Jacklyn / feel pass | Scores and prefs. Read once, never written by Phaser. |
| `newGlennRunnerStateV4` | Phaser 4 first vertical slice | Scores and prefs. Read once, never written after V5. |
| `newGlennRunnerStateV5` | Phaser 4 NG-n missions | Unlocks and per-mission bests. Read once, never written after V6. |
| `newGlennRunnerStateV6` | **Phaser 4 (current)** | SFX/music volume split, control hints, sequence HUD. Migrates hi-score, last score, difficulty, mute/motion/haptics, mission count, unlocks, and best-flight summary from V5/V4/V3/V2 on first launch. |

V6 does **not** delete older keys, so a leftover canvas bookmark can still see its own record. After migration, new flights only update V6.

Audio prefs (`sound`, `music`, `muted`, `volume` 0–1, `sfxVolume` 0–1, `musicVolume` 0–1) live on the same V6 blob. Mute is the master switch and stays in lockstep with Settings → Sound (`muted === !sound`); `prefers-reduced-motion` does not mute. `launchTipSeen` dismisses the one-line tip under LAUNCH after the first flight.

Unlock rule: finishing Jacklyn (soft recover, salvage, or splash — not RUD) unlocks the next NG-n. Difficulty stays KID / CADET / PAD RAT *inside* a flight.

`recordGameScore('new-glenn-runner', points)` still writes the toolbox cross-game best via `local-store.js`.
