/** Cuban / South Florida TTS instructions for OpenAI `/v1/audio/speech`. */

import type { TranslateVoiceMode } from "./translatePrompt.js";
import { normalizeTranslateVoiceMode } from "./translatePrompt.js";

/** Deep male-ish built-in voice for Jobsite mode. */
export const SPEAK_DEFAULT_VOICE = "onyx";

/** Warm female-ish built-in voice for Clean mode. */
export const SPEAK_CLEAN_VOICE = "nova";

/**
 * Prefer gpt-4o-mini-tts so `instructions` apply.
 * Override with TTS_MODEL=tts-1 when chasing the absolute cheapest path
 * (tts-1 ignores instructions).
 */
export const SPEAK_DEFAULT_MODEL = "gpt-4o-mini-tts";

export const SPEAK_MAX_INPUT_CHARS = 500;

export const SPEAK_JOBSITE_VOICE_INSTRUCTIONS = `Read the supplied Spanish text exactly, in the voice of a fictional older Cuban and South American tradesman whose voice sounds weathered by fifty years of cigarettes and hard jobsite work. Deep, chesty male register; coarse gravel, dry rasp, husky vocal fry at phrase endings, and slightly uneven breath. Hilarious in the way a real old hand is hilarious: deadpan, skeptical, a dry bite on the stressed word, short deliberate phrases, never slapstick and never a cartoon. Cuban-American rhythm with South American warmth when the line asks for it — a believable working man, not a costume and not an impression of any real person. Project across a noisy site without screaming. The rasp must never swallow a word; electrical terms, numbers, units, and warnings stay crisp. Deliver profanity already in the text naturally — do not beep, sanitize, skip, or soften it. Do not add words, jokes, coughs, cigarette sounds, laughs, threats, or criminal claims. Do not swap words into slang that is not already written. No slurs and no ethnicity mockery. Preserve the text and its meaning; only the delivery changes.`;

export const SPEAK_CLEAN_VOICE_INSTRUCTIONS = `Speak like a polished Cuban / South Florida woman — warm, elegant, clear, and kind. Soft feminine Cuban-American Florida Spanish cadence with graceful confidence. Project enough to be heard, but never yell like a jobsite. Refined and welcoming — not crude, not sarcastic, not a cartoon, not Castilian Spain, not a mocking caricature accent. Do not invent swearing; if the text is already clean, keep it clean and musical. Never invent hate slurs. Pace is clear and unhurried, still lively and warm.`;

/** @deprecated Prefer speakVoiceInstructions(mode). */
export const SPEAK_VOICE_INSTRUCTIONS = SPEAK_JOBSITE_VOICE_INSTRUCTIONS;

export function speakVoiceMode(raw: unknown): SpeakVoiceMode {
  if (typeof raw !== "string") return "jobsite";
  const folded = raw.trim().toLowerCase().replace(/[\s_-]+/g, "");
  if (folded === "deepsouth" || folded === "south") return "deepSouth";
  if (folded === "california" || folded === "socal" || folded === "westcoast") return "california";
  if (folded === "cuban" || folded === "southamerican" || folded === "latam") return "cuban";
  return normalizeTranslateVoiceMode(raw);
}

/**
 * English California character. `echo` is a lighter male than Jobsite `onyx`
 * so California and Deep South (`ballad`) do not share a timbre.
 */
export const SPEAK_EN_CALIFORNIA_VOICE = "echo";

/** Storyteller timbre for the Deep South English character. Not California `echo`. */
export const SPEAK_DEEP_SOUTH_VOICE = "ballad";

/** @deprecated Prefer SPEAK_EN_CALIFORNIA_VOICE. English speak is California, not onyx. */
export const SPEAK_EN_VOICE = SPEAK_EN_CALIFORNIA_VOICE;

/** Japanese delivery reuses the same built-in voices as Spanish, distinguished by `instructions`. */
export const SPEAK_JA_JOBSITE_VOICE = SPEAK_DEFAULT_VOICE;
export const SPEAK_JA_CLEAN_VOICE = SPEAK_CLEAN_VOICE;

export type SpeakLanguage = "en" | "es" | "ja";

/**
 * Speak delivery. `clean` / `jobsite` stay the product modes.
 * `california`, `cuban`, and `deepSouth` select a character directly.
 * Deep South is English-only playback of the supplied words.
 */
export type SpeakVoiceMode = TranslateVoiceMode | "california" | "cuban" | "deepSouth";

/**
 * Spanish and Japanese delivery follow Clean (nova) / Jobsite (onyx).
 * English uses the male voice (`onyx`) with mode-specific delivery.
 */
export function speakDefaultVoiceForMode(
  mode: SpeakVoiceMode,
  language: SpeakLanguage = "es",
): string {
  if (mode === "deepSouth") return SPEAK_DEEP_SOUTH_VOICE;
  if (mode === "california" || language === "en") return SPEAK_EN_CALIFORNIA_VOICE;
  if (mode === "cuban") return SPEAK_DEFAULT_VOICE;
  return mode === "clean" ? SPEAK_CLEAN_VOICE : SPEAK_DEFAULT_VOICE;
}

/**
 * California adult — English playback for Clean.
 * Funny through timing and attitude. The words stay exactly as supplied.
 * Not a stoner bit, not a celebrity impression, not Deep South.
 */
export const SPEAK_EN_CLEAN_VOICE_INSTRUCTIONS = `Read the supplied English text exactly, as a fictional coastal California adult in his thirties: sunny, a little vain, and genuinely funny. Delivery is the joke — relaxed West Coast melody, friendly late punchlines, a soft rise at the end of a phrase, warm confidence like someone who has never been cold. Indoor volume, unhurried, still crisp. This is California, not the Deep South, not New York, not the Midwest, not Britain, and not a tech-campus narrator. Not a stoner, not a surfer cartoon, not a word-swap bit, and not an impression of any real person. Do not insert dude, man, like, or laughs. Do not add words, coughs, or stage directions. Do not invent swearing or slurs. No ethnicity mockery. Keep electrical terms, numbers, units, negations, and warnings perfectly clear. Preserve the text and its meaning; only the performance changes.`;

/**
 * Same California adult, louder and drier, for Jobsite English.
 * Still not the Deep South character and not the Spanish tradesman.
 */
export const SPEAK_EN_JOBSITE_VOICE_INSTRUCTIONS = `Read the supplied English text exactly, as the same fictional coastal California adult, now calling across a noisy jobsite: louder, drier, and funnier. Comic exasperation, a beat of silence before the important word, raised-eyebrow sarcasm you can hear, still a relaxed West Coast cadence — never a Southern drawl, never Cuban Spanish rhythm, never a gravelly cigarette rasp. Project so the far end of the site hears you; do not scream the consonants apart. Not a stoner, not a surfer cartoon, not a corporate narrator, not a word-swap rewrite, and not an impression of any real person. Do not add words, jokes, laughs, coughs, or threats. Deliver swearing already in the text; do not beep or sanitize it. Never invent slurs or mock an ethnicity. Keep electrical terms, numbers, units, negations, and warnings crisp. Preserve the text and its meaning; only the performance changes.`;

/**
 * Third English character. Slow Deep South storyteller on `ballad`.
 * Hilarious understatement. Does not rewrite the words.
 */
export const SPEAK_DEEP_SOUTH_VOICE_INSTRUCTIONS = `Read the supplied English text exactly, as a fictional Deep South adult storyteller: low, round, and unhurried, with a honeyed melody and a sly pause before the last stress of a sentence, like a porch punchline that never announces itself. Warm, understated, and funny — comic timing, not a costume. Clearly not California: no uptalk, no West Coast bounce, no beach attitude. Not Cuban or South American Spanish. Not a hillbilly cartoon, not a minstrel act, not a racial caricature, and not an impression of any real person. Do not add words. Do not insert y'all, howdy, bless your heart, fixin', or anything that is not already in the text. Do not drop g's, do not swap words, do not add laughs, coughs, or asides. Deliver swearing already in the text; do not beep it and do not add any. Never invent slurs or mock an ethnicity. Keep electrical terms, numbers, units, negations, and warnings intelligible even at the slow pace. Preserve the text and its meaning; only the performance changes.`;

/**
 * Japanese delivery: a real, natural Japanese speaker — not an accent
 * impression, not a caricature. Register (direct jobsite vs warm clean)
 * mirrors the Spanish instructions' energy without inventing a voice gimmick.
 */
export const SPEAK_JA_JOBSITE_VOICE_INSTRUCTIONS = `Speak like a real Japanese construction-site coworker — direct, clear, and projected so someone across a noisy jobsite can hear you. Natural native Japanese pronunciation and cadence, casual and fast-paced like a coworker talking on the job, not a news announcer. Not a whisper, not a cartoon, not an accent impression, not a mocking caricature. Keep the pace intelligible over site noise: energetic and direct, a touch slower than rapid casual speech so it lands clearly.`;

export const SPEAK_JA_CLEAN_VOICE_INSTRUCTIONS = `Speak like a polished, warm Japanese voice — clear, natural native Japanese pronunciation and cadence, polite and professional. Project enough to be heard, but never yell like a jobsite. Refined and welcoming — not crude, not sarcastic, not a cartoon, not an accent impression, not a mocking caricature. Pace is clear and unhurried, still warm and natural.`;

/** `en` / `en-*` and `ja` / `ja-*` select those deliveries. Anything else, including omitted, stays Spanish. */
export function normalizeSpeakLanguage(raw: unknown): SpeakLanguage {
  if (typeof raw !== "string") return "es";
  const folded = raw.trim().toLowerCase().replace(/_/g, "-");
  const primary = folded.split("-")[0] ?? "";
  if (primary === "en") return "en";
  if (primary === "ja") return "ja";
  return "es";
}

export function speakVoiceInstructions(mode: SpeakVoiceMode, language: SpeakLanguage = "es"): string {
  if (mode === "deepSouth") return SPEAK_DEEP_SOUTH_VOICE_INSTRUCTIONS;
  if (mode === "california" || (language === "en" && mode !== "cuban")) {
    return mode === "jobsite" ? SPEAK_EN_JOBSITE_VOICE_INSTRUCTIONS : SPEAK_EN_CLEAN_VOICE_INSTRUCTIONS;
  }
  if (language === "ja" && mode !== "cuban") {
    return mode === "clean" ? SPEAK_JA_CLEAN_VOICE_INSTRUCTIONS : SPEAK_JA_JOBSITE_VOICE_INSTRUCTIONS;
  }
  return mode === "clean" ? SPEAK_CLEAN_VOICE_INSTRUCTIONS : SPEAK_JOBSITE_VOICE_INSTRUCTIONS;
}

export function speakSupportsInstructions(model: string): boolean {
  const name = (model || "").toLowerCase();
  return name.includes("gpt-4o-mini-tts") || name.includes("gpt-4o-tts");
}


/** Look Check roast voice: Cassian Vale. Low, close, raspy, unhurried, delighted. */
export const CASSIAN_VALE_NAME = "Cassian Vale";
export const CASSIAN_VALE_VOICE_ID = "uYsaRSYDSuxmtyipO9Qt";
/** Deterministic ElevenLabs seed for this roast voice. Posted when the speak route sends seed. */
export const CASSIAN_VALE_SEED = 60606;
/** Paragraph roast. Crew Talk clips stay on SPEAK_MAX_INPUT_CHARS. */
export const LOOK_CHECK_SPEAK_MAX_CHARS = 1500;

/**
 * Relish without a scream. High style exaggeration, close to the designed voice,
 * slightly slow so each word is savored, still intelligible.
 */
export const CASSIAN_ELEVEN_VOICE_SETTINGS = {
  stability: 0.38,
  similarity_boost: 0.82,
  style: 1,
  speed: 0.86,
  use_speaker_boost: true,
} as const;

/** Crew Talk playback. ElevenLabs voice ids are case-sensitive. */
export const ELEVENLABS_TTS_MODEL = "eleven_v3";

/** Junie Pell only. Thick, slow delivery on the existing voice id. */
export const JUNIE_PELL_VOICE_ID = "tdK8noxHGTBqk6F18tbZ";

export const JUNIE_ELEVEN_VOICE_SETTINGS = {
  stability: 0.15,
  similarity_boost: 0.72,
  style: 1,
  speed: 0.64,
  use_speaker_boost: true,
} as const;

export const CREW_TALK_ELEVEN_VOICES = {
  bodieHale: "XVO6RhOYU9ZEKHFXrx6b",
  titoSolano: "goyf4sY4AqSvMIeO1hb5",
  juniePell: "tdK8noxHGTBqk6F18tbZ",
  pearl: "xDnrPZyqSbomyfOcnNpu",
  sloaneMerritt: "qMmZtYs7EKOOIm0u211n",
} as const;

/** Deterministic ElevenLabs seed for Sloane Merritt. Other crew voices omit seed. */
export const SLOANE_MERRITT_SEED = 50505;

const CREW_TALK_VOICE_IDS = new Set<string>(Object.values(CREW_TALK_ELEVEN_VOICES));

/** Five Crew Talk ids plus Cassian Vale. Client ids outside this set are rejected. */
const ELEVENLABS_SPEAK_ALLOWLIST = new Set<string>([
  ...CREW_TALK_VOICE_IDS,
  CASSIAN_VALE_VOICE_ID,
]);

export function isElevenLabsVoiceId(raw: string): boolean {
  return /^[A-Za-z0-9]{16,30}$/.test(raw);
}

/**
 * ElevenLabs when the client sends an allowlisted voice (five crew ids or Cassian),
 * an eleven_* model, or a provider-shaped id that must be rejected instead of
 * falling through to OpenAI. Built-in OpenAI voice names stay on the OpenAI path.
 */
export function shouldUseElevenLabsSpeak(voice: unknown, model: unknown): boolean {
  const voiceText = typeof voice === "string" ? voice.trim() : "";
  const modelText = typeof model === "string" ? model.trim().toLowerCase() : "";
  if (modelText === ELEVENLABS_TTS_MODEL || modelText.startsWith("eleven_")) return true;
  if (voiceText && ELEVENLABS_SPEAK_ALLOWLIST.has(voiceText)) return true;
  if (voiceText && isElevenLabsVoiceId(voiceText)) return true;
  return false;
}

/** Allowlisted ElevenLabs ids only. Case-sensitive. Unknown ids are not resolved. */
export function resolveElevenLabsVoiceId(voice: unknown): string | null {
  if (typeof voice !== "string") return null;
  const trimmed = voice.trim();
  if (!ELEVENLABS_SPEAK_ALLOWLIST.has(trimmed)) return null;
  return trimmed;
}

/** Any requested model other than eleven_v3 is coerced to eleven_v3. */
export function resolveElevenLabsModel(_model: unknown): string {
  return ELEVENLABS_TTS_MODEL;
}
