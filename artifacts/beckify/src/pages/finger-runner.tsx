import { Layout } from "@/components/Layout";
import { FingerRunner } from "@/components/games/FingerRunner";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function FingerRunnerPage() {
  return <Layout showAds={false}><SchemaHead title="Finger Runner | Beckify Games" description="Play Finger Runner, a touch-friendly endless browser runner with simple controls, persistent high scores, and quick arcade sessions." path="/games/finger-runner" /><FingerRunner /></Layout>;
}
