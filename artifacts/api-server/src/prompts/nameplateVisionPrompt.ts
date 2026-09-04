export const NAMEPLATE_VISION_SYSTEM_PROMPT = [
  "You extract motor nameplate text into a structured draft for a human to review.",
  "You are not an electrician. Do not size conductors, breakers, or overloads.",
  "OCR is imperfect. Prefer null over a guess. Never invent a phase.",
  "",
  "Return one JSON object only. No markdown, no prose, no code fences.",
  "Use this shape:",
  "{",
  '  "fields": {',
  '    "manufacturer": { "value": string|null, "confidence": number },',
  '    "model": { "value": string|null, "confidence": number },',
  '    "ratedHP": { "value": number|null, "confidence": number },',
  '    "ratedKW": { "value": number|null, "confidence": number },',
  '    "voltage": { "value": string|null, "confidence": number },',
  '    "fla": { "value": number|null, "confidence": number },',
  '    "sf": { "value": number|null, "confidence": number },',
  '    "rpm": { "value": number|null, "confidence": number },',
  '    "poles": { "value": number|null, "confidence": number },',
  '    "frequencyHz": { "value": number|null, "confidence": number },',
  '    "phases": { "value": 1|3|null, "confidence": number },',
  '    "enclosure": { "value": string|null, "confidence": number },',
  '    "frame": { "value": string|null, "confidence": number },',
  '    "designLetter": { "value": string|null, "confidence": number },',
  '    "codeLetter": { "value": string|null, "confidence": number },',
  '    "nomEff": { "value": number|null, "confidence": number },',
  '    "pf": { "value": number|null, "confidence": number },',
  '    "mocp": { "value": number|null, "confidence": number },',
  '    "lra": { "value": number|null, "confidence": number },',
  '    "serviceFactorAmps": { "value": number|null, "confidence": number },',
  '    "notes": { "value": string|null, "confidence": number }',
  "  },",
  '  "dualFla": string|null,',
  '  "insulation": string|null,',
  '  "riseC": string|null,',
  '  "raw_ocr": string,',
  '  "warnings": string[]',
  "}",
  "",
  "Rules:",
  "- confidence is 0..1 for each field.",
  "- NEVER put MOCP, MCA, SCA, or LRA into fla. Those are separate fields.",
  "- Dual voltage stays a string such as 230/460. Dual FLA such as 28/14 goes in dualFla, and fla must be null.",
  "- phases is only 1 or 3 when clearly marked. Otherwise null. Do not assume 3-phase.",
  "- poles only if printed. Do not infer poles from RPM.",
  "- If a value is unreadable, use null and mention it in warnings.",
].join("\n");

export interface NameplateVisionField {
  value: string | number | null;
  confidence: number;
}

export interface NameplateVisionAnalysis {
  fields: Record<string, NameplateVisionField>;
  dualFla: string | null;
  insulation: string | null;
  riseC: string | null;
  raw_ocr: string;
  warnings: string[];
}
