/**
 * New Glenn Runner — Phaser 4.2.1 + built-in Matter (pad → ascent → Jacklyn).
 * Arcade-tuned constants. Real NG telemetry is compressed, not simulated.
 * Matter forces are 0.01–0.1; velocities are ~1–15 per step, not pixels/sec.
 */
export const W = 1280;
export const H = 720;

/** Current settings + scores. Bumped for NG-n mission unlocks + per-flight bests. */
export const STORAGE_KEY = 'newGlennRunnerStateV5';
/** Prior keys — high scores and prefs are copied forward once. */
export const LEGACY_KEYS = [
  'newGlennRunnerStateV4',
  'newGlennRunnerStateV3',
  'newGlennRunnerSettingsV2',
];

export const DIFFICULTY = {
  KID: {
    spawnMul: 0.32,
    hitboxScale: 0.42,
    graceSec: 4.2,
    landingTol: 52,
    landingVy: 5.8,
    allowFail: false,
    pickupMul: 1.4,
    fuelDrain: 0.045,
    assist: 0.55,
  },
  CADET: {
    spawnMul: 0.7,
    hitboxScale: 0.54,
    graceSec: 2.1,
    landingTol: 88,
    landingVy: 6.4,
    allowFail: true,
    pickupMul: 1,
    fuelDrain: 0.07,
    assist: 0.4,
  },
  PAD_RAT: {
    spawnMul: 1,
    hitboxScale: 0.68,
    graceSec: 1.05,
    landingTol: 20,
    landingVy: 3.2,
    allowFail: true,
    pickupMul: 0.68,
    fuelDrain: 0.095,
    assist: 0,
  },
};

export const BOOST_COYOTE_SEC = 0.14;
export const BOOST_BUFFER_SEC = 0.18;
export const SHIELD_MAX = 2;
export const FUEL_MAX = 100;
export const OVERDRIVE_SEC = 4.2;
export const ASCENT_TARGET_KM = 42;
export const JACKLYN_BONUS = 2500;
export const JACKLYN_SALVAGE = 900;
export const SPLASH_PENALTY = 800;
export const PICKUP_TYPES = ['shield', 'fuel', 'boost'];

export const TIPS = [
  'New Glenn is 7 m wide. Yes, that wide.',
  'BE-4 burns liquid methane and LOX.',
  'NG-2 landed the booster on Jacklyn.',
  'Gradatim ferociter — step by step, ferociously.',
  'LC-36 is the first newly built orbital pad since the 1960s.',
  'The Integrated Launch Tower carries fully enclosed service platforms.',
  'Jacklyn is the landing barge. Soft deck = BOOSTER RECOVERED.',
  'BE-4 sea-level thrust: 640,000 lbf. Seven of them on first stage.',
];

export const RADIO = {
  PAD: 'Pad systems nominal. Hold boost to charge.',
  LIFTOFF: 'You are go for launch.',
  ASCENT: 'Vehicle flying nominally. Steer the corridor.',
  MAXQ: 'Max-Q. Hold the line.',
  MECO: 'MECO. Booster heading home.',
  JACKLYN: 'Jacklyn in sight. Brake for the painted deck.',
  RECOVERED: 'Landed on Jacklyn. Sea state nominal. Coffee earned.',
  SPLASH: 'Splash. Combo reset — mission continues.',
  SALVAGE: 'Hard catch. Booster on deck, score clipped.',
  RUD: 'RUD. Range safe. Read the fail banner, then retry.',
};

export const DEFAULT_SETTINGS = {
  sound: true,
  music: true,
  reducedMotion: typeof window !== 'undefined'
    && window.matchMedia
    && window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  reducedFlashes: false,
  haptics: true,
  muted: false,
  volume: 0.72,
  difficulty: 'CADET',
  engineerPanel: false,
  hiScore: 0,
  hiArcadeScore: 0,
  lastArcadeScore: 0,
  leaderboard: [],
  missionCount: 0,
  bestFlight: null,
  achievements: [],
  patches: [],
  engine: 'phaser4',
  currentMission: 'NG-1',
  unlockedMissions: ['NG-1'],
  missionBests: {},
};
