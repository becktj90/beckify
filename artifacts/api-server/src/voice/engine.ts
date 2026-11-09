/**
 * Voice-engine provider abstraction for `/api/speak`.
 *
 * Default Crew Talk provider is ElevenLabs (eleven_v3, the shipped character voices).
 * The free, self-hosted Kokoro engine (voice-engine/) stays in the code but is OFF by
 * default after a listening test (Nov 9, 2026): it did not match ElevenLabs quality.
 * Opt in with CREW_VOICE_PROVIDER=kokoro.
 */

import type { CrewVoiceProfile } from "./crewVoices.js";
import { spokenText } from "./crewVoices.js";

export type SpeakFormat = "mp3" | "wav";

export interface VoiceSynthesisRequest {
  text: string;
  format: SpeakFormat;
  profile: CrewVoiceProfile;
  /** Character key, for headers and logs. Never the text. */
  label: string;
}

/** Provider result: a fetch Response so the route can stream-measure first audio chunk. */
export interface VoiceEngine {
  readonly id: "kokoro" | "elevenlabs";
  /** Model label for the X-Beckify-TTS-Model header. */
  readonly model: string;
  synthesize(request: VoiceSynthesisRequest, signal: AbortSignal): Promise<Response>;
}

export class VoiceEngineUnavailableError extends Error {
  constructor(message = "The voice engine is not reachable.") {
    super(message);
    this.name = "VoiceEngineUnavailableError";
  }
}

export const KOKORO_MODEL_LABEL = "kokoro-82m";
export const DEFAULT_VOICE_ENGINE_URL = "http://127.0.0.1:8090";

export function voiceEngineUrl(): string {
  const raw = (process.env["VOICE_ENGINE_URL"] || DEFAULT_VOICE_ENGINE_URL).trim();
  return raw.replace(/\/+$/, "");
}

/** Free engine. Talks to artifacts/voice-engine over HTTP (localhost by default). */
export const kokoroEngine: VoiceEngine = {
  id: "kokoro",
  model: KOKORO_MODEL_LABEL,
  async synthesize(request, signal) {
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    const token = process.env["VOICE_ENGINE_TOKEN"];
    if (token) headers["Authorization"] = `Bearer ${token}`;
    const { profile } = request;
    try {
      return await fetch(`${voiceEngineUrl()}/synthesize`, {
        method: "POST",
        headers,
        signal,
        body: JSON.stringify({
          text: spokenText(request.text, profile),
          lang: profile.lang,
          voices: profile.voices.map(([id, weight]) => [id, weight]),
          speed: profile.speed,
          pitch_semitones: profile.pitchSemitones,
          format: request.format,
        }),
      });
    } catch (error) {
      if (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError")) throw error;
      throw new VoiceEngineUnavailableError();
    }
  },
};

export type CrewVoiceProviderId = "kokoro" | "elevenlabs";

/** CREW_VOICE_PROVIDER: `elevenlabs` (default) or `kokoro` (free, opt-in). */
export function crewVoiceProvider(): CrewVoiceProviderId {
  const raw = (process.env["CREW_VOICE_PROVIDER"] || "").trim().toLowerCase();
  return raw === "kokoro" ? "kokoro" : "elevenlabs";
}

/** Only with CREW_VOICE_PROVIDER=kokoro: CREW_VOICE_FALLBACK=elevenlabs retries a failed engine call on ElevenLabs. */
export function crewVoiceFallback(): CrewVoiceProviderId | null {
  const raw = (process.env["CREW_VOICE_FALLBACK"] || "").trim().toLowerCase();
  return raw === "elevenlabs" ? "elevenlabs" : null;
}

/** TRANSLATOR_VOICE_PROVIDER: `openai` (default, unchanged) or `kokoro` (free). */
export function translatorVoiceProvider(): "openai" | "kokoro" {
  const raw = (process.env["TRANSLATOR_VOICE_PROVIDER"] || "").trim().toLowerCase();
  return raw === "kokoro" ? "kokoro" : "openai";
}
