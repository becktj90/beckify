const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');

const arcade = path.join(__dirname, '..', 'public/arcade/kestrel-heavy/js');

test('touch steer dead zone, clamp, and release', async () => {
  const {
    createInput,
    setTouchSteer,
    peekTouchSteer,
    flightAxis,
    clearFlightHolds,
    TOUCH_STEER_DEAD_PX,
    TOUCH_STEER_FULL_PX,
  } = await import(path.join(arcade, 'input.js'));

  assert.equal(peekTouchSteer(0), 0);
  assert.equal(peekTouchSteer(TOUCH_STEER_DEAD_PX - 1), 0);
  assert.ok(peekTouchSteer(TOUCH_STEER_DEAD_PX + 1) > 0);
  assert.equal(peekTouchSteer(TOUCH_STEER_FULL_PX, true), 1);
  assert.equal(peekTouchSteer(-TOUCH_STEER_FULL_PX - 40, true), -1);

  const input = createInput();
  assert.equal(setTouchSteer(input, 8), null);
  assert.equal(input.touchSteer, null);
  assert.equal(input.touchSteerArmed, false);

  const armed = setTouchSteer(input, 40);
  assert.ok(armed > 0 && armed < 1);
  assert.equal(input.touchSteerArmed, true);
  assert.equal(flightAxis(input, 640, 140), input.touchSteer);

  setTouchSteer(input, 8);
  assert.ok(input.touchSteer !== null, 'once armed, small drag still steers');

  setTouchSteer(input, null);
  assert.equal(input.touchSteer, null);
  assert.equal(input.touchSteerArmed, false);
  assert.equal(flightAxis(input, 640, 140), 0);

  input.left = true;
  assert.equal(flightAxis(input, 640, 140), -1);
  clearFlightHolds(input);
  assert.equal(input.thumbHeld, false);
  assert.equal(input.touchSteer, null);
});

test('Haven glide hold does not arm climb until the burn label', async () => {
  const { climbArmedFromLabel, paintThumbSteer } = await import(path.join(arcade, 'input.js'));
  assert.equal(climbArmedFromLabel('GLIDE'), false);
  assert.equal(climbArmedFromLabel('HOLD TO BURN'), true);
  assert.equal(climbArmedFromLabel('HOLD · DRAG'), true);

  const node = {
    dataset: {},
    style: { props: {}, setProperty(name, value) { this.props[name] = value; } },
    classList: { flags: {}, toggle(name, on) { this.flags[name] = Boolean(on); } },
  };
  paintThumbSteer(node, 0.8);
  assert.equal(node.dataset.steer, '0.80');
  assert.equal(node.style.props['--kh-steer'], '0.8');
  assert.equal(node.classList.flags['is-steer-right'], true);
  paintThumbSteer(node, 0);
  assert.equal(node.dataset.steer, '0.00');
  assert.equal(node.classList.flags['is-steer-right'], false);
});
