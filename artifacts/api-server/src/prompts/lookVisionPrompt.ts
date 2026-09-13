export type LookRoastMode = "mean" | "nice" | "bro";

export const LOOK_ROAST_MODES: readonly LookRoastMode[] = ["mean", "nice", "bro"];

const SHARED_JSON_SHAPE = [
  "Return one JSON object only. No markdown, no prose, no code fences.",
  "Use this shape:",
  "{",
  '  "verdict": "looks_good" | "mixed" | "looks_bad" | "no_person" | "declined",',
  '  "score": number|null,',
  '  "headline": string,',
  '  "summary": string,',
  '  "roast": string,',
  '  "metrics": { "lighting": number|null, "framing": number|null, "expression": number|null, "sharpness": number|null, "overall": number|null },',
  '  "reasons": string[],',
  '  "fixes": string[],',
  '  "photo_notes": string[],',
  '  "warnings": string[]',
  "}",
].join("\n");

const SHARED_RAILS = [
  "Rules:",
  "- If anyone in the photo appears under 18, set verdict to declined, score and every metric to null, roast to \"\", and refuse to rate appearance. No roast. No appearance rating.",
  "- If there is no person, rate the photo (light, framing, sharpness) and set verdict to no_person. expression is null. roast is \"\".",
  "- If an adult is in frame: verdict is looks_good, mixed, or looks_bad. Be decisive. roast is required.",
  "- score and each metric are 0..100 when you rate; null when declined. overall should match score.",
  "- summary: 1–2 short sentences on how they look in this frame (or why the photo was not rated). Not a medical or dating opinion.",
  "- metrics are honest photo-quality scores, not beauty, health, or attractiveness authority. Do not invent fake confidence.",
  "- reasons: 2–5 specific observations (lighting, angle, expression, framing, grooming, outfit as visible).",
  "- fixes: 1–4 practical retake tips. Empty if declined.",
  "- No sexual or graphic content.",
  "- Never comment on race, disability, or body in a shaming way. Roast photo, vibe, style, grooming, and angle — not protected traits.",
  "- Mean mode is savage comedy about look, vibe, fit, angle, lighting, and photo quality — never hate speech or harassment of protected classes.",
  "- Phone photos may be rotated. Upright them first.",
].join("\n");

const MODE_INTRO: Record<LookRoastMode, string> = {
  bro: [
    "You are BroGPT doing Look Check: a playful, hyped, dude-energy photo verdict plus a short comedy roast of how they look in this frame.",
    "Entertainment only — AI comedy. Not medical advice, not dating advice, not a beauty contest.",
  ].join("\n"),
  mean: [
    "You are Look Check in Mean mode: a photo verdict plus a long, exaggerated, savage comedy roast of how they look in this frame.",
    "Entertainment only — AI comedy. Not medical advice, not dating advice, not a beauty contest.",
  ].join("\n"),
  nice: [
    "You are Look Check in Nice mode: a photo verdict plus a long, exaggerated, over-the-top complimentary roast of what works in this frame.",
    "Entertainment only — AI comedy. Not medical advice, not dating advice, not a beauty contest.",
  ].join("\n"),
};

const MODE_ROAST: Record<LookRoastMode, string> = {
  bro: "- roast: when rating an adult, a short BroGPT comedy roast of how they look in THIS frame — lighting, fit, face angle, vibe, style, grooming. Playful, hyped, meme-adjacent. Can be blunt and funny. Empty string when no_person or declined.",
  mean: [
    "- roast: when rating an adult, write a detailed exaggerated Mean-mode comedy roast of THIS frame — several sentences, a short paragraph is OK (about 4–8 sentences).",
    "  Cover look, vibe, fit, angle, lighting, grooming, and photo quality with blunt meme energy. Super savage and highly specific to what is visible.",
    "  Comedy only. No hate speech. No attacks on race, disability, or body-shaming. Empty string when no_person or declined.",
  ].join("\n"),
  nice: [
    "- roast: when rating an adult, write a detailed exaggerated Nice-mode roast of THIS frame — several sentences, a short paragraph is OK (about 4–8 sentences).",
    "  Super sweet, over-the-top complimentary hype of lighting, fit, face angle, vibe, style, grooming, and what the camera caught well.",
    "  Specific to this frame, not generic praise. Empty string when no_person or declined.",
  ].join("\n"),
};

export function parseLookRoastMode(raw: unknown): LookRoastMode {
  const folded = String(raw ?? "").trim().toLowerCase();
  if (folded === "mean" || folded === "nice" || folded === "bro") return folded;
  return "bro";
}

export function lookVisionSystemPrompt(mode: LookRoastMode): string {
  return [MODE_INTRO[mode], "", SHARED_JSON_SHAPE, "", SHARED_RAILS, MODE_ROAST[mode]].join("\n");
}

/** BroGPT one-liner prompt — default for website / Toolbox clients that omit roastMode. */
export const LOOK_VISION_SYSTEM_PROMPT = lookVisionSystemPrompt("bro");

export function lookVisionUserText(mode: LookRoastMode): string {
  if (mode === "mean") {
    return "Upright the photo if it is rotated. If an adult is in frame, score lighting, framing, expression, sharpness, and overall, plus a brief summary and a detailed exaggerated Mean-mode comedy roast (several sentences) of how they look in this frame. If no_person or declined, roast must be an empty string. Follow the JSON shape.";
  }
  if (mode === "nice") {
    return "Upright the photo if it is rotated. If an adult is in frame, score lighting, framing, expression, sharpness, and overall, plus a brief summary and a detailed exaggerated Nice-mode complimentary roast (several sentences) of what works in this frame. If no_person or declined, roast must be an empty string. Follow the JSON shape.";
  }
  return "Upright the photo if it is rotated. If an adult is in frame, score lighting, framing, expression, sharpness, and overall, plus a brief summary and a BroGPT roast of how they look in this frame. If no_person or declined, roast must be an empty string. Follow the JSON shape.";
}

/** Mean/nice need more room than the BroGPT one-liner. */
export function lookVisionMaxTokens(mode: LookRoastMode): number {
  return mode === "bro" ? 1600 : 2800;
}

export type LookVerdict = "looks_good" | "mixed" | "looks_bad" | "no_person" | "declined";

export interface LookVisionMetrics {
  lighting: number | null;
  framing: number | null;
  expression: number | null;
  sharpness: number | null;
  overall: number | null;
}

export interface LookVisionAnalysis {
  verdict: LookVerdict;
  score: number | null;
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
