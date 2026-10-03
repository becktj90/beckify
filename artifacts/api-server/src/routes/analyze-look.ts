import { Router, type IRouter } from "express";
import {
  LOOK_ASSESSMENT_TEMPERATURE,
  LOOK_COMEDY_TEMPERATURE,
  lookAssessmentMaxTokens,
  lookAssessmentSystemPrompt,
  lookAssessmentUserText,
  lookComedySystemPrompt,
  lookComedyUserText,
  lookVisionMaxTokens,
  mergeLookAssessmentWithComedy,
  resolveLookRoastMode,
  type LookRoastMode,
  type LookVerdict,
} from "../prompts/lookVisionPrompt.js";
import {
  analyzeTextWithAnthropic,
  analyzeTextWithOpenAI,
  analyzeWithAnthropic,
  analyzeWithOpenAI,
  beginSharedVisionRequest,
  configuredModel,
  configuredProvider,
  getClientKey,
  pickImage,
  visionProviderFailure,
} from "../lib/visionClient.js";
import { chargeBudget, logAIUsage, refundBudget, shouldRefundAICharge } from "../lib/usageBudget.js";

interface AnalyzeBody {
  base64Image?: string;
  imageBase64?: string;
  image?: string;
  mimeType?: string;
  provider?: string;
  model?: string;
  task?: string;
  roastMode?: string;
  roast_mode?: string;
}

const serverProvider = configuredProvider();
const serverModel = configuredModel(serverProvider);
const router: IRouter = Router();

function assessmentVerdict(raw: unknown): LookVerdict {
  const folded = String((raw as { verdict?: unknown } | null)?.verdict ?? "").trim().toLowerCase();
  if (
    folded === "looks_good"
    || folded === "mixed"
    || folded === "looks_bad"
    || folded === "no_person"
    || folded === "declined"
  ) {
    return folded;
  }
  return "mixed";
}

async function runAssessment(image: string, mimeType: string): Promise<unknown> {
  const system = lookAssessmentSystemPrompt();
  const userText = lookAssessmentUserText();
  const maxTokens = lookAssessmentMaxTokens();
  const temperature = LOOK_ASSESSMENT_TEMPERATURE;
  if (serverProvider === "anthropic") {
    return analyzeWithAnthropic({
      image,
      mimeType,
      model: serverModel,
      system,
      userText,
      maxTokens,
      temperature,
    });
  }
  return analyzeWithOpenAI({
    image,
    mimeType,
    model: serverModel,
    system,
    userText,
    maxTokens,
    temperature,
  });
}

async function runComedy(mode: LookRoastMode, frozenAssessment: unknown): Promise<unknown> {
  const system = lookComedySystemPrompt(mode);
  const userText = lookComedyUserText(mode, frozenAssessment);
  const maxTokens = lookVisionMaxTokens(mode);
  const temperature = LOOK_COMEDY_TEMPERATURE;
  if (serverProvider === "anthropic") {
    return analyzeTextWithAnthropic({
      model: serverModel,
      system,
      userText,
      maxTokens,
      temperature,
    });
  }
  return analyzeTextWithOpenAI({
    model: serverModel,
    system,
    userText,
    maxTokens,
    temperature,
  });
}

router.post("/analyze-look", async (req, res) => {
  const body = (req.body || {}) as AnalyzeBody;
  const picked = pickImage(body);
  if ("error" in picked) return res.status(picked.status).json({ error: picked.error });

  const roastMode = resolveLookRoastMode(body.roastMode ?? body.roast_mode);
  const clientKey = getClientKey(req);
  const gate = beginSharedVisionRequest(clientKey);
  if (!gate.ok) {
    logAIUsage({ route: "/api/analyze-look", kind: "vision", outcome: gate.reason === "budget" ? "blocked" : "refund", clientKey, units: 1, status: 429 });
    res.setHeader("Retry-After", String(gate.retryAfter));
    const error = gate.reason === "burst"
      ? "Too many look checks in progress."
      : "Too many look checks. Please try again later.";
    return res.status(429).json({ error, retryAfter: gate.retryAfter });
  }

  let textCharged = false;
  try {
    // Pass 1: frozen photo assessment at temp 0 (image).
    const assessment = await runAssessment(picked.image.base64, picked.image.mimeType);
    const verdict = assessmentVerdict(assessment);

    let comedy: unknown = { roast: "" };
    // Pass 2: text-only comedy at higher temp. Skip when there is nothing to roast.
    // Cost: second call has no image tokens. Latency: roughly one extra text completion for adult ratings.
    if (verdict !== "declined" && verdict !== "no_person") {
      const textCharge = chargeBudget("text", clientKey, 1);
      if (!textCharge.allowed) {
        logAIUsage({ route: "/api/analyze-look", kind: "text", outcome: "blocked", clientKey, units: 1, status: 429 });
        res.setHeader("Retry-After", String(textCharge.retryAfter));
        return res.status(429).json({
          error: "Too many text analyses. Please try again later.",
          retryAfter: textCharge.retryAfter,
        });
      }
      textCharged = true;
      comedy = await runComedy(roastMode, assessment);
    }

    const analysis = mergeLookAssessmentWithComedy(assessment, comedy);
    logAIUsage({ route: "/api/analyze-look", kind: "vision", outcome: "ok", clientKey, units: 1, model: serverModel });

    return res.json({
      provider: serverProvider,
      model: serverModel,
      roastMode,
      analysis,
    });
  } catch (error) {
    const failure = visionProviderFailure(error);
    if (shouldRefundAICharge(error)) {
      refundBudget("vision", clientKey, 1);
      if (textCharged) refundBudget("text", clientKey, 1);
      logAIUsage({ route: "/api/analyze-look", kind: "vision", outcome: "refund", clientKey, units: 1, status: failure.status });
    } else {
      logAIUsage({ route: "/api/analyze-look", kind: "vision", outcome: "error", clientKey, units: 1, status: failure.status });
    }
    console.error("Look vision provider request failed", error);
    return res.status(failure.status).json({ error: failure.error });
  } finally {
    gate.release();
  }
});

export default router;
