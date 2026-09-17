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
  } = await import(path.join(arcade, 'camera.js'));
  const { HAVEN, W } = await import(path.join(arcade, 'config.js'));

  const parentW = 390;
  const parentH = 844;
  const rocketX = W / 2 + HAVEN.startLat;
  const rocketY = HAVEN.startY;
  const bargeX = W / 2;
  const bargeY = HAVEN.bargeY;
  const zoom = havenZoomWant({
    alt: bargeY - rocketY,
    pulling: false,
    reduced: false,
    parentW,
    parentH,
  });
  const vis = envelopVisibleWorld(parentW, parentH, 1280, 720, zoom);
  const look = havenLookPoint(rocketX, rocketY, bargeX, bargeY, vis.w, vis.h);
  assert.equal(
    vehicleInView(rocketX, rocketY, look.cx, look.cy, vis.w, vis.h, 40),
    true,
    'booster must stay inside the cropped Haven frame at reentry start',
  );
  const midAlt = 220;
  const midRocketY = bargeY - midAlt;
  const pullZoom = havenZoomWant({
    alt: midAlt,
    pulling: true,
    reduced: false,
    parentW,
    parentH,
  });
  const pullVis = envelopVisibleWorld(parentW, parentH, 1280, 720, pullZoom);
  const pullLook = havenLookPoint(bargeX + 80, midRocketY, bargeX, bargeY, pullVis.w, pullVis.h);
  assert.equal(
    vehicleInView(bargeX + 80, midRocketY, pullLook.cx, pullLook.cy, pullVis.w, pullVis.h, 40),
    true,
    'booster must stay framed through the landing-burn pull-in',
  );

  const bounds = expandedHavenBounds();
  assert.ok(rocketX > bounds.x && rocketX < bounds.x + bounds.width);
  assert.ok(rocketY > bounds.y && rocketY < bounds.y + bounds.height);
});
