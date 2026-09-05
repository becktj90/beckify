/**
 * Arcade-compressed New Glenn sequence of events.
 * Spine is an NG-2-class Spaceflight Now / NSF commentary board:
 * Terminal Count → Tank Press → Internal Power → Water Deluge → Ignition →
 * Liftoff → Max-Q → MECO → Stage Sep → SES-1 → Fairing Jettison →
 * Entry Burn → Landing Burn → Jacklyn Touchdown (~T+9 compressed) →
 * SECO → payload deploy.
 *
 * Real NG-2 times are hours and minutes. Here T-8s … T+58s so a stranger
 * hears every callout in one run. Per-mission copy swaps {id}/{payload}/{mark}.
 */
export const T0_LEAD = 8;

/** Compressed MET seconds. Negative = count. */
export const SPINE = [
  {
    id: 'terminal',
    t: -8,
    stage: 'TERMINAL COUNT',
    banner: 'TERMINAL COUNT',
    kind: 'info',
    radio: 'LC-36 terminal count. {id} on the pad. Range is green.',
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
    radio: 'Ignition. Seven BE-4s at startup.',
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
    t: 11.2,
    stage: 'MAX-Q',
    banner: 'MAX-Q',
    kind: 'warn',
    radio: 'Max-Q. Vehicle through the region of maximum dynamic pressure.',
    juice: 'maxq',
  },
  {
    id: 'meco',
    t: 24,
    stage: 'MECO',
    banner: 'MECO',
    kind: 'go',
    radio: 'MECO. First-stage BE-4s shutdown. Booster heading home.',
    juice: 'meco',
  },
  {
    id: 'sep',
    t: 25.1,
    stage: 'STAGE SEP',
    banner: 'STAGE SEP',
    kind: 'go',
    radio: 'Stage sep confirmed. Booster pitching downrange.',
    juice: 'sep',
  },
  {
    id: 'ses1',
    t: 26.4,
    stage: 'SES-1',
    banner: 'SES-1',
    kind: 'info',
    radio: 'SES-1. Upper-stage BE-3U is lit. {payload} still coasting under the fairing.',
    juice: 'ses',
  },
  {
    id: 'fairing',
    t: 29.4,
    stage: 'FAIRING JETTISON',
    banner: 'FAIRING JETTISON',
    kind: 'info',
    radio: 'Fairing jettison. {mark} — {payload} is free of the stack.',
    juice: 'fairing',
  },
  {
    id: 'entry',
    t: 36.5,
    stage: 'ENTRY BURN',
    banner: 'ENTRY BURN',
    kind: 'warn',
    radio: 'Entry burn. Jacklyn is downrange. Slide in diagonal.',
    juice: 'entry',
  },
  {
    id: 'landing',
    t: 45.2,
    stage: 'LANDING BURN',
    banner: 'LANDING BURN',
    kind: 'warn',
    radio: 'Landing burn. Brake for the painted deck.',
    juice: 'landing',
  },
  {
    id: 'touchdown',
    t: 51.5,
    stage: 'JACKLYN',
    banner: 'JACKLYN TOUCHDOWN',
    kind: 'go',
    radio: 'Touchdown. BOOSTER RECOVERED. Sea state nominal.',
    juice: 'touchdown',
  },
  {
    id: 'seco',
    t: 54.2,
    stage: 'SECO',
    banner: 'SECO',
    kind: 'go',
    radio: 'SECO. Upper stage shutdown. Insertion complete.',
    juice: 'seco',
  },
  {
    id: 'deploy',
    t: 57.4,
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
