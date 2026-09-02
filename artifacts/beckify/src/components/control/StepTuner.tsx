import { useMemo, useState } from "react";
import { CartesianGrid, Legend, Line, LineChart, ReferenceLine, Tooltip, XAxis, YAxis } from "recharts";
import { AlertTriangle, RotateCcw, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import type { Plant } from "@/data/control-plants";
import {
  closedLoopTransferFunction,
  computePerformanceMetrics,
  isStable,
  pidTransferFunction,
  seriesTransferFunction,
  simulateStepResponse,
  transferFunctionToStateSpace,
  type PidGains,
} from "@/utils/controlEngine";

type ControllerMode = "open" | "P" | "PI" | "PID";

const MODES: { id: ControllerMode; label: string; hint: string }[] = [
  { id: "open", label: "No control", hint: "The bare plant, driven straight by the step." },
  { id: "P", label: "P", hint: "Proportional only — fast, but usually leaves an offset." },
  { id: "PI", label: "PI", hint: "Integral action removes the steady-state error." },
  { id: "PID", label: "PID", hint: "Derivative action adds damping to settle the overshoot." },
];

const chartConfig = {
  response: { label: "Closed loop", color: "#8b7bff" },
  openLoop: { label: "Open loop", color: "#4f8bff" },
} as const;

/** Zero out the gains a given controller mode does not use. */
function gainsForMode(mode: ControllerMode, gains: PidGains): PidGains {
  if (mode === "open") return { kp: 0, ki: 0, kd: 0 };
  if (mode === "P") return { kp: gains.kp, ki: 0, kd: 0 };
  if (mode === "PI") return { kp: gains.kp, ki: gains.ki, kd: 0 };
  return gains;
}

function simulate(plant: Plant, mode: ControllerMode, gains: PidGains) {
  const samples = 600;
  const dt = plant.duration / samples;
  if (mode === "open") {
    const response = simulateStepResponse(transferFunctionToStateSpace(plant.transferFunction), {
      duration: plant.duration,
      dt,
    });
    return { response, stable: isStable(plant.transferFunction) };
  }
  const controller = pidTransferFunction(gainsForMode(mode, gains));
  const closedLoop = closedLoopTransferFunction(seriesTransferFunction(controller, plant.transferFunction));
  const response = simulateStepResponse(transferFunctionToStateSpace(closedLoop), { duration: plant.duration, dt });
  return { response, stable: isStable(closedLoop) };
}

/**
 * Coordinate search for gains that track a unit step well: penalise integrated
 * squared error plus overshoot, and reject anything that is not stable. This is
 * a real search against the actual plant rather than a Ziegler-Nichols formula,
 * which would need a first-order-plus-dead-time fit the plant may not have.
 */
function autoTune(plant: Plant, mode: ControllerMode): PidGains | null {
  if (mode === "open") return null;
  const score = (candidate: PidGains) => {
    const controller = pidTransferFunction(gainsForMode(mode, candidate));
    const closedLoop = closedLoopTransferFunction(seriesTransferFunction(controller, plant.transferFunction));
    if (!isStable(closedLoop)) return Number.POSITIVE_INFINITY;
    let samples;
    try {
      samples = simulateStepResponse(transferFunctionToStateSpace(closedLoop), {
        duration: plant.duration,
        dt: plant.duration / 400,
      });
    } catch {
      return Number.POSITIVE_INFINITY;
    }
    let cost = 0;
    let peak = 0;
    for (const point of samples) {
      if (!Number.isFinite(point.y)) return Number.POSITIVE_INFINITY;
      const error = 1 - point.y;
      cost += error * error;
      peak = Math.max(peak, point.y);
    }
    return cost / samples.length + Math.max(0, peak - 1) * 4;
  };

  let best = { kp: 1, ki: mode === "P" ? 0 : 0.5, kd: mode === "PID" ? 0.5 : 0 };
  let bestScore = score(best);
  const keys: (keyof PidGains)[] = mode === "P" ? ["kp"] : mode === "PI" ? ["kp", "ki"] : ["kp", "ki", "kd"];

  for (let pass = 0; pass < 6; pass += 1) {
    for (const key of keys) {
      for (const factor of [0.4, 0.6, 0.8, 1.25, 1.7, 2.5, 4]) {
        const candidate = { ...best, [key]: Math.max(0.001, best[key] * factor) };
        const candidateScore = score(candidate);
        if (candidateScore < bestScore) {
          best = candidate;
          bestScore = candidateScore;
        }
      }
      // Seed the search when the starting point is itself unstable.
      if (!Number.isFinite(bestScore)) {
        for (const seed of [0.05, 0.2, 1, 3, 10, 30]) {
          const candidate = { ...best, [key]: seed };
          const candidateScore = score(candidate);
          if (candidateScore < bestScore) {
            best = candidate;
            bestScore = candidateScore;
          }
        }
      }
    }
  }
  return Number.isFinite(bestScore) ? best : null;
}

const round = (value: number) => Math.round(value * 1000) / 1000;
const fmt = (value: number | null, digits = 2, suffix = "") =>
  value === null || !Number.isFinite(value) ? "—" : `${value.toFixed(digits)}${suffix}`;

export function StepTuner({ plant }: { plant: Plant }) {
  const [mode, setMode] = useState<ControllerMode>("PI");
  const [gains, setGains] = useState<PidGains>(plant.suggested);
  const [showOpenLoop, setShowOpenLoop] = useState(true);
  const [plantId, setPlantId] = useState(plant.id);

  // Switching plants resets the gains to that plant's sensible starting point,
  // without an effect that would fight the user's own edits.
  if (plantId !== plant.id) {
    setPlantId(plant.id);
    setGains(plant.suggested);
  }

  const closed = useMemo(() => simulate(plant, mode, gains), [plant, mode, gains]);
  const open = useMemo(() => simulate(plant, "open", gains), [plant, gains]);

  const diverged = closed.response.some((point) => !Number.isFinite(point.y) || Math.abs(point.y) > 1e6);
  const unstable = !closed.stable || diverged;

  const metrics = useMemo(
    () => (unstable ? null : computePerformanceMetrics(closed.response)),
    [closed.response, unstable],
  );

  const chartData = useMemo(() => {
    const openByIndex = open.response;
    return closed.response.map((point, index) => {
      const openValue = openByIndex[index]?.y;
      return {
        t: Number(point.t.toFixed(3)),
        response: Number.isFinite(point.y) ? point.y : null,
        openLoop: showOpenLoop && Number.isFinite(openValue) && Math.abs(openValue) < 1e6 ? openValue : null,
      };
    });
  }, [closed.response, open.response, showOpenLoop]);

  const applyAutoTune = () => {
    const tuned = autoTune(plant, mode);
    if (tuned) setGains({ kp: round(tuned.kp), ki: round(tuned.ki), kd: round(tuned.kd) });
  };

  const sliders: { key: keyof PidGains; label: string; max: number; step: number }[] = [
    { key: "kp", label: "Kp — proportional", max: 50, step: 0.05 },
    { key: "ki", label: "Ki — integral", max: 30, step: 0.05 },
    { key: "kd", label: "Kd — derivative", max: 20, step: 0.05 },
  ];
  const visibleSliders = sliders.filter(({ key }) => {
    if (mode === "open") return false;
    if (key === "kp") return true;
    if (key === "ki") return mode === "PI" || mode === "PID";
    return mode === "PID";
  });

  return (
    <section className="card-surface rounded-3xl p-5 md:p-6" aria-labelledby="tuner-heading">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 id="tuner-heading" className="font-display text-xl font-bold text-[var(--foreground)]">
            Step response
          </h2>
          <p className="mt-1 text-sm text-[var(--muted)]">
            A unit step into {plant.name.toLowerCase()}, with the loop closed around it.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <label className="flex items-center gap-2 text-xs font-semibold text-[var(--muted)]">
            <input
              type="checkbox"
              checked={showOpenLoop}
              onChange={(event) => setShowOpenLoop(event.target.checked)}
              className="h-4 w-4 accent-[var(--accent-2)]"
            />
            Compare to open loop
          </label>
          <Button type="button" variant="outline" size="sm" onClick={() => setGains(plant.suggested)}>
            <RotateCcw className="mr-1.5 h-3.5 w-3.5" /> Reset
          </Button>
          {mode !== "open" ? (
            <Button type="button" size="sm" onClick={applyAutoTune}>
              <Sparkles className="mr-1.5 h-3.5 w-3.5" /> Auto-tune
            </Button>
          ) : null}
        </div>
      </div>

      {/* Controller mode */}
      <div className="mt-5 flex flex-wrap gap-2" role="group" aria-label="Controller type">
        {MODES.map(({ id, label }) => (
          <button
            key={id}
            type="button"
            aria-pressed={mode === id}
            onClick={() => setMode(id)}
            className={`rounded-full border px-4 py-1.5 text-sm font-semibold transition ${
              mode === id
                ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]"
                : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--accent)]/60 hover:text-[var(--foreground)]"
            }`}
          >
            {label}
          </button>
        ))}
      </div>
      <p className="mt-2 text-xs text-[var(--muted)]">{MODES.find((entry) => entry.id === mode)?.hint}</p>

      <div className="mt-5 grid gap-5 lg:grid-cols-[minmax(0,1.55fr)_minmax(0,1fr)]">
        {/* Chart */}
        <div className="rounded-2xl border border-[var(--border)] bg-black/20 p-4">
          {unstable ? (
            <div className="flex h-72 flex-col items-center justify-center gap-3 text-center">
              <AlertTriangle className="h-8 w-8 text-amber-300" aria-hidden="true" />
              <p className="font-display text-lg font-bold text-[var(--foreground)]">This loop is unstable</p>
              <p className="max-w-md text-sm leading-6 text-[var(--muted)]">
                The response diverges instead of settling, so there is no meaningful curve to plot. Back the gains off,
                or try Auto-tune to search for a stable set.
              </p>
            </div>
          ) : (
            <ChartContainer config={chartConfig} className="aspect-auto h-72 w-full">
              <LineChart data={chartData} margin={{ top: 8, right: 12, bottom: 4, left: -12 }}>
                <CartesianGrid strokeDasharray="3 3" strokeOpacity={0.25} />
                <XAxis dataKey="t" unit=" s" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip content={<ChartTooltipContent />} />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <ReferenceLine y={1} stroke="#7f8ba3" strokeDasharray="4 4" />
                {showOpenLoop ? (
                  <Line
                    type="monotone"
                    dataKey="openLoop"
                    name="Open loop"
                    stroke="var(--color-openLoop)"
                    dot={false}
                    strokeWidth={1.5}
                    strokeDasharray="5 4"
                    connectNulls
                  />
                ) : null}
                <Line
                  type="monotone"
                  dataKey="response"
                  name={mode === "open" ? "Plant" : "Closed loop"}
                  stroke="var(--color-response)"
                  dot={false}
                  strokeWidth={2.5}
                  connectNulls
                />
              </LineChart>
            </ChartContainer>
          )}
        </div>

        {/* Controls */}
        <div className="space-y-4">
          {visibleSliders.length ? (
            visibleSliders.map(({ key, label, max, step }) => (
              <div key={key} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="text-sm font-semibold text-[var(--foreground)]">{label}</span>
                  <input
                    type="number"
                    step={step}
                    min={0}
                    value={gains[key]}
                    onChange={(event) => setGains((current) => ({ ...current, [key]: Number(event.target.value) }))}
                    className="w-24 rounded-lg border border-[var(--border)] bg-black/30 px-2 py-1 text-right text-sm text-[var(--foreground)]"
                    aria-label={label}
                  />
                </div>
                <input
                  type="range"
                  min={0}
                  max={max}
                  step={step}
                  value={Math.min(gains[key], max)}
                  onChange={(event) => setGains((current) => ({ ...current, [key]: Number(event.target.value) }))}
                  className="mt-3 h-6 w-full cursor-pointer accent-[var(--accent)]"
                  aria-label={`${label} slider`}
                />
              </div>
            ))
          ) : (
            <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm leading-6 text-[var(--muted)]">
              No controller in the loop — this is the plant’s own natural response. Pick P, PI, or PID to start tuning.
            </div>
          )}

          <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">What to notice</p>
            <p className="mt-2 text-sm leading-6 text-[var(--muted)]">{plant.teaches}</p>
          </div>
        </div>
      </div>

      {/* Metrics */}
      <div className="mt-5 grid gap-3 sm:grid-cols-3 xl:grid-cols-5">
        {[
          ["Rise time", fmt(metrics?.riseTime ?? null, 2, " s")],
          ["Overshoot", fmt(metrics?.overshoot ?? null, 1, " %")],
          ["Settling time", fmt(metrics?.settlingTime ?? null, 2, " s")],
          ["Steady-state error", fmt(metrics?.steadyStateError ?? null, 3)],
          ["Stability", unstable ? "Unstable" : "Stable"],
        ].map(([label, value]) => (
          <div key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">{label}</p>
            <p
              className={`mt-1.5 font-display text-lg font-bold ${
                label === "Stability"
                  ? unstable
                    ? "text-amber-300"
                    : "text-emerald-300"
                  : "text-[var(--foreground)]"
              }`}
            >
              {value}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}

export default StepTuner;
