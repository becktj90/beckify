export type Matrix = number[][];

export type Complex = {
  re: number;
  im: number;
};

export type TransferFunction = {
  numerator: number[];
  denominator: number[];
  sampleTime?: number | null;
};

export type StateSpaceSystem = {
  A: Matrix;
  B: Matrix;
  C: Matrix;
  D: Matrix;
  sampleTime?: number | null;
};

export type StepSample = {
  t: number;
  y: number;
  u: number;
  states: number[];
};

export type PerformanceMetrics = {
  riseTime: number | null;
  peakTime: number | null;
  overshoot: number;
  settlingTime: number | null;
  steadyStateError: number;
  finalValue: number;
};

export type BodePoint = {
  omega: number;
  magnitudeDb: number;
  phaseDeg: number;
  real: number;
  imag: number;
};

const EPSILON = 1e-9;

export function cloneMatrix(matrix: Matrix): Matrix {
  return matrix.map((row) => [...row]);
}

export function zeros(rows: number, cols: number): Matrix {
  return Array.from({ length: rows }, () => Array(cols).fill(0));
}

export function identity(size: number): Matrix {
  const out = zeros(size, size);
  for (let index = 0; index < size; index += 1) out[index][index] = 1;
  return out;
}

export function transpose(matrix: Matrix): Matrix {
  return matrix[0].map((_, column) => matrix.map((row) => row[column] ?? 0));
}

export function addMatrices(a: Matrix, b: Matrix): Matrix {
  return a.map((row, rowIndex) => row.map((value, columnIndex) => value + (b[rowIndex]?.[columnIndex] ?? 0)));
}

export function subtractMatrices(a: Matrix, b: Matrix): Matrix {
  return a.map((row, rowIndex) => row.map((value, columnIndex) => value - (b[rowIndex]?.[columnIndex] ?? 0)));
}

export function scaleMatrix(matrix: Matrix, scalar: number): Matrix {
  return matrix.map((row) => row.map((value) => value * scalar));
}

export function multiplyMatrices(a: Matrix, b: Matrix): Matrix {
  const rows = a.length;
  const cols = b[0]?.length ?? 0;
  const inner = b.length;
  const out = zeros(rows, cols);
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      let sum = 0;
      for (let index = 0; index < inner; index += 1) sum += (a[row]?.[index] ?? 0) * (b[index]?.[col] ?? 0);
      out[row][col] = sum;
    }
  }
  return out;
}

export function inverse(matrix: Matrix): Matrix {
  const size = matrix.length;
  const augmented = matrix.map((row, rowIndex) => [...row, ...identity(size)[rowIndex]]);
  for (let pivot = 0; pivot < size; pivot += 1) {
    let pivotRow = pivot;
    for (let row = pivot + 1; row < size; row += 1) {
      if (Math.abs(augmented[row][pivot]) > Math.abs(augmented[pivotRow][pivot])) pivotRow = row;
    }
    if (Math.abs(augmented[pivotRow][pivot]) < EPSILON) throw new Error("Matrix is singular.");
    if (pivotRow !== pivot) [augmented[pivot], augmented[pivotRow]] = [augmented[pivotRow], augmented[pivot]];
    const pivotValue = augmented[pivot][pivot];
    for (let col = 0; col < size * 2; col += 1) augmented[pivot][col] /= pivotValue;
    for (let row = 0; row < size; row += 1) {
      if (row === pivot) continue;
      const factor = augmented[row][pivot];
      for (let col = 0; col < size * 2; col += 1) augmented[row][col] -= factor * augmented[pivot][col];
    }
  }
  return augmented.map((row) => row.slice(size));
}

export function trace(matrix: Matrix): number {
  return matrix.reduce((sum, row, index) => sum + (row[index] ?? 0), 0);
}

export function matrixPower(matrix: Matrix, exponent: number): Matrix {
  if (exponent === 0) return identity(matrix.length);
  let out = cloneMatrix(matrix);
  for (let index = 1; index < exponent; index += 1) out = multiplyMatrices(out, matrix);
  return out;
}

export function normalizePolynomial(coefficients: number[]): number[] {
  const trimmed = [...coefficients];
  while (trimmed.length > 1 && Math.abs(trimmed[0]) < EPSILON) trimmed.shift();
  if (Math.abs(trimmed[0] ?? 0) < EPSILON) return [0];
  const lead = trimmed[0];
  return trimmed.map((value) => value / lead);
}

export function padPolynomial(coefficients: number[], size: number): number[] {
  if (coefficients.length >= size) return [...coefficients];
  return [...Array(size - coefficients.length).fill(0), ...coefficients];
}

export function addPolynomials(a: number[], b: number[]): number[] {
  const size = Math.max(a.length, b.length);
  const left = padPolynomial(a, size);
  const right = padPolynomial(b, size);
  return left.map((value, index) => value + right[index]);
}

export function multiplyPolynomials(a: number[], b: number[]): number[] {
  const out = Array(a.length + b.length - 1).fill(0);
  for (let left = 0; left < a.length; left += 1) {
    for (let right = 0; right < b.length; right += 1) out[left + right] += a[left] * b[right];
  }
  return out;
}

export function complex(re: number, im = 0): Complex {
  return { re, im };
}

export function complexAdd(a: Complex, b: Complex): Complex {
  return { re: a.re + b.re, im: a.im + b.im };
}

export function complexSub(a: Complex, b: Complex): Complex {
  return { re: a.re - b.re, im: a.im - b.im };
}

export function complexMul(a: Complex, b: Complex): Complex {
  return { re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re };
}

export function complexDiv(a: Complex, b: Complex): Complex {
  const denom = b.re * b.re + b.im * b.im;
  return { re: (a.re * b.re + a.im * b.im) / denom, im: (a.im * b.re - a.re * b.im) / denom };
}

export function complexMagnitude(value: Complex): number {
  return Math.hypot(value.re, value.im);
}

export function complexPhaseDeg(value: Complex): number {
  return (Math.atan2(value.im, value.re) * 180) / Math.PI;
}

export function evaluatePolynomialComplex(coefficients: number[], value: Complex): Complex {
  return coefficients.reduce((accumulator, coefficient) => complexAdd(complexMul(accumulator, value), complex(coefficient, 0)), complex(0, 0));
}

export function evaluateTransferFunction(tf: TransferFunction, omega: number): Complex {
  const s = complex(0, omega);
  return complexDiv(evaluatePolynomialComplex(tf.numerator, s), evaluatePolynomialComplex(tf.denominator, s));
}

function characteristicPolynomial(matrix: Matrix): number[] {
  const size = matrix.length;
  let b = identity(size);
  const coefficients = [1];
  for (let order = 1; order <= size; order += 1) {
    const ab = multiplyMatrices(matrix, b);
    const c = -trace(ab) / order;
    coefficients.push(c);
    b = addMatrices(ab, scaleMatrix(identity(size), c));
  }
  return coefficients;
}

function makeInitialRoots(order: number): Complex[] {
  return Array.from({ length: order }, (_, index) => {
    const angle = (2 * Math.PI * index) / order;
    return complex(Math.cos(angle), Math.sin(angle));
  });
}

export function polynomialRoots(coefficients: number[]): Complex[] {
  const normalized = normalizePolynomial(coefficients);
  const order = normalized.length - 1;
  if (order <= 0) return [];
  if (order === 1) return [complex(-normalized[1])];
  let roots = makeInitialRoots(order);
  for (let iteration = 0; iteration < 120; iteration += 1) {
    let maxDelta = 0;
    roots = roots.map((root, index) => {
      const value = evaluatePolynomialComplex(normalized, root);
      const divisor = roots.reduce((accumulator, current, currentIndex) => {
        if (currentIndex === index) return accumulator;
        return complexMul(accumulator, complexSub(root, current));
      }, complex(1, 0));
      const next = complexSub(root, complexDiv(value, divisor));
      maxDelta = Math.max(maxDelta, Math.hypot(next.re - root.re, next.im - root.im));
      return next;
    });
    if (maxDelta < 1e-8) break;
  }
  return roots;
}

export function eigenvalues(matrix: Matrix): Complex[] {
  return polynomialRoots(characteristicPolynomial(matrix));
}

export function controllabilityMatrix(A: Matrix, B: Matrix): Matrix {
  const order = A.length;
  let out = cloneMatrix(B);
  let power = cloneMatrix(B);
  for (let index = 1; index < order; index += 1) {
    power = multiplyMatrices(A, power);
    out = out.map((row, rowIndex) => [...row, ...power[rowIndex]]);
  }
  return out;
}

export function parsePolynomialInput(input: string): number[] {
  return input
    .split(/[\s,]+/)
    .map((part) => Number(part.trim()))
    .filter((value) => Number.isFinite(value));
}

export function parseMatrixInput(input: string): Matrix {
  return input
    .trim()
    .split(/\n+/)
    .map((line) => line.split(/[\s,]+/).map((part) => Number(part.trim())).filter((value) => Number.isFinite(value)))
    .filter((row) => row.length > 0);
}

export function transferFunctionToStateSpace(tf: TransferFunction): StateSpaceSystem {
  // normalizePolynomial divides the denominator through by its leading
  // coefficient, so the numerator has to be divided by that same value or the
  // model silently gains a 1/lead gain error. G = 0.6/(0.002s^2+0.08s+0.52)
  // otherwise settles at 0.0023 instead of 1.1538 — off by 500x.
  const rawDenominator = [...tf.denominator];
  while (rawDenominator.length > 1 && Math.abs(rawDenominator[0]) < EPSILON) rawDenominator.shift();
  const lead = Math.abs(rawDenominator[0] ?? 0) < EPSILON ? 1 : rawDenominator[0];
  const denominator = normalizePolynomial(tf.denominator);
  const numerator = padPolynomial(tf.numerator.map((value) => value / lead), denominator.length);
  const order = denominator.length - 1;
  if (order < 1) {
    return {
      A: [[0]],
      B: [[0]],
      C: [[0]],
      D: [[numerator[numerator.length - 1] / denominator[denominator.length - 1]]],
      sampleTime: tf.sampleTime ?? null,
    };
  }
  const A = zeros(order, order);
  for (let row = 0; row < order - 1; row += 1) A[row][row + 1] = 1;
  const trailing = denominator.slice(1).map((value) => -value);
  A[order - 1] = [...trailing].reverse();
  const B = zeros(order, 1);
  B[order - 1][0] = 1;
  const direct = numerator[0];
  const adjusted = numerator.slice(1).map((value, index) => value - direct * denominator[index + 1]);
  const C = [adjusted.reverse()];
  const D = [[direct]];
  return { A, B, C, D, sampleTime: tf.sampleTime ?? null };
}

export function bodeResponse(tf: TransferFunction, options?: { minOmega?: number; maxOmega?: number; points?: number }): BodePoint[] {
  const minOmega = options?.minOmega ?? 0.1;
  const maxOmega = options?.maxOmega ?? 100;
  const points = options?.points ?? 140;
  return Array.from({ length: points }, (_, index) => {
    const fraction = index / Math.max(points - 1, 1);
    const omega = minOmega * (maxOmega / minOmega) ** fraction;
    const response = evaluateTransferFunction(tf, omega);
    return {
      omega,
      magnitudeDb: 20 * Math.log10(Math.max(complexMagnitude(response), EPSILON)),
      phaseDeg: complexPhaseDeg(response),
      real: response.re,
      imag: response.im,
    };
  });
}

export function computeMargins(points: BodePoint[]) {
  let gainMarginDb: number | null = null;
  let phaseMarginDeg: number | null = null;
  let gainCrossover: number | null = null;
  let phaseCrossover: number | null = null;

  for (let index = 1; index < points.length; index += 1) {
    const prev = points[index - 1];
    const next = points[index];
    if ((prev.magnitudeDb <= 0 && next.magnitudeDb >= 0) || (prev.magnitudeDb >= 0 && next.magnitudeDb <= 0)) {
      const ratio = (0 - prev.magnitudeDb) / ((next.magnitudeDb - prev.magnitudeDb) || 1);
      const omega = prev.omega + (next.omega - prev.omega) * ratio;
      const phase = prev.phaseDeg + (next.phaseDeg - prev.phaseDeg) * ratio;
      gainCrossover = omega;
      phaseMarginDeg = 180 + phase;
    }
    if ((prev.phaseDeg <= -180 && next.phaseDeg >= -180) || (prev.phaseDeg >= -180 && next.phaseDeg <= -180)) {
      const ratio = (-180 - prev.phaseDeg) / ((next.phaseDeg - prev.phaseDeg) || 1);
      const omega = prev.omega + (next.omega - prev.omega) * ratio;
      const magnitude = prev.magnitudeDb + (next.magnitudeDb - prev.magnitudeDb) * ratio;
      phaseCrossover = omega;
      gainMarginDb = -magnitude;
    }
  }

  return { gainMarginDb, phaseMarginDeg, gainCrossover, phaseCrossover };
}

function vectorFromMatrix(matrix: Matrix): number[] {
  return matrix.map((row) => row[0] ?? 0);
}

function matrixFromVector(vector: number[]): Matrix {
  return vector.map((value) => [value]);
}

function rk4Step(A: Matrix, B: Matrix, x: number[], u: number, dt: number): number[] {
  const dx = (state: number[]) => {
    const stateColumn = matrixFromVector(state);
    const derivative = addMatrices(multiplyMatrices(A, stateColumn), scaleMatrix(B, u));
    return vectorFromMatrix(derivative);
  };
  const k1 = dx(x);
  const k2 = dx(x.map((value, index) => value + k1[index] * dt * 0.5));
  const k3 = dx(x.map((value, index) => value + k2[index] * dt * 0.5));
  const k4 = dx(x.map((value, index) => value + k3[index] * dt));
  return x.map((value, index) => value + ((k1[index] + 2 * k2[index] + 2 * k3[index] + k4[index]) * dt) / 6);
}

export function simulateStepResponse(system: StateSpaceSystem, options?: { duration?: number; dt?: number; inputAmplitude?: number; feedbackGain?: Matrix | null }): StepSample[] {
  const duration = options?.duration ?? 8;
  const dt = options?.dt ?? 0.01;
  const inputAmplitude = options?.inputAmplitude ?? 1;
  const feedbackGain = options?.feedbackGain ?? null;
  const A = feedbackGain ? subtractMatrices(system.A, multiplyMatrices(system.B, feedbackGain)) : system.A;
  const B = system.B;
  const C = system.C;
  const D = system.D;
  const samples: StepSample[] = [];
  let x = Array(system.A.length).fill(0);
  for (let time = 0; time <= duration + EPSILON; time += dt) {
    const y = multiplyMatrices(C, matrixFromVector(x))[0]?.[0] ?? 0;
    const d = D[0]?.[0] ?? 0;
    samples.push({ t: time, y: y + d * inputAmplitude, u: inputAmplitude, states: [...x] });
    x = rk4Step(A, B, x, inputAmplitude, dt);
  }
  return samples;
}

export function computePerformanceMetrics(samples: StepSample[], target = 1): PerformanceMetrics {
  const finalValue = samples[samples.length - 1]?.y ?? 0;
  const ten = target * 0.1;
  const ninety = target * 0.9;
  const riseStart = samples.find((sample) => sample.y >= ten)?.t ?? null;
  const riseEnd = samples.find((sample) => sample.y >= ninety)?.t ?? null;
  const peak = samples.reduce((best, sample) => (sample.y > best.y ? sample : best), samples[0] ?? { t: 0, y: 0, u: 0, states: [] });
  const overshoot = target === 0 ? 0 : Math.max(0, ((peak.y - target) / Math.max(Math.abs(target), EPSILON)) * 100);
  let settlingTime: number | null = null;
  const band = Math.abs(target) * 0.02 || 0.02;
  for (let index = samples.length - 1; index >= 0; index -= 1) {
    if (Math.abs(samples[index].y - target) > band) {
      settlingTime = samples[index + 1]?.t ?? null;
      break;
    }
  }
  return {
    riseTime: riseStart !== null && riseEnd !== null ? riseEnd - riseStart : null,
    peakTime: peak.t ?? null,
    overshoot,
    settlingTime,
    steadyStateError: Math.abs(target - finalValue),
    finalValue,
  };
}

function symmetrize(matrix: Matrix): Matrix {
  return matrix.map((row, rowIndex) => row.map((value, columnIndex) => (value + (matrix[columnIndex]?.[rowIndex] ?? 0)) / 2));
}

export function solveCARE(A: Matrix, B: Matrix, Q: Matrix, R: Matrix, options?: { horizon?: number; steps?: number }): Matrix {
  const horizon = options?.horizon ?? 18;
  const steps = options?.steps ?? 3600;
  const dt = horizon / steps;
  const AT = transpose(A);
  const BT = transpose(B);
  const Rinv = inverse(R);
  let P = cloneMatrix(Q);
  for (let index = 0; index < steps; index += 1) {
    const PB = multiplyMatrices(P, B);
    const riccatiTerm = multiplyMatrices(multiplyMatrices(PB, Rinv), multiplyMatrices(BT, P));
    const derivative = addMatrices(addMatrices(multiplyMatrices(AT, P), multiplyMatrices(P, A)), subtractMatrices(Q, riccatiTerm));
    P = symmetrize(addMatrices(P, scaleMatrix(derivative, dt)));
  }
  return P;
}

export function computeLQR(A: Matrix, B: Matrix, Q: Matrix, R: Matrix) {
  const P = solveCARE(A, B, Q, R);
  const K = multiplyMatrices(multiplyMatrices(inverse(R), transpose(B)), P);
  const closedLoop = subtractMatrices(A, multiplyMatrices(B, K));
  return {
    P,
    K,
    closedLoopPoles: eigenvalues(closedLoop),
  };
}

export function computeKalmanGain(A: Matrix, C: Matrix, W: Matrix, V: Matrix) {
  const estimatorP = solveCARE(transpose(A), transpose(C), W, V);
  const L = transpose(multiplyMatrices(multiplyMatrices(inverse(V), transpose(C)), estimatorP));
  return {
    P: estimatorP,
    L,
    estimatorPoles: eigenvalues(subtractMatrices(A, multiplyMatrices(L, C))),
  };
}

function companionPolynomialFromRoots(roots: number[]): number[] {
  return roots.reduce((coefficients, root) => multiplyPolynomials(coefficients, [1, -root]), [1]);
}

export function placePolesAckermann(A: Matrix, B: Matrix, desiredPoles: number[]): Matrix {
  const order = A.length;
  if (B[0]?.length !== 1) throw new Error("Ackermann pole placement in this toolbox expects a single-input system.");
  const ctrb = controllabilityMatrix(A, B);
  const ctrbInv = inverse(ctrb);
  const alpha = companionPolynomialFromRoots(desiredPoles);
  let phiA = zeros(order, order);
  alpha.forEach((coefficient, index) => {
    const power = order - index;
    const term = power === 0 ? identity(order) : matrixPower(A, power);
    phiA = addMatrices(phiA, scaleMatrix(term, coefficient));
  });
  const selector = [Array(order).fill(0)];
  selector[0][order - 1] = 1;
  return multiplyMatrices(multiplyMatrices(selector, ctrbInv), phiA);
}

export function rootLocus(tf: TransferFunction, gains: number[]): { gain: number; poles: Complex[] }[] {
  const denominator = normalizePolynomial(tf.denominator);
  const numerator = padPolynomial(tf.numerator, denominator.length);
  return gains.map((gain) => ({ gain, poles: polynomialRoots(addPolynomials(denominator, numerator.map((value) => value * gain))) }));
}

export function poleZeroMap(tf: TransferFunction) {
  return {
    poles: polynomialRoots(tf.denominator),
    zeros: polynomialRoots(tf.numerator),
  };
}

export type PidGains = { kp: number; ki: number; kd: number };

/**
 * Ideal PID as a transfer function: Kp + Ki/s + Kd·s = (Kd s² + Kp s + Ki) / s.
 * With ki = kd = 0 this collapses to proportional-only, and the extra pole at
 * the origin cancels in seriesTransferFunction.
 */
export function pidTransferFunction({ kp, ki, kd }: PidGains): TransferFunction {
  // Without integral action there is no pole at the origin. Writing PD as
  // (Kd s² + Kp s)/s instead would leave an uncancelled s in both numerator and
  // denominator, which is harmless in the response but makes the closed-loop
  // denominator carry a spurious root at 0 — reporting stable loops as unstable.
  if (Math.abs(ki) < EPSILON) {
    if (Math.abs(kd) < EPSILON) return { numerator: [kp], denominator: [1] };
    return { numerator: [kd, kp], denominator: [1] };
  }
  return { numerator: [kd, kp, ki], denominator: [1, 0] };
}

/** Series (cascade) connection: C(s)·G(s). */
export function seriesTransferFunction(a: TransferFunction, b: TransferFunction): TransferFunction {
  return {
    numerator: multiplyPolynomials(a.numerator, b.numerator),
    denominator: multiplyPolynomials(a.denominator, b.denominator),
  };
}

/**
 * Unity-negative-feedback closed loop: T = L / (1 + L) where L is the open-loop
 * transfer function. With L = N/D that is N / (D + N).
 */
export function closedLoopTransferFunction(openLoop: TransferFunction): TransferFunction {
  return {
    numerator: [...openLoop.numerator],
    denominator: addPolynomials(openLoop.denominator, openLoop.numerator),
  };
}

/** Steady-state value of a step response, i.e. the DC gain N(0)/D(0). */
export function dcGain(tf: TransferFunction): number {
  const num = tf.numerator[tf.numerator.length - 1] ?? 0;
  const den = tf.denominator[tf.denominator.length - 1] ?? 0;
  if (Math.abs(den) < EPSILON) return Number.POSITIVE_INFINITY;
  return num / den;
}

/** A system is stable when every closed-loop pole sits in the open left half plane. */
export function isStable(tf: TransferFunction): boolean {
  return polynomialRoots(tf.denominator).every((pole) => pole.re < -EPSILON);
}

function matrixExpSeries(A: Matrix, dt: number, order = 16): Matrix {
  const scaled = scaleMatrix(A, dt);
  let out = identity(A.length);
  let term = identity(A.length);
  for (let index = 1; index <= order; index += 1) {
    term = scaleMatrix(multiplyMatrices(term, scaled), 1 / index);
    out = addMatrices(out, term);
  }
  return out;
}

export function discretizeStateSpace(system: StateSpaceSystem, dt: number, method: "zoh" | "tustin" = "zoh"): StateSpaceSystem {
  if (method === "tustin") {
    const I = identity(system.A.length);
    const half = scaleMatrix(system.A, dt / 2);
    const invTerm = inverse(subtractMatrices(I, half));
    const Ad = multiplyMatrices(invTerm, addMatrices(I, half));
    const Bd = multiplyMatrices(invTerm, scaleMatrix(system.B, dt));
    return { A: Ad, B: Bd, C: system.C, D: system.D, sampleTime: dt };
  }
  const Ad = matrixExpSeries(system.A, dt);
  let Bd = zeros(system.B.length, system.B[0]?.length ?? 1);
  let term = scaleMatrix(system.B, dt);
  Bd = addMatrices(Bd, term);
  for (let index = 2; index <= 14; index += 1) {
    term = scaleMatrix(multiplyMatrices(system.A, term), dt / index);
    Bd = addMatrices(Bd, term);
  }
  return { A: Ad, B: Bd, C: system.C, D: system.D, sampleTime: dt };
}

export function simulateDiscreteSystem(system: StateSpaceSystem, options?: { steps?: number; input?: number; feedbackGain?: Matrix | null }): StepSample[] {
  const steps = options?.steps ?? 40;
  const input = options?.input ?? 1;
  const gain = options?.feedbackGain ?? null;
  const A = gain ? subtractMatrices(system.A, multiplyMatrices(system.B, gain)) : system.A;
  const samples: StepSample[] = [];
  let x = Array(system.A.length).fill(0);
  for (let step = 0; step <= steps; step += 1) {
    const y = multiplyMatrices(system.C, matrixFromVector(x))[0]?.[0] ?? 0;
    samples.push({ t: step * (system.sampleTime ?? 1), y, u: input, states: [...x] });
    const next = addMatrices(multiplyMatrices(A, matrixFromVector(x)), scaleMatrix(system.B, input));
    x = vectorFromMatrix(next);
  }
  return samples;
}

export function formatComplex(value: Complex): string {
  const real = value.re.toFixed(3);
  const imag = Math.abs(value.im).toFixed(3);
  const sign = value.im >= 0 ? "+" : "−";
  return `${real} ${sign} ${imag}j`;
}
