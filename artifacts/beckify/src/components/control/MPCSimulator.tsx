import { useMemo, useState, type Dispatch, type SetStateAction } from "react";
import { CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Scatter, ScatterChart, Tooltip, XAxis, YAxis } from "recharts";
import { Button } from "@/components/ui/button";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import { computeLQR, simulateStepResponse, type Matrix, type StateSpaceSystem } from "@/utils/controlEngine";

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function simulatePredictiveController({
  system,
  predictionHorizon,
  controlHorizon,
  outputLimit,
  slewLimit,
}: {
  system: StateSpaceSystem;
  predictionHorizon: number;
  controlHorizon: number;
  outputLimit: number;
  slewLimit: number;
}) {
  const dt = system.sampleTime ?? 0.1;
  const candidateFractions = [-1, -0.5, 0, 0.5, 1];
  let x = Array(system.A.length).fill(0);
  let lastU = 0;
  const preview: { step: number; y: number; u: number; constrainedY: number }[] = [];

  const propagate = (state: number[], u: number) => {
    const next = state.map((_, rowIndex) => state.reduce((sum, value, columnIndex) => sum + value * (system.A[rowIndex]?.[columnIndex] ?? 0), 0) + (system.B[rowIndex]?.[0] ?? 0) * u);
    const y = next.reduce((sum, value, columnIndex) => sum + value * (system.C[0]?.[columnIndex] ?? 0), 0) + (system.D[0]?.[0] ?? 0) * u;
    return { next, y };
  };

  for (let step = 0; step < 36; step += 1) {
    let best = { cost: Number.POSITIVE_INFINITY, u: 0, y: 0 };
    for (const fraction of candidateFractions) {
      const desired = fraction * slewLimit;
      const u = clamp(lastU + desired, -outputLimit, outputLimit);
      let state = [...x];
      let runningCost = 0;
      let output = 0;
      for (let horizon = 0; horizon < predictionHorizon; horizon += 1) {
        const horizonU = horizon < controlHorizon ? u : 0;
        const propagated = propagate(state, horizonU);
        state = propagated.next;
        output = propagated.y;
        const constraintPenalty = Math.max(0, Math.abs(output) - outputLimit);
        runningCost += output * output + 0.12 * horizonU * horizonU + 50 * constraintPenalty * constraintPenalty;
      }
      if (runningCost < best.cost) best = { cost: runningCost, u, y: output };
    }
    const actual = propagate(x, best.u);
    x = actual.next;
    lastU = best.u;
    preview.push({ step: Number(((step + 1) * dt).toFixed(2)), y: actual.y, u: best.u, constrainedY: clamp(actual.y, -outputLimit, outputLimit) });
  }

  return preview;
}

const chartConfig = {
  output: { label: "Output", color: "#8b7bff" },
  clamp: { label: "Constraint", color: "#ff8a8a" },
  control: { label: "Control", color: "#4f8bff" },
} as const;

function matrixToText(matrix: Matrix) {
  return matrix.map((row) => row.map((value) => value.toFixed(3)).join(", ")).join("\n");
}

export function MPCSimulator({
  system,
  exampleLabel,
  onLoadExample,
}: {
  system: StateSpaceSystem;
  exampleLabel: string;
  onLoadExample?: () => void;
}) {
  const [predictionHorizon, setPredictionHorizon] = useState(8);
  const [controlHorizon, setControlHorizon] = useState(3);
  const [outputLimit, setOutputLimit] = useState(0.6);
  const [slewLimit, setSlewLimit] = useState(0.25);
  const lqr = useMemo(() => computeLQR(system.A, system.B, system.A.map((row, rowIndex) => row.map((_, columnIndex) => (rowIndex === columnIndex ? 2 : 0))), [[0.4]]), [system]);
  const lqrStep = useMemo(() => simulateStepResponse(system, { duration: 6, dt: 0.05, feedbackGain: lqr.K }), [system, lqr]);
  const predictive = useMemo(() => simulatePredictiveController({ system, predictionHorizon, controlHorizon, outputLimit, slewLimit }), [system, predictionHorizon, controlHorizon, outputLimit, slewLimit]);
  const phasePortrait = predictive.map((point, index) => ({ x1: point.y, x2: index === 0 ? point.y / (system.sampleTime ?? 0.1) : (point.y - predictive[index - 1].y) / (system.sampleTime ?? 0.1) }));
  const sliderConfigs: { label: string; value: number; setter: Dispatch<SetStateAction<number>>; min: number; max: number; step: number }[] = [
    { label: "Prediction horizon (Nₚ)", value: predictionHorizon, setter: setPredictionHorizon, min: 4, max: 16, step: 1 },
    { label: "Control horizon (N𝚌)", value: controlHorizon, setter: setControlHorizon, min: 1, max: 8, step: 1 },
    { label: "Output limit", value: outputLimit, setter: setOutputLimit, min: 0.2, max: 1.2, step: 0.05 },
    { label: "Δu max", value: slewLimit, setter: setSlewLimit, min: 0.05, max: 0.5, step: 0.01 },
  ];

  return (
    <section className="card-surface rounded-3xl p-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Advanced &amp; predictive control</p>
          <h3 className="mt-2 font-display text-2xl font-bold">MPC, sliding-mode intuition, and policy previews</h3>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">Preview constrained receding-horizon behavior for {exampleLabel}, then compare it with a fast LQR baseline.</p>
        </div>
        {onLoadExample ? <Button type="button" variant="outline" onClick={onLoadExample}>Load example</Button> : null}
      </div>

      <details className="mt-5 rounded-2xl border border-[var(--border)] bg-white/[0.02] p-4">
        <summary className="cursor-pointer list-none text-sm font-semibold text-[var(--foreground)]">Theory &amp; Glossary</summary>
        <div className="mt-4 grid gap-4 lg:grid-cols-3 text-sm text-[var(--muted)]">
          <div>
            <h4 className="font-semibold text-[var(--foreground)]">Overview</h4>
            <p className="mt-2 leading-6">MPC looks ahead, scores future trajectories, and picks the next control move that best respects constraints. Sliding-mode plots show how states move toward a desired switching surface. The policy preview offers an intuitive “what will the controller do next?” view.</p>
          </div>
          <div>
            <h4 className="font-semibold text-[var(--foreground)]">Math</h4>
            <p className="mt-2 font-mono text-xs leading-6 text-slate-300">min Σ(y² + λu²), x[k+1]=Ax[k]+Bu[k], y[k]=Cx[k]</p>
            <p className="mt-2 font-mono text-xs leading-6 text-slate-300">Nₚ = prediction horizon, N𝚌 = control horizon, |Δu| ≤ Δuₘₐₓ</p>
          </div>
          <div>
            <h4 className="font-semibold text-[var(--foreground)]">4-step workflow</h4>
            <ol className="mt-2 list-decimal space-y-1 pl-4 leading-6">
              <li>Set horizon lengths and constraint ceilings.</li>
              <li>Run the predictive trajectory and watch clipping behavior.</li>
              <li>Compare constrained output to the LQR reference.</li>
              <li>Inspect the phase portrait for sliding-surface intuition.</li>
            </ol>
          </div>
        </div>
      </details>

      <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {sliderConfigs.map(({ label, value, setter, min, max, step }) => (
          <label key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
            <span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">{label}</span>
            <input className="mt-3 w-full" type="range" min={min} max={max} step={step} value={value} onChange={(event) => setter(Number(event.target.value))} />
            <span className="mt-2 block text-lg font-semibold text-[var(--foreground)]">{value.toFixed(step < 1 ? 2 : 0)}</span>
          </label>
        ))}
      </div>

      <div className="mt-6 grid gap-5 xl:grid-cols-2">
        <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
          <p className="text-sm font-semibold text-[var(--foreground)]">Receding-horizon trajectory</p>
          <ChartContainer config={chartConfig} className="mt-4 h-72 w-full">
            <LineChart data={predictive}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="step" unit=" s" />
              <YAxis />
              <Tooltip content={<ChartTooltipContent />} />
              <Legend />
              <Line type="monotone" dataKey="y" stroke="var(--color-output)" dot={false} strokeWidth={2} />
              <Line type="monotone" dataKey="constrainedY" stroke="var(--color-clamp)" dot={false} strokeDasharray="5 5" />
            </LineChart>
          </ChartContainer>
        </div>
        <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
          <p className="text-sm font-semibold text-[var(--foreground)]">LQR reference vs MPC control effort</p>
          <ChartContainer config={chartConfig} className="mt-4 h-72 w-full">
            <LineChart data={predictive.map((point, index) => ({ ...point, lqr: lqrStep[index]?.y ?? 0 }))}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="step" unit=" s" />
              <YAxis />
              <Tooltip content={<ChartTooltipContent />} />
              <Legend />
              <Line type="monotone" dataKey="u" stroke="var(--color-control)" dot={false} strokeWidth={2} />
              <Line type="monotone" dataKey="lqr" stroke="var(--color-output)" dot={false} strokeDasharray="4 4" />
            </LineChart>
          </ChartContainer>
        </div>
        <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
          <p className="text-sm font-semibold text-[var(--foreground)]">Sliding-mode phase portrait</p>
          <ResponsiveContainer width="100%" height={280}>
            <ScatterChart>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis type="number" dataKey="x1" name="x1" />
              <YAxis type="number" dataKey="x2" name="x2" />
              <Tooltip formatter={(value) => Number(value).toFixed(3)} />
              <Scatter data={phasePortrait} fill="#6ee7b7" line />
            </ScatterChart>
          </ResponsiveContainer>
        </div>
        <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
          <p className="text-sm font-semibold text-[var(--foreground)]">Policy engine snapshot</p>
          <pre className="mt-4 overflow-auto rounded-2xl border border-[var(--border)] bg-black/25 p-4 text-xs leading-6 text-slate-200">{matrixToText(lqr.K)}</pre>
          <p className="mt-4 text-sm leading-6 text-[var(--muted)]">The preview pairs an LQR-derived gain with a brute-force constrained search over admissible future control moves. It is designed for intuition and rapid UI feedback, not plant certification.</p>
        </div>
      </div>
    </section>
  );
}
