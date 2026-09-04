import { Router, type IRouter } from "express";
import { LOOK_VISION_SYSTEM_PROMPT } from "../prompts/lookVisionPrompt.js";
import {
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

router.post("/analyze-look", async (req, res) => {
  const body = (req.body || {}) as AnalyzeBody;
  const picked = pickImage(body);
  if ("error" in picked) return res.status(picked.status).json({ error: picked.error });

  const clientKey = getClientKey(req);
  const bucket = consumeRateLimit(rateBuckets, clientKey);
  if (!bucket.allowed) {
    res.setHeader("Retry-After", String(Math.ceil((bucket.resetAt - Date.now()) / 1000)));
    return res.status(429).json({ error: "Too many look checks. Please try again later." });
  }
  if (bucket.inFlight >= 2) {
    return res.status(429).json({ error: "Too many look checks in progress." });
  }
  bucket.inFlight += 1;

  const userText = "Upright the photo if it is rotated. Give a playful honest verdict: do they look good or bad? Follow the JSON shape.";

  try {
    const result = serverProvider === "anthropic"
      ? await analyzeWithAnthropic({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: LOOK_VISION_SYSTEM_PROMPT,
        userText,
        maxTokens: 1200,
      })
      : await analyzeWithOpenAI({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: LOOK_VISION_SYSTEM_PROMPT,
        userText,
        maxTokens: 1200,
      });

    return res.json({
      provider: serverProvider,
      model: serverModel,
      analysis: result,
    });
  } catch (error) {
    const isTimeout = error instanceof ProviderTimeoutError;
    console.error("Look vision provider request failed", error);
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
