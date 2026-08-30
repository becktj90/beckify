import { z } from "zod";

export const ReviewRequestSchema = z.object({ calculation: z.string().min(1).max(160), values: z.record(z.string(), z.number().finite()).default({}), units: z.record(z.string(), z.string().max(12)).default({}) });
export const ReviewResponseSchema = z.object({ verdict: z.enum(["sound", "check", "unsafe"]), snide_summary: z.string().min(1).max(360), fix_recommendation: z.string().min(1).max(240) });
export type ReviewResponse = z.infer<typeof ReviewResponseSchema>;

export function localReview(calculation: string, values: Record<string, number>): ReviewResponse {
  if (Object.values(values).some((value) => value < 0)) return { verdict: "unsafe", snide_summary: "The arithmetic may be tidy, but negative physical inputs are not a design philosophy. Your circuit is asking for a reality check before it asks for power.", fix_recommendation: "Validate polarity and units, then rerun with measured, physically meaningful inputs." };
  if (/voltage drop/i.test(calculation)) return { verdict: "check", snide_summary: "The number is a useful first pass, not a permit to pull the wire yet. Temperature, topology, terminations, and the actual conductor impedance still get a vote.", fix_recommendation: "Confirm the conductor table, installation temperature, phase arrangement, and the applicable voltage-drop target." };
  if (/conduit/i.test(calculation)) return { verdict: "check", snide_summary: "A raceway that fits on paper can still become a wrestling match in the field. Fill percentage is only the opening argument; bends, pulls, and future capacity finish it.", fix_recommendation: "Verify the raceway chapter, conductor dimensions, bend count, and pulling tension before installation." };
  return { verdict: "sound", snide_summary: "The math is behaving itself for once. That is encouraging, though equipment ratings and field conditions remain stubbornly real.", fix_recommendation: "Check the result against the equipment nameplate, code edition, and measured installation conditions." };
}

export async function streamReview(request: z.input<typeof ReviewRequestSchema>, onChunk: (review: ReviewResponse) => void) {
  const parsed = ReviewRequestSchema.parse(request);
  const response = await fetch("/api/review-calculation", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(parsed) });
  if (!response.ok || !response.body) throw new Error("Review service unavailable");
  const reader = response.body.getReader(); const decoder = new TextDecoder(); let buffer = "";
  while (true) { const { done, value } = await reader.read(); if (done) break; buffer += decoder.decode(value, { stream: true }); const lines = buffer.split("\n"); buffer = lines.pop() ?? ""; for (const line of lines) { if (!line.startsWith("data:")) continue; const result = ReviewResponseSchema.safeParse(JSON.parse(line.slice(5))); if (result.success) onChunk(result.data); } }
}
