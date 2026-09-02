import { Layout } from "@/components/Layout";
import { PupPlanet } from "@/components/games/PupPlanet";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function PupPlanetPage() {
  return <Layout showAds={false}><SchemaHead title="Pup Planet | Beckify Games" description="Play Pup Planet: pick Apollo or Rocco and mine and build on a seeded little planet in this first-person WebGL sandbox. Built big and simple for iPad." path="/games/pup-planet" /><PupPlanet /></Layout>;
}
