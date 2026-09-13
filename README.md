# Beckify

  Trevor Beck's personal engineering resource site — EE calculators, builds, and games.

  **Live site:** https://beckify.com
  **Stack:** React + Vite + Tailwind CSS · pnpm monorepo

  ## What's here

  - `artifacts/beckify/` — main site (bento grid home, toolbox, games, about, projects)
  - `artifacts/api-server/` — lightweight Express API
  - `artifacts/mockup-sandbox/` — canvas component preview server
  - `ios/` — native SwiftUI apps: **Beckify Toolbox** (`com.beckify.toolbox`), standalone **Look Check** (`com.beckify.lookcheck`), and standalone **Kestrel Heavy** (`com.beckify.kestrelheavy`). See `ios/README.md`, `ios/LookCheck/README.md`, and `ios/KestrelHeavy/README.md`. Toolbox Archive / Xcode Cloud stays on scheme **Beckify** only.

  ## Running locally

  ```bash
  pnpm install
  pnpm --filter @workspace/beckify run dev
  ```
