import { Layout } from "@/components/Layout";
import { GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function GearPage() { return <Layout><SchemaHead title="Recommended Electrical Engineering Gear | Beckify" description="Browse Beckify's technically justified recommendations for wire termination, bench prototyping, and field electrical diagnostics." path="/gear" /><GearMatrix /></Layout>; }
