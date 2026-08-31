import { ExternalLink } from "lucide-react";
import { useMemo, useState } from "react";
import { FadeIn } from "@/components/FadeIn";

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
  { category: "Powertrain", name: "QS 10-inch hub motor, 4kW 55H V3", supplier: "QS Motor", price: "$275.00", quantity: 1, image: `${project}/journal/hub-motor.jpg`, alt: "QS hub motor fitted to the Vespa wheel", caption: "Direct-drive motor used in the conversion." },
  { category: "Powertrain", name: "VOTOL EM-100 controller, 72V / 100A", supplier: "QS Motor", price: "$130.00", quantity: 1, image: `${project}/studio/controller-install.jpg`, alt: "VOTOL controller installed in the Vespa rear bay", caption: "Controller installed with protected cable routing." },
  { category: "Powertrain", name: "ZEVA Smart Precharger", supplier: "EV West", price: "$58.00", quantity: 1, href: "https://www.evwest.com/catalog/product_info.php?products_id=299", caption: "Precharge belongs in the protected high-voltage control path." },
  { category: "Powertrain", name: "Contactor EMC-135", supplier: "TTI", price: "$89.47", quantity: 1, href: "https://www.tti.com/content/ttiinc/en/apps/part-detail.html?partsNumber=2138622-1&mfgShortname=TYC&utm=ga-shop1&channel=ppc&source=google&campaigns=tti-products", caption: "Main contactor is part of the guarded traction circuit." },
  { category: "Battery", name: "Samsung INR18650-25R cells", supplier: "EV West", price: "$330.00 / case", quantity: 2, href: "https://www.evwest.com/catalog/product_info.php?cPath=4&products_id=523", image: `${project}/journal/cell-stack.jpg`, alt: "Blue 18650 cells in battery holders", caption: "200 cells configure the 20S10P pack." },
  { category: "Battery", name: "18650 cell spacers, 10-cell", supplier: "Amazon", price: "$16.99", quantity: 2, href: "https://www.amazon.com/gp/product/B08CT3XXY6/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", image: `${project}/cell-layout.jpg`, alt: "Black cell spacers laid out for an 18650 battery pack", caption: "Spacers maintain cell position and working clearance." },
  { category: "Battery", name: "18650 insulating rings, 300 pack", supplier: "Amazon", price: "$8.88", quantity: 1, href: "https://www.amazon.com/gp/product/B07H6TF58L/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", caption: "Positive-terminal insulation is a small but essential detail." },
  { category: "Battery", name: "Pure nickel strip, 0.2 × 8mm", supplier: "Amazon", price: "$17.99", quantity: 1, href: "https://www.amazon.com/gp/product/B07P3ZCJXT/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", image: `${project}/journal/nickel-busbars.jpg`, alt: "Nickel strip busbars spot welded across battery cells", caption: "0.2 × 8mm pure nickel interconnects the cell groups." },
  { category: "Battery", name: "84V 3A 20S lithium-ion charger", supplier: "Amazon", price: "$58.00", quantity: 1, href: "https://www.amazon.com/gp/product/B07R33QHD4/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", caption: "A 20S charger must terminate at the pack's chemistry-correct voltage." },
  { category: "Electrical", name: "DZ47-125 2P circuit breaker", supplier: "Amazon", price: "$25.29", quantity: 1, href: "https://www.amazon.com/gp/product/B07QWWPXLZ/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", caption: "A serviceable breaker makes isolation and troubleshooting safer." },
  { category: "Electrical", name: "DROK 0–90V / 100A power meter", supplier: "Amazon", price: "$32.69", quantity: 1, href: "https://www.amazon.com/gp/product/B08JB5NQ4B/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", caption: "Use a meter to observe pack voltage and current during testing." },
  { category: "Electrical", name: "2–4 gauge quick-disconnect connector", supplier: "Amazon", price: "$16.99", quantity: 1, href: "https://www.amazon.com/gp/product/B01KHQR0K4/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", caption: "The main connector provides a positive, serviceable pack disconnect." },
  { category: "Electrical", name: "12V 40A automotive relay and socket", supplier: "Amazon", price: "$8.99", quantity: 1, href: "https://www.amazon.com/gp/product/B074T77LPQ/ref=ppx_yo_dt_b_asin_title_o08_s00?ie=UTF8&psc=1", caption: "Relay logic keeps accessory switching separate from traction power." },
  { category: "Chassis", name: "MMG 3.50-10 tubeless street tire set", supplier: "Amazon", price: "$68.90", quantity: 1, href: "https://www.amazon.com/gp/product/B01N9I5TL9/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1", image: `${project}/studio/rear-hub-detail.jpg`, alt: "Rear wheel and tire fitted around the hub motor and disc brake", caption: "Street tire fitted to the motorized rear wheel." },
  { category: "Chassis", name: "Vespa engine main bolt, M14 × 240", supplier: "Scooter Speed", price: "$15.99", quantity: 1, href: "https://scooter-speed.com/vespa-engine-bolt-main-m14x240-fa-italia-c41-87500000/", caption: "Main pivot hardware is selected around the fabricated rear structure." },
];

const categories = ["All", "Powertrain", "Battery", "Electrical", "Chassis"] as const;

function PartIllustration({ part }: { part: CatalogPart }) {
  const label = part.name.includes("Precharger") ? "PRE" : part.name.includes("Contactor") ? "HV" : part.name.includes("rings") ? "18650" : part.name.includes("charger") ? "84V" : part.name.includes("breaker") ? "2P" : part.name.includes("meter") ? "V/A" : part.name.includes("connector") ? "DC" : part.name.includes("relay") ? "12V" : "M14";
  return <div className="part-card-illustration" role="img" aria-label={`${part.name} technical reference illustration`}><svg viewBox="0 0 320 200" aria-hidden="true"><rect x="57" y="40" width="206" height="120" rx="12" fill="none" stroke="currentColor" strokeWidth="3" /><path d="M86 100h148M160 67v66" stroke="currentColor" strokeWidth="3" /><circle cx="96" cy="70" r="9" fill="none" stroke="currentColor" strokeWidth="3" /><circle cx="224" cy="130" r="9" fill="none" stroke="currentColor" strokeWidth="3" /></svg><strong>{label}</strong><span>Technical reference</span></div>;
}

export function VespaPartsCatalog() {
  const [filter, setFilter] = useState<(typeof categories)[number]>("All");
  const shown = useMemo(() => filter === "All" ? catalog : catalog.filter((part) => part.category === filter), [filter]);

  return <FadeIn><><style>{`.vespa-journal section:has(.at-glance) .section-index,#comparison .section-index,#battery-wiring .section-index,#theoretical-comparison .section-index,#top-speed .section-index,#motor-guide .section-index,#engineering .section-index,#safety .section-index,#parts .section-index{font-size:0}.vespa-journal section:has(.at-glance) .section-index:after{content:"07 / build at a glance"}#comparison .section-index:after{content:"08 / stock and converted"}#battery-wiring .section-index:after{content:"09 / wiring reference"}#theoretical-comparison .section-index:after{content:"10 / theoretical comparison"}#top-speed .section-index:after{content:"11 / speed estimate"}#motor-guide .section-index:after{content:"12 / motor guide"}#engineering .section-index:after{content:"13 / engineering notes"}#safety .section-index:after{content:"14 / safe build sequence"}#parts .section-index:after{content:"15 / source list"}.vespa-journal section:has(.at-glance) .section-index:after,#comparison .section-index:after,#battery-wiring .section-index:after,#theoretical-comparison .section-index:after,#top-speed .section-index:after,#motor-guide .section-index:after,#engineering .section-index:after,#safety .section-index:after,#parts .section-index:after{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.64rem;font-weight:700;letter-spacing:.1em;text-transform:uppercase}.part-card-illustration{display:grid;place-content:center;min-height:12.5rem;color:#f6f1e8;text-align:center;background:linear-gradient(135deg,#1d2421,#315247)}.part-card-illustration svg{width:8rem;height:5rem;margin:auto}.part-card-illustration strong{font-family:Georgia,serif;font-size:1.7rem;line-height:1}.part-card-illustration span{margin-top:.45rem;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.58rem;font-weight:700;letter-spacing:.09em;text-transform:uppercase}`}</style><section className="journal-section parts-catalog" id="parts" aria-labelledby="parts-catalog-title">
    <div className="section-heading"><p className="section-index">11 / source list</p><h2 id="parts-catalog-title">Parts, shown in context.</h2><p>An image-led BOM makes the purchasing list easier to scan: select a system, identify the component in the build, then follow its exact supplied vendor link.</p></div>
    <p className="affiliate-note">Affiliate disclosure: some outbound product links may earn Beckify a commission if you make a qualifying purchase, at no extra cost to you.</p>
    <div className="part-filter" aria-label="Filter parts by system">{categories.map((category) => <button key={category} type="button" onClick={() => setFilter(category)} aria-pressed={filter === category}>{category}</button>)}</div>
    <div className="parts-catalog-grid">{shown.map((part) => <article className="part-card" key={part.name}>
      <div className="part-card-image">{part.image ? <img src={part.image} alt={part.alt ?? part.name} loading="lazy" /> : <PartIllustration part={part} />}<span>{part.category}</span></div>
      <div className="part-card-body"><p className="part-card-supplier">{part.supplier} · Qty {part.quantity}</p><h3>{part.name}</h3><p className="part-card-caption">{part.caption}</p><div className="part-card-footer"><strong>{part.price}</strong>{part.href ? <a href={part.href} target="_blank" rel="sponsored noopener noreferrer">View part <ExternalLink size={15} aria-hidden="true" /></a> : <span>Purchase link unavailable</span>}</div></div>
    </article>)}</div>
    <p className="photo-caption">Photographs are used only where they show the listed item. Other cards use labeled technical references so a build-system photograph is never mistaken for a product image. Confirm the live supplier listing, fit, voltage, and current ratings before ordering.</p>
  </section></></FadeIn>;
}
