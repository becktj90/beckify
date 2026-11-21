import { ExternalLink } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { FadeIn } from "@/components/FadeIn";

const AMAZON_ASSOCIATE_TAG = "beckify-20";

/** Build a canonical Amazon Special Link from an ASIN in one auditable place. */
export function amazonAffiliateUrl(asin: string) {
  if (!/^[A-Z0-9]{10}$/.test(asin)) {
    throw new Error(`Invalid Amazon ASIN: ${asin}`);
  }
  return `https://www.amazon.com/dp/${asin}?tag=${AMAZON_ASSOCIATE_TAG}`;
}

/** Stable anchor id so the build narrative can link to a part by name. */
export function partSlug(name: string) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

type Category = "Powertrain" | "Battery" | "Electrical" | "Chassis";

type CatalogPart = {
  category: Category;
  name: string;
  supplier: string;
  price: string;
  quantity: number;
  href?: string;
  image?: string;
  alt?: string;
  caption: string;
};

const project = "/projects/vespa";

// Only photos that actually show the listed item are used as photographs. When
// a vendor packshot was not supplied, the card uses a labeled technical
// illustration instead of a misleading subsystem photograph.
const catalog: readonly CatalogPart[] = [
  {
    category: "Powertrain",
    name: "QS 10-inch hub motor, 4kW 55H V3",
    supplier: "QS Motor",
    price: "$275.00",
    quantity: 1,
    image: `${project}/journal/hub-motor.jpg`,
    alt: "QS hub motor fitted to the Vespa wheel",
    href: "https://www.qs-motor.com/product/10inch-4000w-v3-type-e-scooter-hub-motor/",
    caption: "Direct-drive motor used in the conversion.",
  },
  {
    category: "Powertrain",
    name: "VOTOL EM-100 controller, 72V / 100A",
    supplier: "QS Motor",
    price: "$130.00",
    quantity: 1,
    image: `${project}/studio/controller-install.jpg`,
    alt: "VOTOL controller installed in the Vespa rear bay",
    href: "https://www.qsmotor.com/product/votol-controller-em-100/",
    caption: "Controller installed with protected cable routing.",
  },
  {
    category: "Powertrain",
    name: "ZEVA Smart Precharger",
    supplier: "EV West",
    price: "$58.00",
    quantity: 1,
    href: "https://www.evwest.com/catalog/product_info.php?products_id=299",
    caption: "Precharge belongs in the protected high-voltage control path.",
  },
  {
    category: "Powertrain",
    name: "Contactor EMC-135",
    supplier: "TTI",
    price: "$89.47",
    quantity: 1,
    href: "https://www.tti.com/content/ttiinc/en/apps/part-detail.html?partsNumber=2138622-1&mfgShortname=TYC&utm=ga-shop1&channel=ppc&source=google&campaigns=tti-products",
    caption:
      "Main contactor is part of the guarded high-voltage battery circuit.",
  },
  {
    category: "Battery",
    name: "Samsung INR18650-25R cells",
    supplier: "EV West",
    price: "$330.00 / case",
    quantity: 2,
    href: "https://www.evwest.com/catalog/product_info.php?cPath=4&products_id=523",
    image: `${project}/journal/cell-stack.jpg`,
    alt: "Blue 18650 cells in battery holders",
    caption: "200 cells configure the 20S10P pack.",
  },
  {
    category: "Battery",
    name: "18650 cell spacers, 10-cell",
    supplier: "Amazon",
    price: "$16.99",
    quantity: 2,
    href: amazonAffiliateUrl("B08CT3XXY6"),
    image: `${project}/cell-layout.jpg`,
    alt: "Black cell spacers laid out for an 18650 battery pack",
    caption: "Spacers maintain cell position and working clearance.",
  },
  {
    category: "Battery",
    name: "18650 insulating rings, 300 pack",
    supplier: "Amazon",
    price: "$8.88",
    quantity: 1,
    href: amazonAffiliateUrl("B07H6TF58L"),
    caption: "Positive-terminal insulation is a small but essential detail.",
  },
  {
    category: "Battery",
    name: "Pure nickel strip, 0.2 × 8mm",
    supplier: "Amazon",
    price: "$17.99",
    quantity: 1,
    href: amazonAffiliateUrl("B07P3ZCJXT"),
    image: `${project}/journal/nickel-busbars.jpg`,
    alt: "Nickel strip busbars spot welded across battery cells",
    caption: "0.2 × 8mm pure nickel interconnects the cell groups.",
  },
  {
    category: "Battery",
    name: "84V 3A 20S lithium-ion charger",
    supplier: "Amazon",
    price: "$58.00",
    quantity: 1,
    href: amazonAffiliateUrl("B07R33QHD4"),
    caption:
      "A 20S charger must terminate at the pack's chemistry-correct voltage.",
  },
  {
    category: "Electrical",
    name: "DZ47-125 2P circuit breaker — DC suitability unverified",
    supplier: "Installed part; listing withheld",
    price: "$25.29",
    quantity: 1,
    caption:
      "Historical build record only. The former listing was removed because an AC rating does not establish suitability for interrupting this 72V nominal / 84V maximum DC battery pack. Verify the installed device's DC voltage, interrupting rating, polarity requirements, and fault-current coordination before use.",
  },
  {
    category: "Electrical",
    name: "DROK 0–90V / 100A power meter",
    supplier: "Amazon",
    price: "$32.69",
    quantity: 1,
    href: amazonAffiliateUrl("B08JB5NQ4B"),
    caption: "Use a meter to observe pack voltage and current during testing.",
  },
  {
    category: "Electrical",
    name: "2–4 gauge quick-disconnect connector",
    supplier: "Amazon",
    price: "$16.99",
    quantity: 1,
    href: amazonAffiliateUrl("B01KHQR0K4"),
    caption:
      "The main connector provides a positive, serviceable pack disconnect.",
  },
  {
    category: "Electrical",
    name: "12V 40A automotive relay and socket",
    supplier: "Amazon",
    price: "$8.99",
    quantity: 1,
    href: amazonAffiliateUrl("B074T77LPQ"),
    caption:
      "Relay logic keeps accessory switching separate from high-voltage power.",
  },
  {
    category: "Chassis",
    name: "MMG 3.50-10 tubeless street tire set",
    supplier: "Amazon",
    price: "$68.90",
    quantity: 1,
    href: amazonAffiliateUrl("B01N9I5TL9"),
    image: `${project}/studio/rear-hub-detail.jpg`,
    alt: "Rear wheel and tire fitted around the hub motor and disc brake",
    caption: "Street tire fitted to the motorized rear wheel.",
  },
  {
    category: "Chassis",
    name: "Vespa engine main bolt, M14 × 240",
    supplier: "Scooter Speed",
    price: "$15.99",
    quantity: 1,
    href: "https://scooter-speed.com/vespa-engine-bolt-main-m14x240-fa-italia-c41-87500000/",
    caption:
      "Main pivot hardware is selected around the fabricated rear structure.",
  },
  {
    category: "Chassis",
    name: "1979 Vespa P200E",
    supplier: "Piaggio / Revolution Moto",
    price: "$1,300.00",
    quantity: 1,
    caption:
      "The steel donor chassis, bodywork, and visual vocabulary of the project.",
  },
  {
    category: "Powertrain",
    name: "48–72V to 12V, 10A DC-DC converter",
    supplier: "QS Motor",
    price: "$8.00",
    quantity: 1,
    href: "https://www.qsmotor.com/product/dc-dc-convertor/",
    caption:
      "Steps the high-voltage pack down to run 12V lighting and accessories.",
  },
  {
    category: "Chassis",
    name: "QS disc-brake kit",
    supplier: "QS Motor",
    price: "$35.00",
    quantity: 1,
    caption: "Adds disc braking at the hub-motor wheel.",
  },
  {
    category: "Electrical",
    name: "25mm three-wire twist throttle",
    supplier: "eBay",
    price: "$8.73",
    quantity: 1,
    caption: "Sends the rider's demand signal to the controller.",
  },
  {
    category: "Battery",
    name: "Daly Li-ion 20S 72V 100A BMS",
    supplier: "eBay",
    price: "$60.00",
    quantity: 1,
    href: "https://www.dalybms.com/",
    caption: "Monitors series groups and protects the 20S pack.",
  },
  {
    category: "Electrical",
    name: "LED headlight",
    supplier: "eBay",
    price: "$78.39",
    quantity: 1,
    caption:
      "Provides a low-draw headlight suitable for the 12V accessory circuit.",
  },
  {
    category: "Chassis",
    name: "uxcell rear-wheel damper bushings, 26mm OD / 14mm ID",
    supplier: "Amazon",
    price: "$14.28",
    quantity: 1,
    href: amazonAffiliateUrl("B01N760BZN"),
    caption:
      "Pairs of compliant bushings used in the rear-wheel mounting work.",
  },
  {
    category: "Battery",
    name: "Blue 18650 cell wrap, 300 pack",
    supplier: "Amazon",
    price: "$7.88",
    quantity: 1,
    href: amazonAffiliateUrl("B081RPF2G3"),
    caption: "Re-wrap material for individual cylindrical cells.",
  },
  {
    category: "Chassis",
    name: "PVR70 angled tubeless valve stems",
    supplier: "Amazon",
    price: "$5.79",
    quantity: 1,
    href: amazonAffiliateUrl("B08CXN9Q83"),
    caption:
      "Angled valves make pressure checks practical on the 10-inch wheel.",
  },
  {
    category: "Battery",
    name: "Blue 18650 heat-shrink wrap, 300 pack",
    supplier: "Amazon",
    price: "$7.88",
    quantity: 1,
    href: amazonAffiliateUrl("B081RNT8M2"),
    caption: "Additional wrap material for repaired or protected cells.",
  },
  {
    category: "Chassis",
    name: "2-inch square 1008–1010 steel tube, 0.083-inch wall",
    supplier: "Amazon",
    price: "$32.65",
    quantity: 1,
    href: amazonAffiliateUrl("B007WLWPM6"),
    caption: "Structural stock for the fabricated rear swingarm.",
  },
  {
    category: "Chassis",
    name: "1 × 2-inch 1008–1010 rectangular steel tube, 0.120-inch wall",
    supplier: "Amazon",
    price: "$34.98",
    quantity: 1,
    href: amazonAffiliateUrl("B007WLWQDE"),
    caption: "Secondary structural stock for the rear mounting structure.",
  },
  {
    category: "Electrical",
    name: "Six-position DIN-rail fuse distribution module",
    supplier: "Amazon",
    price: "$28.00",
    quantity: 1,
    href: amazonAffiliateUrl("B08PT3PXSB"),
    caption:
      "Distributes and individually protects low-voltage accessory circuits.",
  },
  {
    category: "Battery",
    name: "Zhuvatar portable battery spot welder",
    supplier: "Amazon",
    price: "$58.99",
    quantity: 1,
    href: amazonAffiliateUrl("B091BY3L6L"),
    caption:
      "Joins nickel strip to cell terminals without heating the cell body like soldering.",
  },
  {
    category: "Battery",
    name: "350mm PVC battery-pack heat-shrink tube",
    supplier: "Amazon",
    price: "$18.99",
    quantity: 1,
    href: amazonAffiliateUrl("B07FXWMQJP"),
    caption:
      "Final outer insulation and abrasion layer for the completed pack.",
  },
  {
    category: "Electrical",
    name: "iBrightstar red 1157 LED tail/brake bulbs",
    supplier: "Amazon",
    price: "$16.99",
    quantity: 1,
    href: amazonAffiliateUrl("B01MY4T4BU"),
    caption: "Red LED replacement lamps for the rear running and brake light.",
  },
  {
    category: "Electrical",
    name: "iBrightstar amber 1156 LED signal bulbs",
    supplier: "Amazon",
    price: "$16.99",
    quantity: 1,
    href: amazonAffiliateUrl("B0739RCR3J"),
    caption: "Amber LED replacements for the turn signals.",
  },
  {
    category: "Electrical",
    name: "CEC Industries EF33RL electronic flasher",
    supplier: "Amazon",
    price: "$13.04",
    quantity: 1,
    href: amazonAffiliateUrl("B00JXLHE8S"),
    caption:
      "Keeps indicator cadence correct after the LED lighting conversion.",
  },
  {
    category: "Electrical",
    name: "SoundOriginal 12V waterproof horn kit",
    supplier: "Amazon",
    price: "$8.99",
    quantity: 1,
    href: amazonAffiliateUrl("B072QBNTSM"),
    caption: "Provides a compact 12V audible warning device.",
  },
  {
    category: "Chassis",
    name: "Center-stand hardware kit",
    supplier: "ScooterWest",
    price: "$52.41",
    quantity: 1,
    href: "https://www.scooterwest.com/complete-center-stand-hardware-kit-p-series-vespa.html",
    caption: "Restores the mounting hardware for the reinforced center stand.",
  },
  {
    category: "Chassis",
    name: "Reinforced P200E / P125X / PX150 center stand",
    supplier: "ScooterWest",
    price: "$45.95",
    quantity: 1,
    href: "https://www.scooterwest.com/px-reinforced-center-stand-stella-176160r.html",
    caption:
      "Supports the finished scooter with the conversion's altered rear mass.",
  },
  {
    category: "Chassis",
    name: "Zinc-plated mirror flat brackets",
    supplier: "ScooterWest",
    price: "$7.95",
    quantity: 2,
    href: "https://www.scooterwest.com/vintage-mirror-bracket-flat-zinc-plated-mr-07.html",
    caption: "Mounting brackets for the replacement mirrors.",
  },
  {
    category: "Chassis",
    name: "P125X–P200E–PXE floor-strip set",
    supplier: "ScooterWest",
    price: "$49.95",
    quantity: 1,
    href: "https://www.scooterwest.com/px-stella-floor-strip-set-fs-p.html",
    caption: "Restores the classic aluminum floor-rail finish.",
  },
  {
    category: "Chassis",
    name: "Pair of 12-inch chrome Vespa mirrors",
    supplier: "ScooterWest",
    price: "$45.95",
    quantity: 1,
    href: "https://www.scooterwest.com/mirror-pair-chrome-long-stems-mr-01.html",
    caption: "Restores rearward visibility and the period silhouette.",
  },
  {
    category: "Chassis",
    name: "P200E metal cowl badge emblem",
    supplier: "ScooterWest",
    price: "$10.95",
    quantity: 1,
    href: "https://www.scooterwest.com/p200e-metal-cowl-badge-emblem-181328.html",
    caption: "Replacement badge for the spare-wheel cowl.",
  },
  {
    category: "Chassis",
    name: "Steering and glove-box matching lock set",
    supplier: "ScooterWest",
    price: "$39.95",
    quantity: 1,
    href: "https://www.scooterwest.com/vintage-vespa-steering-glove-box-lock-set-139188.html",
    caption:
      "Refreshes the mechanical locks while retaining the original bodywork.",
  },
  {
    category: "Chassis",
    name: "Front right-hand amber turn-signal assembly",
    supplier: "ScooterWest",
    price: "$22.95",
    quantity: 1,
    href: "https://www.scooterwest.com/front-r-h-turn-signal-assembly-amber-vespa-px-162818.html",
    caption: "Replacement front amber signal assembly.",
  },
  {
    category: "Chassis",
    name: "Ridetech universal shock-tower mount",
    supplier: "JEGS",
    price: "$20.99",
    quantity: 1,
    href: "https://ridetech.com/product/3-sided-upper-shock-bracket/",
    caption:
      "Provides an adaptable starting point for the revised rear shock location.",
  },
];

const categories = [
  "All",
  "Powertrain",
  "Battery",
  "Electrical",
  "Chassis",
] as const;

export function VespaPartsCatalog() {
  const [filter, setFilter] = useState<(typeof categories)[number]>("All");

  // An inline link in the story points at #part-<slug>. If a category filter is
  // active that row may not be rendered, so the anchor would go nowhere — reset
  // to "All" whenever the hash targets a specific part.
  useEffect(() => {
    const showTargetedPart = () => {
      if (window.location.hash.startsWith("#part-")) setFilter("All");
    };
    showTargetedPart();
    window.addEventListener("hashchange", showTargetedPart);
    return () => window.removeEventListener("hashchange", showTargetedPart);
  }, []);

  const shown = useMemo(
    () =>
      filter === "All"
        ? catalog
        : catalog.filter((part) => part.category === filter),
    [filter],
  );

  return (
    <FadeIn>
      <section
        className="journal-section parts-section"
        id="parts"
        aria-labelledby="parts-title"
      >
        <div className="section-heading">
          <p className="section-index">10 / bill of materials</p>
          <h2 id="parts-title">Bill of materials</h2>
          <p>
            Every part used in the build, what each one was for, and where to
            source it. Part names linked in the story above jump to their row
            here. Links are direct vendor URLs or affiliate links where
            available.
          </p>
        </div>
        <p className="affiliate-note">
          As an Amazon Associate I earn from qualifying purchases. Some vendor
          buttons are paid Amazon links; others go to the parts supplier
          directly.
        </p>
        <p className="affiliate-note" style={{ borderColor: "#f0a54a" }}>
          <strong>Battery protection note:</strong> the original DZ47-125
          Amazon listing has been removed. Its published AC rating does not by
          itself establish that it can safely interrupt this battery pack's DC
          fault current. Treat the row as a historical build record until the
          installed device's DC ratings are verified.
        </p>
        <div className="part-filter" aria-label="Filter parts by system">
          {categories.map((category) => (
            <button
              key={category}
              type="button"
              onClick={() => setFilter(category)}
              aria-pressed={filter === category}
            >
              {category}
            </button>
          ))}
        </div>
        {/* Scrolls horizontally on narrow screens, so it needs to be a real
            keyboard stop rather than only mouse/touch scrollable. */}
        <div className="parts-table-wrap" tabIndex={0} role="region" aria-label="Bill of materials table">
          <table>
            <thead>
              <tr>
                <th>Part</th>
                <th>Used for</th>
                <th>Qty</th>
                <th>Build cost (historical)</th>
                <th>
                  <span className="sr-only">Link</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {shown.map((part) => (
                <tr key={part.name} id={`part-${partSlug(part.name)}`}>
                  <td>
                    <strong>{part.name}</strong>
                    <small>{part.supplier}</small>
                  </td>
                  <td>{part.caption}</td>
                  <td>{part.quantity}</td>
                  <td>
                    {part.supplier === "Amazon" ? (
                      <span className="unavailable">See retailer</span>
                    ) : (
                      part.price
                    )}
                  </td>
                  <td>
                    {part.href ? (
                      <a
                        href={part.href}
                        target="_blank"
                        rel={part.href.includes("amazon.com") ? "sponsored noopener noreferrer" : "noopener noreferrer"}
                      >
                        {part.href.includes("amazon.com")
                          ? "Amazon (paid link)"
                          : "View supplier"}{" "}
                        <ExternalLink size={14} aria-hidden="true" />
                      </a>
                    ) : (
                      <span className="unavailable">Not linked</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="photo-caption" style={{ marginTop: "1.25rem" }}>
          Non-Amazon amounts are historical build costs, not current price
          quotes. Amazon prices are intentionally shown only by Amazon. Confirm
          every live listing, fit, voltage, and current rating before ordering.
        </p>
      </section>
    </FadeIn>
  );
}
