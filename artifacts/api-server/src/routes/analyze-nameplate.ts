import { Router, type IRouter } from "express";
import { NAMEPLATE_VISION_SYSTEM_PROMPT } from "../prompts/nameplateVisionPrompt.js";
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

router.post("/analyze-nameplate", async (req, res) => {
  const body = (req.body || {}) as AnalyzeBody;
  const picked = pickImage(body);
  if ("error" in picked) return res.status(picked.status).json({ error: picked.error });

  const clientKey = getClientKey(req);
  const bucket = consumeRateLimit(rateBuckets, clientKey);
  if (!bucket.allowed) {
    const retryAfter = Math.ceil((bucket.resetAt - Date.now()) / 1000);
    res.setHeader("Retry-After", String(retryAfter));
    return res.status(429).json({
      error: "Too many nameplate analyses. Please try again later.",
      retryAfter,
    });
  }
  if (bucket.inFlight >= 2) {
    res.setHeader("Retry-After", "15");
    return res.status(429).json({
      error: "Too many nameplate analyses in progress.",
      retryAfter: 15,
    });
  }
  bucket.inFlight += 1;

  try {
    const result = serverProvider === "anthropic"
      ? await analyzeWithAnthropic({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: NAMEPLATE_VISION_SYSTEM_PROMPT,
        userText: "Upright the plate if the photo is rotated. Extract this motor nameplate into the structured JSON draft. Ignore glare. Never treat MOCP or LRA as FLA. Never steal HP from a catalog/model string. Dual FLA stays in dualFla with fla null. Phase is only 1 or 3 when printed.",
      })
      : await analyzeWithOpenAI({
        image: picked.image.base64,
        mimeType: picked.image.mimeType,
        model: serverModel,
        system: NAMEPLATE_VISION_SYSTEM_PROMPT,
        userText: "Upright the plate if the photo is rotated. Extract this motor nameplate into the structured JSON draft. Ignore glare. Never treat MOCP or LRA as FLA. Never steal HP from a catalog/model string. Dual FLA stays in dualFla with fla null. Phase is only 1 or 3 when printed.",
      });

    return res.json({
      provider: serverProvider,
      model: serverModel,
      analysis: result,
    });
  } catch (error) {
    const failure = visionProviderFailure(error);
    console.error("Nameplate vision provider request failed", error);
    return res.status(failure.status).json({ error: failure.error });
  } finally {
    bucket.inFlight -= 1;
  }
});

export default router;
