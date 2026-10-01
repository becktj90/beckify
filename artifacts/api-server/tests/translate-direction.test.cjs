"use strict";

/**
 * Pair validation for /api/translate. Defaults stay English → Spanish.
 * Loads the TypeScript prompt module through esbuild so Node 20 CI can run it.
 * Run: node ./tests/translate-direction.test.cjs
 */

const assert = require("node:assert/strict");
const esbuild = require("esbuild");
const path = require("node:path");

function loadPromptModule() {
  const result = esbuild.buildSync({
    entryPoints: [path.join(__dirname, "..", "src", "prompts", "translatePrompt.ts")],
    bundle: true,
    format: "cjs",
    platform: "node",
    write: false,
  });
  const mod = { exports: {} };
  const run = new Function("module", "exports", "require", result.outputFiles[0].text);
  run(mod, mod.exports, require);
  return mod.exports;
}

const {
  englishResponseDialect,
  resolveTranslateDirection,
  translateSystemPrompt,
  translateUserPrompt,
} = loadPromptModule();

assert.equal(resolveTranslateDirection("en", "es"), "en-to-es");
assert.equal(resolveTranslateDirection("en-US", "es-MX"), "en-to-es");
assert.equal(resolveTranslateDirection("EN", "es_419"), "en-to-es");
assert.equal(resolveTranslateDirection("es", "en"), "es-to-en");
assert.equal(resolveTranslateDirection("es-US", "en-US"), "es-to-en");
assert.equal(resolveTranslateDirection("es_MX", "en"), "es-to-en");

assert.equal(resolveTranslateDirection("es", "es"), null);
assert.equal(resolveTranslateDirection("en", "en"), null);
assert.equal(resolveTranslateDirection("es", "fr"), null);
assert.equal(resolveTranslateDirection("fr", "en"), null);
assert.equal(resolveTranslateDirection("en", "estonian"), null);
assert.equal(resolveTranslateDirection("english", "spanish"), null);
assert.equal(resolveTranslateDirection("de", "es"), null);

const forward = JSON.parse(translateUserPrompt("Where's the breaker?", "en", "jobsite"));
assert.equal(forward.targetLanguage, "es");
assert.equal(forward.voiceMode, "jobsite");
assert.match(translateSystemPrompt("jobsite"), /Spanish/i);
assert.doesNotMatch(translateSystemPrompt("jobsite"), /blunt field English/);

const reverseJobsite = JSON.parse(
  translateUserPrompt("¿Dónde está el breaker?", "es-US", "jobsite", "es-to-en"),
);
assert.equal(reverseJobsite.targetLanguage, "en");
assert.equal(reverseJobsite.sourceLanguage, "es-US");
assert.equal(reverseJobsite.voiceMode, "jobsite");
assert.match(reverseJobsite.style, /blunt_field_english/);
assert.match(translateSystemPrompt("jobsite", "es-to-en"), /blunt field English/);
assert.match(translateSystemPrompt("jobsite", "es-to-en"), /hate speech|protected classes/i);

const reverseClean = JSON.parse(translateUserPrompt("Corta la corriente.", "es", "clean", "es-to-en"));
assert.equal(reverseClean.targetLanguage, "en");
assert.equal(reverseClean.voiceMode, "clean");
assert.match(translateSystemPrompt("clean", "es-to-en"), /polished English|clear, polished English/i);
assert.match(translateSystemPrompt("clean", "es-to-en"), /No swearing|without cussing/i);

assert.equal(englishResponseDialect("jobsite", ""), "english_jobsite");
assert.equal(englishResponseDialect("clean", "cuban_florida_clean"), "english_clean");
assert.equal(englishResponseDialect("jobsite", "english_jobsite"), "english_jobsite");
assert.equal(englishResponseDialect("clean", "clear_english_clean"), "clear_english_clean");

console.log("translate-direction.test.cjs: ok");
