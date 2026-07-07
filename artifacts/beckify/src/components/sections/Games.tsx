import { Gamepad2, ExternalLink } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { GAMES } from "@/data/site-content";
import { Button } from "@/components/ui/button";

/**
 * Arcade games collection. Display all available games with launch cards.
 */
export const Games = () => (
  <section id="games" className="space-y-8 scroll-mt-24">
    <FadeIn>
      <SectionHeader
        title="Games"
        subtitle="A collection of arcade and puzzle games built with React and Canvas."
        icon={Gamepad2}
      />
    </FadeIn>

    <FadeIn delay={0.1}>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {GAMES.map((game, idx) => (
          <div
            key={game.name}
            className="group relative p-6 rounded-xl border border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/50 hover:shadow-lg transition-all duration-200"
            style={{ animationDelay: `${idx * 0.1}s` }}
          >
            <div className="space-y-4">
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1">
                  <h3 className="text-lg font-semibold text-[var(--foreground)] group-hover:text-[var(--accent)] transition-colors">
                    {game.name}
                  </h3>
                </div>
                <Gamepad2 className="w-5 h-5 text-[var(--accent)] shrink-0" />
              </div>

              <p className="text-sm text-[var(--muted)] leading-relaxed">
                {game.description}
              </p>

              <Button
                asChild
                variant="outline"
                size="sm"
                className="w-full"
                disabled={game.url === "#"}
              >
                {game.url === "#" ? (
                  <span className="inline-flex items-center gap-2">
                    Coming Soon
                  </span>
                ) : (
                  <a
                    href={game.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2"
                  >
                    <span>Play Now</span>
                    <ExternalLink className="w-4 h-4" />
                  </a>
                )}
              </Button>
            </div>
          </div>
        ))}
      </div>
    </FadeIn>
  </section>
);
