import { Layout } from "@/components/Layout";
import { About as AboutSection } from "@/components/sections/About";
import { Contact } from "@/components/sections/Contact";
import { SchemaHead, SITE_URL, toCanonicalUrl } from "@/components/seo/SchemaHead";
import { PROFILE } from "@/data/site-content";
import { PAGE_SEO } from "@/data/seo-copy.mjs";

export default function AboutPage() {
  return (
    <Layout>
      <SchemaHead
        title={PAGE_SEO["/about"].title}
        description={PAGE_SEO["/about"].description}
        path="/about"
        schema={{
          "@context": "https://schema.org",
          "@type": ["Organization", "Person"],
          name: PROFILE.name,
          url: toCanonicalUrl("/about"),
          jobTitle: PROFILE.title,
          description: PROFILE.bio,
          worksFor: { "@type": "Organization", name: "Beckify", url: SITE_URL },
        }}
      />
      <AboutSection />
      <Contact />
    </Layout>
  );
}
