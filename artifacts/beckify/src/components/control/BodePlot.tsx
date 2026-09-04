import { useMemo, useState } from "react";
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Scatter,
  ScatterChart,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Button } from "@/components/ui/button";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import { ChartExportButton } from "@/components/control/ChartExportButton";
import {
  bodeResponse,
  closedLoopBandwidth,
  closedLoopTransferFunction,
  computeMargins,
  computePerformanceMetrics,
  formatComplex,
  isStable,
  locusAsymptotes,
  poleZeroMap,
  rootLocus,
  seriesTransferFunction,
  simulateStepResponse,
  transferFunctionToStateSpace,
  ultimateGain,
  type TransferFunction,
} from "@/utils/controlEngine";

function fmt(value: number | null | undefined, digits = 2) {
  if (value === null || value === undefined || Number.isNaN(value)) return "—";
  return value.toFixed(digits);
}

function log10(value: number) {
  return Math.log10(Math.max(value, 1e-9));
}

const chartConfig = {
  magnitude: { label: "OL mag", color: "#8b7bff" },
  closedMag: { label: "CL mag", color: "#6ee7b7" },
  phase: { label: "Phase", color: "#4f8bff" },
  step: { label: "Step", color: "#6ee7b7" },
  root: { label: "Root locus", color: "#f5c451" },
  pole: { label: "Poles", color: "#ff8a8a" },
  zero: { label: "Zeros", color: "#7dd3fc" },
  closed: { label: "Closed-loop at K", color: "#f97316" },
} as const;

export function BodePlot({
  title,
  transferFunction,
  systemExample,
  onLoadExample,
}: {
  title: string;
  transferFunction: TransferFunction;
  systemExample: string;
  onLoadExample?: () => void;
}) {
  const [gain, setGain] = useState(1);

  const openLoop = useMemo(
    () => seriesTransferFunction({ numerator: [gain], denominator: [1] }, transferFunction),
    [gain, transferFunction],
  );
  const closedLoop = useMemo(() => closedLoopTransferFunction(openLoop), [openLoop]);

  const bode = useMemo(
    () => bodeResponse(transferFunction, { minOmega: 0.05, maxOmega: 200, points: 180 }),
    [transferFunction],
  );
  const closedBode = useMemo(
    () => bodeResponse(closedLoop, { minOmega: 0.05, maxOmega: 200, points: 180 }),
    [closedLoop],
  );
  const margins = useMemo(() => computeMargins(bodeResponse(openLoop, { minOmega: 0.05, maxOmega: 200, points: 220 })), [openLoop]);
  const omegaB = useMemo(() => closedLoopBandwidth(openLoop), [openLoop]);
  const stateSpace = useMemo(() => transferFunctionToStateSpace(closedLoop), [closedLoop]);
  const step = useMemo(() => simulateStepResponse(stateSpace, { duration: 8, dt: 0.02 }), [stateSpace]);
  const metrics = useMemo(() => computePerformanceMetrics(step), [step]);
  const gains = useMemo(() => Array.from({ length: 48 }, (_, index) => (index * index) / 40), []);
  const locus = useMemo(
    () =>
      rootLocus(transferFunction, gains).flatMap((entry) =>
        entry.poles.map((pole) => ({ gain: entry.gain, real: pole.re, imag: pole.im })),
      ),
    [transferFunction, gains],
  );
  const closedPoles = useMemo(() => poleZeroMap(closedLoop).poles.map((pole) => ({ real: pole.re, imag: pole.im })), [closedLoop]);
  const poleZero = useMemo(() => poleZeroMap(transferFunction), [transferFunction]);
  const poleData = poleZero.poles.map((pole) => ({ real: pole.re, imag: pole.im }));
  const zeroData = poleZero.zeros.map((zero) => ({ real: zero.re, imag: zero.im }));
  const asymptotes = useMemo(() => locusAsymptotes(transferFunction), [transferFunction]);
  const ku = useMemo(() => ultimateGain(transferFunction), [transferFunction]);
  const stable = useMemo(() => isStable(closedLoop), [closedLoop]);

  const magData = bode.map((point, index) => ({
    x: log10(point.omega),
    magnitudeDb: point.magnitudeDb,
    closedMag: closedBode[index]?.magnitudeDb ?? null,
    omega: point.omega,
  }));

  const relative =
    margins.phaseMarginDeg === null
      ? "No gain crossover on this sweep — the loop may never reach |KG|=1."
      : margins.phaseMarginDeg < 0
        ? "Negative phase margin: the closed loop is expected to be unstable."
        : margins.phaseMarginDeg < 30
          ? "Thin phase margin: expect ringing and a long settle. Relative stability is poor."
          : margins.phaseMarginDeg < 60
            ? "Moderate phase margin: a usable but still lively loop."
            : "Comfortable phase margin: the closed loop should look well damped.";

  return (
    <section className="space-y-5">
      <div className="card-surface rounded-3xl p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Classic linear analysis</p>
            <h3 className="mt-2 font-display text-2xl font-bold tracking-[-0.015em] text-[var(--foreground)]">{title}</h3>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">
              Open-loop Bode of G, closed-loop T = KG/(1+KG), gain/phase margins, bandwidth ωb, and a K-slider root
              locus for {systemExample}. Extra lag from the plant model shows up here as slower damping.
            </p>
          </div>
          {onLoadExample ? (
            <Button type="button" variant="outline" onClick={onLoadExample}>
              Load example
            </Button>
          ) : null}
        </div>

        <label className="mt-5 block rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
          Loop gain K = {gain.toFixed(2)} {stable ? "(closed loop stable)" : "(closed loop unstable)"}
          <input
            type="range"
            min={0}
            max={20}
            step={0.05}
            value={gain}
            onChange={(event) => setGain(Number(event.target.value))}
            className="mt-3 h-6 w-full cursor-pointer accent-[var(--accent)]"
            aria-label="Loop gain K"
          />
        </label>

        <details className="mt-5 rounded-2xl border border-[var(--border)] bg-white/[0.02] p-4">
          <summary className="cursor-pointer list-none text-sm font-semibold text-[var(--foreground)]">
            How it Works &amp; Math Engine
          </summary>
          <div className="mt-4 grid gap-4 md:grid-cols-3 text-sm text-[var(--muted)]">
            <div>
              <h4 className="font-semibold text-[var(--foreground)]">Plain-English overview</h4>
              <p className="mt-2 leading-6">
                Magnitude says how much the plant amplifies each frequency; phase says how late it is. Gain and phase
                margins are how far you are from the −1 point. Closed-loop bandwidth ωb is where |T| has fallen 3 dB
                from DC — a speed number, not a stability number.
              </p>
            </div>
            <div>
              <h4 className="font-semibold text-[var(--foreground)]">Math</h4>
              <p className="mt-2 font-mono text-xs leading-6 text-slate-300">
                |G(jω)|dB = 20 log10 |G|, ∠G = atan2(Im, Re)
              </p>
              <p className="mt-2 font-mono text-xs leading-6 text-slate-300">
                PM = 180° + ∠G(jωgc), GM = −|G(jωpc)|dB, ωb : |T(jωb)| = |T(0)|/√2
              </p>
            </div>
            <div>
              <h4 className="font-semibold text-[var(--foreground)]">Relative stability</h4>
              <p className="mt-2 leading-6">{relative}</p>
            </div>
          </div>
        </details>

        <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-6">
          {[
            ["Gain margin", `${fmt(margins.gainMarginDb)} dB`],
            ["Phase margin", `${fmt(margins.phaseMarginDeg)}°`],
            ["ωgc", `${fmt(margins.gainCrossover)} rad/s`],
            ["ωpc", `${fmt(margins.phaseCrossover)} rad/s`],
            ["ωb (CL −3 dB)", `${fmt(omegaB)} rad/s`],
            ["Overshoot", `${fmt(metrics.overshoot)} %`],
          ].map(([label, value]) => (
            <div key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="type-label text-[var(--muted)]">{label}</p>
              <p className="mt-2 text-lg font-semibold text-[var(--foreground)]">{value}</p>
            </div>
          ))}
        </div>

        <div className="mt-6 grid gap-5 xl:grid-cols-2">
          <div data-chart-export-root className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <div className="mb-3 flex items-start justify-between gap-3">
              <p className="text-sm font-semibold text-[var(--foreground)]">Bode magnitude — OL G vs CL T</p>
              <ChartExportButton fileName="beckify-bode-magnitude" />
            </div>
            <ChartContainer config={chartConfig} className="aspect-auto h-72 w-full">
              <LineChart data={magData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="x" tickFormatter={(value) => `10^${Number(value).toFixed(1)}`} />
                <YAxis unit=" dB" />
                <Tooltip content={<ChartTooltipContent formatter={(value) => <span>{fmt(Number(value))} dB</span>} />} />
                <Legend />
                <ReferenceLine y={0} stroke="#94a3b8" strokeDasharray="4 4" />
                <Line type="monotone" dataKey="magnitudeDb" name="OL |G|" stroke="var(--color-magnitude)" dot={false} strokeWidth={2} />
                <Line type="monotone" dataKey="closedMag" name="CL |T|" stroke="var(--color-closedMag)" dot={false} strokeWidth={2} />
              </LineChart>
            </ChartContainer>
          </div>
          <div data-chart-export-root className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <div className="mb-3 flex items-start justify-between gap-3">
              <p className="text-sm font-semibold text-[var(--foreground)]">Bode phase (open loop)</p>
              <ChartExportButton fileName="beckify-bode-phase" />
            </div>
            <ChartContainer config={chartConfig} className="aspect-auto h-72 w-full">
              <LineChart data={bode.map((point) => ({ ...point, x: log10(point.omega) }))}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="x" tickFormatter={(value) => `10^${Number(value).toFixed(1)}`} />
                <YAxis unit="°" />
                <Tooltip content={<ChartTooltipContent formatter={(value) => <span>{fmt(Number(value))}°</span>} />} />
                <ReferenceLine y={-180} stroke="#94a3b8" strokeDasharray="4 4" />
                <Line type="monotone" dataKey="phaseDeg" stroke="var(--color-phase)" dot={false} strokeWidth={2} />
              </LineChart>
            </ChartContainer>
          </div>
          <div data-chart-export-root className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <div className="mb-3 flex items-start justify-between gap-3">
              <p className="text-sm font-semibold text-[var(--foreground)]">Nyquist plane</p>
              <ChartExportButton fileName="beckify-nyquist" />
            </div>
            <ResponsiveContainer width="100%" height={290}>
              <ScatterChart>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis type="number" dataKey="real" name="Real" />
                <YAxis type="number" dataKey="imag" name="Imag" />
                <Tooltip cursor={{ strokeDasharray: "3 3" }} />
                <ReferenceLine x={-1} stroke="#ff8a8a" strokeDasharray="4 4" />
                <ReferenceLine y={0} stroke="#94a3b8" strokeDasharray="4 4" />
                <Scatter data={bode} fill="#8b7bff" line shape="circle" />
              </ScatterChart>
            </ResponsiveContainer>
          </div>
          <div data-chart-export-root className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <div className="mb-3 flex items-start justify-between gap-3">
              <p className="text-sm font-semibold text-[var(--foreground)]">Nichols chart</p>
              <ChartExportButton fileName="beckify-nichols" />
            </div>
            <ChartContainer config={chartConfig} className="aspect-auto h-72 w-full">
              <LineChart data={bode}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="phaseDeg" unit="°" type="number" domain={["dataMin", "dataMax"]} />
                <YAxis dataKey="magnitudeDb" unit=" dB" />
                <Tooltip content={<ChartTooltipContent />} />
                <Line type="monotone" dataKey="magnitudeDb" stroke="var(--color-magnitude)" dot={false} strokeWidth={2} />
              </LineChart>
            </ChartContainer>
          </div>
          <div data-chart-export-root className="rounded-3xl border border-[var(--border)] bg-black/20 p-4 xl:col-span-2">
            <div className="grid gap-5 xl:grid-cols-2">
              <div>
                <div className="mb-1 flex items-start justify-between gap-3">
                  <p className="text-sm font-semibold text-[var(--foreground)]">Root locus vs K</p>
                  <ChartExportButton fileName="beckify-root-locus" />
                </div>
                <p className="mb-3 text-xs leading-5 text-[var(--muted)]">
                  Closed-loop poles at this K: {closedPoles.map((pole) => formatComplex({ re: pole.real, im: pole.imag })).join(" · ") || "—"}.
                  {ku.Ku
                    ? ` Stability crossing near Ku ≈ ${fmt(ku.Ku, 2)} (Pu ≈ ${fmt(ku.Pu, 2)} s).`
                    : " No finite Ku on this scan — the locus may stay in the LHP."}{" "}
                  Asymptote centroid {fmt(asymptotes.centroid, 2)}, angles {asymptotes.anglesDeg.map((angle) => `${Math.round(angle)}°`).join(", ") || "—"}.
                </p>
                <ResponsiveContainer width="100%" height={280}>
                  <ScatterChart>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis type="number" dataKey="real" name="Real" />
                    <YAxis type="number" dataKey="imag" name="Imag" />
                    <Tooltip cursor={{ strokeDasharray: "3 3" }} formatter={(value) => fmt(Number(value), 3)} />
                    <ReferenceLine x={0} stroke="#94a3b8" strokeDasharray="4 4" />
                    <ReferenceLine y={0} stroke="#94a3b8" strokeDasharray="4 4" />
                    <Scatter name="Locus" data={locus} fill="#f5c451" />
                    <Scatter name="CL poles" data={closedPoles} fill="#f97316" />
                    <Scatter name="OL poles" data={poleData} fill="#ff8a8a" />
                    <Scatter name="Zeros" data={zeroData} fill="#7dd3fc" />
                  </ScatterChart>
                </ResponsiveContainer>
              </div>
              <div>
                <p className="mb-3 text-sm font-semibold text-[var(--foreground)]">Open-loop pole-zero map</p>
                <ResponsiveContainer width="100%" height={280}>
                  <ScatterChart>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis type="number" dataKey="real" name="Real" />
                    <YAxis type="number" dataKey="imag" name="Imag" />
                    <Tooltip cursor={{ strokeDasharray: "3 3" }} />
                    <ReferenceLine x={0} stroke="#94a3b8" strokeDasharray="4 4" />
                    <ReferenceLine y={0} stroke="#94a3b8" strokeDasharray="4 4" />
                    <Legend />
                    <Scatter name="Poles" data={poleData} fill="#ff8a8a" />
                    <Scatter name="Zeros" data={zeroData} fill="#7dd3fc" />
                  </ScatterChart>
                </ResponsiveContainer>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
