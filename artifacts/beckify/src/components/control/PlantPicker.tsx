import { Check } from "lucide-react";
import { PLANT_CATEGORIES, PLANTS, type Plant } from "@/data/control-plants";

/**
 * The plant library. Every other panel on the page reads from whichever plant
 * is selected here, so there is exactly one system under study at a time.
 */
export function PlantPicker({ selectedId, onSelect }: { selectedId: string; onSelect: (plant: Plant) => void }) {
  return (
    <div className="space-y-6">
      {PLANT_CATEGORIES.map((category) => {
        const plants = PLANTS.filter((plant) => plant.category === category);
        if (!plants.length) return null;
        return (
          <section key={category} aria-labelledby={`plants-${category.replace(/\s+/g, "-")}`}>
            <h3
              id={`plants-${category.replace(/\s+/g, "-")}`}
              className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--accent)]"
            >
              {category}
            </h3>
            <div className="mt-3 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
              {plants.map((plant) => {
                const active = plant.id === selectedId;
                return (
                  <button
                    key={plant.id}
                    type="button"
                    aria-pressed={active}
                    onClick={() => onSelect(plant)}
                    className={`group flex h-full flex-col rounded-2xl border p-4 text-left transition ${
                      active
                        ? "border-[var(--accent)] bg-[var(--accent-soft)]"
                        : "border-[var(--border)] bg-black/15 hover:border-[var(--accent)]/60 hover:bg-white/[0.03]"
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <span className="font-display text-base font-bold text-[var(--foreground)]">{plant.name}</span>
                      {active ? (
                        <span className="rounded-full bg-[var(--accent)] p-1" aria-hidden="true">
                          <Check className="h-3 w-3 text-[var(--accent-foreground)]" />
                        </span>
                      ) : null}
                    </div>
                    <code className="mt-2 block font-mono text-sm text-[var(--accent-2)]">{plant.display}</code>
                    <span className="mt-2 text-xs leading-5 text-[var(--muted)]">{plant.summary}</span>
                  </button>
                );
              })}
            </div>
          </section>
        );
      })}
    </div>
  );
}

export default PlantPicker;
