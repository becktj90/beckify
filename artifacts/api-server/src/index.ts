import app from "./app.js";
import { logger } from "./lib/logger.js";

export default app;

// Vercel owns the HTTP listener for serverless deployments. Keep the listener
// for local and long-running service deployments (Fly.io, Docker, Replit).
if (!process.env["VERCEL"]) {
  const rawPort = process.env["PORT"];

  if (!rawPort) {
    throw new Error(
      "PORT environment variable is required but was not provided.",
    );
  }

  const port = Number(rawPort);

  if (Number.isNaN(port) || port <= 0) {
    throw new Error(`Invalid PORT value: "${rawPort}"`);
  }

  // Bind all interfaces so container platforms (Fly.io) can reach the process.
  app.listen(port, "0.0.0.0", (err) => {
    if (err) {
      logger.error({ err }, "Error listening on port");
      process.exit(1);
    }

    logger.info({ port }, "Server listening");
  });
}
