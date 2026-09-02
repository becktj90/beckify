import { useMemo } from "react";
import { CartesianGrid, Legend, Line, LineChart, ReferenceLine, Tooltip, XAxis, YAxis } from "recharts";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import { computePerformanceMetrics, simulateQualitativeNonlinearity } from "@/utils/controlEngine";

const chartConfig = {
  linear: { label: "Linear", color: "#8b7bff" },
  nonlinear: { label: "With nonlinearity", color: "#f5c451" },
} as const;

const fmt = (value: number | null | undefined, digits = 2) =>
  value === null || value === undefined || !Number.isFinite(value) ? "—" : value.toFixed(digits);

export function NonlinearityPanel() {
  const linear = useMemo(
    () => simulateQualitativeNonlinearity({ wn: 2, zeta: 0.3, kind: "linear" }),
    [],
  );
  const sat = useMemo(
    () => simulateQualitativeNonlinearity({ wn: 2, zeta: 0.3, kind: "saturation", uMax: 0.35 }),
    [],
  );
  const coulomb = useMemo(
    () => simulateQualitativeNonlinearity({ wn: 2, zeta: 0.3, kind: "coulomb", friction: 0.28 }),
    [],
  );
  const backlash = useMemo(
    () => simulateQualitativeNonlinearity({ wn: 2, zeta: 0.3, kind: "backlash", backlash: 0.18 }),
    [],
  );

  const linearM = useMemo(() => computePerformanceMetrics(linear.map((p) => ({ ...p, u: 1, states: [] }))), [linear]);
  const rows = [
    ["Saturation", sat, "Actuator hits ±umax. Predicted Mp/ts from ζ, ωn assume unbounded force, so the real rise stretches and the overshoot usually drops."],
    ["Coulomb friction", coulomb, "A constant opposing force that does not go to zero at rest. The loop can stick short of the setpoint — linear ess formulas say zero; this one does not."],
    ["Backlash", backlash, "A deadband in the output (gear lash). The measured Mp/ts of the internal state no longer match what you see, and small commands do nothing."],
  ] as const;

  return (
    <section className="card-surface rounded-3xl p-5 md:p-6" aria-labelledby="nl-heading">
      <h2 id="nl-heading" className="font-display text-xl font-bold text-[var(--foreground)]">
        Nonlinearities, qualitatively
      </h2>
      <p className="mt-1 max-w-3xl text-sm leading-6 text-[var(--muted)]">
        Linear Mp and ts come from ζ and ωn. Saturation, Coulomb friction, and backlash break that contract. These
        traces are a 2nd-order mass–spring–damper with one extra rule — not a nonlinear DAE solver, and not for
        safety-critical commissioning.
      </p>
      <p className="mt-2 font-mono text-xs text-[var(--muted)]">
        Linear reference: ζ = 0.3, ωn = 2 → Mp ≈ {fmt(linearM.overshoot, 1)}%, ts ≈ {fmt(linearM.settlingTime, 2)} s
      </p>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        {rows.map(([title, series, note]) => {
          const metrics = computePerformanceMetrics(series.map((p) => ({ ...p, u: 1, states: [] })));
          const data = linear.map((point, index) => ({
            t: Number(point.t.toFixed(3)),
            linear: point.y,
            nonlinear: series[index]?.y ?? null,
          }));
          return (
            <div key={title} className="rounded-2xl border border-[var(--border)] bg-black/20 p-4">
              <p className="text-sm font-semibold text-[var(--foreground)]">{title}</p>
              <ChartContainer config={chartConfig} className="mt-3 aspect-auto h-48 w-full">
                <LineChart data={data} margin={{ top: 4, right: 8, bottom: 0, left: -16 }}>
                  <CartesianGrid strokeDasharray="3 3" strokeOpacity={0.25} />
                  <XAxis dataKey="t" hide />
                  <YAxis tick={{ fontSize: 10 }} />
                  <Tooltip content={<ChartTooltipContent />} />
                  <Legend wrapperStyle={{ fontSize: 11 }} />
                  <ReferenceLine y={1} stroke="#7f8ba3" strokeDasharray="4 4" />
                  <Line type="monotone" dataKey="linear" stroke="var(--color-linear)" dot={false} strokeWidth={1.5} />
                  <Line type="monotone" dataKey="nonlinear" stroke="var(--color-nonlinear)" dot={false} strokeWidth={2} />
                </LineChart>
              </ChartContainer>
              <p className="mt-2 text-xs text-[var(--accent-2)]">
                Mp {fmt(metrics.overshoot, 1)}% · ts {fmt(metrics.settlingTime, 2)} s · ess {fmt(metrics.steadyStateError, 3)}
              </p>
              <p className="mt-2 text-xs leading-5 text-[var(--muted)]">{note}</p>
            </div>
          );
        })}
      </div>
    </section>
  );
}

export default NonlinearityPanel;
