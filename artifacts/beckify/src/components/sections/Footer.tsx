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
        <p className="type-hud text-[var(--muted)]">© {new Date().getFullYear()} Beck</p>
        {/* p-2 -m-2 grows the tap target to WCAG's 24px minimum without
            shifting the visible text/icon or the footer's own spacing —
            the negative margin cancels the padding's effect on layout. */}
        <Link href="/sitemap" className="p-2 -m-2 transition-colors duration-200 hover:text-[var(--accent)]">
          Site Map
        </Link>
        <Link href="/privacy" className="p-2 -m-2 transition-colors duration-200 hover:text-[var(--accent)]">
          Privacy
        </Link>
        {CONTACT_LINKS.map(({ href, label, icon: Icon, external }) => (
          <a
            key={href}
            href={href}
            {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
            className="flex items-center gap-1.5 p-2 -m-2 transition-colors duration-200 hover:text-[var(--accent)]"
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
      {/* opacity-60 measured at 3.14:1 against the page background — below
          the 4.5:1 WCAG AA needs for this size of text. 85% clears it with
          margin (5.33:1) while still reading as the intentionally quiet,
          secondary link it's meant to be. */}
      <Link href="/about" className="p-2 -m-2 text-xs opacity-85 transition-opacity duration-200 hover:opacity-100">
        About Me
      </Link>
    </div>
  </footer>
);
