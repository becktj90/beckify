import { Layout } from "@/components/Layout";
import { AmericanMadeShowcase } from "@/components/AmericanMadeShowcase";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { MADE_IN_AMERICA_FAQ, USA_MADE_GEAR } from "@/data/gear-recommendations";

const pageSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "@id": "https://beckify.com/made-in-america#webpage",
    url: "https://beckify.com/made-in-america",
    name: "American-Made Electrical Tools & Supplies",
    description:
      "Verified American-made electrical hand tools, strippers, cutters, tape, and supplies with exact model numbers and manufacturer sourcing notes.",
    mainEntity: { "@id": "https://beckify.com/made-in-america#list" },
    about: ["made in america", "american made tools", "usa made electrical tools", "domestic manufacturing"],
  },
  {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "@id": "https://beckify.com/made-in-america#list",
    name: "American-Made Electrical Tools",
    description: "Manufacturer-verified U.S.-made electrical tools and supplies.",
    numberOfItems: USA_MADE_GEAR.length,
    itemListElement: USA_MADE_GEAR.map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      item: {
        "@type": "Product",
        name: `${item.name} - ${item.model}`,
        description: item.bestFor,
        brand: { "@type": "Brand", name: item.name.split(" ")[0] },
        countryOfOrigin: { "@type": "Country", name: "United States" },
        sameAs: item.manufacturerUrl,
        ...(item.imageUrl ? { image: item.imageUrl } : {}),
      },
    })),
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: MADE_IN_AMERICA_FAQ.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: { "@type": "Answer", text: item.answer },
    })),
  },
];

export default function MadeInAmericaPage() {
  return (
    <Layout>
      <SchemaHead
        title="American-Made Electrical Tools & Supplies | Made in America | Beckify"
        description="Find verified American-made electrical tools — Klein strippers, CHANNELLOCK pliers, Daniels crimp frames, and 3M tape. Exact models, manufacturer links, and sourcing notes for electricians."
        path="/made-in-america"
        type="article"
        schema={pageSchema}
      />
      <AmericanMadeShowcase />
    </Layout>
  );
}
