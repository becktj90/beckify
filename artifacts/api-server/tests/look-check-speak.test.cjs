'use strict';

/**
 * Look Check roast speech: Cassian Vale on ElevenLabs via /api/speak.
 * The provider key stays in the environment. Run: node ./tests/look-check-speak.test.cjs
 */

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const src = path.join(__dirname, '..', 'src');
const speakRoute = fs.readFileSync(path.join(src, 'routes', 'speak.ts'), 'utf8');
const speakPrompt = fs.readFileSync(path.join(src, 'prompts', 'speakPrompt.ts'), 'utf8');
const lookPrompt = fs.readFileSync(path.join(src, 'prompts', 'lookVisionPrompt.ts'), 'utf8');

assert.match(speakPrompt, /CASSIAN_VALE_VOICE_ID = "uYsaRSYDSuxmtyipO9Qt"/);
assert.match(speakPrompt, /CASSIAN_VALE_SEED = 60606/);
assert.match(speakPrompt, /LOOK_CHECK_SPEAK_MAX_CHARS = 1500/);
assert.match(speakPrompt, /stability: 0\.38/);
assert.match(speakPrompt, /similarity_boost: 0\.82/);
assert.match(speakPrompt, /style: 1/);
assert.match(speakPrompt, /speed: 0\.86/);
assert.match(speakRoute, /CASSIAN_VALE_VOICE_ID/);
assert.match(speakRoute, /pickSpeakSeed/);
assert.match(speakRoute, /seed != null \? \{ seed \}/);
assert.match(speakRoute, /ELEVENLABS_API_KEY/);
assert.doesNotMatch(speakRoute, /sk_[A-Za-z0-9]{8,}/);
assert.doesNotMatch(speakRoute, /xi-api-key":\s*"[^"]+"/);
assert.doesNotMatch(speakPrompt, /sk_[A-Za-z0-9]{8,}/);

assert.match(lookPrompt, /filthy-sweet/);
assert.match(lookPrompt, /No slurs/);
assert.match(lookPrompt, /No threats/);
assert.match(lookPrompt, /No sexual or graphic content/);
assert.match(lookPrompt, /under 18/);
assert.match(lookPrompt, /declined or no_person/);
assert.match(lookPrompt, /lookScore/);
assert.match(lookPrompt, /Do not mention lookScore/);

console.log('look-check-speak.test.cjs: ok');
