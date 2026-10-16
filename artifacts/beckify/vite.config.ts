import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";
import runtimeErrorOverlay from "@replit/vite-plugin-runtime-error-modal";

// PORT only configures the dev/preview server, so it must not block a build.
// Requiring it unconditionally made `npm run build` fail on a clean checkout.
const rawPort = process.env.PORT;
const port = rawPort ? Number(rawPort) : 3000;

if (rawPort && (Number.isNaN(port) || port <= 0)) {
  throw new Error(`Invalid PORT value: "${rawPort}"`);
}

const basePath = process.env.BASE_PATH;

/** Vite's SPA fallback serves index.html for /toolbox/classic/ in dev.
 *  GitHub Pages already maps that directory to classic/index.html. */
function serveClassicToolboxIndex() {
  const rewrite = (req: { url?: string }) => {
    if (!req.url) return;
    const queryAt = req.url.indexOf("?");
    const path = queryAt === -1 ? req.url : req.url.slice(0, queryAt);
    if (path !== "/toolbox/classic" && path !== "/toolbox/classic/") return;
    const search = queryAt === -1 ? "" : req.url.slice(queryAt);
    req.url = `/toolbox/classic/index.html${search}`;
    (req as { originalUrl?: string }).originalUrl = req.url;
  };
  return {
    name: "serve-classic-toolbox-index",
    configureServer(server: { middlewares: { use: (fn: (req: { url?: string }, res: unknown, next: () => void) => void) => void } }) {
      server.middlewares.use((req, _res, next) => {
        rewrite(req);
        next();
      });
    },
    configurePreviewServer(server: { middlewares: { use: (fn: (req: { url?: string }, res: unknown, next: () => void) => void) => void } }) {
      server.middlewares.use((req, _res, next) => {
        rewrite(req);
        next();
      });
    },
  };
}

if (!basePath) {
  throw new Error(
    "BASE_PATH environment variable is required but was not provided.",
  );
}

export default defineConfig({
  base: basePath,
  plugins: [
    serveClassicToolboxIndex(),
    react(),
    tailwindcss(),
    runtimeErrorOverlay(),
    ...(process.env.NODE_ENV !== "production" &&
    process.env.REPL_ID !== undefined
      ? [
          await import("@replit/vite-plugin-cartographer").then((m) =>
            m.cartographer({
              root: path.resolve(import.meta.dirname, ".."),
            }),
          ),
          await import("@replit/vite-plugin-dev-banner").then((m) =>
            m.devBanner(),
          ),
        ]
      : []),
  ],
  resolve: {
    alias: {
      "@": path.resolve(import.meta.dirname, "src"),
      "@assets": path.resolve(import.meta.dirname, "..", "..", "attached_assets"),
    },
    dedupe: ["react", "react-dom"],
  },
  root: path.resolve(import.meta.dirname),
  build: {
    outDir: path.resolve(import.meta.dirname, "dist/public"),
    emptyOutDir: true,
  },
  server: {
    port,
    strictPort: true,
    host: "0.0.0.0",
    allowedHosts: true,
    fs: {
      strict: true,
    },
  },
  preview: {
    port,
    host: "0.0.0.0",
    allowedHosts: true,
  },
});
