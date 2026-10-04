"use strict";

/**
 * Crew Talk device linking: RoomStore rules plus the real HTTP/SSE route.
 * Run: node ./tests/rooms.test.cjs
 */

const assert = require("node:assert/strict");
const http = require("node:http");
const path = require("node:path");
const esbuild = require("esbuild");

async function bundle(entry) {
  const result = await esbuild.build({
    absWorkingDir: path.join(__dirname, ".."),
    entryPoints: [entry],
    bundle: true,
    format: "cjs",
    platform: "node",
    target: "node20",
    write: false,
    external: ["pino", "pino-http", "express", "cors"],
    logLevel: "silent",
  });
  const module = { exports: {} };
  const runner = new Function("require", "module", "exports", result.outputFiles[0].text);
  runner(require, module, module.exports);
  return module.exports;
}

function request(port, method, urlPath, body) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? null : JSON.stringify(body);
    const req = http.request(
      { host: "127.0.0.1", port, method, path: urlPath, headers: data ? { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(data) } : {} },
      (res) => {
        let text = "";
        res.on("data", (c) => (text += c));
        res.on("end", () => resolve({ status: res.statusCode, json: text ? JSON.parse(text) : null }));
      },
    );
    req.on("error", reject);
    if (data) req.write(data);
    req.end();
  });
}

function openStream(port, urlPath) {
  const events = [];
  const waiters = [];
  let req;
  const ready = new Promise((resolve, reject) => {
    req = http.get({ host: "127.0.0.1", port, path: urlPath }, (res) => {
      assert.equal(res.statusCode, 200);
      assert.match(res.headers["content-type"], /text\/event-stream/);
      let buf = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        buf += chunk;
        let idx;
        while ((idx = buf.indexOf("\n\n")) >= 0) {
          const frame = buf.slice(0, idx);
          buf = buf.slice(idx + 2);
          if (!frame.startsWith("data: ")) continue;
          const event = JSON.parse(frame.slice(6));
          events.push(event);
          waiters.splice(0).forEach((w) => w());
        }
      });
      resolve();
    });
    req.on("error", reject);
  });
  async function next(predicate, timeoutMs = 2000) {
    const start = Date.now();
    for (;;) {
      const found = events.find(predicate);
      if (found) return found;
      if (Date.now() - start > timeoutMs) throw new Error("timed out waiting for event");
      await new Promise((r) => { waiters.push(r); setTimeout(r, 50); });
    }
  }
  return { ready, next, events, close: () => req.destroy() };
}

(async () => {
  const lib = await bundle("src/lib/roomStore.ts");
  const { RoomStore, normalizeRoomLanguage, normalizeRoomCode, ROOM_MAX_TEXT_CHARS, ROOM_SEND_LIMIT, ROOM_IDLE_TTL_MS, ROOM_OFFLINE_GRACE_MS } = lib;

  // --- normalization
  assert.equal(normalizeRoomLanguage("en-US"), "en");
  assert.equal(normalizeRoomLanguage("ES_mx"), "es");
  assert.equal(normalizeRoomLanguage("ja"), null);
  assert.equal(normalizeRoomLanguage(5), null);
  assert.equal(normalizeRoomCode(" ab-c 123 "), "ABC123");

  // --- store rules
  {
    let t = 1_000;
    const store = new RoomStore(() => t);
    const made = store.create("en");
    assert.ok(made.ok);
    assert.match(made.code, /^[A-HJ-NP-Z2-9]{6}$/);

    const same = store.join(made.code, "en");
    assert.equal(same.ok, false);
    assert.equal(same.status, 409);
    assert.equal(store.join("ZZZZZZ", "es").status, 404);

    const joined = store.join(made.code.toLowerCase(), "es");
    assert.ok(joined.ok);
    assert.equal(joined.partnerLanguage, "en");
    assert.equal(store.join(made.code, "es").status, 409, "room is full");

    // message to an offline partner queues, then flushes on subscribe
    const sent = store.post(made.code, made.pid, "  Kill the power.  ");
    assert.ok(sent.ok);
    assert.equal(sent.delivered, false);
    const got = [];
    const sub = store.subscribe(made.code, joined.pid, (e) => got.push(e));
    assert.ok(sub.ok);
    assert.equal(got[0].t, "ready");
    assert.equal(got[0].partnerLanguage, "en");
    const msg = got.find((e) => e.t === "message");
    assert.equal(msg.text, "Kill the power.");
    assert.equal(msg.language, "en");

    // live delivery goes only to the other person
    const hostGot = [];
    store.subscribe(made.code, made.pid, (e) => hostGot.push(e));
    assert.ok(store.post(made.code, joined.pid, "Corta la corriente.").delivered);
    assert.equal(hostGot.filter((e) => e.t === "message").length, 1);
    assert.equal(got.filter((e) => e.t === "message").length, 1, "sender does not hear itself");

    // validation
    assert.equal(store.post(made.code, "nope", "hi").status, 404);
    assert.equal(store.post(made.code, made.pid, "   ").status, 400);
    assert.equal(store.post(made.code, made.pid, "x".repeat(ROOM_MAX_TEXT_CHARS + 1)).status, 413);

    // send rate limit (per participant, windowed)
    let limited = 0;
    for (let i = 0; i < ROOM_SEND_LIMIT + 5; i += 1) {
      if (store.post(made.code, made.pid, "ping").status === 429) limited += 1;
    }
    assert.ok(limited >= 5);
    t += 11_000;
    assert.ok(store.post(made.code, made.pid, "ok again").ok);

    // disconnect → partner sees offline; reconnect replaces the stream
    sub.unsubscribe();
    assert.deepEqual(hostGot.filter((e) => e.t === "peer").pop(), { t: "peer", language: "es", online: false });

    // leave removes the participant and frees the slot
    store.leave(made.code, joined.pid);
    assert.equal(store.post(made.code, made.pid, "anyone?").status, 409);
    assert.ok(store.join(made.code, "es").ok);
    store.leave(made.code, made.pid);
  }

  // --- sweep drops idle rooms and participants that never reconnect
  {
    let t = 0;
    const store = new RoomStore(() => t);
    const a = store.create("en");
    assert.equal(store.size, 1);
    t += ROOM_IDLE_TTL_MS + 1;
    store.sweep();
    assert.equal(store.size, 0, "idle room removed");

    const b = store.create("es");
    const c = store.join(b.code, "en");
    const live = store.subscribe(b.code, b.pid, () => {});
    const sub2 = store.subscribe(b.code, c.pid, () => {});
    sub2.unsubscribe();
    t += ROOM_OFFLINE_GRACE_MS + 1;
    store.sweep();
    assert.equal(store.post(b.code, b.pid, "hola").status, 409, "absent guest dropped after grace");
    live.unsubscribe();
  }

  // --- HTTP + SSE through the real Express app
  const { default: app } = await bundle("src/app.ts").then((m) => ({ default: m.default }));
  const server = http.createServer(app);
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const port = server.address().port;
  try {
    assert.equal((await request(port, "POST", "/api/rooms", { language: "fr" })).status, 400);

    const created = await request(port, "POST", "/api/rooms", { language: "en" });
    assert.equal(created.status, 201);
    const { code, pid: hostPid } = created.json;

    assert.equal((await request(port, "GET", `/api/rooms/${code}/events?pid=bad`)).status, 404);
    assert.equal((await request(port, "POST", `/api/rooms/${code}/join`, { language: "en" })).status, 409);
    const joined = await request(port, "POST", `/api/rooms/${code}/join`, { language: "es" });
    assert.equal(joined.status, 200);
    assert.equal(joined.json.partnerLanguage, "en");

    const host = openStream(port, `/api/rooms/${code}/events?pid=${hostPid}`);
    const guest = openStream(port, `/api/rooms/${code}/events?pid=${joined.json.pid}`);
    await Promise.all([host.ready, guest.ready]);
    await host.next((e) => e.t === "ready");
    await guest.next((e) => e.t === "ready" && e.partnerLanguage === "en");
    await host.next((e) => e.t === "peer" && e.language === "es" && e.online === true);

    const posted = await request(port, "POST", `/api/rooms/${code}/messages`, { pid: hostPid, text: "Where's the breaker?" });
    assert.equal(posted.status, 202);
    const heard = await guest.next((e) => e.t === "message");
    assert.equal(heard.text, "Where's the breaker?");
    assert.equal(heard.language, "en");

    const reply = await request(port, "POST", `/api/rooms/${code}/messages`, { pid: joined.json.pid, text: "Está en el garaje." });
    assert.equal(reply.status, 202);
    const back = await host.next((e) => e.t === "message");
    assert.equal(back.language, "es");

    assert.equal((await request(port, "POST", `/api/rooms/${code}/messages`, { pid: "nope", text: "x" })).status, 404);

    host.close();
    await guest.next((e) => e.t === "peer" && e.online === false);
    guest.close();
    assert.equal((await request(port, "POST", `/api/rooms/${code}/leave`, { pid: hostPid })).status, 204);
  } finally {
    server.closeAllConnections?.();
    await new Promise((r) => server.close(r));
  }

  console.log("rooms.test.cjs ok");
  process.exit(0);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
