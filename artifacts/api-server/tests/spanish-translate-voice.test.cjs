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

console.log("spanish-translate-voice.test.cjs: ok");
