'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const promptPath = path.join(__dirname, '..', 'src', 'prompts', 'lookVisionPrompt.ts');
const routePath = path.join(__dirname, '..', 'src', 'routes', 'analyze-look.ts');
const prompt = fs.readFileSync(promptPath, 'utf8');
const route = fs.readFileSync(routePath, 'utf8');

assert.match(prompt, /export type LookRoastMode = "mean" \| "nice" \| "bro"/);
assert.match(prompt, /parseLookRoastMode/);
assert.match(prompt, /lookVisionSystemPrompt/);
assert.match(prompt, /lookVisionMaxTokens/);
assert.match(prompt, /BroGPT/);
assert.match(prompt, /several sentences/);
assert.match(prompt, /under 18/);
assert.match(prompt, /No sexual or graphic content/);
assert.match(prompt, /never hate speech/);
assert.match(prompt, /not protected traits/);
assert.doesNotMatch(prompt, /Never be cruel/);
assert.doesNotMatch(prompt, /Prefer kind-honest/);

assert.match(route, /parseLookRoastMode\(body\.roastMode/);
assert.match(route, /roastMode,/);
assert.match(route, /lookVisionMaxTokens/);

console.log('look roast-mode prompt + route contract passed');
