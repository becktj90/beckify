import { Layout } from "@/components/Layout";
import { GEAR_FAQS, GEAR_RECOMMENDATIONS, GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

const gearSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "@id": "https://beckify.com/gear#webpage",
    url: "https://beckify.com/gear",
    name: "Recommended Electrical Test Equipment and Tools for Professionals",
    description: "A practical list of hand tools, multimeters, insulation testers, oscilloscopes, clamp meters, cable testers, and RF analyzers for electrical workers and engineers.",
    mainEntity: { "@id": "https://beckify.com/gear#recommendations" },
    about: ["electrical hand tools", "electrical test equipment", "insulation resistance testing", "oscilloscope diagnostics", "RF cable analysis"],
  },
  {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "@id": "https://beckify.com/gear#recommendations",
    name: "Recommended Electrical Test Equipment",
    description: "Model-specific recommendations for professional electrical field and bench work.",
    numberOfItems: GEAR_RECOMMENDATIONS.length,
    itemListElement: GEAR_RECOMMENDATIONS.map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      item: {
        "@type": "Thing",
        name: `${item.name} - ${item.model}`,
        sameAs: item.manufacturerUrl,
      },
    })),
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: GEAR_FAQS.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: { "@type": "Answer", text: item.answer },
    })),
  },
];

export default function GearPage() {
  return <Layout><SchemaHead title="Recommended Electrical Test Equipment & Tools | Beckify" description="Direct model links for professional electrical test equipment: multimeters, clamp meters, insulation testers, hand tools, oscilloscopes, cable testers, RF analyzers, and budget picks." path="/gear" type="article" schema={gearSchema} /><GearMatrix /></Layout>;
}
