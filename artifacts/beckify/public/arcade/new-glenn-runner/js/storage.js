/**
 * Settings + personal-best persistence.
 *
 * Storage key history (document bumps here when the schema changes):
 *   newGlennRunnerSettingsV2  — early canvas settings blob
 *   newGlennRunnerStateV3     — canvas Jacklyn / feel-pass scores
 *   newGlennRunnerStateV4     — Phaser 4 vertical slice
 *   newGlennRunnerStateV5     — NG-n missions, payload unlocks, per-flight bests
 *
 * V5 copies scores and prefs from V4/V3/V2 on first load, then writes V5 only.
 * Old keys are left in place so a player can still open a canvas bookmark.
 */
import { DEFAULT_SETTINGS, LEGACY_KEYS, STORAGE_KEY } from './config.js';
import { FIRST_MISSION, MISSIONS, getMission } from './missions.js';

function parse(raw) {
  if (!raw) return null;
  try {
    const data = JSON.parse(raw);
    return data && typeof data === 'object' ? data : null;
  } catch {
    return null;
  }
}

function normalizeMissions(next) {
  const known = new Set(MISSIONS.map((m) => m.id));
  let unlocked = Array.isArray(next.unlockedMissions)
    ? next.unlockedMissions.filter((id) => known.has(id))
    : [];
  if (!unlocked.includes(FIRST_MISSION)) unlocked = [FIRST_MISSION, ...unlocked];
  next.unlockedMissions = [...new Set(unlocked)];
  if (!known.has(next.currentMission)) next.currentMission = FIRST_MISSION;
  if (!next.unlockedMissions.includes(next.currentMission)) {
    next.currentMission = FIRST_MISSION;
  }
  const bests = next.missionBests && typeof next.missionBests === 'object'
    ? next.missionBests
    : {};
  next.missionBests = {};
  for (const id of known) {
    const row = bests[id] || {};
    next.missionBests[id] = {
      score: Number(row.score) || 0,
      recovered: Boolean(row.recovered),
    };
  }
  return next;
}

function normalize(merged) {
  const next = { ...DEFAULT_SETTINGS, ...merged };
  if (next.difficulty === 'ENGINEER') next.difficulty = 'PAD_RAT';
  if (!['KID', 'CADET', 'PAD_RAT'].includes(next.difficulty)) next.difficulty = 'CADET';
  next.hiArcadeScore = Number(next.hiArcadeScore) || 0;
  next.lastArcadeScore = Number(next.lastArcadeScore) || 0;
  next.hiScore = Number(next.hiScore) || 0;
  next.missionCount = Number(next.missionCount) || 0;
  next.engine = 'phaser4';
  const volume = Number(next.volume);
  next.volume = Number.isFinite(volume) ? Math.max(0, Math.min(1, volume)) : 0.72;
  return normalizeMissions(next);
}

export function loadSettings() {
  try {
    const current = parse(localStorage.getItem(STORAGE_KEY));
    if (current) return normalize(current);
    for (const key of LEGACY_KEYS) {
      const legacy = parse(localStorage.getItem(key));
      if (!legacy) continue;
      const migrated = normalize(legacy);
      saveSettings(migrated);
      return migrated;
    }
  } catch {
    /* private mode / blocked storage */
  }
  return { ...DEFAULT_SETTINGS, missionBests: { ...DEFAULT_SETTINGS.missionBests } };
}

export function saveSettings(settings) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
  } catch {
    /* ignore quota / private mode */
  }
}

export function resetRecord(settings) {
  settings.hiScore = 0;
  settings.hiArcadeScore = 0;
  settings.lastArcadeScore = 0;
  settings.bestFlight = null;
  settings.patches = [];
  settings.currentMission = FIRST_MISSION;
  settings.unlockedMissions = [FIRST_MISSION];
  settings.missionBests = {};
  for (const mission of MISSIONS) {
    settings.missionBests[mission.id] = { score: 0, recovered: false };
  }
  saveSettings(settings);
  return settings;
}

export function recordMissionResult(settings, missionId, points, recovered) {
  const mission = getMission(missionId);
  if (!settings.missionBests[mission.id]) {
    settings.missionBests[mission.id] = { score: 0, recovered: false };
  }
  const row = settings.missionBests[mission.id];
  if (points >= (row.score || 0)) row.score = points;
  if (recovered) row.recovered = true;
  return row;
}
