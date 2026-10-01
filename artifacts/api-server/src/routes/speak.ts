import { Router, type IRouter } from "express";
import {
  SPEAK_DEFAULT_MODEL,
  SPEAK_DEFAULT_VOICE,
  SPEAK_MAX_INPUT_CHARS,
  speakDefaultVoiceForMode,
  speakSupportsInstructions,
  speakVoiceInstructions,
  speakVoiceMode,
} from "../prompts/speakPrompt.js";
import { MissingProviderKeyError, getClientKey } from "../lib/visionClient.js";

interface SpeakBody {
  text?: unknown;
  input?: unknown;
  translation?: unknown;
  voice?: unknown;
  model?: unknown;
  format?: unknown;
  language?: unknown;
  voiceMode?: unknown;
  mode?: unknown;
  style?: unknown;
}

const router: IRouter = Router();
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 30;
const MAX_IN_FLIGHT_PER_CLIENT = 2;
const PROVIDER_TIMEOUT_MS = 30_000;
const ALLOWED_VOICES = new Set([
  "alloy",
  "ash",
  "ballad",
  "coral",
  "echo",
  "fable",
  "onyx",
  "nova",
  "sage",
  "shimmer",
  "verse",
  "marin",
  "cedar",
]);
const rateBuckets = new Map<string, { count: number; resetAt: number; inFlight: number }>();

router.post("/speak", async (req, res) => {
  const body = (req.body || {}) as SpeakBody;
  const text = pickText(body);
  if (!text) {
    return res.status(400).json({
      error: "Provide Spanish (or mixed) text in `text`, `input`, or `translation` (1–500 characters).",
    });
  }
  if (text.length > SPEAK_MAX_INPUT_CHARS) {
    return res.status(413).json({
      error: `Text must be ${SPEAK_MAX_INPUT_CHARS} characters or fewer for short jobsite clips.`,
    });
  }

  const voiceMode = speakVoiceMode(body.voiceMode ?? body.mode ?? body.style);
  const voice = pickVoice(body.voice, voiceMode);
  const format = pickFormat(body.format);
  const model =
    (typeof body.model === "string" && body.model.trim()) ||
    process.env["TTS_MODEL"] ||
    SPEAK_DEFAULT_MODEL;

  const clientKey = getClientKey(req);
  const bucket = consumeLocalRateLimit(clientKey);
  if (!bucket.allowed) {
    const retryAfter = Math.ceil((bucket.resetAt - Date.now()) / 1000);
    res.setHeader("Retry-After", String(Math.max(1, retryAfter)));
    return res.status(429).json({
      error: "Too many speak requests. Please try again later.",
      retryAfter: Math.max(1, retryAfter),
    });
  }
  if (bucket.inFlight >= MAX_IN_FLIGHT_PER_CLIENT) {
    res.setHeader("Retry-After", "10");
    return res.status(429).json({ error: "Too many speak requests in progress.", retryAfter: 10 });
  }
  bucket.inFlight += 1;

  try {
    const apiKey = process.env["OPENAI_API_KEY"];
    if (!apiKey) throw new MissingProviderKeyError("OPENAI_API_KEY");

    const payload: Record<string, unknown> = {
      model,
      voice,
      input: text,
      response_format: format,
    };
    if (speakSupportsInstructions(model)) {
      payload.instructions = speakVoiceInstructions(voiceMode);
    }

    const response = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.error("Speak provider HTTP", response.status, errText.slice(0, 400));
      return res.status(502).json({ error: "The speech provider could not synthesize this text." });
    }

    const audio = Buffer.from(await response.arrayBuffer());
    if (!audio.length) {
      return res.status(502).json({ error: "The speech provider returned empty audio." });
    }

    const contentType = format === "wav" ? "audio/wav" : "audio/mpeg";
    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Beckify-TTS-Model", model);
    res.setHeader("X-Beckify-TTS-Voice", voice);
    res.setHeader("X-Beckify-TTS-VoiceMode", voiceMode);
    res.setHeader("Content-Length", String(audio.length));
    return res.status(200).send(audio);
  } catch (error) {
    if (error instanceof MissingProviderKeyError) {
      return res.status(503).json({ error: error.message });
    }
    if (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError")) {
      return res.status(504).json({ error: "The speech provider timed out. Please try again." });
    }
    console.error("Speak provider request failed", error);
    return res.status(502).json({ error: "The speech provider could not synthesize this text." });
  } finally {
    bucket.inFlight -= 1;
  }
});

function consumeLocalRateLimit(clientKey: string) {
  const now = Date.now();
  const current = rateBuckets.get(clientKey);
  const bucket = !current || current.resetAt <= now
    ? { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS, inFlight: 0 }
    : current;
  bucket.count += 1;
  rateBuckets.set(clientKey, bucket);
  if (rateBuckets.size > 10_000) {
    for (const [key, value] of rateBuckets) {
      if (value.resetAt <= now) rateBuckets.delete(key);
    }
  }
  return Object.assign(bucket, { allowed: bucket.count <= MAX_REQUESTS_PER_WINDOW });
}

function pickText(body: SpeakBody): string {
  for (const raw of [body.text, body.input, body.translation]) {
    if (typeof raw !== "string") continue;
    const trimmed = raw.trim();
    if (trimmed.length >= 1) return trimmed;
  }
  return "";
}

function pickVoice(raw: unknown, mode: ReturnType<typeof speakVoiceMode> = "jobsite"): string {
  if (typeof raw === "string") {
    const voice = raw.trim().toLowerCase();
    if (ALLOWED_VOICES.has(voice)) return voice;
  }
  return speakDefaultVoiceForMode(mode) || SPEAK_DEFAULT_VOICE;
}

function pickFormat(raw: unknown): "mp3" | "wav" {
  if (typeof raw !== "string") return "mp3";
  const format = raw.trim().toLowerCase();
  if (format === "wav" || format === "audio/wav") return "wav";
  return "mp3";
}

export default router;
