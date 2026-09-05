# Beckify API (`api.beckify.com`)

Express vision + review service. **Root Directory on Vercel must be `artifacts/api-server`.**

Registered POST routes (must be present after every production deploy):

- `/api/analyze-look`
- `/api/analyze-nameplate`
- `/api/analyze-panel`
- `/api/analyze-tdr`
- `/api/review-calculation`

`GET /api/healthz` returns `status: "ok"` plus that route list.

GitHub Pages (`https://beckify.com`) cannot accept these POSTs (`405`). Clients must use `https://api.beckify.com`.

## Local

```bash
pnpm --filter @workspace/api-server run typecheck
pnpm --filter @workspace/api-server run smoke
PORT=5000 pnpm --filter @workspace/api-server run dev
```

`smoke` starts the bundled app and dry-POSTs `{}` to each vision route. Pass = **400** (missing image), fail = Express **Cannot POST**.

Vision keys (`OPENAI_API_KEY` or `ANTHROPIC_API_KEY`) are optional for the 400 smoke. A real photo without a key returns **503** with an honest missing-key message.

## Production is stale until Trevor redeploys

Live `https://api.beckify.com` (checked 2026-09-05) is a Vercel Express app that still only has `/api/healthz` and `/api/analyze-tdr`. Look / nameplate / panel return `Cannot POST` because that Vercel project was last published from the TDR-only snapshot, not current `main`.

This repo **cannot** push a Vercel production deploy (no `VERCEL_TOKEN` in GitHub Actions). Merge of this PR does **not** update `api.beckify.com` until someone hits Redeploy.

### Vercel (this is what serves `api.beckify.com`)

1. Open the Vercel project whose Production URL is `https://api.beckify.com`.
2. Settings → General:
   - **Root Directory** = `artifacts/api-server`
   - Framework = Other / Express
   - Production branch = `main`
3. Settings → Git: GitHub repo `becktj90/beckify` connected, **auto-deploy Production on push to `main`**.
4. Settings → Environment Variables (Production): `OPENAI_API_KEY` and/or `ANTHROPIC_API_KEY`. Optional: `NAMEPLATE_VISION_PROVIDER`, `NAMEPLATE_VISION_MODEL`, `TDR_VISION_PROVIDER`, `TDR_VISION_MODEL`, `CORS_ORIGINS`.
5. Deployments → select the latest `main` deployment (or **Create Deployment** from `main`) → **Redeploy**. Do not reuse an old TDR-only build.
6. Verify (must be **400 JSON**, not HTML `Cannot POST`):

```bash
curl -sS -D - -X POST https://api.beckify.com/api/analyze-look \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Expected: `HTTP/2 400` and `{"error":"Provide a base64 image string in \`base64Image\` or \`imageBase64\`."}`

Also:

```bash
curl -sS https://api.beckify.com/api/healthz
```

Expected: `routes.post` includes `/api/analyze-look`.

If Git is connected, the next push to `main` after this merge should build a new Production deployment automatically. If it does not, auto-deploy is off — use Redeploy once, then turn auto-deploy on.

### Replit (only if you also host the API there)

Production traffic today is **Vercel**, not Replit. If a Replit Autoscale service is still pointed at `api.beckify.com`, republish from latest `main`:

1. Pull `main`.
2. `pnpm --filter @workspace/api-server run build`
3. Run `node --enable-source-maps artifacts/api-server/dist/index.mjs` with `PORT` and the vision keys.
4. Repeat the same `curl` checks.

`.replit-artifact/artifact.toml` already builds this package and health-checks `/api/healthz`.
