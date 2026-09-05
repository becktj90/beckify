import { Layout } from "@/components/Layout";
import { KestrelHeavy } from "@/components/games/KestrelHeavy";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function KestrelHeavyPage() {
  return (
    <Layout showAds={false} variant="cabinet">
      <SchemaHead
        title="Kestrel Heavy | Beckify Games"
        description="Play Kestrel Heavy, a Phaser 4 Pier 7 launch arcade with KID, CADET, and PAD RAT difficulty, Haven recovery, rocket pickups, local personal bests, and fullscreen play."
        path="/games/kestrel-heavy"
      />
      <KestrelHeavy />
    </Layout>
  );
}
