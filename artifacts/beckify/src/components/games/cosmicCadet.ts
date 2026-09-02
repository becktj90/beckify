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
export const HIT_IFRAMES = 1.1;
export const POWER_DURATION = { guard: 6, track: 7, burst: 7 } as const;

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
  if (random() > (gold ? 0.62 : 0.22)) return null;
  const roll = random();
  if (roll < 0.28) return "heart";
  if (roll < 0.52) return "guard";
  if (roll < 0.76) return "burst";
  return "track";
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
  const storedBest = Number(storage.getItem(BEST_KEY) || 0);
  const best = Number.isFinite(storedBest) && storedBest >= 0 ? storedBest : 0;
  let board = parseBoard(storage.getItem(BOARD_KEY));
  if (board.length === 0 && best > 0) board = [{ score: best, wave: 1, at: 0 }];
  return { best: Math.max(best, board[0]?.score ?? 0), board };
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
