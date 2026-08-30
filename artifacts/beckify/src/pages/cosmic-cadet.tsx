import { Layout } from "@/components/Layout";
import { KidsSpaceShooter } from "@/components/games/KidsSpaceShooter";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function CosmicCadetPage() {
  return <Layout showAds={false}><SchemaHead title="Cosmic Cadet | Beckify Games" description="Play Cosmic Cadet, a responsive browser space shooter with keyboard, pointer, touch, waves, hull damage, pause, and fullscreen play." path="/games/cosmic-cadet" /><KidsSpaceShooter /></Layout>;
}
