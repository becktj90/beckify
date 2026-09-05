import { Layout } from "@/components/Layout";
import { Games as GamesSection } from "@/components/sections/Games";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function GamesPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="Browser Games | Beckify"
        description="Play Kestrel Heavy, Beckify's on-site launch arcade. No ads."
        path="/games"
      />
      <GamesSection />
    </Layout>
  );
}
