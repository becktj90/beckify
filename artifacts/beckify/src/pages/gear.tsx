import { Layout } from "@/components/Layout";
import { GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

const gearSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: "Electrical Test Equipment and Field Gear Guide",
    about: ["electrical testing equipment", "aerospace electrical tooling", "wire termination", "TDR cable fault locating"],
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: [
      {
        "@type": "Question",
        name: "Can buying a product guarantee Amazon Associates approval?",
        acceptedAnswer: { "@type": "Answer", text: "No. Amazon evaluates qualifying purchases and program compliance; no individual product guarantees approval or sales." },
      },
      {
        "@type": "Question",
        name: "What should I check before buying electrical test equipment?",
        acceptedAnswer: { "@type": "Answer", text: "Confirm the safety category, voltage and measurement range, accuracy, cable or connector compatibility, calibration requirements, included accessories, and manufacturer documentation." },
      },
      {
        "@type": "Question",
        name: "How does the Beckify three-sale plan work?",
        acceptedAnswer: { "@type": "Answer", text: "The guide organizes useful buying content around three real field use cases within the initial 180-day window. It does not guarantee sales or Amazon Associates approval." },
      },
    ],
  },
];

export default function GearPage() {
  return <Layout><SchemaHead title="Best Electrical Test Equipment and TDR Tools | Beckify" description="Expert-curated electrical test equipment for aerospace harness work, TDR cable fault locating, field diagnostics, and bench testing, with tagged shopping links." path="/gear" schema={gearSchema} /><GearMatrix /></Layout>;
}
