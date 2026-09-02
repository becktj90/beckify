import { Layout } from "@/components/Layout";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { ApolloRoccoRun } from "@/components/games/ApolloRoccoRun";

export default function ApolloRoccoRunPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="Apollo & Rocco Run | Beckify Games"
        description="Play Apollo & Rocco Run, a backyard water-balloon runner starring Apollo (orange balloon) and Rocco (pink balloon), with kid-friendly lanes, jump, slide, and a local best on this device."
        path="/games/apollo-rocco-run"
      />
      <ApolloRoccoRun />
    </Layout>
  );
}
