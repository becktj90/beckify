import { Router, type IRouter } from "express";
import {
  buildSharePayload,
  sharePageURL,
  signShareToken,
  toolTitle,
  validateShareInput,
  verifyShareToken,
} from "../lib/shareToken.js";

const router: IRouter = Router();
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_CREATE_PER_WINDOW = 20;
const MAX_READ_PER_WINDOW = 120;
const buckets = new Map<string, { count: number; resetAt: number }>();

function shareSecret(): string | null {
  const secret = process.env["SHARE_HMAC_SECRET"] ?? "";
  return secret.length >= 16 ? secret : null;
}

function consume(clientKey: string, max: number) {
  const now = Date.now();
  const current = buckets.get(clientKey);
  const bucket = !current || current.resetAt <= now
    ? { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS }
    : current;
  bucket.count += 1;
  buckets.set(clientKey, bucket);
  if (buckets.size > 10_000) {
    for (const [key, value] of buckets) {
      if (value.resetAt <= now) buckets.delete(key);
    }
  }
  return { allowed: bucket.count <= max, resetAt: bucket.resetAt };
}

router.post("/share", (req, res) => {
  const checked = validateShareInput(req.body);
  if (!checked.ok) return res.status(400).json({ error: checked.error });

  const secret = shareSecret();
  if (!secret) return res.status(503).json({ error: "Link hosting is unavailable." });

  const clientKey = `post:${req.ip || req.socket.remoteAddress || "unknown"}`;
  const bucket = consume(clientKey, MAX_CREATE_PER_WINDOW);
  if (!bucket.allowed) {
    res.setHeader("Retry-After", String(Math.ceil((bucket.resetAt - Date.now()) / 1000)));
    return res.status(429).json({ error: "Too many share links. Please try again later." });
  }

  try {
    const payload = buildSharePayload(checked);
    const token = signShareToken(payload, secret);
    return res.status(200).json({
      url: sharePageURL(token),
      tool: payload.tool,
      title: toolTitle(payload.tool),
    });
  } catch {
    return res.status(400).json({ error: "Invalid calculation snapshot." });
  }
});

router.get("/share/:token", (req, res) => {
  const token = req.params.token;
  if (typeof token !== "string" || token.length > 8_000) {
    return res.status(404).json({ error: "Share link not found." });
  }
  const secret = shareSecret();
  if (!secret) return res.status(503).json({ error: "Link hosting is unavailable." });

  const clientKey = `get:${req.ip || req.socket.remoteAddress || "unknown"}`;
  const bucket = consume(clientKey, MAX_READ_PER_WINDOW);
  if (!bucket.allowed) {
    res.setHeader("Retry-After", String(Math.ceil((bucket.resetAt - Date.now()) / 1000)));
    return res.status(429).json({ error: "Too many share reads. Please try again later." });
  }

  const payload = verifyShareToken(token, secret);
  if (!payload) return res.status(404).json({ error: "Share link not found." });
  res.setHeader("Cache-Control", "public, max-age=300");
  return res.json({
    tool: payload.tool,
    title: toolTitle(payload.tool),
    contractor: payload.contractor,
    createdAt: payload.createdAt,
    fields: payload.fields,
  });
});

export default router;
