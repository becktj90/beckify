import { Router, type IRouter } from "express";
import { NAMEPLATE_VISION_SYSTEM_PROMPT } from "../prompts/nameplateVisionPrompt.js";
import {
  analyzeWithAnthropic,
  analyzeWithOpenAI,
  beginSharedVisionRequest,
  configuredModel,
  configuredProvider,
  getClientKey,
  pickImage,
  visionProviderFailure,
} from "../lib/visionClient.js";
import { logAIUsage, refundBudget, shouldRefundAICharge } from "../lib/usageBudget.js";

interface AnalyzeBody {
  base64Image?: string;
  imageBase64?: string;
  image?: string;
  mimeType?: string;
  provider?: string;
  model?: string;
  task?: string;
}

const serverProvider = configuredProvider();
const serverModel = configuredModel(serverProvider);
const router: IRouter = Router();

router.post("/analyze-nameplate", async (req, res) => {
  const body = (req.body || {}) as AnalyzeBody;
  const picked = pickImage(body);
  if ("error" in picked) return res.status(picked.status).json({ error: picked.error });

  const clientKey = getClientKey(req);
  const gate = beginSharedVisionRequest(clientKey);
  if (!gate.ok) {
    logAIUsage({ route: "/api/analyze-nameplate", kind: "vision", outcome: gate.reason === "budget" ? "blocked" : "refund", clientKey, units: 1, status: 429 });
    res.setHeader("Retry-After", String(gate.retryAfter));
    const error = gate.reason === "burst"
      ? "Too many nameplate analyses in progress."
      : "Too many nameplate analyses. Please try again later.";
    return res.status(429).json({ error, retryAfter: gate.retryAfter });
  }

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

    logAIUsage({ route: "/api/analyze-nameplate", kind: "vision", outcome: "ok", clientKey, units: 1, model: serverModel });
    return res.json({
      provider: serverProvider,
      model: serverModel,
      analysis: result,
    });
  } catch (error) {
    const failure = visionProviderFailure(error);
    if (shouldRefundAICharge(error)) {
      refundBudget("vision", clientKey, 1);
      logAIUsage({ route: "/api/analyze-nameplate", kind: "vision", outcome: "refund", clientKey, units: 1, status: failure.status });
    } else {
      logAIUsage({ route: "/api/analyze-nameplate", kind: "vision", outcome: "error", clientKey, units: 1, status: failure.status });
    }
    console.error("Nameplate vision provider request failed", error);
    return res.status(failure.status).json({ error: failure.error });
  } finally {
    gate.release();
  }
});

export default router;
