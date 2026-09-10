import { Layout } from "@/components/Layout";
import { Projects as ProjectsSection } from "@/components/sections/Projects";
import { SchemaHead, toCanonicalUrl } from "@/components/seo/SchemaHead";
import { PAGE_SEO } from "@/data/seo-copy.mjs";

export default function ProjectsPage() {
  return (
    <Layout>
      <SchemaHead
        title={PAGE_SEO["/projects"].title}
        description={PAGE_SEO["/projects"].description}
        path="/projects"
        schema={{
          "@context": "https://schema.org",
          "@type": "CollectionPage",
          name: PAGE_SEO["/projects"].title,
          description: PAGE_SEO["/projects"].description,
          url: toCanonicalUrl("/projects"),
          hasPart: [
            { "@type": "TechArticle", name: "1979 Vespa P200E electric conversion", url: toCanonicalUrl("/projects/vespa-p200e") },
            { "@type": "TechArticle", name: "Honda XR650R electric conversion", url: toCanonicalUrl("/projects/honda-xr650r") },
          ],
        }}
      />
      <ProjectsSection />
    </Layout>
  );
}
