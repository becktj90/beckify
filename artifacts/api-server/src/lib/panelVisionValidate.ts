/**
 * Validate / normalize panel vision JSON before it leaves the API.
 * Prefer null over invented values. Never treat trip as loadAmps.
 */

export type PanelVisionField = { value: string | number | null; confidence: number };

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
    busAmps?: PanelVisionField;
    feederAmps?: PanelVisionField;
    phases?: PanelVisionField;
    location?: PanelVisionField;
  };
  slotCount?: number | null;
  circuits: PanelVisionCircuit[];
  raw_ocr: string;
  warnings: string[];
}

function asField(raw: unknown, preferNumber = false): PanelVisionField {
  if (raw == null) return { value: null, confidence: 0 };
  if (typeof raw === "object" && !Array.isArray(raw)) {
    const obj = raw as Record<string, unknown>;
    const value = obj.value === undefined ? null : (obj.value as string | number | null);
    const confidence = typeof obj.confidence === "number" && Number.isFinite(obj.confidence)
      ? Math.min(1, Math.max(0, obj.confidence))
      : 0;
    if (preferNumber && typeof value === "string" && value.trim() !== "") {
      const n = Number(value);
      if (Number.isFinite(n)) return { value: n, confidence };
    }
    return { value: value ?? null, confidence };
  }
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return { value: raw, confidence: 0.5 };
  }
  if (typeof raw === "string") {
    return { value: raw, confidence: 0.5 };
  }
  return { value: null, confidence: 0 };
}

function asCircuit(raw: unknown): PanelVisionCircuit | null {
  if (!raw || typeof raw !== "object") return null;
  const src = raw as Record<string, unknown>;
  const fields = (src.fields && typeof src.fields === "object"
    ? (src.fields as Record<string, unknown>)
    : src);
  const circuit = asField(fields.circuit);
  const description = asField(fields.description ?? fields.name);
  const trip = asField(fields.trip, true);
  const poles = asField(fields.poles, true);
  const notes = asField(fields.notes);
  // Trip is never a reviewed load.
  const loadAmps: PanelVisionField = { value: null, confidence: 0 };
  if (
    circuit.value == null
    && description.value == null
    && trip.value == null
    && poles.value == null
    && notes.value == null
  ) {
    return null;
  }
  return { circuit, description, trip, poles, loadAmps, notes };
}

export function validatePanelVisionAnalysis(raw: unknown): {
  ok: true;
  analysis: PanelVisionAnalysis;
} | {
  ok: false;
  error: string;
} {
  if (raw == null || typeof raw !== "object") {
    return { ok: false, error: "Panel analysis must be a JSON object." };
  }
  const src = raw as Record<string, unknown>;
  const panelRaw = (src.panel && typeof src.panel === "object")
    ? (src.panel as Record<string, unknown>)
    : {};
  const circuitsIn = Array.isArray(src.circuits)
    ? src.circuits
    : (Array.isArray(src.rows) ? src.rows : []);
  const circuits: PanelVisionCircuit[] = [];
  for (const item of circuitsIn.slice(0, 84)) {
    const circuit = asCircuit(item);
    if (circuit) circuits.push(circuit);
  }
  let slotCount: number | null = null;
  const slotRaw = src.slotCount ?? src.slot_count ?? panelRaw.slotCount ?? panelRaw.spaces;
  if (typeof slotRaw === "number" && Number.isFinite(slotRaw) && slotRaw >= 6) {
    slotCount = Math.min(84, Math.round(slotRaw));
  } else if (typeof slotRaw === "object" && slotRaw && typeof (slotRaw as any).value === "number") {
    const n = (slotRaw as any).value;
    if (Number.isFinite(n) && n >= 6) slotCount = Math.min(84, Math.round(n));
  }

  const warnings = Array.isArray(src.warnings)
    ? src.warnings.map(String).filter(Boolean)
    : [];
  if (slotCount != null && circuits.length > 0 && circuits.length < slotCount) {
    warnings.push(`Incomplete coverage: ${circuits.length} of ${slotCount} slots in this draft.`);
  }
  const rawOcr = typeof src.raw_ocr === "string"
    ? src.raw_ocr
    : (typeof src.rawOCR === "string" ? src.rawOCR : (typeof src.rawText === "string" ? src.rawText : ""));

  const analysis: PanelVisionAnalysis = {
    panel: {
      name: asField(panelRaw.name),
      voltage: asField(panelRaw.voltage),
      mainAmps: asField(panelRaw.mainAmps ?? panelRaw.main, true),
      busAmps: asField(panelRaw.busAmps ?? panelRaw.busRating, true),
      feederAmps: asField(panelRaw.feederAmps ?? panelRaw.feederRating, true),
      phases: asField(panelRaw.phases, true),
      location: asField(panelRaw.location),
    },
    slotCount,
    circuits,
    raw_ocr: rawOcr,
    warnings,
  };
  return { ok: true, analysis };
}

/** In-memory idempotency for identical Analyze retries (no photo bytes logged). */
const idempotencyCache = new Map<string, { expires: number; body: unknown }>();
const IDEMPOTENCY_TTL_MS = 10 * 60 * 1000;

export function rememberIdempotent(key: string | undefined, body: unknown): void {
  if (!key || key.length < 8 || key.length > 128) return;
  idempotencyCache.set(key, { expires: Date.now() + IDEMPOTENCY_TTL_MS, body });
  if (idempotencyCache.size > 200) {
    const now = Date.now();
    for (const [k, v] of idempotencyCache) {
      if (v.expires < now) idempotencyCache.delete(k);
    }
  }
}

export function recallIdempotent(key: string | undefined): unknown | null {
  if (!key) return null;
  const hit = idempotencyCache.get(key);
  if (!hit) return null;
  if (hit.expires < Date.now()) {
    idempotencyCache.delete(key);
    return null;
  }
  return hit.body;
}

export function panelVisionMetrics(input: {
  view: string;
  provider: string;
  model: string;
  ok: boolean;
  circuitCount: number;
  durationMs: number;
  idempotentHit?: boolean;
}): void {
  // Metrics only — never log photo bytes or OCR transcripts.
  console.info("[panel-vision]", JSON.stringify({
    event: "analyze_panel",
    view: input.view,
    provider: input.provider,
    model: input.model,
    ok: input.ok,
    circuitCount: input.circuitCount,
    durationMs: input.durationMs,
    idempotentHit: !!input.idempotentHit,
  }));
}

export async function withRetries<T>(
  run: () => Promise<T>,
  opts: { attempts?: number; label?: string } = {},
): Promise<T> {
  const attempts = opts.attempts ?? 2;
  let lastError: unknown;
  for (let i = 0; i < attempts; i += 1) {
    try {
      return await run();
    } catch (error) {
      lastError = error;
      if (i + 1 >= attempts) break;
    }
  }
  throw lastError;
}
