const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');

const arcade = path.join(__dirname, '..', 'public/arcade/kestrel-heavy/js');

test('ascent science evolves through Max-Q and MECO', async () => {
  const { computeTelemetry, formatScience } = await import(path.join(arcade, 'telemetry.js'));
  const pad = computeTelemetry({ status: 'PRELAUNCH', tClock: -4, throttle: 0.2, fuel: 100, charge: 0.4 });
  const early = computeTelemetry({ status: 'ASCENT', tClock: 6, throttle: 1, fuel: 88 });
  const maxq = computeTelemetry({ status: 'ASCENT', tClock: 21.6, throttle: 0.92, fuel: 62 });
  const meco = computeTelemetry({ status: 'ASCENT', tClock: 38.8, throttle: 0.2, fuel: 18 });
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

  for (const id of ['corridor', 'corridorEdge', 'fuel', 'hazard', 'maxq', 'attitude', 'sepFoul', 'recontact', 'tip', 'salvage', 'splash', 'fuelHaven']) {
    const abort = describeAbort(id);
    assert.ok(ABORTS[id], id);
    assert.ok(abort.reason, id);
    assert.ok(abort.banner, id);
    assert.ok(abort.coach, id);
    assert.ok(abort.radio.length >= 1, id);
    assert.doesNotMatch(abort.reason, /Jacklyn|New Glenn|Blue Origin|LC-36/);
  }
});

test('one-thumb climb drag arms analog steer without stealing pads', async () => {
  const {
    createInput,
    setTouchSteer,
    flightAxis,
    steerAxis,
    clearFlightHolds,
    TOUCH_STEER_DEAD_PX,
    TOUCH_STEER_FULL_PX,
  } = await import(path.join(arcade, 'input.js'));

  const input = createInput();
  input.left = true;
  setTouchSteer(input, TOUCH_STEER_DEAD_PX - 2);
  assert.equal(input.touchSteer, null, 'inside deadzone, ◀ ▶ / canvas analog stay live');
  assert.equal(flightAxis(input, 640, 140), -1);

  setTouchSteer(input, TOUCH_STEER_FULL_PX);
  assert.equal(input.touchSteer, 1);
  assert.equal(flightAxis(input, 640, 140), 1, 'armed drag wins over digital pads');

  setTouchSteer(input, -TOUCH_STEER_FULL_PX / 2);
  assert.ok(input.touchSteer < 0 && input.touchSteer > -1);

  input.pointerX = 900;
  input.touchSteer = null;
  input.touchSteerArmed = false;
  assert.equal(flightAxis(input, 640, 140), 1);
  input.pointerX = null;
  assert.equal(flightAxis(input, 640, 140), steerAxis(input));

  clearFlightHolds(input);
  assert.equal(input.touchSteer, null);
  assert.equal(input.touchSteerArmed, false);
  assert.equal(input.left, false);
});

test('corridor rails are play bounds and beat goals stay readable', async () => {
  const { corridorBounds, corridorEdge, clampToCorridor } = await import(path.join(arcade, 'corridor.js'));
  const { playGoal, playNext, beatsFor, nextCoachBeat } = await import(path.join(arcade, 'sequence.js'));
  const { PAD_ROCKET_X, PAD_ROCKET_Y } = await import(path.join(arcade, 'config.js'));

  const pad = corridorBounds(PAD_ROCKET_Y);
  assert.ok(PAD_ROCKET_X > pad.left && PAD_ROCKET_X < pad.right, 'pad stack starts inside the rails');
  assert.equal(corridorEdge(PAD_ROCKET_X, PAD_ROCKET_Y).state, 'ok');
  assert.equal(corridorEdge(pad.left - 20, PAD_ROCKET_Y).state, 'out');
  assert.equal(corridorEdge(pad.left + 8, PAD_ROCKET_Y).state, 'warn');
  const bounced = clampToCorridor(0, PAD_ROCKET_Y);
  assert.ok(bounced > pad.left);

  const mission = { id: 'KH-1', payload: 'Aether Scout', mark: 'AES', objective: { id: 'shield', label: 'Grab an aero shield' } };
  assert.match(playGoal('PRELAUNCH', { tClock: -4 }, mission), /HOLD CLIMB/);
  assert.match(playGoal('ASCENT', { tClock: 6, objectiveDone: false }, mission), /corridor/);
  assert.match(playGoal('ASCENT', { tClock: 6, objectiveDone: false }, mission), /aero shield/);
  assert.match(playGoal('ASCENT', { tClock: 18.6 }, mission), /Max-Q/);
  assert.match(playGoal('SEP', { sepPhase: 'window' }, mission), /SEPARATE/);
  assert.match(playGoal('JACKLYN', { jacklynPhase: 'glide', jacklynElapsed: 1 }, mission), /glide|STRAKES/i);
  assert.match(playGoal('JACKLYN', { jacklynPhase: 'burn', jacklynElapsed: 8 }, mission), /landing burn/i);

  const beats = beatsFor(mission);
  const next = nextCoachBeat(beats, -7);
  assert.ok(next);
  assert.match(playNext(beats, -7, 'PRELAUNCH'), /NEXT ·/);
  assert.ok(beats.filter((b) => b.quiet).length >= 4, 'filler beats stay quiet');
});
