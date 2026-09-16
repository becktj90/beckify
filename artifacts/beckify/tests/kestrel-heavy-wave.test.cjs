const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');

const arcade = path.join(__dirname, '..', 'public/arcade/kestrel-heavy/js');

test('hazards spawn above the camera, never inside the corridor frame', async () => {
  const { cameraTopY, spawnYAboveCamera, spawnIsAheadOfCamera, SPAWN } = await import(path.join(arcade, 'spawn.js'));
  const rocketY = 400;
  const lookAhead = 210;
  const viewH = 720;
  const mobileTop = cameraTopY(rocketY, 0.5, lookAhead, viewH);
  const desktopTop = cameraTopY(rocketY, 0.62, lookAhead, viewH);
  const oldPop = rocketY - 420;
  assert.ok(oldPop > mobileTop, 'legacy spawn sat inside the mobile camera (the bug)');

  const yMin = spawnYAboveCamera(mobileTop, SPAWN.leadMin, SPAWN.leadMax, () => 0);
  const yMaxLead = spawnYAboveCamera(mobileTop, SPAWN.leadMin, SPAWN.leadMax, () => 1);
  assert.ok(spawnIsAheadOfCamera(yMin, mobileTop));
  assert.ok(spawnIsAheadOfCamera(yMaxLead, mobileTop));
  assert.ok(yMin < mobileTop);
  assert.ok(yMaxLead < yMin);
  assert.ok(spawnIsAheadOfCamera(spawnYAboveCamera(desktopTop, SPAWN.leadMin, SPAWN.leadMax, () => 0), desktopTop));
});

test('integrity names graze vs lethal and shield still eats a hit', async () => {
  const { applyHit, applyScrape, healthMaxFor } = await import(path.join(arcade, 'health.js'));
  assert.equal(healthMaxFor('CADET'), 100);
  const shield = applyHit({ health: 100, shield: 1, grace: 0 }, 'debris', 'CADET');
  assert.equal(shield.kind, 'shield');
  assert.equal(shield.health, 100);
  assert.equal(shield.shield, 0);

  const graze = applyHit({ health: 100, shield: 0, grace: 0 }, 'bird', 'CADET');
  assert.equal(graze.kind, 'graze');
  assert.ok(graze.health > 0 && graze.health < 100);

  const lethal = applyHit({ health: 10, shield: 0, grace: 0 }, 'debris', 'CADET');
  assert.equal(lethal.kind, 'lethal');
  assert.equal(lethal.health, 0);

  const kid = applyHit({ health: 12, shield: 0, grace: 0 }, 'ice', 'KID');
  assert.equal(kid.kind, 'kid');
  assert.ok(kid.health >= 8);

  const scrape = applyScrape({ health: 20, grace: 0 }, 2, 'CADET');
  assert.equal(scrape.kind, 'lethal');
});

test('hangar combo space is thousands and loadouts persist', async () => {
  const {
    comboCount,
    clampLoadout,
    evaluateUnlocks,
    grantPickupUnlock,
    isPartUnlocked,
    DEFAULT_LOADOUT,
    PARTS,
  } = await import(path.join(arcade, 'loadout.js'));
  assert.ok(comboCount() >= 1000, `comboCount ${comboCount()} should be thousands`);
  assert.equal(
    comboCount(),
    PARTS.nose.length * PARTS.body.length * PARTS.strakes.length
      * PARTS.engines.length * PARTS.paint.length * PARTS.accent.length,
  );
  const locked = evaluateUnlocks({
    unlockedMissions: ['KH-1'],
    missionBests: {},
    hiArcadeScore: 0,
  });
  assert.equal(isPartUnlocked(locked, 'nose', 'ogive-gold'), true);
  assert.equal(isPartUnlocked(locked, 'paint', 'night'), false);
  const flown = evaluateUnlocks({
    unlockedMissions: ['KH-1', 'KH-2', 'KH-3', 'KH-4', 'KH-5'],
    missionBests: { 'KH-5': { recovered: true, score: 9000 } },
    hiArcadeScore: 20000,
  });
  assert.equal(isPartUnlocked(flown, 'paint', 'lumen'), true);
  assert.equal(isPartUnlocked(flown, 'engines', 'slim'), true);
  const settings = { unlockedParts: { accent: [] }, loadout: { ...DEFAULT_LOADOUT, paint: 'night' } };
  const granted = grantPickupUnlock(settings, 'shield');
  assert.equal(granted.cat, 'accent');
  assert.equal(granted.id, 'cyan');
  const equipped = clampLoadout(settings.loadout, locked);
  assert.equal(equipped.paint, 'white', 'locked paint must fall back to starter');
  const persisted = evaluateUnlocks({
    unlockedMissions: ['KH-1'],
    missionBests: {},
    hiArcadeScore: 0,
    unlockedParts: { accent: ['cyan'] },
    loadout: { ...DEFAULT_LOADOUT, accent: 'cyan' },
  });
  assert.equal(isPartUnlocked(persisted, 'accent', 'cyan'), true, 'pickup unlocks survive V7 reload extras');
  assert.equal(clampLoadout({ ...DEFAULT_LOADOUT, accent: 'cyan' }, persisted).accent, 'cyan');
});

test('each KH-n has a distinct time of day palette', async () => {
  const { MISSIONS } = await import(path.join(arcade, 'missions.js'));
  const { todPalette } = await import(path.join(arcade, 'tod.js'));
  const tods = MISSIONS.map((m) => m.tod);
  assert.deepEqual(tods, ['dawn', 'noon', 'golden', 'dusk', 'night']);
  const skies = tods.map((id) => todPalette(id).sky.map((stop) => stop[1]).join('|'));
  assert.equal(new Set(skies).size, 5, 'sky gradients must not be a single tint');
  assert.notEqual(todPalette('dawn').sun.x, todPalette('noon').sun.x);
  assert.notEqual(todPalette('night').flood, todPalette('golden').flood);
});
