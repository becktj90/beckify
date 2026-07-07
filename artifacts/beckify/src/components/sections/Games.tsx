import { Activity } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { GAME } from "@/data/site-content";

/**
 * Embedded game. To change the game, update GAME.embedUrl in
 * src/data/site-content.ts.
 */
export const Games = () => (
  <section id="games" className="space-y-8 scroll-mt-24">
    <FadeIn>
      <SectionHeader title="Games" subtitle={GAME.name} icon={Activity} />
    </FadeIn>

    <FadeIn delay={0.1}>
      <div className="max-w-2xl card-surface p-6">
        <div className="card-surface overflow-hidden">
          <iframe
            src={GAME.embedUrl}
            title={GAME.name}
            className="w-full h-[420px] border-0 bg-transparent block"
            loading="lazy"
          />
        </div>
      </div>
    </FadeIn>
  </section>
);
