import { useMemo, useState, type Dispatch, type SetStateAction } from "react";
import { Binary, BrainCircuit, Gauge, Radar, SlidersHorizontal, Waves, Zap } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { Button } from "@/components/ui/button";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { BodePlot } from "@/components/control/BodePlot";
import { LQRStudio } from "@/components/control/LQRStudio";
import { MPCSimulator } from "@/components/control/MPCSimulator";
import {
  computePerformanceMetrics,
  discretizeStateSpace,
  formatComplex,
  parseMatrixInput,
  parsePolynomialInput,
  poleZeroMap,
  simulateDiscreteSystem,
  simulateStepResponse,
  transferFunctionToStateSpace,
  type StateSpaceSystem,
  type TransferFunction,
} from "@/utils/controlEngine";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import { CartesianGrid, Line, LineChart, Tooltip, XAxis, YAxis } from "recharts";

type Preset = {
  id: string;
  label: string;
  summary: string;
  transferFunction: TransferFunction;
  stateSpace: StateSpaceSystem;
  zpk: { zeros: number[]; poles: number[]; gain: number };
  modelingSteps: string[];
};

const CONTROL_PRESETS: Preset[] = [
  {
    id: "inverted-pendulum",
    label: "Inverted Pendulum on a Cart",
    summary: "Unstable 4th-order state-space model for LQR, pole placement, and constrained MPC comparisons.",
    transferFunction: { numerator: [1], denominator: [1, -1.15, -6.2, -2.1, 0.8] },
    stateSpace: {
      A: [[0, 1, 0, 0], [0, -0.18, 2.67, 0], [0, 0, 0, 1], [0, -0.44, 31.18, 0]],
      B: [[0], [1.81], [0], [4.55]],
      C: [[1, 0, 0, 0]],
      D: [[0]],
      sampleTime: 0.1,
    },
    zpk: { zeros: [], poles: [5.56, -5.62, -0.14, -0.02], gain: 1 },
    modelingSteps: [
      "Start from the cart position and pendulum angle state equations.",
      "Compare open-loop poles to see why the upright equilibrium is unstable.",
      "Use LQR and MPC to stabilize the plant and respect actuator limits.",
      "Compare constrained and unconstrained step responses side by side.",
    ],
  },
  {
    id: "dc-motor",
    label: "DC Motor Speed Control",
    summary: "Second-order motor model for PID tuning, Bode analysis, and disturbance rejection tradeoffs.",
    transferFunction: { numerator: [0.6], denominator: [0.002, 0.08, 0.52] },
    stateSpace: {
      A: [[0, 1], [-260, -40]],
      B: [[0], [300]],
      C: [[1, 0]],
      D: [[0]],
      sampleTime: 0.05,
    },
    zpk: { zeros: [], poles: [-20, -20], gain: 1.154 },
    modelingSteps: [
      "Express the armature, inertia, damping, and back-EMF terms as a transfer function.",
      "Inspect crossover and phase margin before changing loop gains.",
      "Tune PID or LQR to reduce droop under a load-torque step.",
      "Validate rise time, overshoot, and settling time after each change.",
    ],
  },
  {
    id: "aircraft-pitch",
    label: "Aircraft Pitch Dynamics",
    summary: "Short-period pitch dynamics for root-locus exploration and state feedback design.",
    transferFunction: { numerator: [1.2, 0.8], denominator: [1, 1.4, 3.2, 0.9] },
    stateSpace: {
      A: [[0, 1, 0], [0, -0.8, 1], [0, -3.2, -0.6]],
      B: [[0], [0.5], [3.4]],
      C: [[1, 0, 0]],
      D: [[0]],
      sampleTime: 0.1,
    },
    zpk: { zeros: [-0.667], poles: [-0.352, -0.524, -0.524], gain: 1.2 },
    modelingSteps: [
      "Enter the elevator-to-pitch transfer function or short-period state matrices.",
      "Trace the root locus as loop gain changes.",
      "Watch damping ratio and natural frequency as poles move left or right.",
      "Pick a gain or pole set that balances responsiveness and passenger comfort.",
    ],
  },
  {
    id: "mass-spring",
    label: "Mass-Spring-Damper",
    summary: "Continuous-to-discrete conversion playground for ZPK, transfer function, and sampled response comparisons.",
    transferFunction: { numerator: [1], denominator: [1, 1.4, 12] },
    stateSpace: {
      A: [[0, 1], [-12, -1.4]],
      B: [[0], [1]],
      C: [[1, 0]],
      D: [[0]],
      sampleTime: 0.1,
    },
    zpk: { zeros: [], poles: [-0.7, -0.7], gain: 0.083 },
    modelingSteps: [
      "Define the mass, damping, and spring terms in s-domain form.",
      "Convert the continuous model to z-domain using ZOH or Tustin.",
      "Compare sampled poles against the unit-circle boundary.",
      "Use the discrete response to pick an appropriate controller sample time.",
    ],
  },
];

const TABS = [
  { id: "modeling", label: "System Modeling", icon: Binary },
  { id: "classic", label: "Classic Linear Analysis", icon: Waves },
  { id: "time", label: "Time-Domain & Performance Tuning", icon: Gauge },
  { id: "modern", label: "Modern & Optimal Control", icon: BrainCircuit },
  { id: "advanced", label: "Advanced & Predictive Control", icon: Radar },
] as const;

const responseChartConfig = {
  output: { label: "Output", color: "#8b7bff" },
  discrete: { label: "Discrete", color: "#4f8bff" },
} as const;

function fmt(value: number | null | undefined, digits = 3) {
  if (value === null || value === undefined || Number.isNaN(value)) return "—";
  return value.toFixed(digits);
}

function matrixToText(matrix: number[][]) {
  return matrix.map((row) => row.join(", ")).join("\n");
}

function PidTunerCard({ preset }: { preset: Preset }) {
  const [mode, setMode] = useState("PID");
  const [method, setMethod] = useState("IMC");
  const [gain, setGain] = useState(1.1);
  const [timeConstant, setTimeConstant] = useState(0.6);
  const [deadTime, setDeadTime] = useState(0.08);

  const tuning = useMemo(() => {
    const K = Math.max(gain, 0.01);
    const T = Math.max(timeConstant, 0.01);
    const L = Math.max(deadTime, 0.001);
    if (method === "Ziegler-Nichols") {
      if (mode === "P") return { kp: T / (K * L), ki: 0, kd: 0 };
      if (mode === "PI") return { kp: 0.9 * T / (K * L), ki: 0.3 / L, kd: 0 };
      if (mode === "PD") return { kp: 1.1 * T / (K * L), ki: 0, kd: 0.125 * L };
      return { kp: 1.2 * T / (K * L), ki: 0.5 / L, kd: 0.5 * L };
    }
    if (method === "Cohen-Coon") {
      const ratio = L / T;
      if (mode === "PI") return { kp: (0.9 / K) * (T / L) * (1 + ratio / 12), ki: (3.33 + ratio) / T, kd: 0 };
      return { kp: (1.35 / K) * (T / L) * (1 + ratio / 5), ki: (2.5 + 0.66 * ratio) / T, kd: (0.37 - 0.37 * ratio) * L };
    }
    const filter = Math.max(L, 0.05);
    if (mode === "PI") return { kp: T / (K * (filter + L)), ki: 1 / T, kd: 0 };
    if (mode === "PD") return { kp: (T + 0.5 * L) / (K * (filter + L)), ki: 0, kd: (T * L) / (2 * T + L) };
    if (mode === "P") return { kp: T / (K * (filter + L)), ki: 0, kd: 0 };
    return { kp: (T + 0.5 * L) / (K * (filter + L)), ki: 1 / (T + 0.5 * L), kd: (T * L) / (2 * T + L) };
  }, [mode, method, gain, timeConstant, deadTime]);
  const sliderConfigs: { label: string; value: number; setter: Dispatch<SetStateAction<number>>; min: number; max: number; step: number }[] = [
    { label: "Plant gain", value: gain, setter: setGain, min: 0.2, max: 4, step: 0.05 },
    { label: "Time constant", value: timeConstant, setter: setTimeConstant, min: 0.1, max: 3, step: 0.05 },
    { label: "Dead time", value: deadTime, setter: setDeadTime, min: 0.01, max: 0.5, step: 0.01 },
  ];

  return (
    <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">PID tuner</p>
          <h3 className="mt-1 font-display text-xl font-bold">P, PI, PD, and PID quick tuning</h3>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">Use beginner-friendly heuristics for {preset.label} before refining with the response charts.</p>
        </div>
      </div>
      <details className="mt-4 rounded-2xl border border-[var(--border)] bg-white/[0.02] p-4">
        <summary className="cursor-pointer list-none text-sm font-semibold text-[var(--foreground)]">Theory &amp; Glossary</summary>
        <div className="mt-3 grid gap-3 lg:grid-cols-3 text-sm text-[var(--muted)]">
          <p>Rise time is the 10–90% climb to target. Settling time is when the response stays inside the 2% band. Overshoot shows how far the response exceeds the target.</p>
          <p className="font-mono text-xs leading-6 text-slate-300">u(t)=Kp e(t)+Ki∫e(t)dt+Kd de(t)/dt</p>
          <ol className="list-decimal space-y-1 pl-4 leading-6"><li>Estimate plant gain, time constant, and dead time.</li><li>Choose a tuning method.</li><li>Pick controller structure.</li><li>Validate against the step metrics below.</li></ol>
        </div>
      </details>
      <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
        <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Controller</span><select className="mt-3 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-[var(--foreground)]" value={mode} onChange={(event) => setMode(event.target.value)}><option>P</option><option>PI</option><option>PD</option><option>PID</option></select></label>
        <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Method</span><select className="mt-3 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-[var(--foreground)]" value={method} onChange={(event) => setMethod(event.target.value)}><option>IMC</option><option>Ziegler-Nichols</option><option>Cohen-Coon</option></select></label>
        {sliderConfigs.map(({ label, value, setter, min, max, step }) => <label key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">{label}</span><input className="mt-3 w-full" type="range" min={min} max={max} step={step} value={value} onChange={(event) => setter(Number(event.target.value))} /><span className="mt-2 block text-lg font-semibold text-[var(--foreground)]">{value.toFixed(2)}</span></label>)}
      </div>
      <div className="mt-5 grid gap-3 sm:grid-cols-3">
        {[ ["Kp", tuning.kp], ["Ki", tuning.ki], ["Kd", tuning.kd] ].map(([label, value]) => <div key={String(label)} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4"><p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">{label}</p><p className="mt-2 text-xl font-semibold text-[var(--foreground)]">{fmt(Number(value), 3)}</p></div>)}
      </div>
    </div>
  );
}

export default function ControlSystemsPage() {
  const [activeTab, setActiveTab] = useState<(typeof TABS)[number]["id"]>("modeling");
  const [presetId, setPresetId] = useState(CONTROL_PRESETS[0].id);
  const [numeratorText, setNumeratorText] = useState(CONTROL_PRESETS[0].transferFunction.numerator.join(", "));
  const [denominatorText, setDenominatorText] = useState(CONTROL_PRESETS[0].transferFunction.denominator.join(", "));
  const [aText, setAText] = useState(matrixToText(CONTROL_PRESETS[0].stateSpace.A));
  const [bText, setBText] = useState(matrixToText(CONTROL_PRESETS[0].stateSpace.B));
  const [cText, setCText] = useState(matrixToText(CONTROL_PRESETS[0].stateSpace.C));
  const [dText, setDText] = useState(matrixToText(CONTROL_PRESETS[0].stateSpace.D));
  const [discretizationMethod, setDiscretizationMethod] = useState<"zoh" | "tustin">("zoh");
  const [sampleTime, setSampleTime] = useState(0.1);

  const preset = useMemo(() => CONTROL_PRESETS.find((entry) => entry.id === presetId) ?? CONTROL_PRESETS[0], [presetId]);
  const transferFunction = useMemo<TransferFunction>(() => ({ numerator: parsePolynomialInput(numeratorText), denominator: parsePolynomialInput(denominatorText) }), [numeratorText, denominatorText]);
  const stateSpace = useMemo<StateSpaceSystem>(() => ({ A: parseMatrixInput(aText), B: parseMatrixInput(bText), C: parseMatrixInput(cText), D: parseMatrixInput(dText), sampleTime }), [aText, bText, cText, dText, sampleTime]);
  const continuousStep = useMemo(() => simulateStepResponse(stateSpace, { duration: 8, dt: 0.02 }), [stateSpace]);
  const metrics = useMemo(() => computePerformanceMetrics(continuousStep), [continuousStep]);
  const discrete = useMemo(() => discretizeStateSpace(stateSpace, sampleTime, discretizationMethod), [stateSpace, sampleTime, discretizationMethod]);
  const discreteStep = useMemo(() => simulateDiscreteSystem(discrete, { steps: 40 }), [discrete]);
  const discreteByTime = useMemo(() => new Map(discreteStep.map((point) => [point.t.toFixed(2), point.y])), [discreteStep]);
  const tfStateSpace = useMemo(() => transferFunctionToStateSpace(transferFunction), [transferFunction]);
  const tfPoleZero = useMemo(() => poleZeroMap(transferFunction), [transferFunction]);
  const matrixEditors: { label: string; value: string; setter: Dispatch<SetStateAction<string>> }[] = [
    { label: "A matrix", value: aText, setter: setAText },
    { label: "B matrix", value: bText, setter: setBText },
    { label: "C matrix", value: cText, setter: setCText },
    { label: "D matrix", value: dText, setter: setDText },
  ];

  const loadPreset = (next: Preset) => {
    setPresetId(next.id);
    setNumeratorText(next.transferFunction.numerator.join(", "));
    setDenominatorText(next.transferFunction.denominator.join(", "));
    setAText(matrixToText(next.stateSpace.A));
    setBText(matrixToText(next.stateSpace.B));
    setCText(matrixToText(next.stateSpace.C));
    setDText(matrixToText(next.stateSpace.D));
    setSampleTime(next.stateSpace.sampleTime ?? 0.1);
  };

  return (
    <Layout>
      <SchemaHead title="Control System Toolbox | Beckify" description="Interactive control-system modeling, Bode and root-locus analysis, PID tuning, LQR/LQG design, and predictive-control visualizers." path="/control-systems" />
      <FadeIn>
        <SectionHeader title="Control System Toolbox" subtitle="A modern, interactive control workspace for modeling plants, tuning loops, exploring stability, and comparing classical, optimal, and predictive control strategies." icon={SlidersHorizontal} />
      </FadeIn>

      <FadeIn delay={0.04}>
        <div className="grid gap-6 xl:grid-cols-[260px_minmax(0,1fr)]">
          <aside className="card-surface h-fit rounded-3xl p-4 xl:sticky xl:top-24">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Toolbox hub</p>
            <div className="mt-4 space-y-2" role="tablist" aria-label="Control toolbox sections">
              {TABS.map(({ id, label, icon: Icon }) => {
                const active = activeTab === id;
                return (
                  <button
                    key={id}
                    id={`tab-${id}`}
                    type="button"
                    role="tab"
                    aria-selected={active}
                    aria-controls={`panel-${id}`}
                    onClick={() => setActiveTab(id)}
                    className={`flex w-full items-center gap-3 rounded-2xl border px-4 py-3 text-left transition ${active ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]" : "border-[var(--border)] bg-white/[0.02] text-[var(--muted)] hover:border-[var(--accent)]/50 hover:text-[var(--foreground)]"}`}
                  >
                    <span className="rounded-xl bg-black/20 p-2"><Icon className="h-4 w-4" /></span>
                    <span className="text-sm font-semibold">{label}</span>
                  </button>
                );
              })}
            </div>
            <div className="mt-5 rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Example presets</p>
              <div className="mt-3 space-y-2">
                {CONTROL_PRESETS.map((entry) => (
                  <button key={entry.id} type="button" onClick={() => loadPreset(entry)} className={`w-full rounded-xl border px-3 py-2 text-left text-sm transition ${presetId === entry.id ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]" : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--accent)]/50 hover:text-[var(--foreground)]"}`}>
                    <span className="block font-semibold">{entry.label}</span>
                    <span className="mt-1 block text-xs leading-5">{entry.summary}</span>
                  </button>
                ))}
              </div>
            </div>
          </aside>

          <div className="space-y-6">
            <section id="panel-modeling" role="tabpanel" aria-labelledby="tab-modeling" hidden={activeTab !== "modeling"} className="space-y-6">
              <div className="card-surface rounded-3xl p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">System modeling</p>
                    <h3 className="mt-2 font-display text-2xl font-bold">LTI objects, state-space, ZPK, and discretization</h3>
                    <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">Build transfer functions, state-space models, and sampled equivalents from one shared mathematical engine.</p>
                  </div>
                  <Button type="button" variant="outline" onClick={() => loadPreset(preset)}>Reload example</Button>
                </div>
                <details className="mt-5 rounded-2xl border border-[var(--border)] bg-white/[0.02] p-4">
                  <summary className="cursor-pointer list-none text-sm font-semibold text-[var(--foreground)]">How it Works &amp; Math Engine</summary>
                  <div className="mt-4 grid gap-4 lg:grid-cols-3 text-sm text-[var(--muted)]">
                    <div><h4 className="font-semibold text-[var(--foreground)]">Plain-English overview</h4><p className="mt-2 leading-6">System models are the shared language behind every response plot and controller design. Define the plant once, then reuse it across classical and modern tools.</p></div>
                    <div><h4 className="font-semibold text-[var(--foreground)]">Mathematical formulations</h4><p className="mt-2 font-mono text-xs leading-6 text-slate-300">G(s)=N(s)/D(s), x˙=Ax+Bu, y=Cx+Du, G(z)=c2d(G(s),Ts)</p></div>
                    <div><h4 className="font-semibold text-[var(--foreground)]">4-step workflow</h4><ol className="mt-2 list-decimal space-y-1 pl-4 leading-6">{preset.modelingSteps.map((step) => <li key={step}>{step}</li>)}</ol></div>
                  </div>
                </details>
                <div className="mt-6 grid gap-5 xl:grid-cols-2">
                  <div className="grid gap-4">
                    <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Transfer function numerator</span><input className="mt-3 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-[var(--foreground)]" value={numeratorText} onChange={(event) => setNumeratorText(event.target.value)} /></label>
                    <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Transfer function denominator</span><input className="mt-3 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-[var(--foreground)]" value={denominatorText} onChange={(event) => setDenominatorText(event.target.value)} /></label>
                    <div className="grid gap-4 md:grid-cols-2">
                      <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Discretization method</span><select className="mt-3 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-[var(--foreground)]" value={discretizationMethod} onChange={(event) => setDiscretizationMethod(event.target.value as "zoh" | "tustin")}><option value="zoh">Zero-Order Hold (ZOH)</option><option value="tustin">Bilinear (Tustin)</option></select></label>
                      <label className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Sample time</span><input className="mt-3 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-[var(--foreground)]" type="number" min="0.01" step="0.01" value={sampleTime} onChange={(event) => setSampleTime(Number(event.target.value))} /></label>
                    </div>
                  </div>
                  <div className="grid gap-4 md:grid-cols-2">
                    {matrixEditors.map(({ label, value, setter }) => <label key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]"><span className="block text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">{label}</span><textarea className="mt-3 min-h-28 w-full rounded-xl border border-[var(--border)] bg-black/25 p-3 text-[var(--foreground)]" value={value} onChange={(event) => setter(event.target.value)} /></label>)}
                  </div>
                </div>
                <div className="mt-6 grid gap-4 xl:grid-cols-3">
                  <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4"><p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Zero-pole-gain</p><p className="mt-3 text-sm leading-6 text-[var(--muted)]">Zeros: {preset.zpk.zeros.length ? preset.zpk.zeros.join(", ") : "none"}</p><p className="text-sm leading-6 text-[var(--muted)]">Poles: {preset.zpk.poles.join(", ")}</p><p className="text-sm leading-6 text-[var(--muted)]">Gain: {preset.zpk.gain}</p></div>
                  <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4"><p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Transfer-function poles</p><p className="mt-3 text-sm leading-6 text-[var(--muted)]">{tfPoleZero.poles.map(formatComplex).join(" · ") || "—"}</p><p className="mt-3 text-xs text-[var(--muted)]">Zeros: {tfPoleZero.zeros.map(formatComplex).join(" · ") || "none"}</p></div>
                  <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4"><p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Discrete model preview</p><pre className="mt-3 overflow-auto text-xs leading-6 text-slate-200">A = {matrixToText(discrete.A)}{"\n"}B = {matrixToText(discrete.B)}</pre></div>
                </div>
              </div>
            </section>

            <section id="panel-classic" role="tabpanel" aria-labelledby="tab-classic" hidden={activeTab !== "classic"}>
              <BodePlot title="Frequency-domain analysis workspace" transferFunction={transferFunction} systemExample={preset.label} onLoadExample={() => loadPreset(preset)} />
            </section>

            <section id="panel-time" role="tabpanel" aria-labelledby="tab-time" hidden={activeTab !== "time"} className="space-y-6">
              <div className="card-surface rounded-3xl p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Time-domain analysis</p>
                    <h3 className="mt-2 font-display text-2xl font-bold">Step, impulse intuition, and transient performance</h3>
                    <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">Real-time RK4 simulation powers the continuous response, while sampled previews show what your controller will feel like after discretization.</p>
                  </div>
                </div>
                <details className="mt-5 rounded-2xl border border-[var(--border)] bg-white/[0.02] p-4">
                  <summary className="cursor-pointer list-none text-sm font-semibold text-[var(--foreground)]">Theory &amp; Glossary</summary>
                  <div className="mt-4 grid gap-4 lg:grid-cols-3 text-sm text-[var(--muted)]">
                    <div><p>Control engineers use time-domain plots to verify tracking quality, actuator burden, and disturbance rejection with the same language used in specifications.</p></div>
                    <div><p className="font-mono text-xs leading-6 text-slate-300">Rise time tᵣ: 10%→90%, Settling time tₛ: 2% band, %OS = (peak-target)/target × 100</p></div>
                    <div><ol className="list-decimal space-y-1 pl-4 leading-6"><li>Load a preset plant.</li><li>Inspect continuous and sampled responses.</li><li>Read transient metrics.</li><li>Tune with PID or state feedback.</li></ol></div>
                  </div>
                </details>
                <div className="mt-6 grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
                  <div className="rounded-3xl border border-[var(--border)] bg-black/20 p-4">
                    <p className="text-sm font-semibold text-[var(--foreground)]">Continuous vs discrete step response</p>
                    <ChartContainer config={responseChartConfig} className="mt-4 h-80 w-full">
                      <LineChart data={continuousStep.map((point) => ({ ...point, discrete: discreteByTime.get(point.t.toFixed(2)) ?? null }))}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="t" unit=" s" />
                        <YAxis />
                        <Tooltip content={<ChartTooltipContent />} />
                        <Line type="monotone" dataKey="y" stroke="var(--color-output)" dot={false} strokeWidth={2} />
                        <Line type="monotone" dataKey="discrete" stroke="var(--color-discrete)" dot={false} strokeDasharray="5 5" />
                      </LineChart>
                    </ChartContainer>
                  </div>
                  <div className="grid gap-4">
                    {[
                      ["Rise time", `${fmt(metrics.riseTime, 2)} s`],
                      ["Peak time", `${fmt(metrics.peakTime, 2)} s`],
                      ["Overshoot", `${fmt(metrics.overshoot, 2)} %`],
                      ["Settling time", `${fmt(metrics.settlingTime, 2)} s`],
                      ["Steady-state error", fmt(metrics.steadyStateError, 3)],
                      ["TF-derived output matrix", matrixToText(tfStateSpace.C)],
                    ].map(([label, value]) => <div key={String(label)} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4"><p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">{label}</p><p className="mt-2 text-lg font-semibold text-[var(--foreground)] whitespace-pre-wrap">{String(value)}</p></div>)}
                  </div>
                </div>
              </div>
              <PidTunerCard preset={preset} />
            </section>

            <section id="panel-modern" role="tabpanel" aria-labelledby="tab-modern" hidden={activeTab !== "modern"}>
              <LQRStudio system={stateSpace} exampleLabel={preset.label} onLoadExample={() => loadPreset(preset)} />
            </section>

            <section id="panel-advanced" role="tabpanel" aria-labelledby="tab-advanced" hidden={activeTab !== "advanced"}>
              <MPCSimulator system={discrete} exampleLabel={preset.label} onLoadExample={() => loadPreset(preset)} />
            </section>
          </div>
        </div>
      </FadeIn>
    </Layout>
  );
}
