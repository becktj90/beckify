#!/usr/bin/env bash
# Vendors the newest successful "WebGL build" artifact from becktj90/kestrel-heavy main into the site demo.
# Usage: tools/sync-kestrel-web.sh [run_id]   (needs gh + GH_TOKEN). Prints changed=true/false to $GITHUB_OUTPUT.
set -euo pipefail
SRC=becktj90/kestrel-heavy
DEST=artifacts/beckify/public/arcade/kestrel-heavy
TSX=artifacts/beckify/src/components/games/KestrelHeavy.tsx
STAMP=$DEST/.kestrel-run
out() { echo "$1" >> "${GITHUB_OUTPUT:-/dev/null}"; }

RUN=${1:-$(gh run list -R $SRC -w "WebGL build" -b main -s success -L 20 --json databaseId,event \
  -q '[.[]|select(.event=="workflow_dispatch" or .event=="push")][0].databaseId')}
[ -n "$RUN" ] && [ "$RUN" != null ] || { echo "no successful run found"; out changed=false; exit 0; }
SHA=$(gh run view "$RUN" -R $SRC --json headSha -q .headSha)
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$RUN" ]; then echo "already at run $RUN"; out changed=false; exit 0; fi
# Never go backwards: only sync if newer than the stamped run
if [ -f "$STAMP" ] && [ "$RUN" -le "$(cat "$STAMP")" ]; then echo "run $RUN older than stamp"; out changed=false; exit 0; fi

T=$(mktemp -d)
gh run download "$RUN" -R $SRC -n webgl-build -D "$T"
[ -d "$T/WebGL" ] && T="$T/WebGL"
for k in loader.js framework.js.unityweb wasm.unityweb data.unityweb; do
  ls "$T"/Build/*."$k" >/dev/null || { echo "artifact missing *.$k"; exit 1; }
done
rm -rf "$DEST/Build" "$DEST/StreamingAssets"
cp -r "$T/Build" "$DEST/Build"
[ -d "$T/StreamingAssets" ] && cp -r "$T/StreamingAssets" "$DEST/StreamingAssets"
for k in loader.js framework.js.unityweb wasm.unityweb data.unityweb; do
  new=$(basename "$T"/Build/*."$k")
  sed -E -i "s#[0-9a-f]{32}\.${k//./\\.}#${new}#" "$DEST/index.html"
done
grep -q "$(basename "$T"/Build/*.loader.js)" "$DEST/index.html"
cur=$(grep -oE 'unity-[0-9]+' "$TSX" | head -1 | cut -d- -f2)
sed -i "s/unity-$cur/unity-$((cur+1))/" "$TSX"
echo "$RUN" > "$STAMP"
echo "$SHA" > "$DEST/.kestrel-sha"
out changed=true; out run="$RUN"; out sha="${SHA:0:8}"
