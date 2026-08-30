import { Layout } from "@/components/Layout";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { BootyButtScooter } from "@/components/games/BootyButtScooter";

export default function BootyButtScooterPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="Booty Butt Scooter | Beckify Games"
        description="Play Booty Butt Scooter, a responsive lane runner with swipe controls, jump timing, local high scores, and fast arcade pacing."
        path="/games/booty-butt-scooter"
      />
      <BootyButtScooter />
    </Layout>
  );
}
