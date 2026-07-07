import { ExternalLink, Wifi } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { PROJECTS } from "@/data/site-content";

/**
 * Projects grid. To add a new project card, add an entry to the PROJECTS
 * array in src/data/site-content.ts — no changes needed here.
 */
export const Projects = () => (
  <section id="projects" className="space-y-8 scroll-mt-24">
    <FadeIn>
      <SectionHeader title="Projects" icon={Wifi} />
    </FadeIn>

    <FadeIn delay={0.1}>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
        {PROJECTS.map((project) => (
          <a
            key={project.name}
            href={project.url}
            target="_blank"
            rel="noopener noreferrer"
            className="card-surface group block p-8 relative overflow-hidden"
          >
            <div className="flex justify-between items-start mb-6 relative z-10">
              <h3 className="font-display text-xl font-bold text-[var(--foreground)] group-hover:text-[var(--accent)] transition-colors flex items-center gap-3">
                <project.icon className="w-5 h-5 text-[var(--accent)]" />
                {project.name}
              </h3>
              <ExternalLink className="w-5 h-5 text-[var(--muted)] group-hover:text-[var(--accent)] transition-colors transform group-hover:translate-x-1 group-hover:-translate-y-1" />
            </div>
            <p className="text-sm text-[var(--muted)] leading-relaxed relative z-10">
              {project.description}
            </p>
          </a>
        ))}
      </div>
    </FadeIn>
  </section>
);
