# Beckify API (`api.beckify.com`)

Express vision + review service.

**Production path:** [Fly.io](https://fly.io) (`artifacts/api-server/fly.toml`). Vercel config is kept for rollback but is no longer the intended host for `api.beckify.com`.

Registered POST routes (must be present after every production deploy):

- `/api/analyze-look`
- `/api/analyze-nameplate`
- `/api/analyze-panel`
- `/api/analyze-tdr`
- `/api/review-calculation`
- `/api/translate`
- `/api/speak`

`GET /api/healthz` returns `status: "ok"` plus that route list.

GitHub Pages (`https://beckify.com`) cannot accept these POSTs (`405`). Clients must use `https://api.beckify.com`.

### `POST /api/analyze-look` roast modes

Body (existing clients unchanged):

```json
{
  "imageBase64": "data:image/jpeg;base64,…",
  "mimeType": "image/jpeg",
  "task": "look",
  "roastMode": "mean"
}
```

`roastMode` is `mean` | `nice` | `bro`. Omitted, blank, or unknown values default to **`bro`** (short BroGPT one-liner used by the website and Beckify Toolbox). The standalone **Look Check** iOS app (`com.beckify.lookcheck`) secretly coins `mean` or `nice` on each Analyze for a longer, exaggerated roast (several sentences) and does not show the choice. Safety rails are the same in every mode: anyone who appears under 18 is `declined` with no roast and no appearance rating; no sexual/graphic content; no race, disability, or body-shaming. Success JSON includes `roastMode` next to `analysis`.

After merge, Fly auto-deploys when `artifacts/api-server` changes (needs `FLY_API_TOKEN`). Old clients that omit `roastMode` keep the BroGPT prompt.

### `POST /api/translate`

Text translation for the Toolbox **Spanish Translator** tool. Omitting languages stays **English → Spanish** (`sourceLanguage` defaults to `en`, `targetLanguage` defaults to `es`). Optional `voiceMode`: `jobsite` or `clean`.

- **en → es** (default): Jobsite is rough banter (short attention seeds lean oye/mira/espérate); Clean is polished. Body: `{ "text": "…", "sourceLanguage": "en", "targetLanguage": "es", "voiceMode": "jobsite" }`. Success `targetLanguage` is `es`.
- **es → en**: spoken Spanish (including Cuban / Florida LatAm / jobsite) into English. Jobsite English is blunt and matches the energy without adding hate speech. Clean English is clear and does not amplify cussing. Body: `{ "text": "…", "sourceLanguage": "es", "targetLanguage": "en", "voiceMode": "jobsite" }`. `es-US` / `en-US` are accepted. Success `targetLanguage` is `en` and `dialect` is `english_jobsite` or `english_clean` (no geographic branding).

Same JSON shape either way: `translation`, `dialect`, `notes`, `voiceMode`, `sourceText`, `sourceLanguage`, `targetLanguage`. Uses `OPENAI_API_KEY` (optional `TRANSLATE_MODEL`, defaults to `REVIEW_MODEL` or `gpt-4o-mini`). Empty body → **400**. Any other pair (for example `fr`, or Spanish → Spanish) → **400**.

### `POST /api/speak`

Short text → OpenAI neural TTS audio (`audio/mpeg` by default, or `audio/wav`). Body: `{ "text": "…", "voice": "onyx", "format": "mp3", "language": "es" }`. `language` defaults to **es** (Spanish delivery). Pass `"language": "en"` (or `en-*`) for English playback on the reverse translator path (chill California surfer-stoner male delivery on **onyx**); omitted or Spanish tags keep the Spanish instructions. Defaults: model **gpt-4o-mini-tts**; Spanish voice **onyx** Jobsite / **nova** Clean; English always **onyx** with surfer-stoner `instructions` (override with `TTS_MODEL=tts-1` for cheaper clips without instructions). Caps input at **500** characters. Empty body → **400**. Used by Spanish Translator loud playback; Apple AVSpeech remains the on-device fallback (Spanish voice for es, English voice for en).

## Local

```bash
pnpm --filter @workspace/api-server run typecheck
pnpm --filter @workspace/api-server run smoke
PORT=5000 pnpm --filter @workspace/api-server run dev
```

`smoke` starts the bundled app and dry-POSTs `{}` to each vision route. Pass = **400** (missing image), fail = Express **Cannot POST**.

Vision keys (`OPENAI_API_KEY` or `ANTHROPIC_API_KEY`) are optional for the 400 smoke. A real photo without a key returns **503** with an honest missing-key message.

## Production: Fly.io (new path for `api.beckify.com`)

Cheap shared-CPU Machines with scale-to-zero. Config lives next to this package:

- `Dockerfile` — multi-stage Node 20 build → `dist/index.mjs`
- `fly.toml` — app name **`beckify-api`**, region `iad`, internal port `8080`, health check `GET /api/healthz`
- `artifacts/api-server/ci/fly-api-server.yml` — workflow source (copy to `.github/workflows/fly-api-server.yml` once; OAuth deploys cannot create workflow files without the `workflow` scope). Deploys on push to `main` only when `artifacts/api-server/**` (or the workflow) changes

### One-time setup (Trevor)

1. Install the Fly CLI and log in: https://fly.io/docs/hands-on/install-flyctl/
2. Create the app (name must match `fly.toml`):

   ```bash
   fly apps create beckify-api
   ```

3. From `artifacts/api-server`, set runtime secrets (never commit these):

   ```bash
   cd artifacts/api-server
   fly secrets set OPENAI_API_KEY=sk-...
   # optional:
   # fly secrets set ANTHROPIC_API_KEY=...
   # fly secrets set CORS_ORIGINS=https://beckify.com,https://www.beckify.com
   # fly secrets set TRANSLATE_MODEL=gpt-4o-mini
   # fly secrets set REVIEW_MODEL=gpt-4o-mini
   ```

4. First deploy (local CLI or wait for Actions after step 5):

   ```bash
   fly deploy --remote-only
   ```

5. Install the deploy workflow (one-time; GitHub blocks creating `.github/workflows/*` without the `workflow` OAuth scope):

   ```bash
   cp artifacts/api-server/ci/fly-api-server.yml .github/workflows/fly-api-server.yml
   git add .github/workflows/fly-api-server.yml
   git commit -m "ci(api): enable Fly.io deploy workflow"
   git push
   ```

6. Add the GitHub Actions secret (repo Settings → Secrets and variables → Actions):

   - Name: **`FLY_API_TOKEN`**
   - Value: output of `fly tokens create deploy -x 999999h` (include the `FlyV1 ` prefix)
   - Do **not** paste the token into the PR or commit it

7. Point DNS **`api.beckify.com`** at Fly (see root `README.md` cutover). Verify:

   ```bash
   curl -sS https://api.beckify.com/api/healthz
   curl -sS -D - -X POST https://api.beckify.com/api/analyze-look \
     -H 'Content-Type: application/json' -d '{}'
   ```

   Expected healthz: `status: "ok"` and `routes.post` includes `/api/analyze-look`.  
   Expected empty look POST: **400** JSON (not HTML `Cannot POST`).

### Environment variables

| Variable | Required | Notes |
|---|---|---|
| `OPENAI_API_KEY` | Yes (for vision / translate / speak / review) | Set via `fly secrets set` |
| `ANTHROPIC_API_KEY` | Optional | Alternate vision provider |
| `CORS_ORIGINS` | Optional | Comma-separated; defaults include `https://beckify.com` |
| `TRANSLATE_MODEL` | Optional | Defaults to `REVIEW_MODEL` or `gpt-4o-mini` |
| `REVIEW_MODEL` | Optional | Defaults to `gpt-4o-mini` |
| `PORT` | Set by Fly | `8080` in `fly.toml`; do not override unless you change the service port |
| `NODE_ENV` | Set by Fly | `production` |
| `NAMEPLATE_VISION_PROVIDER` / `NAMEPLATE_VISION_MODEL` | Optional | Nameplate route |
| `TDR_VISION_PROVIDER` / `TDR_VISION_MODEL` | Optional | TDR route |
| `LOG_LEVEL` | Optional | Defaults to `info` |

`FLY_APP_NAME` is injected by Fly (used to enable `trust proxy`).

### Vercel (kept for rollback — not the new production path)

Vercel project docs stay so we can roll back if needed. **Do not delete `vercel.json` yet.**

1. Open the Vercel project that previously served `https://api.beckify.com`.
2. Settings → General:
   - **Root Directory** = `artifacts/api-server`
   - Framework = Other / Express
   - Production branch = `main`
3. Settings → Environment Variables (Production): same keys as the Fly table above.
4. After DNS cutover to Fly, leave the Vercel project idle (or disconnect the custom domain) so it does not fight Fly for `api.beckify.com`.

### Replit (legacy only)

If a Replit Autoscale service is still pointed at this package:

1. Pull `main`.
2. `pnpm --filter @workspace/api-server run build`
3. Run `node --enable-source-maps artifacts/api-server/dist/index.mjs` with `PORT` and the vision keys.
4. Repeat the same `curl` checks.

`.replit-artifact/artifact.toml` already builds this package and health-checks `/api/healthz`.
