import { Activity, GraduationCap } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { PROFILE, CONTACT_LINKS } from "@/data/site-content";
import profilePhoto from "@/assets/beck-profile.jpg";
import familySara from "@/assets/family-sara.jpg";
import familyTrevorSon from "@/assets/family-trevor-son.jpg";

/**
 * Hero / About section. Edit PROFILE in src/data/site-content.ts to change
 * the name, title, education, or bio text.
 */
export const About = () => {
  const socialLinks = CONTACT_LINKS.filter((l) => l.external);

  return (
    <header id="about" className="space-y-10 relative scroll-mt-24">
      <FadeIn delay={0.05}>
        <div className="flex flex-col sm:flex-row items-start sm:items-center gap-8">
          <div className="relative shrink-0">
            <img
              src={profilePhoto}
              alt={PROFILE.name}
              className="w-28 h-28 sm:w-32 sm:h-32 rounded-2xl object-cover border border-[var(--border)] shadow-lg"
            />
          </div>
          <div className="space-y-3">
            <h1 className="font-display text-4xl md:text-5xl font-extrabold tracking-tight text-[var(--foreground)]">
              {PROFILE.name}
            </h1>
            <div className="flex flex-wrap items-center gap-2">
              <div className="flex items-center gap-2 text-sm font-medium text-[var(--accent)] bg-[var(--accent-soft)] border border-[var(--accent)]/15 px-3 py-1.5 rounded-full w-fit">
                <Activity className="w-4 h-4" />
                <span>{PROFILE.title}</span>
              </div>
              <div className="flex items-center gap-2 text-sm font-medium text-[var(--muted)] bg-[var(--surface)] border border-[var(--border)] px-3 py-1.5 rounded-full w-fit">
                <GraduationCap className="w-4 h-4" />
                <span>{PROFILE.education}</span>
              </div>
            </div>
            <div className="flex items-center gap-2 flex-wrap pt-1">
              {socialLinks.map(({ href, label, icon: Icon }) => (
                <a
                  key={href}
                  href={href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 text-sm font-medium text-[var(--muted)] hover:text-[var(--accent)] border border-[var(--border)] hover:border-[var(--accent)]/40 bg-[var(--surface)] px-3 py-1.5 rounded-full transition-colors duration-200"
                >
                  <Icon className="w-4 h-4" />
                  <span>{label}</span>
                </a>
              ))}
            </div>
          </div>
        </div>
      </FadeIn>

      <FadeIn delay={0.15}>
        <p className="text-base md:text-lg leading-relaxed text-[var(--muted)] max-w-2xl">
          {PROFILE.bio}
        </p>
      </FadeIn>

      <FadeIn delay={0.25}>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
          <div className="overflow-hidden rounded-2xl border border-[var(--border)] shadow-sm">
            <img
              src={familySara}
              alt="Sara Beck"
              className="w-full aspect-[4/5] object-cover"
            />
          </div>
          <div className="overflow-hidden rounded-2xl border border-[var(--border)] shadow-sm md:translate-y-6">
            <img
              src={familyTrevorSon}
              alt="Trevor with one of the boys"
              className="w-full aspect-[4/5] object-cover"
            />
          </div>
        </div>
      </FadeIn>
    </header>
  );
};
