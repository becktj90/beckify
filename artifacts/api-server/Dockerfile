# syntax=docker/dockerfile:1
# Beckify API (artifacts/api-server) for Fly.io / Docker.
# Builds the esbuild bundle (dist/index.mjs) and runs it with Node 20.

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

# Bundled output is self-contained (express/cors/pino inlined by esbuild).
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

USER node
EXPOSE 8080

CMD ["node", "--enable-source-maps", "./dist/index.mjs"]
