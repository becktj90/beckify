const assert = require("assert");
const fs = require("fs");
const path = require("path");

const src = fs.readFileSync(
  path.resolve(__dirname, "../src/lib/panelVisionValidate.ts"),
  "utf8",
);
assert.match(src, /loadAmps[\s\S]*value: null/);
assert.match(src, /Incomplete coverage/);
assert.match(src, /rememberIdempotent/);
assert.match(src, /panelVisionMetrics/);
assert.match(src, /withRetries/);

const route = fs.readFileSync(
  path.resolve(__dirname, "../src/routes/analyze-panel.ts"),
  "utf8",
);
assert.match(route, /validatePanelVisionAnalysis/);
assert.match(route, /idempotencyKey/);
assert.match(route, /server-controlled|void body\.provider/);
assert.match(route, /withRetries/);
assert.match(route, /panelVisionMetrics/);
assert.doesNotMatch(route, /console\.error\("Panel vision provider request failed", error\)/);

const prompt = fs.readFileSync(
  path.resolve(__dirname, "../src/prompts/panelVisionPrompt.ts"),
  "utf8",
);
assert.match(prompt, /busAmps/);
assert.match(prompt, /feederAmps/);

console.log("panel-vision-validate ok");
