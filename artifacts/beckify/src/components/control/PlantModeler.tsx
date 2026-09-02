import { useEffect, useMemo, useState } from "react";
import type { Plant } from "@/data/control-plants";
import {
  addRealLagPole,
  firstOrderPlant,
  formatTransferFunction,
  loopErrorConstants,
  parsePolynomialInput,
  secondOrderFromOvershootSettling,
  secondOrderPlant,
  type TransferFunction,
} from "@/utils/controlEngine";

export type ModelMode = "library" | "first" | "second" | "custom";

export type PlantModel = {
  mode: ModelMode;
  km: number;
  tau: number;
  wn: number;
  zeta: number;
  numText: string;
  denText: string;
  lagTau: number;
  mpPercent: number;
  ts: number;
};

const DEFAULT_MODEL: PlantModel = {
  mode: "library",
  km: 1,
  tau: 2,
  wn: 2,
  zeta: 0.3,
  numText: "4",
  denText: "1, 1.2, 4",
  lagTau: 0,
  mpPercent: 16.3,
  ts: 6.67,
};

function fmtErr(value: number, digits = 3) {
  if (!Number.isFinite(value)) return "∞";
  if (Math.abs(value) < 1e-12) return "0";
  return value.toFixed(digits);
}

function fmtK(value: number) {
  if (!Number.isFinite(value)) return "∞";
  if (Math.abs(value) < 1e-12) return "0";
  return value.toPrecision(4);
}

export function seedModelFromPlant(plant: Plant): PlantModel {
  const num = plant.transferFunction.numerator.join(", ");
  const den = plant.transferFunction.denominator.join(", ");
  return { ...DEFAULT_MODEL, numText: num, denText: den };
}

export function resolvePlantTransferFunction(plant: Plant, model: PlantModel): TransferFunction {
  let tf: TransferFunction = plant.transferFunction;
  if (model.mode === "first") tf = firstOrderPlant(model.km, model.tau);
  else if (model.mode === "second") tf = secondOrderPlant(model.wn, model.zeta);
  else if (model.mode === "custom") {
    const numerator = parsePolynomialInput(model.numText);
    const denominator = parsePolynomialInput(model.denText);
    if (numerator.length && denominator.length) tf = { numerator, denominator };
  }
  return addRealLagPole(tf, model.lagTau);
}

const PRESETS: { id: string; label: string; apply: () => Partial<PlantModel> }[] = [
  {
    id: "thermal",
    label: "1st-order thermal",
    apply: () => ({ mode: "first", km: 1, tau: 8, lagTau: 0 }),
  },
  {
    id: "servo",
    label: "DC motor position (Type 1)",
    apply: () => ({ mode: "custom", numText: "1", denText: "0.5, 1, 0", lagTau: 0 }),
  },
  {
    id: "unstable",
    label: "Unstable 1/s²",
    apply: () => ({ mode: "custom", numText: "1", denText: "1, 0, 0", lagTau: 0 }),
  },
];

export function PlantModeler({
  plant,
  model,
  onChange,
}: {
  plant: Plant;
  model: PlantModel;
  onChange: (next: PlantModel) => void;
}) {
  const tf = useMemo(() => resolvePlantTransferFunction(plant, model), [plant, model]);
  const errors = useMemo(() => loopErrorConstants(tf), [tf]);
  const [mpDraft, setMpDraft] = useState(String(model.mpPercent));
  const [tsDraft, setTsDraft] = useState(String(model.ts));

  useEffect(() => {
    setMpDraft(String(model.mpPercent));
    setTsDraft(String(model.ts));
  }, [model.mpPercent, model.ts]);

  const set = (patch: Partial<PlantModel>) => onChange({ ...model, ...patch });

  const applyMeasured = () => {
    const mp = Number(mpDraft);
    const ts = Number(tsDraft);
    if (!(mp > 0) || !(ts > 0) || mp >= 100) return;
    const fit = secondOrderFromOvershootSettling(mp, ts);
    set({
      mode: "second",
      wn: Number(fit.wn.toPrecision(4)),
      zeta: Number(fit.zeta.toPrecision(4)),
      mpPercent: mp,
      ts,
    });
  };

  const modes: { id: ModelMode; label: string }[] = [
    { id: "library", label: "Library G(s)" },
    { id: "first", label: "1st-order Km/(τs+1)" },
    { id: "second", label: "2nd-order ωn, ζ" },
    { id: "custom", label: "Custom polynomial" },
  ];

  return (
    <section className="card-surface rounded-3xl p-5 md:p-6" aria-labelledby="model-heading">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 id="model-heading" className="font-display text-xl font-bold text-[var(--foreground)]">
            Plant model
          </h2>
          <p className="mt-1 max-w-3xl text-sm text-[var(--muted)]">
            Fit a 1st- or 2nd-order plant from a measured step, or type G(s). Unity-feedback Type 0/1/2 identities
            (ess = 1/(1+Kp) for a Type 0 step) sit in the table — educational approximations, not a commissioning
            autotune.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {PRESETS.map((preset) => (
            <button
              key={preset.id}
              type="button"
              onClick={() => set(preset.apply())}
              className="rounded-full border border-[var(--border)] px-3 py-1.5 text-xs font-semibold text-[var(--muted)] hover:border-[var(--accent)] hover:text-[var(--foreground)]"
            >
              {preset.label}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-5 flex flex-wrap gap-2" role="group" aria-label="Plant model source">
        {modes.map(({ id, label }) => (
          <button
            key={id}
            type="button"
            aria-pressed={model.mode === id}
            onClick={() => set({ mode: id })}
            className={`rounded-full border px-4 py-1.5 text-sm font-semibold transition ${
              model.mode === id
                ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]"
                : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--accent)]/60"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="mt-5 grid gap-5 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
        <div className="space-y-4">
          {model.mode === "library" ? (
            <p className="rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm leading-6 text-[var(--muted)]">
              Using the library plant as written. Switch to 1st/2nd-order or custom to edit coefficients. An optional
              extra lag pole (op-amp feedback-capacitor analogue — generic RC, not a lab fixture) is applied on the
              right for every mode.
            </p>
          ) : null}

          {model.mode === "first" ? (
            <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="font-mono text-sm text-[var(--accent-2)]">G(s) = Km / (τ s + 1)</p>
              <div className="mt-3 grid gap-3 sm:grid-cols-2">
                <label className="text-sm text-[var(--muted)]">
                  Km
                  <input
                    type="number"
                    step="any"
                    value={model.km}
                    onChange={(event) => set({ km: Number(event.target.value) })}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  τ (s)
                  <input
                    type="number"
                    step="any"
                    value={model.tau}
                    onChange={(event) => set({ tau: Number(event.target.value) })}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
              </div>
              <p className="mt-3 text-xs leading-5 text-[var(--muted)]">
                Plugged in: G(s) = {model.km} / ({model.tau}s + 1). A step of 1 settles at Km with time constant τ.
              </p>
            </div>
          ) : null}

          {model.mode === "second" ? (
            <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="font-mono text-sm text-[var(--accent-2)]">G(s) = ωn² / (s² + 2 ζ ωn s + ωn²)</p>
              <div className="mt-3 grid gap-3 sm:grid-cols-2">
                <label className="text-sm text-[var(--muted)]">
                  ωn (rad/s)
                  <input
                    type="number"
                    step="any"
                    value={model.wn}
                    onChange={(event) => set({ wn: Number(event.target.value) })}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  ζ
                  <input
                    type="number"
                    step="any"
                    value={model.zeta}
                    onChange={(event) => set({ zeta: Number(event.target.value) })}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                  />
                </label>
              </div>
              <div className="mt-4 border-t border-[var(--border)] pt-4">
                <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--accent)]">
                  From a measured step
                </p>
                <p className="mt-1 font-mono text-xs text-[var(--muted)]">
                  ζ = −ln(Mp) / √(π² + ln²(Mp)), ωn = 4 / (ζ ts) at 2%
                </p>
                <div className="mt-3 grid gap-3 sm:grid-cols-[1fr_1fr_auto]">
                  <label className="text-sm text-[var(--muted)]">
                    Overshoot Mp (%)
                    <input
                      type="number"
                      step="any"
                      value={mpDraft}
                      onChange={(event) => setMpDraft(event.target.value)}
                      className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                    />
                  </label>
                  <label className="text-sm text-[var(--muted)]">
                    Settling ts (s)
                    <input
                      type="number"
                      step="any"
                      value={tsDraft}
                      onChange={(event) => setTsDraft(event.target.value)}
                      className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
                    />
                  </label>
                  <button
                    type="button"
                    onClick={applyMeasured}
                    className="self-end h-10 rounded-lg border border-[var(--accent)] px-4 text-sm font-semibold text-[var(--foreground)]"
                  >
                    Fit ωn, ζ
                  </button>
                </div>
              </div>
            </div>
          ) : null}

          {model.mode === "custom" ? (
            <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <p className="text-sm text-[var(--muted)]">
                Highest power first. Example: 1 / (0.5s² + s) → num <code>1</code>, den <code>0.5, 1, 0</code>.
              </p>
              <div className="mt-3 grid gap-3 sm:grid-cols-2">
                <label className="text-sm text-[var(--muted)]">
                  Numerator
                  <input
                    value={model.numText}
                    onChange={(event) => set({ numText: event.target.value })}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 font-mono text-[var(--foreground)]"
                  />
                </label>
                <label className="text-sm text-[var(--muted)]">
                  Denominator
                  <input
                    value={model.denText}
                    onChange={(event) => set({ denText: event.target.value })}
                    className="mt-1 h-10 w-full rounded-lg border border-[var(--border)] bg-black/30 px-3 font-mono text-[var(--foreground)]"
                  />
                </label>
              </div>
            </div>
          ) : null}

          <label className="block rounded-2xl border border-[var(--border)] bg-black/15 p-4 text-sm text-[var(--muted)]">
            Extra lag pole τ_lag (s) — G ← G / (τ s + 1). Watch damping on the root locus.
            <input
              type="range"
              min={0}
              max={2}
              step={0.02}
              value={model.lagTau}
              onChange={(event) => set({ lagTau: Number(event.target.value) })}
              className="mt-3 h-6 w-full cursor-pointer accent-[var(--accent)]"
            />
            <input
              type="number"
              step="0.02"
              min={0}
              value={model.lagTau}
              onChange={(event) => set({ lagTau: Number(event.target.value) })}
              className="mt-2 h-10 w-32 rounded-lg border border-[var(--border)] bg-black/30 px-3 text-[var(--foreground)]"
            />
          </label>
        </div>

        <div className="space-y-4">
          <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--accent)]">Working G(s)</p>
            <code className="mt-2 block font-mono text-sm leading-6 text-[var(--foreground)]">
              {formatTransferFunction(tf)}
            </code>
            <p className="mt-2 text-xs text-[var(--muted)]">
              Type {errors.type} · Kp = {fmtK(errors.Kp)} · Kv = {fmtK(errors.Kv)} · Ka = {fmtK(errors.Ka)}
            </p>
          </div>
          <div className="overflow-x-auto rounded-2xl border border-[var(--border)] bg-black/15 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--accent)]">
              Unity-feedback ess (unit reference)
            </p>
            <table className="mt-3 w-full min-w-[16rem] text-left text-sm">
              <thead>
                <tr className="text-[11px] uppercase tracking-[0.12em] text-[var(--muted)]">
                  <th className="pb-2 font-semibold">Input</th>
                  <th className="pb-2 font-semibold">Type 0</th>
                  <th className="pb-2 font-semibold">Type 1</th>
                  <th className="pb-2 font-semibold">Type 2</th>
                  <th className="pb-2 font-semibold">This G</th>
                </tr>
              </thead>
              <tbody className="font-mono text-[var(--foreground)]">
                <tr>
                  <td className="py-1.5 text-[var(--muted)]">Step</td>
                  <td>1/(1+Kp)</td>
                  <td>0</td>
                  <td>0</td>
                  <td>{fmtErr(errors.step)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 text-[var(--muted)]">Ramp</td>
                  <td>∞</td>
                  <td>1/Kv</td>
                  <td>0</td>
                  <td>{fmtErr(errors.ramp)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 text-[var(--muted)]">Parabola</td>
                  <td>∞</td>
                  <td>∞</td>
                  <td>1/Ka</td>
                  <td>{fmtErr(errors.parabola)}</td>
                </tr>
              </tbody>
            </table>
            <p className="mt-3 text-xs leading-5 text-[var(--muted)]">
              A Type 1 plant still needs a loop: open-loop 1/s ramps on a step command and does not hold a position
              against a load. Proportional feedback around it tracks a step with ess = 0.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}

export { DEFAULT_MODEL };
