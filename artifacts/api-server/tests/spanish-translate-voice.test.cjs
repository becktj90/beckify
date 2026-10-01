"use strict";

/**
 * Contract: translate + speak prompts keep the crass Cuban / South Florida jobsite voice.
 * Run: node ./tests/spanish-translate-voice.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..", "src", "prompts");
const translate = fs.readFileSync(path.join(root, "translatePrompt.ts"), "utf8");
const speak = fs.readFileSync(path.join(root, "speakPrompt.ts"), "utf8");

assert.match(translate, /smart-ass/i);
assert.match(translate, /profane|swear freely|workplace cussing/i);
assert.match(translate, /cuban/i);
assert.match(translate, /protected classes|hate/i);
assert.match(translate, /Do NOT produce a sanitized|Do not sanitize/i);
assert.match(speak, /do not beep|sanitize|soften/i);
assert.match(speak, /swear|profanity|vulgarity/i);
assert.match(speak, /cuban|south florida/i);
assert.doesNotMatch(speak, /No hate, no slurs, no mocking/);

console.log("spanish-translate-voice.test.cjs: ok");
