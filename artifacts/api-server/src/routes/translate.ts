import { Router, type IRouter } from "express";
import {
  TRANSLATE_MAX_OUTPUT_TOKENS,
  TRANSLATE_MAX_SOURCE_CHARS,
  normalizeTranslateVoiceMode,
  translateSystemPrompt,
  translateUserPrompt,
} from "../prompts/translatePrompt.js";
import { MissingProviderKeyError, getClientKey } from "../lib/visionClient.js";

interface TranslateBody {
  text?: unknown;
  sourceText?: unknown;
  sourceLanguage?: unknown;
  targetLanguage?: unknown;
  task?: unknown;
  dialect?: unknown;
  voiceMode?: unknown;
  mode?: unknown;
  style?: unknown;
}

const router: IRouter = Router();
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 40;
const MAX_IN_FLIGHT_PER_CLIENT = 3;
const PROVIDER_TIMEOUT_MS = 25_000;
const rateBuckets = new Map<string, { count: number; resetAt: number; inFlight: number }>();

router.post("/translate", async (req, res) => {
  const body = (req.body || {}) as TranslateBody;
  const sourceText = pickText(body);
  if (!sourceText) {
    return res.status(400).json({
      error: "Provide English (or mixed) text in `text` or `sourceText` (1–2000 characters).",
    });
  }
  if (sourceText.length > TRANSLATE_MAX_SOURCE_CHARS) {
    return res.status(413).json({
      error: `Text must be ${TRANSLATE_MAX_SOURCE_CHARS} characters or fewer.`,
    });
  }

  const sourceLanguage = asShortString(body.sourceLanguage, "en");
  const targetLanguage = asShortString(body.targetLanguage, "es");
  if (targetLanguage !== "es" && !targetLanguage.toLowerCase().startsWith("es")) {
    return res.status(400).json({
      error: "This route translates to Spanish (`targetLanguage` es / es-*).",
    });
  }

  const voiceMode = normalizeTranslateVoiceMode(body.voiceMode ?? body.mode ?? body.style ?? body.dialect);

  const clientKey = getClientKey(req);
  const bucket = consumeLocalRateLimit(clientKey);
  if (!bucket.allowed) {
    const retryAfter = Math.ceil((bucket.resetAt - Date.now()) / 1000);
    res.setHeader("Retry-After", String(Math.max(1, retryAfter)));
    return res.status(429).json({
      error: "Too many translations. Please try again later.",
      retryAfter: Math.max(1, retryAfter),
    });
  }
  if (bucket.inFlight >= MAX_IN_FLIGHT_PER_CLIENT) {
    res.setHeader("Retry-After", "10");
    return res.status(429).json({ error: "Too many translations in progress.", retryAfter: 10 });
  }
  bucket.inFlight += 1;

  const model = process.env["TRANSLATE_MODEL"] ?? process.env["REVIEW_MODEL"] ?? "gpt-4o-mini";

  try {
    const apiKey = process.env["OPENAI_API_KEY"];
    if (!apiKey) throw new MissingProviderKeyError("OPENAI_API_KEY");

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
      body: JSON.stringify({
        model,
        temperature: 0.75,
        response_format: { type: "json_object" },
        max_tokens: TRANSLATE_MAX_OUTPUT_TOKENS,
        messages: [
          { role: "system", content: translateSystemPrompt(voiceMode) },
          { role: "user", content: translateUserPrompt(sourceText, sourceLanguage, voiceMode) },
        ],
      }),
    });

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.error("Translate provider HTTP", response.status, errText.slice(0, 400));
      return res.status(502).json({ error: "The translation provider could not translate this text." });
    }

    const payload = (await response.json()) as {
      choices?: Array<{ message?: { content?: string | null } }>;
    };
    const content = payload.choices?.[0]?.message?.content;
    if (!content) {
      return res.status(502).json({ error: "The translation provider returned no content." });
    }

    const parsed = parseTranslateJSON(content);
    if (!parsed) {
      return res.status(502).json({ error: "The translation provider returned invalid JSON." });
    }

    return res.json({
      task: "translate",
      provider: "openai",
      model,
      sourceLanguage,
      targetLanguage: "es",
      dialect: parsed.dialect || (voiceMode === "clean" ? "cuban_florida_clean" : "cuban_florida_jobsite"),
      voiceMode,
      sourceText,
      translation: parsed.translation,
      notes: parsed.notes || undefined,
    });
  } catch (error) {
    if (error instanceof MissingProviderKeyError) {
      return res.status(503).json({ error: error.message });
    }
    if (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError")) {
      return res.status(504).json({ error: "The translation provider timed out. Please try again." });
    }
    console.error("Translate provider request failed", error);
    return res.status(502).json({ error: "The translation provider could not translate this text." });
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

function pickText(body: TranslateBody): string {
  for (const raw of [body.text, body.sourceText]) {
    if (typeof raw !== "string") continue;
    const trimmed = raw.trim();
    if (trimmed.length >= 1) return trimmed;
  }
  return "";
}

function asShortString(raw: unknown, fallback: string): string {
  if (typeof raw !== "string") return fallback;
  const trimmed = raw.trim().toLowerCase();
  if (!trimmed || trimmed.length > 16) return fallback;
  return trimmed;
}

function parseTranslateJSON(
  content: string,
): { translation: string; dialect: string; notes: string } | null {
  try {
    const trimmed = content.trim();
    const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
    const source = fenced ? fenced[1] : trimmed;
    const start = source.indexOf("{");
    const end = source.lastIndexOf("}");
    const json = start >= 0 && end >= 0 ? source.slice(start, end + 1) : source;
    const obj = JSON.parse(json) as Record<string, unknown>;
    const translation = typeof obj.translation === "string" ? obj.translation.trim() : "";
    if (!translation) return null;
    const dialect = typeof obj.dialect === "string" ? obj.dialect.trim().slice(0, 64) : "";
    const notes = typeof obj.notes === "string" ? obj.notes.trim().slice(0, 240) : "";
    return { translation, dialect, notes };
  } catch {
    return null;
  }
}

export default router;
