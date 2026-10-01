# Beckify

  Trevor Beck's personal engineering resource site — EE calculators, builds, and games.

  **Live site:** https://beckify.com
  **Stack:** React + Vite + Tailwind CSS · pnpm monorepo

  ## What's here

  - `artifacts/beckify/` — main site (bento grid home, toolbox, games, about, projects)
  - `artifacts/api-server/` — lightweight Express API
  - `artifacts/mockup-sandbox/` — canvas component preview server
  - `ios/` — native SwiftUI apps: **Beckify Toolbox** (`com.beckify.toolbox`), standalone **Look Check** (`com.beckify.lookcheck`), standalone **Kestrel Heavy** (`com.beckify.kestrelheavy`), and standalone **Beckify Drive** (`com.beckify.drive`, CarPlay + Bluetooth OBD). See `ios/README.md`. Toolbox Archive / Xcode Cloud stays on scheme **Beckify** only.

  ## Running locally

  ```bash
  pnpm install
  pnpm --filter @workspace/beckify run dev
  ```

## API (`api.beckify.com`)

Express vision + review + translate lives in `artifacts/api-server/`.

**Production host:** [Fly.io](https://fly.io) app **`beckify-api`** (see `artifacts/api-server/fly.toml` and that package’s README).  
Vercel config remains in-tree for rollback only; do not treat Vercel as the active production path after cutover.

### DNS cutover to Fly

After the Fly app is created, secrets are set, and `fly deploy` (or the GitHub Action) succeeds:

1. Confirm the app hostname works, e.g. `https://beckify-api.fly.dev/api/healthz`.
2. In your DNS provider for `beckify.com`, set **`api`** to Fly:
   - Preferred: CNAME `api` → `beckify-api.fly.dev` (or follow `fly certs add api.beckify.com` / dashboard instructions for A/AAAA).
   - Issue/attach the certificate: `fly certs add api.beckify.com` from `artifacts/api-server`.
3. Wait for DNS + cert, then verify:

   ```bash
   curl -sS https://api.beckify.com/api/healthz
   ```

4. In Vercel, remove or idle the custom domain `api.beckify.com` so only Fly answers that name.
5. Optional: add GitHub Actions secret **`FLY_API_TOKEN`** (`fly tokens create deploy -x 999999h`) so pushes that touch `artifacts/api-server/**` auto-deploy. See `artifacts/api-server/README.md`. Do not put the token in a PR or commit.
