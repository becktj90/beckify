const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../public/toolbox');
const context = vm.createContext({ console });
for (const name of ['model', 'profile', 'eval', 'plant', 'scenario', 'trace', 'lint', 'report', 'seed-main-tie-main']) {
  vm.runInContext(fs.readFileSync(path.join(root, `js/switchgear/${name}.js`), 'utf8'), context);
}
const E = context.SwitchgearEngine;
const demo = () => E.seedMainTieMain.build(E.model, E.profile, E.plant);

test('invalid imported project yields errors without throwing', () => {
  for (const p of [null, {}, { modelVersion: 99 }, { ...demo(), nodes: [null] }]) {
    assert.ok(E.model.validateProject(p).length);
  }
  assert.equal(E.model.validateProject(demo()).length, 0);
});
test('timers settle only after pickup finishes', () => {
  const p = E.model.newProject(E.profile.clone(E.profile.GENERIC_PROFILE));
  p.signals = [E.model.newSignal({ id: 'in', kind: 'VI' }), E.model.newSignal({ id: 'out', kind: 'VO' })];
  p.nodes = [E.model.newNode({ id: 'timer', type: 'TIMER', inputs: [{ ref: 'in' }], output: 'out', params: { fieldA: 500 } })];
  const settled = E.eval.settle(p, E.eval.newRuntime(), { in: true }, 100, 20);
  assert.equal(settled.settled, true);
  assert.equal(settled.result.signalValues.out, true);
  assert.ok(settled.scans >= 5);
});
test('scenario rejects zero scan period and excessive work', () => {
  const p = demo();
  for (const dtMs of [0, -1, NaN, Infinity, 0.0001]) {
    assert.throws(() => E.scenario.run(p, { durationMs: 10000, dtMs, events: [] }, E.eval, E.plant));
  }
});
test('off-grid events are applied at the next scan, never early', () => {
  const p = demo();
  const result = E.scenario.run(p, { durationMs: 200, dtMs: 100, events: [{ tMs: 40, type: 'breakerPosition', breakerId: 'tie', position: 'closed' }] }, E.eval, E.plant);
  assert.equal(result.steps[0].breakerPositions.tie, 'open');
  assert.equal(result.steps[1].breakerPositions.tie, 'closed');
});
test('large enumeration is bounded and input bits above 31 stay independent', () => {
  const p = E.model.newProject(E.profile.clone(E.profile.GENERIC_PROFILE));
  for (let i = 0; i < 35; i++) p.signals.push(E.model.newSignal({ id: 'in' + i, kind: 'VI' }));
  const result = E.report.enumerateSettledStates(p, E.eval, { sampleCap: 100 });
  assert.equal(result.exhaustive, false);
  assert.ok(result.rows.length <= 100);
  assert.ok(result.rows.some(r => r.inputs.in0 !== r.inputs.in32));
});
test('open source breaker isolates an unavailable source from an energized bus', () => {
  const p = demo();
  const positions = E.scenario.initialPositions(p.plant);
  const availability = E.scenario.initialAvailability(p.plant);
  assert.equal(E.plant.detectBackfeed(p.plant, positions, availability).length, 0);
  positions.gen1 = 'closed';
  assert.ok(E.plant.detectBackfeed(p.plant, positions, availability).some(f => f.category === 'backfeed'));
});
test('completed breaker movement is reflected in same-scan feedback', () => {
  const p = demo();
  const result = E.scenario.run(p, { durationMs: 400, dtMs: 100, events: [{tMs:0,type:'input',signalId:'utility1Ok',value:true}] }, E.eval, E.plant);
  const step = result.steps.find(s => s.tMs === 300);
  assert.equal(step.breakerPositions.main1, 'closed');
  assert.equal(step.signalValues.main1Fb, true);
});

test('original gate, timing, topology, and lint acceptance suite stays green', () => {
  vm.runInContext(fs.readFileSync(path.join(root, 'tests/switchgear-tests.js'), 'utf8'), context);
  const result = context.SwitchgearEngineTests.runAll(E);
  assert.equal(result.failed, 0, JSON.stringify(result.results.filter(r => !r.pass)));
  assert.equal(result.passed, 25);
});
test('review export includes logic, topology, transfer sequence, and finding evidence', () => {
  const p = demo();
  const html = E.report.buildReviewExportHtml(p, [{ severity: 'high', category: 'example', title: '<script>', evidence: [{ signalId: 'tieCloseCmd' }], status: 'dismissed' }], null, [{ tMsStart: 0, tMsEnd: 100, breakerPositions: { tie: 'open' }, busFeeds: { bus1: ['utility1'] } }]);
  for (const text of ['Logic', 'Plant and breaker mappings', 'Transfer sequence', 'tieCloseCmd', 'dismissed', '&lt;script&gt;']) assert.ok(html.includes(text));
  assert.ok(!html.includes('<script>'));
});
test('timer interpretation comparison exercises the complete saved scenario', () => {
  const p = demo();
  assert.ok(E.scenario.compareProfiles(p, p.scenarios[0], E.eval, E.plant, 'timerFieldOrder', ['pickup-then-dropout','dropout-then-pickup']).includes('genOnDelay'));
});
test('app bundle matches every website engine and UI asset', () => {
  const app = path.resolve(__dirname, '../../../ios/Beckify/SwitchgearLogicLabWeb');
  const files = ['css/switchgear-logic-lab.css', 'js/switchgear-logic-lab-ui.js', ...fs.readdirSync(path.join(root, 'js/switchgear')).map(f => 'js/switchgear/' + f)];
  for (const file of files) assert.equal(fs.readFileSync(path.join(app, file), 'utf8'), fs.readFileSync(path.join(root, file), 'utf8'), file);
  assert.equal(fs.readFileSync(path.join(app, 'index.html'), 'utf8'), fs.readFileSync(path.join(root, 'switchgear-logic-lab.html'), 'utf8'));
});
