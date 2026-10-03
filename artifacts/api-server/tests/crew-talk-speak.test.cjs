"use strict";

/**
 * Crew Talk speak routes ElevenLabs voice ids / eleven_v3 without embedding a key.
 * Run: node ./tests/crew-talk-speak.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const src = path.join(__dirname, "..", "src");
const speakRoute = fs.readFileSync(path.join(src, "routes", "speak.ts"), "utf8");
const speakPrompt = fs.readFileSync(path.join(src, "prompts", "speakPrompt.ts"), "utf8");

assert.match(speakPrompt, /ELEVENLABS_TTS_MODEL = "eleven_v3"/);
assert.match(speakPrompt, /bodieHale: "XVO6RhOYU9ZEKHFXrx6b"/);
assert.match(speakPrompt, /titoSolano: "goyf4sY4AqSvMIeO1hb5"/);
assert.match(speakPrompt, /juniePell: "tdK8noxHGTBqk6F18tbZ"/);
assert.match(speakPrompt, /pearl: "xDnrPZyqSbomyfOcnNpu"/);
assert.match(speakPrompt, /sloaneMerritt: "qMmZtYs7EKOOIm0u211n"/);
assert.match(speakPrompt, /shouldUseElevenLabsSpeak/);
assert.match(speakPrompt, /resolveElevenLabsVoiceId/);

assert.match(speakRoute, /ELEVENLABS_API_KEY/);
assert.match(speakRoute, /api\.elevenlabs\.io\/v1\/text-to-speech/);
assert.match(speakRoute, /model_id: model/);
assert.match(speakRoute, /voice_settings/);
assert.match(speakPrompt, /JUNIE_PELL_VOICE_ID = "tdK8noxHGTBqk6F18tbZ"/);
assert.match(speakPrompt, /stability: 0\.15/);
assert.match(speakPrompt, /similarity_boost: 0\.72/);
assert.match(speakPrompt, /style: 1/);
assert.match(speakPrompt, /speed: 0\.64/);
assert.match(speakRoute, /JUNIE_ELEVEN_VOICE_SETTINGS/);
assert.match(speakPrompt, /BODIE_HALE_VOICE_ID = "XVO6RhOYU9ZEKHFXrx6b"/);
assert.match(speakPrompt, /stability: 0,/);
assert.match(speakPrompt, /similarity_boost: 0\.75/);
assert.match(speakPrompt, /style: 0\.8/);
assert.match(speakPrompt, /speed: 0\.9/);
assert.match(speakPrompt, /CrewTalkMember\.voiceID/);
assert.match(speakRoute, /BODIE_ELEVEN_VOICE_SETTINGS/);

assert.match(speakRoute, /shouldUseElevenLabsSpeak/);
assert.match(speakRoute, /https:\/\/api\.openai\.com\/v1\/audio\/speech/);
assert.match(speakRoute, /OPENAI_API_KEY/);

assert.doesNotMatch(speakRoute, /sk_[A-Za-z0-9]{8,}/);
assert.doesNotMatch(speakRoute, /xi-api-key":\s*"[^"]+"/);
assert.doesNotMatch(speakPrompt, /sk_[A-Za-z0-9]{8,}/);

const banned = ["comedy", "stoner", "smart-ass", "florida", "profanity"];
const crewBlock = speakPrompt.slice(speakPrompt.indexOf("CREW_TALK_ELEVEN_VOICES"));
for (const word of banned) {
  assert.equal(crewBlock.toLowerCase().includes(word), false, word);
}

console.log("crew-talk-speak.test.cjs: ok");
