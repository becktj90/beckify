/**
 * Game Center leaderboards — one per KH-n flight.
 *
 * The web arcade only posts to the native bridge when it runs inside the
 * Kestrel Heavy iOS app (WKWebView message handler `kestrelGameCenter`).
 * Everywhere else (browser, offline, no Game Center) this is a silent no-op.
 * Native side: ios/KestrelHeavy/KestrelHeavyGameView.swift (GameKit).
 */
export const LEADERBOARD_PREFIX = 'com.beckify.kestrelheavy.lb.';

export function leaderboardIdFor(missionId) {
  const m = String(missionId || '').match(/^KH-(\d+)$/i);
  return m ? `${LEADERBOARD_PREFIX}kh${m[1]}` : null;
}

export function leaderboardIds(missions) {
  return missions.map((m) => leaderboardIdFor(m.id || m)).filter(Boolean);
}

function bridge(win) {
  const w = win || (typeof window !== 'undefined' ? window : null);
  return w?.webkit?.messageHandlers?.kestrelGameCenter || null;
}

/** Returns true if a message was handed to the native bridge. */
export function submitFlightScore(missionId, points, win) {
  const id = leaderboardIdFor(missionId);
  const score = Math.max(0, Math.floor(Number(points) || 0));
  const b = bridge(win);
  if (!id || !b || score <= 0) return false;
  try {
    b.postMessage({ type: 'score', leaderboard: id, score });
    return true;
  } catch {
    return false;
  }
}

/** Ask native to open the Game Center leaderboard sheet (no-op on web). */
export function showLeaderboard(missionId, win) {
  const b = bridge(win);
  if (!b) return false;
  try {
    b.postMessage({ type: 'show', leaderboard: leaderboardIdFor(missionId) });
    return true;
  } catch {
    return false;
  }
}

export function hasGameCenter(win) {
  return Boolean(bridge(win));
}
