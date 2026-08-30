import { Layout } from "@/components/Layout";
import { GEAR_RECOMMENDATIONS, GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

const gearSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "@id": "https://beckify.com/gear#webpage",
    url: "https://beckify.com/gear",
    name: "Recommended Electrical Tools, Supplies, and Field Gear",
    description: "Model-specific tools, electrical test equipment, cable fault locators, jobsite supplies, field power, lighting, cooling, and USA-made choices.",
    mainEntity: { "@id": "https://beckify.com/gear#recommendations" },
    about: ["electrical hand tools", "electrical test equipment", "cable fault location", "jobsite lighting", "portable power"],
  },
  {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "@id": "https://beckify.com/gear#recommendations",
    name: "Recommended Electrical Tools and Field Gear",
    description: "Model-specific recommendations for professional electrical work, supplies, and field support.",
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
  return <Layout><SchemaHead title="Recommended Electrical Tools, Supplies & Field Gear | Beckify" description="Direct model links for industry-standard tools, electrical test equipment, cable fault locators, jobsite supplies, field power, lighting, cooling, and USA-made choices." path="/gear" type="article" schema={gearSchema} /><GearMatrix /></Layout>;
}
