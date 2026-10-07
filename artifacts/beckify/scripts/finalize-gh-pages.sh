#!/usr/bin/env bash
# Run from repo root after `pnpm --filter @workspace/beckify run build`.
# Writes CNAME and keeps the dedicated noindex 404.html from public/.
set -euo pipefail
DIST="artifacts/beckify/dist/public"
echo "beckify.com" > "$DIST/CNAME"
if [[ ! -s "$DIST/404.html" ]] || ! grep -qi 'noindex' "$DIST/404.html" || ! grep -qi 'Page not found' "$DIST/404.html"; then
  echo "error: $DIST/404.html must be the dedicated not-found page (public/404.html), not the app shell" >&2
  exit 1
fi
echo "finalize-gh-pages: CNAME written; 404.html looks correct"
