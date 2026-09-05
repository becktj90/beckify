/**
 * Flight designations. Each NG-n is a different launch with a different payload.
 *
 * Difficulty scheme (documented for the PR):
 *   KID / CADET / PAD RAT is the skill slider *inside* a mission.
 *   NG-n only changes payload, fairing mark, Jacklyn flavor, and a light spawn nudge.
 *   Completing Jacklyn (soft, salvage, or splash — not RUD) unlocks the next NG-n.
 */
export const MISSIONS = [
  {
    id: 'NG-1',
    payload: 'Blue Ring Pathfinder',
    mark: 'BRP',
    accent: '#3ec6ff',
    blurb: 'Demo stack. Prove the corridor.',
    spawnMul: 1,
    hazards: ['bird', 'bird', 'balloon'],
    lzOffset: -70,
    seaTint: 0xffffff,
    objective: { id: 'shield', label: 'Grab an aero shield' },
    jacklyn: {
      recovered: 'On Jacklyn — history rewritten.',
      salvage: 'Hard catch. Pathfinder still uphill.',
      splash: 'Splash. Jacklyn waits for the next flight.',
    },
  },
  {
    id: 'NG-2',
    payload: 'ESCAPADE Pair',
    mark: 'ESC',
    accent: '#ff7a3c',
    blurb: 'Twin Mars probes. Land the booster.',
    spawnMul: 1.08,
    hazards: ['balloon', 'ice', 'bird'],
    lzOffset: 0,
    seaTint: 0xe8f4ff,
    objective: { id: 'recover', label: 'Soft catch on Jacklyn' },
    jacklyn: {
      recovered: 'BOOSTER RECOVERED — reuse is real.',
      salvage: 'On deck, hard. Probes still go.',
      splash: 'Splash. Probes are fine; the barge is not.',
    },
  },
  {
    id: 'NG-3',
    payload: 'BlueBird Block 1',
    mark: 'BB1',
    accent: '#ffcf5d',
    blurb: 'Commercial sat. Corridor gets busy.',
    spawnMul: 1.16,
    hazards: ['ice', 'balloon', 'debris'],
    lzOffset: 80,
    seaTint: 0xffe8d0,
    objective: { id: 'combo4', label: 'Hold a ×4 combo' },
    jacklyn: {
      recovered: 'Recovered. BlueBird is on its way.',
      salvage: 'Salvage. Sat deployed, barge scuffed.',
      splash: 'Splash. Customer sat still coasts.',
    },
  },
  {
    id: 'NG-4',
    payload: 'Lightspeed Ka',
    mark: 'LSK',
    accent: '#b7abff',
    blurb: 'Ka-band bird. Tight TVC.',
    spawnMul: 1.24,
    hazards: ['debris', 'ice', 'ice'],
    lzOffset: -40,
    seaTint: 0xd8d0ff,
    objective: { id: 'clean', label: 'No structural hits' },
    jacklyn: {
      recovered: 'On Jacklyn. Ka-band is live.',
      salvage: 'Hard catch. Lightspeed still talks.',
      splash: 'Splash. Payload does not care.',
    },
  },
  {
    id: 'NG-5',
    payload: 'Blue Ring Tug',
    mark: 'BRT',
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
