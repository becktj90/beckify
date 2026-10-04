"use strict";

/**
 * WP-0A: timing logs must not change translate/speak responses or echo text.
 * No latency thresholds. Run: node ./tests/route-timing.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const esbuild = require("esbuild");

const SOURCE_TOKEN = "WP0A_SOURCE_TOKEN";
const TARGET_TOKEN = "WP0A_TARGET_TOKEN";
const SPEAK_TOKEN = "WP0A_SPEAK_TOKEN";
const AUDIO = Buffer.from([0x49, 0x44, 0x33, 0x04, 0x00, 0x00]);

function loadApp() {
  const entry = path.join(
    os.tmpdir(),
    `beckify-route-timing-${process.pid}.mjs`,
  );
  const root = path.join(__dirname, "..", "src");
  fs.writeFileSync(
    entry,
    `
import translateRouter from ${JSON.stringify(path.join(root, "routes/translate.ts"))};
import speakRouter from ${JSON.stringify(path.join(root, "routes/speak.ts"))};
import { logger } from ${JSON.stringify(path.join(root, "lib/logger.ts"))};
const timingLogs = [];
const originalInfo = logger.info.bind(logger);
logger.info = (obj, msg, ...rest) => {
  if (obj && typeof obj === "object") timingLogs.push({ obj, msg: msg ?? null });
  return originalInfo(obj, msg, ...rest);
};
export { translateRouter, speakRouter, timingLogs };
`,
  );
  const result = esbuild.buildSync({
    absWorkingDir: path.join(__dirname, ".."),
    entryPoints: [entry],
    bundle: true,
    format: "cjs",
    platform: "node",
    target: "node20",
    write: false,
    external: ["express", "pino", "pino-pretty", "thread-stream"],
    logLevel: "silent",
  });
  const module = { exports: {} };
  const runner = new Function(
    "require",
    "module",
    "exports",
    result.outputFiles[0].text,
  );
  runner(require, module, module.exports);
  return module.exports;
}

function post(port, route, body) {
  const payload = JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port,
        path: route,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const raw = Buffer.concat(chunks);
          let json = null;
          try {
            json = JSON.parse(raw.toString("utf8"));
          } catch {
            json = null;
          }
          resolve({ status: res.statusCode, headers: res.headers, raw, json });
        });
      },
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

function listen(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function routeTiming(logs, route) {
  return logs.filter(
    (entry) =>
      entry.msg === "route_timing" && entry.obj && entry.obj.route === route,
  );
}

async function main() {
  process.env.LOG_LEVEL = process.env.LOG_LEVEL || "silent";
  process.env.OPENAI_API_KEY = "wp0a-test-key";
  process.env.ELEVENLABS_API_KEY = "wp0a-test-key";

  const calls = [];
  global.fetch = async (url, init) => {
    const href = String(url);
    calls.push(href);
    if (href.includes("api.openai.com/v1/chat/completions")) {
      const content = JSON.stringify({
        translation: TARGET_TOKEN,
        dialect: "es",
        notes: "",
      });
      return new Response(
        JSON.stringify({
          choices: [{ finish_reason: "stop", message: { content } }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }
    if (href.includes("api.elevenlabs.io/")) {
      return new Response(AUDIO, {
        status: 200,
        headers: { "Content-Type": "audio/mpeg" },
      });
    }
    throw new Error(`unexpected provider url ${href}`);
  };

  const { translateRouter, speakRouter, timingLogs } = loadApp();
  const express = require("express");
  const app = express();
  app.use(express.json());
  app.use(translateRouter);
  app.use(speakRouter);
  const server = await listen(app);
  const port = server.address().port;

  try {
    const missing = await post(port, "/translate", {});
    assert.equal(missing.status, 400);
    assert.deepEqual(missing.json, {
      error: "Provide text in `text` or `sourceText` (1–2000 characters).",
    });
    assert.equal(calls.length, 0);

    const badDirection = await post(port, "/translate", {
      text: SOURCE_TOKEN,
      sourceLanguage: "en",
      targetLanguage: "fr",
    });
    assert.equal(badDirection.status, 400);
    assert.equal(calls.length, 0);

    const translated = await post(port, "/translate", {
      task: "translate",
      text: SOURCE_TOKEN,
      sourceText: SOURCE_TOKEN,
      sourceLanguage: "en",
      targetLanguage: "es",
      voiceMode: "jobsite",
      mode: "jobsite",
    });
    assert.equal(translated.status, 200);
    assert.equal(translated.json.translation, TARGET_TOKEN);
    assert.equal(translated.json.task, "translate");
    assert.equal(translated.json.sourceText, SOURCE_TOKEN);
    assert.equal("duration_ms" in translated.json, false);
    assert.equal("outcome" in translated.json, false);

    const speakMissing = await post(port, "/speak", {});
    assert.equal(speakMissing.status, 400);
    assert.equal(speakMissing.json.error.includes("Provide text"), true);

    const spoken = await post(port, "/speak", {
      task: "speak",
      text: SPEAK_TOKEN,
      voice: "XVO6RhOYU9ZEKHFXrx6b",
      model: "eleven_v3",
      format: "mp3",
      language: "en",
      voiceMode: "jobsite",
      mode: "jobsite",
    });
    assert.equal(spoken.status, 200, JSON.stringify(spoken.json));
    assert.equal(spoken.headers["content-type"], "audio/mpeg");
    assert.equal(spoken.headers["content-length"], String(AUDIO.length));
    assert.equal(spoken.headers["x-beckify-tts-cacheable"], "1");
    assert.deepEqual(spoken.raw, AUDIO);

    const translateLogs = routeTiming(timingLogs, "/api/translate");
    const speakLogs = routeTiming(timingLogs, "/api/speak");
    assert.equal(translateLogs.length, 3);
    assert.equal(speakLogs.length, 2);
    assert.equal(translateLogs[0].obj.outcome, "client_error");
    assert.equal(translateLogs[1].obj.outcome, "client_error");
    assert.equal(translateLogs[2].obj.outcome, "ok");
    assert.equal(speakLogs[0].obj.outcome, "client_error");
    assert.equal(speakLogs[1].obj.outcome, "ok");
    for (const entry of [...translateLogs, ...speakLogs]) {
      assert.equal(typeof entry.obj.duration_ms, "number");
      assert.equal(Number.isFinite(entry.obj.duration_ms), true);
      assert.equal(entry.obj.duration_ms >= 0, true);
      const blob = JSON.stringify(entry.obj);
      assert.equal(blob.includes(SOURCE_TOKEN), false);
      assert.equal(blob.includes(TARGET_TOKEN), false);
      assert.equal(blob.includes(SPEAK_TOKEN), false);
      assert.equal(blob.includes("wp0a-test-key"), false);
      assert.equal("clientKey" in entry.obj, false);
      assert.equal("text" in entry.obj, false);
    }
    assert.equal(typeof speakLogs[1].obj.first_audio_chunk_ms, "number");
    assert.equal(Number.isFinite(speakLogs[1].obj.first_audio_chunk_ms), true);
    assert.equal("first_audio_chunk_ms" in speakLogs[0].obj, false);
    assert.equal("first_audio_chunk_ms" in translateLogs[2].obj, false);
  } finally {
    await new Promise((resolve, reject) =>
      server.close((err) => (err ? reject(err) : resolve())),
    );
  }

  console.log("route-timing.test.cjs: ok");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
