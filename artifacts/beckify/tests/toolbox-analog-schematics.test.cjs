const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const sandbox = { console, Math, Number, String, Object, Array, JSON };
sandbox.window = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'analog-schematics.js'), 'utf8'), sandbox, {
  filename: 'analog-schematics.js',
});

const A = sandbox.window.AnalogSchematics;
assert.ok(A, 'AnalogSchematics is exported');

// --- every topology and family draws a schematic and names a transfer fn ----
const OP_AMPS = [
  'inverting', 'noninverting', 'difference', 'summing', 'transimpedance',
  'integrator', 'firstorder', 'lead', 'differentiator', 'comparator', 'schmitt', 'instrumentation',
];
const FILTERS = [
  'rc-low', 'rc-high', 'sk-low', 'sk-high', 'rlc-band', 'rlc-notch',
  'mfb-band', 'state-variable', 'twin-t', 'allpass',
];

for (const type of OP_AMPS) {
  const markup = A.opAmp(type);
  assert.ok(markup.startsWith('<svg') && markup.endsWith('</svg>'), `${type} renders an svg`);
  assert.ok(markup.includes('viewBox'), `${type} svg has a viewBox so it scales`);
  assert.ok(markup.length > 400, `${type} schematic has real content`);
  const tf = A.opAmpTransfer(type);
  assert.ok(tf && tf.h && tf.note, `${type} has a transfer function and a note`);
}

for (const type of FILTERS) {
  const markup = A.filter(type);
  assert.ok(markup.startsWith('<svg') && markup.endsWith('</svg>'), `${type} renders an svg`);
  assert.ok(markup.length > 400, `${type} schematic has real content`);
  const tf = A.filterTransfer(type);
  assert.ok(tf && tf.h && tf.order && tf.roll, `${type} has a transfer function`);
  // The state-variable filter names the output it is plotting (H_BP), since it
  // presents low-pass, band-pass and high-pass simultaneously.
  const sub = A.substituted(type, 1000, 0.707, 1);
  assert.ok(/^H(_[A-Z]+)?\(s\) =/.test(sub), `${type} substitutes real values: ${sub}`);
}

// --- no floating op-amp pins -------------------------------------------------
// Every op-amp pin must have a wire endpoint on it. Drawing these by hand left
// several inputs hanging in mid-air, which looks plausible but is wrong.
function unconnectedPins(markup) {
  const amps = [...markup.matchAll(/M(\d+),(\d+) L\1,(\d+) L(\d+),(\d+) Z/g)]
    .map((m) => ({ x: Number(m[1]), cy: (Number(m[2]) + Number(m[3])) / 2 }));
  const points = [];
  for (const m of markup.matchAll(/<line x1="([\d.]+)" y1="([\d.]+)" x2="([\d.]+)" y2="([\d.]+)"/g)) {
    points.push([Number(m[1]), Number(m[2])], [Number(m[3]), Number(m[4])]);
  }
  for (const m of markup.matchAll(/points="([^"]+)"/g)) {
    for (const pair of m[1].split(' ')) {
      const [px, py] = pair.split(',').map(Number);
      points.push([px, py]);
    }
  }
  const touches = (x, y) => points.some((p) => Math.abs(p[0] - x) < 3 && Math.abs(p[1] - y) < 3);
  const bad = [];
  for (const a of amps) {
    if (!touches(a.x, a.cy - 18)) bad.push(`inverting pin at ${a.x},${a.cy - 18}`);
    if (!touches(a.x, a.cy + 18)) bad.push(`non-inverting pin at ${a.x},${a.cy + 18}`);
    if (!touches(a.x + 64, a.cy)) bad.push(`output at ${a.x + 64},${a.cy}`);
  }
  return bad;
}

for (const type of [...OP_AMPS, ...FILTERS]) {
  const markup = OP_AMPS.includes(type) ? A.opAmp(type) : A.filter(type);
  const bad = unconnectedPins(markup);
  assert.equal(bad.length, 0, `${type} has floating op-amp pins: ${bad.join(', ')}`);
}

// Unknown keys degrade quietly rather than throwing into the page.
assert.equal(A.opAmp('nope'), '');
assert.equal(A.filter('nope'), '');
assert.equal(A.opAmpTransfer('nope'), null);

// --- phase behaviour, checked against the known shape of each response ------
const near = (got, want, tol = 1) => Math.abs(got - want) < tol;

// First-order low-pass: 0° well below f₀, −45° at f₀, −90° well above.
assert.ok(near(A.phaseDeg('rc-low', 0.001, 0.707), 0));
assert.ok(near(A.phaseDeg('rc-low', 1, 0.707), -45));
assert.ok(near(A.phaseDeg('rc-low', 1000, 0.707), -90));

// First-order high-pass is the mirror image: +90° → +45° → 0°.
assert.ok(near(A.phaseDeg('rc-high', 0.001, 0.707), 90));
assert.ok(near(A.phaseDeg('rc-high', 1, 0.707), 45));
assert.ok(near(A.phaseDeg('rc-high', 1000, 0.707), 0));

// All-pass is the reason to plot phase at all: flat magnitude, 0° → −180°.
assert.ok(near(A.phaseDeg('allpass', 0.001, 1), 0));
assert.ok(near(A.phaseDeg('allpass', 1, 1), -90));
assert.ok(near(A.phaseDeg('allpass', 1000, 1), -180));

// Second-order low-pass passes through −90° exactly at resonance.
assert.ok(near(A.phaseDeg('sk-low', 1, 0.707), -90));
assert.ok(near(A.phaseDeg('sk-low', 1000, 0.707), -180, 2));

// Band-pass is 0° at centre, leading below it and lagging above.
assert.ok(near(A.phaseDeg('rlc-band', 1, 0.707), 0));
assert.ok(A.phaseDeg('rlc-band', 0.1, 0.707) > 0, 'band-pass leads below centre');
assert.ok(A.phaseDeg('rlc-band', 10, 0.707) < 0, 'band-pass lags above centre');

// --- substituted forms carry the designed numbers ---------------------------
const w0 = 2 * Math.PI * 1000;
const skLow = A.substituted('sk-low', 1000, 0.707, 2);
assert.ok(skLow.includes('s²'), 'second-order form is quadratic');
assert.ok(
  skLow.includes(Math.round(w0 * w0).toLocaleString('en-US')) ||
  skLow.includes((w0 * w0).toLocaleString('en-US', { maximumFractionDigits: 1 })),
  `sk-low substitutes ω₀² : ${skLow}`,
);
assert.ok(A.substituted('rc-low', 1000, 0.707, 1).includes('s'), 'first-order form is linear in s');

assert.ok(A.opAmpTransfer('lead').h.includes('R1 C1'), 'lead names T = R1 C1');
assert.ok(A.opAmpTransfer('firstorder').h.includes('Rf Cf'), 'first-order lag names Rf Cf');

console.log('Analog schematics and transfer functions passed');
