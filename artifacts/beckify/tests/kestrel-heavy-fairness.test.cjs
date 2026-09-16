const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const arcade = path.join(__dirname, '..', 'public/arcade/kestrel-heavy/js');

test('near-misses do not INT-hit; only honest overlaps count', async () => {
  const {
    HAZARD_CANVAS,
    HAZARD_RADIUS,
    GRAZE_PAD,
    contactsHazard,
    isNearMiss,
    hazardRadius,
    rocketHitSize,
  } = await import(path.join(arcade, 'hit.js'));

  assert.ok(hazardRadius('bird') < HAZARD_CANVAS / 2, 'body tighter than 48px canvas');
  assert.ok(hazardRadius('ice') <= HAZARD_RADIUS.ice + GRAZE_PAD + 0.01);
  const rocket = { x: 400, y: 400, scaleX: 1.18 };
  const box = rocketHitSize(false);
  const hw = (box.width * 1.18) / 2;
  const far = { x: rocket.x + hw + 28, y: rocket.y, scaleX: 1 };
  assert.equal(contactsHazard(rocket, far, 'bird', false), false);
  assert.equal(isNearMiss(rocket, far, 'bird', false), true, 'old fat pad would have overlapped');

  const touch = { x: rocket.x + hw - 2, y: rocket.y, scaleX: 1 };
  assert.equal(contactsHazard(rocket, touch, 'bird', false), true);
});

test('sky→space blend is continuous over altitude', async () => {
  const { spaceBlend, skyLayerAlphas, smoothstep } = await import(path.join(arcade, 'tod.js'));
  assert.equal(spaceBlend(0, 'ASCENT'), 0);
  assert.equal(spaceBlend(80, 'ASCENT'), 1);
  assert.equal(spaceBlend(12, 'SEP'), 1);
  const a = spaceBlend(18, 'ASCENT');
  const b = spaceBlend(19, 'ASCENT');
  const c = spaceBlend(36, 'ASCENT');
  assert.ok(a > 0 && a < 1);
  assert.ok(b > a, 'no step down');
  assert.ok(c > b);
  assert.ok(c < 1);
  const low = skyLayerAlphas(0);
  const mid = skyLayerAlphas(0.45);
  const high = skyLayerAlphas(1);
  assert.equal(low.sky, 1);
  assert.ok(mid.sky < low.sky && mid.sky > high.sky);
  assert.equal(high.sky, 0);
  assert.ok(high.stars > mid.stars);
  assert.ok(smoothstep(0, 1, 0.5) === 0.5);
});

test('Haven glide is longer and the burn window waits for the player', async () => {
  const { HAVEN } = await import(path.join(arcade, 'config.js'));
  assert.ok(HAVEN.glideMinSec >= 9, `glideMinSec ${HAVEN.glideMinSec}`);
  assert.ok(HAVEN.startLat >= 1500, `startLat ${HAVEN.startLat}`);
  assert.ok(HAVEN.startY <= -1000, `startY ${HAVEN.startY}`);
  assert.ok(HAVEN.reentrySec + HAVEN.strakeSec > 4);
  assert.ok(HAVEN.readySec >= 10);
  const mission = fs.readFileSync(path.join(arcade, 'mission.js'), 'utf8');
  assert.match(mission, /burnWindow && boosting/);
  assert.match(mission, /HOLD CLIMB and steer onto the paint/);
  assert.doesNotMatch(mission, /setVelocityY\(0\.48\)/);
  assert.match(mission, /clamp\(this\.rocket\.x, -1900/);
});
