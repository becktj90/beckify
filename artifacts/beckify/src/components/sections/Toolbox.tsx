import { Wrench } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { TOOLBOX } from "@/data/site-content";

/**
 * Embedded electrical toolbox. To change the embedded app, update
 * TOOLBOX.embedUrl in src/data/site-content.ts.
 */
export const Toolbox = () => (
  <section id="toolbox" className="space-y-8 scroll-mt-24">
    <FadeIn>
      <SectionHeader title="Toolbox" subtitle={TOOLBOX.description} icon={Wrench} />
    </FadeIn>

    <FadeIn delay={0.15}>
      <div className="card-surface overflow-hidden">
        <iframe
          src={TOOLBOX.embedUrl}
          title="Electrical Toolbox"
          className="w-full h-[720px] border-0 bg-transparent block"
          loading="lazy"
        />
      </div>
    </FadeIn>
  </section>
);
