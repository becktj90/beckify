/** Cuban / South Florida jobsite yell instructions for OpenAI `/v1/audio/speech`. */

/** Deep male-ish built-in voice (onyx > echo > alloy for projection). */
export const SPEAK_DEFAULT_VOICE = "onyx";

/**
 * Prefer gpt-4o-mini-tts so `instructions` apply (Cuban yell energy).
 * Override with TTS_MODEL=tts-1 when chasing the absolute cheapest path
 * (tts-1 ignores instructions).
 */
export const SPEAK_DEFAULT_MODEL = "gpt-4o-mini-tts";

export const SPEAK_MAX_INPUT_CHARS = 500;

export const SPEAK_VOICE_INSTRUCTIONS = `Speak like a real Cuban / South Florida construction guy yelling across a noisy jobsite — loud, clear, projected so someone on a scaffold can hear you. Warm Cuban-American Florida Spanish cadence. Deep male coworker energy: blunt, cocky, urgent when the words are urgent. Deliver every swear word and dirty slang in the text fully and naturally — do not beep, skip, soften, whisper, or sanitize profanity or sexual vulgarity. Workplace cussing and insult-as-banter should land hard and clear. Not a studio whisper, not a cartoon, not Castilian Spain, not a mocking caricature accent. Never invent hate slurs aimed at protected classes; if the text has ordinary jobsite swearing, speak it. Keep the pace intelligible over site noise: a touch slower than rapid Miami chatter, still energetic and projected.`;

export function speakSupportsInstructions(model: string): boolean {
  const name = (model || "").toLowerCase();
  return name.includes("gpt-4o-mini-tts") || name.includes("gpt-4o-tts");
}
