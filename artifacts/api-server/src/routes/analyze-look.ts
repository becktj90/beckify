import { Router, type IRouter } from "express";
import { LOOK_VISION_SYSTEM_PROMPT } from "../prompts/lookVisionPrompt.js";
import {
  analyzeWithAnthropic,
  analyzeWithOpenAI,
  configuredModel,
  configuredProvider,
  consumeRateLimit,
  getClientKey,
  pickImage,
  visionProviderFailure,
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
    const retryAfter = Math.ceil((bucket.resetAt - Date.now()) / 1000);
    res.setHeader("Retry-After", String(retryAfter));
    return res.status(429).json({ error: "Too many look checks. Please try again later.", retryAfter });
  }
  if (bucket.inFlight >= 2) {
    res.setHeader("Retry-After", "15");
    return res.status(429).json({ error: "Too many look checks in progress.", retryAfter: 15 });
  }
  bucket.inFlight += 1;

  const userText = "Upright the photo if it is rotated. If an adult is in frame, score lighting, framing, expression, sharpness, and overall, plus a brief summary of how they look. Follow the JSON shape.";

  try {
    const result = serverProvider === "anthropic"
      ? await analyzeWithAnthropic({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: LOOK_VISION_SYSTEM_PROMPT,
        userText,
        maxTokens: 1600,
      })
      : await analyzeWithOpenAI({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: LOOK_VISION_SYSTEM_PROMPT,
        userText,
        maxTokens: 1600,
      });

    return res.json({
      provider: serverProvider,
      model: serverModel,
      analysis: result,
    });
  } catch (error) {
    const failure = visionProviderFailure(error);
    console.error("Look vision provider request failed", error);
    return res.status(failure.status).json({ error: failure.error });
  } finally {
    bucket.inFlight -= 1;
  }
});

export default router;
