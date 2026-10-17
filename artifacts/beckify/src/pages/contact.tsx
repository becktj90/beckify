import { Mail } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead, toCanonicalUrl } from "@/components/seo/SchemaHead";
import { PAGE_SEO } from "@/data/seo-copy.mjs";
import { EMAIL_ADDRESS } from "@/data/site-content";
import { SHOP_ORIGIN } from "@/data/shop.mjs";

const CONTACT_URL = toCanonicalUrl("/contact");

const pageSchema = {
  "@context": "https://schema.org",
  "@type": "ContactPage",
  "@id": `${CONTACT_URL}#webpage`,
  url: CONTACT_URL,
  name: "Contact — Beckify",
  mainEntity: {
    "@type": "Person",
    name: "Trevor Beck",
    email: EMAIL_ADDRESS,
  },
};

const TOPICS = [
  { label: "Site and app", text: "Questions about beckify.com, the Beckify iPhone and iPad app, or Kestrel Heavy." },
  { label: "Shop orders", text: `Questions about an order from ${SHOP_ORIGIN.replace("https://", "")}. Include the order number.` },
  { label: "Corrections", text: "Report a calculator error or a broken page. Include the page address and the inputs used." },
];

export default function ContactPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title={PAGE_SEO["/contact"].title}
        description={PAGE_SEO["/contact"].description}
        path="/contact"
        schema={pageSchema}
      />
      <FadeIn>
        <SectionHeader
          title="Contact"
          level="h1"
          subtitle="One address for the site, the app, and the shop."
          icon={Mail}
        />
      </FadeIn>

      <FadeIn delay={0.05}>
        <section className="max-w-3xl space-y-8 text-[var(--foreground)]">
          <p className="text-sm leading-relaxed">
            Email{" "}
            <a
              className="text-[var(--accent)] underline-offset-4 hover:underline"
              href={`mailto:${EMAIL_ADDRESS}`}
            >
              {EMAIL_ADDRESS}
            </a>
            .
          </p>
          <dl className="grid grid-cols-1 sm:grid-cols-[10rem_1fr] gap-x-6 gap-y-3 text-sm leading-relaxed">
            {TOPICS.map((t) => (
              <div key={t.label} className="contents">
                <dt className="text-[var(--muted)]">{t.label}</dt>
                <dd>{t.text}</dd>
              </div>
            ))}
          </dl>
          <p className="text-sm leading-relaxed text-[var(--muted)]">
            Shop: <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={SHOP_ORIGIN}>{SHOP_ORIGIN.replace("https://", "")}</a>.
            Privacy: <a className="text-[var(--accent)] underline-offset-4 hover:underline" href="/privacy/">privacy policy</a>.
          </p>
        </section>
      </FadeIn>
    </Layout>
  );
}
