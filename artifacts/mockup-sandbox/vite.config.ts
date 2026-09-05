import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";
import runtimeErrorOverlay from "@replit/vite-plugin-runtime-error-modal";
import { mockupPreviewPlugin } from "./mockupPreviewPlugin";

function parsePort(rawPort: string | undefined, required: boolean): number {
  if (!rawPort) {
    if (required) {
      throw new Error(
        "PORT environment variable is required but was not provided.",
      );
    }
    return 8081;
  }

  const port = Number(rawPort);

  if (Number.isNaN(port) || port <= 0) {
    throw new Error(`Invalid PORT value: "${rawPort}"`);
  }

  return port;
}

function resolveBasePath(
  rawBasePath: string | undefined,
  required: boolean,
): string {
  if (!rawBasePath) {
    if (required) {
      throw new Error(
        "BASE_PATH environment variable is required but was not provided.",
      );
    }
    return "/__mockup";
  }

  return rawBasePath;
}

export default defineConfig(async ({ command }) => {
  // PORT / BASE_PATH are Replit preview-server settings. Requiring them at
  // module load made `vite build` fail on Vercel/CI where those vars are unset.
  const requirePreviewEnv = command === "serve";
  const port = parsePort(process.env.PORT, requirePreviewEnv);
  const basePath = resolveBasePath(process.env.BASE_PATH, requirePreviewEnv);

  return {
    base: basePath,
    plugins: [
      mockupPreviewPlugin(),
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
          ]
        : []),
    ],
    resolve: {
      alias: {
        "@": path.resolve(import.meta.dirname, "src"),
      },
    },
    root: path.resolve(import.meta.dirname),
    build: {
      outDir: path.resolve(import.meta.dirname, "dist"),
      emptyOutDir: true,
    },
    server: {
      port,
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
  };
});
