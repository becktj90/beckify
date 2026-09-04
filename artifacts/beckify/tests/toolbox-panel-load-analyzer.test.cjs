const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  Set,
  JSON,
  document: { getElementById() { return null; } },
};
sandbox.window = sandbox;
sandbox.window.addEventListener = () => {};
sandbox.window.__ENABLE_PANEL_SCHEDULE_TEST_API__ = true;
sandbox.window.__ENABLE_FACTOR_TEST_API__ = true;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'panel-schedule.js'), 'utf8'), sandbox, { filename: 'panel-schedule.js' });
vm.runInContext(fs.readFileSync(path.join(root, 'factor-tools.js'), 'utf8'), sandbox, { filename: 'factor-tools.js' });

const panel = sandbox.__panelScheduleTestApi;
const factors = sandbox.__factorTestApi;

assert.equal(panel.inferLoadType('Roof top AC condenser'), 'HVAC');
assert.equal(panel.inferLoadType('LED corridor lighting'), 'Lighting');
const parsedVoltage = panel.panelVoltageInfo('208Y/120V');
assert.equal(parsedVoltage.lineToLine, 208);
assert.equal(parsedVoltage.lineToNeutral, 120);
assert.equal(panel.rowLoadVa({ loadAmps: '20', poles: '1' }, panel.panelVoltageInfo('208Y/120V'), 3), 2400);
assert.ok(Math.abs(panel.rowLoadVa({ loadAmps: '10', poles: '3' }, panel.panelVoltageInfo('208Y/120V'), 3) - 3602.665) < 0.01);
assert.equal(panel.normalizeLoadAmps('', '30A'), '30');
assert.equal(panel.isLoadAmpsCopiedFromTrip('', '30A'), true);
assert.equal(panel.isLoadAmpsCopiedFromTrip('14', '30A'), false);
assert.equal(panel.normalizeDemandFactor('0.8'), '0.8');
assert.equal(factors.factorPercent(0.7), '70%');

assert.equal(panel.phaseLegFromCircuit('1', 1), 'L1');
assert.equal(panel.phaseLegFromCircuit('2', 1), 'L2');
assert.equal(panel.phaseLegFromCircuit('3', 1), 'L1');
assert.equal(panel.phaseLegFromCircuit('4', 1), 'L2');
assert.equal(panel.phaseLegFromCircuit('1', 3), 'A');
assert.equal(panel.phaseLegFromCircuit('2', 3), 'A');
assert.equal(panel.phaseLegFromCircuit('3', 3), 'B');
assert.equal(panel.phaseLegFromCircuit('5', 3), 'C');
assert.equal(panel.isSpareOrOpen({ description: 'SPARE', trip: '' }), true);
assert.equal(panel.isUnlabeled({ description: '', trip: '20A' }), true);

const metrics = panel.computeDirectoryMetrics([
  { circuit: '1', description: 'Lights', trip: '20A', poles: '1' },
  { circuit: '2', description: 'Receptacles', trip: '20A', poles: '1' },
  { circuit: '3', description: 'SPARE', trip: '', poles: '' },
  { circuit: '4', description: '', trip: '15A', poles: '1' },
], { phase: 1, mainAmps: 100, slotCount: 4 });
assert.equal(metrics.connectedBreakerAmps, 55);
assert.equal(metrics.connectedToMainPct, 55);
assert.equal(String(metrics.connectedToMainPct), '55');
assert.equal(metrics.spareCount, 1);

const twoPoleSpare = panel.computeDirectoryMetrics([
  { circuit: '1', description: 'Lights', trip: '20A', poles: '1' },
  { circuit: '3', description: 'SPARE', trip: '', poles: '2' },
], { phase: 1, mainAmps: 100 });
assert.equal(twoPoleSpare.spareCount, 2);
assert.equal(twoPoleSpare.spareTotal, 3);
assert.equal(metrics.unlabeledCount, 1);
assert.match(metrics.connectedNote, /not an NEC Article 220/i);
assert.match(metrics.connectedNote, /does not mean the panel is unsafe/i);
assert.ok(metrics.flags.some((f) => /blank labels found: 1/.test(f)));
assert.match(metrics.phaseBalance.assumption, /odd circuits on L1/i);
assert.equal(metrics.phaseBalance.legs.L1, 20);
assert.equal(metrics.phaseBalance.legs.L2, 35);

const twoPole = panel.phaseBalance(
  [{ circuit: '1', description: 'Range', trip: '30A', poles: '2' }],
  1,
);
assert.equal(twoPole.legs.L1, 30);
assert.equal(twoPole.legs.L2, 30);

const threePole = panel.phaseBalance(
  [{ circuit: '1', description: 'AHU', trip: '40A', poles: '3' }],
  3,
);
assert.equal(threePole.legs.A, 40);
assert.equal(threePole.legs.B, 40);
assert.equal(threePole.legs.C, 40);
assert.match(threePole.assumption, /3-pole breaker/i);

const floatPct = panel.computeDirectoryMetrics(
  [{ circuit: '1', description: 'Lights', trip: '11A', poles: '1' }],
  { phase: 1, mainAmps: 20, slotCount: 1 }
);
assert.equal(floatPct.connectedToMainPct, 55);
assert.equal(String(floatPct.connectedToMainPct), '55');

const panelSrc = fs.readFileSync(path.join(root, 'panel-schedule.js'), 'utf8');
assert.match(panelSrc, /DOMContentLoaded/);
assert.match(panelSrc, /bootPanelSchedule/);
assert.match(panelSrc, /pagehide/);
assert.match(panelSrc, /cacheElements\(\)/);
assert.match(panelSrc, /bindEvents\(\)/);
assert.match(panelSrc, /copied from trip — edit me/);
assert.equal(panelSrc.includes('aria-describedby=""'), false);
assert.match(panelSrc, /aria-describedby="trip-copy-\$\{index\}"/);
assert.match(panelSrc, /function renderLoadAnalysis[\s\S]*scheduleCalcGateMessage/);
assert.match(panelSrc, /function scheduleCalcGateMessage[\s\S]*calcReady/);
assert.match(panelSrc, /function requestCalculate/);
assert.match(panelSrc, /function handlePrint[\s\S]*isScheduleReviewed/);
assert.match(panelSrc, /Breaker trip is not a reviewed load/);
assert.equal(panel.isLikelyImageFile({ type: '', name: 'dir.JPG' }), true);
assert.equal(panel.isLikelyImageFile({ type: '', name: 'dir.heic' }), true);
assert.equal(panel.isLikelyImageFile({ type: 'application/pdf', name: 'dir.jpg' }), false);

const panelHtml = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'panel-schedule.html'), 'utf8');
assert.match(panelHtml, /id="reviewedSchedule"[^>]*data-no-persist/);
assert.match(panelHtml, /id="ps_calculate"/);
assert.match(panelHtml, /Calculate from reviewed table/);
assert.match(panelHtml, /id="panelEnhance"[^>]*data-no-persist/);
assert.match(panelHtml, /id="scheduleFile"/);
assert.match(panelHtml, /id="scheduleCapture"[^>]*capture="environment"/);
assert.match(panelHtml, /id="breakersFile"/);
assert.match(panelHtml, /id="breakersCapture"[^>]*capture="environment"/);
assert.match(panelHtml, /id="scheduleAdd"/);
assert.match(panelHtml, /id="breakersAdd"/);
assert.match(panelHtml, /id="mergeRows"/);
assert.match(panelHtml, /Unknown — select before load math/);
assert.doesNotMatch(panelHtml, /<option value="3" selected>/);
assert.match(panelSrc, /mergeCircuitRows/);
assert.match(panelSrc, /parseBreakerFace/);
assert.match(panelSrc, /sizeTableToSlots/);
assert.match(panelSrc, /Phase is never assumed/);

assert.equal(panel.snapSlotCount(41), 42);
assert.equal(panel.snapSlotCount(20), 20);
assert.equal(panel.parseBreakerFace('SQUARE D 42 CIRCUIT 200A MAIN').slotCount, 42);
const breakerFace = panel.parseBreakerFace('1 20A 2 20A 3 15A 4 30A 5 20A 6 20A 7 15A 8 20A 9 20A 10 20A 11 15A 12 20A');
assert.equal(breakerFace.slotCount, 12);
assert.equal(breakerFace.rows[0].trip, '20A');
const sized = panel.sizeTableToSlots(20, [
  { circuit: '1', description: 'Lights', trip: '20A', poles: '1', loadType: 'Lighting', loadAmps: '', loadAmpsCopiedFromTrip: false, demandFactor: '1' },
]);
assert.equal(sized.length, 20);
assert.equal(sized[0].description, 'Lights');
assert.equal(sized[19].circuit, '20');

const mergedRows = panel.mergeCircuitRows(
  [{ circuit: '1', description: 'Lights', trip: '20A', poles: '1', loadType: 'Lighting', loadAmps: '', loadAmpsCopiedFromTrip: false, demandFactor: '1' }],
  [{ circuit: '1', description: '', trip: '', poles: '', loadType: 'General', loadAmps: '', loadAmpsCopiedFromTrip: false, demandFactor: '1' },
   { circuit: '2', description: 'Receptacles', trip: '20A', poles: '1', loadType: 'Receptacle', loadAmps: '', loadAmpsCopiedFromTrip: false, demandFactor: '1' }],
);
assert.equal(mergedRows.find((row) => row.circuit === '1').description, 'Lights');
assert.equal(mergedRows.find((row) => row.circuit === '2').description, 'Receptacles');

const unknownPhase = panel.computeDirectoryMetrics(
  [{ circuit: '1', description: 'Lights', trip: '20A', poles: '1' }],
  { mainAmps: 100, slotCount: 1 }
);
assert.match(unknownPhase.phaseBalance.assumption, /never assumed/i);

const seeded = [];
for (let i = 1; i <= 42; i += 1) {
  seeded.push({ circuit: String(i), description: '', trip: '', poles: '1' });
}
seeded[0] = { circuit: '1', description: 'AHU', trip: '30A', poles: '2' };
const seededMetrics = panel.computeDirectoryMetrics(seeded, { phase: 3, mainAmps: 200, slotCount: 42 });
assert.equal(seededMetrics.spareTotal, 42);
assert.notEqual(seededMetrics.spareTotal, 43);
assert.equal(seededMetrics.spareCount, 40);
const seeded1ph = panel.computeDirectoryMetrics(seeded, { phase: 1, mainAmps: 200, slotCount: 42 });
assert.equal(seeded1ph.spareCount, 40);

assert.equal(panel.MAX_SHOTS_PER_VIEW, 3);
assert.equal(panel.MAX_SHOTS_TOTAL, 5);
assert.equal(panel.canAddPanelShot({ schedule: ['a', 'b'], breakers: ['c', 'd'] }, 'schedule'), true);
assert.equal(panel.canAddPanelShot({ schedule: ['a', 'b', 'c'], breakers: ['d', 'e'] }, 'breakers'), false);
assert.equal(panel.canAddPanelShot({ schedule: ['a', 'b', 'c'], breakers: ['d', 'e'] }, 'schedule'), false);
assert.equal(panel.canAddPanelShot({ schedule: ['a'], breakers: [] }, 'breakers'), true);
assert.match(panelHtml, /5 total/);

const twoUp = panel.parseScheduleText([
  'PANEL BLT 11',
  'POWER POLE RM 105 1 2 POWER POLE RM 106',
  'RECP RM 105 3 4 RECP TV RM 105',
].join('\n'));
assert.match(String(twoUp.meta.panelName), /BLT|11/i);
const byCkt = Object.fromEntries(twoUp.rows.map((row) => [row.circuit, row.description]));
assert.equal(byCkt['1'], 'POWER POLE RM 105');
assert.equal(byCkt['2'], 'POWER POLE RM 106');
assert.equal(byCkt['3'], 'RECP RM 105');
assert.equal(byCkt['4'], 'RECP TV RM 105');
const numbered = panel.parseScheduleText('1 WEST TURNSTILES 2 SPARE');
assert.equal(numbered.rows.find((row) => row.circuit === '1').description, 'WEST TURNSTILES');
assert.equal(numbered.rows.find((row) => row.circuit === '2').description, 'SPARE');
const paired = panel.parsePairedDirectoryLine('WEST SECURITY GATE 23 25 WEST SECURITY GATE');
assert.equal(paired, null);
const adjacent = panel.parsePairedDirectoryLine('WEST SECURITY GATE 23 24 SPACE');
assert.equal(adjacent[0].circuit, '23');
assert.equal(adjacent[1].description, 'SPACE');

assert.equal(panel.normalizeCircuit('01'), '1');
assert.equal(panel.normalizeCircuit('01A'), '1A');
const paddedRows = panel.mergeCircuitRows(
  [{ circuit: '01', description: 'Lights', trip: '20A', poles: '1', loadType: 'Lighting', loadAmps: '', loadAmpsCopiedFromTrip: false, demandFactor: '1' }],
  [{ circuit: '1', description: '', trip: '', poles: '', loadType: 'General', loadAmps: '', loadAmpsCopiedFromTrip: false, demandFactor: '1' }],
);
assert.equal(paddedRows.find((row) => row.circuit === '1').description, 'Lights');
assert.equal(paddedRows.filter((row) => row.circuit === '1' || row.circuit === '01').length, 1);

assert.equal(panel.describeShotRole('schedule', 0, 1), 'Schedule 1');
assert.match(panel.describeShotRole('schedule', 0, 2), /top\/left/);
assert.match(panel.describeShotRole('breakers', 1, 2), /bottom\/right/);

const twenty = Array.from({ length: 20 }, (_, i) => ({
  circuit: String(i + 1),
  description: i === 0 ? 'Lights' : '',
  trip: i === 0 ? '20A' : '',
  poles: i === 0 ? '1' : '',
}));
assert.equal(panel.printSlotCount(twenty, 20), 20);
assert.ok(panel.printSlotCount(twenty, 20) < 42);

const exportedSchedule = panel.buildScheduleExport([
  { circuit: '1', description: 'Lights', trip: '20A', poles: '1', loadAmps: '', loadAmpsCopiedFromTrip: true },
], { slotCount: 20, phase: null });
assert.match(exportedSchedule.csv, /1,Lights,20/);
assert.doesNotMatch(exportedSchedule.csv.split('\n')[1], /,20$/);
assert.ok(exportedSchedule.warnings.some((w) => /Phase is unknown/i.test(w)));

assert.match(panelSrc, /copyCsvButton/);
assert.match(panelSrc, /printSlotCount/);
assert.match(panelSrc, /describeShotRole/);
assert.match(panelHtml, /id="copyCsvButton"/);
assert.match(panelHtml, /01 and 1 are the same slot/);

console.log('Panel load analyzer helpers passed');
