"use strict";

/**
 * Signed contractor share tokens: round-trip, payload caps, HTTP create/read.
 * Run: node ./tests/share-token.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const esbuild = require("esbuild");
const express = require("express");

const src = path.join(__dirname, "..", "src");
const outfile = path.join(os.tmpdir(), `beckify-share-token-${process.pid}.cjs`);

esbuild.buildSync({
  entryPoints: [path.join(src, "lib", "shareToken.ts")],
  bundle: true,
  platform: "node",
  format: "cjs",
  outfile,
  logLevel: "silent",
});

const share = require(outfile);

const secret = "test-share-hmac-secret";
const input = {
  tool: "voltage-drop",
  contractor: "  Acme   Electric  ",
  fields: [
    { label: "Voltage drop", value: "6.02 V" },
    { label: "Drop", value: "1.25%" },
  ],
};

const checked = share.validateShareInput(input);
assert.equal(checked.ok, true);
assert.equal(checked.contractor, "Acme Electric");

const payload = share.buildSharePayload(checked, "2026-10-03T04:00:00.000Z");
const token = share.signShareToken(payload, secret);
const opened = share.verifyShareToken(token, secret);
assert.equal(opened.contractor, "Acme Electric");
assert.equal(opened.tool, "voltage-drop");
assert.equal(opened.fields[0].value, "6.02 V");
assert.equal(opened.createdAt, "2026-10-03T04:00:00.000Z");
assert.equal(share.sharePageURL(token, "https://beckify.com"), `https://beckify.com/share/${token}`);

const [body, sig] = token.split(".");
const forged = `${Buffer.from(JSON.stringify({ ...payload, contractor: "Someone Else" })).toString("base64url")}.${sig}`;
assert.equal(share.verifyShareToken(forged, secret), null);
assert.equal(share.verifyShareToken(token, "another-secret-value"), null);
assert.equal(share.verifyShareToken("not-a-token", secret), null);

assert.equal(share.validateShareInput({ tool: "look-check", contractor: "A", fields: [{ label: "A", value: "B" }] }).ok, false);
assert.equal(share.validateShareInput({ tool: "conduit-fill", contractor: "", fields: [{ label: "A", value: "B" }] }).ok, false);
assert.equal(share.validateShareInput({
  tool: "conduit-fill",
  contractor: "A".repeat(81),
  fields: [{ label: "Fill", value: "40%" }],
}).ok, false);
assert.equal(share.validateShareInput({
  tool: "conduit-fill",
  contractor: "North\nSide",
  fields: [{ label: "Fill", value: "40%" }],
}).ok, false);
assert.equal(share.validateShareInput({
  tool: "conduit-fill",
  contractor: "North Side",
  fields: Array.from({ length: 17 }, (_, i) => ({ label: `L${i}`, value: "1" })),
}).ok, false);

const routeSrc = fs.readFileSync(path.join(src, "routes", "share.ts"), "utf8");
assert.match(routeSrc, /SHARE_HMAC_SECRET/);
assert.doesNotMatch(routeSrc, /billingStatus|stripe|StoreKit|\$1/i);
assert.match(routeSrc, /429/);
assert.match(fs.readFileSync(path.join(src, "routes", "health.ts"), "utf8"), /\/api\/share/);

const routeOut = path.join(os.tmpdir(), `beckify-share-route-${process.pid}.cjs`);
esbuild.buildSync({
  entryPoints: [path.join(src, "routes", "share.ts")],
  bundle: true,
  platform: "node",
  format: "cjs",
  outfile: routeOut,
  external: ["express"],
  logLevel: "silent",
});

process.env.SHARE_HMAC_SECRET = secret;
process.env.SHARE_PUBLIC_ORIGIN = "https://beckify.com";
const router = require(routeOut).default;
const app = express();
app.use(express.json({ limit: "64kb" }));
app.use("/api", router);

(async () => {
  const server = app.listen(0, "127.0.0.1");
  const port = await new Promise((resolve) => {
    server.once("listening", () => resolve(server.address().port));
  });
  const base = `http://127.0.0.1:${port}`;

  const bad = await fetch(`${base}/api/share`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  assert.equal(bad.status, 400);

  const created = await fetch(`${base}/api/share`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      tool: "conduit-fill",
      contractor: "Harbor Electric",
      fields: [{ label: "Actual fill", value: "28%" }, { label: "Status", value: "PASS" }],
    }),
  });
  assert.equal(created.status, 200);
  const createdJson = await created.json();
  assert.match(createdJson.url, /^https:\/\/beckify\.com\/share\/[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  assert.equal(createdJson.tool, "conduit-fill");
  assert.equal("billingStatus" in createdJson, false);

  const token = createdJson.url.split("/share/")[1];
  const read = await fetch(`${base}/api/share/${token}`);
  assert.equal(read.status, 200);
  const readJson = await read.json();
  assert.equal(readJson.contractor, "Harbor Electric");
  assert.equal(readJson.fields[1].value, "PASS");
  assert.equal(readJson.title, "Conduit Fill");

  const missing = await fetch(`${base}/api/share/${token}x`);
  assert.equal(missing.status, 404);

  delete process.env.SHARE_HMAC_SECRET;
  const unconfigured = await fetch(`${base}/api/share`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      tool: "voltage-drop",
      contractor: "Harbor Electric",
      fields: [{ label: "Drop", value: "1%" }],
    }),
  });
  assert.equal(unconfigured.status, 503);

  server.close();
  fs.rmSync(outfile, { force: true });
  fs.rmSync(routeOut, { force: true });
  console.log("share-token.test.cjs: ok");
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
