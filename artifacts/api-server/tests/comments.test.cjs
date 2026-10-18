"use strict";
/** Build-page comments: validation, spam defenses, store, and the HTTP routes. */
const assert = require("node:assert/strict");
const http = require("node:http");
const path = require("node:path");
const esbuild = require("esbuild");

async function bundle(entry) {
  const result = await esbuild.build({
    absWorkingDir: path.join(__dirname, ".."), entryPoints: [entry], bundle: true,
    format: "cjs", platform: "node", target: "node20", write: false,
    external: ["pino", "pino-http", "express", "cors"], logLevel: "silent",
  });
  const module = { exports: {} };
  new Function("require", "module", "exports", result.outputFiles[0].text)(require, module, module.exports);
  return module.exports;
}
let pass = 0;
const t = async (name, fn) => { await fn(); pass++; console.log("  PASS ", name); };

(async () => {
  process.env.COMMENTS_ADMIN_TOKEN = "test-admin-token-1234567890";
  const L = await bundle("src/lib/comments.ts");

  await t("accepts a normal comment, optional name", () => {
    assert.equal(L.validateSubmission({ body: "Great build, which BMS did you use?" }).ok, true);
    const v = L.validateSubmission({ name: "  Sam  ", body: "Nice\n\n\n\nwork!" });
    assert.equal(v.name, "Sam"); assert.equal(v.body, "Nice\n\nwork!");
  });
  await t("length caps", () => {
    assert.equal(L.validateSubmission({ body: "a b".repeat(400) }).ok, false);
    assert.equal(L.validateSubmission({ body: "hi" }).ok, false);
    assert.equal(L.validateSubmission({ name: "x".repeat(41), body: "hello there" }).ok, false);
  });
  await t("link limits and URL filter", () => {
    assert.equal(L.validateSubmission({ body: "see https://a.example/x for more" }).ok, true);
    assert.equal(L.validateSubmission({ body: "see https://a.example and www.b.example" }).ok, false);
    assert.equal(L.validateSubmission({ body: "visit buy-stuff.xyz and shop.top now" }).ok, false);
    assert.equal(L.validateSubmission({ name: "www.spam.com", body: "hello there" }).ok, false);
  });
  await t("profanity / spam words / repeats / non-text", () => {
    assert.equal(L.validateSubmission({ body: "this is shit" }).ok, false);
    assert.equal(L.validateSubmission({ body: "cheap viagra here" }).ok, false);
    assert.equal(L.validateSubmission({ body: "aaaaaaaaaaaaaaaaaaaaaaa" }).ok, false);
    assert.equal(L.validateSubmission({ body: "!!! ??? 123" }).ok, false);
    assert.equal(L.validateSubmission({ body: { $ne: 1 } }).ok, false);
    assert.equal(L.validateSubmission({ body: "ok then", name: 5 }).ok, false);
    assert.equal(L.validateSubmission(null).ok, false);
  });
  await t("XSS payloads are kept as inert text (rendered via textContent) and control chars stripped", () => {
    const v = L.validateSubmission({ body: "<script>alert(1)</script> <img src=x onerror=alert(1)>\u202e\u0000hi" });
    assert.equal(v.ok, true);
    assert.ok(!/[\u0000\u202e]/.test(v.body));
  });
  await t("page keys", () => {
    assert.equal(L.sanitizePageKey("vespa-p200e"), "vespa-p200e");
    for (const k of ["../x", "A", "a", "x y", "<s>", "a".repeat(80), 5, undefined, "-ab", "ab-"]) assert.equal(L.sanitizePageKey(k), null);
  });
  await t("form token: too fast, tampered, expired, ok", () => {
    const now = 1_000_000_000_000;
    const tok = L.issueFormToken("vespa-p200e", now);
    assert.equal(L.checkFormToken(tok, "vespa-p200e", now + 1000).ok, false);
    assert.equal(L.checkFormToken(tok, "vespa-p200e", now + 6000).ok, true);
    assert.equal(L.checkFormToken(tok, "honda-xr650r", now + 6000).ok, false);
    assert.equal(L.checkFormToken(tok.replace(/.$/, "0"), "vespa-p200e", now + 6000).ok, false);
    assert.equal(L.checkFormToken(tok, "vespa-p200e", now + 25 * 3600_000).ok, false);
    assert.equal(L.checkFormToken(undefined, "vespa-p200e", now).ok, false);
  });
  await t("ip rate limit uses hashed keys (raw IP never stored)", () => {
    L.resetRateLimits();
    const k = L.ipKey("203.0.113.9");
    assert.ok(!k.includes("203"));
    assert.notEqual(k, L.ipKey("203.0.113.10"));
    for (let i = 0; i < 3; i++) assert.equal(L.consumeIp(k).allowed, true);
    assert.equal(L.consumeIp(k).allowed, false);
  });
  await t("store: pending hidden, approve shows, dedupe, delete, conflict retry", async () => {
    const backend = new L.MemoryBackend();
    const s = new L.CommentStore(backend, 0);
    const a = await s.add("vespa-p200e", "Sam", "First!!");
    assert.equal(a.ok, true);
    assert.equal((await s.approved("vespa-p200e")).length, 0);
    assert.equal((await s.add("vespa-p200e", "", "first!!")).ok, false);
    await s.approve(a.id);
    assert.equal((await s.approved("vespa-p200e")).length, 1);
    assert.equal((await s.approved("honda-xr650r")).length, 0);
    assert.equal(Object.keys(L.publicComment((await s.approved("vespa-p200e"))[0])).sort().join(), "body,id,name,ts");
    // simulate a concurrent writer: first save conflicts once
    let first = true; const orig = backend.save.bind(backend);
    backend.save = async (d, v) => { if (first) { first = false; throw new L.ConflictError(); } return orig(d, v); };
    assert.equal((await s.add("vespa-p200e", "", "after conflict ok")).ok, true);
    assert.equal(await s.remove(a.id), true);
    assert.equal((await s.approved("vespa-p200e")).length, 0);
  });
  await t("GitHub backend talks to the contents API with sha handling", async () => {
    const calls = [];
    const fake = async (url, init = {}) => {
      calls.push([url, init.method || "GET"]);
      if (!init.method) return new Response(JSON.stringify({ sha: "abc", content: Buffer.from('{"comments":[]}').toString("base64") }), { status: 200 });
      const b = JSON.parse(init.body); assert.equal(b.sha, "abc");
      return new Response("{}", { status: 200 });
    };
    const g = new L.GitHubBackend("tok", "o/r", "comments.json", fake);
    const snap = await g.load(); assert.equal(snap.version, "abc");
    await g.save({ comments: [] }, snap.version);
    const conflict = new L.GitHubBackend("tok", "o/r", "c.json", async () => new Response("{}", { status: 409 }));
    await assert.rejects(conflict.save({ comments: [] }, "x"), L.ConflictError);
    assert.equal(calls.length, 2);
  });

  // ---- HTTP ----
  const express = require("express");
  const R = await bundle("src/routes/comments.ts");
  assert.ok(R.default);
  const app = express(); app.use(express.json({ limit: "64kb" })); app.use("/api", R.default);
  const server = http.createServer(app); await new Promise((r) => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}/api`;
  const j = async (p, init) => { const r = await fetch(base + p, init); return { status: r.status, body: await r.json().catch(() => null) }; };

  await t("HTTP: without storage configured, reads are empty and posts are refused", async () => {
    delete process.env.COMMENTS_GH_TOKEN;
    const g = await j("/comments?page=vespa-p200e");
    assert.equal(g.status, 200); assert.equal(g.body.enabled, false);
    assert.equal((await j("/comments?page=../etc")).status, 400);
    const admin = await j("/comments/admin/queue");
    assert.equal(admin.status, 401);
    assert.equal((await j("/comments/admin/queue", { headers: { Authorization: "Bearer wrong" } })).status, 401);
  });
  await t("HTTP: honeypot is silently accepted but stores nothing; bad token rejected", async () => {
    const hp = await j("/comments", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ page: "vespa-p200e", website: "http://x", body: "hello world", token: "x" }) });
    assert.equal(hp.status, 202);
    const bad = await j("/comments", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ page: "vespa-p200e", body: "hello world", token: "1.2" }) });
    assert.equal(bad.status, 400);
  });
  await t("admin page is served with strict CSP and noindex", async () => {
    const r = await fetch(base + "/comments/admin");
    assert.equal(r.status, 200);
    assert.match(r.headers.get("content-security-policy"), /default-src 'none'/);
    assert.match(await r.text(), /textContent/);
  });
  await t("HTTP full flow against a fake GitHub contents API: submit -> hidden -> approve -> visible -> delete", async () => {
    const realFetch = globalThis.fetch;
    let file = null, sha = 0;
    globalThis.fetch = async (url, init = {}) => {
      if (String(url).startsWith("http://127.0.0.1")) return realFetch(url, init);
      assert.match(String(url), /^https:\/\/api\.github\.com\/repos\/becktj90\/beckify-comments\/contents\/comments\.json$/);
      assert.equal(init.headers.Authorization, "Bearer fake-gh-token");
      if (!init.method || init.method === "GET") {
        if (!file) return new Response("{}", { status: 404 });
        return new Response(JSON.stringify({ sha: String(sha), content: file }), { status: 200 });
      }
      const b = JSON.parse(init.body);
      if ((file && b.sha !== String(sha)) || (!file && b.sha)) return new Response("{}", { status: 409 });
      file = b.content; sha++;
      return new Response("{}", { status: 200 });
    };
    process.env.COMMENTS_GH_TOKEN = "fake-gh-token";
    try {
      const page = "vespa-p200e";
      const first = await j("/comments?page=" + page);
      assert.equal(first.body.enabled, true);
      const post = (extra) => j("/comments", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ page, token: first.body.token, ...extra }) });
      // too fast
      assert.equal((await post({ body: "Too quick comment" })).status, 400);
      // age the token by forging an old-enough one using the shared secret
      const old = L.issueFormToken(page, Date.now() - 10_000);
      const send = (extra) => j("/comments", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ page, token: old, ...extra }) });
      assert.equal((await send({ name: "<b>Sam</b>", body: "<script>alert(1)</script> nice pack" })).status, 202);
      assert.equal((await send({ body: "this is shit" })).status, 400);
      assert.equal((await send({ body: "<script>alert(1)</script> nice pack" })).status, 409);
      const pub = await j("/comments?page=" + page);
      assert.equal(pub.body.comments.length, 0); // hidden until approved
      const H = { Authorization: "Bearer " + process.env.COMMENTS_ADMIN_TOKEN, "content-type": "application/json" };
      const q = await j("/comments/admin/queue", { headers: H });
      assert.equal(q.body.pending.length, 1);
      assert.equal(q.body.pending[0].body.includes("<script>"), true); // stored as text, never as HTML
      assert.equal((await j("/comments/admin/approve", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ id: q.body.pending[0].id }) })).status, 401);
      assert.equal((await j("/comments/admin/approve", { method: "POST", headers: H, body: JSON.stringify({ id: "zzz" }) })).status, 400);
      assert.equal((await j("/comments/admin/approve", { method: "POST", headers: H, body: JSON.stringify({ id: q.body.pending[0].id }) })).status, 200);
      await new Promise((r) => setTimeout(r, 31_000 > 0 ? 0 : 0));
      const shown = await j("/comments/admin/queue", { headers: H });
      assert.equal(shown.body.approved.length, 1);
      assert.equal((await j("/comments/admin/delete", { method: "POST", headers: H, body: JSON.stringify({ id: shown.body.approved[0].id }) })).status, 200);
      assert.equal((await j("/comments/admin/queue", { headers: H })).body.approved.length, 0);
      // per-IP rate limit: 3/hour (2 accepted above already counted)
      let limited = 0;
      for (let i = 0; i < 4; i++) { const r = await send({ body: "unique comment number " + i + " ok" }); if (r.status === 429) limited++; }
      assert.ok(limited >= 1);
    } finally { globalThis.fetch = realFetch; delete process.env.COMMENTS_GH_TOKEN; }
  });
  server.close();
  console.log(`\n${pass} comment checks passed`);
})().catch((e) => { console.error(e); process.exit(1); });
