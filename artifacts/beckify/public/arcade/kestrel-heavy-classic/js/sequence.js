/**
 * Arcade-compressed Kestrel Heavy sequence of events.
 * Spine is a commentary board, chapter-ordered like public launch→landing
 * cuts: Terminal Count → Ignition → Liftoff → Max-Q → MECO → Stage Sep →
 * SES-1 → Fairing Jettison → Entry Burn → Landing Burn → Haven Touchdown
 * (~T+96 compressed) → SECO → payload deploy.
 *
 * Real orbital times are minutes. Here T-8s … T+104s so a stranger hears
 * every callout in one run. Per-mission copy swaps {id}/{payload}/{mark}.
 */
import { PACE } from './config.js';

export const T0_LEAD = 8;

/** Compressed MET seconds. Negative = count. */
export const SPINE = [
  {
    id: 'terminal',
    t: -8,
    stage: 'TERMINAL COUNT',
    banner: 'TERMINAL COUNT',
    kind: 'info',
    radio: 'Pier 7 terminal count. {id} on the pad. Range is green.',
    juice: 'none',
    coach: 'TAP TO LAUNCH',
  },
  {
    id: 'tankpress',
    t: -6,
    stage: 'TANK PRESS',
    banner: 'TANK PRESS',
    kind: 'info',
    radio: 'Tank pressurization. LOX and LCH4 going flight pressure.',
    juice: 'none',
    quiet: true,
  },
  {
    id: 'internal',
    t: -4.2,
    stage: 'INTERNAL POWER',
    banner: 'INTERNAL POWER',
    kind: 'info',
    radio: 'Vehicle on internal power. Ground power is safed.',
    juice: 'none',
    quiet: true,
  },
  {
    id: 'deluge',
    t: -2.1,
    stage: 'WATER DELUGE',
    banner: 'WATER DELUGE',
    kind: 'warn',
    radio: 'Water deluge. Pad suppression is on.',
    juice: 'deluge',
    quiet: true,
  },
  {
    id: 'ignition',
    t: -0.8,
    stage: 'IGNITION',
    banner: 'IGNITION',
    kind: 'warn',
    radio: 'Ignition. Seven core engines at startup.',
    juice: 'ignition',
    coach: 'TAP TO LAUNCH — then steer',
  },
  {
    id: 'liftoff',
    t: 0,
    stage: 'LIFTOFF',
    banner: 'LIFTOFF',
    kind: 'go',
    radio: 'Liftoff. {id} clearing the tower.',
    juice: 'liftoff',
    coach: 'Stay inside the corridor · steer only',
  },
  {
    id: 'maxq',
    t: PACE.MAXQ,
    stage: 'MAX-Q',
    banner: 'MAX-Q',
    kind: 'warn',
    radio: 'Max-Q. Vehicle through the region of maximum dynamic pressure.',
    juice: 'maxq',
    coach: 'Fly smooth through Max-Q',
  },
  {
    id: 'meco',
    t: PACE.MECO,
    stage: 'MECO',
    banner: 'MECO',
    kind: 'go',
    radio: 'MECO. First-stage cores shutdown. Hold attitude for sep.',
    juice: 'meco',
    coach: 'Hold attitude — sep zone incoming',
  },
  {
    id: 'sep',
    t: PACE.SEP,
    stage: 'STAGE SEP',
    banner: 'STAGE SEP — SEP ZONE then SEPARATE',
    kind: 'go',
    radio: 'Sep zone. ALIGN green, then press SEPARATE.',
    juice: 'sep',
    quiet: true,
    coach: 'SEP ZONE · press SEPARATE',
  },
  {
    id: 'ses1',
    t: PACE.SES1,
    stage: 'SES-1',
    banner: 'SES-1',
    kind: 'info',
    radio: 'SES-1. Upper-stage engine is lit. {payload} still coasting under the fairing.',
    juice: 'ses',
  },
  {
    id: 'fairing',
    t: PACE.FAIRING,
    stage: 'FAIRING JETTISON',
    banner: 'FAIRING JETTISON',
    kind: 'info',
    radio: 'Fairing jettison. {mark} — {payload} is free of the stack.',
    juice: 'fairing',
  },
  {
    id: 'entry',
    t: PACE.ENTRY,
    stage: 'ENTRY BURN',
    banner: 'ENTRY BURN',
    kind: 'warn',
    radio: 'Entry burn. Pitch over. Haven is downrange. Strakes next — then glide.',
    juice: 'entry',
    coach: 'Pitch over · strakes · glide · then burn',
  },
  {
    id: 'landing',
    t: PACE.LANDING,
    stage: 'LANDING BURN',
    banner: 'LANDING BURN',
    kind: 'warn',
    radio: 'Landing burn. HOLD climb. Kill sink over the paint.',
    juice: 'landing',
    coach: 'HOLD TO BURN for the landing burn',
  },
  {
    id: 'touchdown',
    t: PACE.TOUCHDOWN,
    stage: 'HAVEN',
    banner: 'HAVEN TOUCHDOWN',
    kind: 'go',
    radio: 'Touchdown. BOOSTER RECOVERED. Sea state nominal.',
    juice: 'touchdown',
    coach: 'Catch the painted deck',
  },
  {
    id: 'seco',
    t: PACE.SECO,
    stage: 'SECO',
    banner: 'SECO',
    kind: 'go',
    radio: 'SECO. Upper stage shutdown. Insertion complete.',
    juice: 'seco',
    quiet: true,
  },
  {
    id: 'deploy',
    t: PACE.DEPLOY,
    stage: 'PAYLOAD DEPLOY',
    banner: 'PAYLOAD DEPLOY',
    kind: 'go',
    radio: '{payload} deploy confirmed. {id} is a good flight.',
    juice: 'deploy',
  },
];

export const TAPE_IDS = [
  'terminal', 'tankpress', 'internal', 'deluge', 'ignition', 'liftoff',
  'maxq', 'meco', 'sep', 'ses1', 'fairing', 'entry', 'landing', 'touchdown',
];

function fill(text, mission) {
  return String(text || '')
    .replaceAll('{id}', mission.id)
    .replaceAll('{payload}', mission.payload)
    .replaceAll('{mark}', mission.mark);
}

export function beatsFor(mission) {
  return SPINE.map((beat) => ({
    ...beat,
    banner: fill(beat.banner, mission),
    radio: fill(beat.radio, mission),
  }));
}

export function formatClock(t) {
  const sign = t < 0 ? '-' : '+';
  const abs = Math.min(5999, Math.abs(t));
  const m = Math.floor(abs / 60);
  const s = abs - m * 60;
  const sec = s.toFixed(1).padStart(4, '0');
  return `T${sign}${m}:${sec}`;
}

export function currentBeat(beats, tClock) {
  let last = beats[0];
  for (const beat of beats) {
    if (tClock + 0.001 >= beat.t) last = beat;
  }
  return last;
}

const PHASE_CHIP = {
  terminal: 'TERMINAL COUNT',
  tankpress: 'TERMINAL COUNT',
  internal: 'TERMINAL COUNT',
  deluge: 'TERMINAL COUNT',
  ignition: 'IGNITION',
  liftoff: 'LIFTOFF',
  maxq: 'MAX-Q',
  meco: 'MECO',
  sep: 'STAGE SEP',
  ses1: 'STAGE SEP',
  fairing: 'FAIRING',
  entry: 'PITCH OVER',
  landing: 'LANDING BURN',
  touchdown: 'HAVEN',
  seco: 'HAVEN',
  deploy: 'HAVEN',
};

export function phaseChip(beatId) {
  return PHASE_CHIP[beatId] || 'TERMINAL COUNT';
}

/** Compact play chip — status/phase first so stage changes actually read. */
export function playPhase(status, session = {}, beatId = '') {
  if (status === 'MENU') return 'STANDBY';
  if (status === 'SUMMARY') return 'SUMMARY';
  if (status === 'PRELAUNCH') return session.launchArmed ? 'IGNITION' : 'TERMINAL COUNT';
  if (status === 'ASCENT') {
    const clock = Number(session.tClock) || 0;
    if (clock >= PACE.MECO - 1.6) return 'MECO';
    if (beatId === 'maxq' || clock >= PACE.MAXQ) return 'MAX-Q';
    return 'LIFTOFF';
  }
  if (status === 'SEP') {
    if (session.sepPhase === 'clear') return 'STAGE SEP';
    if (session.sepPhase === 'window') return 'SEP ZONE';
    return 'MECO';
  }
  if (status === 'JACKLYN') {
    const phase = session.jacklynPhase || 'glide';
    if (session.landingLock) return 'HAVEN';
    if (session.burnWindow || phase === 'burn' || phase === 'straighten' || phase === 'settle') {
      return 'LANDING BURN';
    }
    if (phase === 'reentry') return 'PITCH OVER';
    if (phase === 'strakes') return 'STRAKES';
    return 'GLIDE';
  }
  return phaseChip(beatId);
}

export function playPhaseKind(label) {
  if (label === 'LIFTOFF' || label === 'STAGE SEP' || label === 'HAVEN' || label === 'IGNITION') return 'go';
  if (label === 'MAX-Q' || label === 'LANDING BURN' || label === 'SEP ZONE' || label === 'PITCH OVER') return 'warn';
  return 'info';
}

export function nextCoachBeat(beats, tClock) {
  const t = Number(tClock) || 0;
  return (beats || []).find((beat) => beat.coach && t + 0.05 < beat.t) || null;
}

export function playGoal(status, session = {}, flight = {}) {
  if (status === 'PRELAUNCH') {
    return session.launchArmed ? 'IGNITION — cores coming up' : 'TAP TO LAUNCH · one tap, then steer';
  }
  if (status === 'ASCENT') {
    const clock = Number(session.tClock) || 0;
    if (clock < PACE.MAXQ - 4) {
      if (flight.objective?.id === 'shield' && !session.objectiveDone) {
        return 'Stay inside the corridor · grab an aero shield';
      }
      return 'Stay inside the corridor · steer only';
    }
    if (clock < PACE.MAXQ + 5) return 'Fly smooth through Max-Q';
    return 'Steer to MECO — climb stays on';
  }
  if (status === 'SEP') {
    if (session.sepPhase === 'window') return 'SEP ZONE  ·  press SEPARATE';
    if (session.sepPhase === 'clear') return 'Open the gap, then Haven';
    return 'Hold attitude — sep zone incoming';
  }
  if (status === 'JACKLYN') {
    const phase = session.jacklynPhase || 'glide';
    if (phase === 'reentry') return 'PITCH OVER  ·  reentry  ·  strakes stand by';
    if (session.burnWindow || phase === 'burn' || phase === 'straighten' || phase === 'settle') {
      return 'LANDING BURN  ·  HOLD TO BURN  ·  keep holding and steer onto the paint';
    }
    return 'STRAKES OUT  ·  glide the diagonal onto the PAINT  ·  do not burn yet';
  }
  return '';
}

export function playNext(beats, tClock, status) {
  if (status === 'JACKLYN' || status === 'SUMMARY' || status === 'MENU') return '';
  const next = nextCoachBeat(beats, tClock);
  if (!next) return '';
  return `NEXT · ${next.stage} — ${next.coach}`;
}
