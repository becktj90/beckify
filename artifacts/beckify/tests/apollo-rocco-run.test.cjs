const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');

const sourcePath = path.join(__dirname, '..', 'src', 'components', 'games', 'apolloRoccoRun.ts');
const source = fs.readFileSync(sourcePath, 'utf8');
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
});
const generated = new Module('apolloRoccoRun');
generated._compile(outputText, path.join(__dirname, 'apolloRoccoRun.generated.js'));
const run = generated.exports;

assert.equal(run.shiftLane(1, -1), 0);
assert.equal(run.shiftLane(0, -1), 0, 'left edge stays in the left lane');
assert.equal(run.shiftLane(2, 1), 2, 'right edge stays in the right lane');
assert.equal(run.shiftLane(0, 1), 1);
assert.equal(run.shiftLane(1, 1), 2);

assert.equal(run.poseFromTimers(0.4, 0), 'jump');
assert.equal(run.poseFromTimers(0, 0.3), 'slide');
assert.equal(run.poseFromTimers(0, 0), 'run');
assert.equal(run.poseFromTimers(0.2, 0.2), 'jump', 'jump wins if both somehow overlap');

assert.equal(run.hazardResult('jump', 'low'), 'clear');
assert.equal(run.hazardResult('run', 'low'), 'hit');
assert.equal(run.hazardResult('slide', 'low'), 'hit');
assert.equal(run.hazardResult('slide', 'high'), 'clear');
assert.equal(run.hazardResult('jump', 'high'), 'hit');
assert.equal(run.hazardResult('run', 'high'), 'hit');

assert.equal(run.startJump(0, 0, 0.9), 0.9);
assert.equal(run.startJump(0.4, 0, 0.9), 0.4, 'cannot double-jump');
assert.equal(run.startSlide(0.4, 0, 0.6), 0, 'cannot slide while jumping');
assert.equal(run.startSlide(0, 0, 0.6), 0.6);
assert.ok(run.jumpLift(0.45, 0.9) > 0.9);
assert.equal(run.jumpLift(0, 0.9), 0);

assert.equal(run.inHitWindow(run.PLAYER_Z, 1.7), true);
assert.equal(run.inHitWindow(run.PLAYER_Z + 1.69, 1.7), true);
assert.equal(run.inHitWindow(20, 1.7), false);

const first = run.applyHit(3, 0, 2.2);
assert.equal(first.hitsLeft, 2);
assert.equal(first.dead, false);
assert.equal(first.iframes, 2.2);
const ignored = run.applyHit(2, 1.5, 2.2);
assert.equal(ignored.hitsLeft, 2, 'i-frames swallow extra hits');
assert.equal(ignored.ignored, true);
const second = run.applyHit(2, 0, 2.2);
const last = run.applyHit(1, 0, 2.2);
assert.equal(last.hitsLeft, 0);
assert.equal(last.dead, true, 'KID dies on the third real hit, not the first bump');

assert.equal(run.TUNING.kid.hits, 3);
assert.equal(run.TUNING.cadet.hits, 2);
assert.ok(run.TUNING.kid.iframes > run.TUNING.cadet.iframes);
assert.ok(run.TUNING.kid.minGap > run.TUNING.cadet.minGap, 'KID keeps wider gaps');
assert.ok(run.TUNING.kid.startSpeed < run.TUNING.cadet.startSpeed);
assert.ok(run.TUNING.kid.accel < run.TUNING.cadet.accel, 'KID speed ramp stays gentle');
assert.ok(run.runSpeed(40, 'kid') < run.runSpeed(40, 'cadet'));
assert.ok(run.runSpeed(400, 'kid') <= run.TUNING.kid.maxSpeed);

const kidHazards = run.planHazards(run.TUNING.kid.maxBlockedLanes, () => 0.99);
assert.equal(kidHazards.length, 1, 'KID never blocks more than one lane');
const cadetHazards = run.planHazards(run.TUNING.cadet.maxBlockedLanes, () => 0);
assert.ok(cadetHazards.length >= 1 && cadetHazards.length <= 2);
for (let i = 0; i < 40; i += 1) {
  const pack = run.planHazards(2, () => Math.random());
  assert.ok(pack.length <= 2, 'never close all three lanes');
  const lanes = new Set(pack.map((item) => item.lane));
  assert.equal(lanes.size, pack.length, 'one hazard per lane');
}

assert.equal(run.togglePause('running'), 'paused');
assert.equal(run.togglePause('paused'), 'running');
assert.equal(run.togglePause('ready'), 'ready', 'pause must not start a run');
assert.equal(run.togglePause('gameover'), 'gameover', 'pause must not revive a finished run');
assert.equal(run.playIntent('paused'), 'resume');
assert.equal(run.playIntent('ready'), 'start');
assert.equal(run.playIntent('running'), 'ignore');

assert.equal(run.swipeAction(-80, 4), 'left');
assert.equal(run.swipeAction(80, 8), 'right');
assert.equal(run.swipeAction(2, -80), 'jump');
assert.equal(run.swipeAction(2, 80), 'slide');
assert.equal(run.swipeAction(4, 4), null);

const store = {
  data: {},
  getItem(key) { return Object.prototype.hasOwnProperty.call(this.data, key) ? this.data[key] : null; },
  setItem(key, value) { this.data[key] = String(value); },
};
assert.equal(run.loadBest(store), 0);
assert.equal(run.saveBest(store, 120), 120);
assert.equal(run.saveBest(store, 40), 120, 'local best never drops');
assert.equal(run.loadBest(store), 120);

const blocked = {
  getItem() { throw new Error('blocked'); },
  setItem() { throw new Error('blocked'); },
};
assert.equal(run.loadBest(blocked), 0);
assert.doesNotThrow(() => run.saveBest(blocked, 50));

const gameFiles = [
  sourcePath,
  path.join(__dirname, '..', 'src', 'components', 'games', 'ApolloRoccoRun.tsx'),
  path.join(__dirname, '..', 'src', 'pages', 'apollo-rocco-run.tsx'),
];
for (const file of gameFiles) {
  const text = fs.readFileSync(file, 'utf8').toLowerCase();
  assert.equal(text.includes('temple run'), false, `${path.basename(file)} must not name Temple Run`);
  assert.equal(text.includes('imangi'), false, `${path.basename(file)} must not credit Imangi`);
  assert.equal(text.includes('based on temple'), false);
}

console.log('Apollo & Rocco Run lane/jump/kid-hit helpers passed');
