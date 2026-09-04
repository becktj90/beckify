# New Glenn Runner storage keys

The Phaser 4 runner owns settings, NG-n unlocks, and personal bests.

| Key | Engine | Notes |
| --- | --- | --- |
| `newGlennRunnerSettingsV2` | Canvas (legacy) | Early settings blob. Read once, never written. |
| `newGlennRunnerStateV3` | Canvas Jacklyn / feel pass | Scores and prefs. Read once, never written by Phaser. |
| `newGlennRunnerStateV4` | Phaser 4 first vertical slice | Scores and prefs. Read once, never written after V5. |
| `newGlennRunnerStateV5` | **Phaser 4 (current)** | NG-n flight unlocks, payload identity, per-mission bests. Migrates hi-score, last score, difficulty, mute/motion/haptics, mission count, and best-flight summary from V4/V3/V2 on first launch. |

V5 does **not** delete older keys, so a leftover canvas bookmark can still see its own record. After migration, new flights only update V5.

Unlock rule: finishing Jacklyn (soft recover, salvage, or splash — not RUD) unlocks the next NG-n. Difficulty stays KID / CADET / PAD RAT *inside* a flight.

`recordGameScore('new-glenn-runner', points)` still writes the toolbox cross-game best via `local-store.js`.
