import { useMemo, useState } from "react";
import { Activity, BrainCircuit, ChevronDown, LibraryBig, SlidersHorizontal } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { BodePlot } from "@/components/control/BodePlot";
import { LQRStudio } from "@/components/control/LQRStudio";
import { MPCSimulator } from "@/components/control/MPCSimulator";
import { PlantPicker } from "@/components/control/PlantPicker";
import { StepTuner } from "@/components/control/StepTuner";
import { DEFAULT_PLANT_ID, findPlant, type Plant } from "@/data/control-plants";
import {
  dcGain,
  discretizeStateSpace,
  formatComplex,
  isStable,
  poleZeroMap,
  transferFunctionToStateSpace,
} from "@/utils/controlEngine";

const TABS = [
  { id: "tune", label: "Tune", icon: SlidersHorizontal, blurb: "Pick a plant and close a loop around it." },
  { id: "analyze", label: "Analyze", icon: Activity, blurb: "Frequency response, margins, poles and zeros." },
  { id: "advanced", label: "State space", icon: BrainCircuit, blurb: "LQR, Kalman, and predictive control." },
] as const;

type TabId = (typeof TABS)[number]["id"];

const matrixToText = (matrix: number[][]) => matrix.map((row) => row.map((v) => Number(v.toFixed(4))).join(", ")).join("\n");

export default function ControlSystemsPage() {
  const [activeTab, setActiveTab] = useState<TabId>("tune");
  const [plant, setPlant] = useState<Plant>(() => findPlant(DEFAULT_PLANT_ID));
  const [libraryOpen, setLibraryOpen] = useState(true);

  // Everything below derives from the one selected plant, so the transfer
  // function, the step response, the Bode plot and the state-space model can
  // never drift out of sync with each other.
  const stateSpace = useMemo(
    () => plant.stateSpace ?? transferFunctionToStateSpace(plant.transferFunction),
    [plant],
  );
  const discrete = useMemo(() => discretizeStateSpace(stateSpace, stateSpace.sampleTime ?? 0.1, "zoh"), [stateSpace]);
  const poleZero = useMemo(() => poleZeroMap(plant.transferFunction), [plant]);
  const openLoopStable = useMemo(() => isStable(plant.transferFunction), [plant]);
  const gain = useMemo(() => dcGain(plant.transferFunction), [plant]);
  const order = plant.transferFunction.denominator.length - 1;

  const selectPlant = (next: Plant) => {
    setPlant(next);
    setLibraryOpen(false);
  };

  return (
    <Layout>
      <SchemaHead
        title="Control System Toolbox | Beckify"
        description="Pick from a library of classic plants — first-order lags, motors, unstable and non-minimum-phase systems — then tune a PID loop and watch the step response, Bode plot, and state-space design update live."
        path="/control-systems"
      />
      <FadeIn>
        <SectionHeader
          title="Control System Toolbox"
          subtitle="Choose a plant, close a loop around it, and see what the controller actually does to the step response."
          icon={SlidersHorizontal}
        />
      </FadeIn>

      {/* Plant context bar — always visible, so you never lose track of which
          system every panel below is describing. */}
      <FadeIn delay={0.04}>
        <div className="card-surface rounded-3xl p-5">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--accent)]">
                Plant under study
              </p>
              <h2 className="mt-1 font-display text-2xl font-bold text-[var(--foreground)]">{plant.name}</h2>
              <code className="mt-2 block font-mono text-base text-[var(--accent-2)]">G(s) = {plant.display}</code>
              <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">{plant.summary}</p>
            </div>
            <button
              type="button"
              onClick={() => setLibraryOpen((open) => !open)}
              aria-expanded={libraryOpen}
              aria-controls="plant-library"
              className="inline-flex shrink-0 items-center gap-2 rounded-full border border-[var(--border)] px-4 py-2 text-sm font-semibold text-[var(--muted)] transition hover:border-[var(--accent)] hover:text-[var(--foreground)]"
            >
              <LibraryBig className="h-4 w-4" />
              {libraryOpen ? "Hide library" : "Change plant"}
              <ChevronDown className={`h-4 w-4 transition ${libraryOpen ? "rotate-180" : ""}`} />
            </button>
          </div>

          <dl className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              ["Order", String(order)],
              ["DC gain", Number.isFinite(gain) ? gain.toFixed(3) : "∞ (integrator)"],
              ["Open loop", openLoopStable ? "Stable" : "Unstable"],
              ["Poles", poleZero.poles.length ? poleZero.poles.map(formatComplex).join(", ") : "—"],
            ].map(([label, value]) => (
              <div key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-3">
                <dt className="text-[10px] font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">{label}</dt>
                <dd
                  className={`mt-1 truncate font-mono text-sm ${
                    label === "Open loop" && !openLoopStable ? "text-amber-300" : "text-[var(--foreground)]"
                  }`}
                  title={value}
                >
                  {value}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      </FadeIn>

      {libraryOpen ? (
        <FadeIn delay={0.06}>
          <div id="plant-library" className="card-surface rounded-3xl p-5">
            <h2 className="font-display text-xl font-bold text-[var(--foreground)]">Plant library</h2>
            <p className="mt-1 text-sm text-[var(--muted)]">
              Classic systems to experiment with. Selecting one loads its transfer function everywhere on this page.
            </p>
            <div className="mt-5">
              <PlantPicker selectedId={plant.id} onSelect={selectPlant} />
            </div>
          </div>
        </FadeIn>
      ) : null}

      {/* Section switcher */}
      <FadeIn delay={0.08}>
        <div className="flex flex-wrap gap-2" role="tablist" aria-label="Toolbox sections">
          {TABS.map(({ id, label, icon: Icon, blurb }) => {
            const active = activeTab === id;
            return (
              <button
                key={id}
                type="button"
                role="tab"
                id={`tab-${id}`}
                aria-selected={active}
                aria-controls={`panel-${id}`}
                onClick={() => setActiveTab(id)}
                title={blurb}
                className={`inline-flex items-center gap-2 rounded-2xl border px-5 py-3 text-sm font-semibold transition ${
                  active
                    ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]"
                    : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--accent)]/60 hover:text-[var(--foreground)]"
                }`}
              >
                <Icon className="h-4 w-4" />
                {label}
              </button>
            );
          })}
        </div>
      </FadeIn>

      <FadeIn delay={0.1}>
        <div className="space-y-6">
          <div id="panel-tune" role="tabpanel" aria-labelledby="tab-tune" hidden={activeTab !== "tune"}>
            <StepTuner plant={plant} />
          </div>

          <div
            id="panel-analyze"
            role="tabpanel"
            aria-labelledby="tab-analyze"
            hidden={activeTab !== "analyze"}
            className="space-y-6"
          >
            <BodePlot
              title="Frequency response and stability margins"
              transferFunction={plant.transferFunction}
              systemExample={plant.name}
            />
            <section className="card-surface rounded-3xl p-5 md:p-6">
              <h2 className="font-display text-xl font-bold text-[var(--foreground)]">Poles and zeros</h2>
              <p className="mt-1 text-sm text-[var(--muted)]">
                Roots of the denominator and numerator of G(s). Anything with a positive real part is in the right half
                plane and makes the open-loop plant unstable.
              </p>
              <div className="mt-4 grid gap-3 md:grid-cols-2">
                <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">Poles</p>
                  <p className="mt-2 font-mono text-sm leading-6 text-[var(--foreground)]">
                    {poleZero.poles.length ? poleZero.poles.map(formatComplex).join("  ·  ") : "—"}
                  </p>
                </div>
                <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">Zeros</p>
                  <p className="mt-2 font-mono text-sm leading-6 text-[var(--foreground)]">
                    {poleZero.zeros.length ? poleZero.zeros.map(formatComplex).join("  ·  ") : "none"}
                  </p>
                </div>
              </div>
            </section>
          </div>

          <div
            id="panel-advanced"
            role="tabpanel"
            aria-labelledby="tab-advanced"
            hidden={activeTab !== "advanced"}
            className="space-y-6"
          >
            <section className="card-surface rounded-3xl p-5 md:p-6">
              <h2 className="font-display text-xl font-bold text-[var(--foreground)]">State-space model</h2>
              <p className="mt-1 text-sm text-[var(--muted)]">
                {plant.stateSpace
                  ? "This plant ships with a physically meaningful realisation, so the states map to real quantities."
                  : "Derived from G(s) in controllable canonical form, so it always matches the transfer function above."}
              </p>
              <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                {[
                  ["A", stateSpace.A],
                  ["B", stateSpace.B],
                  ["C", stateSpace.C],
                  ["D", stateSpace.D],
                ].map(([label, matrix]) => (
                  <div key={String(label)} className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--accent)]">
                      {String(label)} matrix
                    </p>
                    <pre className="mt-2 overflow-auto font-mono text-xs leading-6 text-[var(--foreground)]">
                      {matrixToText(matrix as number[][])}
                    </pre>
                  </div>
                ))}
              </div>
            </section>
            <LQRStudio system={stateSpace} exampleLabel={plant.name} />
            <MPCSimulator system={discrete} exampleLabel={plant.name} />
          </div>
        </div>
      </FadeIn>
    </Layout>
  );
}
