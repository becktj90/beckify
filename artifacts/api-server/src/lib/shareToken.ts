import { createHmac, timingSafeEqual } from "node:crypto";

export const SHARE_TOOLS = ["voltage-drop", "conduit-fill"] as const;
export type ShareTool = (typeof SHARE_TOOLS)[number];

export type ShareField = { label: string; value: string };

export type SharePayload = {
  v: 1;
  tool: ShareTool;
  contractor: string;
  createdAt: string;
  fields: ShareField[];
};

export const SHARE_LIMITS = {
  contractor: 80,
  fields: 16,
  label: 80,
  value: 120,
  tokenChars: 8_000,
  payloadBytes: 6_000,
} as const;

const CONTROL = /[\u0000-\u001F\u007F]/;

export function cleanShareLine(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  if (CONTROL.test(value)) return null;
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (!trimmed || trimmed.length > max) return null;
  return trimmed;
}

export function validateShareInput(body: unknown):
  | { ok: true; tool: ShareTool; contractor: string; fields: ShareField[] }
  | { ok: false; error: string } {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, error: "Invalid share payload." };
  }
  const row = body as Record<string, unknown>;
  if (typeof row.tool !== "string" || !SHARE_TOOLS.includes(row.tool as ShareTool)) {
    return { ok: false, error: "Unsupported calculation." };
  }
  const contractor = cleanShareLine(row.contractor, SHARE_LIMITS.contractor);
  if (!contractor) return { ok: false, error: "Enter a contractor or company name." };
  if (!Array.isArray(row.fields) || row.fields.length < 1 || row.fields.length > SHARE_LIMITS.fields) {
    return { ok: false, error: "Invalid calculation snapshot." };
  }
  const fields: ShareField[] = [];
  for (const item of row.fields) {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      return { ok: false, error: "Invalid calculation snapshot." };
    }
    const field = item as Record<string, unknown>;
    const label = cleanShareLine(field.label, SHARE_LIMITS.label);
    const value = cleanShareLine(field.value, SHARE_LIMITS.value);
    if (!label || !value) return { ok: false, error: "Invalid calculation snapshot." };
    fields.push({ label, value });
  }
  return { ok: true, tool: row.tool as ShareTool, contractor, fields };
}

export function buildSharePayload(
  input: { tool: ShareTool; contractor: string; fields: ShareField[] },
  createdAt = new Date().toISOString(),
): SharePayload {
  return {
    v: 1,
    tool: input.tool,
    contractor: input.contractor,
    createdAt,
    fields: input.fields,
  };
}

function payloadBytes(payload: SharePayload): Buffer {
  return Buffer.from(JSON.stringify(payload), "utf8");
}

export function signShareToken(payload: SharePayload, secret: string): string {
  if (secret.length < 16) throw new Error("SHARE_HMAC_SECRET is too short.");
  const json = payloadBytes(payload);
  if (json.length > SHARE_LIMITS.payloadBytes) throw new Error("Share payload is too large.");
  const sig = createHmac("sha256", secret).update(json).digest();
  return `${json.toString("base64url")}.${sig.toString("base64url")}`;
}

function decodePayload(token: string): { json: Buffer; sig: Buffer } | null {
  if (token.length < 8 || token.length > SHARE_LIMITS.tokenChars) return null;
  if (!/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) return null;
  const dot = token.indexOf(".");
  const json = Buffer.from(token.slice(0, dot), "base64url");
  const sig = Buffer.from(token.slice(dot + 1), "base64url");
  if (json.length < 2 || json.length > SHARE_LIMITS.payloadBytes || sig.length !== 32) return null;
  return { json, sig };
}

export function verifyShareToken(token: string, secret: string): SharePayload | null {
  if (secret.length < 16) return null;
  const parts = decodePayload(token);
  if (!parts) return null;
  const expected = createHmac("sha256", secret).update(parts.json).digest();
  if (expected.length !== parts.sig.length || !timingSafeEqual(expected, parts.sig)) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(parts.json.toString("utf8"));
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  const row = parsed as Record<string, unknown>;
  if (row.v !== 1 || typeof row.createdAt !== "string" || row.createdAt.length > 40) return null;
  const checked = validateShareInput({
    tool: row.tool,
    contractor: row.contractor,
    fields: row.fields,
  });
  if (!checked.ok) return null;
  return {
    v: 1,
    tool: checked.tool,
    contractor: checked.contractor,
    createdAt: row.createdAt,
    fields: checked.fields,
  };
}

export function sharePageURL(token: string, origin = process.env["SHARE_PUBLIC_ORIGIN"] ?? "https://beckify.com"): string {
  const base = origin.replace(/\/$/, "");
  return `${base}/share/${token}`;
}

export function toolTitle(tool: ShareTool): string {
  return tool === "voltage-drop" ? "Voltage Drop" : "Conduit Fill";
}
