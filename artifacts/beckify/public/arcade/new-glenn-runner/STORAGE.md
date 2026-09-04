# New Glenn Runner storage keys

The Phaser 4 runner owns settings and personal bests.

| Key | Engine | Notes |
| --- | --- | --- |
| `newGlennRunnerSettingsV2` | Canvas (legacy) | Early settings blob. Read once, never written. |
| `newGlennRunnerStateV3` | Canvas Jacklyn / feel pass | Scores and prefs. Read once, never written by Phaser. |
| `newGlennRunnerStateV4` | **Phaser 4 (current)** | Migrates hi-score, last score, difficulty, mute/motion/haptics, mission count, and best-flight summary from V3/V2 on first launch. |

V4 does **not** delete V3/V2, so an old canvas bookmark can still see its own record. After migration, new flights only update V4.

`recordGameScore('new-glenn-runner', points)` still writes the toolbox cross-game best via `local-store.js`.
