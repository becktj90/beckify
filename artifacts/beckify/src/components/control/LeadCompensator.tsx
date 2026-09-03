import { useMemo, useState } from "react";
import { CartesianGrid, Legend, Line, LineChart, ReferenceLine, Tooltip, XAxis, YAxis } from "recharts";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import {
  closedLoopTransferFunction,
  computePerformanceMetrics,
  designLeadCancellation,
  designLeadPhaseBump,
  designLeadRaiseWn,
  formatTransferFunction,
  leadNetworkParts,
  predictedSecondOrderMetrics,
  seriesTransferFunction,
  simulateStepResponse,
  transferFunctionToStateSpace,
  type TransferFunction,
} from "@/utils/controlEngine";

const chartConfig = {
  plant: { label: "Plant", color: "#4f8bff" },
  lead: { label: "With lead", color: "#8b7bff" },
} as const;

type LeadMode = "phase" | "raise" | "cancel";

const fmt = (value: number | null | undefined, digits = 3) =>
  value === null || value === undefined || !Number.isFinite(value) ? "—" : Number(value).toFixed(digits);

function ohms(n: number) {
  if (n >= 1e6) return `${(n / 1e6).toPrecision(3)} MΩ`;
  if (n >= 1e3) return `${(n / 1e3).toPrecision(3)} kΩ`;
  return `${n.toPrecision(3)} Ω`;
}

export function LeadCompensator({ plant }: { plant: TransferFunction }) {
  const [mode, setMode] = useState<LeadMode>("phase");
  const [phase, setPhase] = useState(50);
  const [omega, setOmega] = useState(4);
  const [zeta, setZeta] = useState(0.5);
  const [wn, setWn] = useState(4);
  const [alpha, setAlpha] = useState(0.2);
  const [plantPole, setPlantPole] = useState(-0.5);
  const [actualPole, setActualPole] = useState(-0.45);

  const designed = useMemo(() => {
    if (mode === "phase") return designLeadPhaseBump(phase, omega);
    if (mode === "raise") return designLeadRaiseWn(zeta, wn, alpha);
    return designLeadCancellation(Math.abs(plantPole), alpha);
  }, [mode, phase, omega, zeta, wn, alpha, plantPole]);

  const gc = designed.tf;
  const parts = useMemo(() => leadNetworkParts(designed.alpha, designed.T), [designed]);
  const metrics = useMemo(() => predictedSecondOrderMetrics(mode === "raise" ? wn : omega, zeta), [mode, wn, omega, zeta]);

  const compensated = useMemo(
    () => seriesTransferFunction(gc, plant),
    [gc, plant],
  );
  const closedPlant = useMemo(() => closedLoopTransferFunction(plant), [plant]);
  const closedLead = useMemo(() => closedLoopTransferFunction(compensated), [compensated]);

  const plantStep = useMemo(
    () => simulateStepResponse(transferFunctionToStateSpace(closedPlant), { duration: 8, dt: 0.02 }),
    [closedPlant],
  );
  const leadStep = useMemo(
    () => simulateStepResponse(transferFunctionToStateSpace(closedLead), { duration: 8, dt: 0.02 }),
    [closedLead],
  );
  const plantMetrics = useMemo(() => computePerformanceMetrics(plantStep), [plantStep]);
  const leadMetrics = useMemo(() => computePerformanceMetrics(leadStep), [leadStep]);

  const mismatch = useMemo(() => {
    const assumed = Math.abs(plantPole);
    const actual = Math.abs(actualPole);
    const designedCancel = designLeadCancellation(assumed, alpha);
    const trueCascade = seriesTransferFunction(designedCancel.tf, {
      numerator: [1],
      denominator: [1, actual],
    });
    return { designedCancel, trueCascade };
  }, [plantPole, actualPole, alpha]);

  const chartData = plantStep.map((point, index) => ({
    t: Number(point.t.toFixed(3)),
    plant: point.y,
    lead: leadStep[index]?.y ?? null,
  }));

  return (
    <section className="card-surface rounded-3xl p-5 md:p-6" aria-labelledby="lead-heading">
      <h2 id="lead-heading" className="font-display text-xl font-bold text-[var(--foreground)]">
        Lead compensator
      </h2>
      <p className="mt-1 max-w-3xl text-sm leading-6 text-[var(--muted)]">
        Gc(s) = (T s + 1) / (α T s + 1) with 0 &lt; α &lt; 1. Two design stories: a PD-like lead that raises ωn, and
        pole-zero cancellation versus dominant-pole placement. Cancelling a slow plant pole looks tidy on paper and
        falls apart when the plant moves a few percent — that residue is the point of the third mode.
      </p>

      <div className="mt-5 flex flex-wrap gap-2" role="group" aria-label="Lead design mode">
        {(
          [
            ["phase", "Phase bump at ωm"],
            ["raise", "PD-like: raise ωn"],
            ["cancel", "Cancel vs dominant pole"],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            aria-pressed={mode === id}
            onClick={() => setMode(id)}
            className={`rounded-full border px-4 py-1.5 text-sm font-semibold ${
              mode === id
                ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]"
                : "border-[var(--border)] text-[var(--muted)]"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="mt-5 grid gap-5 lg:grid-cols-2">
        <div className="space-y-4">
          {mode === "phase" ? (
            <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="font-mono text-xs text-[var(--muted)]">
                α = (1 − sin φ) / (1 + sin φ), T = 1 / (ωm √α)
              </p>
              <div className="mt-3 grid gap-3 sm:grid-cols-2">
                <label className="text-sm text-[var(--muted)]">
                  Desired phase bump φ (deg)
                  <input
                    type="number"
                    step="1"
                    value={phase}
                    onChange={(event) => setPhase(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  ωm (rad/s)
                  <input
                    type="number"
                    step="any"
                    value={omega}
                    onChange={(event) => setOmega(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
              </div>
            </div>
          ) : null}

          {mode === "raise" ? (
            <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="font-mono text-xs text-[var(--muted)]">Zero at −ζ ωn, pole at zero/α. Predict tr, Mp from 2nd-order envelopes.</p>
              <div className="mt-3 grid gap-3 sm:grid-cols-3">
                <label className="text-sm text-[var(--muted)]">
                  ζ
                  <input
                    type="number"
                    step="0.05"
                    value={zeta}
                    onChange={(event) => setZeta(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  ωn (rad/s)
                  <input
                    type="number"
                    step="any"
                    value={wn}
                    onChange={(event) => setWn(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  α
                  <input
                    type="number"
                    step="0.05"
                    min={0.05}
                    max={0.95}
                    value={alpha}
                    onChange={(event) => setAlpha(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
              </div>
              <p className="mt-3 text-xs text-[var(--muted)]">
                Envelope: Mp ≈ {fmt(metrics.overshootPercent, 1)}%, tr ≈ {fmt(metrics.riseTime, 2)} s, ts ≈{" "}
                {fmt(metrics.settlingTime, 2)} s. Dominant-pole estimates only.
              </p>
            </div>
          ) : null}

          {mode === "cancel" ? (
            <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="text-sm leading-6 text-[var(--muted)]">
                T = 1/|p|. If the real plant pole is not exactly p, (s − p_actual)/(s − p_assumed) leaves a slow
                dipole. Dominant-pole placement does not rely on that cancellation.
              </p>
              <div className="mt-3 grid gap-3 sm:grid-cols-3">
                <label className="text-sm text-[var(--muted)]">
                  Assumed plant pole
                  <input
                    type="number"
                    step="any"
                    value={plantPole}
                    onChange={(event) => setPlantPole(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  Actual plant pole
                  <input
                    type="number"
                    step="any"
                    value={actualPole}
                    onChange={(event) => setActualPole(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  α
                  <input
                    type="number"
                    step="0.05"
                    min={0.05}
                    max={0.95}
                    value={alpha}
                    onChange={(event) => setAlpha(Number(event.target.value))}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
              </div>
              <p className="mt-3 font-mono text-xs leading-5 text-[var(--accent-2)]">
                Designed Gc = {formatTransferFunction(mismatch.designedCancel.tf)}. Cascade with the actual pole:{" "}
                {formatTransferFunction(mismatch.trueCascade)}.
              </p>
            </div>
          ) : null}

          <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--accent)]">Show the math</p>
            <p className="mt-2 font-mono text-sm text-[var(--foreground)]">
              α = {fmt(designed.alpha)} · T = {fmt(designed.T)} s
            </p>
            <p className="mt-1 font-mono text-sm text-[var(--accent-2)]">Gc(s) = {formatTransferFunction(gc)}</p>
            <p className="mt-3 text-xs leading-5 text-[var(--muted)]">
              Generic analog lead (inverting): T = R1 C1, α T = R2 C2. Example at C = 0.1 µF: R1 = {ohms(parts.R1)}, R2 ={" "}
              {ohms(parts.R2)}, C1 = C2 = 0.1 µF. Same topology lives in the Analog Design Workbench — not a copy of any
              lab schematic.
            </p>
          </div>
        </div>

        <div className="rounded-2xl border border-[var(--border)] bg-black/20 p-4">
          <p className="text-sm font-semibold text-[var(--foreground)]">Unity-feedback step: plant vs plant·Gc</p>
          <ChartContainer config={chartConfig} className="mt-3 aspect-auto h-72 w-full">
            <LineChart data={chartData} margin={{ top: 8, right: 12, bottom: 4, left: -12 }}>
              <CartesianGrid strokeDasharray="3 3" strokeOpacity={0.25} />
              <XAxis dataKey="t" unit=" s" tick={{ fontSize: 11 }} />
              <YAxis tick={{ fontSize: 11 }} />
              <Tooltip content={<ChartTooltipContent />} />
              <Legend />
              <ReferenceLine y={1} stroke="#7f8ba3" strokeDasharray="4 4" />
              <Line type="monotone" dataKey="plant" stroke="var(--color-plant)" dot={false} strokeWidth={1.5} strokeDasharray="5 4" />
              <Line type="monotone" dataKey="lead" stroke="var(--color-lead)" dot={false} strokeWidth={2.5} />
            </LineChart>
          </ChartContainer>
          <div className="mt-3 grid grid-cols-2 gap-2 text-xs text-[var(--muted)]">
            <p>Plant Mp {fmt(plantMetrics.overshoot, 1)}% · ts {fmt(plantMetrics.settlingTime, 2)} s</p>
            <p>Lead Mp {fmt(leadMetrics.overshoot, 1)}% · ts {fmt(leadMetrics.settlingTime, 2)} s</p>
          </div>
        </div>
      </div>
    </section>
  );
}

export default LeadCompensator;
