/* Number-base converter — round-trips, wrapping, two’s complement. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  BigInt,
  isFinite,
  parseInt,
  setTimeout,
  clearTimeout,
  document: {
    getElementById() { return null; },
    querySelector() { return null; },
    addEventListener() {},
    readyState: 'complete',
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.runInContext(
  fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'js', 'base-converter.js'), 'utf8'),
  vm.createContext(sandbox),
  { filename: 'base-converter.js' }
);

const api = sandbox.__baseConverterTestApi;
assert.ok(api && typeof api.roundTrip === 'function', 'test API exported');

/* ── Round-trip: hex → all bases → hex at 32-bit ── */
{
  const r = api.roundTrip('DEADBEEF', 16, 32, false);
  assert.equal(r.hex, 'DEADBEEF');
  assert.equal(r.dec, '3735928559');
  assert.equal(r.oct, '33653337357');
  assert.equal(r.bin, '11011110101011011011111011101111');
  const back = api.roundTrip(r.bin, 2, 32, false);
  assert.equal(back.hex, 'DEADBEEF');
  const fromOct = api.roundTrip(r.oct, 8, 32, false);
  assert.equal(fromOct.dec, r.dec);
  const fromDec = api.roundTrip(r.dec, 10, 32, false);
  assert.equal(fromDec.hex, 'DEADBEEF');
}

/* ── Grouped / prefixed input still round-trips ── */
{
  const r = api.parseBase('0xDE AD BE EF', 16, 32, false);
  assert.equal(api.formatBase(r, 16, 32, false), 'DEADBEEF');
  const b = api.parseBase('1101_1110 1010_1101', 2, 16, false);
  assert.equal(api.formatBase(b, 16, 16, false), 'DEAD');
}

/* ── Wrapping at width: 256 at 8-bit → 0; 0x1FF at 8-bit → 0xFF ── */
{
  assert.equal(api.wrapWidth(256n, 8), 0n);
  assert.equal(api.parseBase('256', 10, 8, false), 0n);
  assert.equal(api.parseBase('1FF', 16, 8, false), 0xFFn);
  assert.equal(api.formatBase(256n, 16, 8, false), '00');
  // 2^32 wraps to 0 at 32-bit; 2^32 + 1 → 1
  assert.equal(api.wrapWidth(4294967296n, 32), 0n);
  assert.equal(api.wrapWidth(4294967297n, 32), 1n);
}

/* ── Signed two’s complement: 0xFF at 8-bit is −1; 0x80 is −128 ── */
{
  assert.equal(api.toSigned(0xFFn, 8), -1n);
  assert.equal(api.toSigned(0x80n, 8), -128n);
  assert.equal(api.toSigned(0x7Fn, 8), 127n);
  assert.equal(api.fromSigned(-1n, 8), 0xFFn);
  assert.equal(api.fromSigned(-128n, 8), 0x80n);
  const r = api.roundTrip('FF', 16, 8, true);
  assert.equal(r.signed, '-1');
  const fromSignedDec = api.roundTrip('-1', 10, 8, true);
  assert.equal(fromSignedDec.hex, 'FF');
  assert.equal(fromSignedDec.bin, '11111111');
  // 16-bit: 0x8000 = −32768
  assert.equal(api.toSigned(0x8000n, 16), -32768n);
}

/* ── Signed decimal positive overflow is rejected, not silently wrapped ── */
{
  assert.throws(
    () => api.parseBase('200', 10, 8, true),
    /outside/,
    '200 is outside 8-bit signed range'
  );
  assert.throws(
    () => api.parseBase('128', 10, 8, true),
    /outside/,
    '128 is outside 8-bit signed range (−128 … 127)'
  );
  assert.throws(
    () => api.parseBase('+128', 10, 8, true),
    /outside/
  );
  assert.equal(api.parseBase('127', 10, 8, true), 127n);
  assert.equal(api.parseBase('-128', 10, 8, true), 0x80n);
  // Unsigned still wraps at width; signed decimal of the same magnitude is rejected.
  assert.equal(api.parseBase('256', 10, 8, false), 0n);
  assert.throws(() => api.parseBase('256', 10, 8, true), /outside/);
}

/* ── 64-bit stays exact (beyond Number.MAX_SAFE_INTEGER) ── */
{
  const r = api.roundTrip('FFFFFFFFFFFFFFFF', 16, 64, false);
  assert.equal(r.dec, '18446744073709551615');
  assert.equal(api.toSigned((1n << 64n) - 1n, 64), -1n);
  const big = api.roundTrip('9007199254740993', 10, 64, false); // 2^53 + 1
  assert.equal(big.dec, '9007199254740993');
}

console.log('Base converter verified: round-trips, wrapping at width, signed two’s complement, 64-bit exactness');
