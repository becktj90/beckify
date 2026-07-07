import { Wifi } from "lucide-react";
import { CONTACT_LINKS, SITE_VERSION } from "@/data/site-content";
import beckifyMark from "@/assets/beckify-mark-white.png";

export const Footer = () => (
  <footer className="pt-12 pb-8 border-t border-[var(--border)] flex flex-col md:flex-row justify-between items-center gap-6 text-sm text-[var(--muted)]">
    <div className="flex items-center gap-4">
      <div className="w-8 h-8 rounded-full bg-[var(--accent-soft)] border border-[var(--accent)]/20 flex items-center justify-center p-1.5">
        <img src={beckifyMark} alt="Beckify" className="w-full h-full object-contain" />
      </div>
      <p>© {new Date().getFullYear()} Beck</p>
      {CONTACT_LINKS.map(({ href, label, icon: Icon, external }) => (
        <a
          key={href}
          href={href}
          {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
          className="flex items-center gap-1.5 hover:text-[var(--accent)] transition-colors duration-200"
          aria-label={label}
        >
          <Icon className="w-4 h-4" />
        </a>
      ))}
    </div>

    <div className="flex items-center gap-6 bg-[var(--surface)] border border-[var(--border)] px-4 py-2 rounded-full shadow-sm">
      <p className="flex items-center gap-2">
        <span className="w-2 h-2 rounded-full bg-[var(--accent)]" />
        <span>Online</span>
      </p>
      <div className="w-px h-4 bg-[var(--border)]" />
      <p className="flex items-center gap-2 text-[var(--accent)]">
        <Wifi className="w-3 h-3" />
        <span>{SITE_VERSION}</span>
      </p>
    </div>
  </footer>
);
