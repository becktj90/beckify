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

// --- 2nd-order wn / ζ from overshoot and 2% settling -------------------------
// Mp = exp(−ζπ/√(1−ζ²)); ζ = 0.5 ⇒ Mp ≈ 16.3%. ts = 4/(ζ wn); ts = 4, wn = 2.
const fromStep = engine.secondOrderFromOvershootSettling(16.3, 4);
assert.ok(near(fromStep.zeta, 0.5, 0.01), 'ζ from 16.3% overshoot');
assert.ok(near(fromStep.wn, 2, 0.05), 'ωn = 4/(ζ ts)');
assert.ok(near(engine.overshootFromZeta(0.5) * 100, 16.3, 0.2), 'Mp from ζ inverts');

// --- Type-N ess formulas (Ogata / Nise) -------------------------------------
const type0 = engine.loopErrorConstants({ numerator: [1], denominator: [1, 1] }); // 1/(s+1)
assert.equal(type0.type, 0);
assert.ok(near(type0.Kp, 1), 'Type 0 Kp = G(0)');
assert.ok(near(type0.step, 0.5), 'ess = 1/(1+Kp) for a Type 0 step');
assert.equal(type0.ramp, Infinity);

const type1 = engine.loopErrorConstants({ numerator: [1], denominator: [1, 0] }); // 1/s
assert.equal(type1.type, 1);
assert.equal(type1.step, 0);
assert.ok(near(type1.Kv, 1));
assert.ok(near(type1.ramp, 1), 'ess = 1/Kv for a Type 1 ramp');

const type2 = engine.loopErrorConstants({ numerator: [1], denominator: [1, 0, 0] }); // 1/s²
assert.equal(type2.type, 2);
assert.equal(type2.step, 0);
assert.equal(type2.ramp, 0);
assert.ok(near(type2.Ka, 1));
assert.ok(near(type2.parabola, 1), 'ess = 1/Ka for a Type 2 parabola');

const motorPos = engine.loopErrorConstants({ numerator: [1], denominator: [0.5, 1, 0] });
assert.equal(motorPos.type, 1, '1/(0.5s² + s) is Type 1');

// --- Lead α / T placement ---------------------------------------------------
const lead = engine.designLeadPhaseBump(60, 10);
assert.ok(near(lead.alpha, (1 - Math.sin(Math.PI / 3)) / (1 + Math.sin(Math.PI / 3)), 1e-6));
assert.ok(near(lead.T, 1 / (10 * Math.sqrt(lead.alpha)), 1e-6));
assert.deepEqual(lead.tf.numerator, [lead.T, 1]);
assert.ok(near(lead.tf.denominator[0], lead.alpha * lead.T));
const parts = engine.leadNetworkParts(0.2, 0.01, 1e-7);
assert.ok(near(parts.R1, 0.01 / 1e-7));
assert.ok(near(parts.R2, 0.2 * parts.R1));
assert.ok(parts.alpha < 1, 'example network is a lead');

const raise = engine.designLeadRaiseWn(0.5, 4, 0.25);
assert.ok(near(raise.zero, -2));
assert.ok(near(raise.pole, -8));

// --- Ziegler–Nichols Ku/Pu and reaction-curve -------------------------------
const znC = engine.zieglerNicholsUltimate(6, 4, 'PID', 'classic');
assert.ok(near(znC.kp, 0.6 * 6));
assert.ok(near(znC.Ti, 2));
assert.ok(near(znC.Td, 0.5));
assert.ok(near(znC.ki, znC.kp / znC.Ti));
assert.ok(near(znC.kd, znC.kp * znC.Td));
const znM = engine.zieglerNicholsUltimate(6, 4, 'PID', 'modified');
assert.ok(near(znM.kp, 0.33 * 6));
assert.ok(near(znM.Ti, 2));
assert.ok(near(znM.Td, 4 / 3));
const znP = engine.zieglerNicholsUltimate(8, 2, 'P', 'classic');
assert.ok(near(znP.kp, 4));
assert.ok(near(znP.ki, 0));
const znPI = engine.zieglerNicholsUltimate(8, 2.4, 'PI', 'classic');
assert.ok(near(znPI.kp, 0.45 * 8));
assert.ok(near(znPI.Ti, 2));

const znR = engine.zieglerNicholsReactionCurve(1, 0.5, 2, 'PID', 'classic');
assert.ok(near(znR.kp, 1.2 * 2 / 0.5));
assert.ok(near(znR.Ti, 1));
assert.ok(near(znR.Td, 0.25));

// 1/(s(s+1)(s+2)) has Ku = 6 by Routh.
const kuPlant = { numerator: [1], denominator: [1, 3, 2, 0] };
const ku = engine.ultimateGain(kuPlant);
assert.ok(ku.Ku !== null && near(ku.Ku, 6, 0.15), `Ku ≈ 6, got ${ku.Ku}`);

// --- Bode GM / PM and closed-loop bandwidth ---------------------------------
// G = 4 / (s(s+2)): |G| = 1 at ωgc ≈ 1.572, phase ≈ −128.2°, PM ≈ 51.8°, GM = ∞.
const type1lag = { numerator: [4], denominator: [1, 2, 0] };
const bode = engine.bodeResponse(type1lag, { minOmega: 0.05, maxOmega: 50, points: 400 });
const margins = engine.computeMargins(bode);
assert.ok(near(margins.gainCrossover, 1.572, 0.08), `ωgc got ${margins.gainCrossover}`);
assert.ok(near(margins.phaseMarginDeg, 51.8, 2), `PM got ${margins.phaseMarginDeg}`);
assert.equal(margins.gainMarginDb, null, 'this loop never reaches −180°');

// Kp = 9 on 1/(s+1) closes to 9/(s+10). |T| DC = 0.9; −3 dB at ωb = 10.
const olP = engine.seriesTransferFunction({ numerator: [9], denominator: [1] }, plant);
assert.ok(near(engine.closedLoopBandwidth(olP), 10, 0.4), 'ωb of 9/(s+10)');

// --- Ackermann / companion 2nd-order placement ------------------------------
// s² + 3s + 2, poles at −2, −4 ⇒ desired s² + 6s + 8, K = [6, 3].
const ss = engine.transferFunctionToStateSpace({ numerator: [1], denominator: [1, 3, 2] });
assert.ok(engine.isControllableCompanion(ss.A, ss.B));
const K = engine.placePolesAckermann(ss.A, ss.B, [-2, -4]);
assert.ok(near(K[0][0], 6, 0.05) && near(K[0][1], 3, 0.05), `K got ${JSON.stringify(K)}`);
const bass = engine.companionPlacementGains([1, 3, 2], [-2, -4]);
assert.ok(near(bass.K[0][0], 6) && near(bass.K[0][1], 3));

// --- Anti-windup integrator clamp -------------------------------------------
const satPlant = engine.transferFunctionToStateSpace({ numerator: [1], denominator: [1, 1] });
const free = engine.simulatePidWithSaturation({
  plant: satPlant, kp: 1, ki: 20, kd: 0, duration: 4, dt: 0.01, uMin: -0.5, uMax: 0.5, antiWindup: false,
});
const clamped = engine.simulatePidWithSaturation({
  plant: satPlant, kp: 1, ki: 20, kd: 0, duration: 4, dt: 0.01, uMin: -0.5, uMax: 0.5, antiWindup: true,
});
const lastFree = free[free.length - 1];
const lastClamped = clamped[clamped.length - 1];
assert.ok(lastFree.integrator > 1, `unclamped I winds up, got ${lastFree.integrator}`);
assert.ok(lastClamped.integrator <= 0.5 + 1e-6, `clamped I stays within umax, got ${lastClamped.integrator}`);
assert.ok(Math.abs(lastClamped.u) <= 0.5 + 1e-6);

console.log('Control engine helpers passed');
