import { useEffect, useMemo, useState } from "react";
import { Activity, BrainCircuit, ChevronDown, LibraryBig, SlidersHorizontal, Spline } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { BodePlot } from "@/components/control/BodePlot";
import { LeadCompensator } from "@/components/control/LeadCompensator";
import { LQRStudio } from "@/components/control/LQRStudio";
import { MPCSimulator } from "@/components/control/MPCSimulator";
import { NonlinearityPanel } from "@/components/control/NonlinearityPanel";
import { PlantPicker } from "@/components/control/PlantPicker";
import { PlantModeler, resolvePlantTransferFunction, seedModelFromPlant, type PlantModel } from "@/components/control/PlantModeler";
import { StepTuner } from "@/components/control/StepTuner";
import { DEFAULT_PLANT_ID, findPlant, type Plant } from "@/data/control-plants";
import {
  dcGain,
  discretizeStateSpace,
  formatComplex,
  formatTransferFunction,
  isStable,
  poleZeroMap,
  transferFunctionToStateSpace,
} from "@/utils/controlEngine";

const TABS = [
  { id: "tune", label: "Tune", icon: SlidersHorizontal, blurb: "Model the plant, compare open loop vs P, then walk P → I → D." },
  { id: "compensator", label: "Lead", icon: Spline, blurb: "Place a lead network and see Gc(s) plus analog R/C." },
  { id: "analyze", label: "Analyze", icon: Activity, blurb: "Bode, ωb, root locus vs K, nonlinearities." },
  { id: "advanced", label: "State space", icon: BrainCircuit, blurb: "LQR, Kalman, Ackermann, MPC." },
] as const;

type TabId = (typeof TABS)[number]["id"];

const STORAGE_KEY = "beckify-control-systems-v1";

const matrixToText = (matrix: number[][]) => matrix.map((row) => row.map((v) => Number(v.toFixed(4))).join(", ")).join("\n");

type SavedState = {
  tab?: TabId;
  plantId?: string;
  model?: PlantModel;
};

function loadSaved(): SavedState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    return JSON.parse(raw) as SavedState;
  } catch {
    return {};
  }
}

export default function ControlSystemsPage() {
  const saved = useMemo(() => loadSaved(), []);
  const [activeTab, setActiveTab] = useState<TabId>(saved.tab ?? "tune");
  const [libraryPlant, setLibraryPlant] = useState<Plant>(() => findPlant(saved.plantId ?? DEFAULT_PLANT_ID));
  const [model, setModel] = useState<PlantModel>(() => saved.model ?? seedModelFromPlant(findPlant(saved.plantId ?? DEFAULT_PLANT_ID)));
  const [libraryOpen, setLibraryOpen] = useState(true);

  const workingTf = useMemo(() => resolvePlantTransferFunction(libraryPlant, model), [libraryPlant, model]);
  const customized = model.mode !== "library" || model.lagTau > 0;
  const plant: Plant = useMemo(
    () => ({
      ...libraryPlant,
      display: formatTransferFunction(workingTf),
      transferFunction: workingTf,
      stateSpace: customized ? undefined : libraryPlant.stateSpace,
      duration:
        model.mode === "first"
          ? Math.max(8, model.tau * 6)
          : model.mode === "second"
            ? Math.max(8, 12 / Math.max(model.wn * Math.max(model.zeta, 0.15), 0.2))
            : libraryPlant.duration,
    }),
    [libraryPlant, workingTf, customized, model],
  );

  const stateSpace = useMemo(
    () => plant.stateSpace ?? transferFunctionToStateSpace(plant.transferFunction),
    [plant],
  );
  const discrete = useMemo(() => discretizeStateSpace(stateSpace, stateSpace.sampleTime ?? 0.1, "zoh"), [stateSpace]);
  const poleZero = useMemo(() => poleZeroMap(plant.transferFunction), [plant]);
  const openLoopStable = useMemo(() => isStable(plant.transferFunction), [plant]);
  const gain = useMemo(() => dcGain(plant.transferFunction), [plant]);
  const order = plant.transferFunction.denominator.length - 1;

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ tab: activeTab, plantId: libraryPlant.id, model }));
    } catch {
      /* ignore quota */
    }
  }, [activeTab, libraryPlant.id, model]);

  const selectPlant = (next: Plant) => {
    setLibraryPlant(next);
    setModel(seedModelFromPlant(next));
    setLibraryOpen(false);
  };

  return (
    <Layout>
      <SchemaHead
        title="Control System Toolbox | Beckify"
        description="Undergraduate servo analysis: plant modeling, open- vs closed-loop P control, root locus, lead compensators, PID with Ziegler–Nichols and anti-windup, Bode GM/PM/ωb, and state-feedback pole placement."
        path="/control-systems"
      />
      <FadeIn>
        <SectionHeader
          title="Control System Toolbox"
          level="h1"
          subtitle="Walk a plant from modeling → P control → root locus → lead → PID with windup → Bode margins → pole placement. Inspired by a typical undergraduate servo lab; original widgets, public-domain identities (Nise / Ogata / Franklin class of results). Educational approximations — not for safety-critical commissioning."
          icon={SlidersHorizontal}
        />
      </FadeIn>

      <FadeIn delay={0.04}>
        <div className="card-surface rounded-3xl p-5">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--accent)]">
                Plant under study
              </p>
              <h2 className="mt-1 font-display text-2xl font-bold text-[var(--foreground)]">
                {libraryPlant.name}
                {customized ? " · edited" : ""}
              </h2>
              <code className="mt-2 block font-mono text-base text-[var(--accent-2)]">G(s) = {plant.display}</code>
              <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">{libraryPlant.summary}</p>
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
              Classic systems, including 1/(s−1) and 1/s². Selecting one loads G(s) everywhere on this page.
            </p>
            <div className="mt-5">
              <PlantPicker selectedId={libraryPlant.id} onSelect={selectPlant} />
            </div>
          </div>
        </FadeIn>
      ) : null}

      <FadeIn delay={0.08}>
        <div className="flex flex-wrap gap-2 print:hidden" role="tablist" aria-label="Toolbox sections">
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
                className={`inline-flex min-h-11 items-center gap-2 rounded-2xl border px-5 py-3 text-sm font-semibold transition ${
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
          <div id="panel-tune" role="tabpanel" aria-labelledby="tab-tune" hidden={activeTab !== "tune"} className="space-y-6">
            <PlantModeler plant={libraryPlant} model={model} onChange={setModel} />
            <StepTuner plant={plant} />
          </div>

          <div
            id="panel-compensator"
            role="tabpanel"
            aria-labelledby="tab-compensator"
            hidden={activeTab !== "compensator"}
          >
            <LeadCompensator plant={plant.transferFunction} />
          </div>

          <div
            id="panel-analyze"
            role="tabpanel"
            aria-labelledby="tab-analyze"
            hidden={activeTab !== "analyze"}
            className="space-y-6"
          >
            <BodePlot
              title="Frequency response, margins, and root locus"
              transferFunction={plant.transferFunction}
              systemExample={plant.name}
            />
            <section className="card-surface rounded-3xl p-5 md:p-6">
              <h2 className="font-display text-xl font-bold text-[var(--foreground)]">Poles and zeros</h2>
              <p className="mt-1 text-sm text-[var(--muted)]">
                Roots of G(s). A positive real part is a right-half-plane pole. Extra lag from the modeler adds a real
                pole that the locus has to drag left.
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
            <NonlinearityPanel />
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
