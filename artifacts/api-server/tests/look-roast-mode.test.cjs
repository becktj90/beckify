'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

const promptPath = path.join(__dirname, '..', 'src', 'prompts', 'lookVisionPrompt.ts');
const routePath = path.join(__dirname, '..', 'src', 'routes', 'analyze-look.ts');
const visionPath = path.join(__dirname, '..', 'src', 'lib', 'visionClient.ts');
const prompt = fs.readFileSync(promptPath, 'utf8');
const route = fs.readFileSync(routePath, 'utf8');
const vision = fs.readFileSync(visionPath, 'utf8');

assert.match(prompt, /export type LookRoastMode = "mean" \| "nice" \| "bro"/);
assert.match(prompt, /surprise/);
assert.match(prompt, /resolveLookRoastMode/);
assert.match(prompt, /lookAssessmentSystemPrompt/);
assert.match(prompt, /lookComedySystemPrompt/);
assert.match(prompt, /LOOK_COMEDY_TEMPERATURE/);
assert.match(prompt, /mergeLookAssessmentWithComedy/);
assert.match(prompt, /outfit/);
assert.match(prompt, /brutal/);
assert.match(prompt, /under 18/);
assert.match(prompt, /No sexual or graphic content/);
assert.match(prompt, /never hate speech|Never attack race/i);
assert.match(prompt, /attractiveness|beauty/);
assert.doesNotMatch(prompt, /Never be cruel/);
assert.doesNotMatch(prompt, /Prefer kind-honest/);

assert.match(route, /resolveLookRoastMode\(body\.roastMode/);
assert.match(route, /roastMode,/);
assert.match(route, /mergeLookAssessmentWithComedy/);
assert.match(route, /lookAssessmentSystemPrompt/);
assert.match(route, /runComedy/);
assert.match(route, /LOOK_COMEDY_TEMPERATURE/);

assert.match(vision, /analyzeTextWithOpenAI/);
assert.match(vision, /analyzeTextWithAnthropic/);
assert.match(vision, /temperature\?: number/);

// Execute merge + resolve helpers via transpile (no build step required).
const transpiled = ts.transpileModule(prompt, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;
const promptModule = { exports: {} };
// eslint-disable-next-line no-new-func
Function('exports', 'module', 'require', transpiled)(promptModule.exports, promptModule, require);
const {
  resolveLookRoastMode,
  mergeLookAssessmentWithComedy,
  LOOK_ASSESSMENT_TEMPERATURE,
  LOOK_COMEDY_TEMPERATURE,
} = promptModule.exports;

assert.equal(LOOK_ASSESSMENT_TEMPERATURE, 0);
assert.ok(LOOK_COMEDY_TEMPERATURE > 0 && LOOK_COMEDY_TEMPERATURE < 1.05);

assert.equal(resolveLookRoastMode('mean'), 'mean');
assert.equal(resolveLookRoastMode('NICE'), 'nice');
assert.equal(resolveLookRoastMode('bro'), 'bro');
assert.equal(resolveLookRoastMode(undefined), 'bro');
assert.equal(resolveLookRoastMode('surprise', () => 0.1), 'mean');
assert.equal(resolveLookRoastMode('surprise', () => 0.9), 'nice');

const merged = mergeLookAssessmentWithComedy(
  {
    verdict: 'looks_good',
    score: 91,
    headline: 'Strong frame.',
    summary: 'Light and framing work.',
    roast: 'IGNORED ASSESSMENT ROAST',
    metrics: { lighting: 90, framing: 88, expression: 80, sharpness: 92, outfit: 70, overall: 91 },
    reasons: ['Good sidelight'],
    fixes: ['Step one foot left', 'Chin slightly down'],
    photo_notes: ['Phone JPEG'],
    warnings: [],
  },
  { roast: 'This fit is committing vehicular manslaughter on blandness, you absolute menace.', score: 1, verdict: 'looks_bad' },
);

assert.equal(merged.verdict, 'looks_good');
assert.equal(merged.score, 91);
assert.equal(merged.metrics.outfit, 70);
assert.equal(merged.metrics.lighting, 90);
assert.match(merged.roast, /vehicular manslaughter/);
assert.deepEqual(merged.fixes, ['Step one foot left', 'Chin slightly down']);

const declined = mergeLookAssessmentWithComedy(
  { verdict: 'declined', score: 50, metrics: { lighting: 10 }, roast: 'nope' },
  { roast: 'should clear' },
);
assert.equal(declined.roast, '');
assert.equal(declined.score, null);
assert.equal(declined.metrics.lighting, null);

console.log('look roast-mode prompt + route + merge contract passed');
