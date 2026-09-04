import type { Request } from "express";

export type VisionProvider = "openai" | "anthropic";

export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
export const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
export const MAX_REQUESTS_PER_WINDOW = 5;
export const MAX_IN_FLIGHT_PER_CLIENT = 2;
export const PROVIDER_TIMEOUT_MS = 45_000;
const SUPPORTED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/gif", "image/webp"]);

export class ProviderTimeoutError extends Error {
  constructor() {
    super("Vision provider request timed out.");
    this.name = "ProviderTimeoutError";
  }
}

export function configuredProvider(envName = "NAMEPLATE_VISION_PROVIDER"): VisionProvider {
  const provider = (process.env[envName] ?? process.env["TDR_VISION_PROVIDER"] ?? "openai").toLowerCase();
  if (provider !== "openai" && provider !== "anthropic") {
    throw new Error(`${envName} must be openai or anthropic.`);
  }
  return provider;
}

export function configuredModel(provider: VisionProvider, envName = "NAMEPLATE_VISION_MODEL"): string {
  return process.env[envName]
    || process.env["TDR_VISION_MODEL"]
    || (provider === "anthropic" ? "claude-3-5-sonnet-latest" : "gpt-4o");
}

export function getClientKey(req: Request): string {
  return req.ip || req.socket.remoteAddress || "unknown";
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
  return { ...bucket, allowed: bucket.count <= MAX_REQUESTS_PER_WINDOW };
}

export function validateImage(
  rawImage: string,
  requestedMimeType?: string,
): { ok: true; base64: string; mimeType: string } | { ok: false; status: 400 | 413; error: string } {
  const dataUrlMatch = /^data:([^;,]+);base64,([A-Za-z0-9+/=\s]+)$/.exec(rawImage.trim());
  const mimeType = dataUrlMatch?.[1] || requestedMimeType || "image/jpeg";
  const base64 = (dataUrlMatch?.[2] || rawImage).replace(/\s/g, "");
  if (!SUPPORTED_IMAGE_TYPES.has(mimeType)) {
    return { ok: false, status: 400, error: "Only JPEG, PNG, GIF, and WebP images are supported." };
  }
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(base64) || base64.length % 4 === 1) {
    return { ok: false, status: 400, error: "The image is not valid base64 data." };
  }
  const byteLength = Math.floor(base64.length * 3 / 4) - (base64.endsWith("==") ? 2 : base64.endsWith("=") ? 1 : 0);
  if (byteLength <= 0) return { ok: false, status: 400, error: "The image is empty." };
  if (byteLength > MAX_IMAGE_BYTES) return { ok: false, status: 413, error: "The image must be 8 MiB or smaller." };
  const bytes = Buffer.from(base64, "base64");
  if (!hasImageSignature(bytes, mimeType)) {
    return { ok: false, status: 400, error: "The image data does not match its declared type." };
  }
  return { ok: true, base64, mimeType };
}

function hasImageSignature(bytes: Buffer, mimeType: string): boolean {
  if (mimeType === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (mimeType === "image/png") return bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  if (mimeType === "image/gif") return bytes.subarray(0, 6).toString("ascii") === "GIF87a" || bytes.subarray(0, 6).toString("ascii") === "GIF89a";
  return bytes.subarray(0, 4).toString("ascii") === "RIFF" && bytes.subarray(8, 12).toString("ascii") === "WEBP";
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
}): Promise<unknown> {
  const apiKey = process.env["OPENAI_API_KEY"];
  if (!apiKey) throw new Error("OPENAI_API_KEY is required for OpenAI vision analysis.");

  const response = await fetchWithTimeout("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: args.model,
      temperature: 0,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: args.system },
        {
          role: "user",
          content: [
            { type: "text", text: args.userText },
            { type: "image_url", image_url: { url: toDataUrl(args.image, args.mimeType) } },
          ],
        },
      ],
    }),
  });

  const payload = await response.json() as {
    choices?: Array<{ message?: { content?: string | null } }>;
    error?: { message?: string };
  };
  if (!response.ok) throw new Error(payload.error?.message || `OpenAI request failed with HTTP ${response.status}.`);
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
}): Promise<unknown> {
  const apiKey = process.env["ANTHROPIC_API_KEY"];
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY is required for Anthropic vision analysis.");

  const response = await fetchWithTimeout("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: args.model,
      max_tokens: 1600,
      temperature: 0,
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
  });

  const payload = await response.json() as {
    content?: Array<{ text?: string }>;
    error?: { message?: string };
  };
  if (!response.ok) throw new Error(payload.error?.message || `Anthropic request failed with HTTP ${response.status}.`);
  const content = payload.content?.find((part) => typeof part.text === "string")?.text;
  if (!content) throw new Error("Anthropic returned no analysis content.");
  return extractJsonObject(content);
}

async function fetchWithTimeout(input: string, init: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") throw new ProviderTimeoutError();
    throw error;
  } finally {
    clearTimeout(timeout);
  }
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
