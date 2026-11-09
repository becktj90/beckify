/**
 * OPTIONAL, PAID, OFF BY DEFAULT. Kept only as a rollback switch.
 * Used when CREW_VOICE_PROVIDER=elevenlabs, or CREW_VOICE_FALLBACK=elevenlabs after the
 * free engine fails. Needs ELEVENLABS_API_KEY. Nothing in Beckify requires it.
 */

import {
  BODIE_ELEVEN_VOICE_SETTINGS,
  BODIE_HALE_VOICE_ID,
  CREW_TALK_ELEVEN_VOICES,
  ELEVENLABS_TTS_MODEL,
  JUNIE_ELEVEN_VOICE_SETTINGS,
  JUNIE_PELL_VOICE_ID,
  SLOANE_MERRITT_SEED,
  resolveElevenLabsVoiceId,
} from "../prompts/speakPrompt.js";
import { MissingProviderKeyError } from "../lib/visionClient.js";
import type { CrewVoiceKey } from "./crewVoices.js";
import type { SpeakFormat } from "./engine.js";

/** ElevenLabs id for a character, preferring the exact allowlisted id the client sent. */
export function elevenVoiceIdFor(key: CrewVoiceKey, rawVoice: string): string | null {
  const sent = resolveElevenLabsVoiceId(rawVoice);
  if (sent) return sent;
  if (key === "humbertoArismendiEnglish") return CREW_TALK_ELEVEN_VOICES.humbertoArismendi;
  if (key === "cassianVale") return null;
  return CREW_TALK_ELEVEN_VOICES[key];
}

export async function synthesizeElevenLabs(
  text: string,
  voiceId: string,
  format: SpeakFormat,
  signal: AbortSignal,
): Promise<Response> {
  const apiKey = process.env["ELEVENLABS_API_KEY"];
  if (!apiKey) {
    throw new MissingProviderKeyError("ELEVENLABS_API_KEY");
  }
  const voiceSettings = elevenVoiceSettings(voiceId);
  const seed = pickSpeakSeed(voiceId);
  const outputFormat = format === "wav" ? "wav_44100" : "mp3_44100_128";
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=${outputFormat}`;
  return fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: format === "wav" ? "audio/wav" : "audio/mpeg",
      "xi-api-key": apiKey,
    },
    signal,
    body: JSON.stringify({
      text,
      model_id: ELEVENLABS_TTS_MODEL,
      ...(voiceSettings ? { voice_settings: voiceSettings } : {}),
      ...(seed != null ? { seed } : {}),
    }),
  });
}

/**
 * Bodie and Junie presets stay server-side.
 * Client stability, similarity, style, and speed are ignored.
 */
function elevenVoiceSettings(voiceId: string): Record<string, number | boolean> | undefined {
  const preset = voiceId === BODIE_HALE_VOICE_ID
    ? BODIE_ELEVEN_VOICE_SETTINGS
    : voiceId === JUNIE_PELL_VOICE_ID
      ? JUNIE_ELEVEN_VOICE_SETTINGS
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

/** Seed only for Sloane (50505). Client seed is ignored. */
function pickSpeakSeed(voiceId: string): number | undefined {
  if (voiceId === CREW_TALK_ELEVEN_VOICES.sloaneMerritt) return SLOANE_MERRITT_SEED;
  return undefined;
}
