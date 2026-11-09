# syntax=docker/dockerfile:1
# Beckify API (artifacts/api-server) for Fly.io / Docker.
# Builds the esbuild bundle (dist/index.mjs) and runs it with Node 20.
# Optionally runs the free voice engine next to it (VOICE_ENGINE_LOCAL=1).

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

FROM node:${NODE_VERSION}-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080

# Free Crew Talk voice engine (Kokoro-82M, Apache-2.0). See docs/crew-voice-engine.md.
# Installed in the image, but it only starts when VOICE_ENGINE_LOCAL=1, because it needs
# about 700 MB of RAM (the 256 MB machine in fly.toml is too small for it).
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 python3-venv curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY voice-engine/requirements.txt voice-engine/fetch-models.sh voice-engine/server.py ./voice-engine/
RUN python3 -m venv /opt/voice \
  && /opt/voice/bin/pip install --no-cache-dir -r ./voice-engine/requirements.txt \
  && sh ./voice-engine/fetch-models.sh ./voice-engine/models

# Bundled output is self-contained (express/cors/pino inlined by esbuild).
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
COPY start.sh ./

USER node
EXPOSE 8080

CMD ["sh", "./start.sh"]
