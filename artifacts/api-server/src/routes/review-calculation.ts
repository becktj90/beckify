import { Router, type IRouter } from "express";
const router: IRouter = Router();
const allowedOrigins = new Set((process.env["CORS_ORIGINS"] ?? "https://beckify.com,https://www.beckify.com,http://localhost:3000").split(",").map((value) => value.trim()));

router.post("/review-calculation", async (req, res) => {
  const body = req.body as { calculation?: unknown; values?: unknown; units?: unknown };
  if (typeof body.calculation !== "string" || body.calculation.length < 1 || body.calculation.length > 160 || !isNumberRecord(body.values)) return res.status(400).json({ error: "Invalid calculation payload." });
  const origin = req.get("origin");
  if (origin && !allowedOrigins.has(origin)) return res.status(403).json({ error: "Origin not allowed." });
  res.setHeader("Content-Type", "text/event-stream; charset=utf-8"); res.setHeader("Cache-Control", "no-cache, no-transform"); res.setHeader("Connection", "keep-alive");
  const fallback = reviewFor(body.calculation, body.values);
  const key = process.env["OPENAI_API_KEY"];
  if (!key) { res.write(`data: ${JSON.stringify(fallback)}\n\n`); return res.end(); }
  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(20_000), body: JSON.stringify({ model: process.env["REVIEW_MODEL"] ?? "gpt-4o-mini", temperature: 0.2, response_format: { type: "json_object" }, messages: [{ role: "system", content: "You are a concise senior electrical engineer. Return only JSON with verdict (sound, check, or unsafe), snide_summary (1-2 witty sentences), and fix_recommendation (one technical sentence). Be candid, never reckless, and do not invent code requirements." }, { role: "user", content: JSON.stringify({ calculation: body.calculation, values: body.values }) }] }) });
    if (!response.ok) throw new Error("provider error");
    const payload = await response.json() as { choices?: Array<{ message?: { content?: string } }> }; const candidate = JSON.parse(payload.choices?.[0]?.message?.content ?? "{}");
    res.write(`data: ${JSON.stringify(isReview(candidate) ? candidate : fallback)}\n\n`);
  } catch { res.write(`data: ${JSON.stringify(fallback)}\n\n`); }
  return res.end();
});

function isNumberRecord(value: unknown): value is Record<string, number> { return !!value && typeof value === "object" && Object.values(value).every((item) => typeof item === "number" && Number.isFinite(item)); }
function isReview(value: unknown): value is { verdict: "sound" | "check" | "unsafe"; snide_summary: string; fix_recommendation: string } { if (!value || typeof value !== "object") return false; const row = value as Record<string, unknown>; return (row.verdict === "sound" || row.verdict === "check" || row.verdict === "unsafe") && typeof row.snide_summary === "string" && row.snide_summary.length <= 360 && typeof row.fix_recommendation === "string" && row.fix_recommendation.length <= 240; }
function reviewFor(calculation: string, values: Record<string, number>) { if (Object.values(values).some((value) => value < 0)) return { verdict: "unsafe", snide_summary: "The arithmetic may be tidy, but negative physical inputs are not a design philosophy. Your circuit is asking for a reality check before it asks for power.", fix_recommendation: "Validate polarity and units, then rerun with measured, physically meaningful inputs." }; if (/voltage drop/i.test(calculation)) return { verdict: "check", snide_summary: "The number is a useful first pass, not a permit to pull the wire yet. Temperature, topology, terminations, and conductor impedance still get a vote.", fix_recommendation: "Confirm conductor data, installation temperature, phase arrangement, and the applicable voltage-drop target." }; return { verdict: "sound", snide_summary: "The math is behaving itself for once. That is encouraging, though equipment ratings and field conditions remain stubbornly real.", fix_recommendation: "Check the result against the equipment nameplate, code edition, and measured installation conditions." }; }

export default router;
