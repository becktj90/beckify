import { BookOpen, PencilLine } from "lucide-react";

/**
 * MathWorks-style entry fork: explore a reference example, or specify your own
 * plant structure (process model / custom TF) before analyzing.
 */
export type PlantSource = "example" | "custom";

const OPTIONS: {
  id: PlantSource;
  title: string;
  blurb: string;
  detail: string;
  icon: typeof BookOpen;
}[] = [
  {
    id: "example",
    title: "Example plants",
    blurb: "Pick a curated G(s) and start analyzing.",
    detail: "Reference applications — motors, thermal, flight, unstable benchmarks.",
    icon: BookOpen,
  },
  {
    id: "custom",
    title: "Enter your own",
    blurb: "Choose a structure and type the coefficients.",
    detail: "1st-order, 2nd-order, or custom numerator / denominator polynomials.",
    icon: PencilLine,
  },
];

export function PlantSourceChooser({
  source,
  onChange,
}: {
  source: PlantSource;
  onChange: (next: PlantSource) => void;
}) {
  return (
    <section className="card-surface rounded-3xl p-5 md:p-6" aria-labelledby="plant-source-heading">
      <div className="max-w-3xl">
        <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--accent)]">
          Step 1 · Model the plant
        </p>
        <h2 id="plant-source-heading" className="mt-1 font-display text-xl font-bold text-[var(--foreground)]">
          How do you want to define G(s)?
        </h2>
        <p className="mt-1 text-sm leading-6 text-[var(--muted)]">
          Same fork MathWorks uses in Control System Toolbox: open an interactive example, or build a linear model
          yourself as a transfer function / process structure.
        </p>
      </div>

      <div className="mt-5 grid gap-3 md:grid-cols-2" role="radiogroup" aria-label="Plant source">
        {OPTIONS.map(({ id, title, blurb, detail, icon: Icon }) => {
          const active = source === id;
          return (
            <button
              key={id}
              type="button"
              role="radio"
              aria-checked={active}
              onClick={() => onChange(id)}
              className={`group flex min-h-[7.5rem] flex-col rounded-2xl border p-5 text-left transition ${
                active
                  ? "border-[var(--accent)] bg-[var(--accent-soft)] shadow-[0_0_0_1px_var(--accent-ring)]"
                  : "border-[var(--border)] bg-black/15 hover:border-[var(--accent)]/60 hover:bg-white/[0.03]"
              }`}
            >
              <div className="flex items-start gap-3">
                <span
                  className={`mt-0.5 rounded-xl border p-2.5 ${
                    active
                      ? "border-[var(--accent)] bg-[var(--accent)] text-[var(--accent-foreground)]"
                      : "border-[var(--border)] text-[var(--accent)]"
                  }`}
                  aria-hidden="true"
                >
                  <Icon className="h-5 w-5" />
                </span>
                <div className="min-w-0">
                  <span className="font-display text-lg font-bold text-[var(--foreground)]">{title}</span>
                  <p className="mt-1 text-sm leading-5 text-[var(--foreground)]/90">{blurb}</p>
                  <p className="mt-2 text-xs leading-5 text-[var(--muted)]">{detail}</p>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

export default PlantSourceChooser;
