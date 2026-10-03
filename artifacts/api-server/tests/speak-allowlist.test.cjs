"use strict";

/**
 * WP-110: ElevenLabs speak allowlist.
 * Unknown voices fail before any provider call. Client voice knobs are ignored.
 * Run: node ./tests/speak-allowlist.test.cjs
 */

const assert = require("node:assert/strict");
const http = require("node:http");
const path = require("node:path");

const CREW = {
  bodieHale: "XVO6RhOYU9ZEKHFXrx6b",
  titoSolano: "goyf4sY4AqSvMIeO1hb5",
  juniePell: "tdK8noxHGTBqk6F18tbZ",
  pearl: "xDnrPZyqSbomyfOcnNpu",
  sloaneMerritt: "qMmZtYs7EKOOIm0u211n",
};
const CASSIAN = "uYsaRSYDSuxmtyipO9Qt";
const BODIE_SETTINGS = {
  stability: 0,
  similarity_boost: 0.75,
  style: 0.8,
  speed: 0.9,
  use_speaker_boost: true,
};
const JUNIE_SETTINGS = {
  stability: 0.15,
  similarity_boost: 0.72,
  style: 1,
  speed: 0.64,
  use_speaker_boost: true,
};
const CASSIAN_SETTINGS = {
  stability: 0.38,
  similarity_boost: 0.82,
  style: 1,
  speed: 0.86,
  use_speaker_boost: true,
};

const calls = [];

function installFetchMock() {
  global.fetch = async (url, init) => {
    const href = String(url);
    if (!href.startsWith("https://api.elevenlabs.io/") && !href.startsWith("https://api.openai.com/")) {
      throw new Error(`unexpected provider url ${href}`);
    }
    calls.push({ url: href, init });
    const bytes = Uint8Array.from([0x49, 0x44, 0x33, 0x04]);
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

async function loadSpeakRouter() {
  const esbuild = require("esbuild");
  const result = await esbuild.build({
    absWorkingDir: path.join(__dirname, ".."),
    entryPoints: ["src/routes/speak.ts"],
    bundle: true,
    format: "cjs",
    platform: "node",
    target: "node20",
    write: false,
    external: ["express"],
    logLevel: "silent",
  });
  const code = result.outputFiles[0].text;
  const module = { exports: {} };
  const runner = new Function("require", "module", "exports", code);
  runner(require, module, module.exports);
  const router = module.exports.default || module.exports;
  if (typeof router !== "function") {
    throw new Error("speak router did not export a function");
  }
  return router;
}

function listen(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function expectUnknown(port, body) {
  const before = calls.length;
  const res = await postJson(port, { text: "Breaker is off.", ...body });
  assert.equal(res.status, 400, JSON.stringify(res.json));
  assert.deepEqual(res.json, { error: "Unknown voice." });
  assert.equal(calls.length, before, "provider was called for an unknown voice");
  assert.equal(res.headers["x-beckify-tts-cacheable"], undefined);
}

const CLIENT_KNOBS = {
  model: "eleven_turbo_v2_5",
  stability: 0.99,
  similarity_boost: 0.11,
  similarityBoost: 0.12,
  style: 0.13,
  speed: 1.2,
  seed: 1,
};

async function speakEleven(port, voice) {
  const before = calls.length;
  const res = await postJson(port, {
    text: "Panel is dead.",
    voice,
    ...CLIENT_KNOBS,
  });
  assert.equal(res.status, 200, JSON.stringify(res.json));
  assert.equal(calls.length, before + 1);
  assert.equal(res.headers["x-beckify-tts-cacheable"], "1");
  assert.equal(res.headers["x-beckify-tts-model"], "eleven_v3");
  const call = calls[calls.length - 1];
  const payload = JSON.parse(call.init.body);
  assert.equal(payload.model_id, "eleven_v3");
  assert.equal(payload.text, "Panel is dead.");
  assert.match(call.url, new RegExp(`/text-to-speech/${encodeURIComponent(voice.trim())}\\?`));
  assert.equal(call.init.headers["xi-api-key"], process.env.ELEVENLABS_API_KEY);
  return payload;
}

async function main() {
  installFetchMock();
  process.env.ELEVENLABS_API_KEY = "wp110-test-key";
  process.env.OPENAI_API_KEY = "wp110-test-key";

  const express = require("express");
  const router = await loadSpeakRouter();
  const app = express();
  app.use(express.json());
  app.use(router);
  const server = await listen(app);
  const port = server.address().port;

  try {
    delete process.env.ELEVENLABS_API_KEY;
    await expectUnknown(port, { voice: "AbCdEfGhIjKlMnOpQrSt", model: "eleven_v3" });
    process.env.ELEVENLABS_API_KEY = "wp110-test-key";

    await expectUnknown(port, { voice: "AbCdEfGhIjKlMnOpQrSt" });
    await expectUnknown(port, { voice: "alloy", model: "eleven_multilingual_v2" });
    await expectUnknown(port, { voice: "uYsaRSYDSuxmtyipO9QT", model: "eleven_v3" });
    await expectUnknown(port, { model: "eleven_v3" });
    await expectUnknown(port, { voice: "not-a-crew-voice", model: "eleven_flash_v2_5" });
    await expectUnknown(port, { voice: `  ${CASSIAN.toLowerCase()}  `, model: "eleven_v3" });

    const bodie = await speakEleven(port, `  ${CREW.bodieHale}  `);
    assert.deepEqual(bodie.voice_settings, BODIE_SETTINGS);
    assert.equal(bodie.seed, undefined);
    assert.equal(calls[calls.length - 1].url.includes(CREW.bodieHale), true);
    const bodieOverride = await postJson(port, {
      text: "Panel is dead.",
      voice: CREW.bodieHale,
      model: "eleven_v3",
      stability: 0.99,
      similarity_boost: 0.1,
      style: 0.1,
      speed: 1.4,
    });
    assert.equal(bodieOverride.status, 200, JSON.stringify(bodieOverride.json));
    const bodiePayload = JSON.parse(calls[calls.length - 1].init.body);
    assert.deepEqual(bodiePayload.voice_settings, BODIE_SETTINGS);

    const tito = await speakEleven(port, CREW.titoSolano);
    assert.equal(tito.voice_settings, undefined);
    assert.equal(tito.seed, undefined);

    const junie = await speakEleven(port, CREW.juniePell);
    assert.deepEqual(junie.voice_settings, JUNIE_SETTINGS);
    assert.equal(junie.seed, undefined);

    const pearl = await speakEleven(port, CREW.pearl);
    assert.equal(pearl.voice_settings, undefined);
    assert.equal(pearl.seed, undefined);

    const sloane = await speakEleven(port, CREW.sloaneMerritt);
    assert.equal(sloane.voice_settings, undefined);
    assert.equal(sloane.seed, 50505);

    const cassian = await speakEleven(port, CASSIAN);
    assert.deepEqual(cassian.voice_settings, CASSIAN_SETTINGS);
    assert.equal(cassian.seed, 60606);

    const longBefore = calls.length;
    const longCassian = await postJson(port, {
      text: "a".repeat(600),
      voice: CASSIAN,
      model: "eleven_multilingual_v2",
      seed: 42,
      stability: 0.01,
    });
    assert.equal(longCassian.status, 200, JSON.stringify(longCassian.json));
    assert.equal(longCassian.headers["x-beckify-tts-cacheable"], "1");
    assert.equal(calls.length, longBefore + 1);
    const longPayload = JSON.parse(calls[calls.length - 1].init.body);
    assert.equal(longPayload.model_id, "eleven_v3");
    assert.equal(longPayload.seed, 60606);
    assert.deepEqual(longPayload.voice_settings, CASSIAN_SETTINGS);

    const tooLongBefore = calls.length;
    const tooLong = await postJson(port, {
      text: "b".repeat(501),
      voice: CREW.bodieHale,
      model: "eleven_v3",
    });
    assert.equal(tooLong.status, 413);
    assert.equal(calls.length, tooLongBefore);

    const openaiBefore = calls.length;
    const openai = await postJson(port, {
      text: "Hello site.",
      voice: "alloy",
      model: "gpt-4o-mini-tts",
      stability: 0.2,
      similarity_boost: 0.3,
      speed: 1.1,
      seed: 99,
    });
    assert.equal(openai.status, 200, JSON.stringify(openai.json));
    assert.equal(openai.headers["x-beckify-tts-cacheable"], undefined);
    assert.equal(calls.length, openaiBefore + 1);
    const openaiCall = calls[calls.length - 1];
    assert.match(openaiCall.url, /^https:\/\/api\.openai\.com\/v1\/audio\/speech$/);
    const openaiPayload = JSON.parse(openaiCall.init.body);
    assert.equal(openaiPayload.voice, "alloy");
    assert.equal(openaiPayload.model, "gpt-4o-mini-tts");
    assert.equal("seed" in openaiPayload, false);
    assert.equal("voice_settings" in openaiPayload, false);
  } finally {
    await new Promise((resolve, reject) => server.close((err) => (err ? reject(err) : resolve())));
  }

  console.log("speak-allowlist.test.cjs: ok");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
