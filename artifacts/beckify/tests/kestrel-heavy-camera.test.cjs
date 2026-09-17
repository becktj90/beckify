const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');

const arcade = path.join(__dirname, '..', 'public/arcade/kestrel-heavy/js');

test('portrait ENVELOP crop keeps the corridor by zooming out', async () => {
  const {
    envelopVisibleWorld,
    isPortraitPlayfield,
    padZoomForPlayfield,
    corridorNeedWidth,
  } = await import(path.join(arcade, 'camera.js'));

  assert.equal(isPortraitPlayfield(390, 844), true);
  assert.equal(isPortraitPlayfield(1180, 820), false);

  const zoom = padZoomForPlayfield(390, 844, false);
  const vis = envelopVisibleWorld(390, 844, 1280, 720, zoom);
  assert.ok(zoom < 0.72, `portrait pad zoom should drop below landscape pad, got ${zoom}`);
  assert.ok(vis.w + 1 >= corridorNeedWidth(), `visible world ${vis.w} must cover corridor ${corridorNeedWidth()}`);
});

test('Haven camera stays locked on the booster, not empty ocean', async () => {
  const {
    envelopVisibleWorld,
    havenLookPoint,
    havenZoomWant,
    vehicleInView,
    expandedHavenBounds,
    shouldSnapVehicle,
    FILL_PLAYFIELDS,
  } = await import(path.join(arcade, 'camera.js'));
  const { HAVEN, W } = await import(path.join(arcade, 'config.js'));

  const rocketX = W / 2 + HAVEN.startLat;
  const rocketY = HAVEN.startY;
  const bargeX = W / 2;
  const bargeY = HAVEN.bargeY;
  const bounds = expandedHavenBounds();
  assert.ok(rocketX > bounds.x && rocketX < bounds.x + bounds.width);
  assert.ok(rocketY > bounds.y && rocketY < bounds.y + bounds.height);

  for (const field of FILL_PLAYFIELDS) {
    const zoom = havenZoomWant({
      alt: bargeY - rocketY,
      pulling: false,
      reduced: false,
      parentW: field.w,
      parentH: field.h,
    });
    const vis = envelopVisibleWorld(field.w, field.h, 1280, 720, zoom);
    const look = havenLookPoint(rocketX, rocketY, bargeX, bargeY, vis.w, vis.h);
    assert.equal(
      vehicleInView(rocketX, rocketY, look.cx, look.cy, vis.w, vis.h, 40),
      true,
      `${field.name}: booster must stay inside the cropped Haven frame at reentry start`,
    );
    assert.equal(
      shouldSnapVehicle(rocketX, rocketY, look.cx, look.cy, vis.w, vis.h, 80),
      false,
      `${field.name}: start-of-glide look must not need a snap`,
    );
    const midAlt = 220;
    const midRocketY = bargeY - midAlt;
    const pullZoom = havenZoomWant({
      alt: midAlt,
      pulling: true,
      reduced: false,
      parentW: field.w,
      parentH: field.h,
    });
    const pullVis = envelopVisibleWorld(field.w, field.h, 1280, 720, pullZoom);
    const pullLook = havenLookPoint(bargeX + 80, midRocketY, bargeX, bargeY, pullVis.w, pullVis.h);
    assert.equal(
      vehicleInView(bargeX + 80, midRocketY, pullLook.cx, pullLook.cy, pullVis.w, pullVis.h, 40),
      true,
      `${field.name}: booster must stay framed through the landing-burn pull-in`,
    );
  }

  assert.equal(
    shouldSnapVehicle(2320, -1180, 640, 360, 333, 720, 80),
    true,
    'empty-ocean mid-world camera must snap back to stage-1',
  );
});
