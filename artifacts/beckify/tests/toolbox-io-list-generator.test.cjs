/* I/O list generator — 26 columns, brands, generic counts, numbering. */
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
  'Page',
  'Field Device',
  'Intermediate Device',
  'EPLAN Updated',
  'Electrical Check Complete',
  'Scaling Verified',
  'T&LO V&V',
  'Comments',
];

assert.equal(COLUMNS.length, 26, 'workbook IO List is 26 columns');
assert.deepEqual(Array.from(api.COLUMNS), COLUMNS, 'column order must match the specified I/O list');

const catalog = api.SEED_CATALOG;
assert.ok(catalog.length > 12, 'multi-brand seed is larger than Beckhoff-only');
assert.ok(api.catalogByPn(catalog, 'EK1100'), 'EK1100 in seed catalog');
assert.equal(api.catalogByPn(catalog, 'EK1100').channels, 0);
assert.equal(api.catalogByPn(catalog, 'EL1819').channels, 16);
assert.equal(api.catalogByPn(catalog, 'EL3048').rawMin, '0');
assert.equal(api.catalogByPn(catalog, 'EL3048').rawMax, '4095');
assert.equal(api.catalogByPn(catalog, 'EL4022').rawMin, '6554');
assert.equal(api.catalogByPn(catalog, 'EL4022').rawMax, '32767');
assert.ok(api.catalogByPn(catalog, '1756-IB16'), 'Rockwell 1756 DI');
assert.ok(api.catalogByPn(catalog, '1734-AENT'), 'POINT adapter');
assert.ok(api.catalogByPn(catalog, '6ES7131-6BH01-0BA0'), 'ET 200SP DI');
assert.ok(api.catalogByPn(catalog, '750-430'), 'WAGO DI');
assert.ok(api.BRANDS.some((b) => b.id === 'generic'), 'generic brand exists');
assert.ok(api.BRANDS.some((b) => b.id === 'beckhoff-ethercat'));

assert.equal(api.paddedCardName('KEC', 1), 'KEC0101');
assert.equal(api.paddedCardName('KFD', 1), 'KFD0101');
assert.equal(api.paddedCardName('XDC', 2), 'XDC0102');
assert.equal(api.signalFamily('AI (4-20mA)'), 'AI');
assert.equal(api.signalFamily('Coupler'), 'coupler');
assert.equal(api.typeColor('DI').html, 'iol-sig-di');
assert.equal(api.colorKey('AI (0-10V)'), 'AI-V');

const stations = [{
  controller: 'PLC-1',
  stationName: 'MCC-A',
  brand: 'beckhoff-ethercat',
  couplerPrefix: 'KFD',
  ioPrefix: 'KEC',
  powerPrefix: 'XDC',
  modules: [
    { pn: 'EK1100', qty: 1 },
    { pn: 'EL1819', qty: 1 },
    { pn: 'EL9410', qty: 1 },
    { pn: 'EL3048', qty: 1 },
    { pn: 'EL2828', qty: 2 },
  ],
}];

const rows = api.expandBuildList(stations, catalog);

const coupler = rows.filter((r) => r['Card Part Number'] === 'EK1100');
assert.equal(coupler.length, 1, 'coupler emits one row');
assert.equal(coupler[0]['Slot Number'], '1');
assert.equal(coupler[0]['Channel Number'], '', 'coupler has no channel number');
assert.equal(coupler[0]['Wire Terminal'], '');
assert.equal(coupler[0]['Card Name'], 'KFD0101');
assert.equal(coupler[0]['Signal Type'], 'Coupler');

const di = rows.filter((r) => r['Card Part Number'] === 'EL1819');
assert.equal(di.length, 16, 'EL1819 expands to 16 channel rows');
assert.ok(di.every((r) => r['Slot Number'] === '2'), 'DI card is slot 2 after the coupler');
assert.ok(di.every((r) => r['Card Name'] === 'KEC0101'));
assert.deepEqual(Array.from(di.map((r) => r['Channel Number'])), Array.from({ length: 16 }, (_, i) => String(i + 1)));
assert.deepEqual(Array.from(di.map((r) => r['Wire Terminal'])), Array.from(di.map((r) => r['Channel Number'])));

const power = rows.filter((r) => r['Card Part Number'] === 'EL9410');
assert.equal(power.length, 1);
assert.equal(power[0]['Slot Number'], '3');
assert.equal(power[0]['Channel Number'], '');
assert.equal(power[0]['Card Name'], 'XDC0101');

const ai = rows.filter((r) => r['Card Part Number'] === 'EL3048');
assert.equal(ai.length, 8);
assert.ok(ai.every((r) => r['Card Name'] === 'KEC0102'));
assert.ok(ai.every((r) => r['Raw Min'] === '0' && r['Raw Max'] === '4095'));
assert.ok(ai.every((r) => r.Min === '' && r.Max === '' && r.Units === ''));

const doCards = rows.filter((r) => r['Card Part Number'] === 'EL2828');
assert.equal(doCards.length, 16);
assert.equal(doCards[0]['Card Name'], 'KEC0103');
assert.equal(doCards[8]['Card Name'], 'KEC0104');
assert.ok(doCards.every((r) => r.Min === '0' && r.Max === '1' && r.Units === 'BOOL'));
assert.ok(doCards.every((r) => r['Raw Min'] === '0' && r['Raw Max'] === '1'));

const blankCols = [
  'Wire Number', 'Linked PLC Variable Name', 'Description', 'System',
  'Device Category', 'Page', 'Field Device', 'Intermediate Device',
  'EPLAN Updated', 'Electrical Check Complete', 'Scaling Verified', 'T&LO V&V', 'Comments',
];
for (const col of blankCols) {
  assert.ok(rows.every((r) => r[col] === ''), col + ' left blank on generate');
}

const summary = api.summarizeRows(rows);
assert.equal(summary.DI, 16);
assert.equal(summary.DO, 16);
assert.equal(summary.AI, 8);
assert.equal(summary.analogInputs, 8);
assert.equal(summary.couplers, 1);
assert.equal(summary.power, 1);
assert.equal(summary.spare, 16 + 16 + 8, 'all generated channel rows are spare until tagged');
assert.equal(summary.totalChannels, 16 + 16 + 8);

const aoa = api.rowsToAoa(rows);
assert.deepEqual(Array.from(aoa[0]), COLUMNS);
assert.equal(aoa.length, rows.length + 1);

const csv = api.rowsToCsv(rows);
assert.equal(csv.split(/\r\n/)[0], COLUMNS.join(','));

const roundTrip = api.parseProject(JSON.stringify(api.serializeProject(stations, catalog)));
assert.equal(roundTrip.stations[0].brand, 'beckhoff-ethercat');
assert.equal(roundTrip.stations[0].mode, 'catalog');
assert.equal(roundTrip.stations[0].modules.length, 5);
assert.ok(!JSON.stringify(api.serializeProject(stations, catalog)).includes('Linked PLC Variable Name'));

const v1 = api.parseProject(JSON.stringify({
  version: 1,
  kind: 'io-list-build',
  catalog: [{ pn: 'EK1100', description: 'c', channels: 0, signalType: 'Coupler', rawMin: '', rawMax: '' }],
  stations: [{ controller: 'A', stationName: 'S', cardPrefix: 'C', modules: [{ pn: 'EK1100', qty: 1 }] }],
}));
assert.equal(v1.stations[0].ioPrefix, 'C');
assert.equal(v1.stations[0].brand, 'beckhoff-ethercat');

const two = api.expandBuildList([
  { controller: 'A', stationName: 'S1', brand: 'beckhoff-ethercat', couplerPrefix: 'KFD', ioPrefix: 'KEC', powerPrefix: 'XDC', modules: [{ pn: 'EK1100', qty: 1 }, { pn: 'EL4022', qty: 1 }] },
  { controller: 'B', stationName: 'S2', brand: 'ra-1734', couplerPrefix: 'AENT', ioPrefix: 'POINT', powerPrefix: 'PWR', modules: [{ pn: '1734-AENT', qty: 1 }] },
], catalog);
assert.equal(two.filter((r) => r['Card Part Number'] === 'EL4022')[0]['Raw Min'], '6554');
assert.equal(two.filter((r) => r['Card Part Number'] === 'EL4022')[0]['Card Name'], 'KEC0101');
assert.equal(two.filter((r) => r['Station Name'] === 'S2')[0]['Card Name'], 'AENT0101');
assert.equal(two.filter((r) => r['Station Name'] === 'S2')[0]['Channel Number'], '');

const genericSt = {
  controller: 'PLC-1',
  stationName: 'Generic Rack',
  brand: 'generic',
  mode: 'generic',
  couplerPrefix: 'CPL',
  ioPrefix: 'IO',
  powerPrefix: 'PWR',
  genericCounts: {
    coupler: 1,
    power: 1,
    DI: { points: 32, density: 16 },
    DO: { points: 8, density: 8 },
    AI: { points: 0, density: 8 },
    AO: { points: 0, density: 4 },
    RTD: { points: 0, density: 4 },
    TC: { points: 0, density: 8 },
    IOLINK: { points: 0, density: 4 },
  },
  modules: [],
};
assert.equal(api.isGenericStation(genericSt), true);
const genMods = api.genericCountsToModules(genericSt.genericCounts);
assert.equal(genMods.filter((m) => m.pn === 'Generic DI').length, 2);
const genRows = api.expandBuildList([genericSt], catalog);
assert.equal(genRows.filter((r) => r['Card Part Number'] === 'Generic Coupler').length, 1);
assert.equal(genRows.filter((r) => r['Card Part Number'] === 'Generic Coupler')[0]['Channel Number'], '');
assert.equal(genRows.filter((r) => r['Card Part Number'] === 'Generic DI').length, 32);
assert.equal(genRows.filter((r) => r['Card Part Number'] === 'Generic DI')[0]['Card Name'], 'IO0101');
assert.equal(genRows.filter((r) => r['Card Part Number'] === 'Generic DO')[0]['Units'], 'BOOL');
const genJson = api.parseProject(JSON.stringify(api.serializeProject([genericSt], catalog)));
assert.equal(genJson.stations[0].mode, 'generic');
assert.equal(genJson.stations[0].genericCounts.DI.points, 32);

const ebus = api.ebusRowsFromBuild(stations, catalog, 200);
assert.ok(ebus.length >= 5);
assert.equal(ebus[0]['Current contribution mA'], '2000');
assert.ok(Number(ebus[1]['Running total mA']) < Number(ebus[0]['Running total mA']));
const powerEbus = ebus.filter((r) => r['Part Type'] === 'EL9410')[0];
assert.equal(powerEbus['Running total mA'], '2000', 'power refresh resets remaining');
