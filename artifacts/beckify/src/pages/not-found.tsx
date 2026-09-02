import { Link } from "wouter";
import { Compass } from "lucide-react";
import { Layout } from "@/components/Layout";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { NAV_LINKS } from "@/data/site-content";

/**
 * GitHub Pages serves this same file for every unmatched path (the SPA
 * 404->200 fallback), so it renders under whatever URL a visitor actually
 * typed or followed. It must never be indexed as a real page — a broken
 * inbound link would otherwise become a crawlable duplicate of this one.
 */
export default function NotFound() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="Page Not Found | Beckify"
        description="This page doesn't exist. Find engineering tools, projects, and games from the Beckify home page."
        robots="noindex,follow"
      />
      <section className="flex flex-col items-center gap-6 py-20 text-center">
        <Compass className="h-10 w-10 text-[var(--accent)]" aria-hidden="true" />
        <div>
          <h1 className="text-3xl font-bold text-[var(--foreground)]">Page not found</h1>
          <p className="mt-3 max-w-md text-[var(--muted)]">
            The page you're looking for doesn't exist or may have moved. Try
            one of these instead:
          </p>
        </div>
        <nav aria-label="Suggested pages" className="flex flex-wrap justify-center gap-3">
          <Link
            href="/"
            className="rounded-xl bg-[var(--accent)] px-4 py-2.5 text-sm font-semibold text-[var(--accent-foreground)] transition-opacity hover:opacity-90"
          >
            Go home
          </Link>
          {NAV_LINKS.map(({ href, label, external }) => {
            const LinkTag = (external ? "a" : Link) as typeof Link;
            return (
              <LinkTag
                key={href}
                href={href}
                className="rounded-xl border border-[var(--border)] px-4 py-2.5 text-sm font-medium text-[var(--foreground)] transition-colors hover:border-[var(--accent)]/60"
              >
                {label}
              </LinkTag>
            );
          })}
        </nav>
      </section>
    </Layout>
  );
}
