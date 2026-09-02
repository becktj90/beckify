/* I/O list generator — numbering, coupler-as-slot, column order. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  Set,
  isFinite,
  parseFloat,
  parseInt,
  document: {
    getElementById() { return null; },
    querySelector() { return null; },
    addEventListener() {},
    readyState: 'complete',
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'js', 'io-list-generator.js'), 'utf8'),
  sandbox,
  { filename: 'io-list-generator.js' }
);

const api = sandbox.__ioListGeneratorTestApi;
assert.ok(api, 'test API exported');

const COLUMNS = [
  'Controller',
  'Card Name',
  'Card Part Number',
  'Station Name',
  'Slot Number',
  'Channel Number',
  'Wire Terminal',
  'Wire Number',
  'Linked PLC Variable Name',
  'Description',
  'System',
  'Device Category',
  'Signal Type',
  'Min',
  'Max',
  'Units',
  'Raw Min',
  'Raw Max',
  'Field Device',
  'Intermediate Device',
  'Comments',
];

assert.deepEqual(Array.from(api.COLUMNS), COLUMNS, 'column order must match the specified I/O list');

const catalog = api.SEED_CATALOG;
assert.equal(catalog.length, 12, 'seed catalog has the 12 Beckhoff-style parts');
assert.ok(api.catalogByPn(catalog, 'EK1100'), 'EK1100 in seed catalog');
assert.equal(api.catalogByPn(catalog, 'EK1100').channels, 0);
assert.equal(api.catalogByPn(catalog, 'EL1819').channels, 16);
assert.equal(api.catalogByPn(catalog, 'EL3048').rawMin, '0');
assert.equal(api.catalogByPn(catalog, 'EL3048').rawMax, '4095');
assert.equal(api.catalogByPn(catalog, 'EL3318').rawMin, '-32768');

const stations = [{
  controller: 'PLC-1',
  stationName: 'MCC-A',
  cardPrefix: 'C',
  modules: [
    { pn: 'EK1100', qty: 1 },
    { pn: 'EL1819', qty: 1 },
    { pn: 'EL9410', qty: 1 },
    { pn: 'EL3048', qty: 1 },
    { pn: 'EL2828', qty: 2 },
  ],
}];

const rows = api.expandBuildList(stations, catalog);

/* Coupler and power consume slots and each emit one documentation row. */
const coupler = rows.filter((r) => r['Card Part Number'] === 'EK1100');
assert.equal(coupler.length, 1, 'coupler emits one row');
assert.equal(coupler[0]['Slot Number'], '1');
assert.equal(coupler[0]['Channel Number'], '', 'coupler has no channel number');
assert.equal(coupler[0]['Signal Type'], 'Coupler');
assert.equal(coupler[0]['Wire Terminal'], '');

const di = rows.filter((r) => r['Card Part Number'] === 'EL1819');
assert.equal(di.length, 16, 'EL1819 expands to 16 channel rows');
assert.ok(di.every((r) => r['Slot Number'] === '2'), 'DI card is slot 2 after the coupler');
assert.deepEqual(Array.from(di.map((r) => r['Channel Number'])), Array.from({ length: 16 }, (_, i) => String(i + 1)));
assert.deepEqual(Array.from(di.map((r) => r['Wire Terminal'])), Array.from(di.map((r) => r['Channel Number'])));
assert.ok(di.every((r) => r.Controller === 'PLC-1'));
assert.ok(di.every((r) => r['Station Name'] === 'MCC-A'));
assert.ok(di.every((r) => r['Card Name'] === 'C2'));
assert.ok(di.every((r) => r['Signal Type'] === 'DI'));

const power = rows.filter((r) => r['Card Part Number'] === 'EL9410');
assert.equal(power.length, 1, 'power refresh emits one documentation row');
assert.equal(power[0]['Slot Number'], '3', 'power card still consumes a slot');
assert.equal(power[0]['Channel Number'], '');

const ai = rows.filter((r) => r['Card Part Number'] === 'EL3048');
assert.equal(ai.length, 8);
assert.ok(ai.every((r) => r['Slot Number'] === '4'));
assert.ok(ai.every((r) => r['Raw Min'] === '0' && r['Raw Max'] === '4095'), 'AI raw range comes from catalog');
assert.ok(ai.every((r) => r.Min === '' && r.Max === '' && r.Units === ''), 'eng min/max/units stay blank');

const doCards = rows.filter((r) => r['Card Part Number'] === 'EL2828');
assert.equal(doCards.length, 16, 'qty 2 of EL2828 → 16 DO channels');
assert.ok(doCards.slice(0, 8).every((r) => r['Slot Number'] === '5'));
assert.ok(doCards.slice(8).every((r) => r['Slot Number'] === '6'));
assert.equal(doCards[0]['Card Name'], 'C5');
assert.equal(doCards[8]['Card Name'], 'C6');

const blankCols = [
  'Wire Number', 'Linked PLC Variable Name', 'Description', 'System',
  'Device Category', 'Min', 'Max', 'Units', 'Field Device', 'Intermediate Device', 'Comments',
];
for (const col of blankCols) {
  assert.ok(rows.every((r) => r[col] === ''), col + ' left blank on generate');
}

const summary = api.summarizeRows(rows);
assert.equal(summary.DI, 16);
assert.equal(summary.DO, 16);
assert.equal(summary.AI, 8);
assert.equal(summary.AO, 0);
assert.equal(summary.RTD, 0);
assert.equal(summary.TC, 0);
assert.equal(summary.couplers, 1);
assert.equal(summary.totalChannels, 16 + 16 + 8);

const aoa = api.rowsToAoa(rows);
assert.deepEqual(Array.from(aoa[0]), COLUMNS, 'xlsx/csv header is the specified column order');
assert.equal(aoa.length, rows.length + 1);

const csv = api.rowsToCsv(rows);
const headerLine = csv.split(/\r\n/)[0];
assert.equal(headerLine, COLUMNS.join(','));

const roundTrip = api.parseProject(JSON.stringify(api.serializeProject(stations, catalog)));
assert.equal(roundTrip.stations[0].modules.length, 5, 'JSON saves the build list, not the expanded table');
assert.ok(!JSON.stringify(api.serializeProject(stations, catalog)).includes('Linked PLC Variable Name'));

/* Two stations number slots independently. */
const two = api.expandBuildList([
  { controller: 'A', stationName: 'S1', cardPrefix: 'X', modules: [{ pn: 'EK1100', qty: 1 }, { pn: 'EL4022', qty: 1 }] },
  { controller: 'B', stationName: 'S2', cardPrefix: 'Y', modules: [{ pn: 'EK1110', qty: 1 }] },
], catalog);
assert.equal(two.filter((r) => r['Station Name'] === 'S1' && r['Slot Number'] === '1').length, 1);
assert.equal(two.filter((r) => r['Card Part Number'] === 'EL4022')[0]['Slot Number'], '2');
assert.equal(two.filter((r) => r['Card Part Number'] === 'EL4022')[0]['Raw Min'], '0');
assert.equal(two.filter((r) => r['Card Part Number'] === 'EL4022')[0]['Raw Max'], '32767');
assert.equal(two.filter((r) => r['Station Name'] === 'S2')[0]['Slot Number'], '1');
assert.equal(two.filter((r) => r['Station Name'] === 'S2')[0]['Card Name'], 'Y1');
assert.equal(api.cardNameFor('AI-', 3), 'AI-3');
