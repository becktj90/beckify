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
  translateFallbackDialect,
  translateSystemPrompt,
  translateTargetLanguage,
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

// English <-> Japanese: a real translation path, not a stereotyped-accent
// voice. Verify the prompts ask for an accurate translation and explicitly
// forbid hate speech / slurs, same as every other direction.
assert.equal(resolveTranslateDirection("en", "ja"), "en-to-ja");
assert.equal(resolveTranslateDirection("en-US", "ja-JP"), "en-to-ja");
assert.equal(resolveTranslateDirection("ja", "en"), "ja-to-en");
assert.equal(resolveTranslateDirection("ja-JP", "en-US"), "ja-to-en");
assert.equal(resolveTranslateDirection("ja", "es"), null);
assert.equal(resolveTranslateDirection("ja", "ja"), null);

assert.equal(translateTargetLanguage("en-to-ja"), "ja");
assert.equal(translateTargetLanguage("ja-to-en"), "en");

const jaForwardJobsite = JSON.parse(translateUserPrompt("Where's the breaker?", "en", "jobsite", "en-to-ja"));
assert.equal(jaForwardJobsite.targetLanguage, "ja");
assert.equal(jaForwardJobsite.voiceMode, "jobsite");
const jaJobsitePrompt = translateSystemPrompt("jobsite", "en-to-ja");
assert.match(jaJobsitePrompt, /Japanese/i);
assert.match(jaJobsitePrompt, /real.+translation|not a caricature|not an accent/i);
assert.match(jaJobsitePrompt, /hate speech|protected classes/i);
assert.doesNotMatch(jaJobsitePrompt, /broken English|Engrish/i);

const jaForwardClean = JSON.parse(translateUserPrompt("Hand me that wire.", "en", "clean", "en-to-ja"));
assert.equal(jaForwardClean.targetLanguage, "ja");
assert.equal(jaForwardClean.voiceMode, "clean");
assert.match(translateSystemPrompt("clean", "en-to-ja"), /polite|warm/i);

const jaReverseJobsite = JSON.parse(
  translateUserPrompt("ブレーカーはどこ？", "ja", "jobsite", "ja-to-en"),
);
assert.equal(jaReverseJobsite.targetLanguage, "en");
assert.equal(jaReverseJobsite.sourceLanguage, "ja");
assert.match(translateSystemPrompt("jobsite", "ja-to-en"), /blunt field English/);
assert.match(translateSystemPrompt("jobsite", "ja-to-en"), /hate speech|protected classes/i);

const jaReverseClean = JSON.parse(translateUserPrompt("電源を切って。", "ja", "clean", "ja-to-en"));
assert.equal(jaReverseClean.targetLanguage, "en");
assert.match(translateSystemPrompt("clean", "ja-to-en"), /polished English|clear, polished English/i);

// A dialect label that names the *source* language (Japanese) rather than
// the English output gets stripped to the generic label too, same as
// Spanish-branded labels already do for es-to-en — including a label in the
// source language's own script, which a Latin-alphabet blacklist could never
// catch (this is why the check whitelists "english" rather than blacklisting
// every other language).
assert.equal(englishResponseDialect("jobsite", "japanese_jobsite"), "english_jobsite");
assert.equal(englishResponseDialect("clean", "japan_source_clean"), "english_clean");
assert.equal(englishResponseDialect("jobsite", "日本語_jobsite"), "english_jobsite");
assert.equal(englishResponseDialect("clean", "español_clean"), "english_clean");
assert.equal(englishResponseDialect("jobsite", "english_jobsite"), "english_jobsite");
assert.equal(translateFallbackDialect("en-to-ja", "jobsite"), "japanese_jobsite");
assert.equal(translateFallbackDialect("en-to-ja", "clean"), "japanese_clean");
assert.equal(translateFallbackDialect("ja-to-en", "jobsite"), "english_jobsite");
assert.equal(translateFallbackDialect("en-to-es", "jobsite"), "cuban_florida_jobsite");

console.log("translate-direction.test.cjs: ok");
