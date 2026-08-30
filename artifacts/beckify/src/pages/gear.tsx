import { Layout } from "@/components/Layout";
import { GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

const gearSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: "Electrical Qualification and Field Gear Guide",
    about: ["electrical exam preparation", "electrical testing equipment", "wire termination", "field diagnostics"],
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: [
      {
        "@type": "Question",
        name: "Can a tool guarantee that I become a qualified electrician?",
        acceptedAnswer: { "@type": "Answer", text: "No. Tools and study products can support preparation, but qualification depends on the applicable authority, supervised experience, training, and exam or certification requirements." },
      },
      {
        "@type": "Question",
        name: "What should I buy first for electrical exam preparation?",
        acceptedAnswer: { "@type": "Answer", text: "Start with the current exam-preparation material and code reference accepted by your licensing authority. Add a reliable meter and supervised measurement practice before specialized diagnostic equipment." },
      },
      {
        "@type": "Question",
        name: "How long does the Beckify field kit plan take?",
        acceptedAnswer: { "@type": "Answer", text: "The guide is organized as a 90-day preparation pathway with 30-day milestones. It is a study and practice framework, not a promise of a license or certification by a particular date." },
      },
    ],
  },
];

export default function GearPage() {
  return <Layout><SchemaHead title="Best Electrical Exam Prep and Field Test Tools | Beckify" description="An expert-curated electrical gear guide with exam prep, NEC references, meters, crimpers, and field testers organized into a 180-day plan." path="/gear" schema={gearSchema} /><GearMatrix /></Layout>;
}
