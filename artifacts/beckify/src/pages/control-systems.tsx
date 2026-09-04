import { useEffect, useMemo, useState } from "react";
import { Activity, BrainCircuit, Lightbulb, SlidersHorizontal, Spline } from "lucide-react";
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
import {
  PlantModeler,
  resolvePlantTransferFunction,
  seedCustomModel,
  seedModelFromPlant,
  type PlantModel,
} from "@/components/control/PlantModeler";
import { PlantSourceChooser, type PlantSource } from "@/components/control/PlantSourceChooser";
import { StepTuner } from "@/components/control/StepTuner";
import { DEFAULT_PLANT_ID, DIFFICULTY_LABEL, findPlant, type Plant } from "@/data/control-plants";
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
  { id: "tune", label: "Tune", icon: SlidersHorizontal, blurb: "Compare open loop vs P, then walk P → I → D." },
  { id: "compensator", label: "Lead", icon: Spline, blurb: "Place a lead network and see Gc(s) plus analog R/C." },
  { id: "analyze", label: "Analyze", icon: Activity, blurb: "Bode, ωb, root locus vs K, nonlinearities." },
  { id: "advanced", label: "State space", icon: BrainCircuit, blurb: "LQR, Kalman, Ackermann, MPC." },
] as const;

type TabId = (typeof TABS)[number]["id"];

const STORAGE_KEY = "beckify-control-systems-v2";

const matrixToText = (matrix: number[][]) => matrix.map((row) => row.map((v) => Number(v.toFixed(4))).join(", ")).join("\n");

type SavedState = {
  tab?: TabId;
  plantId?: string;
  model?: PlantModel;
  source?: PlantSource;
};

function loadSaved(): SavedState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY) ?? localStorage.getItem("beckify-control-systems-v1");
    if (!raw) return {};
    return JSON.parse(raw) as SavedState;
  } catch {
    return {};
  }
}

function inferSource(model: PlantModel | undefined, explicit?: PlantSource): PlantSource {
  if (explicit) return explicit;
  if (!model || model.mode === "library") return "example";
  return "custom";
}

export default function ControlSystemsPage() {
  const saved = useMemo(() => loadSaved(), []);
  const [activeTab, setActiveTab] = useState<TabId>(saved.tab ?? "tune");
  const [libraryPlant, setLibraryPlant] = useState<Plant>(() => findPlant(saved.plantId ?? DEFAULT_PLANT_ID));
  const [model, setModel] = useState<PlantModel>(() => saved.model ?? seedModelFromPlant(findPlant(saved.plantId ?? DEFAULT_PLANT_ID)));
  const [source, setSource] = useState<PlantSource>(() => inferSource(saved.model, saved.source));
  const [galleryOpen, setGalleryOpen] = useState(true);

  const workingTf = useMemo(() => resolvePlantTransferFunction(libraryPlant, model), [libraryPlant, model]);
  const customized = model.mode !== "library" || model.lagTau > 0;
  const displayName =
    source === "custom" || model.mode !== "library"
      ? model.mode === "first"
        ? "Custom · one pole"
        : model.mode === "second"
          ? "Custom · two poles"
          : model.mode === "custom"
            ? "Custom transfer function"
            : `${libraryPlant.name}${customized ? " · edited" : ""}`
      : libraryPlant.name;

  const plant: Plant = useMemo(
    () => ({
      ...libraryPlant,
      name: displayName,
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
    [libraryPlant, workingTf, customized, model, displayName],
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
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ tab: activeTab, plantId: libraryPlant.id, model, source }),
      );
    } catch {
      /* ignore quota */
    }
  }, [activeTab, libraryPlant.id, model, source]);

  const selectPlant = (next: Plant) => {
    setLibraryPlant(next);
    setModel(seedModelFromPlant(next));
    setSource("example");
    setGalleryOpen(false);
  };

  const changeSource = (next: PlantSource) => {
    setSource(next);
    if (next === "example") {
      setModel(seedModelFromPlant(libraryPlant));
      setGalleryOpen(true);
    } else {
      setModel((prev) => (prev.mode === "library" ? seedCustomModel() : prev));
      setGalleryOpen(false);
    }
  };

  return (
    <Layout>
      <SchemaHead
        title="Control System Toolbox | Beckify"
        description="Undergraduate servo analysis: pick an example plant or enter your own G(s), then tune PID, Bode margins, root locus, lead compensators, and state-feedback."
        path="/control-systems"
      />
      <FadeIn>
        <SectionHeader
          title="Control System Toolbox"
          level="h1"
          subtitle="Model → analyze → design. Choose a reference plant or enter your own transfer function, then walk open-loop vs P → PID, Bode margins, lead, and state-space. Inspired by Control System Toolbox workflows; educational approximations — not for safety-critical commissioning."
          icon={SlidersHorizontal}
        />
      </FadeIn>

      <FadeIn delay={0.03}>
        <ol className="mb-2 flex flex-wrap items-center gap-2 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
          {[
            ["1", "Model"],
            ["2", "Analyze / tune"],
            ["3", "Compensator / state space"],
          ].map(([n, label], index) => (
            <li key={label} className="flex items-center gap-2">
              <span className="inline-flex items-center gap-2 rounded-full border border-[var(--border)] bg-black/20 px-3 py-1.5">
                <span className="text-[var(--accent)]">{n}</span>
                {label}
              </span>
              {index < 2 ? <span className="text-[var(--muted)]/50" aria-hidden="true">→</span> : null}
            </li>
          ))}
        </ol>
      </FadeIn>

      <FadeIn delay={0.04}>
        <PlantSourceChooser source={source} onChange={changeSource} />
      </FadeIn>

      {source === "example" ? (
        <FadeIn delay={0.06}>
          <div id="plant-library" className="card-surface rounded-3xl p-5 md:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--accent)]">
                  Reference applications
                </p>
                <h2 className="mt-1 font-display text-xl font-bold text-[var(--foreground)]">Example plant library</h2>
                <p className="mt-1 max-w-2xl text-sm text-[var(--muted)]">
                  Open an interactive example — motors, thermal processes, flight pitch, unstable benchmarks — then
                  analyze it across every tab below.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setGalleryOpen((open) => !open)}
                aria-expanded={galleryOpen}
                aria-controls="example-gallery"
                className="inline-flex min-h-11 shrink-0 items-center gap-2 rounded-full border border-[var(--border)] px-4 py-2 text-sm font-semibold text-[var(--muted)] transition hover:border-[var(--accent)] hover:text-[var(--foreground)]"
              >
                {galleryOpen ? "Collapse gallery" : "Browse examples"}
              </button>
            </div>
            {galleryOpen ? (
              <div id="example-gallery" className="mt-5">
                <PlantPicker selectedId={libraryPlant.id} onSelect={selectPlant} />
              </div>
            ) : null}
          </div>
        </FadeIn>
      ) : (
        <FadeIn delay={0.06}>
          <PlantModeler
            plant={libraryPlant}
            model={model}
            onChange={setModel}
            allowLibrary={false}
            compactIntro="Pick a structure (one pole, two poles, or custom coefficients), then tune parameters. Quick presets load common lab plants."
          />
        </FadeIn>
      )}

      <FadeIn delay={0.08}>
        <div className="card-surface rounded-3xl p-5">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="min-w-0">
              <p className="type-label text-[var(--accent)]">
                Plant under study
              </p>
              <h2 className="mt-1 font-display text-2xl font-bold tracking-[-0.015em] text-[var(--foreground)]">{displayName}</h2>
              <code className="mt-2 block font-mono text-base text-[var(--accent-2)]">G(s) = {plant.display}</code>
              {source === "example" ? (
                <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">{libraryPlant.summary}</p>
              ) : (
                <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">
                  Your coefficients feed every analysis tool on this page. Switch to Example plants anytime to load a
                  reference system instead.
                </p>
              )}
            </div>
            {source === "example" ? (
              <div className="rounded-2xl border border-[var(--border)] bg-black/15 px-3 py-2 text-xs text-[var(--muted)]">
                <span className="font-semibold uppercase tracking-[0.1em] text-[var(--accent)]">
                  {DIFFICULTY_LABEL[libraryPlant.difficulty]}
                </span>
                <span className="mx-2 text-[var(--border)]">·</span>
                {libraryPlant.category}
              </div>
            ) : null}
          </div>

          {source === "example" ? (
            <div className="mt-4 flex gap-3 rounded-2xl border border-[var(--border)] bg-black/15 p-4">
              <Lightbulb className="mt-0.5 h-4 w-4 shrink-0 text-[var(--accent)]" aria-hidden="true" />
              <p className="text-sm leading-6 text-[var(--muted)]">
                <span className="font-semibold text-[var(--foreground)]">What to notice: </span>
                {libraryPlant.teaches}
              </p>
            </div>
          ) : null}

          <dl className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              ["Order", String(order)],
              ["DC gain", Number.isFinite(gain) ? gain.toFixed(3) : "∞ (integrator)"],
              ["Open loop", openLoopStable ? "Stable" : "Unstable"],
              ["Poles", poleZero.poles.length ? poleZero.poles.map(formatComplex).join(", ") : "—"],
            ].map(([label, value]) => (
              <div key={label} className="rounded-2xl border border-[var(--border)] bg-black/15 p-3">
                <dt className="type-label text-[var(--muted)]">{label}</dt>
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

      {source === "example" ? (
        <FadeIn delay={0.09}>
          <PlantModeler
            plant={libraryPlant}
            model={model}
            onChange={setModel}
            allowLibrary
            compactIntro="Optional: refine the selected example with a process-model structure, custom polynomials, or an extra lag pole before tuning."
          />
        </FadeIn>
      ) : null}

      <FadeIn delay={0.1}>
        <div>
          <p className="mb-3 text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--accent)]">
            Step 2 · Analyze and design
          </p>
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
        </div>
      </FadeIn>

      <FadeIn delay={0.12}>
        <div className="space-y-6">
          <div id="panel-tune" role="tabpanel" aria-labelledby="tab-tune" hidden={activeTab !== "tune"} className="space-y-6">
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
              <h2 className="font-display text-xl font-bold tracking-[-0.015em] text-[var(--foreground)]">Poles and zeros</h2>
              <p className="mt-1 text-sm text-[var(--muted)]">
                Roots of G(s). A positive real part is a right-half-plane pole. Extra lag from the modeler adds a real
                pole that the locus has to drag left.
              </p>
              <div className="mt-4 grid gap-3 md:grid-cols-2">
                <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
                  <p className="type-label text-[var(--muted)]">Poles</p>
                  <p className="mt-2 font-mono text-sm leading-6 text-[var(--foreground)]">
                    {poleZero.poles.length ? poleZero.poles.map(formatComplex).join("  ·  ") : "—"}
                  </p>
                </div>
                <div className="rounded-2xl border border-[var(--border)] bg-black/15 p-4">
                  <p className="type-label text-[var(--muted)]">Zeros</p>
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
              <h2 className="font-display text-xl font-bold tracking-[-0.015em] text-[var(--foreground)]">State-space model</h2>
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
                    <p className="type-label text-[var(--accent)]">
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
