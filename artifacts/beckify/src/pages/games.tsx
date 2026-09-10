import { Layout } from "@/components/Layout";
import { Games as GamesSection } from "@/components/sections/Games";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { PAGE_SEO } from "@/data/seo-copy.mjs";

export default function GamesPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title={PAGE_SEO["/games"].title}
        description={PAGE_SEO["/games"].description}
        path="/games"
      />
      <GamesSection />
    </Layout>
  );
}
