export type LookRoastMode = "mean" | "nice" | "bro";

/** Client may send surprise; server resolves to mean or nice. Older clients keep mean/nice/bro. */
export type LookRoastModeInput = LookRoastMode | "surprise";

export const LOOK_ROAST_MODES: readonly LookRoastMode[] = ["mean", "nice", "bro"];

/** Temp 0 for frozen photo assessment (scores/verdict/retake). */
export const LOOK_ASSESSMENT_TEMPERATURE = 0;

/**
 * Comedy-only text pass. Raised carefully above 0 so roasts are wilder without
 * touching assessment scores. Keep below 1.0 to limit total gibberish.
 */
export const LOOK_COMEDY_TEMPERATURE = 0.9;

const ASSESSMENT_JSON_SHAPE = [
  "Return one JSON object only. No markdown, no prose, no code fences.",
  "Use this shape:",
  "{",
  '  "verdict": "looks_good" | "mixed" | "looks_bad" | "no_person" | "declined",',
  '  "score": number|null,',
  '  "lookScore": number|null,',
  '  "headline": string,',
  '  "summary": string,',
  '  "roast": "",',
  '  "metrics": { "lighting": number|null, "framing": number|null, "expression": number|null, "sharpness": number|null, "outfit": number|null, "overall": number|null },',
  '  "reasons": string[],',
  '  "fixes": string[],',
  '  "photo_notes": string[],',
  '  "warnings": string[]',
  "}",
].join("\n");

const ASSESSMENT_RAILS = [
  "You are Look Check photo assessment only. Honest, specific, field-plain.",
  "This pass is NOT comedy. Do not roast, hype, insult, or compliment for laughs.",
  "Set roast to an empty string always on this pass.",
  "Rules:",
  "- If anyone in the photo appears under 18, set verdict to declined, score and lookScore and every metric to null, roast to \"\", and refuse to rate appearance.",
  "- If there is no person, rate the photo (light, framing, sharpness, outfit if visible clothing/props) and set verdict to no_person. expression is null. roast is \"\". lookScore is null.",
  "- If an adult is in frame: verdict is looks_good, mixed, or looks_bad. Be decisive.",
  "- score and each metric are 0..100 when you rate; null when declined. overall should match score.",
  "- lookScore is an integer 1..10 when an adult is in frame; null when declined or no_person. Score THIS frame only: style, vibe, fit, grooming, angle, lighting, and photo quality — never race, disability, body-shame, health, dating worth, or protected traits.",
  "- Metrics are photo-quality / presentation scores for THIS frame — never attractiveness, beauty, health, dating worth, or body-shaming scores.",
  "- Score lighting (exposure + light quality), framing (angle + crop), sharpness, expression (subjective face/energy in frame), outfit (clothes/grooming as visible), overall.",
  "- summary: 1–2 short factual sentences on how the photo reads (or why it was not rated). Not medical or dating advice.",
  "- reasons: 2–5 specific observations covering lighting/exposure, framing/angle, sharpness, expression, outfit as visible.",
  "- fixes: exactly 2 or 3 practical retake tips when rating an adult or no_person photo. Empty if declined. Keep tips honest even if the shot is strong.",
  "- No sexual or graphic content.",
  "- Never comment on race, disability, or body in a shaming way.",
  "- Phone photos may be rotated. Upright them first.",
  "- A great photo can still get blunt notes. A weak photo still gets accurate retake advice.",
].join("\n");

const COMEDY_JSON_SHAPE = [
  "Return one JSON object only. No markdown, no prose, no code fences.",
  'Use this exact shape: { "roast": string }',
].join("\n");

const COMEDY_SHARED_RAILS = [
  "You write ONLY the comedy roast string for Look Check.",
  "The photo assessment below is FROZEN. Do not change scores, lookScore, verdict, summary, reasons, or retake tips.",
  "Do not contradict the factual assessment. Comedy can be savage or over-the-top hype about the SAME frame the assessment describes.",
  "A strong photo can get a brutal roast. A weak photo can get outrageous hype — still grounded in what is visible.",
  "Profane, specific, hilarious, unpredictable is encouraged. Comedy may make people uncomfortable.",
  "Grotesque comic exaggeration of THIS frame is the job: style, vibe, fit, grooming, angle, lighting, photo quality, and energy.",
  "Never attack race, disability, or body-shame protected traits. No slurs. No hate. No threats.",
  "No sexual or graphic content. Do not sexualize anyone. Do not describe sex acts, genitals, or gore.",
  "Do not print a mode name. Do not mention lookScore, any numeric score, or a 1–10 rating in the roast. Plain spoken sentences only — this string is read aloud.",
  "If verdict is declined or no_person, roast MUST be an empty string.",
].join("\n");

const MODE_COMEDY: Record<LookRoastMode, string> = {
  bro: [
    "Tone: BroGPT — short, hyped, dude-energy one-liner (1–3 sentences).",
    "Playful blunt comedy of THIS frame. Meme-adjacent. Empty string when no_person or declined.",
  ].join("\n"),
  mean: [
    "Tone: savage and delighted. The speaker is enjoying the cruelty. Brutal funny roast. Not a cartoon, not goofy, not a pun list.",
    "Write a detailed grotesque comic exaggeration of THIS frame — style, vibe, fit, grooming, angle, lighting, and photo quality. About 4–6 spoken sentences.",
    "Profanity should be heavy, specific, and inventive. Delighted cruelty about the photograph, never a threat.",
    "Still comedy, never hate speech. Empty string when no_person or declined.",
  ].join("\n"),
  nice: [
    "Tone: filthy-sweet hype. Over-the-top complimentary adoration that is delighted, unhinged, and still kind in intent. Not an insult and not a cartoon.",
    "Write a detailed grotesque comic exaggeration that lands as wild praise of THIS frame — style, vibe, fit, grooming, angle, lighting, and photo quality. About 4–6 spoken sentences.",
    "Profane OK when it lands as wild praise. Specific to this frame, not generic. Empty string when no_person or declined.",
  ].join("\n"),
};

export function parseLookRoastMode(raw: unknown): LookRoastMode | "surprise" {
  const folded = String(raw ?? "").trim().toLowerCase();
  if (folded === "mean" || folded === "nice" || folded === "bro" || folded === "surprise") {
    return folded;
  }
  // Older clients that omit roastMode stay on bro.
  return "bro";
}

/** Resolve surprise (or passthrough) to a concrete mean|nice|bro mode. */
export function resolveLookRoastMode(
  raw: unknown,
  random: () => number = Math.random,
): LookRoastMode {
  const parsed = parseLookRoastMode(raw);
  if (parsed === "surprise") {
    return random() < 0.5 ? "mean" : "nice";
  }
  return parsed;
}

export function lookAssessmentSystemPrompt(): string {
  return [ASSESSMENT_RAILS, "", ASSESSMENT_JSON_SHAPE].join("\n");
}

export function lookAssessmentUserText(): string {
  return [
    "Upright the photo if it is rotated.",
    "Assess this frame only: lighting/exposure, framing/angle, sharpness, expression (subjective), outfit, overall score,",
    "lookScore (1–10 for style/vibe/fit/grooming/angle/lighting/photo when an adult is in frame; null if declined or no_person),",
    "verdict, brief factual summary, 2–5 reasons, and 2–3 retake tips when rating.",
    "roast must be an empty string. Follow the JSON shape.",
  ].join(" ");
}

export function lookComedySystemPrompt(mode: LookRoastMode): string {
  return [COMEDY_SHARED_RAILS, "", MODE_COMEDY[mode], "", COMEDY_JSON_SHAPE].join("\n");
}

export function lookComedyUserText(mode: LookRoastMode, frozenAssessment: unknown): string {
  const frozen = JSON.stringify(frozenAssessment);
  if (mode === "mean") {
    return `Frozen photo assessment JSON (do not change it):\n${frozen}\n\nWrite only the savage delighted roast for an adult rating, or "" if declined/no_person. Do not name the mode. Follow the JSON shape.`;
  }
  if (mode === "nice") {
    return `Frozen photo assessment JSON (do not change it):\n${frozen}\n\nWrite only the filthy-sweet hype for an adult rating, or "" if declined/no_person. Do not name the mode. Follow the JSON shape.`;
  }
  return `Frozen photo assessment JSON (do not change it):\n${frozen}\n\nWrite only a short BroGPT comedy roast for an adult rating, or "" if declined/no_person. Follow the JSON shape.`;
}

export function lookVisionMaxTokens(mode: LookRoastMode): number {
  return mode === "bro" ? 900 : 1800;
}

export function lookAssessmentMaxTokens(): number {
  return 1600;
}

/** @deprecated Single-call prompt kept for tests/docs that reference the old export. Prefer assessment + comedy. */
export function lookVisionSystemPrompt(mode: LookRoastMode): string {
  return [
    mode === "bro"
      ? "You are BroGPT doing Look Check: honest photo assessment plus a short comedy roast."
      : mode === "mean"
        ? "You are Look Check in Mean mode: honest photo assessment plus a brutal funny roast."
        : "You are Look Check in Nice mode: honest photo assessment plus outrageous complimentary hype.",
    "Entertainment only. Not medical advice, not dating advice, not a beauty contest.",
    "",
    ASSESSMENT_JSON_SHAPE.replace('"roast": "",', '  "roast": string,'),
    "",
    ASSESSMENT_RAILS.replace("Set roast to an empty string always on this pass.", MODE_COMEDY[mode]),
  ].join("\n");
}

/** @deprecated */
export function lookVisionUserText(mode: LookRoastMode): string {
  return lookComedyUserText(mode, { note: "single-call fallback — prefer two-pass API" });
}

/** BroGPT one-liner prompt — default export for older docs. */
export const LOOK_VISION_SYSTEM_PROMPT = lookVisionSystemPrompt("bro");

export type LookVerdict = "looks_good" | "mixed" | "looks_bad" | "no_person" | "declined";

export interface LookVisionMetrics {
  lighting: number | null;
  framing: number | null;
  expression: number | null;
  sharpness: number | null;
  outfit: number | null;
  overall: number | null;
}

export interface LookVisionAnalysis {
  verdict: LookVerdict;
  score: number | null;
  /** Integer 1–10 look score for this frame; null when declined, no_person, or empty roast. */
  lookScore: number | null;
  headline: string;
  summary: string;
  roast: string;
  metrics: LookVisionMetrics;
  reasons: string[];
  fixes: string[];
  photo_notes: string[];
  warnings: string[];
}

/** Empty roast when the photo is not an adult rating. */
export function normalizeLookRoast(raw: unknown, verdict: LookVerdict): string {
  if (verdict === "declined" || verdict === "no_person") return "";
  if (raw == null) return "";
  return String(raw).trim();
}

function asScore(value: unknown): number | null {
  if (value == null || value === "") return null;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.max(0, Math.min(100, Math.round(n)));
}

/** Integer look score 1..10. */
export function asTenLookScore(value: unknown): number | null {
  if (value == null || value === "") return null;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.max(1, Math.min(10, Math.round(n)));
}

/** Fallback when the model omits lookScore: map photo assessment 0..100 → 1..10. */
export function lookScoreFromPhotoScore(score: number | null): number | null {
  if (score == null) return null;
  return Math.max(1, Math.min(10, Math.round(score / 10)));
}

function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean);
}

function asVerdict(raw: unknown): LookVerdict {
  const folded = String(raw ?? "").trim().toLowerCase();
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

/** Freeze assessment fields; overlay comedy roast only. Comedy cannot change scores/verdict/retake. */
export function mergeLookAssessmentWithComedy(
  assessmentRaw: unknown,
  comedyRaw: unknown,
): LookVisionAnalysis {
  const assessment = (assessmentRaw && typeof assessmentRaw === "object")
    ? assessmentRaw as Record<string, unknown>
    : {};
  const metricsSrc = (assessment.metrics && typeof assessment.metrics === "object")
    ? assessment.metrics as Record<string, unknown>
    : assessment;
  const verdict = asVerdict(assessment.verdict);
  let score = asScore(assessment.score);
  if (verdict === "declined") score = null;

  const metrics: LookVisionMetrics = {
    lighting: asScore(metricsSrc.lighting),
    framing: asScore(metricsSrc.framing),
    expression: asScore(metricsSrc.expression),
    sharpness: asScore(metricsSrc.sharpness ?? metricsSrc.focus),
    outfit: asScore(metricsSrc.outfit),
    overall: asScore(metricsSrc.overall),
  };
  if (metrics.overall == null) metrics.overall = score;
  if (verdict === "declined") {
    metrics.lighting = null;
    metrics.framing = null;
    metrics.expression = null;
    metrics.sharpness = null;
    metrics.outfit = null;
    metrics.overall = null;
  } else if (verdict === "no_person") {
    metrics.expression = null;
  }

  const comedy = (comedyRaw && typeof comedyRaw === "object")
    ? comedyRaw as Record<string, unknown>
    : {};
  const roast = normalizeLookRoast(comedy.roast ?? assessment.roast, verdict);

  let summary = String(assessment.summary ?? assessment.brief ?? "").trim();
  if (verdict === "declined" && !summary) {
    summary = String(assessment.headline ?? "").trim();
  }

  // lookScore comes from the frozen assessment only — never the comedy pass —
  // so mean|nice cannot bias or reveal the hidden coin. Empty roast → no score.
  let lookScore: number | null = null;
  if (verdict !== "declined" && verdict !== "no_person" && roast) {
    lookScore = asTenLookScore(assessment.lookScore ?? assessment.look_score);
    if (lookScore == null) lookScore = lookScoreFromPhotoScore(score);
  }

  return {
    verdict,
    score,
    lookScore,
    headline: String(assessment.headline ?? ""),
    summary,
    roast,
    metrics,
    reasons: asStringList(assessment.reasons),
    fixes: asStringList(assessment.fixes),
    photo_notes: asStringList(assessment.photo_notes ?? assessment.photoNotes),
    warnings: asStringList(assessment.warnings),
  };
}
