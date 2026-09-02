import { Layout } from "@/components/Layout";
import { Games as GamesSection } from "@/components/sections/Games";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function GamesPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="Browser Games | Beckify"
        description="Play seven original Beckify browser games — Cosmic Cadet, Pup Planet, Finger Runner, Toot Troopers, Booty Butt Scooter, Apollo & Rocco Run, and New Glenn Runner. No ads."
        path="/games"
      />
      <GamesSection />
    </Layout>
  );
}
