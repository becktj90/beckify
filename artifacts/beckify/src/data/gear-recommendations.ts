export type GearCategory =
  | "Tools and supplies"
  | "Test equipment"
  | "Cable and fault location"
  | "Job comfort and power";

export type Gear = {
  category: GearCategory;
  name: string;
  model: string;
  bestFor: string;
  note: string;
  amazonUrl: string;
  manufacturerUrl: string;
  imageUrl?: string;
  imagePlaceholder?: boolean;
  budget?: boolean;
  usaMade?: boolean;
  /** How we confirmed U.S. manufacturing — shown on the made-in-America page. */
  usaMadeSource?: string;
  certification?: string;
};

/** Verified U.S.-made picks for the Made in America lookbook. Not a full catalog. */
export const GEAR_RECOMMENDATIONS: Gear[] = [
  {
    category: "Tools and supplies",
    name: "Daniels Manufacturing AF8",
    model: "M22520/1-01 crimp frame",
    bestFor: "Qualified machined-contact crimping with the approved turret or positioner.",
    note: "Match the contact family, setting, locator, and work instruction.",
    amazonUrl: "https://www.amazon.com/dp/B09CV54JPN?tag=beckify-20",
    manufacturerUrl: "https://dmctools.com/af8-af8",
    imageUrl: "/images/gear/daniels-af8.jpg",
    usaMade: true,
    usaMadeSource: "Daniels Manufacturing designs and builds crimp tools in Orlando, Florida.",
  },
  {
    category: "Tools and supplies",
    name: "Klein Tools 11055",
    model: "Wire stripper and cutter",
    bestFor: "Everyday copper-conductor stripping and cutting.",
    note: "A practical general wiring tool, not qualified contact-crimp tooling.",
    amazonUrl: "https://www.amazon.com/dp/B00080DPNQ?tag=beckify-20",
    manufacturerUrl:
      "https://www.kleintools.com/catalog/wire-strippers-cutters-and-crimpers/wire-stripper-and-cutter-self-opening",
    imageUrl: "/images/gear/klein-11055.jpg",
    budget: true,
    usaMade: true,
    usaMadeSource: "Klein Tools manufactures the majority of its hand tools in U.S. plants, including this stripper line.",
  },
  {
    category: "Tools and supplies",
    name: "Klein Tools 63050",
    model: "High-leverage cable cutter",
    bestFor: "Clean copper, aluminum, and communications-cable cuts before termination.",
    note: "Verify capacity; never use on energized cable.",
    amazonUrl: "https://www.amazon.com/dp/B0000302X1?tag=beckify-20",
    manufacturerUrl: "https://www.kleintools.com/catalog/standard-cable-cutters/cable-cutter",
    imageUrl: "/images/gear/klein-63050.jpg",
    usaMade: true,
    usaMadeSource: "Klein Tools manufactures the majority of its hand tools in U.S. plants, including this cable cutter.",
  },
  {
    category: "Tools and supplies",
    name: "Scotch Super 33+",
    model: "3/4 in x 66 ft vinyl electrical tape",
    bestFor: "A durable general-purpose tape for electrical insulation and harness finishing.",
    note: "Use the approved splice or termination method; tape is not a substitute for it.",
    amazonUrl: "https://www.amazon.com/dp/B01N3D2AFK?tag=beckify-20",
    manufacturerUrl: "https://www.scotchbrand.com/3M/en_US/p/d/b10014694/",
    imageUrl: "/images/gear/scotch-33-plus.jpg",
    usaMade: true,
    usaMadeSource: "3M manufactures Scotch Super 33+ electrical tape in the United States.",
  },
  {
    category: "Tools and supplies",
    name: "CHANNELLOCK 338CB",
    model: "8 in high-leverage diagonal cutting pliers",
    bestFor: "General cutting where durable, comfortable hand pliers are needed.",
    note: "Not an insulated tool or a substitute for an approved cable cutter.",
    amazonUrl: "https://www.amazon.com/dp/B00004SBDD?tag=beckify-20",
    manufacturerUrl: "https://www.channellock.com/product/338cb/",
    imageUrl: "/images/gear/channellock-338cb.jpg",
    usaMade: true,
    usaMadeSource: "CHANNELLOCK manufactures pliers in Meadville, Pennsylvania.",
  },
];

export const USA_MADE_GEAR = GEAR_RECOMMENDATIONS.filter((item) => item.usaMade);

export const USA_MADE_BRANDS = [
  { name: "Klein Tools", note: "Hand tools and strippers from U.S. plants" },
  { name: "CHANNELLOCK", note: "Pliers forged in Meadville, Pennsylvania" },
  { name: "Daniels Manufacturing", note: "Aerospace crimp tools built in Florida" },
  { name: "3M Scotch", note: "Super 33+ tape made in the United States" },
] as const;

export const MADE_IN_AMERICA_FAQ = [
  {
    question: "What electrical tools are made in America?",
    answer:
      "American-made electrical hand tools include Klein strippers and cable cutters, CHANNELLOCK pliers, Daniels crimp frames, and 3M Scotch Super 33+ tape. This guide lists verified model numbers with direct manufacturer links so you can confirm origin before buying.",
  },
  {
    question: "How do you verify a product is American-made?",
    answer:
      "We only list items where the manufacturer publicly identifies U.S. manufacturing for that specific product line. Check the product page, packaging country-of-origin label, and manufacturer’s American manufacturing statement. A U.S. brand name alone is not enough.",
  },
  {
    question: "Are Klein Tools made in the USA?",
    answer:
      "Most Klein hand tools — pliers, cutters, strippers, and similar forged tools — are manufactured in U.S. plants. Klein also sells test equipment and accessories that may be sourced globally, so verify the specific model before assuming U.S. origin.",
  },
  {
    question: "Why isn’t every recommended tool on this list?",
    answer:
      "This is a conservative, field-tested shortlist — not a directory of every American-made electrical product. We prioritize tools electricians actually use daily and only include items we can trace to a clear U.S. manufacturing claim.",
  },
] as const;
