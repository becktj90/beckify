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
  CASSIAN_ELEVEN_VOICE_SETTINGS,
  CASSIAN_VALE_SEED,
  CASSIAN_VALE_VOICE_ID,
  JUNIE_ELEVEN_VOICE_SETTINGS,
  JUNIE_PELL_VOICE_ID,
  LOOK_CHECK_SPEAK_MAX_CHARS,
  resolveElevenLabsModel,
  resolveElevenLabsVoiceId,
  shouldUseElevenLabsSpeak,
  speakVoiceInstructions,
  speakVoiceMode,
  type SpeakLanguage,
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
  stability?: unknown;
  similarity_boost?: unknown;
  similarityBoost?: unknown;
  speed?: unknown;
  seed?: unknown;
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
      error: "Provide text in `text`, `input`, or `translation` (1–500 characters, or up to 1500 for a Look Check roast).",
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
      return res.status(400).json({ error: "ElevenLabs speech needs a voice id." });
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
    const response = useEleven
      ? await synthesizeElevenLabs(text, voice, model, format, elevenVoiceSettings(voice, body), pickSpeakSeed(body.seed, voice))
      : await synthesizeOpenAI(text, voice, model, format, voiceMode, language);

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
    res.setHeader("X-Beckify-TTS-Language", language);
    res.setHeader("Content-Length", String(audio.length));
    return res.status(200).send(audio);
  } catch (error) {
    if (error instanceof MissingProviderKeyError) {
      return res.status(503).json({
        error: `The speech provider key is missing (${error.envName}).`,
      });
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


function clampUnit(raw: unknown, fallback: number): number {
  const value = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(1, Math.max(0, value));
}

function clampSpeed(raw: unknown, fallback: number): number {
  const value = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(1.2, Math.max(0.5, value));
}

/** Junie and Cassian Vale get presets. Other voices stay on the provider default unless the body sets knobs. */
function elevenVoiceSettings(voiceId: string, body: SpeakBody): Record<string, number | boolean> | undefined {
  const junie = voiceId === JUNIE_PELL_VOICE_ID;
  const cassian = voiceId === CASSIAN_VALE_VOICE_ID;
  const preset = junie ? JUNIE_ELEVEN_VOICE_SETTINGS : CASSIAN_ELEVEN_VOICE_SETTINGS;
  const stability = body.stability;
  const similarity = body.similarity_boost ?? body.similarityBoost;
  const style = body.style;
  const speed = body.speed;
  const hasOverride = stability != null || similarity != null || (typeof style === "number") || speed != null;
  if (!junie && !cassian && !hasOverride) return undefined;
  return {
    stability: clampUnit(stability, junie || cassian ? preset.stability : 0.5),
    similarity_boost: clampUnit(similarity, junie || cassian ? preset.similarity_boost : 0.75),
    style: clampUnit(typeof style === "number" ? style : undefined, junie || cassian ? preset.style : 0),
    use_speaker_boost: true,
    speed: clampSpeed(speed, junie || cassian ? preset.speed : 1),
  };
}

/** Look Check posts seed 60606. Other voices omit seed unless the body sets one. */
function pickSpeakSeed(raw: unknown, voiceId: string): number | undefined {
  const fallback = voiceId === CASSIAN_VALE_VOICE_ID ? CASSIAN_VALE_SEED : undefined;
  if (raw == null || raw === "") return fallback;
  const value = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isInteger(value) || value < 0 || value > 4294967295) return fallback;
  return value;
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
