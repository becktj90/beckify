"use strict";

/**
 * Signed contractor share tokens: round-trip, payload caps, and route contract.
 * Run: node ./tests/share-token.test.cjs
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const esbuild = require("esbuild");

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

console.log("share-token.test.cjs: ok");
fs.rmSync(outfile, { force: true });
