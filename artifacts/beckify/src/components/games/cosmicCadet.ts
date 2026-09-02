export type GameStatus = "ready" | "playing" | "paused" | "gameover";
export type PowerUpKind = "guard" | "track" | "burst" | "heart";
export type BoardEntry = { score: number; wave: number; at: number };
export type HudSnapshot = { score: number; wave: number; hull: number };

export const PLAYFIELD = { width: 540, height: 760 };
export const BEST_KEY = "cosmic-cadet-best";
export const BOARD_KEY = "cosmic-cadet-board";
export const BOARD_SIZE = 5;
export const MAX_HULL = 5;
export const KILLS_PER_WAVE = 8;
export const HIT_IFRAMES = 1.75;
export const START_GUARD = 3.2;
export const SHIP_HIT_RADIUS = 28;
export const ENEMY_BOLT_RADIUS = 34;
export const PICKUP_RADIUS = 58;
export const LEAK_MARGIN = 40;
export const POWER_DURATION = { guard: 7, track: 8, burst: 8 } as const;

type StorageLike = { getItem(key: string): string | null; setItem(key: string, value: string): void };

export const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));

export function scoreForEnemy(gold: boolean) {
  return gold ? 250 : 100;
}

export function waveFromKills(kills: number) {
  return 1 + Math.floor(Math.max(0, kills) / KILLS_PER_WAVE);
}

export function applyKill(state: { points: number; kills: number }, gold: boolean) {
  const points = state.points + scoreForEnemy(gold);
  const kills = state.kills + 1;
  return { points, kills, wave: waveFromKills(kills) };
}

export function togglePause(status: GameStatus): GameStatus {
  if (status === "playing") return "paused";
  if (status === "paused") return "playing";
  return status;
}

export function playIntent(status: GameStatus): "start" | "resume" | "ignore" {
  if (status === "paused") return "resume";
  if (status === "ready" || status === "gameover") return "start";
  return "ignore";
}

export function fireInterval(rapid: boolean) {
  return rapid ? 0.07 : 0.16;
}

export function applyHeart(hull: number) {
  return Math.min(MAX_HULL, hull + 1);
}

export function pickPowerUp(gold: boolean, random: () => number): PowerUpKind | null {
  if (random() > (gold ? 0.74 : 0.36)) return null;
  const roll = random();
  if (roll < 0.32) return "heart";
  if (roll < 0.56) return "guard";
  if (roll < 0.78) return "burst";
  return "track";
}

export function spawnInterval(wave: number) {
  return Math.max(0.78, 1.48 - Math.max(0, wave - 1) * 0.028);
}

export function enemyFallSpeed(wave: number) {
  return 0.72 + Math.min(Math.max(1, wave), 12) * 0.048;
}

export function enemyHp(wave: number, random: () => number) {
  return wave >= 4 && random() > 0.82 ? 2 : 1;
}

export function enemyLeaked(y: number, fieldHeight = PLAYFIELD.height, margin = LEAK_MARGIN) {
  return y > fieldHeight + margin;
}

export function shipHitsEnemy(shipX: number, shipY: number, enemyX: number, enemyY: number, radius = SHIP_HIT_RADIUS) {
  return Math.hypot(enemyX - shipX, enemyY - shipY) < radius;
}

export function hudChanged(previous: HudSnapshot, next: HudSnapshot) {
  return previous.score !== next.score || previous.wave !== next.wave || previous.hull !== next.hull;
}

function parseBoard(raw: string | null): BoardEntry[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map((entry) => ({
        score: Number((entry as BoardEntry)?.score),
        wave: Number((entry as BoardEntry)?.wave) || 1,
        at: Number((entry as BoardEntry)?.at) || 0,
      }))
      .filter((entry) => Number.isFinite(entry.score) && entry.score >= 0)
      .sort((a, b) => b.score - a.score || b.at - a.at)
      .slice(0, BOARD_SIZE);
  } catch {
    return [];
  }
}

export function loadScores(storage: StorageLike): { best: number; board: BoardEntry[] } {
  try {
    const storedBest = Number(storage.getItem(BEST_KEY) || 0);
    const best = Number.isFinite(storedBest) && storedBest >= 0 ? storedBest : 0;
    let board = parseBoard(storage.getItem(BOARD_KEY));
    if (board.length === 0 && best > 0) board = [{ score: best, wave: 1, at: 0 }];
    return { best: Math.max(best, board[0]?.score ?? 0), board };
  } catch {
    return { best: 0, board: [] };
  }
}

export function recordRun(storage: StorageLike, score: number, wave: number, at = Date.now()) {
  const current = loadScores(storage);
  const board = [...current.board, { score, wave, at }]
    .sort((a, b) => b.score - a.score || b.at - a.at)
    .slice(0, BOARD_SIZE);
  const best = Math.max(current.best, score);
  try {
    storage.setItem(BEST_KEY, String(best));
    storage.setItem(BOARD_KEY, JSON.stringify(board));
  } catch {
    /* Local scores are optional. */
  }
  return { best, board };
}
