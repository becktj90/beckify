import { Layout } from "@/components/Layout";
import { KidsSpaceShooter } from "@/components/games/KidsSpaceShooter";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function CosmicCadetPage() {
  return <Layout showAds={false}><SchemaHead title="Cosmic Cadet | Beckify Games" description="Play Cosmic Cadet, a kid-friendly browser space blaster with auto-fire, touch steering, power-ups, live score and wave, pause, and local best flights." path="/games/cosmic-cadet" /><KidsSpaceShooter /></Layout>;
}
