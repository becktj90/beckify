import { Router, type IRouter } from "express";
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

const router: IRouter = Router();

router.post("/analyze-tdr", async (req, res) => {
  const body = (req.body || {}) as AnalyzeTdrRequestBody;
  const rawImage = body.base64Image ?? body.imageBase64 ?? body.image;
  if (!rawImage || typeof rawImage !== "string") {
    return res.status(400).json({
      error: "Provide a base64 image string in `base64Image` or `imageBase64`.",
    });
  }

  const provider = (body.provider ?? process.env["TDR_VISION_PROVIDER"] ?? "openai")
    .toLowerCase() as VisionProvider;
  const mimeType = body.mimeType || inferMimeType(rawImage) || "image/jpeg";
  const model = body.model
    || process.env["TDR_VISION_MODEL"]
    || (provider === "anthropic" ? "claude-3-5-sonnet-latest" : "gpt-4o");

  try {
    const result = provider === "anthropic"
      ? await analyzeWithAnthropic({ image: rawImage, mimeType, model })
      : await analyzeWithOpenAI({ image: rawImage, mimeType, model });

    const parsed = normalizeAnalysis(result);
    return res.json({
      provider,
      model,
      analysis: parsed,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown analyzer error";
    return res.status(502).json({
      error: message,
    });
  }
});

function inferMimeType(dataUrlOrBase64: string): string | null {
  const match = /^data:([^;]+);base64,/.exec(dataUrlOrBase64);
  return match ? match[1] : null;
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

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
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

  const response = await fetch("https://api.anthropic.com/v1/messages", {
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

export default router;
