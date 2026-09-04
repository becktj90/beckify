import { Layout } from "@/components/Layout";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { BootyButtScooter } from "@/components/games/BootyButtScooter";

export default function BootyButtScooterPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="Booty Butt Scooter | Beckify Games"
        description="Play Booty Butt Scooter, a Crossy-style scooter hopper with cartoon riders Blaze and Spark, fart boosts, traffic dodges, and local high scores."
        path="/games/booty-butt-scooter"
      />
      <BootyButtScooter />
    </Layout>
  );
}
