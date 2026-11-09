"use strict";

/**
 * Crew Talk speech cache: a second identical /api/speak request for an
 * ElevenLabs voice must not call ElevenLabs again, must not charge the
 * ElevenLabs character budget, and must be marked HIT. OpenAI speech is
 * not cached. Cache keys match the iOS canonical document
 * (CrewTalkSpeakRequest.audioCacheKey).
 * Run: node ./tests/speak-cache.test.cjs
 */

const assert = require("node:assert/strict");
const http = require("node:http");
const path = require("node:path");

const TITO = "goyf4sY4AqSvMIeO1hb5";
const BODIE = "XVO6RhOYU9ZEKHFXrx6b";
// Golden vector from CrewTalkContractsTests (iOS): Tito + "Kill the power."
const GOLDEN_KEY = "613fabd7244fe30beca7f88811e980d818b3ad65d4570501cf04cd3735abb5f6";

const calls = [];

function installFetchMock() {
  global.fetch = async (url, init) => {
    const href = String(url);
    if (!href.startsWith("https://api.elevenlabs.io/") && !href.startsWith("https://api.openai.com/")) {
      throw new Error(`unexpected provider url ${href}`);
    }
    calls.push({ url: href, init });
    const bytes = Uint8Array.from([0x49, 0x44, 0x33, 0x04, 0x00, 0x00]);
    return new Response(bytes, {
      status: 200,
      headers: { "Content-Type": "audio/mpeg" },
    });
  };
}

function postJson(port, body) {
  const payload = JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port,
        path: "/speak",
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

async function bundle(entryPoint) {
  const esbuild = require("esbuild");
  const result = await esbuild.build({
    absWorkingDir: path.join(__dirname, ".."),
    entryPoints: [entryPoint],
    bundle: true,
    format: "cjs",
    platform: "node",
    target: "node20",
    write: false,
    external: ["express", "pino", "pino-pretty", "thread-stream"],
    logLevel: "silent",
  });
  const module = { exports: {} };
  const runner = new Function("require", "module", "exports", result.outputFiles[0].text);
  runner(require, module, module.exports);
  return module.exports;
}

async function loadSpeakRouter() {
  const router = (await bundle("src/routes/speak.ts")).default;
  if (typeof router !== "function") throw new Error("speak router did not export a function");
  return router;
}

function listen(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function startApp() {
  const express = require("express");
  const router = await loadSpeakRouter();
  const app = express();
  app.use(express.json());
  app.use(router);
  const server = await listen(app);
  return { server, port: server.address().port };
}

async function main() {
  installFetchMock();
  process.env.ELEVENLABS_API_KEY = "cache-test-key";
  process.env.OPENAI_API_KEY = "cache-test-key";

  // --- Cache key: same canonical document as iOS -------------------------
  const cacheLib = await bundle("src/lib/speakCache.ts");
  const { speakCacheKey, speakCacheDocument, SpeakAudioCache } = cacheLib;
  assert.equal(
    speakCacheKey({ voice: TITO, model: "eleven_v3", language: "es", format: "mp3", text: "Kill the power." }),
    GOLDEN_KEY,
    "server cache key must match the iOS golden vector",
  );
  assert.equal(
    speakCacheDocument({ voice: TITO, model: "eleven_v3", language: "es", format: "mp3", text: "Kill the power." }),
    [
      "crewtalk-speak-v1",
      "voiceMode=jobsite",
      "model=eleven_v3",
      `voice=${TITO}`,
      "language=es",
      "format=mp3",
      "text=Kill the power.",
    ].join("\n"),
  );
  // Canonicalization: NFC and CRLF fold to the same key as the iOS client.
  const nfc = speakCacheKey({ voice: BODIE, model: "eleven_v3", language: "en", format: "mp3", text: "café" });
  const nfd = speakCacheKey({ voice: BODIE, model: "eleven_v3", language: "en", format: "mp3", text: "café" });
  assert.equal(nfc, nfd, "NFC/NFD text must share a cache key");
  const crlf = speakCacheKey({ voice: BODIE, model: "eleven_v3", language: "en", format: "mp3", text: "Kill the power.\r\nNow." });
  const lf = speakCacheKey({ voice: BODIE, model: "eleven_v3", language: "en", format: "mp3", text: "Kill the power.\nNow." });
  assert.equal(crlf, lf, "CRLF/LF text must share a cache key");

  // --- LRU / TTL / caps (unit level) --------------------------------------
  {
    const tiny = new SpeakAudioCache({ maxEntries: 2, maxBytes: 100, ttlMs: 60_000 });
    tiny.set("a", Buffer.alloc(40));
    tiny.set("b", Buffer.alloc(40));
    assert.equal(tiny.get("a").length, 40, "hit refreshes recency");
    tiny.set("c", Buffer.alloc(40));
    assert.equal(tiny.get("b"), null, "least-recently-used entry is evicted");
    assert.equal(tiny.get("a").length, 40);
    assert.equal(tiny.get("c").length, 40);
    tiny.set("big", Buffer.alloc(101));
    assert.equal(tiny.get("big"), null, "a clip larger than the byte cap is not stored");
    tiny.set("empty", Buffer.alloc(0));
    assert.equal(tiny.get("empty"), null, "empty audio is never stored");
    const stale = new SpeakAudioCache({ ttlMs: 0 });
    stale.set("x", Buffer.alloc(10), 1_000);
    assert.equal(stale.get("x", 1_001), null, "expired entries are misses");
    assert.deepEqual(stale.stats().entries, 0);
  }

  // --- Route: identical ElevenLabs request is a hit -----------------------
  const { server, port } = await startApp();
  try {
    const body = { text: "Kill the power.", voice: TITO, model: "eleven_v3" };

    const first = await postJson(port, body);
    assert.equal(first.status, 200, JSON.stringify(first.json));
    assert.equal(first.headers["x-beckify-tts-cache"], "MISS");
    assert.equal(first.headers["x-beckify-tts-cacheable"], "1");
    assert.equal(first.headers["cache-control"], "no-store");
    const callsAfterFirst = calls.length;
    assert.equal(callsAfterFirst, 1, "first request must call ElevenLabs once");

    const second = await postJson(port, body);
    assert.equal(second.status, 200, JSON.stringify(second.json));
    assert.equal(second.headers["x-beckify-tts-cache"], "HIT");
    assert.equal(second.headers["x-beckify-tts-cacheable"], "1");
    assert.equal(second.headers["cache-control"], "private, max-age=86400");
    assert.deepEqual(second.raw, first.raw, "hit returns the same audio bytes");
    assert.equal(calls.length, callsAfterFirst, "second identical request must not call ElevenLabs again");

    // Different text and different voice are misses.
    const otherText = await postJson(port, { text: "Panel is dead.", voice: TITO, model: "eleven_v3" });
    assert.equal(otherText.headers["x-beckify-tts-cache"], "MISS");
    assert.equal(calls.length, callsAfterFirst + 1);
    const otherVoice = await postJson(port, { text: "Kill the power.", voice: BODIE, model: "eleven_v3" });
    assert.equal(otherVoice.headers["x-beckify-tts-cache"], "MISS");
    assert.equal(calls.length, callsAfterFirst + 2);

    // Unknown voice still fails before any provider call and poisons nothing.
    const unknownBefore = calls.length;
    const unknown = await postJson(port, { text: "Kill the power.", voice: "AbCdEfGhIjKlMnOpQrSt", model: "eleven_v3" });
    assert.equal(unknown.status, 400);
    assert.equal(unknown.headers["x-beckify-tts-cache"], undefined);
    assert.equal(calls.length, unknownBefore);

    // OpenAI speech is not cached.
    const openaiBody = { text: "Hello site.", voice: "alloy", model: "gpt-4o-mini-tts" };
    const openaiFirst = await postJson(port, openaiBody);
    assert.equal(openaiFirst.status, 200, JSON.stringify(openaiFirst.json));
    assert.equal(openaiFirst.headers["x-beckify-tts-cache"], undefined);
    const openaiCalls = calls.length;
    const openaiSecond = await postJson(port, openaiBody);
    assert.equal(openaiSecond.status, 200);
    assert.equal(openaiSecond.headers["x-beckify-tts-cache"], undefined);
    assert.equal(calls.length, openaiCalls + 1, "OpenAI path must synthesize every time");
  } finally {
    await new Promise((resolve, reject) => server.close((err) => (err ? reject(err) : resolve())));
  }

  // --- Route: a cache hit does not charge the ElevenLabs budget -----------
  // Fresh app (fresh budget buckets + fresh cache). Limit 30 chars: a
  // 15-char MISS uses 15, the identical HIT must use 0, so a second
  // distinct 15-char line still fits (15 + 15 = 30). If the hit had
  // charged, that third request would be 429.
  process.env.AI_BUDGET_ELEVEN_CHARS = "30";
  const budgeted = await startApp();
  try {
    const fifteen = "123456789012345"; // 15 chars
    const miss = await postJson(budgeted.port, { text: fifteen, voice: TITO, model: "eleven_v3" });
    assert.equal(miss.status, 200, JSON.stringify(miss.json));
    assert.equal(miss.headers["x-beckify-tts-cache"], "MISS");
    const hit = await postJson(budgeted.port, { text: fifteen, voice: TITO, model: "eleven_v3" });
    assert.equal(hit.status, 200);
    assert.equal(hit.headers["x-beckify-tts-cache"], "HIT");
    const third = await postJson(budgeted.port, { text: "abcdefghijklmno", voice: TITO, model: "eleven_v3" });
    assert.equal(third.status, 200, JSON.stringify(third.json));
    assert.equal(third.headers["x-beckify-tts-cache"], "MISS");
  } finally {
    delete process.env.AI_BUDGET_ELEVEN_CHARS;
    await new Promise((resolve, reject) => budgeted.server.close((err) => (err ? reject(err) : resolve())));
  }

  console.log("speak-cache.test.cjs: ok");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
