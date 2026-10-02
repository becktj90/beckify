import { Router, type IRouter } from "express";
import { BREAKER_VISION_SYSTEM_PROMPT, PANEL_VISION_SYSTEM_PROMPT } from "../prompts/panelVisionPrompt.js";
import {
  PANEL_MAX_OUTPUT_TOKENS,
  PANEL_PROVIDER_TIMEOUT_MS,
  analyzeWithAnthropic,
  analyzeWithOpenAI,
  configuredModel,
  configuredProvider,
  consumeRateLimit,
  getClientKey,
  pickImage,
  visionProviderFailure,
} from "../lib/visionClient.js";
import {
  panelVisionMetrics,
  recallIdempotent,
  rememberIdempotent,
  validatePanelVisionAnalysis,
  withRetries,
} from "../lib/panelVisionValidate.js";

interface AnalyzeBody {
  base64Image?: string;
  imageBase64?: string;
  image?: string;
  mimeType?: string;
  provider?: string;
  model?: string;
  task?: string;
  view?: string;
  idempotencyKey?: string;
}

const rateBuckets = new Map<string, { count: number; resetAt: number; inFlight: number }>();
const serverProvider = configuredProvider();
const serverModel = configuredModel(serverProvider);
const router: IRouter = Router();

/* Optional Enhance path for panel-schedule / panel-power-study. On-device
   Tesseract remains the default when Enhance is off. Client model/provider
   hints are ignored — the server controls the vision model. */
router.post("/analyze-panel", async (req, res) => {
  const started = Date.now();
  const body = (req.body || {}) as AnalyzeBody;
  const picked = pickImage(body);
  if ("error" in picked) return res.status(picked.status).json({ error: picked.error });

  const idempotencyKey = String(
    body.idempotencyKey
      || req.get("idempotency-key")
      || req.get("x-idempotency-key")
      || "",
  ).trim() || undefined;
  const cached = recallIdempotent(idempotencyKey);
  if (cached) {
    panelVisionMetrics({
      view: String(body.view || "directory"),
      provider: serverProvider,
      model: serverModel,
      ok: true,
      circuitCount: Array.isArray((cached as any)?.analysis?.circuits)
        ? (cached as any).analysis.circuits.length
        : 0,
      durationMs: Date.now() - started,
      idempotentHit: true,
    });
    return res.json(cached);
  }

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

  const breakerView = String(body.view || "").toLowerCase() === "breakers";
  const userText = breakerView
    ? [
      "Count dead-front breaker spaces and read handle amp stamps into structured JSON.",
      "Upright rotated phone photos first. slotCount is the visible space count. Do not invent missing spaces.",
      "description stays null. Do not copy trip into load amps. Cover-on dead-front only.",
      "Prefer null over guesses. Keep SPARE/SPACE/unreadable distinct when printed.",
    ].join(" ")
    : [
      "Extract the printed panel directory into structured JSON.",
      "Upright rotated phone photos first. Emit one circuit entry per odd/even number you can actually read.",
      "This frame may be only part of a large card — do not invent missing circuits or renumber from 1.",
      "Prefer handwritten corrections over crossed-out print. Do not copy breaker trip into load amps.",
      "phases is 1 or 3 only when printed. Never assume 3-phase. Separate mainAmps, busAmps, feederAmps when printed.",
      "Tandem 1A/1B stay distinct. Multi-pole breakers stay one description group.",
    ].join(" ");
  const system = breakerView ? BREAKER_VISION_SYSTEM_PROMPT : PANEL_VISION_SYSTEM_PROMPT;
  // Ignore client provider/model — server-controlled only.
  void body.provider;
  void body.model;

  try {
    const result = await withRetries(async () => {
      return serverProvider === "anthropic"
        ? await analyzeWithAnthropic({
          image: picked.image.base64,
          mimeType: picked.image.mimeType,
          model: serverModel,
          system,
          userText,
          maxTokens: PANEL_MAX_OUTPUT_TOKENS,
          timeoutMs: PANEL_PROVIDER_TIMEOUT_MS,
        })
        : await analyzeWithOpenAI({
          image: picked.image.base64,
          mimeType: picked.image.mimeType,
          model: serverModel,
          system,
          userText,
          maxTokens: PANEL_MAX_OUTPUT_TOKENS,
          timeoutMs: PANEL_PROVIDER_TIMEOUT_MS,
        });
    }, { attempts: 2, label: "analyze-panel" });

    const validated = validatePanelVisionAnalysis(result);
    if (!validated.ok) {
      panelVisionMetrics({
        view: breakerView ? "breakers" : "directory",
        provider: serverProvider,
        model: serverModel,
        ok: false,
        circuitCount: 0,
        durationMs: Date.now() - started,
      });
      return res.status(502).json({ error: validated.error });
    }

    const payload = {
      provider: serverProvider,
      model: serverModel,
      analysis: validated.analysis,
    };
    rememberIdempotent(idempotencyKey, payload);
    panelVisionMetrics({
      view: breakerView ? "breakers" : "directory",
      provider: serverProvider,
      model: serverModel,
      ok: true,
      circuitCount: validated.analysis.circuits.length,
      durationMs: Date.now() - started,
    });
    return res.json(payload);
  } catch (error) {
    const failure = visionProviderFailure(error);
    // Do not log photo bytes.
    console.error("Panel vision provider request failed", {
      status: failure.status,
      error: failure.error,
      provider: serverProvider,
      model: serverModel,
    });
    panelVisionMetrics({
      view: breakerView ? "breakers" : "directory",
      provider: serverProvider,
      model: serverModel,
      ok: false,
      circuitCount: 0,
      durationMs: Date.now() - started,
    });
    return res.status(failure.status).json({ error: failure.error });
  } finally {
    bucket.inFlight -= 1;
  }
});

export default router;
