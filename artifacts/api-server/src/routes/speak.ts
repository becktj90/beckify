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
  BODIE_ELEVEN_VOICE_SETTINGS,
  BODIE_HALE_VOICE_ID,
  CASSIAN_ELEVEN_VOICE_SETTINGS,
  CASSIAN_VALE_SEED,
  CASSIAN_VALE_VOICE_ID,
  CREW_TALK_ELEVEN_VOICES,
  JUNIE_ELEVEN_VOICE_SETTINGS,
  JUNIE_PELL_VOICE_ID,
  LOOK_CHECK_SPEAK_MAX_CHARS,
  SLOANE_MERRITT_SEED,
  resolveElevenLabsModel,
  resolveElevenLabsVoiceId,
  shouldUseElevenLabsSpeak,
  speakVoiceInstructions,
  speakVoiceMode,
  type SpeakLanguage,
} from "../prompts/speakPrompt.js";
import { observeRouteTiming } from "../lib/logger.js";
import { MissingProviderKeyError, getClientKey } from "../lib/visionClient.js";
import { chargeBudget, logAIUsage, refundBudget } from "../lib/usageBudget.js";

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
  /** OpenAI voice-mode alias when it is a string. Numeric ElevenLabs style is ignored. */
  style?: unknown;
  /** Ignored. ElevenLabs stability is server-side for Bodie, Junie, and Cassian. */
  stability?: unknown;
  /** Ignored. */
  similarity_boost?: unknown;
  /** Ignored. */
  similarityBoost?: unknown;
  /** Ignored. */
  speed?: unknown;
  /** Ignored. Seed is server-side for Cassian and Sloane only. */
  seed?: unknown;
}

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
      error: "Provide text in `text`, `input`, or `translation` (1–500 characters, or up to 900 for a Look Check roast).",
    });
  }

  const voiceMode = speakVoiceMode(body.voiceMode ?? body.mode ?? body.style);
  const language = normalizeSpeakLanguage(body.language);
  const format = pickFormat(body.format);
  const rawVoice = typeof body.voice === "string" ? body.voice.trim() : "";
  const rawModel = typeof body.model === "string" ? body.model.trim() : "";
  const useEleven = shouldUseElevenLabsSpeak(rawVoice, rawModel);
  let voice: string;
  let model: string;
  if (useEleven) {
    const elevenVoice = resolveElevenLabsVoiceId(rawVoice);
    if (!elevenVoice) {
      return res.status(400).json({ error: "Unknown voice." });
    }
    voice = elevenVoice;
    model = resolveElevenLabsModel(rawModel);
  } else {
    voice = pickVoice(body.voice, voiceMode, language);
    model = rawModel || process.env["TTS_MODEL"] || SPEAK_DEFAULT_MODEL;
  }

  const maxChars = voice === CASSIAN_VALE_VOICE_ID ? LOOK_CHECK_SPEAK_MAX_CHARS : SPEAK_MAX_INPUT_CHARS;
  if (text.length > maxChars) {
    return res.status(413).json({
      error: `Text must be ${maxChars} characters or fewer.`,
    });
  }

  const clientKey = getClientKey(req);
  const budgetKind = useEleven ? "eleven" as const : "openai" as const;
  const budgetUnits = useEleven ? text.length : 1;
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

  try {
    const response = useEleven
      ? await synthesizeElevenLabs(text, voice, model, format, elevenVoiceSettings(voice), pickSpeakSeed(voice))
      : await synthesizeOpenAI(text, voice, model, format, voiceMode, language);

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.error("Speak provider HTTP", response.status, errText.slice(0, 400));
      refundBudget(budgetKind, clientKey, budgetUnits);
      logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "refund", clientKey, units: budgetUnits, status: 502 });
      return res.status(502).json({ error: "The speech provider could not synthesize this text." });
    }

    const audioResult = await readProviderAudio(response, startedAtMs);
    firstAudioChunkMs = audioResult.firstAudioChunkMs;
    const audio = audioResult.audio;
    if (!audio.length) {
      refundBudget(budgetKind, clientKey, budgetUnits);
      logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "refund", clientKey, units: budgetUnits, status: 502 });
      return res.status(502).json({ error: "The speech provider returned empty audio." });
    }

    const contentType = format === "wav" ? "audio/wav" : "audio/mpeg";
    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Beckify-TTS-Model", model);
    res.setHeader("X-Beckify-TTS-Voice", voice);
    res.setHeader("X-Beckify-TTS-VoiceMode", voiceMode);
    res.setHeader("X-Beckify-TTS-Language", language);
    if (useEleven) res.setHeader("X-Beckify-TTS-Cacheable", "1");
    logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "ok", clientKey, units: budgetUnits, model });
    res.setHeader("Content-Length", String(audio.length));
    return res.status(200).send(audio);
  } catch (error) {
    if (error instanceof MissingProviderKeyError) {
      refundBudget(budgetKind, clientKey, budgetUnits);
      logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "refund", clientKey, units: budgetUnits, status: 503 });
      return res.status(503).json({
        error: `The speech provider key is missing (${error.envName}).`,
      });
    }
    if (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError")) {
      refundBudget(budgetKind, clientKey, budgetUnits);
      logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "refund", clientKey, units: budgetUnits, status: 504 });
      return res.status(504).json({ error: "The speech provider timed out. Please try again." });
    }
    refundBudget(budgetKind, clientKey, budgetUnits);
    logAIUsage({ route: "/api/speak", kind: budgetKind, outcome: "refund", clientKey, units: budgetUnits, status: 502 });
    console.error("Speak provider request failed", error);
    return res.status(502).json({ error: "The speech provider could not synthesize this text." });
  } finally {
    bucket.inFlight -= 1;
  }
});



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
    signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
    body: JSON.stringify(payload),
  });
}

async function synthesizeElevenLabs(
  text: string,
  voiceId: string,
  model: string,
  format: "mp3" | "wav",
  voiceSettings?: Record<string, number | boolean>,
  seed?: number,
): Promise<Response> {
  const apiKey = process.env["ELEVENLABS_API_KEY"];
  if (!apiKey) {
    throw new MissingProviderKeyError("ELEVENLABS_API_KEY");
  }
  const outputFormat = format === "wav" ? "wav_44100" : "mp3_44100_128";
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=${outputFormat}`;
  return fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: format === "wav" ? "audio/wav" : "audio/mpeg",
      "xi-api-key": apiKey,
    },
    signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
    body: JSON.stringify({
      text,
      model_id: model,
      ...(voiceSettings ? { voice_settings: voiceSettings } : {}),
      ...(seed != null ? { seed } : {}),
    }),
  });
}


/**
 * Bodie, Junie, and Cassian presets stay server-side.
 * Client stability, similarity, style, and speed are ignored.
 * Other allowlisted voices use the provider default.
 */
function elevenVoiceSettings(voiceId: string): Record<string, number | boolean> | undefined {
  const preset = voiceId === BODIE_HALE_VOICE_ID
    ? BODIE_ELEVEN_VOICE_SETTINGS
    : voiceId === JUNIE_PELL_VOICE_ID
      ? JUNIE_ELEVEN_VOICE_SETTINGS
      : voiceId === CASSIAN_VALE_VOICE_ID
        ? CASSIAN_ELEVEN_VOICE_SETTINGS
        : undefined;
  if (!preset) return undefined;
  return {
    stability: preset.stability,
    similarity_boost: preset.similarity_boost,
    style: preset.style,
    use_speaker_boost: preset.use_speaker_boost,
    speed: preset.speed,
  };
}

/** Seed only for Cassian (60606) and Sloane (50505). Client seed is ignored. */
function pickSpeakSeed(voiceId: string): number | undefined {
  if (voiceId === CASSIAN_VALE_VOICE_ID) return CASSIAN_VALE_SEED;
  if (voiceId === CREW_TALK_ELEVEN_VOICES.sloaneMerritt) return SLOANE_MERRITT_SEED;
  return undefined;
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
