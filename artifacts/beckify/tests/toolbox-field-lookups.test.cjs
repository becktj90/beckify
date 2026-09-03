/* Torque lookup, NEC 220 load worksheet, and NEC / UL 508A wire colors. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function load(filename, exportName) {
  const sandbox = {
    console,
    Math,
    Number,
    String,
    Object,
    Array,
    JSON,
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
    fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'js', filename), 'utf8'),
    sandbox,
    { filename: filename }
  );
  const api = sandbox[exportName];
  assert.ok(api, exportName + ' exported from ' + filename);
  return api;
}

const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');

let fails = 0;
function ok(name, condition, detail) {
  if (!condition) fails += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name.padEnd(72) + (detail ?? ''));
}

const torque = load('torque-lookup.js', '__torqueLookupTestApi');
const loadWs = load('load-worksheet.js', '__loadWorksheetTestApi');
const colors = load('wire-colors.js', '__wireColorsTestApi');

console.log('\n--- Torque: UL 486A-B typical AWG lookup ---');
{
  const r = torque.lookupLug('8 AWG', 'slotNarrow');
  ok('8 AWG narrow slot is 25 in-lb', r.ok && r.inLb === 25, JSON.stringify(r));
  ok('8 AWG reports N·m', r.ok && Math.abs(r.nm - (25 / 8.8507457676)) < 1e-9);
  ok('citation names UL 486A-B', /UL 486A-B/.test(r.citation));
  ok('manufacturer marking wins', /Manufacturer marking/.test(r.caveat));
}
{
  const r = torque.lookupLug('4/0', 'splitBolt');
  ok('4/0 split-bolt is 500 in-lb', r.ok && r.inLb === 500, JSON.stringify(r));
}
{
  const r = torque.lookupLug('1 AWG', 'slotNarrow');
  ok('1 AWG narrow slot is not listed', !r.ok && /does not list/i.test(r.error));
}

console.log('\n--- Load worksheet: 220.42 lighting demand ---');
{
  const fixtures = {
    method: 'commercial',
    occupancy: 'dwelling',
    voltage: 240,
    system: '1ph',
    sparePct: 0,
    rows: [
      { id: 'a', description: 'Living room cans', type: 'lighting', qty: 10, value: 60, unit: 'W', phase: '1ph', dfOverride: '' },
      { id: 'b', description: 'Hall', type: 'lighting', qty: 4, value: 40, unit: 'W', phase: '1ph', dfOverride: '' },
    ],
  };
  const connected = 10 * 60 + 4 * 40; /* 760 VA */
  const r = loadWs.computeSheet(fixtures);
  ok('small fixture list connected VA is 760', r.connectedVA === connected, String(r.connectedVA));
  /* 220.42 dwelling: first 3000 @ 100%. 760 < 3000 → demand = 760 */
  ok('220.42 dwelling lighting under 3 kVA is 100%', Math.abs(r.demandVA - 760) < 0.01, String(r.demandVA));
  ok('cites 220.42', r.cited.indexOf('220.42') !== -1);
}
{
  const lighting = loadWs.lightingDemand220_42(10000, 'dwelling');
  /* first 3000 @ 100% = 3000; remaining 7000 @ 35% = 2450; total 5450 */
  ok('10 kVA dwelling lighting demand is 5450 VA', Math.abs(lighting.demandVA - 5450) < 0.01, String(lighting.demandVA));
}
{
  const r = loadWs.computeSheet({
    method: 'commercial',
    occupancy: 'other',
    voltage: 208,
    system: '3ph',
    sparePct: 10,
    rows: [
      { id: 'a', description: 'Office lights', type: 'lighting', qty: 1, value: 5000, unit: 'VA', phase: '3ph', dfOverride: '' },
    ],
  });
  ok('commercial "all others" lighting stays 100%', Math.abs(r.demandVA - 5000) < 0.01, String(r.demandVA));
  ok('spare adder is applied to feeder', Math.abs(r.demandWithSpareVA - 5500) < 0.01, String(r.demandWithSpareVA));
}

console.log('\n--- Wire colors: high-leg is CODE; UL 508A yellow interlock ---');
{
  const high = colors.highLegRow();
  ok('high-leg row exists', !!high);
  ok('high-leg color is orange', high && /orange/i.test(high.color));
  ok('high-leg is labeled code', high && high.mandate === 'code');
  ok('high-leg cites 110.15', high && /110\.15/.test(high.cite));
  ok('high-leg text says this one is code, not convention', high && /code, not convention/i.test(high.cite));
}
{
  const yel = colors.ulYellowInterlock();
  ok('UL 508A yellow interlock row present', !!yel);
  ok('yellow interlock is a safety callout', yel && yel.safety === true);
  ok('yellow note mentions disconnect off / live', yel && /disconnect/i.test(yel.note) && /energized|live/i.test(yel.role + yel.note));
  ok('UL 508A section is cited', yel && /66\./.test(yel.section));
}
{
  const grounded = colors.NEC_SYSTEMS[0].rows.filter((r) => r.mandate === 'code');
  ok('NEC 120/240 marks grounded and EGC as code', grounded.length >= 2);
}

console.log('\n--- Markup wiring ---');
ok('torque section exists', /id="sec-torque-lookup"/.test(html));
ok('wire-colors section exists', /id="sec-wire-colors"/.test(html));
ok('load worksheet host exists', /id="lw_rows"/.test(html));
ok('torque script is loaded', /js\/torque-lookup\.js/.test(html));
ok('load worksheet script is loaded', /js\/load-worksheet\.js/.test(html));
ok('wire-colors script is loaded', /js\/wire-colors\.js/.test(html));
ok('nav has torque lookup', /data-target="sec-torque-lookup"/.test(html));
ok('nav has wire colors', /data-target="sec-wire-colors"/.test(html));
ok('UL 508A tab exists', /UL 508A/.test(html));

console.log(fails ? `\n${fails} FAILURE(S)` : '\nAll field-lookup checks passed');
process.exitCode = fails ? 1 : 0;
