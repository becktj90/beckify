import { Layout } from "@/components/Layout";
import { About as AboutSection } from "@/components/sections/About";
import { Contact } from "@/components/sections/Contact";
import { SchemaHead, SITE_URL } from "@/components/seo/SchemaHead";
import { PROFILE } from "@/data/site-content";

export default function AboutPage() {
  return (
    <Layout>
      <SchemaHead
        title="About Trevor Beck | Beckify"
        description="Meet Trevor Beck, an electrical engineer building practical engineering tools, references, and hands-on projects for the field."
        path="/about"
        schema={{
          "@context": "https://schema.org",
          "@type": ["Organization", "Person"],
          name: PROFILE.name,
          url: `${SITE_URL}/about`,
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
