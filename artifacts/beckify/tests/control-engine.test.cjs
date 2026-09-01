const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');

// controlEngine is TypeScript and the rest of the suite is plain CommonJS, so
// transpile it in memory (types stripped, no type checking) and evaluate the
// result rather than adding a build step just for tests.
const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'utils', 'controlEngine.ts'), 'utf8');
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
});
const engineModule = new Module('controlEngine');
engineModule._compile(outputText, path.join(__dirname, 'controlEngine.generated.js'));
const engine = engineModule.exports;

const near = (got, want, tol = 1e-3) => Math.abs(got - want) < tol;
const steadyState = (tf, duration, dt = 0.005) => {
  const samples = engine.simulateStepResponse(engine.transferFunctionToStateSpace(tf), { duration, dt });
  return samples[samples.length - 1].y;
};

// --- transferFunctionToStateSpace numerator scaling -------------------------
// The denominator is normalised to monic, so the numerator must be divided by
// the same leading coefficient. Without that, this DC motor model settles at
// 0.0023 instead of 1.1538 — a 500x error, since the lead is 0.002.
const dcMotor = { numerator: [0.6], denominator: [0.002, 0.08, 0.52] };
assert.ok(near(engine.dcGain(dcMotor), 0.6 / 0.52), 'dcGain reads N(0)/D(0)');
assert.ok(
  near(steadyState(dcMotor, 20), 0.6 / 0.52),
  'non-monic denominator must not rescale the plant gain',
);

// A monic denominator was always correct; guard against a regression there.
assert.ok(near(steadyState({ numerator: [1], denominator: [1, 1.4, 12] }, 40), 1 / 12));

// --- PID / series / closed-loop algebra -------------------------------------
const plant = { numerator: [1], denominator: [1, 1] }; // 1/(s+1)

// Proportional only collapses to a constant, no spurious pole at the origin.
const pOnly = engine.pidTransferFunction({ kp: 9, ki: 0, kd: 0 });
assert.deepEqual(pOnly.numerator, [9]);
assert.deepEqual(pOnly.denominator, [1]);

// Kp = 9 on 1/(s+1) closes to 9/(s+10): DC gain Kp/(1+Kp) = 0.9.
const closedP = engine.closedLoopTransferFunction(engine.seriesTransferFunction(pOnly, plant));
assert.deepEqual(closedP.numerator, [9]);
assert.deepEqual(closedP.denominator, [1, 10]);
assert.ok(near(engine.dcGain(closedP), 0.9), 'P control leaves a steady-state offset');
assert.ok(near(steadyState(closedP, 5, 0.001), 0.9), 'simulated P response matches the algebra');

// Integral action removes the offset entirely.
const closedPi = engine.closedLoopTransferFunction(
  engine.seriesTransferFunction(engine.pidTransferFunction({ kp: 2, ki: 3, kd: 0 }), plant),
);
assert.ok(near(engine.dcGain(closedPi), 1), 'PI drives steady-state error to zero');
assert.ok(near(steadyState(closedPi, 20, 0.002), 1, 2e-3), 'simulated PI response reaches setpoint');

// --- stability ---------------------------------------------------------------
assert.equal(engine.isStable(closedP), true);
assert.equal(engine.isStable({ numerator: [1], denominator: [1, -1] }), false, '1/(s-1) is unstable');

// A high proportional gain on a third-order plant should destabilise it, which
// is the whole point of showing stability next to the tuning sliders.
const thirdOrder = { numerator: [1], denominator: [1, 3, 3, 1] };
assert.equal(engine.isStable(engine.closedLoopTransferFunction(
  engine.seriesTransferFunction(engine.pidTransferFunction({ kp: 1, ki: 0, kd: 0 }), thirdOrder),
)), true, 'modest gain stays stable');
assert.equal(engine.isStable(engine.closedLoopTransferFunction(
  engine.seriesTransferFunction(engine.pidTransferFunction({ kp: 20, ki: 0, kd: 0 }), thirdOrder),
)), false, 'excessive gain goes unstable');

console.log('Control engine helpers passed');
