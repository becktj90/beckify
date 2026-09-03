import { useMemo, useState } from "react";
import { CartesianGrid, Legend, Line, LineChart, ReferenceLine, Tooltip, XAxis, YAxis } from "recharts";
import { AlertTriangle, RotateCcw, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import type { Plant } from "@/data/control-plants";
import {
  closedLoopTransferFunction,
  computePerformanceMetrics,
  fitReactionCurve,
  isStable,
  loopErrorConstants,
  pidTransferFunction,
  seriesTransferFunction,
  simulatePidWithSaturation,
  simulateStepResponse,
  transferFunctionToStateSpace,
  ultimateGain,
  zieglerNicholsReactionCurve,
  zieglerNicholsUltimate,
  type PidGains,
  type ZnForm,
  type ZnVariant,
} from "@/utils/controlEngine";

type ControllerMode = "open" | "P" | "PD" | "PI" | "PID";

const MODES: { id: ControllerMode; label: string; hint: string }[] = [
  { id: "open", label: "Open loop", hint: "No feedback — the plant driven by the command. Type 1 ramps; a load disturbance walks straight through." },
  { id: "P", label: "P", hint: "Proportional only. Compare ess, Kv, and disturbance rejection against the dashed open-loop trace." },
  { id: "PD", label: "PD", hint: "Derivative damping without an integrator. Type number of the loop does not increase." },
  { id: "PI", label: "PI", hint: "Integral action raises Type by one and drives step ess toward zero." },
  { id: "PID", label: "PID", hint: "P then I then D. Ziegler–Nichols is a tuning aid, not autotune of a real plant." },
];

const chartConfig = {
  response: { label: "Closed loop", color: "#8b7bff" },
  openLoop: { label: "Open loop", color: "#4f8bff" },
  windup: { label: "Unclamped", color: "#f5c451" },
  clamped: { label: "Anti-windup", color: "#6ee7b7" },
  disturbance: { label: "Load disturbance", color: "#ff8a8a" },
} as const;

function gainsForMode(mode: ControllerMode, gains: PidGains): PidGains {
  if (mode === "open") return { kp: 0, ki: 0, kd: 0 };
  if (mode === "P") return { kp: gains.kp, ki: 0, kd: 0 };
  if (mode === "PD") return { kp: gains.kp, ki: 0, kd: gains.kd };
  if (mode === "PI") return { kp: gains.kp, ki: gains.ki, kd: 0 };
  return gains;
}

function znFormForMode(mode: ControllerMode): ZnForm {
  if (mode === "P") return "P";
  if (mode === "PI") return "PI";
  return "PID";
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

  let best = { kp: 1, ki: mode === "P" || mode === "PD" ? 0 : 0.5, kd: mode === "PD" || mode === "PID" ? 0.5 : 0 };
  let bestScore = score(best);
  const keys: (keyof PidGains)[] =
    mode === "P" ? ["kp"] : mode === "PD" ? ["kp", "kd"] : mode === "PI" ? ["kp", "ki"] : ["kp", "ki", "kd"];

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
const fmtK = (value: number) => {
  if (!Number.isFinite(value)) return "∞";
  if (Math.abs(value) < 1e-12) return "0";
  return value.toPrecision(3);
};

export function StepTuner({ plant }: { plant: Plant }) {
  const [mode, setMode] = useState<ControllerMode>("P");
  const [gains, setGains] = useState<PidGains>(plant.suggested);
  const [showOpenLoop, setShowOpenLoop] = useState(true);
  const [showDisturbance, setShowDisturbance] = useState(false);
  const [showWindup, setShowWindup] = useState(false);
  const [uMax, setUMax] = useState(0.6);
  const [plantId, setPlantId] = useState(plant.id);
  const [ku, setKu] = useState(4);
  const [pu, setPu] = useState(2);
  const [fopdtK, setFopdtK] = useState(1);
  const [fopdtL, setFopdtL] = useState(0.4);
  const [fopdtT, setFopdtT] = useState(2);
  const [znVariant, setZnVariant] = useState<ZnVariant>("classic");
  const [storyStep, setStoryStep] = useState(0);

  if (plantId !== plant.id) {
    setPlantId(plant.id);
    setGains(plant.suggested);
    setStoryStep(0);
  }

  const closed = useMemo(() => simulate(plant, mode, gains), [plant, mode, gains]);
  const open = useMemo(() => simulate(plant, "open", gains), [plant, gains]);

  const diverged = closed.response.some((point) => !Number.isFinite(point.y) || Math.abs(point.y) > 1e6);
  const unstable = !closed.stable || diverged;

  const metrics = useMemo(
    () => (unstable ? null : computePerformanceMetrics(closed.response)),
    [closed.response, unstable],
  );

  const openLoopForErrors = useMemo(() => {
    if (mode === "open") return plant.transferFunction;
    return seriesTransferFunction(pidTransferFunction(gainsForMode(mode, gains)), plant.transferFunction);
  }, [mode, gains, plant.transferFunction]);
  const errors = useMemo(() => loopErrorConstants(openLoopForErrors), [openLoopForErrors]);
  const plantErrors = useMemo(() => loopErrorConstants(plant.transferFunction), [plant.transferFunction]);

  const disturbance = useMemo(() => {
    const dt = plant.duration / 600;
    const distTf =
      mode === "open"
        ? plant.transferFunction
        : {
            numerator: plant.transferFunction.numerator,
            denominator: closedLoopTransferFunction(
              seriesTransferFunction(pidTransferFunction(gainsForMode(mode, gains)), plant.transferFunction),
            ).denominator,
          };
    try {
      return simulateStepResponse(transferFunctionToStateSpace(distTf), { duration: plant.duration, dt });
    } catch {
      return [];
    }
  }, [plant, mode, gains]);

  const ss = useMemo(() => transferFunctionToStateSpace(plant.transferFunction), [plant.transferFunction]);
  const windup = useMemo(() => {
    if (!showWindup || mode === "open") return { free: [], clamped: [] };
    const common = {
      plant: ss,
      kp: gains.kp,
      ki: mode === "P" || mode === "PD" ? 0 : Math.max(gains.ki, 0.4),
      kd: mode === "P" || mode === "PI" ? 0 : gains.kd,
      duration: plant.duration,
      dt: plant.duration / 500,
      uMin: -uMax,
      uMax,
    };
    return {
      free: simulatePidWithSaturation({ ...common, antiWindup: false }),
      clamped: simulatePidWithSaturation({ ...common, antiWindup: true }),
    };
  }, [showWindup, mode, ss, gains, plant.duration, uMax]);

  const chartData = useMemo(() => {
    const openByIndex = open.response;
    return closed.response.map((point, index) => {
      const openValue = openByIndex[index]?.y;
      return {
        t: Number(point.t.toFixed(3)),
        response: Number.isFinite(point.y) ? point.y : null,
        openLoop: showOpenLoop && Number.isFinite(openValue) && Math.abs(openValue) < 1e6 ? openValue : null,
        disturbance: showDisturbance && Number.isFinite(disturbance[index]?.y) ? disturbance[index].y : null,
        windup: showWindup ? windup.free[index]?.y ?? null : null,
        clamped: showWindup ? windup.clamped[index]?.y ?? null : null,
      };
    });
  }, [closed.response, open.response, showOpenLoop, showDisturbance, disturbance, showWindup, windup]);

  const applyAutoTune = () => {
    const tuned = autoTune(plant, mode);
    if (tuned) setGains({ kp: round(tuned.kp), ki: round(tuned.ki), kd: round(tuned.kd) });
  };

  const applyZn = (source: "ultimate" | "reaction") => {
    const form = znFormForMode(mode === "open" || mode === "PD" ? "PID" : mode);
    const table =
      source === "ultimate"
        ? zieglerNicholsUltimate(ku, pu, form, znVariant)
        : zieglerNicholsReactionCurve(fopdtK, fopdtL, fopdtT, form, znVariant);
    setGains({ kp: round(table.kp), ki: round(table.ki), kd: round(table.kd) });
    if (mode === "open" || mode === "PD") setMode(form === "P" ? "P" : form === "PI" ? "PI" : "PID");
  };

  const estimateKu = () => {
    const result = ultimateGain(plant.transferFunction);
    if (result.Ku) setKu(round(result.Ku));
    if (result.Pu) setPu(round(result.Pu));
  };

  const fitFopdt = () => {
    const fit = fitReactionCurve(open.response);
    if (Number.isFinite(fit.K)) setFopdtK(round(fit.K));
    if (Number.isFinite(fit.L)) setFopdtL(round(Math.max(fit.L, 0.01)));
    if (Number.isFinite(fit.T)) setFopdtT(round(Math.max(fit.T, 0.05)));
  };

  const sequential = [
    {
      label: "1. P until it holds",
      run: () => {
        setMode("P");
        setGains((current) => ({ ...current, ki: 0, kd: 0, kp: Math.max(current.kp, 2) }));
        setStoryStep(1);
      },
    },
    {
      label: "2. Add I (kill ess)",
      run: () => {
        setMode("PI");
        setGains((current) => ({ ...current, kd: 0, ki: Math.max(current.ki, 0.4) }));
        setStoryStep(2);
      },
    },
    {
      label: "3. Add D (damp)",
      run: () => {
        setMode("PID");
        setGains((current) => ({ ...current, kd: Math.max(current.kd, 0.4) }));
        setStoryStep(3);
      },
    },
  ];

  const sliders: { key: keyof PidGains; label: string; max: number; step: number }[] = [
    { key: "kp", label: "Kp — proportional", max: 50, step: 0.05 },
    { key: "ki", label: "Ki — integral", max: 30, step: 0.05 },
    { key: "kd", label: "Kd — derivative", max: 20, step: 0.05 },
  ];
  const visibleSliders = sliders.filter(({ key }) => {
    if (mode === "open") return false;
    if (key === "kp") return true;
    if (key === "ki") return mode === "PI" || mode === "PID";
    return mode === "PD" || mode === "PID";
  });

  return (
    <section className="card-surface rounded-3xl p-5 md:p-6" aria-labelledby="tuner-heading">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 id="tuner-heading" className="font-display text-xl font-bold text-[var(--foreground)]">
            Open loop vs P / PID
          </h2>
          <p className="mt-1 text-sm text-[var(--muted)]">
            Same plant, unit step. Open loop vs proportional (and PI/PD/PID) on one plot. Type {plantErrors.type} plant
            · Kv = {fmtK(plantErrors.Kv)}. Educational tuning aid — not autotune of a real actuator.
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
            Open-loop overlay
          </label>
          <label className="flex items-center gap-2 text-xs font-semibold text-[var(--muted)]">
            <input
              type="checkbox"
              checked={showDisturbance}
              onChange={(event) => setShowDisturbance(event.target.checked)}
              className="h-4 w-4 accent-[var(--accent-2)]"
            />
            Load disturbance
          </label>
          <label className="flex items-center gap-2 text-xs font-semibold text-[var(--muted)]">
            <input
              type="checkbox"
              checked={showWindup}
              onChange={(event) => setShowWindup(event.target.checked)}
              className="h-4 w-4 accent-[var(--accent-2)]"
            />
            Anti-windup
          </label>
          <Button type="button" variant="outline" size="sm" onClick={() => setGains(plant.suggested)}>
            <RotateCcw className="mr-1.5 h-3.5 w-3.5" /> Reset
          </Button>
          {mode !== "open" ? (
            <Button type="button" size="sm" onClick={applyAutoTune}>
              <Sparkles className="mr-1.5 h-3.5 w-3.5" /> ISE search
            </Button>
          ) : null}
        </div>
      </div>

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

      <div className="mt-4 flex flex-wrap gap-2">
        {sequential.map((step, index) => (
          <button
            key={step.label}
            type="button"
            onClick={step.run}
            className={`rounded-full border px-3 py-1.5 text-xs font-semibold ${
              storyStep === index + 1
                ? "border-[var(--accent)] text-[var(--foreground)]"
                : "border-[var(--border)] text-[var(--muted)]"
            }`}
          >
            {step.label}
          </button>
        ))}
      </div>
      <p className="mt-2 text-xs leading-5 text-[var(--muted)]">
        Sequential story on an unstable plant (library: 1/(s−1) or 1/s²): P first so it stops running away, I next to
        kill offset, D last to put damping back. Ziegler–Nichols below is a second method, not a replacement for that
        walk.
      </p>

      <div className="mt-5 grid gap-5 lg:grid-cols-[minmax(0,1.55fr)_minmax(0,1fr)]">
        <div className="rounded-2xl border border-[var(--border)] bg-black/20 p-4">
          {unstable && !showWindup ? (
            <div className="flex h-72 flex-col items-center justify-center gap-3 text-center">
              <AlertTriangle className="h-8 w-8 text-amber-300" aria-hidden="true" />
              <p className="font-display text-lg font-bold text-[var(--foreground)]">This loop is unstable</p>
              <p className="max-w-md text-sm leading-6 text-[var(--muted)]">
                The linear TF response diverges. Back the gains off, walk P → I → D, or try ISE search.
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
                {showDisturbance ? (
                  <Line
                    type="monotone"
                    dataKey="disturbance"
                    name="Plant-input disturbance"
                    stroke="var(--color-disturbance)"
                    dot={false}
                    strokeWidth={1.5}
                    connectNulls
                  />
                ) : null}
                {showWindup ? (
                  <>
                    <Line type="monotone" dataKey="windup" name="Saturated, unclamped I" stroke="var(--color-windup)" dot={false} strokeWidth={2} connectNulls />
                    <Line type="monotone" dataKey="clamped" name="Anti-windup clamp" stroke="var(--color-clamped)" dot={false} strokeWidth={2.5} connectNulls />
                  </>
                ) : (
                  <Line
                    type="monotone"
                    dataKey="response"
                    name={mode === "open" ? "Plant" : "Closed loop"}
                    stroke="var(--color-response)"
                    dot={false}
                    strokeWidth={2.5}
                    connectNulls
                  />
                )}
              </LineChart>
            </ChartContainer>
          )}
        </div>

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
                    className="h-10 w-24 rounded-lg border border-[var(--border)] bg-black/30 px-2 text-right text-sm text-[var(--foreground)]"
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
              Open loop: a Type {plantErrors.type} plant with Kv = {fmtK(plantErrors.Kv)}. A Type 1 1/s ramps on a
              position command — that is why it still needs a loop.
            </div>
          )}

          {showWindup ? (
            <label className="block rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
              Actuator ±umax = {uMax}
              <input
                type="range"
                min={0.1}
                max={2}
                step={0.05}
                value={uMax}
                onChange={(event) => setUMax(Number(event.target.value))}
                className="mt-3 h-6 w-full cursor-pointer accent-[var(--accent)]"
              />
            </label>
          ) : null}

          <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Loop Type / Kv</p>
            <p className="mt-2 font-mono text-sm text-[var(--foreground)]">
              Type {errors.type} · Kp={fmtK(errors.Kp)} · Kv={fmtK(errors.Kv)} · Ka={fmtK(errors.Ka)}
            </p>
            <p className="mt-2 text-xs leading-5 text-[var(--muted)]">
              Step ess {fmt(Number.isFinite(errors.step) ? errors.step : null, 3)} · ramp ess{" "}
              {Number.isFinite(errors.ramp) ? fmt(errors.ramp, 3) : "∞"}. Extra far-left poles (lag slider) barely
              move these DC identities; they do move damping on the locus.
            </p>
            <p className="mt-2 text-xs leading-5 text-[var(--muted)]">{plant.teaches}</p>
          </div>
        </div>
      </div>

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
                label === "Stability" ? (unstable ? "text-amber-300" : "text-emerald-300") : "text-[var(--foreground)]"
              }`}
            >
              {value}
            </p>
          </div>
        ))}
      </div>

      <details className="mt-5 rounded-2xl border border-[var(--border)] bg-black/15 p-4">
        <summary className="cursor-pointer text-sm font-semibold text-[var(--foreground)]">
          Ziegler–Nichols (Ku, Pu) and reaction-curve — tuning aid
        </summary>
        <div className="mt-4 grid gap-4 lg:grid-cols-2">
          <div>
            <p className="font-mono text-xs text-[var(--muted)]">
              Classic PID: Kp=0.6 Ku, Ti=Pu/2, Td=Pu/8. Modified PID: Kp=0.33 Ku, Ti=Pu/2, Td=Pu/3. Ki=Kp/Ti, Kd=Kp Td.
            </p>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <label className="text-sm text-[var(--muted)]">
                Ku
                <input
                  type="number"
                  step="any"
                  value={ku}
                  onChange={(event) => setKu(Number(event.target.value))}
                  className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                />
              </label>
              <label className="text-sm text-[var(--muted)]">
                Pu (s)
                <input
                  type="number"
                  step="any"
                  value={pu}
                  onChange={(event) => setPu(Number(event.target.value))}
                  className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                />
              </label>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              <Button type="button" variant="outline" size="sm" onClick={estimateKu}>
                Estimate Ku, Pu from G
              </Button>
              <Button type="button" size="sm" onClick={() => applyZn("ultimate")}>
                Apply ultimate ZN
              </Button>
            </div>
          </div>
          <div>
            <p className="font-mono text-xs text-[var(--muted)]">
              Reaction curve FOPDT: classic PID Kp=1.2 T/(K L), Ti=2L, Td=0.5L.
            </p>
            <div className="mt-3 grid grid-cols-3 gap-3">
              <label className="text-sm text-[var(--muted)]">
                K
                <input
                  type="number"
                  step="any"
                  value={fopdtK}
                  onChange={(event) => setFopdtK(Number(event.target.value))}
                  className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                />
              </label>
              <label className="text-sm text-[var(--muted)]">
                L (s)
                <input
                  type="number"
                  step="any"
                  value={fopdtL}
                  onChange={(event) => setFopdtL(Number(event.target.value))}
                  className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                />
              </label>
              <label className="text-sm text-[var(--muted)]">
                T (s)
                <input
                  type="number"
                  step="any"
                  value={fopdtT}
                  onChange={(event) => setFopdtT(Number(event.target.value))}
                  className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                />
              </label>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              <Button type="button" variant="outline" size="sm" onClick={fitFopdt}>
                Fit from open-loop step
              </Button>
              <Button type="button" size="sm" onClick={() => applyZn("reaction")}>
                Apply reaction ZN
              </Button>
            </div>
          </div>
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          {(["classic", "modified"] as const).map((variant) => (
            <button
              key={variant}
              type="button"
              aria-pressed={znVariant === variant}
              onClick={() => setZnVariant(variant)}
              className={`rounded-full border px-3 py-1.5 text-xs font-semibold ${
                znVariant === variant
                  ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]"
                  : "border-[var(--border)] text-[var(--muted)]"
              }`}
            >
              {variant === "classic" ? "Classic ZN" : "Modified ZN"}
            </button>
          ))}
        </div>
      </details>
    </section>
  );
}

export default StepTuner;
