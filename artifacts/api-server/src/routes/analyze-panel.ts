import { Router, type IRouter } from "express";
import { PANEL_VISION_SYSTEM_PROMPT } from "../prompts/panelVisionPrompt.js";
import {
  PANEL_MAX_OUTPUT_TOKENS,
  PANEL_PROVIDER_TIMEOUT_MS,
  ProviderTimeoutError,
  analyzeWithAnthropic,
  analyzeWithOpenAI,
  configuredModel,
  configuredProvider,
  consumeRateLimit,
  getClientKey,
  pickImage,
} from "../lib/visionClient.js";

interface AnalyzeBody {
  base64Image?: string;
  imageBase64?: string;
  image?: string;
  mimeType?: string;
  provider?: string;
  model?: string;
  task?: string;
}

const rateBuckets = new Map<string, { count: number; resetAt: number; inFlight: number }>();
const serverProvider = configuredProvider();
const serverModel = configuredModel(serverProvider);
const router: IRouter = Router();

/* Optional Enhance path for panel-schedule / panel-power-study. On-device
   Tesseract remains the default when Enhance is off. */
router.post("/analyze-panel", async (req, res) => {
  const body = (req.body || {}) as AnalyzeBody;
  const picked = pickImage(body);
  if ("error" in picked) return res.status(picked.status).json({ error: picked.error });

  const clientKey = getClientKey(req);
  const bucket = consumeRateLimit(rateBuckets, clientKey);
  if (!bucket.allowed) {
    const retryAfter = Math.ceil((bucket.resetAt - Date.now()) / 1000);
    res.setHeader("Retry-After", String(retryAfter));
    return res.status(429).json({
      error: "Too many panel analyses. Please try again later.",
      retryAfter,
    });
  }
  if (bucket.inFlight >= 2) {
    res.setHeader("Retry-After", "15");
    return res.status(429).json({
      error: "Too many panel analyses in progress.",
      retryAfter: 15,
    });
  }
  bucket.inFlight += 1;

  const userText = [
    "Extract the printed panel directory into structured JSON.",
    "Upright rotated phone photos first. Emit one circuit entry per odd/even number you can actually read.",
    "This frame may be only part of a large card — do not invent missing circuits.",
    "Prefer handwritten corrections over crossed-out print. Do not copy breaker trip into load amps.",
    "phases is 1 or 3 only when printed. Never assume 3-phase.",
  ].join(" ");

  try {
    const result = serverProvider === "anthropic"
      ? await analyzeWithAnthropic({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: PANEL_VISION_SYSTEM_PROMPT,
        userText,
        maxTokens: PANEL_MAX_OUTPUT_TOKENS,
        timeoutMs: PANEL_PROVIDER_TIMEOUT_MS,
      })
      : await analyzeWithOpenAI({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: PANEL_VISION_SYSTEM_PROMPT,
        userText,
        maxTokens: PANEL_MAX_OUTPUT_TOKENS,
        timeoutMs: PANEL_PROVIDER_TIMEOUT_MS,
      });

    return res.json({
      provider: serverProvider,
      model: serverModel,
      analysis: result,
    });
  } catch (error) {
    const isTimeout = error instanceof ProviderTimeoutError;
    console.error("Panel vision provider request failed", error);
    return res.status(isTimeout ? 504 : 502).json({
      error: isTimeout
        ? "The vision provider timed out. Please try again."
        : "The vision provider could not analyze this image.",
    });
  } finally {
    bucket.inFlight -= 1;
  }
});

export default router;
