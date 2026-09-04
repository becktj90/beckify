import { Layout } from "@/components/Layout";
import { NewGlennRunner } from "@/components/games/NewGlennRunner";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function NewGlennRunnerPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="New Glenn Runner | Beckify Games"
        description="Play New Glenn Runner, a Phaser 4 LC-36 launch arcade with KID, CADET, and PAD RAT difficulty, Jacklyn recovery, rocket pickups, local personal bests, and fullscreen play."
        path="/games/new-glenn-runner"
      />
      <NewGlennRunner />
    </Layout>
  );
}
