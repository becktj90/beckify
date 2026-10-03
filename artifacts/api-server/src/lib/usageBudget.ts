import { logger } from "./logger.js";

/** Rolling window for every AI meter. Not a login. Keyed by client address. */
export const AI_BUDGET_WINDOW_MS = 15 * 60 * 1000;

export type AIBudgetKind = "vision" | "eleven" | "openai" | "text";

export type AIBudgetDecision = {
  allowed: boolean;
  retryAfter: number;
  limit: number;
  used: number;
};

type WindowBucket = { units: number; resetAt: number };

const windows = new Map<string, WindowBucket>();

const DEFAULT_LIMITS: Record<AIBudgetKind, { env: string; limit: number }> = {
  /** Shared image analyses (look, nameplate, panel, TDR) per client per window. */
  vision: { env: "AI_BUDGET_VISION", limit: 5 },
  /** ElevenLabs characters accepted per client per window. */
  eleven: { env: "AI_BUDGET_ELEVEN_CHARS", limit: 8_000 },
  /** OpenAI speech requests per client per window. Toolbox math is not metered. */
  openai: { env: "AI_BUDGET_OPENAI", limit: 20 },
  /** Text completions (translate, review, look comedy) per client per window. */
  text: { env: "AI_BUDGET_TEXT", limit: 30 },
};

export class OutputTruncatedError extends Error {
  constructor() {
    super("The model hit its output token cap.");
    this.name = "OutputTruncatedError";
  }
}

export class ProviderStatusError extends Error {
  readonly status: number;
  constructor(status: number, message?: string) {
    super(message || `The provider returned HTTP ${status}.`);
    this.name = "ProviderStatusError";
    this.status = status;
  }
}

export function textMaxOutputTokens(): number {
  return readPositiveInt(process.env["AI_TEXT_MAX_OUTPUT_TOKENS"], 1800);
}

export function visionMaxOutputTokens(): number {
  return readPositiveInt(process.env["AI_VISION_MAX_OUTPUT_TOKENS"], 8192);
}

export function panelMaxOutputTokens(): number {
  return readPositiveInt(process.env["AI_PANEL_MAX_OUTPUT_TOKENS"], 8192);
}

export function budgetLimit(kind: AIBudgetKind): number {
  const spec = DEFAULT_LIMITS[kind];
  return readPositiveInt(process.env[spec.env], spec.limit);
}

/**
 * Reserve units. A rejected charge does not consume the window.
 * Call refundBudget when the provider did not do billable work.
 */
export function chargeBudget(
  kind: AIBudgetKind,
  clientKey: string,
  units = 1,
  now = Date.now(),
): AIBudgetDecision {
  const amount = normalizeUnits(units);
  const limit = budgetLimit(kind);
  const key = windowKey(kind, clientKey);
  const bucket = freshBucket(key, now);
  const retryAfter = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
  if (bucket.units + amount > limit) {
    return { allowed: false, retryAfter, limit, used: bucket.units };
  }
  bucket.units += amount;
  windows.set(key, bucket);
  prune(now);
  return { allowed: true, retryAfter, limit, used: bucket.units };
}

/** Give units back after a provider failure. Never drops below zero. */
export function refundBudget(
  kind: AIBudgetKind,
  clientKey: string,
  units = 1,
  now = Date.now(),
): void {
  const amount = normalizeUnits(units);
  const key = windowKey(kind, clientKey);
  const bucket = windows.get(key);
  if (!bucket || bucket.resetAt <= now) return;
  bucket.units = Math.max(0, bucket.units - amount);
}

export function shouldRefundAICharge(error: unknown): boolean {
  return !(error instanceof OutputTruncatedError);
}

export function isRetryableProviderError(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const name = (error as { name?: string }).name;
  if (name === "OutputTruncatedError" || name === "MissingProviderKeyError") return false;
  if (name === "ProviderTimeoutError" || name === "TimeoutError" || name === "AbortError") return true;
  if (name === "ProviderStatusError") {
    const status = (error as { status?: number }).status;
    return status === 408 || status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
  }
  return false;
}

export function isRetryableProviderStatus(status: number): boolean {
  return status === 408 || status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
}

export async function withRetries<T>(
  fn: () => Promise<T>,
  options?: { attempts?: number; delayMs?: number },
): Promise<T> {
  const attempts = Math.max(1, options?.attempts ?? 3);
  const delayMs = options?.delayMs ?? 200;
  let last: unknown;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      last = error;
      if (!isRetryableProviderError(error) || attempt === attempts) throw error;
      if (delayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, delayMs * attempt));
      }
    }
  }
  throw last;
}

export function assertNotTruncated(reason: string | null | undefined): void {
  if (reason === "length" || reason === "max_tokens") throw new OutputTruncatedError();
}

export function logAIUsage(fields: {
  route: string;
  kind: AIBudgetKind | "speak" | "translate" | "review";
  outcome: "ok" | "blocked" | "refund" | "error";
  units?: number;
  clientKey?: string;
  model?: string;
  status?: number;
}): void {
  logger.info({
    event: "ai_usage",
    route: fields.route,
    kind: fields.kind,
    outcome: fields.outcome,
    units: fields.units ?? 0,
    clientKey: fields.clientKey ?? "unknown",
    model: fields.model,
    status: fields.status,
  });
}

/** Test-only. Production windows live for the process lifetime. */
export function resetBudgetsForTests(): void {
  windows.clear();
}

function windowKey(kind: AIBudgetKind, clientKey: string): string {
  return `${kind}:${clientKey || "unknown"}`;
}

function freshBucket(key: string, now: number): WindowBucket {
  const current = windows.get(key);
  if (!current || current.resetAt <= now) {
    return { units: 0, resetAt: now + AI_BUDGET_WINDOW_MS };
  }
  return current;
}

function normalizeUnits(units: number): number {
  if (!Number.isFinite(units) || units <= 0) return 1;
  return Math.ceil(units);
}

function readPositiveInt(raw: string | undefined, fallback: number): number {
  if (raw == null || raw.trim() === "") return fallback;
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) return fallback;
  return parsed;
}

function prune(now: number): void {
  if (windows.size <= 10_000) return;
  for (const [key, value] of windows) {
    if (value.resetAt <= now) windows.delete(key);
  }
}

/**
 * IPv4 stays as-is. IPv6 collapses to the /64 so a client cannot rotate
 * the interface id and mint a new budget. IPv4-mapped addresses unwrap.
 */
export function clientKeyFromAddress(address: string): string {
  let raw = address.trim();
  if (!raw) return "unknown";
  const zone = raw.indexOf("%");
  if (zone >= 0) raw = raw.slice(0, zone);
  if (raw.startsWith("[") && raw.endsWith("]")) raw = raw.slice(1, -1);
  const lower = raw.toLowerCase();
  if (lower.startsWith("::ffff:")) {
    const mapped = lower.slice("::ffff:".length);
    if (mapped.includes(".")) return mapped;
  }
  if (lower.includes(".")) return lower;
  const expanded = expandIPv6(lower);
  if (!expanded) return lower;
  const hextets = expanded.split(":");
  return `${hextets.slice(0, 4).join(":")}::/64`;
}

function expandIPv6(input: string): string | null {
  if (!input.includes(":")) return null;
  const halves = input.split("::");
  if (halves.length > 2) return null;
  const left = halves[0] ? halves[0].split(":") : [];
  const right = halves.length === 2 && halves[1] ? halves[1].split(":") : [];
  if (halves.length === 1) {
    if (left.length !== 8) return null;
    return left.map(padHextet).join(":");
  }
  const missing = 8 - left.length - right.length;
  if (missing < 0) return null;
  const zeros = Array<string>(missing).fill("0");
  return [...left, ...zeros, ...right].map(padHextet).join(":");
}

function padHextet(value: string): string {
  return value.padStart(4, "0");
}
