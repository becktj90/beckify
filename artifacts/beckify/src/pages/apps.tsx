import { ExternalLink } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead, toCanonicalUrl } from "@/components/seo/SchemaHead";
import { IOS_APPS } from "@/data/site-content";
import { PAGE_SEO } from "@/data/seo-copy.mjs";
import { BeckifyIcon } from "@/components/ui/icons/BeckifyIcon";

export default function AppsPage() {
  return (
    <Layout>
      <SchemaHead
        title={PAGE_SEO["/apps"].title}
        description={PAGE_SEO["/apps"].description}
        path="/apps"
        schema={{
          "@context": "https://schema.org",
          "@type": "CollectionPage",
          name: PAGE_SEO["/apps"].title,
          description: PAGE_SEO["/apps"].description,
          url: toCanonicalUrl("/apps"),
          hasPart: IOS_APPS.map((app) => ({
            "@type": "MobileApplication",
            name: app.name,
            operatingSystem: "iOS",
            applicationCategory: app.meta.split(" · ")[1],
            description: app.tagline,
            offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
            ...(app.appStoreUrl ? { url: app.appStoreUrl } : {}),
          })),
        }}
      />
      <section id="apps" className="space-y-8 scroll-mt-24">
        <FadeIn>
          <SectionHeader
            title="iPhone & iPad Apps"
            level="h1"
            subtitle="Native SwiftUI apps — not website wrappers. Free, no ads, no accounts."
            icon={(props: { className?: string }) => <BeckifyIcon name="toolbox" {...props} />}
          />
        </FadeIn>

        <FadeIn delay={0.1}>
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
            {IOS_APPS.map((app) => (
              <article key={app.bundleId} className="card-surface flex flex-col p-6">
                <div className="flex items-center gap-3">
                  <app.icon className="h-5 w-5 text-[var(--accent)]" />
                  <h2 className="font-display text-xl font-bold text-[var(--foreground)]">{app.name}</h2>
                </div>
                <p className="type-label mt-1 text-[var(--accent)]">{app.tagline}</p>
                <p className="mt-4 text-sm leading-relaxed text-[var(--muted)]">{app.description}</p>
                <ul className="mt-4 list-disc space-y-1.5 pl-5 text-sm leading-relaxed text-[var(--muted)]">
                  {app.highlights.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
                <p className="mt-4 text-xs text-[var(--muted)]">{app.meta}</p>
                <div className="mt-auto pt-5">
                  {app.appStoreUrl ? (
                    <a
                      href={app.appStoreUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 rounded-xl bg-[var(--accent)] px-4 py-2 text-sm font-semibold text-[var(--accent-foreground)]"
                    >
                      View on the App Store
                      <ExternalLink className="h-4 w-4" />
                    </a>
                  ) : (
                    <span className="inline-flex rounded-full border border-[var(--border)] px-3 py-1.5 text-sm text-[var(--muted)]">
                      {app.status}
                    </span>
                  )}
                </div>
              </article>
            ))}
          </div>
        </FadeIn>

        <FadeIn delay={0.14}>
          <p className="text-sm leading-relaxed text-[var(--muted)]">
            The browser <a className="text-[var(--accent)] underline" href="/toolbox/">EE Toolbox</a> stays free on the web.
            Calculators are design aids, not a PE stamp. See the <a className="text-[var(--accent)] underline" href="/privacy">privacy policy</a>.
          </p>
        </FadeIn>
      </section>
    </Layout>
  );
}
