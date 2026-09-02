import { useState } from "react";
import { Link, useLocation } from "wouter";
import { NAV_LINKS } from "@/data/site-content";
import beckifyMark from "@/assets/beckify-mark-white.png";
import { EngineeringAssistant } from "@/components/EngineeringAssistant";
import { BeckifyIcon, type BeckifyIconName } from "@/components/ui/icons/BeckifyIcon";
import { Sheet, SheetClose, SheetContent, SheetDescription, SheetTitle, SheetTrigger } from "@/components/ui/sheet";

const NAV_ICON_NAMES: Record<string, BeckifyIconName> = {
  Toolbox: "toolbox",
  "Control Systems": "gauge",
  Projects: "projects",
  Games: "games",
  "Recommended Gear": "signal",
};

function NavLink({
  href,
  label,
  external,
  active,
  variant,
}: {
  href: string;
  label: string;
  external?: boolean;
  active: boolean;
  /** "bar" = compact icon+label pill in the desktop header. "menu" = full-width row in the mobile sheet. */
  variant: "bar" | "menu";
}) {
  /* External entries leave the SPA, so they must be real anchors — wouter
     would otherwise route them client-side. */
  const LinkTag = (external ? "a" : Link) as typeof Link;
  const icon = (
    <BeckifyIcon
      name={NAV_ICON_NAMES[label] ?? "home"}
      className={variant === "bar" ? `w-3.5 h-3.5 ${active ? "opacity-100" : "opacity-70"}` : "w-5 h-5 shrink-0"}
    />
  );
  if (variant === "menu") {
    return (
      <LinkTag
        href={href}
        aria-current={active ? "page" : undefined}
        className={`flex items-center gap-3 rounded-xl px-4 py-3 text-base font-medium transition-colors ${
          active
            ? "text-[var(--accent-foreground)] bg-[var(--accent)]"
            : "text-[var(--foreground)] hover:bg-white/08"
        }`}
      >
        {icon}
        {label}
      </LinkTag>
    );
  }
  return (
    <LinkTag
      href={href}
      aria-label={label}
      title={label}
      className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-sm font-medium transition-all duration-200 whitespace-nowrap ${
        active
          ? "text-[var(--accent-foreground)] bg-[var(--accent)] shadow-[0_0_12px_rgba(139,123,255,0.45)]"
          : "text-[var(--muted)] hover:text-[var(--foreground)] hover:bg-white/08"
      }`}
    >
      {icon}
      <span>{label}</span>
    </LinkTag>
  );
}

/**
 * Full-width sticky top navigation bar.
 * Logo anchors left; nav links sit on the right with a high-contrast filled
 * active state. Backdrop-blur keeps it legible over the starfield.
 *
 * The full label+icon link row only fits from `lg` up (measured: it needs
 * ~940px at full label width). Below that, the bar shows logo + search +
 * a single menu button, and the same links reappear as full-width rows in a
 * slide-out sheet — this is what actually fixes the site-wide horizontal
 * scroll that a purely-responsive icon row still hit on phones.
 */
export const Nav = () => {
  const [location] = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav className="sticky top-0 z-40 w-full">
      <div className="mx-auto max-w-5xl px-4 py-3">
        <div
          className="flex items-center justify-between px-4 py-2.5 rounded-2xl backdrop-blur-md border border-[var(--border)]"
          style={{
            background:
              "linear-gradient(135deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0.025) 100%)",
            boxShadow:
              "0 8px 32px -8px rgba(0,0,0,0.7), inset 0 1px 0 rgba(255,255,255,0.07)",
          }}
        >
          {/* Logo + wordmark */}
          <Link
            href="/"
            className="flex items-center gap-2.5 group"
            aria-label="Beckify home"
          >
            <div
              className="w-8 h-8 rounded-xl flex items-center justify-center transition-all duration-200 group-hover:scale-105"
              style={{
                background:
                  "linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%)",
                boxShadow: "0 0 0 1px rgba(139,123,255,0.3)",
              }}
            >
              <img
                src={beckifyMark}
                alt=""
                className="w-4.5 h-4.5 object-contain"
              />
            </div>
            <span
              className="font-logo text-base font-bold tracking-wide text-[var(--foreground)] group-hover:text-[var(--accent)] transition-colors duration-200"
              style={{ fontFamily: "var(--font-logo)" }}
            >
              Beckify
            </span>
          </Link>

          <div className="flex items-center gap-1">
            <EngineeringAssistant />

            {/* Full link row: only from lg up, where it's been measured to fit. */}
            <div className="hidden lg:flex items-center gap-1">
              {NAV_LINKS.map(({ href, label, external }) => (
                <NavLink
                  key={href}
                  href={href}
                  label={label}
                  external={external}
                  variant="bar"
                  active={location === href || (!!external && location === href.replace(/\/$/, ""))}
                />
              ))}
            </div>

            {/* Below lg: a single menu button opens the same links as a sheet. */}
            <Sheet open={menuOpen} onOpenChange={setMenuOpen}>
              <SheetTrigger asChild>
                <button
                  type="button"
                  aria-label="Open navigation menu"
                  className="lg:hidden flex items-center justify-center w-11 h-11 rounded-xl text-[var(--muted)] hover:text-[var(--foreground)] hover:bg-white/08 transition-colors"
                >
                  <BeckifyIcon name="menu" className="w-5 h-5" />
                </button>
              </SheetTrigger>
              <SheetContent side="right" className="w-[min(20rem,85vw)] border-l border-[var(--border)] bg-[var(--background)]">
                <SheetTitle className="text-[var(--foreground)]">Beckify</SheetTitle>
                <SheetDescription className="sr-only">Site navigation</SheetDescription>
                <nav aria-label="Site" className="mt-4 flex flex-col gap-1">
                  {NAV_LINKS.map(({ href, label, external }) => (
                    <SheetClose asChild key={href}>
                      <NavLink
                        href={href}
                        label={label}
                        external={external}
                        variant="menu"
                        active={location === href || (!!external && location === href.replace(/\/$/, ""))}
                      />
                    </SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </nav>
  );
};
