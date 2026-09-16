/**
 * Hangar loadout — modular stack with a large combinatorial space.
 * Unlocks come from flying KH-n, scores, and pickups. No IAP, no ads.
 */

export const LOADOUT_CATS = ['nose', 'body', 'strakes', 'engines', 'paint', 'accent'];

export const PARTS = {
  nose: [
    { id: 'ogive-gold', name: 'Ogive gold', blurb: 'Classic gold tip.' },
    { id: 'blunt-gold', name: 'Blunt gold', blurb: 'Shorter gold ogive.' },
    { id: 'white-needle', name: 'White needle', blurb: 'Pale needle fairing.' },
    { id: 'black-ogive', name: 'Night ogive', blurb: 'Dark fairing, gold lip.' },
    { id: 'twin-mark', name: 'Twin mark', blurb: 'Split chevron fairing.' },
  ],
  body: [
    { id: 'classic', name: 'Classic', blurb: 'Tall white cylinder.' },
    { id: 'stripe', name: 'Race stripe', blurb: 'Single dark stripe.' },
    { id: 'chevron', name: 'Heavy chevron', blurb: 'Bigger stack mark.' },
    { id: 'ringed', name: 'Ringed', blurb: 'Interstage rings.' },
    { id: 'cargo', name: 'Cargo band', blurb: 'Dark payload band.' },
    { id: 'long-window', name: 'Long window', blurb: 'Sensor windows.' },
  ],
  strakes: [
    { id: 'black', name: 'Black strakes', blurb: 'Solid black lineage.' },
    { id: 'wide', name: 'Wide strakes', blurb: 'More span, still solid.' },
    { id: 'aft', name: 'Aft only', blurb: 'Lower pair only.' },
    { id: 'gold-edge', name: 'Gold edge', blurb: 'Black with gold lip.' },
    { id: 'stub', name: 'Stub strakes', blurb: 'Short solid plates.' },
  ],
  engines: [
    { id: 'seven', name: 'Seven core', blurb: 'Seven methane bells.' },
    { id: 'clustered', name: 'Cluster', blurb: 'Tight seven pack.' },
    { id: 'bell-wide', name: 'Wide bells', blurb: 'Fat nozzles.' },
    { id: 'dual', name: 'Dual outboard', blurb: 'Two large + five.' },
    { id: 'slim', name: 'Slim seven', blurb: 'Nine slim bells.' },
  ],
  paint: [
    { id: 'white', name: 'Pier white', blurb: 'White-ish stack.' },
    { id: 'dawn', name: 'Dawn blush', blurb: 'Warm pad white.' },
    { id: 'ember', name: 'Ember', blurb: 'Heat-stained white.' },
    { id: 'harbor', name: 'Harbor', blurb: 'Cool coastal white.' },
    { id: 'night', name: 'Nightglass', blurb: 'Slate white.' },
    { id: 'lumen', name: 'Lumen', blurb: 'Mint-white stack.' },
    { id: 'storm', name: 'Storm', blurb: 'Gray weather white.' },
    { id: 'pier', name: 'Pier sand', blurb: 'Warm sand white.' },
  ],
  accent: [
    { id: 'gold', name: 'Gold', blurb: 'Gold tip accents.' },
    { id: 'cyan', name: 'Cyan', blurb: 'Aero-cyan trim.' },
    { id: 'ember', name: 'Ember', blurb: 'Heat-orange trim.' },
    { id: 'violet', name: 'Violet', blurb: 'Nightglass trim.' },
    { id: 'copper', name: 'Copper', blurb: 'Copper interstage.' },
    { id: 'lime', name: 'Lime', blurb: 'Range-lime trim.' },
  ],
};

export const DEFAULT_LOADOUT = {
  nose: 'ogive-gold',
  body: 'classic',
  strakes: 'black',
  engines: 'seven',
  paint: 'white',
  accent: 'gold',
};

export const STARTER_UNLOCKS = {
  nose: ['ogive-gold'],
  body: ['classic'],
  strakes: ['black'],
  engines: ['seven'],
  paint: ['white'],
  accent: ['gold'],
};

export const PAINT = {
  white: { hi: '#f7fbff', mid: '#e8eef4', lo: '#8e979e' },
  dawn: { hi: '#fff4ea', mid: '#f0d8c8', lo: '#9a7868' },
  ember: { hi: '#fff0e6', mid: '#e8c4a8', lo: '#8a5040' },
  harbor: { hi: '#eef6ff', mid: '#c8dce8', lo: '#5a7888' },
  night: { hi: '#d8dce8', mid: '#8a90a8', lo: '#3a4058' },
  lumen: { hi: '#f0fff6', mid: '#c8ead8', lo: '#4a7860' },
  storm: { hi: '#e8ecf4', mid: '#a8b0c0', lo: '#4a5260' },
  pier: { hi: '#fff8ee', mid: '#e8d8c0', lo: '#7a6a50' },
};

export const ACCENT = {
  gold: '#c48a2a',
  cyan: '#3ec6ff',
  ember: '#ff7a3c',
  violet: '#b7abff',
  copper: '#c46a28',
  lime: '#7dffb0',
};

export const PICKUP_UNLOCKS = {
  shield: { cat: 'accent', id: 'cyan' },
  boost: { cat: 'engines', id: 'clustered' },
  fuel: { cat: 'body', id: 'stripe' },
};

export function comboCount(catalog = PARTS) {
  return LOADOUT_CATS.reduce((n, cat) => n * (catalog[cat]?.length || 1), 1);
}

export function partById(cat, id) {
  return (PARTS[cat] || []).find((p) => p.id === id) || PARTS[cat]?.[0] || null;
}

export function emptyUnlocks() {
  const next = {};
  for (const cat of LOADOUT_CATS) next[cat] = [...(STARTER_UNLOCKS[cat] || [])];
  return next;
}

function addUnlock(map, cat, id) {
  if (!map[cat]) map[cat] = [];
  if (!map[cat].includes(id)) map[cat].push(id);
  return map;
}

export function isPartUnlocked(unlocks, cat, id) {
  const list = unlocks?.[cat] || STARTER_UNLOCKS[cat] || [];
  return list.includes(id);
}

export function clampLoadout(raw, unlocks) {
  const next = { ...DEFAULT_LOADOUT, ...(raw && typeof raw === 'object' ? raw : {}) };
  for (const cat of LOADOUT_CATS) {
    const id = next[cat];
    const known = (PARTS[cat] || []).some((p) => p.id === id);
    if (!known || !isPartUnlocked(unlocks, cat, id)) next[cat] = DEFAULT_LOADOUT[cat];
  }
  return next;
}

/** Unlock ladder from missions flown, recoveries, and high score. */
export function evaluateUnlocks(settings) {
  const unlocked = emptyUnlocks();
  const missions = settings?.unlockedMissions || ['KH-1'];
  const bests = settings?.missionBests || {};
  const hi = Number(settings?.hiArcadeScore) || 0;
  const grant = (cat, id) => addUnlock(unlocked, cat, id);

  if (missions.includes('KH-2')) {
    grant('nose', 'blunt-gold');
    grant('body', 'stripe');
    grant('paint', 'dawn');
  }
  if (missions.includes('KH-3')) {
    grant('nose', 'white-needle');
    grant('strakes', 'wide');
    grant('paint', 'ember');
    grant('accent', 'ember');
  }
  if (missions.includes('KH-4')) {
    grant('nose', 'black-ogive');
    grant('body', 'ringed');
    grant('engines', 'clustered');
    grant('paint', 'harbor');
    grant('accent', 'cyan');
  }
  if (missions.includes('KH-5')) {
    grant('nose', 'twin-mark');
    grant('body', 'cargo');
    grant('strakes', 'gold-edge');
    grant('paint', 'night');
    grant('accent', 'violet');
  }
  if (bests['KH-2']?.recovered) {
    grant('engines', 'bell-wide');
    grant('body', 'chevron');
  }
  if (bests['KH-3']?.recovered) {
    grant('strakes', 'aft');
    grant('paint', 'storm');
  }
  if (bests['KH-4']?.recovered) {
    grant('engines', 'dual');
    grant('paint', 'pier');
  }
  if (bests['KH-5']?.recovered) {
    grant('paint', 'lumen');
    grant('strakes', 'stub');
    grant('engines', 'slim');
    grant('body', 'long-window');
    grant('accent', 'copper');
    grant('accent', 'lime');
  }
  if (hi >= 4000) grant('accent', 'cyan');
  if (hi >= 8000) grant('body', 'chevron');
  if (hi >= 12000) grant('paint', 'storm');
  if (hi >= 18000) grant('engines', 'slim');

  const extra = settings?.unlockedParts;
  if (extra && typeof extra === 'object') {
    for (const cat of LOADOUT_CATS) {
      for (const id of extra[cat] || []) grant(cat, id);
    }
  }
  return unlocked;
}

export function grantPickupUnlock(settings, kind) {
  const spec = PICKUP_UNLOCKS[kind];
  if (!spec) return null;
  const unlocks = evaluateUnlocks(settings);
  if (isPartUnlocked(unlocks, spec.cat, spec.id)) return null;
  if (!settings.unlockedParts) settings.unlockedParts = emptyUnlocks();
  addUnlock(settings.unlockedParts, spec.cat, spec.id);
  return spec;
}

export function mergeUnlocks(settings) {
  settings.unlockedParts = evaluateUnlocks(settings);
  settings.loadout = clampLoadout(settings.loadout, settings.unlockedParts);
  return settings;
}

export function paintSpec(id) {
  return PAINT[id] || PAINT.white;
}

export function accentColor(id) {
  return ACCENT[id] || ACCENT.gold;
}
