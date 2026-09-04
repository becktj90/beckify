import { Layout } from "@/components/Layout";
import { GEAR_RECOMMENDATIONS, GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

const gearSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "@id": "https://beckify.com/gear#webpage",
    url: "https://beckify.com/gear",
    name: "Field Kit — Electrical Tools We Trust on the Job",
    description:
      "Curated, model-specific field kits for electrical work: jobsite starter, panel troubleshooting, cable fault location, and bench controls.",
    mainEntity: { "@id": "https://beckify.com/gear#recommendations" },
    about: ["electrical field kits", "electrical hand tools", "electrical test equipment", "cable fault location"],
  },
  {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "@id": "https://beckify.com/gear#recommendations",
    name: "Recommended Electrical Tools and Field Gear",
    description: "Model-specific recommendations for professional electrical work, organized as curated field kits.",
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
];

export default function GearPage() {
  return (
    <Layout>
      <SchemaHead
        title="Field Kit | Electrical Tools We Trust on the Job | Beckify"
        description="Curated field kits for electrical work — model-specific meters, hand tools, thermal, insulation, and cable fault gear. Not a gadget dump."
        path="/gear"
        type="article"
        schema={gearSchema}
      />
      <GearMatrix />
    </Layout>
  );
}
