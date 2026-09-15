/**
 * Kestrel Heavy — Phaser 4.2.1 + built-in Matter (pad → ascent → Haven).
 * Arcade-tuned constants. Real orbital telemetry is compressed, not simulated.
 * Matter forces are 0.01–0.1; velocities are ~1–15 per step, not pixels/sec.
 */
export const W = 1280;
export const H = 720;

/** Pad stack sits on the launch table, left of the ILT (photo match). */
export const PAD_ROCKET_X = 508;
export const PAD_ROCKET_Y = 418;

/** Current settings + scores. Bumped for SFX/music splits + control hints. */
export const STORAGE_KEY = 'newGlennRunnerStateV6';
/** Prior keys — high scores and prefs are copied forward once. */
export const LEGACY_KEYS = [
  'newGlennRunnerStateV5',
  'newGlennRunnerStateV4',
  'newGlennRunnerStateV3',
  'newGlennRunnerSettingsV2',
];

export const DIFFICULTY = {
  KID: {
    spawnMul: 0.28,
    hitboxScale: 0.4,
    graceSec: 5.2,
    landingTol: 56,
    landingVy: 7.1,
    allowFail: false,
    pickupMul: 1.5,
    fuelDrain: 0.032,
    assist: 0.62,
    thrust: 1.08,
    wind: 0.14,
    sepAlignDeg: 14,
    sepAlignVx: 1.65,
    sepWindow: 7.4,
  },
  CADET: {
    spawnMul: 0.72,
    hitboxScale: 0.52,
    graceSec: 2.4,
    landingTol: 36,
    landingVy: 6.2,
    allowFail: true,
    pickupMul: 1,
    fuelDrain: 0.058,
    assist: 0.52,
    thrust: 1,
    wind: 0.32,
    sepAlignDeg: 8,
    sepAlignVx: 1.1,
    sepWindow: 5.8,
  },
  PAD_RAT: {
    spawnMul: 1.05,
    hitboxScale: 0.66,
    graceSec: 1.05,
    landingTol: 18,
    landingVy: 3.1,
    allowFail: true,
    pickupMul: 0.64,
    fuelDrain: 0.084,
    assist: 0,
    thrust: 0.96,
    wind: 0.52,
    sepAlignDeg: 5,
    sepAlignVx: 0.72,
    sepWindow: 4.2,
  },
};

/** Compressed MET spine. A clean run is ~T+100, not a 50s sprint. */
export const PACE = {
  MAXQ: 18.6,
  MECO: 38.4,
  SEP: 40.2,
  SES1: 51.8,
  FAIRING: 55.6,
  ENTRY: 64.0,
  LANDING: 84.8,
  TOUCHDOWN: 96.5,
  SECO: 99.8,
  DEPLOY: 103.6,
};

/** MECO → stage sep is a playable beat, not a 400ms cutscene. */
export const SEP = {
  coastSec: 3.4,
  clearSec: 6.4,
  alignHold: 0.55,
  widePenalty: 400,
  contactPenalty: 650,
};

/** Zoomed-out Haven approach — barge reads small; closing speed stays slow. */
export const HAVEN = {
  startY: -340,
  startLat: 820,
  bargeY: 690,
  zoomFar: 0.34,
  zoomNear: 0.46,
  gravity: 0.155,
  frictionAir: 0.058,
  maxVyEarly: 1.85,
  maxVy: 4.2,
  earlySec: 5.2,
  landingFuel: 24,
  swellAmp: 14,
};

/** Dotted rails are the climb corridor. Stay between them or the stack aborts. */
export const CORRIDOR_TEACH_SEC = 5.4;

/** Wider default framing so the corridor, sep stack, and Haven read as space. */
export const CAM = {
  ascentStart: 0.56,
  ascentHigh: 0.50,
  sep: 0.48,
  reduced: 0.58,
  recovered: 0.82,
  deadzoneX: 96,
  deadzoneY: 72,
};

export const BOOST_COYOTE_SEC = 0.14;
export const BOOST_BUFFER_SEC = 0.18;
export const SHIELD_MAX = 2;
export const FUEL_MAX = 100;
export const OVERDRIVE_SEC = 4.2;
export const ASCENT_TARGET_KM = 42;
export const JACKLYN_BONUS = 2800;
export const JACKLYN_SALVAGE = 650;
export const SPLASH_PENALTY = 1200;
export const TIP_PENALTY = 450;
export const PICKUP_TYPES = ['shield', 'fuel', 'boost'];

export const TIPS = [
  'Kestrel Heavy is 7 m wide. Yes, that wide.',
  'Core engines burn liquid methane and LOX.',
  'KH-2 landed the booster on Haven.',
  'Heavy lift. Soft catch.',
  'Pier 7 is a coastal launch complex — scrub, wind, and ocean.',
  'The service tower carries fully enclosed work platforms.',
  'Haven is the landing barge. Soft deck = BOOSTER RECOVERED.',
  'Seven core engines on first stage. Hold the corridor.',
];

export const RADIO = {
  PAD: 'Pier 7 standing by. Terminal count is armed.',
  LIFTOFF: 'Liftoff. Kestrel Heavy clearing the tower.',
  ASCENT: 'Vehicle flying nominally. Steer the corridor.',
  MAXQ: 'Max-Q. Hold the line.',
  MECO: 'MECO. Hold attitude. Sep window is coming.',
  SEP: 'Stage sep. Steer ALIGN green, then tap climb to fire.',
  SEP_CLEAR: 'Booster clear. Keep the relative motion wide of the stack.',
  JACKLYN: 'Haven downrange. Long slide-in. Brake the painted deck.',
  RECOVERED: 'Landed on Haven. Sea state nominal. Coffee earned.',
  SPLASH: 'Splash. Combo reset — upper stage still flies.',
  SALVAGE: 'Hard catch. Booster on deck, score clipped.',
  TIP: 'Tip on deck. Gold ring kissed steel — score clipped.',
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
  sfxVolume: 1,
  musicVolume: 0.85,
  controlHints: true,
  launchTipSeen: false,
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
  currentMission: 'KH-1',
  unlockedMissions: ['KH-1'],
  missionBests: {},
};
