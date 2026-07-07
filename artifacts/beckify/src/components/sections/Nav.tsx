import { Link, useLocation } from "wouter";
import { NAV_LINKS } from "@/data/site-content";
import beckifyMark from "@/assets/beckify-mark-white.png";

/**
 * Full-width sticky top navigation bar.
 * Logo anchors left; nav links sit on the right with a high-contrast filled
 * active state. Backdrop-blur keeps it legible over the starfield.
 */
export const Nav = () => {
  const [location] = useLocation();

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

          {/* Nav links */}
          <div className="flex items-center gap-1">
            {NAV_LINKS.map(({ href, label, icon: Icon }) => {
              const active = location === href;
              return (
                <Link
                  key={href}
                  href={href}
                  className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-sm font-medium transition-all duration-200 whitespace-nowrap ${
                    active
                      ? "text-white bg-[var(--accent)] shadow-[0_0_12px_rgba(139,123,255,0.45)]"
                      : "text-[var(--muted)] hover:text-[var(--foreground)] hover:bg-white/08"
                  }`}
                >
                  <Icon
                    className={`w-3.5 h-3.5 ${active ? "opacity-100" : "opacity-70"}`}
                  />
                  <span className="hidden sm:inline">{label}</span>
                </Link>
              );
            })}
          </div>
        </div>
      </div>
    </nav>
  );
};
