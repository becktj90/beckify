import { Layout } from "@/components/Layout";
import { Games as GamesSection } from "@/components/sections/Games";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { KidsSpaceShooter } from "@/components/games/KidsSpaceShooter";

export default function GamesPage() {
  return (
    <Layout>
      <SchemaHead
        title="Browser Games | Beckify"
        description="Play lightweight browser games from Beckify, including arcade runners built for quick breaks on desktop and mobile."
        path="/games"
      />
      <KidsSpaceShooter />
      <GamesSection />
    </Layout>
  );
}
