import { useEffect, useMemo, useState } from "react";
import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Button } from "@/components/ui/button";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import {
  ackermannShowWork,
  computeKalmanGain,
  computeLQR,
  formatComplex,
  formatPolynomial,
  placePolesAckermann,
  simulateStepResponse,
  type Matrix,
  type StateSpaceSystem,
} from "@/utils/controlEngine";

const chartConfig = {
  output: { label: "Output", color: "#8b7bff" },
  control: { label: "Control", color: "#4f8bff" },
} as const;

function diagonalFromText(value: string) {
  const entries = value.split(/[\s,]+/).map((part) => Number(part)).filter((part) => Number.isFinite(part));
  return entries.map((entry, index) => entries.map((_, column) => (index === column ? entry : 0)));
}

function matrixToText(matrix: Matrix) {
  return matrix.map((row) => row.map((value) => value.toFixed(3)).join(", ")).join("\n");
}

function defaultDiagonalText(order: number, first: number, rest: number) {
  return Array.from({ length: order }, (_, index) => (index === 0 ? first : rest)).join(", ");
}

function defaultPoleText(order: number) {
  return Array.from({ length: order }, (_, index) => `-${(2.5 + index * 0.4).toFixed(1)}`).join(", ");
}

export function LQRStudio({
  system,
  exampleLabel,
  onLoadExample,
}: {
  system: StateSpaceSystem;
  exampleLabel: string;
  onLoadExample?: () => void;
}) {
  const order = system.A.length;
  const [qText, setQText] = useState(() => defaultDiagonalText(order, 12, 1));
  const [rText, setRText] = useState("0.5");
  const [wText, setWText] = useState(() => defaultDiagonalText(order, 0.4, 0.1));
  const [vText, setVText] = useState("0.3");
  const [poleText, setPoleText] = useState(() => defaultPoleText(order));

  useEffect(() => {
    setQText(defaultDiagonalText(order, 12, 1));
    setWText(defaultDiagonalText(order, 0.4, 0.1));
    setPoleText(defaultPoleText(order));
  }, [exampleLabel, order]);

  const q = useMemo(() => diagonalFromText(qText), [qText]);
  const r = useMemo(() => diagonalFromText(rText), [rText]);
  const w = useMemo(() => diagonalFromText(wText), [wText]);
  const v = useMemo(() => diagonalFromText(vText), [vText]);
  const lqr = useMemo(() => computeLQR(system.A, system.B, q, r), [system, q, r]);
  const kalman = useMemo(() => computeKalmanGain(system.A, system.C, w, v), [system, w, v]);
  const desiredPoles = useMemo(
    () => poleText.split(/[\s,]+/).map(Number).filter(Number.isFinite),
    [poleText],
  );
  const polePlacement = useMemo(() => {
    try {
      return placePolesAckermann(system.A, system.B, desiredPoles);
    } catch {
      return [[0]];
    }
  }, [system, desiredPoles]);
  const ackermann = useMemo(() => {
    try {
      return ackermannShowWork(system.A, system.B, desiredPoles);
    } catch {
      return null;
    }
  }, [system, desiredPoles]);
  const closedLoop = useMemo(() => simulateStepResponse(system, { duration: 8, dt: 0.02, feedbackGain: lqr.K }), [system, lqr]);

  return (
    <section className="card-surface rounded-3xl p-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Modern &amp; optimal control</p>
          <h3 className="mt-2 font-display text-2xl font-bold">LQR, LQG, and pole placement</h3>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">Tune state weighting, estimator noise covariances, and target poles for {exampleLabel} without leaving the page.</p>
        </div>
        {onLoadExample ? <Button type="button" variant="outline" onClick={onLoadExample}>Load example</Button> : null}
      </div>

      <details className="mt-5 rounded-2xl border border-[var(--border)] bg-white/[0.02] p-4">
        <summary className="cursor-pointer list-none text-sm font-semibold text-[var(--foreground)]">Theory &amp; Glossary</summary>
        <div className="mt-4 grid gap-4 lg:grid-cols-3 text-sm text-[var(--muted)]">
          <div>
            <h4 className="font-semibold text-[var(--foreground)]">Overview</h4>
            <p className="mt-2 leading-6">LQR balances state error against control effort. LQG adds a Kalman estimator so noisy sensors still support stable feedback. Pole placement lets you directly target closed-loop dynamics.</p>
          </div>
          <div>
            <h4 className="font-semibold text-[var(--foreground)]">Math</h4>
            <p className="mt-2 font-mono text-xs leading-6 text-slate-300">x˙ = Ax + Bu, y = Cx + Du</p>
            <p className="mt-2 font-mono text-xs leading-6 text-slate-300">J = ∫(xᵀQx + uᵀRu)dt, AᵀP + PA − PBR⁻¹BᵀP + Q = 0</p>
          </div>
          <div>
            <h4 className="font-semibold text-[var(--foreground)]">Parameter glossary</h4>
            <ul className="mt-2 space-y-1 leading-6">
              <li><strong>A</strong>: system dynamics matrix</li>
              <li><strong>B</strong>: input matrix</li>
              <li><strong>Q</strong>: state deviation penalty</li>
              <li><strong>R</strong>: control effort penalty</li>
              <li><strong>W, V</strong>: process and measurement noise covariance</li>
            </ul>
          </div>
        </div>
      </details>

      <div className="mt-6 grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="grid gap-4 md:grid-cols-2">
          <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
            <span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Q diagonal</span>
            <textarea className="mt-3 min-h-24 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-sm text-[var(--foreground)]" value={qText} onChange={(event) => setQText(event.target.value)} />
          </label>
          <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
            <span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">R diagonal</span>
            <textarea className="mt-3 min-h-24 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-sm text-[var(--foreground)]" value={rText} onChange={(event) => setRText(event.target.value)} />
          </label>
          <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
            <span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">W diagonal</span>
            <textarea className="mt-3 min-h-24 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-sm text-[var(--foreground)]" value={wText} onChange={(event) => setWText(event.target.value)} />
          </label>
          <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
            <span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">V diagonal</span>
            <textarea className="mt-3 min-h-24 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-sm text-[var(--foreground)]" value={vText} onChange={(event) => setVText(event.target.value)} />
          </label>
          <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)] md:col-span-2">
            <span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Desired closed-loop poles</span>
            <textarea className="mt-3 min-h-20 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-sm text-[var(--foreground)]" value={poleText} onChange={(event) => setPoleText(event.target.value)} />
          </label>
        </div>

        <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
          <p className="text-sm font-semibold text-[var(--foreground)]">Closed-loop step response</p>
          <ChartContainer config={chartConfig} className="mt-4 aspect-auto h-72 w-full">
            <LineChart data={closedLoop}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="t" unit=" s" />
              <YAxis />
              <Tooltip content={<ChartTooltipContent />} />
              <Line type="monotone" dataKey="y" stroke="var(--color-output)" dot={false} strokeWidth={2} />
            </LineChart>
          </ChartContainer>
        </div>
      </div>

      <div className="mt-6 grid gap-4 xl:grid-cols-3">
        <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">LQR gain K</p>
          <pre className="mt-3 overflow-auto text-xs leading-6 text-slate-200">{matrixToText(lqr.K)}</pre>
          <p className="mt-3 text-xs text-[var(--muted)]">Closed-loop poles: {lqr.closedLoopPoles.map(formatComplex).join(" · ")}</p>
        </div>
        <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Kalman gain L</p>
          <pre className="mt-3 overflow-auto text-xs leading-6 text-slate-200">{matrixToText(kalman.L)}</pre>
          <p className="mt-3 text-xs text-[var(--muted)]">Estimator poles: {kalman.estimatorPoles.map(formatComplex).join(" · ")}</p>
        </div>
        <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Ackermann feedback</p>
          <pre className="mt-3 overflow-auto text-xs leading-6 text-slate-200">{matrixToText(polePlacement)}</pre>
          <p className="mt-3 text-xs leading-5 text-[var(--muted)]">
            {ackermann?.formula} Desired φ(s) = {ackermann ? formatPolynomial(ackermann.desired) : "—"}. Open-loop χ(s) ={" "}
            {ackermann ? formatPolynomial(ackermann.openLoop) : "—"}.
            {ackermann?.companion
              ? " Companion 2nd/nth order: K is just the coefficient difference β − a, so the numbers above should match that subtraction."
              : " This realisation is not controllable companion, so K comes from the full Ackermann formula rather than β − a."}
          </p>
        </div>
      </div>
    </section>
  );
}
