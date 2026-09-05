/**
 * Flight designations. Each KH-n is a different launch with a different payload.
 *
 * Difficulty scheme (documented for the PR):
 *   KID / CADET / PAD RAT is the skill slider *inside* a mission.
 *   KH-n only changes payload, fairing mark, Haven flavor, and a light spawn nudge.
 *   Completing Haven (soft, salvage, or splash — not RUD) unlocks the next KH-n.
 */
export const MISSIONS = [
  {
    id: 'KH-1',
    payload: 'Aether Scout',
    mark: 'AES',
    accent: '#3ec6ff',
    blurb: 'Demo stack. Prove the corridor.',
    spawnMul: 1,
    hazards: ['bird', 'bird', 'balloon'],
    lzOffset: -70,
    seaTint: 0xffffff,
    objective: { id: 'shield', label: 'Grab an aero shield' },
    jacklyn: {
      recovered: 'On Haven — first catch in the book.',
      salvage: 'Hard catch. Scout still uphill.',
      splash: 'Splash. Haven waits for the next flight.',
    },
  },
  {
    id: 'KH-2',
    payload: 'Ember Pair',
    mark: 'EMB',
    accent: '#ff7a3c',
    blurb: 'Twin weather-watch microsats. Land the booster.',
    spawnMul: 1.08,
    hazards: ['balloon', 'ice', 'bird'],
    lzOffset: 0,
    seaTint: 0xe8f4ff,
    objective: { id: 'recover', label: 'Soft catch on Haven' },
    jacklyn: {
      recovered: 'BOOSTER RECOVERED — reuse is real.',
      salvage: 'On deck, hard. Pair still go.',
      splash: 'Splash. Sats are fine; the barge is not.',
    },
  },
  {
    id: 'KH-3',
    payload: 'Harbor Eye',
    mark: 'HBE',
    accent: '#ffcf5d',
    blurb: 'Coastal imaging sat. Corridor gets busy.',
    spawnMul: 1.16,
    hazards: ['ice', 'balloon', 'debris'],
    lzOffset: 80,
    seaTint: 0xffe8d0,
    objective: { id: 'combo4', label: 'Hold a ×4 combo' },
    jacklyn: {
      recovered: 'Recovered. Harbor Eye is on its way.',
      salvage: 'Salvage. Sat deployed, barge scuffed.',
      splash: 'Splash. Customer sat still coasts.',
    },
  },
  {
    id: 'KH-4',
    payload: 'Nightglass',
    mark: 'NGL',
    accent: '#b7abff',
    blurb: 'Comms array. Tight TVC.',
    spawnMul: 1.24,
    hazards: ['debris', 'ice', 'ice'],
    lzOffset: -40,
    seaTint: 0xd8d0ff,
    objective: { id: 'clean', label: 'No structural hits' },
    jacklyn: {
      recovered: 'On Haven. Nightglass is live.',
      salvage: 'Hard catch. Nightglass still talks.',
      splash: 'Splash. Payload does not care.',
    },
  },
  {
    id: 'KH-5',
    payload: 'Lumen Tug',
    mark: 'LUT',
    accent: '#7dffb0',
    blurb: 'Tug + cargo. Long climb, same pad.',
    spawnMul: 1.32,
    hazards: ['debris', 'debris', 'ice', 'balloon'],
    lzOffset: 50,
    seaTint: 0xc8ffe0,
    objective: { id: 'recover-combo', label: 'Recover + ×3 combo' },
    jacklyn: {
      recovered: 'Recovered. Tug is on its own now.',
      salvage: 'Salvage. Tug separated anyway.',
      splash: 'Splash. Cadence still counts.',
    },
  },
];

export const FIRST_MISSION = MISSIONS[0].id;

export function getMission(id) {
  return MISSIONS.find((m) => m.id === id) || MISSIONS[0];
}

export function nextMissionId(id) {
  const i = MISSIONS.findIndex((m) => m.id === id);
  if (i < 0 || i >= MISSIONS.length - 1) return null;
  return MISSIONS[i + 1].id;
}

export function isUnlocked(settings, id) {
  const list = settings.unlockedMissions || [FIRST_MISSION];
  return list.includes(id);
}
