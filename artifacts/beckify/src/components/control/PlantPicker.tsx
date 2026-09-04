import { useMemo, useState } from "react";
import { Check, Search, Sparkles } from "lucide-react";
import {
  DIFFICULTY_LABEL,
  PLANT_CATEGORIES,
  PLANTS,
  type Plant,
  type PlantCategory,
  type PlantDifficulty,
} from "@/data/control-plants";

type CategoryFilter = "All" | PlantCategory;
type DifficultyFilter = "All" | PlantDifficulty;

/**
 * Example-plant gallery. Search + category/difficulty filters mirror MathWorks
 * “reference applications” discovery so users can open an interactive example fast.
 */
export function PlantPicker({ selectedId, onSelect }: { selectedId: string; onSelect: (plant: Plant) => void }) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<CategoryFilter>("All");
  const [difficulty, setDifficulty] = useState<DifficultyFilter>("All");
  const [featuredOnly, setFeaturedOnly] = useState(false);

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return PLANTS.filter((plant) => {
      if (category !== "All" && plant.category !== category) return false;
      if (difficulty !== "All" && plant.difficulty !== difficulty) return false;
      if (featuredOnly && !plant.featured) return false;
      if (!needle) return true;
      const haystack = [plant.name, plant.summary, plant.display, plant.teaches, plant.category, ...plant.tags]
        .join(" ")
        .toLowerCase();
      return haystack.includes(needle);
    });
  }, [query, category, difficulty, featuredOnly]);

  const grouped = useMemo(() => {
    return PLANT_CATEGORIES.map((cat) => ({
      category: cat,
      plants: filtered.filter((plant) => plant.category === cat),
    })).filter((group) => group.plants.length > 0);
  }, [filtered]);

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
        <label className="relative block min-w-0 flex-1 text-sm text-[var(--muted)]">
          <span className="sr-only">Search example plants</span>
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--muted)]" />
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search motors, unstable, thermal, flight…"
            className="h-11 w-full rounded-xl border border-[var(--border)] bg-black/30 py-2 pl-10 pr-3 text-[var(--foreground)] placeholder:text-[var(--muted)]/70"
          />
        </label>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            aria-pressed={featuredOnly}
            onClick={() => setFeaturedOnly((value) => !value)}
            className={`inline-flex min-h-11 items-center gap-1.5 rounded-xl border px-3 text-xs font-semibold transition ${
              featuredOnly
                ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]"
                : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--accent)]/60"
            }`}
          >
            <Sparkles className="h-3.5 w-3.5" />
            Good first picks
          </button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2" role="group" aria-label="Filter by category">
        {(["All", ...PLANT_CATEGORIES] as CategoryFilter[]).map((value) => (
          <button
            key={value}
            type="button"
            aria-pressed={category === value}
            onClick={() => setCategory(value)}
            className={`min-h-10 rounded-full border px-3.5 text-xs font-semibold transition ${
              category === value
                ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--foreground)]"
                : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--accent)]/60"
            }`}
          >
            {value}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap gap-2" role="group" aria-label="Filter by difficulty">
        {(["All", "intro", "intermediate", "advanced"] as DifficultyFilter[]).map((value) => (
          <button
            key={value}
            type="button"
            aria-pressed={difficulty === value}
            onClick={() => setDifficulty(value)}
            className={`min-h-10 rounded-full border px-3.5 text-xs font-semibold transition ${
              difficulty === value
                ? "border-[var(--accent-2)] bg-[var(--accent-2)]/15 text-[var(--foreground)]"
                : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--accent-2)]/60"
            }`}
          >
            {value === "All" ? "Any level" : DIFFICULTY_LABEL[value]}
          </button>
        ))}
      </div>

      {grouped.length === 0 ? (
        <p className="rounded-2xl border border-[var(--border)] bg-black/15 p-5 text-sm text-[var(--muted)]">
          No plants match that search. Clear filters or switch to “Enter your own” to type a custom G(s).
        </p>
      ) : (
        <div className="space-y-6">
          {grouped.map(({ category: cat, plants }) => (
            <section key={cat} aria-labelledby={`plants-${cat.replace(/\s+/g, "-")}`}>
              <h3
                id={`plants-${cat.replace(/\s+/g, "-")}`}
                className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--accent)]"
              >
                {cat}
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
                      <div className="mt-2 flex flex-wrap gap-1.5">
                        <span className="rounded-md border border-[var(--border)] px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">
                          {DIFFICULTY_LABEL[plant.difficulty]}
                        </span>
                        {plant.featured ? (
                          <span className="rounded-md border border-[var(--accent)]/40 bg-[var(--accent-soft)] px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--accent)]">
                            Starter
                          </span>
                        ) : null}
                      </div>
                      <code className="mt-2 block font-mono text-sm text-[var(--accent-2)]">{plant.display}</code>
                      <span className="mt-2 text-xs leading-5 text-[var(--muted)]">{plant.summary}</span>
                      <span className="mt-3 border-t border-[var(--border)] pt-2 text-xs leading-5 text-[var(--foreground)]/80">
                        <span className="font-semibold text-[var(--accent)]">Try this: </span>
                        {plant.teaches}
                      </span>
                    </button>
                  );
                })}
              </div>
            </section>
          ))}
        </div>
      )}

      <p className="text-xs leading-5 text-[var(--muted)]">
        {filtered.length} of {PLANTS.length} examples · selecting one loads G(s) into Tune, Lead, Analyze, and State
        space.
      </p>
    </div>
  );
}

export default PlantPicker;
