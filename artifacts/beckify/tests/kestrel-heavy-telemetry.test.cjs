const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');

const arcade = path.join(__dirname, '..', 'public/arcade/kestrel-heavy/js');

test('ascent science evolves through Max-Q and MECO', async () => {
  const { computeTelemetry, formatScience } = await import(path.join(arcade, 'telemetry.js'));
  const pad = computeTelemetry({ status: 'PRELAUNCH', tClock: -4, throttle: 0.2, fuel: 100, charge: 0.4 });
  const early = computeTelemetry({ status: 'ASCENT', tClock: 6, throttle: 1, fuel: 88 });
  const maxq = computeTelemetry({ status: 'ASCENT', tClock: 18.6, throttle: 0.92, fuel: 62 });
  const meco = computeTelemetry({ status: 'ASCENT', tClock: 38.4, throttle: 0.2, fuel: 18 });
  const sep = computeTelemetry({
    status: 'SEP', tClock: 40, throttle: 0.2, fuel: 18, altitudeKm: 54, sepPhase: 'coast', prevVelMs: 400,
  });
  const haven = computeTelemetry({
    status: 'JACKLYN', tClock: 70, throttle: 1, fuel: 24, altitudeKm: 4, vy: 1.6,
  });

  assert.equal(pad.velMs, 0);
  assert.ok(early.velMs > 100 && early.velMs < maxq.velMs);
  assert.ok(maxq.qKpa > early.qKpa, 'q should peak near Max-Q');
  assert.ok(maxq.qKpa > meco.qKpa, 'q should fall after Max-Q');
  assert.ok(maxq.mach > 1, 'Max-Q is supersonic on the compressed spine');
  assert.ok(meco.velMs > 2000, 'MECO velocity is science-shaped, not fluff');
  assert.ok(meco.altKm > maxq.altKm);
  assert.ok(meco.twr < maxq.twr || meco.chamberPct < 30);
  assert.ok(sep.accG < 0.5, 'MECO/sep must not inherit a fake g spike');
  assert.ok(haven.fpaDeg < 0, 'Haven is a descent');
  assert.ok(haven.mach < 0.5);

  const kid = formatScience(maxq, 'KID');
  const cadet = formatScience(maxq, 'CADET');
  assert.match(kid.ticker, /km ·/);
  assert.match(cadet.ticker, /M /);
  assert.match(cadet.ticker, /kPa/);
  assert.equal(kid.dense, false);
  assert.equal(cadet.dense, true);
});

test('voice pools do not repeat the same line back-to-back', async () => {
  const { createVoice, pickLine, speak, ABORTS, describeAbort } = await import(path.join(arcade, 'voice.js'));
  const voice = createVoice();
  const mission = { id: 'KH-1', payload: 'Aether Scout', mark: 'AES' };
  const seen = new Set();
  let prev = '';
  for (let i = 0; i < 6; i += 1) {
    const line = pickLine(voice, 'liftoff', mission);
    assert.ok(line.includes('KH-1') || /Liftoff|tower|pad|climbing/i.test(line));
    assert.notEqual(line, prev, 'liftoff variants must rotate');
    seen.add(line);
    prev = line;
  }
  assert.ok(seen.size >= 2);

  voice.beginFlight();
  const first = speak(voice, 'maxq', { mission, t: 18 });
  const again = speak(voice, 'maxq', { mission, t: 18.4 });
  assert.ok(first);
  assert.equal(again, null, 'phase-once callouts must not re-fire');

  const alignA = speak(voice, 'align-green', { mission, t: 40 });
  const alignB = speak(voice, 'align-green', { mission, t: 40.5 });
  assert.ok(alignA);
  assert.equal(alignB, null, 'align-green is on cooldown');

  for (const id of ['corridor', 'fuel', 'hazard', 'maxq', 'attitude', 'sepFoul', 'recontact', 'tip', 'salvage', 'splash', 'fuelHaven']) {
    const abort = describeAbort(id);
    assert.ok(ABORTS[id], id);
    assert.ok(abort.reason, id);
    assert.ok(abort.banner, id);
    assert.ok(abort.coach, id);
    assert.ok(abort.radio.length >= 1, id);
    assert.doesNotMatch(abort.reason, /Jacklyn|New Glenn|Blue Origin|LC-36/);
  }
});
