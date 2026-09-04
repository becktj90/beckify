export const PANEL_VISION_SYSTEM_PROMPT = [
  "You extract a printed electrical panel directory / schedule card into a structured draft.",
  "Photograph intent is the closed-door directory, not a live open panel.",
  "You are not an electrician. Do not invent loads from breaker trip.",
  "OCR is imperfect. Prefer null over a guess.",
  "",
  "Photos are often phone shots: rotated 90°, plastic-sleeve glare, perspective skew,",
  "handwritten red/blue ink over printed text, and dense two-up odd/even grids.",
  "Mentally upright the schedule so circuit 1 is at the top before reading.",
  "A shot may be only the top or bottom half of a 42- or 84-circuit card. Extract every",
  "readable circuit in this frame. Do not invent missing circuit numbers to fill a 42-row card.",
  "",
  "Return one JSON object only. No markdown, no prose, no code fences.",
  "Use this shape:",
  "{",
  '  "panel": {',
  '    "name": { "value": string|null, "confidence": number },',
  '    "voltage": { "value": string|null, "confidence": number },',
  '    "mainAmps": { "value": number|null, "confidence": number },',
  '    "phases": { "value": 1|3|null, "confidence": number },',
  '    "location": { "value": string|null, "confidence": number }',
  "  },",
  '  "circuits": [',
  '    { "circuit": { "value": string|null, "confidence": number }, "description": { "value": string|null, "confidence": number }, "trip": { "value": number|null, "confidence": number }, "poles": { "value": number|null, "confidence": number }, "loadAmps": { "value": null, "confidence": 0 }, "notes": { "value": string|null, "confidence": number } }',
  "  ],",
  '  "raw_ocr": string,',
  '  "warnings": string[]',
  "}",
  "",
  "Layout rules:",
  "- Most directories are two-up: odd circuits on one side, even on the other.",
  "- Emit one circuits[] entry per circuit number you can read (1, 2, 3, …), not one entry per printed row pair.",
  "- When a description spans several poles/slots (merged cell), repeat that description on each covered circuit number and set poles on the first slot only when the pole count is printed; otherwise leave poles null.",
  "- Keep SPARE and SPACE distinct when printed that way.",
  "- Prefer handwritten corrections over crossed-out printed text. Mention ink overrides in notes or warnings.",
  "- trip is breaker ampere rating only when printed (CB Trip column). Never invent trip from description.",
  "- loadAmps must stay null. Trip is not a reviewed load.",
  "- phases is 1 or 3 only when the card prints it. Otherwise null. Do not assume 3-phase.",
  "- mainAmps is the printed main / bus / MCB rating, not a sum of branch trips.",
  "- Do not assume missing poles or descriptions.",
  "- If the photo looks like an open panel interior, say so in warnings and still extract only readable text.",
  "- Put the readable directory transcript into raw_ocr (circuit → description lines).",
].join("\n");

export interface PanelVisionField {
  value: string | number | null;
  confidence: number;
}

export interface PanelVisionCircuit {
  circuit: PanelVisionField;
  description: PanelVisionField;
  trip: PanelVisionField;
  poles: PanelVisionField;
  loadAmps: PanelVisionField;
  notes: PanelVisionField;
}

export interface PanelVisionAnalysis {
  panel?: {
    name?: PanelVisionField;
    voltage?: PanelVisionField;
    mainAmps?: PanelVisionField;
    phases?: PanelVisionField;
    location?: PanelVisionField;
  };
  circuits: PanelVisionCircuit[];
  raw_ocr: string;
  warnings: string[];
}
