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

export function speakDefaultVoiceForMode(mode: TranslateVoiceMode): string {
  return mode === "clean" ? SPEAK_CLEAN_VOICE : SPEAK_DEFAULT_VOICE;
}

export function speakVoiceInstructions(mode: TranslateVoiceMode): string {
  return mode === "clean" ? SPEAK_CLEAN_VOICE_INSTRUCTIONS : SPEAK_JOBSITE_VOICE_INSTRUCTIONS;
}

export function speakSupportsInstructions(model: string): boolean {
  const name = (model || "").toLowerCase();
  return name.includes("gpt-4o-mini-tts") || name.includes("gpt-4o-tts");
}
