/* Cable schedule numbering, quantity expansion, and blank field-fill columns. */
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
  JSON,
  Promise,
  document: {
    readyState: 'complete',
    addEventListener() {},
    getElementById() { return null; },
    createElement() { return { appendChild() {}, setAttribute() {} }; },
    head: { appendChild() {} },
    body: { appendChild() {} },
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'cable-schedule.js'), 'utf8'), sandbox, { filename: 'cable-schedule.js' });

const api = sandbox.__cableScheduleTestApi;
assert.ok(api, 'cable schedule test API missing');

const COLUMNS = [
  'Cable ID', 'From', 'To', 'Cable Type', 'Conductor Size', 'Conductor Count',
  'Insulation', 'Voltage Rating', 'Length', 'Routing / Tray', 'Ampacity',
  'Voltage Drop', 'System', 'Termination From', 'Termination To', 'Comments',
];
assert.equal(api.COLUMNS.join('|'), COLUMNS.join('|'));

assert.equal(api.nextCableId('C-', 1, 0, 3), 'C-001');
assert.equal(api.nextCableId('C-', 1, 1, 3), 'C-002');
assert.equal(api.nextCableId('PWR-', 10, 0, 3), 'PWR-010');
assert.equal(api.padNumber(7, 4), '0007');
assert.equal(api.formatConductorSize('12'), '12 AWG');
assert.equal(api.formatConductorSize('2/0'), '2/0 AWG');
assert.equal(api.formatConductorSize('250'), '250 kcmil');
assert.equal(api.formatConductorSize('4/0 AWG'), '4/0 AWG');

const catalog = api.SEED_CATALOG;
const rows = api.expandBuildList(
  [
    { typeId: 'PWR-4C-12', qty: 2, from: 'MCC-1', to: 'P-101', system: '480 V' },
    { typeId: 'CTL-8C-14', qty: 1, from: 'PLC-1', to: 'JB-4' },
  ],
  catalog,
  { prefix: 'C-', start: 1, width: 3 },
);
assert.equal(rows.length, 3);
assert.equal(rows[0]['Cable ID'], 'C-001');
assert.equal(rows[1]['Cable ID'], 'C-002');
assert.equal(rows[2]['Cable ID'], 'C-003');
assert.equal(rows[0].From, 'MCC-1');
assert.equal(rows[0].To, 'P-101');
assert.equal(rows[0]['Cable Type'], 'PWR-4C-12');
assert.equal(rows[0]['Conductor Size'], '12 AWG');
assert.equal(rows[0]['Conductor Count'], '4');
assert.equal(rows[0].Length, '');
assert.equal(rows[0]['Routing / Tray'], '');
assert.equal(rows[0].Comments, '');
assert.equal(rows[2]['Cable Type'], 'CTL-8C-14');

const csv = api.rowsToCsv(rows);
const header = csv.split(/\r?\n/)[0];
assert.equal(header, COLUMNS.join(','));

const roundTrip = api.parseProject(JSON.stringify(api.serializeProject(
  [{ typeId: 'PWR-4C-12', qty: 2, from: 'A', to: 'B' }],
  catalog,
  { prefix: 'C-', start: 5, width: 3 },
)));
assert.equal(roundTrip.numbering.prefix, 'C-');
assert.equal(roundTrip.cart[0].qty, 2);

console.log('Cable schedule numbering and export helpers passed');
