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

export const SPEAK_JOBSITE_VOICE_INSTRUCTIONS = `Speak like a real Cuban / South Florida construction guy yelling across a noisy jobsite — loud, clear, projected so someone on a scaffold can hear you. Warm Cuban-American Florida Spanish cadence. Deep male coworker energy: blunt, cocky, urgent when the words are urgent. Deliver every swear word and dirty slang in the text fully and naturally — do not beep, skip, soften, whisper, or sanitize profanity or sexual vulgarity. Workplace cussing and insult-as-banter should land hard and clear. Not a studio whisper, not a cartoon, not Castilian Spain, not a mocking caricature accent. Never invent hate slurs aimed at protected classes; if the text has ordinary jobsite swearing, speak it. Keep the pace intelligible over site noise: a touch slower than rapid Miami chatter, still energetic and projected.`;

export const SPEAK_CLEAN_VOICE_INSTRUCTIONS = `Speak like a polished Cuban / South Florida woman — warm, elegant, clear, and kind. Soft feminine Cuban-American Florida Spanish cadence with graceful confidence. Project enough to be heard, but never yell like a jobsite. Refined and welcoming — not crude, not sarcastic, not a cartoon, not Castilian Spain, not a mocking caricature accent. Do not invent swearing; if the text is already clean, keep it clean and musical. Never invent hate slurs. Pace is clear and unhurried, still lively and warm.`;

/** @deprecated Prefer speakVoiceInstructions(mode). */
export const SPEAK_VOICE_INSTRUCTIONS = SPEAK_JOBSITE_VOICE_INSTRUCTIONS;

export function speakVoiceMode(raw: unknown): TranslateVoiceMode {
  return normalizeTranslateVoiceMode(raw);
}

/** Male lower voice for Spanish → English (California stoner path). */
export const SPEAK_EN_VOICE = "onyx";

/** Japanese delivery reuses the same built-in voices as Spanish, distinguished by `instructions`. */
export const SPEAK_JA_JOBSITE_VOICE = SPEAK_DEFAULT_VOICE;
export const SPEAK_JA_CLEAN_VOICE = SPEAK_CLEAN_VOICE;

export type SpeakLanguage = "en" | "es" | "ja";

/**
 * Spanish and Japanese delivery both follow Clean (nova) / Jobsite (onyx).
 * English delivery always uses the male California stoner voice (`onyx`) — not nova.
 */
export function speakDefaultVoiceForMode(
  mode: TranslateVoiceMode,
  language: SpeakLanguage = "es",
): string {
  if (language === "en") return SPEAK_EN_VOICE;
  return mode === "clean" ? SPEAK_CLEAN_VOICE : SPEAK_DEFAULT_VOICE;
}

/**
 * Classic California stoner dude English for Spanish → English
 * (mellow drawl, dude/man energy). Not corporate. Not a cartoon. Still clear.
 * Do not put trademark character names in user-visible UI copy.
 */
export const SPEAK_EN_JOBSITE_VOICE_INSTRUCTIONS = `Speak like a classic California stoner dude — deep mellow male drawl, lazy SoCal cadence, “dude / man” energy, warm and stoney, still clear on a jobsite. Slow and easy: stretch vowels a touch, never rush, never clip words. Think van-in-the-lot after a session, not a tech-campus corporate California accent, not Midwestern, not Southern, not New York, not British. Deliver swearing already in the text fully; do not add words, do not beep, and do not invent slurs or hate speech. Not a cartoon surfer parody, not Spicoli overacting, not a whisper, not a Spanish accent on English. Intelligible first — mellow, not mushy.`;

/** Same California surfer-stoner male for Clean mode English; a touch softer, still not corporate. */
export const SPEAK_EN_CLEAN_VOICE_INSTRUCTIONS = `Speak like a classic California stoner dude — deep mellow male drawl, lazy SoCal cadence, warm “dude / man” energy, a little stoney but friendly. Soft projection for a room; still slow and easy, never rushed. Not a tech-campus corporate California accent, not Midwestern, not Southern, not New York, not British. Do not add swearing. Do not invent slurs. Not a cartoon surfer parody, not Spicoli overacting, not a whisper, not a Spanish accent on English. Clear and understandable with that mellow California stoner vibe.`;

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

export function speakVoiceInstructions(mode: TranslateVoiceMode, language: SpeakLanguage = "es"): string {
  if (language === "en") {
    return mode === "clean" ? SPEAK_EN_CLEAN_VOICE_INSTRUCTIONS : SPEAK_EN_JOBSITE_VOICE_INSTRUCTIONS;
  }
  if (language === "ja") {
    return mode === "clean" ? SPEAK_JA_CLEAN_VOICE_INSTRUCTIONS : SPEAK_JA_JOBSITE_VOICE_INSTRUCTIONS;
  }
  return mode === "clean" ? SPEAK_CLEAN_VOICE_INSTRUCTIONS : SPEAK_JOBSITE_VOICE_INSTRUCTIONS;
}

export function speakSupportsInstructions(model: string): boolean {
  const name = (model || "").toLowerCase();
  return name.includes("gpt-4o-mini-tts") || name.includes("gpt-4o-tts");
}
