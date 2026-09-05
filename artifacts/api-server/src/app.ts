import express, { type Express } from "express";
import cors from "cors";
import pinoHttp from "pino-http";
import router from "./routes/index.js";
import { logger } from "./lib/logger.js";

const app: Express = express();

// Vercel terminates the client connection at a trusted proxy. Preserve the
// client IP there so per-client abuse controls do not collapse into one bucket.
app.set("trust proxy", process.env["VERCEL"] ? 1 : false);

const defaultCorsOrigins = [
  "https://beckify.com",
  "https://www.beckify.com",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
];
const corsOrigins = new Set(
  (process.env["CORS_ORIGINS"] ?? defaultCorsOrigins.join(","))
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
);

app.disable("x-powered-by");
app.use((_req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Referrer-Policy", "no-referrer");
  next();
});

app.use(
  pinoHttp({
    logger,
    serializers: {
      req(req) {
        return {
          id: req.id,
          method: req.method,
          url: req.url?.split("?")[0],
        };
      },
      res(res) {
        return {
          statusCode: res.statusCode,
        };
      },
    },
  }),
);
app.use(cors({
  // iOS URLSession sends no Origin — allow those requests.
  // Safari on beckify.com sends Origin: https://beckify.com (allow-listed).
  origin(origin, callback) {
    callback(null, !origin || corsOrigins.has(origin));
  },
  methods: ["GET", "POST"],
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400,
}));
// Keep the large parser scoped to the image endpoint. Other routes do not need
// multi-megabyte request bodies and should reject oversized JSON early.
app.use("/api/analyze-tdr", express.json({ limit: "12mb" }));
app.use("/api/analyze-nameplate", express.json({ limit: "12mb" }));
app.use("/api/analyze-panel", express.json({ limit: "12mb" }));
app.use("/api/analyze-look", express.json({ limit: "12mb" }));
app.use(express.json({ limit: "64kb" }));
app.use(express.urlencoded({ extended: true, limit: "64kb" }));

app.use("/api", router);

export default app;
