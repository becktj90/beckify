# New Glenn Runner audio attribution

Arcade clips are **short trims** (about 0.4–3.4 s) of NASA public mission audio, plus a few tiny generated one-shots. No Blue Origin, commercial trailer, or YouTube rips.

NASA material is used under NASA’s media usage guidelines. **No NASA endorsement is implied.** No extra permission is required when those guidelines are followed.

- Artemis Audio Library: https://www.nasa.gov/artemisaudio/
- Historical Sounds: https://www.nasa.gov/historical-sounds/
- Media usage guidelines: https://www.nasa.gov/nasa-brand-center/images-and-media/

| Game file | Source | Source URL | Notes |
| --- | --- | --- | --- |
| `roar-loop` | STS-131 Discovery launch nats (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/590189main_ringtone_131_launchNats.mp3 | ~1.85 s roar loop from mid-clip |
| `liftoff` | Artemis II Launch: Liftoff (Artemis Audio Library) | https://www.nasa.gov/wp-content/uploads/2026/01/artemis-ii-liftoff.mp3 | Trim of the launch roar, not the full broadcast |
| `maxq` | Discovery “Go at throttle up” (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/640150main_Go20at20Throttle20Up.mp3 | Near-full 1.7 s clip |
| `meco` | Discovery MECO (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/640166main_MECO.mp3 | First 2 s |
| `whoosh` | SLS static-fire / ops texture (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/663784main_SLS_Audio_D.mp3 | 1.6 s engine whoosh |
| `burn-loop` | SDO launch nats / Atlas-class roar (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/590329main_ringtone_SDO_launchNats.mp3 | ~1.7 s landing-burn bed |
| `touchdown` | STS-132 landing gear drop (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/590327main_ringtone_landingGearDrop.mp3 | Mechanical ops, not voice |
| `recovered` | Apollo 11 “Eagle has landed” (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/569462main_eagle_has_landed.mp3 | Short success sting |
| `splash` | Artemis I splashdown (Artemis Audio Library) | https://www.nasa.gov/wp-content/uploads/2026/01/artemis-i-audio-splashdown-orion-back-on-earth-1.mp3 | Water/ops texture, not the full show |
| `quindar` | Quindar tone (Historical Sounds) | https://www.nasa.gov/wp-content/uploads/2015/01/578628main_hskquindar.mp3 | First ~0.45 s for UI select |
| `pickup` `hit` `rud` | Generated in-repo (ffmpeg `aevalsrc`) | (this repository) | Procedural arcade juice; no third-party pack |

Each clip ships as `.ogg` and `.mp3` (22.05 kHz mono) so browsers can pick one. Total audio budget is well under 1 MB.
