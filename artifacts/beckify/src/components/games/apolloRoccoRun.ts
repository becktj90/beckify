export type Lane = 0 | 1 | 2;
export type Rider = "apollo" | "rocco";
export type Difficulty = "kid" | "cadet";
export type Pose = "run" | "jump" | "slide";
export type HazardKind = "low" | "high";
export type GameStatus = "ready" | "running" | "paused" | "gameover";

export type Hazard = {
  id: number;
  lane: Lane;
  z: number;
  kind: HazardKind;
};

export type Treat = {
  id: number;
  lane: Lane;
  z: number;
  taken: boolean;
};

type StorageLike = { getItem(key: string): string | null; setItem(key: string, value: string): void };

export const LANE_COUNT = 3;
export const FAR_Z = 40;
export const PLAYER_Z = 1.35;
export const BEST_KEY = "apollo-rocco-run-best";

export const TUNING = {
  kid: {
    startSpeed: 6.2,
    maxSpeed: 11.5,
    accel: 0.18,
    minGap: 16,
    maxGap: 24,
    hits: 3,
    iframes: 2.2,
    jumpTime: 0.9,
    slideTime: 0.64,
    hitDepth: 1.7,
    maxBlockedLanes: 1,
  },
  cadet: {
    startSpeed: 9.2,
    maxSpeed: 19.5,
    accel: 0.52,
    minGap: 9,
    maxGap: 14.5,
    hits: 2,
    iframes: 0.85,
    jumpTime: 0.62,
    slideTime: 0.42,
    hitDepth: 1.05,
    maxBlockedLanes: 2,
  },
} as const;

export const RIDERS: Record<Rider, { label: string; accent: string; ink: string }> = {
  apollo: { label: "Apollo", accent: "#6df0df", ink: "#0a0f24" },
  rocco: { label: "Rocco", accent: "#ffcb75", ink: "#0a0f24" },
};

export function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

export function shiftLane(lane: number, delta: number): Lane {
  return clamp(Math.round(lane + delta), 0, LANE_COUNT - 1) as Lane;
}

export function poseFromTimers(jumpLeft: number, slideLeft: number): Pose {
  if (jumpLeft > 0) return "jump";
  if (slideLeft > 0) return "slide";
  return "run";
}

export function jumpLift(jumpLeft: number, jumpTime: number) {
  if (jumpLeft <= 0 || jumpTime <= 0) return 0;
  const progress = 1 - jumpLeft / jumpTime;
  return Math.sin(clamp(progress, 0, 1) * Math.PI);
}

export function startJump(jumpLeft: number, slideLeft: number, jumpTime: number) {
  if (jumpLeft > 0 || slideLeft > 0) return jumpLeft;
  return jumpTime;
}

export function startSlide(jumpLeft: number, slideLeft: number, slideTime: number) {
  if (jumpLeft > 0 || slideLeft > 0) return slideLeft;
  return slideTime;
}

export function hazardResult(pose: Pose, kind: HazardKind): "clear" | "hit" {
  if (kind === "low" && pose === "jump") return "clear";
  if (kind === "high" && pose === "slide") return "clear";
  return "hit";
}

export function inHitWindow(z: number, hitDepth: number, playerZ = PLAYER_Z) {
  return z <= playerZ + hitDepth && z >= playerZ - 0.4;
}

export function applyHit(hitsLeft: number, iframesLeft: number, iframeDuration: number) {
  if (iframesLeft > 0) {
    return { hitsLeft, iframes: iframesLeft, dead: false, ignored: true as const };
  }
  const next = hitsLeft - 1;
  return { hitsLeft: next, iframes: iframeDuration, dead: next <= 0, ignored: false as const };
}

export function runSpeed(elapsed: number, difficulty: Difficulty) {
  const tuning = TUNING[difficulty];
  return Math.min(tuning.maxSpeed, tuning.startSpeed + Math.max(0, elapsed) * tuning.accel);
}

export function runPoints(distance: number, treats: number) {
  return Math.max(0, Math.floor(distance) + Math.max(0, Math.floor(treats)) * 5);
}

export function spawnGap(difficulty: Difficulty, random: () => number) {
  const tuning = TUNING[difficulty];
  return tuning.minGap + random() * (tuning.maxGap - tuning.minGap);
}

export function planHazards(maxBlockedLanes: number, random: () => number): { lane: Lane; kind: HazardKind }[] {
  const blocked = clamp(Math.floor(1 + (random() < 0.42 && maxBlockedLanes > 1 ? 1 : 0)), 1, Math.min(2, maxBlockedLanes));
  const lanes: Lane[] = [0, 1, 2];
  for (let i = lanes.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [lanes[i], lanes[j]] = [lanes[j], lanes[i]];
  }
  return lanes.slice(0, blocked).map((lane) => ({
    lane,
    kind: random() < 0.5 ? "low" : "high",
  }));
}

export function togglePause(status: GameStatus): GameStatus {
  if (status === "running") return "paused";
  if (status === "paused") return "running";
  return status;
}

export function playIntent(status: GameStatus): "start" | "resume" | "ignore" {
  if (status === "paused") return "resume";
  if (status === "ready" || status === "gameover") return "start";
  return "ignore";
}

export function loadBest(storage: StorageLike) {
  try {
    const value = Number(storage.getItem(BEST_KEY) || 0);
    return Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
  } catch {
    return 0;
  }
}

export function saveBest(storage: StorageLike, score: number) {
  const best = Math.max(loadBest(storage), Math.max(0, Math.floor(score)));
  try {
    storage.setItem(BEST_KEY, String(best));
  } catch {
    /* Local scores are optional. */
  }
  return best;
}

export function swipeAction(dx: number, dy: number, threshold = 36): "left" | "right" | "jump" | "slide" | null {
  if (Math.max(Math.abs(dx), Math.abs(dy)) < threshold) return null;
  if (Math.abs(dx) > Math.abs(dy)) return dx < 0 ? "left" : "right";
  return dy < 0 ? "jump" : "slide";
}
