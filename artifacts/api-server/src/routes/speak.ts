import { Router, type IRouter } from "express";
import {
  SPEAK_DEFAULT_MODEL,
  SPEAK_DEFAULT_VOICE,
  SPEAK_DEEP_SOUTH_VOICE,
  SPEAK_EN_CALIFORNIA_VOICE,
  SPEAK_MAX_INPUT_CHARS,
  speakDefaultVoiceForMode,
  speakSupportsInstructions,
  normalizeSpeakLanguage,
  shouldUseElevenLabsSpeak,
  speakVoiceInstructions,
  speakVoiceMode,
  type SpeakLanguage,
  stripAudioTags,
} from "../prompts/speakPrompt.js";
import { observeRouteTiming } from "../lib/logger.js";
import { MissingProviderKeyError, getClientKey } from "../lib/visionClient.js";
import { chargeBudget, logAIUsage, refundBudget, type AIBudgetKind } from "../lib/usageBudget.js";
import {
  CREW_VOICE_PROFILES,
  TRANSLATOR_VOICE_PROFILES,
  resolveCrewVoiceKey,
  type CrewVoiceKey,
  type CrewVoiceProfile,
} from "../voice/crewVoices.js";
import {
  KOKORO_MODEL_LABEL,
  VoiceEngineUnavailableError,
  crewVoiceFallback,
  crewVoiceProvider,
  kokoroEngine,
  translatorVoiceProvider,
} from "../voice/engine.js";
import { elevenVoiceIdFor, synthesizeElevenLabs } from "../voice/elevenLabs.js";

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
  /** Crew character key (e.g. `bodieHale`). Optional; shipped builds send a legacy voice id. */
  crew?: unknown;
  /** OpenAI voice-mode alias when it is a string. Numeric style is ignored. */
  style?: unknown;
  /** Ignored. Voice settings are server-side. */
  stability?: unknown;
  /** Ignored. */
  similarity_boost?: unknown;
  /** Ignored. */
  similarityBoost?: unknown;
  /** Ignored. */
  speed?: unknown;
  /** Ignored. */
  seed?: unknown;
}

/** One way to make the audio for this request. */
type SpeakPlan =
  | { provider: "kokoro"; label: string; profile: CrewVoiceProfile; text: string; crewKey: CrewVoiceKey | null; rawVoice: string }
  | { provider: "elevenlabs"; voiceId: string; text: string }
  | { provider: "openai"; voice: string; model: string; text: string };

const router: IRouter = Router();
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 20;
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
  const startedAtMs = Date.now();
  // Provider time-to-first-audio-chunk. The HTTP response stays fully buffered.
  let firstAudioChunkMs: number | null = null;
  observeRouteTiming(res, "/api/speak", startedAtMs, () => ({
    first_audio_chunk_ms: firstAudioChunkMs,
  }));
  const body = (req.body || {}) as SpeakBody;
  const text = pickText(body);
  if (!text) {
    return res.status(400).json({
      error: "Provide text in `text`, `input`, or `translation` (1–500 characters).",
    });
  }

  const voiceMode = speakVoiceMode(body.voiceMode ?? body.mode ?? body.style);
  const language = normalizeSpeakLanguage(body.language);
  const format = pickFormat(body.format);
  const rawVoice = typeof body.voice === "string" ? body.voice.trim() : "";
  const rawModel = typeof body.model === "string" ? body.model.trim() : "";

  // Crew Talk: a crew key, a `crew:` voice, a legacy crew voice id, or an eleven_* model.
  const crewKey = resolveCrewVoiceKey(rawVoice, body.crew, language);
  const crewShaped = crewKey != null || rawVoice.startsWith("crew:") || shouldUseElevenLabsSpeak(rawVoice, rawModel);
  if (crewShaped && !crewKey) {
    return res.status(400).json({ error: "Unknown voice." });
  }

  let plan: SpeakPlan;
  if (crewKey) {
    if (crewVoiceProvider() === "elevenlabs") {
      const voiceId = elevenVoiceIdFor(crewKey, rawVoice);
      if (!voiceId) return res.status(400).json({ error: "Unknown voice." });
      plan = { provider: "elevenlabs", voiceId, text };
    } else {
      plan = {
        provider: "kokoro",
        label: crewKey,
        profile: CREW_VOICE_PROFILES[crewKey],
        text: stripAudioTags(text) || text,
        crewKey,
        rawVoice,
      };
    }
  } else if (translatorVoiceProvider() === "kokoro" && language !== "ja") {
    const preset = translatorPreset(voiceMode, language);
    plan = { provider: "kokoro", label: preset, profile: TRANSLATOR_VOICE_PROFILES[preset], text: stripAudioTags(text) || text, crewKey: null, rawVoice };
  } else {
    plan = {
      provider: "openai",
      voice: pickVoice(body.voice, voiceMode, language),
      model: rawModel || process.env["TTS_MODEL"] || SPEAK_DEFAULT_MODEL,
      text: stripAudioTags(text) || text,
    };
  }

  if (text.length > SPEAK_MAX_INPUT_CHARS) {
    return res.status(413).json({
      error: `Text must be ${SPEAK_MAX_INPUT_CHARS} characters or fewer.`,
    });
  }

  const clientKey = getClientKey(req);
  const budgetKind = budgetKindFor(plan);
  const budgetUnits = budgetKind === "openai" ? 1 : text.length;
  const budget = chargeBudget(budgetKind, clientKey, budgetUnits);
  if (!budget.allowed) {
    logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "blocked", clientKey, units: budgetUnits, status: 429 });
    res.setHeader("Retry-After", String(budget.retryAfter));
    return res.status(429).json({
      error: "AI budget exceeded for speech. Please try again later.",
      retryAfter: budget.retryAfter,
    });
  }
  const bucket = consumeLocalRateLimit(clientKey);
  if (!bucket.allowed) {
    refundBudget(budgetKind, clientKey, budgetUnits);
    const retryAfter = Math.ceil((bucket.resetAt - Date.now()) / 1000);
    res.setHeader("Retry-After", String(Math.max(1, retryAfter)));
    return res.status(429).json({
      error: "Too many speak requests. Please try again later.",
      retryAfter: Math.max(1, retryAfter),
    });
  }
  if (bucket.inFlight >= MAX_IN_FLIGHT_PER_CLIENT) {
    refundBudget(budgetKind, clientKey, budgetUnits);
    logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "refund", clientKey, units: budgetUnits, status: 429 });
    res.setHeader("Retry-After", "10");
    return res.status(429).json({ error: "Too many speak requests in progress.", retryAfter: 10 });
  }
  bucket.inFlight += 1;

  const fail = (status: number, error: string) => {
    refundBudget(budgetKind, clientKey, budgetUnits);
    logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "refund", clientKey, units: budgetUnits, status });
    return res.status(status).json({ error });
  };

  try {
    let response: Response;
    let served = plan;
    try {
      response = await runPlan(plan, format, voiceMode, language);
      if (plan.provider === "kokoro" && !response.ok && response.status >= 500) {
        throw new VoiceEngineUnavailableError(`voice engine HTTP ${response.status}`);
      }
    } catch (error) {
      // Optional, off by default: retry a failed free-engine call on ElevenLabs.
      const fallbackPlan = plan.provider === "kokoro" && plan.crewKey && crewVoiceFallback() === "elevenlabs"
        ? elevenVoiceIdFor(plan.crewKey, plan.rawVoice)
        : null;
      if (!fallbackPlan || !isEngineFailure(error)) throw error;
      // The paid fallback keeps its own character meter.
      if (!chargeBudget("eleven", clientKey, text.length).allowed) throw error;
      served = { provider: "elevenlabs", voiceId: fallbackPlan, text };
      response = await runPlan(served, format, voiceMode, language);
    }

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.error("Speak provider HTTP", response.status, errText.slice(0, 400));
      return fail(502, "The speech provider could not synthesize this text.");
    }

    const audioResult = await readProviderAudio(response, startedAtMs);
    firstAudioChunkMs = audioResult.firstAudioChunkMs;
    const audio = audioResult.audio;
    if (!audio.length) {
      return fail(502, "The speech provider returned empty audio.");
    }

    const contentType = format === "wav" ? "audio/wav" : "audio/mpeg";
    const header = servedHeaders(served);
    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Beckify-TTS-Provider", served.provider);
    res.setHeader("X-Beckify-TTS-Model", header.model);
    res.setHeader("X-Beckify-TTS-Voice", header.voice);
    res.setHeader("X-Beckify-TTS-VoiceMode", voiceMode);
    res.setHeader("X-Beckify-TTS-Language", language);
    // Crew voices are deterministic per line, so clients may cache them.
    if (served.provider !== "openai") res.setHeader("X-Beckify-TTS-Cacheable", "1");
    logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "ok", clientKey, units: budgetUnits, model: header.model });
    res.setHeader("Content-Length", String(audio.length));
    return res.status(200).send(audio);
  } catch (error) {
    if (error instanceof MissingProviderKeyError) {
      return fail(503, `The speech provider key is missing (${error.envName}).`);
    }
    if (error instanceof VoiceEngineUnavailableError) {
      console.error("Voice engine unavailable", error.message);
      return fail(503, "The voice engine is not available right now.");
    }
    if (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError")) {
      return fail(504, "The speech provider timed out. Please try again.");
    }
    console.error("Speak provider request failed", error);
    return fail(502, "The speech provider could not synthesize this text.");
  } finally {
    bucket.inFlight -= 1;
  }
});

function runPlan(
  plan: SpeakPlan,
  format: "mp3" | "wav",
  voiceMode: ReturnType<typeof speakVoiceMode>,
  language: SpeakLanguage,
): Promise<Response> {
  const signal = AbortSignal.timeout(PROVIDER_TIMEOUT_MS);
  if (plan.provider === "kokoro") {
    return kokoroEngine.synthesize({ text: plan.text, format, profile: plan.profile, label: plan.label }, signal);
  }
  if (plan.provider === "elevenlabs") return synthesizeElevenLabs(plan.text, plan.voiceId, format, signal);
  return synthesizeOpenAI(plan.text, plan.voice, plan.model, format, voiceMode, language, signal);
}

function isEngineFailure(error: unknown): boolean {
  return error instanceof VoiceEngineUnavailableError
    || (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError"));
}

function budgetKindFor(plan: SpeakPlan): AIBudgetKind {
  if (plan.provider === "kokoro") return "voice";
  if (plan.provider === "elevenlabs") return "eleven";
  return "openai";
}

function servedHeaders(plan: SpeakPlan): { model: string; voice: string } {
  if (plan.provider === "kokoro") return { model: KOKORO_MODEL_LABEL, voice: plan.label };
  if (plan.provider === "elevenlabs") return { model: "eleven_v3", voice: plan.voiceId };
  return { model: plan.model, voice: plan.voice };
}

/** Translator preset on the free engine (only when TRANSLATOR_VOICE_PROVIDER=kokoro). */
function translatorPreset(
  mode: ReturnType<typeof speakVoiceMode>,
  language: SpeakLanguage,
): keyof typeof TRANSLATOR_VOICE_PROFILES {
  if (mode === "deepSouth") return "deepSouth";
  if (mode === "california" || (language === "en" && mode !== "cuban")) return "california";
  return mode === "clean" ? "clean" : "jobsite";
}

/**
 * Buffer the provider body the same way arrayBuffer() did, while noting when the
 * first non-empty audio chunk arrived. The client still receives one buffered
 * body with Content-Length; status codes and headers are unchanged.
 */
async function readProviderAudio(
  response: globalThis.Response,
  startedAtMs: number,
): Promise<{ audio: Buffer; firstAudioChunkMs: number | null }> {
  const body = response.body;
  if (!body || typeof body.getReader !== "function") {
    const audio = Buffer.from(await response.arrayBuffer());
    return {
      audio,
      firstAudioChunkMs: audio.length > 0 ? Date.now() - startedAtMs : null,
    };
  }
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let firstAudioChunkMs: number | null = null;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value || value.byteLength === 0) continue;
      if (firstAudioChunkMs == null) firstAudioChunkMs = Date.now() - startedAtMs;
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const audio = chunks.length === 0 ? Buffer.alloc(0) : Buffer.concat(chunks);
  return { audio, firstAudioChunkMs };
}

async function synthesizeOpenAI(
  text: string,
  voice: string,
  model: string,
  format: "mp3" | "wav",
  voiceMode: ReturnType<typeof speakVoiceMode>,
  language: SpeakLanguage,
  signal: AbortSignal,
): Promise<Response> {
  const apiKey = process.env["OPENAI_API_KEY"];
  if (!apiKey) throw new MissingProviderKeyError("OPENAI_API_KEY");
  const payload: Record<string, unknown> = {
    model,
    voice,
    input: text,
    response_format: format,
  };
  if (speakSupportsInstructions(model)) {
    payload.instructions = speakVoiceInstructions(voiceMode, language);
  }
  return fetch("https://api.openai.com/v1/audio/speech", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    signal,
    body: JSON.stringify(payload),
  });
}

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

function pickVoice(
  raw: unknown,
  mode: ReturnType<typeof speakVoiceMode> = "jobsite",
  language: SpeakLanguage = "es",
): string {
  const maleEnglish = mode === "deepSouth" || mode === "california" || language === "en";
  if (maleEnglish && mode !== "cuban") {
    if (typeof raw === "string") {
      const voice = raw.trim().toLowerCase();
      // California and Deep South stay male. Ignore female Clean defaults.
      if (ALLOWED_VOICES.has(voice) && voice !== "nova" && voice !== "shimmer") return voice;
    }
    return mode === "deepSouth" ? SPEAK_DEEP_SOUTH_VOICE : SPEAK_EN_CALIFORNIA_VOICE;
  }
  if (typeof raw === "string") {
    const voice = raw.trim().toLowerCase();
    if (ALLOWED_VOICES.has(voice)) return voice;
  }
  return speakDefaultVoiceForMode(mode, language) || SPEAK_DEFAULT_VOICE;
}

function pickFormat(raw: unknown): "mp3" | "wav" {
  if (typeof raw !== "string") return "mp3";
  const format = raw.trim().toLowerCase();
  if (format === "wav" || format === "audio/wav") return "wav";
  return "mp3";
}

export default router;
