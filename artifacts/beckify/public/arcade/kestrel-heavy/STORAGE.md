# Kestrel Heavy storage keys

The Phaser 4 runner owns settings, KH-n unlocks, hangar loadouts, and personal bests.

| Key | Engine | Notes |
| --- | --- | --- |
| `newGlennRunnerSettingsV2` | Canvas (legacy) | Early settings blob. Read once, never written. |
| `newGlennRunnerStateV3` | Canvas Haven / feel-pass | Scores and prefs. Read once, never written by Phaser. |
| `newGlennRunnerStateV4` | Phaser 4 first vertical slice | Scores and prefs. Read once, never written after V5. |
| `newGlennRunnerStateV5` | Phaser 4 KH-n missions | Unlocks and per-mission bests. Read once, never written after V6. |
| `newGlennRunnerStateV6` | Phaser 4 sequence HUD | SFX/music split, control hints. Read once, never written after V7. |
| `newGlennRunnerStateV7` | **Phaser 4 (current)** | Hangar loadouts + part unlocks + integrity. Migrates hi-score, last score, difficulty, mute/motion/haptics, mission count, unlocks, and best-flight summary from V6/V5/V4/V3/V2 on first launch. Legacy `NG-n` unlock ids remap to `KH-n`. |

V7 does **not** delete older keys, so a leftover canvas bookmark can still see its own record. After migration, new flights only update V7.

Audio prefs (`sound`, `music`, `muted`, `volume` 0–1, `sfxVolume` 0–1, `musicVolume` 0–1) live on the same V7 blob. Mute is the master switch and stays in lockstep with Settings → Sound (`muted === !sound`); `prefers-reduced-motion` does not mute. `launchTipSeen` dismisses the one-line tip under LAUNCH after the first flight.

Unlock rule: finishing Haven (soft recover, salvage, or splash — not RUD) unlocks the next KH-n. Hangar parts unlock from missions, recoveries, scores, and pickups. Difficulty stays KID / CADET / PAD RAT *inside* a flight.

`recordGameScore('kestrel-heavy', points)` still writes the toolbox cross-game best via `local-store.js`.
