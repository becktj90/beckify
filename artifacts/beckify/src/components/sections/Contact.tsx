import { Mail } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { CONTACT_LINKS } from "@/data/site-content";

/**
 * Contact links grid. To add/remove a contact method, edit CONTACT_LINKS
 * in src/data/site-content.ts.
 */
export const Contact = () => (
  <section id="contact" className="space-y-8 scroll-mt-24">
    <FadeIn>
      <SectionHeader
        title="Contact"
        subtitle="Best way to reach me is email, or find me on the links below."
        icon={Mail}
      />
    </FadeIn>

    <FadeIn delay={0.1}>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {CONTACT_LINKS.map(({ href, label, icon: Icon, external }) => (
          <a
            key={href}
            href={href}
            {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
            className="card-surface group flex items-center gap-4 p-5"
          >
            <div className="w-11 h-11 rounded-xl bg-[var(--accent-soft)] flex items-center justify-center shrink-0">
              <Icon className="w-5 h-5 text-[var(--accent)]" />
            </div>
            <span className="text-sm sm:text-base font-medium text-[var(--foreground)] truncate">
              {label}
            </span>
          </a>
        ))}
      </div>
    </FadeIn>
  </section>
);
