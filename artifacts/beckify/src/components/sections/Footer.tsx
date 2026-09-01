import { Wifi } from "lucide-react";
import { Link } from "wouter";
import { CONTACT_LINKS, SITE_VERSION } from "@/data/site-content";
import beckifyMark from "@/assets/beckify-mark-white.png";

export const Footer = () => (
  <footer className="border-t border-[var(--border)] pt-12 pb-8 text-sm text-[var(--muted)]">
    <div className="flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
      <div className="flex flex-wrap items-center gap-4">
        <div className="flex h-8 w-8 items-center justify-center rounded-full border border-[var(--accent)]/20 bg-[var(--accent-soft)] p-1.5">
          <img src={beckifyMark} alt="Beckify" className="h-full w-full object-contain" />
        </div>
        <p>© {new Date().getFullYear()} Beck</p>
        <Link href="/sitemap" className="transition-colors duration-200 hover:text-[var(--accent)]">
          Site Map
        </Link>
        <Link href="/gear" className="transition-colors duration-200 hover:text-[var(--accent)]">
          Recommended Gear
        </Link>
        {CONTACT_LINKS.map(({ href, label, icon: Icon, external }) => (
          <a
            key={href}
            href={href}
            {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
            className="flex items-center gap-1.5 transition-colors duration-200 hover:text-[var(--accent)]"
            aria-label={label}
          >
            <Icon className="h-4 w-4" />
          </a>
        ))}
      </div>

      <div className="flex items-center gap-6 rounded-full border border-[var(--border)] bg-[var(--surface)] px-4 py-2 shadow-sm">
        <p className="flex items-center gap-2">
          <span className="h-2 w-2 rounded-full bg-[var(--accent)]" />
          <span>Online</span>
        </p>
        <div className="h-4 w-px bg-[var(--border)]" />
        <p className="flex items-center gap-2 text-[var(--accent)]">
          <Wifi className="h-3 w-3" />
          <span>{SITE_VERSION}</span>
        </p>
      </div>
    </div>

    <div className="mt-6 flex justify-end">
      <Link href="/about" className="text-xs opacity-60 transition-opacity duration-200 hover:opacity-100">
        About Me
      </Link>
    </div>
  </footer>
);
