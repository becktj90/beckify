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
assert.match(speak, /surfer|stoner/i);
assert.match(speak, /California|West Coast|SoCal/i);
assert.match(speak, /SPEAK_EN_VOICE|onyx/);
assert.match(speak, /not a cartoon surfer|not Spicoli|not.*corporate/i);
assert.match(speak, /dude|man energy|drawl|mellow/i);
assert.match(speak, /language: "en" \| "es" = "es"/);
console.log("spanish-translate-voice.test.cjs: ok");
