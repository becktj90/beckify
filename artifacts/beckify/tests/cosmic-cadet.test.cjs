const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');

const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'components', 'games', 'cosmicCadet.ts'), 'utf8');
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
});
const generated = new Module('cosmicCadet');
generated._compile(outputText, path.join(__dirname, 'cosmicCadet.generated.js'));
const cadet = generated.exports;

const memoryStore = (seed = {}) => {
  const data = { ...seed };
  return {
    getItem: (key) => (Object.prototype.hasOwnProperty.call(data, key) ? data[key] : null),
    setItem: (key, value) => { data[key] = String(value); },
    data,
  };
};

assert.equal(cadet.waveFromKills(0), 1);
assert.equal(cadet.waveFromKills(7), 1);
assert.equal(cadet.waveFromKills(8), 2);
assert.equal(cadet.waveFromKills(16), 3);

// Old HUD used `points % 1000 === 0`, so 8 regular kills (800 pts) never advanced wave.
let run = { points: 0, kills: 0 };
for (let i = 0; i < 8; i++) run = cadet.applyKill(run, false);
assert.equal(run.points, 800);
assert.equal(run.wave, 2, 'wave must advance on kill count, not an exact 1000-point boundary');

run = cadet.applyKill({ points: 750, kills: 7 }, true);
assert.equal(run.points, 1000);
assert.equal(run.wave, 2);

assert.equal(cadet.togglePause('playing'), 'paused');
assert.equal(cadet.togglePause('paused'), 'playing');
assert.equal(cadet.togglePause('ready'), 'ready', 'pause must not start a run from the title');
assert.equal(cadet.togglePause('gameover'), 'gameover', 'pause must not revive a finished run');

assert.equal(cadet.playIntent('ready'), 'start');
assert.equal(cadet.playIntent('gameover'), 'start');
assert.equal(cadet.playIntent('paused'), 'resume');
assert.equal(cadet.playIntent('playing'), 'ignore');

assert.ok(cadet.fireInterval(true) < cadet.fireInterval(false));
assert.equal(cadet.applyHeart(5), 5);
assert.equal(cadet.applyHeart(3), 4);

assert.equal(cadet.pickPowerUp(true, () => 0.99), null);
assert.equal(cadet.pickPowerUp(true, () => 0), 'heart');

assert.ok(cadet.spawnInterval(1) > cadet.spawnInterval(8), 'later waves spawn a bit faster');
assert.ok(cadet.spawnInterval(1) >= 1.4, 'wave 1 leaves room to aim');
assert.ok(cadet.spawnInterval(20) >= 0.75, 'spawn rate floors before becoming a bullet hell');
assert.ok(cadet.enemyFallSpeed(1) < cadet.enemyFallSpeed(8));
assert.ok(cadet.enemyFallSpeed(12) === cadet.enemyFallSpeed(20), 'fall speed plateaus so late waves stay flyable');
assert.equal(cadet.enemyHp(1, () => 0.99), 1, 'early waves never use two-hit rocks');
assert.equal(cadet.enemyHp(4, () => 0.9), 2);
assert.equal(cadet.enemyLeaked(900), true);
assert.equal(cadet.enemyLeaked(100), false);
assert.equal(cadet.shipHitsEnemy(0, 0, 20, 0), true);
assert.equal(cadet.shipHitsEnemy(0, 0, 40, 0), false, 'old 43px ship radius would still count this as a hit');
assert.ok(cadet.SHIP_HIT_RADIUS < 43);
assert.ok(cadet.START_GUARD > 2);
assert.ok(cadet.HIT_IFRAMES > 1.4);
assert.ok(cadet.PICKUP_RADIUS > cadet.SHIP_HIT_RADIUS);

assert.equal(cadet.hudChanged({ score: 0, wave: 1, hull: 5 }, { score: 100, wave: 1, hull: 5 }), true);
assert.equal(cadet.hudChanged({ score: 100, wave: 2, hull: 5 }, { score: 100, wave: 2, hull: 5 }), false);

const store = memoryStore({ 'cosmic-cadet-best': '400' });
const loaded = cadet.loadScores(store);
assert.equal(loaded.best, 400);
assert.equal(loaded.board[0].score, 400);

const recorded = cadet.recordRun(store, 1200, 3, 10);
assert.equal(recorded.best, 1200);
assert.equal(recorded.board[0].score, 1200);
cadet.recordRun(store, 900, 2, 11);
cadet.recordRun(store, 1500, 4, 12);
cadet.recordRun(store, 200, 1, 13);
cadet.recordRun(store, 1300, 3, 14);
cadet.recordRun(store, 50, 1, 15);
const board = cadet.loadScores(store).board;
assert.equal(board.length, 5, 'local board keeps a short kid-friendly top five');
assert.equal(board[0].score, 1500);
assert.ok(board.every((entry) => entry.score !== 50), 'low scores fall off the board');

const blocked = {
  getItem() { throw new Error('blocked'); },
  setItem() { throw new Error('blocked'); },
};
assert.deepEqual(cadet.loadScores(blocked), { best: 0, board: [] });
assert.doesNotThrow(() => cadet.recordRun(blocked, 100, 1, 1));

console.log('Cosmic Cadet kid-play helpers passed');
