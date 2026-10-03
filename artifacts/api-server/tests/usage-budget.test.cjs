"use strict";

/**
 * AI spend caps: charge/refund, env overrides, IPv6 /64, truncation, retries.
 * Run: node ./tests/usage-budget.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const esbuild = require("esbuild");

async function loadBudget() {
  const result = await esbuild.build({
    absWorkingDir: path.join(__dirname, ".."),
    entryPoints: ["src/lib/usageBudget.ts"],
    bundle: true,
    format: "cjs",
    platform: "node",
    target: "node20",
    write: false,
    external: ["pino"],
    logLevel: "silent",
  });
  const module = { exports: {} };
  const runner = new Function("require", "module", "exports", result.outputFiles[0].text);
  runner(require, module, module.exports);
  return module.exports;
}

async function main() {
  const budget = await loadBudget();
  const {
    chargeBudget,
    refundBudget,
    resetBudgetsForTests,
    clientKeyFromAddress,
    withRetries,
    isRetryableProviderError,
    OutputTruncatedError,
    ProviderStatusError,
    assertNotTruncated,
    textMaxOutputTokens,
    visionMaxOutputTokens,
    budgetLimit,
  } = budget;

  resetBudgetsForTests();
  delete process.env.AI_BUDGET_TEXT;
  assert.equal(budgetLimit("text"), 30);
  assert.equal(budgetLimit("vision"), 5);
  assert.equal(budgetLimit("eleven"), 8000);
  assert.equal(budgetLimit("openai"), 20);
  assert.equal(textMaxOutputTokens(), 1800);
  assert.equal(visionMaxOutputTokens(), 8192);

  process.env.AI_BUDGET_TEXT = "2";
  process.env.AI_TEXT_MAX_OUTPUT_TOKENS = "nope";
  assert.equal(textMaxOutputTokens(), 1800);
  const first = chargeBudget("text", "10.0.0.8", 1, 1_000);
  assert.equal(first.allowed, true);
  assert.equal(chargeBudget("text", "10.0.0.8", 1, 1_000).allowed, true);
  const blocked = chargeBudget("text", "10.0.0.8", 1, 1_000);
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.used, 2);
  refundBudget("text", "10.0.0.8", 1, 1_000);
  assert.equal(chargeBudget("text", "10.0.0.8", 1, 1_000).allowed, true);
  refundBudget("text", "10.0.0.8", 100, 1_000);
  assert.equal(chargeBudget("text", "10.0.0.9", 1, 1_000).allowed, true);
  delete process.env.AI_BUDGET_TEXT;

  assert.equal(clientKeyFromAddress("203.0.113.9"), "203.0.113.9");
  assert.equal(clientKeyFromAddress("::ffff:203.0.113.9"), "203.0.113.9");
  const a = clientKeyFromAddress("2001:db8:1:2:3:4:5:6");
  const b = clientKeyFromAddress("2001:db8:1:2:aaaa:bbbb:cccc:dddd");
  assert.equal(a, b);
  assert.match(a, /::\/64$/);
  assert.notEqual(clientKeyFromAddress("2001:db8:1:3::1"), a);
  assert.equal(clientKeyFromAddress(""), "unknown");

  assert.throws(() => assertNotTruncated("length"), OutputTruncatedError);
  assert.throws(() => assertNotTruncated("max_tokens"), OutputTruncatedError);
  assert.doesNotThrow(() => assertNotTruncated("stop"));
  assert.equal(isRetryableProviderError(new OutputTruncatedError()), false);
  assert.equal(isRetryableProviderError(new ProviderStatusError(503)), true);
  assert.equal(isRetryableProviderError(new ProviderStatusError(400)), false);

  let calls = 0;
  const value = await withRetries(async () => {
    calls += 1;
    if (calls < 3) throw new ProviderStatusError(503);
    return "ok";
  }, { attempts: 3, delayMs: 0 });
  assert.equal(value, "ok");
  assert.equal(calls, 3);
  await assert.rejects(
    () => withRetries(async () => { throw new OutputTruncatedError(); }, { attempts: 3, delayMs: 0 }),
    OutputTruncatedError,
  );

  const src = path.join(__dirname, "..", "src");
  const speak = fs.readFileSync(path.join(src, "routes", "speak.ts"), "utf8");
  const translate = fs.readFileSync(path.join(src, "routes", "translate.ts"), "utf8");
  const review = fs.readFileSync(path.join(src, "routes", "review-calculation.ts"), "utf8");
  const vision = fs.readFileSync(path.join(src, "lib", "visionClient.ts"), "utf8");
  const look = fs.readFileSync(path.join(src, "routes", "analyze-look.ts"), "utf8");
  const tdr = fs.readFileSync(path.join(src, "routes", "analyze-tdr.ts"), "utf8");
  const prompt = fs.readFileSync(path.join(src, "prompts", "speakPrompt.ts"), "utf8");
  assert.match(speak, /MAX_REQUESTS_PER_WINDOW = 20/);
  assert.match(translate, /MAX_REQUESTS_PER_WINDOW = 30/);
  assert.match(prompt, /LOOK_CHECK_SPEAK_MAX_CHARS = 900/);
  assert.match(review, /Object\.assign\(bucket/);
  assert.doesNotMatch(review, /return \{ \.\.\.bucket/);
  assert.match(review, /getClientKey/);
  assert.match(vision, /beginSharedVisionRequest/);
  assert.match(vision, /clientKeyFromAddress/);
  assert.match(look, /beginSharedVisionRequest/);
  assert.match(tdr, /beginSharedVisionRequest/);
  assert.doesNotMatch(look, /const rateBuckets/);
  assert.match(speak, /chargeBudget/);
  assert.match(translate, /chargeBudget\("text"/);

  console.log("usage-budget.test.cjs: ok");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
