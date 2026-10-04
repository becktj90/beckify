# Crew Talk latency baseline (WP-0A)

Date: 2026-10-03 America/New_York (samples ran 20:27–20:43 ET).

Host: `https://api.beckify.com`. Confirmed from the iOS client (`SpanishTranslator` / `PhotoLookCheck` default base) and `artifacts/api-server/README.md` (Fly app `beckify-api`). Live `GET /api/healthz` returned 200 with `server: Fly` before the samples. This measurement does not deploy Fly.

## What this is

API segments only. It is **not** the D2 end-of-speech → partner-audio path (record stop, on-device rewrite, translate, speak, and playback).

D2 targets, for that full path: **p50 ≤ 3s** and **p95 ≤ 5s**. Do not read the tables below as a D2 pass or fail.

## Method

- 30 sequential client calls per series. No concurrency inside a series. No client think-time between successes.
- Directions the task measured: English → Spanish and Spanish → English. A short fixed fixture was used for every call. The fixture text is intentionally not copied here.
- Translate body matches the iOS `/api/translate` contract (`task`, `text`, `sourceText`, `sourceLanguage`, `targetLanguage`, `voiceMode` / `mode` = jobsite).
- Speak body matches the iOS Crew Talk `/api/speak` contract (short fixture, `eleven_v3`, one allowlisted voice, `language` en, `voiceMode` / `mode` = jobsite).
- Clock: client wall time from the start of the HTTPS request.
  - **Total:** until the response body ends.
  - **Speak TTFB (first byte):** until response headers arrive.
  - **Speak first body byte:** until the first response-body chunk. On this host it matched TTFB within about 1 ms, which is what a fully buffered audio response looks like.
- Percentile: nearest rank, `ceil(p / 100 * n)`, n = 30 successful responses. Times are milliseconds, rounded to 0.1 ms.
- Only HTTP 200 responses with a translation string (translate) or a non-empty audio body (speak) are in the percentiles.
- The text budget on the live host returned **429** once, after 40 successful translate calls in one window (30 en→es, then 10 es→en). The runner slept for the `Retry-After` (~871s) and retried that sample. The 429 is not in the table. The retried sample is included (4693.6 ms). That gap is long enough for Fly autostop (`min_machines_running = 0`), so the spike is consistent with a cold start. It is the max, not the p95.
- Speak: 30/30 HTTP 200, no 429, no pause. Speak overlapped the translate window in time but its own calls were sequential.
- These numbers are from **current production**. This PR’s server timing logs are not deployed.

## Results

| Series | Metric | n | min | p50 | p95 | max |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Translate en→es | total | 30 | 633.0 | 748.1 | 1228.7 | 2161.0 |
| Translate es→en | total | 30 | 560.7 | 610.2 | 1007.6 | 4693.6 |
| Speak | TTFB (first byte) | 30 | 563.7 | 686.0 | 852.1 | 910.4 |
| Speak | first body byte | 30 | 563.8 | 686.1 | 852.4 | 910.6 |
| Speak | total | 30 | 582.0 | 700.7 | 868.3 | 921.3 |

Every successful sample in these series was under 5s. p50 for each row is under 3s. That is still only the API segment, not D2.

## Server logs in this PR

`POST /api/translate` and `POST /api/speak` emit one pino `route_timing` info line when the response finishes:

- `route` (`/api/translate` or `/api/speak`)
- `outcome`: `ok`, `client_error`, `rate_limited`, `provider_error`, `unavailable`, `timeout`, or `error` (from the HTTP status)
- `duration_ms` (handler start → response finished)
- Speak only, when a provider audio chunk was read: `first_audio_chunk_ms` (handler start → first non-empty provider audio chunk)

The speak handler still buffers the full provider body and sends it with `Content-Length`. Status codes, JSON shapes, and headers are unchanged. Logs do not include request text, voice text, user ids, or API keys. Toolbox stays MARKETING 1.0.4 / CURRENT_PROJECT_VERSION 256. No version bump. No Fly deploy.
