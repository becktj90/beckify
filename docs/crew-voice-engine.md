# Crew Talk voice engine (no ElevenLabs)

Status: implemented in `artifacts/api-server` (Nov 9, 2026). It is **not deployed yet**; see "Turning it on".

Goal: Beckify needs no ElevenLabs for anything, and Crew Talk still gives every character a good, distinct voice. That includes dynamic text, because Crew Talk rewrites are generated live. Budget is $0 in API fees.

## Decision

Crew Talk now speaks through a **voice-engine provider abstraction** in `/api/speak`. The default provider is a **free, self-hosted Kokoro-82M engine** (`artifacts/api-server/voice-engine/`). The Apache-2.0 weights run on CPU through onnxruntime. It needs no key, makes no outbound calls and costs nothing per call.

- Each character has a server-side **voice profile** in `src/voice/crewVoices.ts`: a blend of Kokoro voice styles, a pace, a small formant-coupled pitch move, the language, and spoken-only pronunciation fixes. Client voice knobs are ignored.
- **Old app builds work unchanged.** Shipped iOS builds still send the old ElevenLabs voice ids and `model: eleven_v3`. Those ids are now just lookup keys that map to a character, and ElevenLabs is never called. New clients can send `crew: "<key>"` or `voice: "crew:<key>"`.
- The **dialect lives in the words.** Crew Talk rewrites already keep the full meaning and are written in each character's voice. The engine sets timbre, pace and energy. It does no accent imitation, no impressions of real people and no caricature.
- Output is **MP3 (or WAV)**, as before, so the app's playback, cache, Copy/Share and clip export need no change. The fp32 model is deterministic: the same line always gives the same audio. That means `X-Beckify-TTS-Cacheable: 1` holds, and draft PR #446's cache idea now works for free.
- **Fallbacks:**
  - If the engine is down, the route returns 503 and the app plays its on-device Apple voice. This path already existed.
  - ElevenLabs remains only as an **optional, paid, off-by-default** provider for rollback: `CREW_VOICE_PROVIDER=elevenlabs`, or `CREW_VOICE_FALLBACK=elevenlabs` to retry a failed engine call. Removing it would not break anything. It is kept only so a bad deploy can be reverted with one env var.
- The **Spanish Translator presets** (California, Cuban/South American, Deep South) stay on OpenAI by default, so their behavior is unchanged. `TRANSLATOR_VOICE_PROVIDER=kokoro` moves English and Spanish to the free engine. Japanese stays on OpenAI.

## Options considered

| Option | License | Fits dynamic text? | Verdict |
|---|---|---|---|
| **Kokoro-82M** via kokoro-onnx | Weights and voices Apache-2.0; kokoro-onnx MIT; onnxruntime MIT; phonemes via espeak-ng (GPL-3.0, used server-side only, not shipped in the app) | Yes, about 0.5x real time on 1 CPU | **Chosen.** Best quality for its size, 54 voices (EN-US, EN-GB, ES and more), and style blending gives distinct characters. |
| Piper (`piper-tts` 1.8 = piper1-gpl) | Engine GPL-3.0. Voices vary: `en_US-ryan` is CC BY-NC-SA (non-commercial, rejected); `en_US-lessac` uses the Blizzard 2013 research license (rejected); `es_MX-ald` Unlicense; `es_MX-claude` says Apache-2.0 but its dataset source is unclear | Yes, very fast (about 0.02x real time) | Runner-up. Fast and small, but few commercially clean voices, flatter prosody and no blending. Good for a Spanish backup voice if Kokoro's Spanish disappoints. |
| StyleTTS 2 | Code MIT; the pretrained model's terms require telling listeners the audio is synthetic unless you have voice permission | Yes, heavier than Kokoro | Not chosen. Kokoro is a smaller, faster derivative of this family. |
| F5-TTS | Code MIT; pretrained weights CC-BY-NC-4.0 | Needs GPU for speed | **Rejected** (non-commercial weights). |
| XTTS-v2 | Coqui Public Model License (non-commercial) | GPU preferred | **Rejected** (non-commercial). |
| Larger expressive models (0.5–3B, e.g. Chatterbox, Orpheus, Dia) | Various permissive | Need a GPU for live latency | Not fit for $0 CPU hosting. |
| Apple AVSpeechSynthesizer (premium/enhanced voices) | Free, on device, Apple SDK | Yes, offline | Kept as the **fallback**. Premium voices must be downloaded by the user in Settings; the app cannot fetch them. Few voices, and limited character range. |
| Apple Personal Voice | On device | Yes | Not usable for characters: it is only the user's own voice and needs their permission. |
| OpenAI TTS (already used by the translator) | Paid per call | Yes | Not free; kept for the translator by default. |
| Pre-rendered clips | n/a | **No** (rewrites are live) | Not viable for Crew Talk. |
| Kokoro **on device** (Core ML / MLX ports) | Apache-2.0 weights | Yes, offline | Best long-term $0 option, but adds about 80–330 MB to the app and needs Mac/device work. Phase 2 candidate. |

## Measurements (box: 8-core x86, no GPU)

Kokoro v1.0 fp32, per line of about 6–8 s of audio, measured through the real `/api/speak` → engine path:

| Setting | Time per line | Real-time factor |
|---|---|---|
| 8 threads | 0.7–1.2 s | ~0.14 |
| 2 threads | ~2 s | ~0.28 |
| **1 thread (pinned to one core, closest to Fly `shared-cpu-1x`)** | **2.5–4.3 s** | ~0.5 |

- **Memory:** engine RSS is about 650 MB (fp32). The int8 file uses about 440 MB, but its output duration wobbles from run to run (one run produced a 13 s clip for a 7 s line), so fp32 is the default.
- **Intelligibility:** checked by an automatic speech recognizer (Whisper small) transcribing every character sample. Word error rate was 0 for most lines. Misses were slang only ("asere", "Ay, bruh", "hella").
- Fly shared CPUs are burst-throttled, so real latency there may be worse than the pinned-core number. This is not measured on Fly.
- Samples and raw numbers live on the build box under `/workspace/crew-voice-eval/` (`final/*.wav|mp3`, `final/scores.json`, `final/timings*.json`).

## Character voice map

| Character | Kokoro blend | Pace | Pitch | Notes |
|---|---|---|---|---|
| Bodie Hale | am_puck 0.6 + am_fenrir 0.4 | 0.88 | −0.7 st | Laid-back California, low and a little rough |
| Junie Pell | af_bella 0.55 + af_nicole 0.45 | 0.80 | −1.0 st | Slow, thick, proud |
| Pearl | af_heart 0.7 + af_aoede 0.3 | 0.94 | −0.8 st | Warm woman in her 40s |
| Sloane Merritt | af_sarah 0.6 + af_kore 0.4 | 1.02 | +0.4 st | Bright, brisk meeting voice |
| Dre Lacey | am_michael 0.5 + am_onyx 0.5 | 1.06 | 0 | Loud, quick, energetic |
| Humberto (EN) | em_alex 0.6 + am_adam 0.4 | 0.88 | −1.2 st | Courteous; Spanish-speaker color from the style blend |
| Humberto (ES) | em_alex 0.75 + em_santa 0.25 | 0.88 | −1.2 st | Measured Caracas Spanish |
| Tito Solano | em_santa 0.6 + em_alex 0.4 | 0.90 | −2.2 st | Deep, weathered jobsite Spanish |
| Lupita Reyes | ef_dora | 0.96 | +0.3 st | Warm, bright Mexican Spanish |
| Cassian Vale | bm_george 0.6 + bm_fable 0.4 | 0.95 | 0 | Dry, arch roast host (no current app caller on main) |

Known gaps compared with the old voices:
- **No performed sound cues.** Audio tags such as `[coughs]`, `[cackles]` and `[laughs]` are stripped before synthesis, as the OpenAI path already did.
- **No true rasp or vocal fry.** Bodie's and Tito's roughness comes from blend and pitch only.
- **Kokoro has fewer Spanish voices** (1 female, 2 male) than English ones.

## Turning it on (Trevor)

Nothing is deployed. Today production still runs the old build.

1. Give the API machine enough memory. The engine needs about 700 MB more than the current 256 MB VM. Change `[[vm]] memory = '1gb'` in `fly.toml`, or run `fly scale memory 1024`.
   - **Cost** (Fly list price, `iad`): `shared-cpu-1x` 1 GB is **$6.70 per 30 days** if always on, versus $2.19 for 256 MB. That is up to **+$4.51/month**.
   - With `auto_stop_machines` it is billed per second while running, so it is usually less.
   - A stopped machine's rootfs is $0.15/GB/month, and the image grows by roughly 0.5 GB.
   - Two vCPUs (`shared-cpu-2x`, 2 GB) would halve latency for **$13.39 per 30 days** always-on.
   - This is new spend, so it is **Trevor's call**.
2. `fly secrets set VOICE_ENGINE_LOCAL=1` (not a secret, but it keeps env in one place). Or add it under `[env]`.
3. `fly deploy` from `artifacts/api-server`. The image downloads the pinned model files (checksummed) at build time.
4. Smoke test: `POST /api/speak {"text":"Kill the power.","crew":"bodieHale","language":"en"}`. Expect `X-Beckify-TTS-Provider: kokoro`.
5. Once happy, the `ELEVENLABS_API_KEY` secret can be removed. Its absence breaks nothing.

**If you deploy without step 1 or 2,** Crew Talk speak returns 503 and the app falls back to Apple voices. Nothing crashes, but voices sound plainer. To keep the old voices temporarily, set `CREW_VOICE_PROVIDER=elevenlabs` (paid).

A $0 hosting alternative is running the engine on any always-on free CPU host and pointing `VOICE_ENGINE_URL` and `VOICE_ENGINE_TOKEN` at it. Free hosts sleep and cold-start slowly, so it is not recommended for live chat.

## Follow-ups (not done here)

- **iOS copy.** `ios/docs/APP_STORE.md`, `ios/docs/PRIVACY.md`, `ios/README.md` and some Swift comments still say "ElevenLabs / eleven_v3". Update them **after** the deploy so they stay true. Less data now goes to third parties. No App Store privacy label changes are needed: Crew Talk speech text was already disclosed as leaving the device for `api.beckify.com`.
- **iOS cleanup** (optional): send `crew` instead of the legacy id. Crew Talk Conversation's Apple fallback (`CrewTalkSpeechOutput`) could pick the best installed voice and apply `applePitchMultiplier` the way the main Crew Talk screen already does.
- Phase 2: Kokoro on device for fully offline, $0, private playback.
