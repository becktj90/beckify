import { Layout } from "@/components/Layout";
import { TootTroopers } from "@/components/games/TootTroopers";
import { SchemaHead } from "@/components/seo/SchemaHead";
export default function TootTroopersPage() { return <Layout showAds={false}><SchemaHead title="Toot Troopers | Beckify Games" description="Fart-flap as Blaze or Spark through an original sky obstacle course." path="/games/toot-troopers" /><TootTroopers /></Layout>; }
