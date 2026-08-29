import { Layout } from "@/components/Layout";
import { Projects as ProjectsSection } from "@/components/sections/Projects";
import { SchemaHead, SITE_URL } from "@/components/seo/SchemaHead";
import { LC934Dashboard } from "@/components/projects/LC934Dashboard";

export default function ProjectsPage() {
  return (
    <Layout>
      <SchemaHead
        title="Projects & Build Logs | Beckify"
        description="Explore Beckify project logs covering electric vehicles, experimental web projects, fabrication, and practical engineering work."
        path="/projects"
        type="article"
        schema={{
          "@context": "https://schema.org",
          "@type": ["TechArticle", "HowTo"],
          name: "Beckify Engineering Projects and Build Logs",
          description: "Technical build logs and project notes from Beckify.",
          url: `${SITE_URL}/projects`,
          author: { "@type": "Person", name: "Trevor Beck" },
        }}
      />
      <LC934Dashboard />
      <ProjectsSection />
    </Layout>
  );
}
