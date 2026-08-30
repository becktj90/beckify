import { useEffect, useState } from "react";
import { ArrowUpRight, Calculator, Command, Search, Sparkles, Upload, X, Zap } from "lucide-react";
import { PenroseCanvas } from "@/components/PenroseCanvas";
import { executeCalculation, inferCalculation, type CalculationResult } from "@/lib/assistant/calculations";
import { searchAssistant, type SearchResult } from "@/lib/assistant/search";
import { SnideReview } from "@/components/toolbox/SnideReview";

export function EngineeringAssistant() {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [calculation, setCalculation] = useState<CalculationResult | null>(null);
  const [imageName, setImageName] = useState<string | null>(null);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => { if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") { event.preventDefault(); setOpen(true); } if (event.key === "Escape") setOpen(false); };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useEffect(() => {
    setResults(searchAssistant(query));
    setCalculation(null);
    if (query.trim()) { const request = inferCalculation(query); if (request) { try { setCalculation(executeCalculation(request)); } catch { setCalculation(null); } } }
  }, [query]);

  const close = () => { setOpen(false); setQuery(""); setImageName(null); };
  return <>
    <button type="button" onClick={() => setOpen(true)} className="inline-flex items-center gap-1.5 rounded-xl border border-[var(--border)] px-3 py-1.5 text-sm font-medium text-[var(--muted)] transition-colors hover:border-[var(--accent)]/60 hover:text-[var(--foreground)]" aria-label="Open Beckify engineering assistant"><Sparkles className="h-3.5 w-3.5 text-[var(--accent)]" /><span className="hidden md:inline">Ask Beckify</span><kbd className="hidden rounded border border-[var(--border)] px-1.5 py-0.5 font-mono text-[10px] md:inline">⌘K</kbd></button>
    {open ? <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/70 px-4 py-16 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label="Beckify engineering assistant" onMouseDown={(event) => { if (event.target === event.currentTarget) close(); }}>
      <div className="w-full max-w-3xl overflow-hidden rounded-2xl border border-[var(--border)] bg-[#080d16] shadow-2xl shadow-black/50">
        <div className="relative h-32 overflow-hidden border-b border-[var(--border)] bg-[#07101a] p-5"><PenroseCanvas className="absolute inset-0 h-full w-full opacity-80" /><div className="relative z-10 flex items-start justify-between"><div><p className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.18em] text-[var(--accent)]"><Zap className="h-3.5 w-3.5" /> Beckify intelligence layer</p><h2 className="mt-2 font-display text-xl font-bold">Search the field guide. Ask the math.</h2></div><button type="button" onClick={close} className="rounded-lg p-2 text-[var(--muted)] hover:bg-white/10 hover:text-white" aria-label="Close assistant"><X className="h-5 w-5" /></button></div></div>
        <div className="p-5"><label className="flex items-center gap-3 rounded-xl border border-[var(--accent)]/50 bg-black/20 px-4 py-3"><Search className="h-5 w-5 text-[var(--accent)]" /><input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Try: how do I prevent lug cracking? or 120 V 10 A resistance" className="min-w-0 flex-1 bg-transparent text-base text-[var(--foreground)] outline-none placeholder:text-[var(--muted)]" /><Command className="hidden h-4 w-4 text-[var(--muted)] sm:block" /></label>
          <div className="mt-4 flex flex-wrap gap-2">{["voltage drop", "conduit fill", "AWG 310.16", "Megger TDR", "Vespa battery"].map((suggestion) => <button type="button" key={suggestion} onClick={() => setQuery(suggestion)} className="rounded-full border border-[var(--border)] px-3 py-1.5 text-xs text-[var(--muted)] transition-colors hover:border-[var(--accent)]/50 hover:text-[var(--foreground)]">{suggestion}</button>)}</div>
          <label className="mt-4 inline-flex cursor-pointer items-center gap-2 text-xs font-semibold text-[var(--muted)] hover:text-[var(--foreground)]"><Upload className="h-4 w-4 text-[var(--accent)]" /> Inspect a photo <input type="file" accept="image/*" className="sr-only" onChange={(event) => setImageName(event.target.files?.[0]?.name ?? null)} /></label>{imageName ? <p className="mt-2 text-xs text-[var(--accent)]">Attached: {imageName}. Connect this handoff to the vision endpoint when API credentials are available.</p> : null}
          {calculation ? <div className="mt-5 rounded-xl border border-emerald-400/30 bg-emerald-400/[0.06] p-4"><div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.14em] text-emerald-300"><Calculator className="h-4 w-4" /> Deterministic calculation</div><div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">{Object.entries(calculation.values).map(([key, value]) => <div key={key}><p className="text-xs capitalize text-[var(--muted)]">{key}</p><p className="font-mono text-lg text-[var(--foreground)]">{value.toFixed(3)} {calculation.units[key]}</p></div>)}</div><p className="mt-3 text-xs leading-5 text-[var(--muted)]">{calculation.explanation}</p><SnideReview calculation={calculation.tool} values={calculation.values} units={calculation.units} /></div> : null}
          <div className="mt-6 space-y-3">{results.length ? results.map((result) => <a key={result.id} href={result.href} onClick={close} className="group flex items-start justify-between gap-4 rounded-xl border border-[var(--border)] bg-white/[0.02] p-4 transition-colors hover:border-[var(--accent)]/60 hover:bg-[var(--accent-soft)]"><div><div className="flex items-center gap-2"><span className="text-xs font-bold uppercase tracking-[0.14em] text-[var(--accent)]">{result.kind}</span>{result.matched.slice(0, 2).map((match) => <span className="rounded bg-white/[0.07] px-1.5 py-0.5 text-[10px] text-[var(--muted)]" key={match}>{match}</span>)}</div><h3 className="mt-2 font-display font-bold text-[var(--foreground)]">{result.title}</h3><p className="mt-1 text-sm leading-5 text-[var(--muted)]">{result.description}</p></div><ArrowUpRight className="h-4 w-4 shrink-0 text-[var(--muted)] transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5 group-hover:text-[var(--accent)]" /></a>) : <div className="rounded-xl border border-dashed border-[var(--border)] p-6 text-center text-sm text-[var(--muted)]">No direct match yet. Try a tool name, NEC section, AWG size, or describe the engineering problem in plain language.</div>}</div>
          <p className="mt-5 text-center text-[10px] leading-4 text-[var(--muted)]">Search is local and privacy-friendly. Calculations are deterministic. Always verify field decisions against the applicable code edition, equipment documentation, and site conditions.</p>
        </div>
      </div>
    </div> : null}
  </>;
}

export default EngineeringAssistant;
