import { Router, type IRouter, type Request, type Response } from "express";
import { getClientKey } from "../lib/visionClient.js";
import {
  normalizeRoomLanguage,
  roomStore,
  type RoomEvent,
} from "../lib/roomStore.js";

/**
 * Crew Talk device linking. Text only, two people, in-memory.
 *
 *   POST /api/rooms                     { language }        → { code, pid }
 *   POST /api/rooms/:code/join          { language }        → { pid, partnerLanguage }
 *   GET  /api/rooms/:code/events?pid=…  Server-Sent Events  (one `data: {json}` line per event)
 *   POST /api/rooms/:code/messages      { pid, text }       → { id, delivered }
 *   POST /api/rooms/:code/leave         { pid }             → 204
 *
 * The sender posts its own words. The receiving device translates and speaks
 * them with the character that person picked, so this route never calls a
 * provider and costs nothing per message.
 */

const router: IRouter = Router();

const HEARTBEAT_MS = 15_000;
const CREATE_WINDOW_MS = 15 * 60 * 1000;
const MAX_CREATES_PER_WINDOW = 12;
const MAX_JOIN_ATTEMPTS_PER_WINDOW = 40;
const MAX_STREAMS_PER_CLIENT = 4;
const attempts = new Map<string, { creates: number; joins: number; resetAt: number }>();
const streamsByClient = new Map<string, number>();

function bumpAttempts(clientKey: string, field: "creates" | "joins", limit: number): boolean {
  const now = Date.now();
  const current = attempts.get(clientKey);
  const bucket = !current || current.resetAt <= now
    ? { creates: 0, joins: 0, resetAt: now + CREATE_WINDOW_MS }
    : current;
  bucket[field] += 1;
  attempts.set(clientKey, bucket);
  if (attempts.size > 10_000) {
    for (const [key, value] of attempts) {
      if (value.resetAt <= now) attempts.delete(key);
    }
  }
  return bucket[field] <= limit;
}

function bodyOf(req: Request): Record<string, unknown> {
  return (req.body && typeof req.body === "object" ? req.body : {}) as Record<string, unknown>;
}

function tooMany(res: Response, message: string) {
  res.setHeader("Retry-After", "60");
  return res.status(429).json({ error: message, retryAfter: 60 });
}

router.post("/rooms", (req, res) => {
  const language = normalizeRoomLanguage(bodyOf(req)["language"]);
  if (!language) return res.status(400).json({ error: "`language` must be en or es." });
  if (!bumpAttempts(getClientKey(req), "creates", MAX_CREATES_PER_WINDOW)) {
    return tooMany(res, "Too many rooms created. Please try again later.");
  }
  const created = roomStore.create(language);
  if (!created.ok) return res.status(created.status).json({ error: created.error });
  return res.status(201).json({ code: created.code, pid: created.pid, language });
});

router.post("/rooms/:code/join", (req, res) => {
  const language = normalizeRoomLanguage(bodyOf(req)["language"]);
  if (!language) return res.status(400).json({ error: "`language` must be en or es." });
  if (!bumpAttempts(getClientKey(req), "joins", MAX_JOIN_ATTEMPTS_PER_WINDOW)) {
    return tooMany(res, "Too many join attempts. Please try again later.");
  }
  const joined = roomStore.join(req.params["code"], language);
  if (!joined.ok) return res.status(joined.status).json({ error: joined.error });
  return res.json({ pid: joined.pid, partnerLanguage: joined.partnerLanguage, language });
});

router.post("/rooms/:code/messages", (req, res) => {
  const body = bodyOf(req);
  const sent = roomStore.post(req.params["code"], body["pid"], body["text"]);
  if (!sent.ok) return res.status(sent.status).json({ error: sent.error });
  return res.status(202).json({ id: sent.id, delivered: sent.delivered });
});

router.post("/rooms/:code/leave", (req, res) => {
  roomStore.leave(req.params["code"], bodyOf(req)["pid"]);
  return res.status(204).end();
});

router.get("/rooms/:code/events", (req, res) => {
  const code = req.params["code"];
  const pid = typeof req.query["pid"] === "string" ? req.query["pid"] : "";
  if (!roomStore.has(code, pid)) {
    return res.status(404).json({ error: "Room or participant not found." });
  }
  const clientKey = getClientKey(req);
  const open = streamsByClient.get(clientKey) ?? 0;
  if (open >= MAX_STREAMS_PER_CLIENT) return tooMany(res, "Too many open room connections.");
  streamsByClient.set(clientKey, open + 1);

  req.socket.setTimeout(0);
  req.socket.setNoDelay(true);
  res.status(200);
  res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders();

  const write = (event: RoomEvent) => {
    res.write(`data: ${JSON.stringify(event)}\n\n`);
  };
  const subscription = roomStore.subscribe(code, pid, write);
  if (!subscription.ok) {
    streamsByClient.set(clientKey, Math.max(0, (streamsByClient.get(clientKey) ?? 1) - 1));
    res.write(`data: ${JSON.stringify({ t: "closed" })}\n\n`);
    return res.end();
  }
  const heartbeat = setInterval(() => res.write(": ping\n\n"), HEARTBEAT_MS);
  let closed = false;
  req.on("close", () => {
    if (closed) return;
    closed = true;
    clearInterval(heartbeat);
    subscription.unsubscribe();
    const left = Math.max(0, (streamsByClient.get(clientKey) ?? 1) - 1);
    if (left === 0) streamsByClient.delete(clientKey);
    else streamsByClient.set(clientKey, left);
  });
  return undefined;
});

// Rooms are small, so a coarse sweep is enough. unref() keeps tests and
// serverless runtimes from hanging on the timer.
setInterval(() => roomStore.sweep(), 60_000).unref();

export default router;
