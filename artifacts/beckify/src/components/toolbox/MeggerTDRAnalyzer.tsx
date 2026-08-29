import { useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";

type PulsePolarity = "positive" | "negative" | "unknown";

interface TdrEvent {
  label: string;
  polarity: PulsePolarity;
  faultType: string;
  distance_ft: number | null;
  distance_m: number | null;
  range_fraction: number | null;
  confidence: number;
  recommendation: string;
}

interface TdrAnalysis {
  screen: {
    vf: number | null;
    range: { value: number | null; unit: string | null };
    impedance: { value: number | null; unit: string | null };
    confidence: number;
  };
  events: TdrEvent[];
  summary: string;
  warnings: string[];
  raw_ocr: string;
}

interface MeggerTDRAnalyzerProps {
  endpoint?: string;
  className?: string;
}

const DEFAULT_VF = 0.66;
const VF_MIN = 0.2;
const VF_MAX = 0.99;

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function fmt(value: number | null | undefined, digits = 2) {
  if (value == null || Number.isNaN(value)) return "—";
  return Number(value).toFixed(digits).replace(/\.00$/, "").replace(/(\.\d*[1-9])0+$/, "$1");
}

function fileToDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(reader.error || new Error("Could not read the selected image."));
    reader.readAsDataURL(file);
  });
}

function getPulseLabel(polarity: PulsePolarity) {
  if (polarity === "positive") return "Up / Open";
  if (polarity === "negative") return "Down / Short";
  return "Unknown";
}

function getPulseClass(polarity: PulsePolarity) {
  if (polarity === "positive") return "bg-emerald-500/15 text-emerald-300 border-emerald-500/30";
  if (polarity === "negative") return "bg-rose-500/15 text-rose-300 border-rose-500/30";
  return "bg-amber-500/15 text-amber-300 border-amber-500/30";
}

export function MeggerTDRAnalyzer({
  endpoint = "/api/analyze-tdr",
  className = "",
}: MeggerTDRAnalyzerProps) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const dropRef = useRef<HTMLDivElement | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState("");
  const [analysis, setAnalysis] = useState<TdrAnalysis | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("Ready for a TDR image.");
  const [vf, setVf] = useState(DEFAULT_VF);
  const [rangeFt, setRangeFt] = useState(1000);
  const [impedanceOhm, setImpedanceOhm] = useState(75);
  const [detectedVf, setDetectedVf] = useState(DEFAULT_VF);
  const [detectedRangeFt, setDetectedRangeFt] = useState(1000);
  const [detectedImpedanceOhm, setDetectedImpedanceOhm] = useState(75);

  useEffect(() => () => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
  }, [previewUrl]);

  useEffect(() => {
    if (!dropRef.current) return;
    const el = dropRef.current;
    const onEnter = (event: DragEvent) => {
      event.preventDefault();
      el.dataset.dragover = "1";
    };
    const onLeave = (event: DragEvent) => {
      event.preventDefault();
      el.dataset.dragover = "";
    };
    const onDrop = (event: DragEvent) => {
      event.preventDefault();
      el.dataset.dragover = "";
      const dropped = event.dataTransfer?.files?.[0];
      if (dropped) void handleFile(dropped);
    };
    el.addEventListener("dragenter", onEnter);
    el.addEventListener("dragover", onEnter);
    el.addEventListener("dragleave", onLeave);
    el.addEventListener("drop", onDrop);
    return () => {
      el.removeEventListener("dragenter", onEnter);
      el.removeEventListener("dragover", onEnter);
      el.removeEventListener("dragleave", onLeave);
      el.removeEventListener("drop", onDrop);
    };
  }, []);

  const scaleFactor = useMemo(() => {
    const vfRatio = detectedVf > 0 ? vf / detectedVf : 1;
    const rangeRatio = detectedRangeFt > 0 ? rangeFt / detectedRangeFt : 1;
    return vfRatio * rangeRatio;
  }, [detectedRangeFt, detectedVf, rangeFt, vf]);

  const currentEvents = useMemo(() => {
    if (!analysis) return [];
    return analysis.events.map((event) => {
      const baseFt = event.distance_ft ?? (event.range_fraction != null ? event.range_fraction * detectedRangeFt : null);
      const scaledFt = baseFt == null ? null : baseFt * scaleFactor;
      return {
        ...event,
        scaledFt,
        scaledM: scaledFt == null ? null : (event.distance_m != null ? event.distance_m * scaleFactor : scaledFt * 0.3048),
      };
    });
  }, [analysis, detectedRangeFt, scaleFactor]);

  async function handleFile(nextFile: File) {
    if (!nextFile.type.startsWith("image/")) {
      setStatus("Please choose a valid image file.");
      return;
    }
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setFile(nextFile);
    setPreviewUrl(URL.createObjectURL(nextFile));
    setAnalysis(null);
    setStatus("Image loaded. Run Analyze Trace to OCR the screen.");
  }

  async function analyze() {
    if (!file || busy) return;
    setBusy(true);
    setStatus("Reading image...");
    try {
      const dataUrl = await fileToDataUrl(file);
      setStatus("Sending to vision model...");
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          imageBase64: dataUrl,
          mimeType: file.type || "image/jpeg",
        }),
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.error || `Analyzer request failed with HTTP ${response.status}.`);

      const nextAnalysis = payload.analysis as TdrAnalysis;
      setAnalysis(nextAnalysis);
      const screen = nextAnalysis?.screen || {};
      const nextVf = clamp(screen.vf ?? vf, VF_MIN, VF_MAX);
      const nextRange = Math.max(1, screen.range?.value ?? rangeFt);
      const nextImpedance = Math.max(1, screen.impedance?.value ?? impedanceOhm);
      setDetectedVf(nextVf);
      setDetectedRangeFt(nextRange);
      setDetectedImpedanceOhm(nextImpedance);
      setVf(nextVf);
      setRangeFt(nextRange);
      setImpedanceOhm(nextImpedance);
      setStatus("Analysis complete. Review the reflection cards below.");
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Unknown analyzer error");
    } finally {
      setBusy(false);
    }
  }

  function reset() {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setFile(null);
    setPreviewUrl("");
    setAnalysis(null);
    setStatus("Ready for a TDR image.");
    setVf(DEFAULT_VF);
    setRangeFt(1000);
    setImpedanceOhm(75);
    setDetectedVf(DEFAULT_VF);
    setDetectedRangeFt(1000);
    setDetectedImpedanceOhm(75);
    if (fileInputRef.current) fileInputRef.current.value = "";
  }

  return (
    <div className={`grid gap-6 xl:grid-cols-[1.05fr_0.95fr] ${className}`}>
      <section className="rounded-[2rem] border border-white/10 bg-slate-950/70 p-5 shadow-2xl shadow-slate-950/40 backdrop-blur-xl">
        <div className="mb-5 space-y-2">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-amber-300/80">
            Field Test & Fault Locating
          </p>
          <h2 className="font-display text-2xl font-semibold text-white">
            Megger TDR Trace Analyzer
          </h2>
          <p className="text-sm text-slate-300">
            Drop in a TDR500 screen photo, let vision OCR the LCD, then override VF when the technician spec sheet wins.
          </p>
        </div>

        <div
          ref={dropRef}
          className="grid min-h-[210px] place-items-center gap-3 rounded-2xl border border-dashed border-amber-400/40 bg-white/5 p-6 text-center transition data-[dragover=1]:border-amber-300 data-[dragover=1]:bg-amber-300/10"
          data-dragover="0"
        >
          <div className="text-4xl">📷</div>
          <div className="space-y-1">
            <p className="font-semibold text-white">Drag and drop a Megger TDR500 photo here</p>
            <p className="text-sm text-slate-300">or choose a file to start OCR analysis.</p>
          </div>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(event) => {
              const nextFile = event.target.files?.[0];
              if (nextFile) void handleFile(nextFile);
            }}
          />
          <Button type="button" variant="secondary" onClick={() => fileInputRef.current?.click()}>
            Choose Photo
          </Button>
        </div>

        <div className="mt-4 overflow-hidden rounded-2xl border border-white/10 bg-white/5 p-3">
          {previewUrl ? (
            <img src={previewUrl} alt="Megger TDR screen preview" className="w-full rounded-xl object-contain" />
          ) : (
            <div className="grid min-h-[280px] place-items-center rounded-xl border border-dashed border-white/10 text-sm text-slate-400">
              No image loaded yet.
            </div>
          )}
        </div>

        <div className="mt-4 grid gap-3 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-slate-300 md:grid-cols-2">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">File</div>
            <div className="mt-1 break-all text-white">{file?.name ?? "No file selected"}</div>
          </div>
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">Status</div>
            <div className="mt-1 text-white">{status}</div>
          </div>
        </div>

        <div className="mt-4 flex gap-3">
          <Button type="button" onClick={() => void analyze()} disabled={!file || busy}>
            {busy ? "Analyzing..." : "Analyze Trace"}
          </Button>
          <Button type="button" variant="outline" onClick={reset}>
            Reset
          </Button>
        </div>
      </section>

      <div className="space-y-6">
        <section className="rounded-[2rem] border border-white/10 bg-slate-950/70 p-5 shadow-2xl shadow-slate-950/40 backdrop-blur-xl">
          <h3 className="font-display text-xl font-semibold text-white">Trace Controls</h3>
          <p className="mt-1 text-sm text-slate-300">
            Distance re-scales live as VF or range changes. Formula: base distance × VF ratio × range ratio.
          </p>

          <div className="mt-5 space-y-5">
            <div className="space-y-3">
              <div className="flex items-center justify-between text-sm text-slate-300">
                <span>Velocity Factor</span>
                <span className="font-semibold text-white">{fmt(vf, 2)}</span>
              </div>
              <Slider
                min={VF_MIN}
                max={VF_MAX}
                step={0.01}
                value={[vf]}
                onValueChange={([next]) => setVf(clamp(next ?? DEFAULT_VF, VF_MIN, VF_MAX))}
              />
              <input
                type="number"
                min={VF_MIN}
                max={VF_MAX}
                step={0.01}
                value={vf}
                onChange={(event) => setVf(clamp(Number(event.target.value) || DEFAULT_VF, VF_MIN, VF_MAX))}
                className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white outline-none ring-0"
              />
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <label className="grid gap-2 text-sm text-slate-300">
                <span>Range (ft)</span>
                <input
                  type="number"
                  min={1}
                  step={1}
                  value={rangeFt}
                  onChange={(event) => setRangeFt(Math.max(1, Number(event.target.value) || 1))}
                  className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white outline-none ring-0"
                />
              </label>
              <label className="grid gap-2 text-sm text-slate-300">
                <span>Impedance (Ω)</span>
                <input
                  type="number"
                  min={1}
                  step={1}
                  value={impedanceOhm}
                  onChange={(event) => setImpedanceOhm(Math.max(1, Number(event.target.value) || 1))}
                  className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white outline-none ring-0"
                />
              </label>
            </div>

            <div className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-slate-300">
              <div className="font-semibold text-white">Detected settings</div>
              <div className="mt-2 space-y-1">
                <p>VF {fmt(detectedVf, 2)} | Range {fmt(detectedRangeFt, 0)} ft | Impedance {fmt(detectedImpedanceOhm, 0)} Ω</p>
                <p>Current VF {fmt(vf, 2)} | Current Range {fmt(rangeFt, 0)} ft | Scale {fmt(scaleFactor, 3)}×</p>
              </div>
            </div>

            {analysis?.warnings?.length ? (
              <ul className="space-y-2 rounded-2xl border border-amber-400/20 bg-amber-400/10 p-4 text-sm text-amber-100">
                {analysis.warnings.map((warning) => (
                  <li key={warning}>• {warning}</li>
                ))}
              </ul>
            ) : null}
          </div>
        </section>

        <section className="rounded-[2rem] border border-white/10 bg-slate-950/70 p-5 shadow-2xl shadow-slate-950/40 backdrop-blur-xl">
          <h3 className="font-display text-xl font-semibold text-white">Detected Fault Events</h3>
          <p className="mt-1 text-sm text-slate-300">
            Pulse polarity tells the story: upward for open, downward for short.
          </p>

          <div className="mt-5 space-y-4">
            {!analysis ? (
              <p className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-slate-300">
                Upload a screen and run the analyzer to populate fault cards.
              </p>
            ) : analysis.events.length ? (
              currentEvents.map((event, index) => (
                <article key={`${event.label}-${index}`} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <h4 className="font-semibold text-white">{event.label || `Reflection ${index + 1}`}</h4>
                      <p className="text-sm text-slate-400">{event.faultType || "fault event"}</p>
                    </div>
                    <span className={`rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] ${getPulseClass(event.polarity)}`}>
                      {getPulseLabel(event.polarity)}
                    </span>
                  </div>

                  <div className="mt-4 grid gap-3 md:grid-cols-2">
                    <div>
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">Distance</div>
                      <div className="mt-1 text-sm text-white">
                        {fmt(event.scaledFt, 2)} ft / {fmt(event.scaledM, 2)} m
                      </div>
                    </div>
                    <div>
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">Confidence</div>
                      <div className="mt-1 text-sm text-white">{fmt((event.confidence ?? 0) * 100, 0)}%</div>
                    </div>
                    <div>
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">Range Fraction</div>
                      <div className="mt-1 text-sm text-white">
                        {event.range_fraction != null ? `${fmt(event.range_fraction * 100, 1)}% of span` : "—"}
                      </div>
                    </div>
                    <div>
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">Recommendation</div>
                      <div className="mt-1 text-sm text-white">{event.recommendation}</div>
                    </div>
                  </div>
                </article>
              ))
            ) : (
              <p className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-slate-300">
                No clear reflections were identified in the screenshot.
              </p>
            )}
          </div>
        </section>

        <section className="rounded-[2rem] border border-white/10 bg-slate-950/70 p-5 shadow-2xl shadow-slate-950/40 backdrop-blur-xl">
          <h3 className="font-display text-xl font-semibold text-white">Feynman Physics</h3>
          <p className="mt-3 text-sm leading-7 text-slate-300">
            A TDR sends a very fast pulse into the cable. If the cable suddenly changes impedance, part of that pulse cannot keep going, so it bounces back. If the impedance jumps higher, the reflection goes upward like an open circuit. If the impedance collapses lower, the reflection flips downward like a short. The round-trip delay tells you how far away the fault is, and VF is the ruler that turns that time into distance.
          </p>
          <p className="mt-3 text-sm leading-7 text-slate-300">
            When the technician overrides VF, the analyzer simply stretches or shrinks every fault distance by the new velocity ratio. That keeps the repair note honest when the cable spec sheet is better than the LCD OCR.
          </p>

          {analysis?.raw_ocr ? (
            <details className="mt-4 rounded-2xl border border-white/10 bg-white/5 p-4">
              <summary className="cursor-pointer text-sm font-semibold text-white">Raw OCR text</summary>
              <pre className="mt-3 whitespace-pre-wrap text-xs leading-6 text-slate-300">{analysis.raw_ocr}</pre>
            </details>
          ) : null}
        </section>
      </div>
    </div>
  );
}

export default MeggerTDRAnalyzer;
