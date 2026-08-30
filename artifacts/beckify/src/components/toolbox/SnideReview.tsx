import { useEffect, useState } from "react";
import { AlertTriangle, Check, RefreshCw, ShieldAlert } from "lucide-react";
import { localReview, streamReview, type ReviewResponse } from "@/lib/assistant/review";

export function SnideReview({ calculation, values, units }: { calculation: string; values: Record<string, number>; units: Record<string, string> }) {
  const [review, setReview] = useState<ReviewResponse>(() => localReview(calculation, values)); const [loading, setLoading] = useState(false);
  useEffect(() => { setReview(localReview(calculation, values)); }, [calculation, values]);
  const requestReview = async () => { setLoading(true); try { await streamReview({ calculation, values, units }, setReview); } catch { setReview(localReview(calculation, values)); } finally { setLoading(false); } };
  const Icon = review.verdict === "unsafe" ? ShieldAlert : review.verdict === "check" ? AlertTriangle : Check;
  const color = review.verdict === "unsafe" ? "text-red-300 border-red-400/30 bg-red-400/[0.06]" : review.verdict === "check" ? "text-amber-200 border-amber-300/30 bg-amber-300/[0.06]" : "text-emerald-200 border-emerald-300/30 bg-emerald-300/[0.06]";
  return <section className={`mt-4 rounded-xl border p-4 ${color}`} aria-live="polite"><div className="flex items-start justify-between gap-3"><div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.14em]"><Icon className="h-4 w-4" /> Senior EE review: {review.verdict}</div><button type="button" onClick={requestReview} disabled={loading} className="inline-flex items-center gap-1 text-xs text-current/70 hover:text-current disabled:opacity-50">{loading ? <RefreshCw className="h-3.5 w-3.5 animate-spin" /> : "Ask reviewer"}</button></div><p className="mt-3 text-sm leading-6 text-[var(--foreground)]">{review.snide_summary}</p><p className="mt-2 text-xs leading-5 text-current/80"><strong>Remedy:</strong> {review.fix_recommendation}</p></section>;
}
