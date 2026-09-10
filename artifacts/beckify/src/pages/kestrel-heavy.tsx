import { Layout } from "@/components/Layout";
import { KestrelHeavy } from "@/components/games/KestrelHeavy";
import { SchemaHead, videoGameSchema } from "@/components/seo/SchemaHead";
import { PAGE_SEO } from "@/data/seo-copy.mjs";

export default function KestrelHeavyPage() {
  return (
    <Layout showAds={false} variant="cabinet">
      <SchemaHead
        title={PAGE_SEO["/games/kestrel-heavy"].title}
        description={PAGE_SEO["/games/kestrel-heavy"].description}
        path="/games/kestrel-heavy"
        schema={videoGameSchema(
          "Kestrel Heavy",
          PAGE_SEO["/games/kestrel-heavy"].description,
          "/games/kestrel-heavy",
        )}
      />
      <KestrelHeavy />
    </Layout>
  );
}
