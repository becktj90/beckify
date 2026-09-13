/**
 * Arcade-compressed Kestrel Heavy sequence of events.
 * Spine is a commentary board:
 * Terminal Count → Tank Press → Internal Power → Water Deluge → Ignition →
 * Liftoff → Max-Q → MECO → Stage Sep → SES-1 → Fairing Jettison →
 * Entry Burn → Landing Burn → Haven Touchdown (~T+96 compressed) →
 * SECO → payload deploy.
 *
 * Real orbital times are hours and minutes. Here T-8s … T+104s so a stranger
 * hears every callout in one longer, more deliberate run. Per-mission copy
 * swaps {id}/{payload}/{mark}.
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
  },
  {
    id: 'tankpress',
    t: -6,
    stage: 'TANK PRESS',
    banner: 'TANK PRESS',
    kind: 'info',
    radio: 'Tank pressurization. LOX and LCH4 going flight pressure.',
    juice: 'none',
  },
  {
    id: 'internal',
    t: -4.2,
    stage: 'INTERNAL POWER',
    banner: 'INTERNAL POWER',
    kind: 'info',
    radio: 'Vehicle on internal power. Ground power is safed.',
    juice: 'none',
  },
  {
    id: 'deluge',
    t: -2.1,
    stage: 'WATER DELUGE',
    banner: 'WATER DELUGE',
    kind: 'warn',
    radio: 'Water deluge. Pad suppression is on.',
    juice: 'deluge',
  },
  {
    id: 'ignition',
    t: -0.8,
    stage: 'IGNITION',
    banner: 'IGNITION',
    kind: 'warn',
    radio: 'Ignition. Seven core engines at startup.',
    juice: 'ignition',
  },
  {
    id: 'liftoff',
    t: 0,
    stage: 'LIFTOFF',
    banner: 'LIFTOFF',
    kind: 'go',
    radio: 'Liftoff. {id} clearing the tower.',
    juice: 'liftoff',
  },
  {
    id: 'maxq',
    t: PACE.MAXQ,
    stage: 'MAX-Q',
    banner: 'MAX-Q',
    kind: 'warn',
    radio: 'Max-Q. Vehicle through the region of maximum dynamic pressure.',
    juice: 'maxq',
  },
  {
    id: 'meco',
    t: PACE.MECO,
    stage: 'MECO',
    banner: 'MECO',
    kind: 'go',
    radio: 'MECO. First-stage cores shutdown. Hold attitude for sep.',
    juice: 'meco',
  },
  {
    id: 'sep',
    t: PACE.SEP,
    stage: 'STAGE SEP',
    banner: 'STAGE SEP — ALIGN then TAP CLIMB',
    kind: 'go',
    radio: 'Sep window. ALIGN green, then tap climb to fire the pyros.',
    juice: 'sep',
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
    radio: 'Entry burn. Haven is downrange. Slide in diagonal.',
    juice: 'entry',
  },
  {
    id: 'landing',
    t: PACE.LANDING,
    stage: 'LANDING BURN',
    banner: 'LANDING BURN',
    kind: 'warn',
    radio: 'Landing burn. Brake for the painted deck.',
    juice: 'landing',
  },
  {
    id: 'touchdown',
    t: PACE.TOUCHDOWN,
    stage: 'HAVEN',
    banner: 'HAVEN TOUCHDOWN',
    kind: 'go',
    radio: 'Touchdown. BOOSTER RECOVERED. Sea state nominal.',
    juice: 'touchdown',
  },
  {
    id: 'seco',
    t: PACE.SECO,
    stage: 'SECO',
    banner: 'SECO',
    kind: 'go',
    radio: 'SECO. Upper stage shutdown. Insertion complete.',
    juice: 'seco',
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
  ignition: 'TERMINAL COUNT',
  liftoff: 'TERMINAL COUNT',
  maxq: 'MAX-Q',
  meco: 'MECO',
  sep: 'STAGE SEP',
  ses1: 'STAGE SEP',
  fairing: 'FAIRING',
  entry: 'HAVEN',
  landing: 'HAVEN',
  touchdown: 'HAVEN',
  seco: 'HAVEN',
  deploy: 'HAVEN',
};

export function phaseChip(beatId) {
  return PHASE_CHIP[beatId] || 'TERMINAL COUNT';
}
