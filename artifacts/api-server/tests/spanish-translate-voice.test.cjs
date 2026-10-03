"use strict";

/**
 * Contract: translate + speak prompts keep Jobsite (rough) and Clean (polished) modes.
 * Run: node ./tests/spanish-translate-voice.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..", "src", "prompts");
const translate = fs.readFileSync(path.join(root, "translatePrompt.ts"), "utf8");
const speak = fs.readFileSync(path.join(root, "speakPrompt.ts"), "utf8");

assert.match(translate, /TranslateVoiceMode/);
assert.match(translate, /TRANSLATE_JOBSITE_SYSTEM_PROMPT/);
assert.match(translate, /TRANSLATE_CLEAN_SYSTEM_PROMPT/);
assert.match(translate, /smart-ass/i);
assert.match(translate, /profane|swear freely|workplace cussing/i);
assert.match(translate, /elegant|polished|warm/i);
assert.match(translate, /No swearing|no dirty slang|never crude/i);
assert.match(translate, /protected classes|hate/i);
assert.match(speak, /SPEAK_JOBSITE_VOICE_INSTRUCTIONS|SPEAK_CLEAN_VOICE_INSTRUCTIONS/);
assert.match(speak, /do not beep|sanitize|soften/i);
assert.match(speak, /polished|elegant|warm/i);
assert.match(speak, /speakDefaultVoiceForMode|SPEAK_CLEAN_VOICE/);


assert.match(translate, /Oye|Mira|Esp[eé]rate|attention-getters/i);
assert.match(translate, /Disculpe|Permiso|Un momento|polite polished attention/i);
assert.match(translate, /TRANSLATE_ES_EN_JOBSITE_SYSTEM_PROMPT/);
assert.match(translate, /TRANSLATE_ES_EN_CLEAN_SYSTEM_PROMPT/);
assert.match(translate, /resolveTranslateDirection/);
assert.match(translate, /blunt field English/i);
assert.match(translate, /polished English|clear, polished English/i);
assert.match(translate, /english_jobsite|field_english_jobsite/);
assert.match(translate, /english_clean|clear_english_clean/);
assert.match(speak, /normalizeSpeakLanguage/);
assert.match(speak, /SPEAK_EN_JOBSITE_VOICE_INSTRUCTIONS/);
assert.match(speak, /SPEAK_EN_CLEAN_VOICE_INSTRUCTIONS/);
assert.match(speak, /SPEAK_DEEP_SOUTH_VOICE_INSTRUCTIONS/);
assert.match(speak, /SPEAK_EN_CALIFORNIA_VOICE = "echo"/);
assert.match(speak, /SPEAK_DEEP_SOUTH_VOICE = "ballad"/);
assert.match(speak, /SPEAK_DEFAULT_MODEL = "gpt-4o-mini-tts"/);
assert.match(speak, /California/);
assert.match(speak, /Deep South/);
assert.match(speak, /not a stoner/i);
assert.match(speak, /not a surfer cartoon/i);
assert.match(speak, /language: SpeakLanguage = "es"/);
assert.doesNotMatch(speak, /Cheech|Spicoli|Cheech and Chong/i);

// Japanese speak path: a real third language, not silently mapped to Spanish.
assert.match(speak, /SpeakLanguage = "en" \| "es" \| "ja"/);
assert.match(speak, /SPEAK_JA_JOBSITE_VOICE_INSTRUCTIONS/);
assert.match(speak, /SPEAK_JA_CLEAN_VOICE_INSTRUCTIONS/);
assert.match(speak, /if \(primary === "ja"\) return "ja";/);
assert.match(speak, /not an accent impression|not a mocking caricature/i);

{
  const block = speak.match(/export const SPEAK_JOBSITE_VOICE_INSTRUCTIONS = `([\s\S]*?)`;/)[1];
  assert.match(block, /fifty years of cigarettes/i);
  assert.match(block, /gravel|rasp/i);
  assert.match(block, /South American/i);
  assert.match(block, /numbers, units/i);
  assert.match(block, /Do not add words/i);
  assert.match(block, /Preserve the text and its meaning/i);
  assert.match(block, /not slapstick|never slapstick/i);
}
for (const name of ["SPEAK_EN_CLEAN_VOICE_INSTRUCTIONS", "SPEAK_EN_JOBSITE_VOICE_INSTRUCTIONS", "SPEAK_DEEP_SOUTH_VOICE_INSTRUCTIONS"]) {
  const block = speak.match(new RegExp("export const " + name + " = `([\\s\\S]*?)`;"))[1];
  assert.match(block, /Read the supplied English text exactly/i);
  assert.match(block, /Do not add words/i);
  assert.match(block, /Preserve the text and its meaning/i);
  assert.match(block, /numbers, units/i);
  assert.match(block, /slur/i);
  assert.doesNotMatch(block, /word-swap bit that replaces/i);
}
const california = speak.match(/export const SPEAK_EN_CLEAN_VOICE_INSTRUCTIONS = `([\s\S]*?)`;/)[1];
const deepSouth = speak.match(/export const SPEAK_DEEP_SOUTH_VOICE_INSTRUCTIONS = `([\s\S]*?)`;/)[1];
assert.match(california, /West Coast|California/i);
assert.match(deepSouth, /Deep South/i);
assert.notEqual(california, deepSouth);
assert.match(speak, /if \(mode === "deepSouth"\) return SPEAK_DEEP_SOUTH_VOICE_INSTRUCTIONS/);


{
  const jobsite = translate.match(/export const TRANSLATE_JOBSITE_SYSTEM_PROMPT = `([\s\S]*?)`;/)[1];
  const clean = translate.match(/export const TRANSLATE_CLEAN_SYSTEM_PROMPT = `([\s\S]*?)`;/)[1];
  assert.match(jobsite, /Maximum allowed profanity/i);
  assert.match(jobsite, /at least two of/i);
  assert.match(jobsite, /coño/);
  assert.match(jobsite, /swear freely/i);
  assert.match(jobsite, /protected classes|hate/i);
  assert.match(clean, /No swearing|never crude/i);
  assert.doesNotMatch(clean, /Maximum allowed profanity/i);
  assert.doesNotMatch(clean, /at least two of/i);
  for (const name of [
    "TRANSLATE_ES_EN_JOBSITE_SYSTEM_PROMPT",
    "TRANSLATE_EN_JA_JOBSITE_SYSTEM_PROMPT",
    "TRANSLATE_JA_EN_JOBSITE_SYSTEM_PROMPT",
  ]) {
    const block = translate.match(new RegExp("export const " + name + " = `([\\s\\S]*?)`;"))[1];
    assert.doesNotMatch(block, /Maximum allowed profanity/i);
    assert.doesNotMatch(block, /at least two of/i);
  }
}

console.log("spanish-translate-voice.test.cjs: ok");
