"use strict";

/**
 * Crew Talk speaks on the free Beckify voice engine by default. ElevenLabs is never
 * called unless explicitly opted in. Run: node ./tests/crew-voice-engine.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");

const ENGINE = "http://127.0.0.1:8090/synthesize";
const LEGACY = {
  bodieHale: "XVO6RhOYU9ZEKHFXrx6b",
  titoSolano: "goyf4sY4AqSvMIeO1hb5",
  juniePell: "m2X69O7Xomk9219qo0Gy",
  pearl: "xDnrPZyqSbomyfOcnNpu",
  sloaneMerritt: "qMmZtYs7EKOOIm0u211n",
  lupitaReyes: "iGXRQ0smdhSFlb6iV1Pr",
  humbertoArismendi: "IvXILleF0UhlyqiuUo87",
  dreLacey: "MAPMuGNkK84YjEK5kMBn",
};
/** Kokoro v1.0 voice pack ids (voices-v1.0.bin). */
const KOKORO_VOICES = new Set([
  "af_alloy", "af_aoede", "af_bella", "af_heart", "af_jessica", "af_kore", "af_nicole", "af_nova", "af_river", "af_sarah", "af_sky",
  "am_adam", "am_echo", "am_eric", "am_fenrir", "am_liam", "am_michael", "am_onyx", "am_puck", "am_santa",
  "bf_alice", "bf_emma", "bf_isabella", "bf_lily", "bm_daniel", "bm_fable", "bm_george", "bm_lewis",
  "ef_dora", "em_alex", "em_santa",
]);

let calls = [];
let engineMode = "ok";
const AUDIO = Uint8Array.from([0x49, 0x44, 0x33, 0x04, 0, 0, 0, 0]);

global.fetch = async (url, init) => {
  const href = String(url);
  calls.push({ url: href, init });
  if (href === ENGINE) {
    if (engineMode === "down") throw new TypeError("fetch failed");
    if (engineMode === "500") return new Response("{}", { status: 500 });
    return new Response(AUDIO, { status: 200, headers: { "Content-Type": "audio/mpeg" } });
  }
  if (href.startsWith("https://api.elevenlabs.io/") || href.startsWith("https://api.openai.com/")) {
    return new Response(AUDIO, { status: 200, headers: { "Content-Type": "audio/mpeg" } });
  }
  throw new Error(`unexpected url ${href}`);
};

function build(entry) {
  const esbuild = require("esbuild");
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
  new Function("require", "module", "exports", result.outputFiles[0].text)(require, module, module.exports);
  return module.exports;
}

function post(port, body) {
  const payload = JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = http.request(
      { hostname: "127.0.0.1", port, path: "/speak", method: "POST", headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(payload) } },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          const raw = Buffer.concat(chunks);
          let json = null;
          try { json = JSON.parse(raw.toString("utf8")); } catch { json = null; }
          resolve({ status: res.statusCode, headers: res.headers, raw, json });
        });
      },
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

function lastEnginePayload() {
  const call = [...calls].reverse().find((c) => c.url === ENGINE);
  assert.ok(call, "engine was called");
  return JSON.parse(call.init.body);
}

function onlyEngineCalls() {
  for (const c of calls) assert.equal(c.url, ENGINE, `unexpected provider ${c.url}`);
}

async function main() {
  delete process.env.CREW_VOICE_PROVIDER;
  delete process.env.CREW_VOICE_FALLBACK;
  delete process.env.TRANSLATOR_VOICE_PROVIDER;
  // A configured key must not matter: the free engine is the default.
  process.env.ELEVENLABS_API_KEY = "test-key-not-used";
  process.env.OPENAI_API_KEY = "test-key";

  const voices = build("src/voice/crewVoices.ts");
  const { CREW_VOICE_PROFILES, TRANSLATOR_VOICE_PROFILES, LEGACY_CREW_VOICE_IDS, resolveCrewVoiceKey, spokenText } = voices;

  // Profiles stay inside the engine's accepted ranges and use real Kokoro voices.
  for (const [key, p] of Object.entries({ ...CREW_VOICE_PROFILES, ...TRANSLATOR_VOICE_PROFILES })) {
    assert.ok(p.voices.length >= 1 && p.voices.length <= 3, key);
    for (const [id, w] of p.voices) {
      assert.ok(KOKORO_VOICES.has(id), `${key} uses unknown voice ${id}`);
      assert.ok(w > 0 && w <= 1, key);
    }
    assert.ok(p.speed >= 0.5 && p.speed <= 1.6, key);
    assert.ok(p.pitchSemitones >= -4 && p.pitchSemitones <= 4, key);
    assert.ok(["en-us", "en-gb", "es"].includes(p.lang), key);
    assert.ok(p.brief.length > 10, key);
  }
  // Every legacy id maps to a character; distinct characters get distinct voice settings.
  for (const [name, id] of Object.entries(LEGACY)) assert.equal(LEGACY_CREW_VOICE_IDS[id], name);
  const signatures = new Set(Object.values(CREW_VOICE_PROFILES).map((p) => JSON.stringify([p.voices, p.speed, p.pitchSemitones, p.lang])));
  assert.equal(signatures.size, Object.keys(CREW_VOICE_PROFILES).length, "two characters share one voice");

  // Every iOS CrewTalkMember case has a profile.
  const swift = fs.readFileSync(path.join(__dirname, "..", "..", "..", "ios", "BeckifyMath", "Sources", "BeckifyMath", "SpanishTranslator.swift"), "utf8");
  const enumBody = swift.slice(swift.indexOf("public enum CrewTalkMember"), swift.indexOf("public static let storageKey"));
  const cases = [...enumBody.matchAll(/^\s*case (\w+)$/gm)].map((m) => m[1]);
  assert.ok(cases.length >= 9, "found CrewTalkMember cases");
  for (const c of cases) assert.ok(CREW_VOICE_PROFILES[c], `no voice profile for ${c}`);

  // Humberto's shared id follows the request language.
  assert.equal(resolveCrewVoiceKey(LEGACY.humbertoArismendi, undefined, "en"), "humbertoArismendiEnglish");
  assert.equal(resolveCrewVoiceKey(LEGACY.humbertoArismendi, undefined, "es"), "humbertoArismendi");
  assert.equal(resolveCrewVoiceKey("crew:pearl", undefined, "en"), "pearl");
  assert.equal(resolveCrewVoiceKey("", "sloaneMerritt", "en"), "sloaneMerritt");
  assert.equal(resolveCrewVoiceKey("crew:nobody", undefined, "en"), null);
  assert.equal(resolveCrewVoiceKey("alloy", undefined, "en"), null);
  assert.equal(spokenText("Ay, bruh, kill it.", CREW_VOICE_PROFILES.dreLacey), "Aye, bruh, kill it.");

  const express = require("express");
  const router = build("src/routes/speak.ts").default;
  const app = express();
  app.use(express.json());
  app.use(router);
  const server = await new Promise((r) => { const s = app.listen(0, "127.0.0.1", () => r(s)); });
  const port = server.address().port;

  try {
    // Shipped builds: legacy id + eleven_v3 lands on the free engine.
    for (const [name, id] of Object.entries(LEGACY)) {
      calls = [];
      const language = ["titoSolano", "lupitaReyes", "humbertoArismendi"].includes(name) ? "es" : "en";
      const res = await post(port, { text: "Panel is dead.", voice: id, model: "eleven_v3", format: "mp3", language, stability: 0.9, speed: 1.5 });
      assert.equal(res.status, 200, JSON.stringify(res.json));
      onlyEngineCalls();
      assert.equal(res.headers["x-beckify-tts-provider"], "kokoro");
      assert.equal(res.headers["x-beckify-tts-model"], "kokoro-82m");
      assert.equal(res.headers["x-beckify-tts-voice"], name);
      assert.equal(res.headers["x-beckify-tts-cacheable"], "1");
      assert.equal(res.headers["content-type"], "audio/mpeg");
      const payload = lastEnginePayload();
      const profile = CREW_VOICE_PROFILES[name];
      // Client knobs are ignored; the server profile wins.
      assert.equal(payload.speed, profile.speed);
      assert.equal(payload.pitch_semitones, profile.pitchSemitones);
      assert.deepEqual(payload.voices, profile.voices.map(([v, w]) => [v, w]));
      assert.equal(payload.lang, profile.lang);
      assert.equal(payload.format, "mp3");
    }

    // Humberto in English uses the English profile.
    calls = [];
    let res = await post(port, { text: "With respect, my friend.", voice: LEGACY.humbertoArismendi, language: "en" });
    assert.equal(res.status, 200);
    assert.equal(lastEnginePayload().lang, "en-us");
    assert.equal(res.headers["x-beckify-tts-voice"], "humbertoArismendiEnglish");

    // New clients may send `crew` or `crew:<key>`. Audio tags are not read aloud.
    calls = [];
    res = await post(port, { text: "[laughs] Ay, bruh, kill the power.", voice: "crew:dreLacey", format: "wav", language: "en" });
    assert.equal(res.status, 200);
    assert.equal(res.headers["content-type"], "audio/wav");
    assert.equal(lastEnginePayload().text, "Aye, bruh, kill the power.");
    assert.equal(lastEnginePayload().format, "wav");
    res = await post(port, { text: "Darling, bold choice.", crew: "cassianVale", language: "en" });
    assert.equal(res.status, 200);
    assert.equal(lastEnginePayload().lang, "en-gb");

    // Unknown voices still fail before any provider call.
    for (const body of [
      { voice: "AbCdEfGhIjKlMnOpQrSt" },
      { voice: "AbCdEfGhIjKlMnOpQrSt", model: "eleven_v3" },
      { model: "eleven_v3" },
      { voice: "alloy", model: "eleven_multilingual_v2" },
      { voice: "crew:nobody" },
      { voice: "uYsaRSYDSuxmtyipO9Qt" },
    ]) {
      calls = [];
      res = await post(port, { text: "Breaker is off.", ...body });
      assert.equal(res.status, 400, JSON.stringify(body));
      assert.deepEqual(res.json, { error: "Unknown voice." });
      assert.equal(calls.length, 0);
    }

    // Length cap still applies.
    calls = [];
    res = await post(port, { text: "b".repeat(501), voice: LEGACY.bodieHale });
    assert.equal(res.status, 413);
    assert.equal(calls.length, 0);

    // Engine down: 503 (the app plays its on-device voice). ElevenLabs is not touched.
    for (const mode of ["down", "500"]) {
      engineMode = mode;
      calls = [];
      res = await post(port, { text: "Panel is dead.", voice: LEGACY.pearl, language: "en" });
      assert.equal(res.status, 503, mode);
      onlyEngineCalls();
    }

    // Opt-in fallback only.
    process.env.CREW_VOICE_FALLBACK = "elevenlabs";
    engineMode = "down";
    calls = [];
    res = await post(port, { text: "Panel is dead.", voice: LEGACY.pearl, language: "en" });
    assert.equal(res.status, 200);
    assert.equal(res.headers["x-beckify-tts-provider"], "elevenlabs");
    assert.match(calls[calls.length - 1].url, /api\.elevenlabs\.io\/v1\/text-to-speech\/xDnrPZyqSbomyfOcnNpu/);
    delete process.env.CREW_VOICE_FALLBACK;
    engineMode = "ok";

    // Translator stays on its current provider by default...
    calls = [];
    res = await post(port, { text: "Hola.", voice: "onyx", language: "es", voiceMode: "jobsite" });
    assert.equal(res.status, 200);
    assert.match(calls[0].url, /^https:\/\/api\.openai\.com\/v1\/audio\/speech$/);
    assert.equal(res.headers["x-beckify-tts-cacheable"], undefined);

    // ...and moves to the free engine when TRANSLATOR_VOICE_PROVIDER=kokoro (not Japanese).
    process.env.TRANSLATOR_VOICE_PROVIDER = "kokoro";
    calls = [];
    res = await post(port, { text: "Well now.", language: "en", voiceMode: "deepSouth" });
    assert.equal(res.status, 200);
    onlyEngineCalls();
    assert.equal(res.headers["x-beckify-tts-voice"], "deepSouth");
    assert.deepEqual(lastEnginePayload().voices, TRANSLATOR_VOICE_PROFILES.deepSouth.voices.map(([v, w]) => [v, w]));
    calls = [];
    res = await post(port, { text: "こんにちは", language: "ja", voiceMode: "clean" });
    assert.equal(res.status, 200);
    assert.match(calls[0].url, /api\.openai\.com/);
    delete process.env.TRANSLATOR_VOICE_PROVIDER;
  } finally {
    await new Promise((r) => server.close(r));
  }
  console.log("crew-voice-engine.test.cjs: ok");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
