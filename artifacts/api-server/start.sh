#!/bin/sh
# Starts the API. With VOICE_ENGINE_LOCAL=1 it also keeps the free voice engine running on
# 127.0.0.1:8090 (not exposed). If the engine is down, Crew Talk speak returns 503 and the
# app plays its on-device voice instead.
set -e
if [ "${VOICE_ENGINE_LOCAL:-0}" = "1" ]; then
  (
    while true; do
      /opt/voice/bin/python ./voice-engine/server.py || true
      echo "voice-engine exited; restarting in 3s" >&2
      sleep 3
    done
  ) &
fi
exec node --enable-source-maps ./dist/index.mjs
