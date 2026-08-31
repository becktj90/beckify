import { Layout } from "@/components/Layout";
import { HexGL } from "@/components/games/HexGL";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function HexGLPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="HexGL | Beckify Games"
        description="Play HexGL, a futuristic WebGL racing game by Thibaut Despoulain (BKcore), hosted on Beckify under the MIT License."
        path="/games/hexgl"
      />
      <HexGL />
    </Layout>
  );
}
