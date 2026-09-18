/**
 * Arcade-compressed ascent science. Numbers track MET, throttle, fuel, and
 * phase — not random fluff. Atmosphere and TWR are methane/LOX shaped.
 */
const G0 = 9.80665;
const RHO0 = 1.225;
const H_SCALE = 8.5;
const WET_KG = 1_180_000;
const PROP_KG = 1_020_000;
const BOOSTER_WET = 290_000;
const BOOSTER_PROP = 210_000;
const THRUST_N = 7 * 2_400_000;
const Q_DISPLAY = 1.38;

function clamp(n, a, b) {
  return Math.max(a, Math.min(b, n));
}

export function density(altKm) {
  const h = Math.max(0, altKm);
  if (h > 86) return 1e-6;
  return RHO0 * Math.exp(-h / H_SCALE);
}

export function soundSpeed(altKm) {
  const h = Math.max(0, altKm);
  if (h < 11) return 340.3 - h * 4.05;
  if (h < 20) return 295;
  if (h < 47) return 295 + (h - 20) * 1.15;
  if (h < 80) return 329 - (h - 47) * 1.4;
  return 275;
}

export function ascentVelocity(tClock, throttle) {
  const t = Math.max(0, tClock);
  const thr = clamp(throttle, 0.12, 1);
  return (26 * t + 1.12 * t * t) * (0.74 + 0.26 * thr);
}

export function computeTelemetry(sample) {
  const status = sample.status || 'MENU';
  const tClock = Number(sample.tClock) || 0;
  const throttle = clamp(Number(sample.throttle) || 0, 0, 1);
  const fuel = clamp(Number(sample.fuel) ?? 100, 0, 100);
  const angle = Number(sample.angle) || 0;
  const vx = Number(sample.vx) || 0;
  const vy = Number(sample.vy) || 0;
  const dt = Math.max(0.008, Number(sample.dt) || 0.016);
  const prevVelMs = sample.prevVelMs;
  const sepPhase = sample.sepPhase || '';
  const onBooster = status === 'SEP' || status === 'JACKLYN' || sepPhase === 'clear';

  let altKm = Math.max(0, Number(sample.altitudeKm) || 0);
  let velMs;
  let fpaDeg;
  let downrangeKm;
  let chamberPct = throttle * 100;

  if (status === 'PRELAUNCH' || status === 'MENU') {
    altKm = 0;
    velMs = 0;
    fpaDeg = 90;
    downrangeKm = 0;
    chamberPct = (Number(sample.charge) || throttle) * 100;
  } else if (status === 'ASCENT') {
    const t = Math.max(0, tClock);
    altKm = clamp(t * 1.42, 0, 110);
    velMs = Math.max(0, ascentVelocity(t, throttle));
    fpaDeg = clamp(90 - t * 1.28 + angle * 0.15, 28, 90);
    downrangeKm = 0.046 * t * t;
  } else if (status === 'SEP') {
    altKm = clamp(Math.max(altKm, 48) + (sample.sepElapsed || 0) * 0.35, 48, 86);
    const coast = Math.max(0, tClock);
    velMs = Math.max(1400, ascentVelocity(Math.min(coast, 42), 0.2) * 0.92);
    fpaDeg = clamp(38 - (sample.sepElapsed || 0) * 1.1, 8, 42);
    downrangeKm = 0.046 * Math.min(coast, 48) * Math.min(coast, 48) + (sample.sepElapsed || 0) * 1.6;
    chamberPct = sepPhase === 'clear' ? 0 : (throttle > 0.8 ? 0 : 0);
  } else if (status === 'JACKLYN') {
    altKm = clamp(altKm, 0, 14);
    velMs = Math.max(0, Math.abs(vy) * 42 + 18);
    fpaDeg = clamp(-78 - angle * 0.4, -90, -40);
    downrangeKm = Math.max(0.4, Math.abs(vx) * 0.08 + altKm * 0.35);
    chamberPct = throttle * 100;
  } else {
    velMs = Math.max(0, Number(sample.velocity) || 0);
    fpaDeg = 0;
    downrangeKm = 0;
  }

  const rho = density(altKm);
  const a = soundSpeed(altKm);
  const mach = a > 1 ? velMs / a : 0;
  const qKpa = (0.5 * rho * velMs * velMs) / 1000 * Q_DISPLAY;

  const wet = onBooster ? BOOSTER_WET : WET_KG;
  const propMax = onBooster ? BOOSTER_PROP : PROP_KG;
  const mass = (wet - propMax) + propMax * (fuel / 100);
  const thrust = THRUST_N * (onBooster ? 0.22 : 1) * throttle;
  const twr = mass > 1 ? thrust / (mass * G0) : 0;

  let accG;
  if (status === 'SEP') {
    accG = sepPhase === 'clear' ? 0.05 : 0.12;
  } else if (prevVelMs != null && Number.isFinite(prevVelMs)) {
    const dv = (velMs - prevVelMs) / dt;
    accG = clamp(dv / G0 + (status === 'JACKLYN' ? -0.15 : 0), -1.2, 6.2);
  } else if (status === 'ASCENT') {
    accG = clamp(twr - Math.cos((fpaDeg * Math.PI) / 180) * 0.92, 0.2, 5.4);
  } else if (status === 'JACKLYN') {
    accG = throttle > 0.5 ? clamp(1.1 + throttle * 1.4, 0.4, 3.6) : 0.2;
  } else {
    accG = throttle > 0.05 ? 0.15 : 0;
  }

  const propPct = fuel;
  const loxPct = clamp(fuel * 0.97 - (100 - fuel) * 0.02, 0, 100);
  const lch4Pct = clamp(fuel * 1.01, 0, 100);
  const massFrac = propMax / wet;
  const apoKm = status === 'JACKLYN'
    ? altKm
    : clamp(altKm + (velMs * velMs) / (2 * G0) / 1000 * 0.42, altKm, 420);

  return {
    altKm,
    velMs,
    mach,
    qKpa,
    accG,
    twr,
    fpaDeg,
    downrangeKm,
    apoKm,
    chamberPct,
    propPct,
    loxPct,
    lch4Pct,
    massFrac,
    rho,
  };
}

/**
 * Arcade recovery tape — closing speed, paint offset, gear, burn cue.
 * Numbers are compressed play-feel, not a GNC sim.
 */
export function formatRecoverHud({
  altPx = 0,
  dxPx = 0,
  vy = 0,
  burnWindow = false,
  burnLit = false,
  boosting = false,
  landingTol = 36,
  gear = false,
} = {}) {
  const rangeM = Math.max(0, Math.round(Math.abs(altPx) * 0.85));
  const offsetM = Math.round(dxPx * 0.55);
  const closing = Math.max(0, Math.round(Math.abs(vy) * 36));
  const onPaint = Math.abs(dxPx) <= landingTol + 22;
  const off = onPaint
    ? 'ON PAINT'
    : `${offsetM < 0 ? 'L' : 'R'} ${Math.abs(offsetM)}`;
  let burn = 'GLIDE';
  if (burnLit && boosting) burn = 'BURN LIT';
  else if (burnWindow && boosting) burn = 'HOLD';
  else if (burnWindow) burn = 'HOLD TO BURN';
  const gearTxt = gear ? 'DN' : 'UP';
  const rng = rangeM >= 1000 ? `${(rangeM / 1000).toFixed(1)}km` : `${rangeM}m`;
  const burnShort = burn === 'HOLD TO BURN' ? 'HOLD' : burn;
  return {
    rangeM,
    offsetM,
    closing,
    onPaint,
    gear: gearTxt,
    burn,
    line: `RNG ${rng} · OFF ${off} · VC ${closing} · GEAR ${gearTxt} · ${burnShort}`,
  };
}

export function formatScience(sci, difficulty) {
  const kid = difficulty === 'KID';
  const mach = sci.mach < 0.12 ? '0.00' : sci.mach.toFixed(2);
  const q = sci.qKpa < 0.05 ? '0.0 kPa' : `${sci.qKpa.toFixed(1)} kPa`;
  return {
    alt: `${sci.altKm.toFixed(1)} km`,
    vel: `${Math.round(sci.velMs)} m/s`,
    mach,
    q,
    acc: `${sci.accG.toFixed(1)} g`,
    twr: sci.twr < 0.04 ? '0.00' : sci.twr.toFixed(2),
    fpa: `${Math.round(sci.fpaDeg)}°`,
    cham: `${Math.round(sci.chamberPct)}%`,
    prop: `${Math.round(sci.propPct)}%`,
    ticker: kid
      ? `${sci.altKm.toFixed(1)} km · ${Math.round(sci.velMs)} m/s · ${Math.round(sci.chamberPct)}% thr`
      : `M ${mach} · q ${sci.qKpa.toFixed(0)} kPa · ${sci.accG.toFixed(1)} g · γ ${Math.round(sci.fpaDeg)}°`,
    dense: !kid,
  };
}
