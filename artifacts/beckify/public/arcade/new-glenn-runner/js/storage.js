/**
 * Settings + personal-best persistence.
 *
 * Storage key history (document bumps here when the schema changes):
 *   newGlennRunnerSettingsV2  — early canvas settings blob
 *   newGlennRunnerStateV3     — canvas Jacklyn / feel-pass scores
 *   newGlennRunnerStateV4     — Phaser 4 runner (this file)
 *
 * V4 copies scores and prefs from V3/V2 on first load, then writes V4 only.
 * Old keys are left in place so a player can still open a canvas bookmark.
 */
import { DEFAULT_SETTINGS, LEGACY_KEYS, STORAGE_KEY } from './config.js';

function parse(raw) {
  if (!raw) return null;
  try {
    const data = JSON.parse(raw);
    return data && typeof data === 'object' ? data : null;
  } catch {
    return null;
  }
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
  return next;
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
  return { ...DEFAULT_SETTINGS };
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
  saveSettings(settings);
  return settings;
}
