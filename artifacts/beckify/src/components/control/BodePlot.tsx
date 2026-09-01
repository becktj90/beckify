import { useMemo } from "react";
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
import {
  bodeResponse,
  computeMargins,
  computePerformanceMetrics,
  poleZeroMap,
  rootLocus,
  simulateStepResponse,
  transferFunctionToStateSpace,
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
  magnitude: { label: "Magnitude", color: "#8b7bff" },
  phase: { label: "Phase", color: "#4f8bff" },
  step: { label: "Step", color: "#6ee7b7" },
  root: { label: "Root locus", color: "#f5c451" },
  pole: { label: "Poles", color: "#ff8a8a" },
  zero: { label: "Zeros", color: "#7dd3fc" },
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
  const bode = useMemo(() => bodeResponse(transferFunction, { minOmega: 0.1, maxOmega: 200, points: 180 }), [transferFunction]);
  const margins = useMemo(() => computeMargins(bode), [bode]);
  const stateSpace = useMemo(() => transferFunctionToStateSpace(transferFunction), [transferFunction]);
  const step = useMemo(() => simulateStepResponse(stateSpace, { duration: 8, dt: 0.02 }), [stateSpace]);
  const metrics = useMemo(() => computePerformanceMetrics(step), [step]);
  const locus = useMemo(() => rootLocus(transferFunction, Array.from({ length: 36 }, (_, index) => index * 0.5)).flatMap((entry) => entry.poles.map((pole) => ({ gain: entry.gain, real: pole.re, imag: pole.im }))), [transferFunction]);
  const poleZero = useMemo(() => poleZeroMap(transferFunction), [transferFunction]);
  const poleData = poleZero.poles.map((pole) => ({ real: pole.re, imag: pole.im }));
  const zeroData = poleZero.zeros.map((zero) => ({ real: zero.re, imag: zero.im }));

  return (
    <section className="space-y-5">
      <div className="card-surface rounded-3xl p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Classic linear analysis</p>
            <h3 className="mt-2 font-display text-2xl font-bold text-[var(--foreground)]">{title}</h3>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">Bode, Nyquist-ready frequency response, root locus motion, and pole-zero locations for {systemExample}.</p>
          </div>
          {onLoadExample ? <Button type="button" variant="outline" onClick={onLoadExample}>Load example</Button> : null}
        </div>

        <details className="mt-5 rounded-2xl border border-[var(--border)] bg-white/[0.02] p-4">
          <summary className="cursor-pointer list-none text-sm font-semibold text-[var(--foreground)]">How it Works &amp; Math Engine</summary>
          <div className="mt-4 grid gap-4 md:grid-cols-3 text-sm text-[var(--muted)]">
            <div>
              <h4 className="font-semibold text-[var(--foreground)]">Plain-English overview</h4>
              <p className="mt-2 leading-6">Use this view to see how much a plant amplifies or delays different frequencies, where closed-loop stability margins land, and how poles move as loop gain increases.</p>
            </div>
            <div>
              <h4 className="font-semibold text-[var(--foreground)]">Math</h4>
              <p className="mt-2 font-mono text-xs leading-6 text-slate-300">G(s)=N(s)/D(s), |G(jω)| dB = 20 log10 |G(jω)|, ∠G(jω) = atan2(Im, Re)</p>
              <p className="mt-2 font-mono text-xs leading-6 text-slate-300">Phase margin = 180° + ∠G(jωgc), gain margin = -|G(jωpc)|dB</p>
            </div>
            <div>
              <h4 className="font-semibold text-[var(--foreground)]">4-step workflow</h4>
              <ol className="mt-2 list-decimal space-y-1 pl-4 leading-6">
                <li>Define the transfer function coefficients.</li>
                <li>Inspect magnitude and phase around crossover.</li>
                <li>Review root-locus and pole-zero clustering.</li>
                <li>Compare margins against step metrics before tuning.</li>
              </ol>
            </div>
          </div>
        </details>

        <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
          {[
            ["Gain margin", `${fmt(margins.gainMarginDb)} dB`],
            ["Phase margin", `${fmt(margins.phaseMarginDeg)}°`],
            ["ωgc", `${fmt(margins.gainCrossover)} rad/s`],
            ["Settling time", `${fmt(metrics.settlingTime)} s`],
            ["Overshoot", `${fmt(metrics.overshoot)} %`],
          ].map(([label, value]) => (
            <div key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">{label}</p>
              <p className="mt-2 text-lg font-semibold text-[var(--foreground)]">{value}</p>
            </div>
          ))}
        </div>

        <div className="mt-6 grid gap-5 xl:grid-cols-2">
          <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <p className="mb-3 text-sm font-semibold text-[var(--foreground)]">Bode magnitude</p>
            <ChartContainer config={chartConfig} className="h-72 w-full">
              <LineChart data={bode.map((point) => ({ ...point, x: log10(point.omega) }))}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="x" tickFormatter={(value) => `10^${Number(value).toFixed(1)}`} />
                <YAxis unit=" dB" />
                <Tooltip content={<ChartTooltipContent formatter={(value) => <span>{fmt(Number(value))} dB</span>} />} />
                <ReferenceLine y={0} stroke="#94a3b8" strokeDasharray="4 4" />
                <Line type="monotone" dataKey="magnitudeDb" stroke="var(--color-magnitude)" dot={false} strokeWidth={2} />
              </LineChart>
            </ChartContainer>
          </div>
          <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <p className="mb-3 text-sm font-semibold text-[var(--foreground)]">Bode phase</p>
            <ChartContainer config={chartConfig} className="h-72 w-full">
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
          <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <p className="mb-3 text-sm font-semibold text-[var(--foreground)]">Nyquist plane</p>
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
          <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
            <p className="mb-3 text-sm font-semibold text-[var(--foreground)]">Nichols chart</p>
            <ChartContainer config={chartConfig} className="h-72 w-full">
              <LineChart data={bode}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="phaseDeg" unit="°" type="number" domain={["dataMin", "dataMax"]} />
                <YAxis dataKey="magnitudeDb" unit=" dB" />
                <Tooltip content={<ChartTooltipContent />} />
                <Line type="monotone" dataKey="magnitudeDb" stroke="var(--color-magnitude)" dot={false} strokeWidth={2} />
              </LineChart>
            </ChartContainer>
          </div>
          <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4 xl:col-span-2">
            <div className="grid gap-5 xl:grid-cols-2">
              <div>
                <p className="mb-3 text-sm font-semibold text-[var(--foreground)]">Root locus</p>
                <ResponsiveContainer width="100%" height={280}>
                  <ScatterChart>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis type="number" dataKey="real" name="Real" />
                    <YAxis type="number" dataKey="imag" name="Imag" />
                    <Tooltip cursor={{ strokeDasharray: "3 3" }} formatter={(value) => fmt(Number(value), 3)} />
                    <ReferenceLine x={0} stroke="#94a3b8" strokeDasharray="4 4" />
                    <ReferenceLine y={0} stroke="#94a3b8" strokeDasharray="4 4" />
                    <Scatter data={locus} fill="#f5c451" />
                  </ScatterChart>
                </ResponsiveContainer>
              </div>
              <div>
                <p className="mb-3 text-sm font-semibold text-[var(--foreground)]">Pole-zero map</p>
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
