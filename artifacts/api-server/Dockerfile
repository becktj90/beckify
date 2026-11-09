# syntax=docker/dockerfile:1
# Beckify API (artifacts/api-server) for Fly.io / Docker.
# Builds the esbuild bundle (dist/index.mjs) and runs it with Node 20.
# The optional voice-engine image is a separate target (voice-runtime), not built by default.

ARG NODE_VERSION=20.19.0

FROM node:${NODE_VERSION}-slim AS build
WORKDIR /app

COPY package.json ./
# No package-lock in this package (monorepo uses root pnpm-lock). npm install
# is deterministic enough for this small Express surface; prefer lock later.
RUN npm install --legacy-peer-deps

COPY build.mjs tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:${NODE_VERSION}-slim AS base-runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080

# Bundled output is self-contained (express/cors/pino inlined by esbuild).
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

USER node
EXPOSE 8080

CMD ["node", "--enable-source-maps", "./dist/index.mjs"]

# OPTIONAL, NOT BUILT BY DEFAULT: free Crew Talk voice engine (Kokoro-82M, Apache-2.0).
# Off after a listening test; see docs/crew-voice-engine.md. Build it only with
# `docker build --target voice-runtime` (or fly.toml [build] build-target = 'voice-runtime'),
# then set VOICE_ENGINE_LOCAL=1 and CREW_VOICE_PROVIDER=kokoro. Needs about 700 MB more RAM.
FROM base-runtime AS voice-runtime
USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 python3-venv curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY voice-engine/requirements.txt voice-engine/fetch-models.sh voice-engine/server.py ./voice-engine/
RUN python3 -m venv /opt/voice \
  && /opt/voice/bin/pip install --no-cache-dir -r ./voice-engine/requirements.txt \
  && sh ./voice-engine/fetch-models.sh ./voice-engine/models
COPY start.sh ./
USER node
CMD ["sh", "./start.sh"]

# Default image (last stage): identical to the pre-engine runtime. No Python, no model.
FROM base-runtime AS runtime
