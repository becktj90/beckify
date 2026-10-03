import type { Request } from "express";
import {
  OutputTruncatedError,
  ProviderStatusError,
  assertNotTruncated,
  chargeBudget,
  clientKeyFromAddress,
  isRetryableProviderStatus,
  refundBudget,
  textMaxOutputTokens,
  visionMaxOutputTokens,
  withRetries,
} from "./usageBudget.js";

export type VisionProvider = "openai" | "anthropic";

export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
export const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
export const MAX_REQUESTS_PER_WINDOW = 5;
export const MAX_IN_FLIGHT_PER_CLIENT = 2;
export const PROVIDER_TIMEOUT_MS = 45_000;
export const PANEL_PROVIDER_TIMEOUT_MS = 90_000;
export const PANEL_MAX_OUTPUT_TOKENS = 8192;
export const DEFAULT_MAX_OUTPUT_TOKENS = 8192;
const SUPPORTED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/gif", "image/webp"]);
const DEFAULT_MODEL: Record<VisionProvider, string> = {
  openai: "gpt-4o",
  anthropic: "claude-3-5-sonnet-latest",
};

export class ProviderTimeoutError extends Error {
  constructor() {
    super("Vision provider request timed out.");
    this.name = "ProviderTimeoutError";
  }
}

export class MissingProviderKeyError extends Error {
  readonly envName: string;
  constructor(envName: string) {
    super(`The vision provider key is missing (${envName}). Photos cannot be analyzed until that secret is set on the API host.`);
    this.name = "MissingProviderKeyError";
    this.envName = envName;
  }
}

export const VISION_POST_PATHS = [
  "/api/analyze-look",
  "/api/analyze-nameplate",
  "/api/analyze-panel",
  "/api/analyze-tdr",
] as const;

export function visionProviderFailure(error: unknown): { status: number; error: string } {
  if (error instanceof MissingProviderKeyError) {
    return { status: 503, error: error.message };
  }
  if (error instanceof OutputTruncatedError) {
    return { status: 502, error: error.message };
  }
  if (error instanceof ProviderTimeoutError) {
    return { status: 504, error: "The vision provider timed out. Please try again." };
  }
  return {
    status: 502,
    error: "The vision provider could not analyze this image.",
  };
}

export function configuredProvider(envName = "NAMEPLATE_VISION_PROVIDER"): VisionProvider {
  const provider = (process.env[envName] ?? process.env["TDR_VISION_PROVIDER"] ?? "openai").toLowerCase();
  if (provider !== "openai" && provider !== "anthropic") {
    throw new Error(`${envName} must be openai or anthropic.`);
  }
  return provider;
}

export function modelFitsProvider(provider: VisionProvider, model: string): boolean {
  const name = String(model || "").toLowerCase();
  if (!name) return false;
  if (provider === "anthropic") return name.includes("claude");
  return !name.includes("claude");
}

export function configuredModel(provider: VisionProvider, envName = "NAMEPLATE_VISION_MODEL"): string {
  const explicit = process.env[envName];
  if (explicit) return explicit;
  const tdrModel = process.env["TDR_VISION_MODEL"];
  if (tdrModel && modelFitsProvider(provider, tdrModel)) return tdrModel;
  return DEFAULT_MODEL[provider];
}

export function getClientKey(req: Request): string {
  return clientKeyFromAddress(req.ip || req.socket.remoteAddress || "unknown");
}

const sharedAnalyzeBurst = new Map<string, { inFlight: number }>();

/** One in-flight cap for every analyze route, so look+panel cannot stack. */
export function tryAcquireSharedAnalyzeBurst(
  clientKey: string,
  maxInFlight = MAX_IN_FLIGHT_PER_CLIENT,
): { ok: true; release: () => void } | { ok: false } {
  const key = clientKey || "unknown";
  const current = sharedAnalyzeBurst.get(key) ?? { inFlight: 0 };
  if (current.inFlight >= maxInFlight) return { ok: false };
  current.inFlight += 1;
  sharedAnalyzeBurst.set(key, current);
  return {
    ok: true,
    release() {
      current.inFlight = Math.max(0, current.inFlight - 1);
      if (current.inFlight === 0) sharedAnalyzeBurst.delete(key);
    },
  };
}

export function resetSharedAnalyzeBurstForTests(): void {
  sharedAnalyzeBurst.clear();
}

/**
 * Charge the shared vision budget, then take one slot of the shared in-flight burst.
 * A burst rejection refunds the charge because no provider call was made.
 */
export function beginSharedVisionRequest(clientKey: string):
  | { ok: true; release: () => void }
  | { ok: false; retryAfter: number; reason: "budget" | "burst" } {
  const charge = chargeBudget("vision", clientKey, 1);
  if (!charge.allowed) return { ok: false, retryAfter: charge.retryAfter, reason: "budget" };
  const burst = tryAcquireSharedAnalyzeBurst(clientKey);
  if (!burst.ok) {
    refundBudget("vision", clientKey, 1);
    return { ok: false, retryAfter: 15, reason: "burst" };
  }
  return { ok: true, release: burst.release };
}

export function consumeRateLimit(
  buckets: Map<string, { count: number; resetAt: number; inFlight: number }>,
  clientKey: string,
) {
  const now = Date.now();
  const current = buckets.get(clientKey);
  const bucket = !current || current.resetAt <= now
    ? { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS, inFlight: 0 }
    : current;
  bucket.count += 1;
  buckets.set(clientKey, bucket);
  if (buckets.size > 10_000) {
    for (const [key, value] of buckets) {
      if (value.resetAt <= now) buckets.delete(key);
    }
  }
  // Mutate the stored object so callers can increment inFlight on the Map entry.
  return Object.assign(bucket, { allowed: bucket.count <= MAX_REQUESTS_PER_WINDOW });
}

export function validateImage(
  rawImage: string,
  requestedMimeType?: string,
): { ok: true; base64: string; mimeType: string } | { ok: false; status: 400 | 413; error: string } {
  const dataUrlMatch = /^data:([^;,]+);base64,([A-Za-z0-9+/=\s]+)$/.exec(rawImage.trim());
  const declaredMime = dataUrlMatch?.[1] || requestedMimeType || "image/jpeg";
  const base64 = (dataUrlMatch?.[2] || rawImage).replace(/\s/g, "");
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(base64) || base64.length % 4 === 1) {
    return { ok: false, status: 400, error: "The image is not valid base64 data." };
  }
  const byteLength = Math.floor(base64.length * 3 / 4) - (base64.endsWith("==") ? 2 : base64.endsWith("=") ? 1 : 0);
  if (byteLength <= 0) return { ok: false, status: 400, error: "The image is empty." };
  if (byteLength > MAX_IMAGE_BYTES) return { ok: false, status: 413, error: "The image must be 8 MiB or smaller." };
  const bytes = Buffer.from(base64, "base64");
  // Prefer magic-byte type so a JPEG re-encode of HEIC/BMP/TIFF still passes
  // even if the client sent the original picker MIME.
  const mimeType = sniffImageType(bytes) || (SUPPORTED_IMAGE_TYPES.has(declaredMime) ? declaredMime : "");
  if (!mimeType || !SUPPORTED_IMAGE_TYPES.has(mimeType)) {
    return { ok: false, status: 400, error: "Only JPEG, PNG, GIF, and WebP images are supported. Convert HEIC, HEIF, BMP, or TIFF before upload." };
  }
  if (!hasImageSignature(bytes, mimeType)) {
    return { ok: false, status: 400, error: "The image data does not match its declared type." };
  }
  return { ok: true, base64, mimeType };
}

function sniffImageType(bytes: Buffer): string | null {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "image/png";
  const gif = bytes.subarray(0, 6).toString("ascii");
  if (gif === "GIF87a" || gif === "GIF89a") return "image/gif";
  if (bytes.subarray(0, 4).toString("ascii") === "RIFF" && bytes.subarray(8, 12).toString("ascii") === "WEBP") return "image/webp";
  return null;
}

function hasImageSignature(bytes: Buffer, mimeType: string): boolean {
  return sniffImageType(bytes) === mimeType;
}

function stripDataUrl(image: string): string {
  const commaIndex = image.indexOf(",");
  if (image.startsWith("data:") && commaIndex >= 0) return image.slice(commaIndex + 1);
  return image;
}

function toDataUrl(image: string, mimeType: string): string {
  if (image.startsWith("data:")) return image;
  return `data:${mimeType};base64,${image}`;
}

export function extractJsonObject(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const source = fenced ? fenced[1] : trimmed;
  const start = source.indexOf("{");
  const end = source.lastIndexOf("}");
  const json = start >= 0 && end >= 0 ? source.slice(start, end + 1) : source;
  return JSON.parse(json);
}

export async function analyzeWithOpenAI(args: {
  image: string;
  mimeType: string;
  model: string;
  system: string;
  userText: string;
  maxTokens?: number;
  timeoutMs?: number;
  /** Defaults to 0 so engineering vision tools stay deterministic. */
  temperature?: number;
}): Promise<unknown> {
  const apiKey = process.env["OPENAI_API_KEY"];
  if (!apiKey) throw new MissingProviderKeyError("OPENAI_API_KEY");

  const temperature = typeof args.temperature === "number" && Number.isFinite(args.temperature)
    ? Math.max(0, Math.min(2, args.temperature))
    : 0;

  const body: Record<string, unknown> = {
    model: args.model,
    temperature,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: args.system },
      {
        role: "user",
        content: [
          { type: "text", text: args.userText },
          { type: "image_url", image_url: { url: toDataUrl(args.image, args.mimeType), detail: "high" } },
        ],
      },
    ],
  };
  body.max_tokens = cappedOutputTokens(args.maxTokens, visionMaxOutputTokens());

  const { ok, status, payload } = await fetchJsonWithTimeout<{
    choices?: Array<{ finish_reason?: string | null; message?: { content?: string | null } }>;
    error?: { message?: string };
  }>("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  }, args.timeoutMs);

  if (!ok) throw new Error(payload.error?.message || `OpenAI request failed with HTTP ${status}.`);
  assertNotTruncated(payload.choices?.[0]?.finish_reason);
  const content = payload.choices?.[0]?.message?.content;
  if (!content) throw new Error("OpenAI returned no analysis content.");
  return extractJsonObject(content);
}

export async function analyzeWithAnthropic(args: {
  image: string;
  mimeType: string;
  model: string;
  system: string;
  userText: string;
  maxTokens?: number;
  timeoutMs?: number;
  /** Defaults to 0 so engineering vision tools stay deterministic. */
  temperature?: number;
}): Promise<unknown> {
  const apiKey = process.env["ANTHROPIC_API_KEY"];
  if (!apiKey) throw new MissingProviderKeyError("ANTHROPIC_API_KEY");

  const temperature = typeof args.temperature === "number" && Number.isFinite(args.temperature)
    ? Math.max(0, Math.min(1, args.temperature))
    : 0;

  const { ok, status, payload } = await fetchJsonWithTimeout<{
    content?: Array<{ text?: string }>;
    stop_reason?: string | null;
    error?: { message?: string };
  }>("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: args.model,
      max_tokens: cappedOutputTokens(args.maxTokens, visionMaxOutputTokens()),
      temperature,
      system: args.system,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: args.userText },
            {
              type: "image",
              source: { type: "base64", media_type: args.mimeType, data: stripDataUrl(args.image) },
            },
          ],
        },
      ],
    }),
  }, args.timeoutMs);

  if (!ok) throw new Error(payload.error?.message || `Anthropic request failed with HTTP ${status}.`);
  assertNotTruncated(payload.stop_reason);
  const content = payload.content?.find((part) => typeof part.text === "string")?.text;
  if (!content) throw new Error("Anthropic returned no analysis content.");
  return extractJsonObject(content);
}

async function fetchJsonWithTimeout<T>(
  input: string,
  init: RequestInit,
  timeoutMs = PROVIDER_TIMEOUT_MS,
): Promise<{ ok: boolean; status: number; payload: T }> {
  return withRetries(async () => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(input, { ...init, signal: controller.signal });
      // Keep the abort timer active while the body streams — a stall after
      // headers should still become ProviderTimeoutError / 504.
      const payload = await response.json() as T;
      if (!response.ok && isRetryableProviderStatus(response.status)) {
        throw new ProviderStatusError(response.status);
      }
      return { ok: response.ok, status: response.status, payload };
    } catch (error) {
      if (error instanceof OutputTruncatedError || error instanceof ProviderStatusError) throw error;
      if (error instanceof Error && error.name === "AbortError") throw new ProviderTimeoutError();
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  });
}

function cappedOutputTokens(requested: number | undefined, cap: number): number {
  const value = typeof requested === "number" && requested > 0 ? requested : cap;
  return Math.min(value, cap);
}

/** Text-only JSON completion — used for Look Check comedy after assessment is frozen. */
export async function analyzeTextWithOpenAI(args: {
  model: string;
  system: string;
  userText: string;
  maxTokens?: number;
  timeoutMs?: number;
  temperature?: number;
}): Promise<unknown> {
  const apiKey = process.env["OPENAI_API_KEY"];
  if (!apiKey) throw new MissingProviderKeyError("OPENAI_API_KEY");

  const temperature = typeof args.temperature === "number" && Number.isFinite(args.temperature)
    ? Math.max(0, Math.min(2, args.temperature))
    : 0;

  const body: Record<string, unknown> = {
    model: args.model,
    temperature,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: args.system },
      { role: "user", content: args.userText },
    ],
  };
  body.max_tokens = cappedOutputTokens(args.maxTokens, textMaxOutputTokens());

  const { ok, status, payload } = await fetchJsonWithTimeout<{
    choices?: Array<{ finish_reason?: string | null; message?: { content?: string | null } }>;
    error?: { message?: string };
  }>("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  }, args.timeoutMs);

  if (!ok) throw new Error(payload.error?.message || `OpenAI request failed with HTTP ${status}.`);
  assertNotTruncated(payload.choices?.[0]?.finish_reason);
  const content = payload.choices?.[0]?.message?.content;
  if (!content) throw new Error("OpenAI returned no analysis content.");
  return extractJsonObject(content);
}

export async function analyzeTextWithAnthropic(args: {
  model: string;
  system: string;
  userText: string;
  maxTokens?: number;
  timeoutMs?: number;
  temperature?: number;
}): Promise<unknown> {
  const apiKey = process.env["ANTHROPIC_API_KEY"];
  if (!apiKey) throw new MissingProviderKeyError("ANTHROPIC_API_KEY");

  const temperature = typeof args.temperature === "number" && Number.isFinite(args.temperature)
    ? Math.max(0, Math.min(1, args.temperature))
    : 0;

  const { ok, status, payload } = await fetchJsonWithTimeout<{
    content?: Array<{ text?: string }>;
    stop_reason?: string | null;
    error?: { message?: string };
  }>("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: args.model,
      max_tokens: cappedOutputTokens(args.maxTokens, textMaxOutputTokens()),
      temperature,
      system: args.system,
      messages: [
        { role: "user", content: args.userText },
      ],
    }),
  }, args.timeoutMs);

  if (!ok) throw new Error(payload.error?.message || `Anthropic request failed with HTTP ${status}.`);
  assertNotTruncated(payload.stop_reason);
  const content = payload.content?.find((part) => typeof part.text === "string")?.text;
  if (!content) throw new Error("Anthropic returned no analysis content.");
  return extractJsonObject(content);
}

export function pickImage(body: { base64Image?: string; imageBase64?: string; image?: string; mimeType?: string; provider?: unknown; model?: unknown; }):
  | { error: string; status: 400 | 413 }
  | { image: { base64: string; mimeType: string } } {
  if (body.provider !== undefined || body.model !== undefined) {
    return { error: "Provider and model are configured by the server.", status: 400 };
  }
  const rawImage = body.base64Image ?? body.imageBase64 ?? body.image;
  if (!rawImage || typeof rawImage !== "string") {
    return { error: "Provide a base64 image string in `base64Image` or `imageBase64`.", status: 400 };
  }
  const image = validateImage(rawImage, body.mimeType);
  if (!image.ok) return { error: image.error, status: image.status };
  return { image: { base64: image.base64, mimeType: image.mimeType } };
}
