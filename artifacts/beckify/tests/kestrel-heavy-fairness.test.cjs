const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const arcade = path.join(__dirname, '..', 'public/arcade/kestrel-heavy/js');

test('overlap hits; near-miss does not; Matter labels survive reshape', async () => {
  const {
    HAZARD_CANVAS,
    HAZARD_RADIUS,
    GRAZE_PAD,
    contactsHazard,
    isNearMiss,
    hazardRadius,
    rocketHitSize,
    isRocketBody,
    otherBody,
    hazardKindOf,
    stampBodyLabel,
    matterLabelOptions,
  } = await import(path.join(arcade, 'hit.js'));

  assert.ok(hazardRadius('bird') < HAZARD_CANVAS / 2, 'body tighter than 48px canvas');
  assert.ok(hazardRadius('ice') < HAZARD_CANVAS / 2);
  assert.ok(hazardRadius('bird') <= HAZARD_RADIUS.bird + GRAZE_PAD + 0.01);
  assert.ok(HAZARD_RADIUS.bird >= 12, 'solid bird art reaches ~16px, not a pinhead');

  const rocket = { x: 400, y: 400, scaleX: 1.18 };
  const box = rocketHitSize(false);
  const hw = (box.width * 1.18) / 2;
  const rBird = hazardRadius('bird');

  const far = { x: rocket.x + hw + 28, y: rocket.y, scaleX: 1 };
  assert.equal(contactsHazard(rocket, far, 'bird', false), false);
  assert.equal(isNearMiss(rocket, far, 'bird', false), true, 'old fat pad would have overlapped');

  const canvasPad = { x: rocket.x + hw + HAZARD_CANVAS / 2 - 2, y: rocket.y, scaleX: 1 };
  assert.equal(contactsHazard(rocket, canvasPad, 'bird', false), false, '48×48 canvas pad is not a hit');
  assert.equal(isNearMiss(rocket, canvasPad, 'bird', false), true);

  const grazeMiss = { x: rocket.x + hw + rBird + 4, y: rocket.y, scaleX: 1 };
  assert.equal(contactsHazard(rocket, grazeMiss, 'bird', false), false);

  const overlapCenter = { x: rocket.x + 4, y: rocket.y, scaleX: 1, hazardKind: 'bird' };
  assert.equal(contactsHazard(rocket, overlapCenter, 'bird', false), true, 'center overlap is a hit');

  const touch = { x: rocket.x + hw - 2, y: rocket.y, scaleX: 1 };
  assert.equal(contactsHazard(rocket, touch, 'bird', false), true);

  const edgeClip = { x: rocket.x + hw + rBird - 1, y: rocket.y, scaleX: 1 };
  assert.equal(contactsHazard(rocket, edgeClip, 'bird', false), true, 'solid-art graze still hits');

  const rocketGo = { body: { label: 'Body' } };
  rocketGo.body.gameObject = rocketGo;
  assert.equal(isRocketBody(rocketGo.body, rocketGo), true, 'identity beats wiped label');
  assert.equal(isRocketBody({ label: 'Body' }, rocketGo), false);
  assert.equal(isRocketBody({ label: 'rocket' }, null), true);

  const hazardBody = { label: 'Body', gameObject: { hazardKind: 'ice', x: 0, y: 0 } };
  const pair = { bodyA: rocketGo.body, bodyB: hazardBody };
  assert.equal(otherBody(pair, rocketGo), hazardBody);
  assert.equal(hazardKindOf(hazardBody.gameObject, 'Body'), 'ice');
  assert.equal(hazardKindOf({}, 'hazard-bird'), 'bird');

  const stamped = stampBodyLabel({ body: { label: 'Body' } }, 'rocket');
  assert.equal(stamped.body.label, 'rocket');
  assert.equal(matterLabelOptions('hazard-bird', { isSensor: true }).label, 'hazard-bird');

  const mission = fs.readFileSync(path.join(arcade, 'mission.js'), 'utf8');
  assert.match(mission, /setCircle\(radius,\s*matterLabelOptions\(label/);
  assert.match(mission, /stampBodyLabel\(img, label\)/);
  assert.match(mission, /stampBodyLabel\(this\.rocket, 'rocket'\)/);
  assert.match(mission, /otherBody\(pair, this\.rocket\)/);
  assert.match(mission, /resolveHazardOverlaps/);
  assert.match(mission, /go\?\.hazardKind/);
  assert.match(mission, /get\('qa'\) === 'hits'/);
  assert.match(mission, /spawnQaHitPair/);
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
  assert.match(mission, /HOLD TO BURN and steer onto the paint/);
  assert.match(mission, /burnHold/);
  assert.match(mission, /haven-burn-nag/);
  assert.match(mission, /applyQaBeat/);
  assert.doesNotMatch(mission, /setVelocityY\(0\.48\)/);
  assert.match(mission, /clamp\(this\.rocket\.x, -1900/);
});
