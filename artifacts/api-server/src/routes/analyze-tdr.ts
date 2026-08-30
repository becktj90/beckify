import { Router, type IRouter, type Request } from "express";
import {
  TDR_VISION_SYSTEM_PROMPT,
  type TdrVisionAnalysis,
} from "../prompts/tdrVisionPrompt";

type VisionProvider = "openai" | "anthropic";

interface AnalyzeTdrRequestBody {
  base64Image?: string;
  imageBase64?: string;
  image?: string;
  mimeType?: string;
  provider?: VisionProvider;
  model?: string;
}

const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 5;
const MAX_IN_FLIGHT_PER_CLIENT = 2;
const PROVIDER_TIMEOUT_MS = 45_000;
const SUPPORTED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/gif", "image/webp"]);
const rateBuckets = new Map<string, { count: number; resetAt: number; inFlight: number }>();
const serverProvider = configuredProvider();
const serverModel = process.env["TDR_VISION_MODEL"]
  || (serverProvider === "anthropic" ? "claude-3-5-sonnet-latest" : "gpt-4o");

const router: IRouter = Router();

router.post("/analyze-tdr", async (req, res) => {
  const body = (req.body || {}) as AnalyzeTdrRequestBody;
  const rawImage = body.base64Image ?? body.imageBase64 ?? body.image;
  if (!rawImage || typeof rawImage !== "string") {
    return res.status(400).json({
      error: "Provide a base64 image string in `base64Image` or `imageBase64`.",
    });
  }

  if (body.provider !== undefined || body.model !== undefined) {
    return res.status(400).json({ error: "Provider and model are configured by the server." });
  }

  const image = validateImage(rawImage, body.mimeType);
  if (!image.ok) return res.status(image.status).json({ error: image.error });

  const provider = serverProvider;
  const model = serverModel;
  const clientKey = getClientKey(req);
  const bucket = consumeRateLimit(clientKey);
  if (!bucket.allowed) {
    res.setHeader("Retry-After", String(Math.ceil((bucket.resetAt - Date.now()) / 1000)));
    return res.status(429).json({ error: "Too many TDR analyses. Please try again later." });
  }
  if (bucket.inFlight >= MAX_IN_FLIGHT_PER_CLIENT) {
    return res.status(429).json({ error: "Too many TDR analyses in progress." });
  }
  bucket.inFlight += 1;

  try {
    const result = provider === "anthropic"
      ? await analyzeWithAnthropic({ image: image.base64, mimeType: image.mimeType, model })
      : await analyzeWithOpenAI({ image: image.base64, mimeType: image.mimeType, model });

    const parsed = normalizeAnalysis(result);
    return res.json({
      provider,
      model,
      analysis: parsed,
    });
  } catch (error) {
    const isTimeout = error instanceof ProviderTimeoutError;
    console.error("TDR vision provider request failed", error);
    return res.status(isTimeout ? 504 : 502).json({
      error: isTimeout ? "The vision provider timed out. Please try again." : "The vision provider could not analyze this image.",
    });
  } finally {
    bucket.inFlight -= 1;
  }
});

class ProviderTimeoutError extends Error {
  constructor() {
    super("Vision provider request timed out.");
    this.name = "ProviderTimeoutError";
  }
}

function configuredProvider(): VisionProvider {
  const provider = (process.env["TDR_VISION_PROVIDER"] ?? "openai").toLowerCase();
  if (provider !== "openai" && provider !== "anthropic") {
    throw new Error("TDR_VISION_PROVIDER must be openai or anthropic.");
  }
  return provider;
}

function getClientKey(req: Request): string {
  return req.ip || req.socket.remoteAddress || "unknown";
}

function consumeRateLimit(clientKey: string) {
  const now = Date.now();
  const current = rateBuckets.get(clientKey);
  const bucket = !current || current.resetAt <= now
    ? { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS, inFlight: 0 }
    : current;
  bucket.count += 1;
  rateBuckets.set(clientKey, bucket);
  if (rateBuckets.size > 10_000) {
    for (const [key, value] of rateBuckets) {
      if (value.resetAt <= now) rateBuckets.delete(key);
    }
  }
  return { ...bucket, allowed: bucket.count <= MAX_REQUESTS_PER_WINDOW };
}

function validateImage(rawImage: string, requestedMimeType?: string): { ok: true; base64: string; mimeType: string } | { ok: false; status: 400 | 413; error: string } {
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
  if (image.startsWith("data:") && commaIndex >= 0) {
    return image.slice(commaIndex + 1);
  }
  return image;
}

function toDataUrl(image: string, mimeType: string): string {
  if (image.startsWith("data:")) return image;
  return `data:${mimeType};base64,${image}`;
}

function extractJsonObject(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const source = fenced ? fenced[1] : trimmed;
  const start = source.indexOf("{");
  const end = source.lastIndexOf("}");
  const json = start >= 0 && end >= 0 ? source.slice(start, end + 1) : source;
  return JSON.parse(json);
}

function normalizeAnalysis(raw: unknown): TdrVisionAnalysis {
  if (!raw || typeof raw !== "object") {
    throw new Error("Vision model returned an empty response.");
  }

  const analysis = raw as Partial<TdrVisionAnalysis> & Record<string, unknown>;
  const screen = (analysis.screen || {}) as TdrVisionAnalysis["screen"];
  const events = Array.isArray(analysis.events) ? analysis.events : [];

  return {
    screen: {
      vf: toNullableNumber(screen?.vf),
      range: {
        value: toNullableNumber(screen?.range?.value),
        unit: typeof screen?.range?.unit === "string" ? screen.range.unit : null,
      },
      impedance: {
        value: toNullableNumber(screen?.impedance?.value),
        unit: typeof screen?.impedance?.unit === "string" ? screen.impedance.unit : null,
      },
      confidence: clamp01(toNullableNumber(screen?.confidence) ?? 0.5),
    },
    events: events.map((event) => {
      const row = event as Partial<Record<keyof TdrVisionAnalysis["events"][number], unknown>>;
      return {
        label: String(row.label || "Reflection"),
        polarity: row.polarity === "positive" || row.polarity === "negative" ? row.polarity : "unknown",
        faultType: String(row.faultType || "unknown"),
        distance_ft: toNullableNumber(row.distance_ft),
        distance_m: toNullableNumber(row.distance_m),
        range_fraction: toNullableNumber(row.range_fraction),
        confidence: clamp01(toNullableNumber(row.confidence) ?? 0.5),
        recommendation: String(row.recommendation || "Inspect the cable termination and the nearest splice."),
      };
    }),
    summary: String(analysis.summary || "No summary returned."),
    warnings: Array.isArray(analysis.warnings) ? analysis.warnings.map((w) => String(w)) : [],
    raw_ocr: String(analysis.raw_ocr || ""),
  };
}

function clamp01(value: number): number {
  return Math.max(0, Math.min(1, value));
}

function toNullableNumber(value: unknown): number | null {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

async function analyzeWithOpenAI(args: { image: string; mimeType: string; model: string; }): Promise<unknown> {
  const apiKey = process.env["OPENAI_API_KEY"];
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is required for OpenAI vision analysis.");
  }

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
        {
          role: "system",
          content: TDR_VISION_SYSTEM_PROMPT,
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Analyze this Megger TDR500 screen and return the structured JSON report.",
            },
            {
              type: "image_url",
              image_url: {
                url: toDataUrl(args.image, args.mimeType),
              },
            },
          ],
        },
      ],
    }),
  });

  const payload = await response.json() as {
    choices?: Array<{ message?: { content?: string | null } }>;
    error?: { message?: string };
  };

  if (!response.ok) {
    throw new Error(payload.error?.message || `OpenAI request failed with HTTP ${response.status}.`);
  }

  const content = payload.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("OpenAI returned no analysis content.");
  }

  return extractJsonObject(content);
}

async function analyzeWithAnthropic(args: { image: string; mimeType: string; model: string; }): Promise<unknown> {
  const apiKey = process.env["ANTHROPIC_API_KEY"];
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY is required for Anthropic vision analysis.");
  }

  const response = await fetchWithTimeout("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: args.model,
      max_tokens: 1200,
      temperature: 0,
      system: TDR_VISION_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Analyze this Megger TDR500 screen and return the structured JSON report.",
            },
            {
              type: "image",
              source: {
                type: "base64",
                media_type: args.mimeType,
                data: stripDataUrl(args.image),
              },
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

  if (!response.ok) {
    throw new Error(payload.error?.message || `Anthropic request failed with HTTP ${response.status}.`);
  }

  const content = payload.content?.find((part) => typeof part.text === "string")?.text;
  if (!content) {
    throw new Error("Anthropic returned no analysis content.");
  }

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

export default router;
