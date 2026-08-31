import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const siteUrl = "https://beckify.com";
const tools = [
  ["voltage-drop", "Voltage Drop Calculator", "Calculate feeder and branch-circuit voltage drop for single-phase and three-phase electrical runs.", "sec-vdrop"],
  ["transformer-sizing", "Transformer Sizing Calculator", "Select transformer size, primary and secondary protection, and practical conductor options for electrical loads.", "sec-xfmr-size"],
  ["conductor-length-resistance", "Conductor Length by Resistance", "Estimate conductor length from measured resistance with copper and aluminum temperature compensation.", "sec-conductor-length"],
  ["ohms-law", "Ohm's Law Calculator", "Solve voltage, current, resistance, and power relationships for DC and resistive AC circuits.", "sec-ohm"],
  ["dc-power", "DC Power Calculator", "Calculate voltage, current, resistance, and watts for a direct-current electrical circuit.", "sec-power-dc"],
  ["power-wizard", "AC and DC Power Wizard", "Solve real power, reactive power, apparent power, current, and motor horsepower for DC, single-phase, and three-phase systems.", "sec-power-wizard"],
  ["reactance-impedance", "Reactance and Impedance Calculator", "Calculate capacitive reactance, inductive reactance, and impedance for AC circuits.", "sec-reactance"],
  ["resonance", "RLC Resonance Calculator", "Find resonant frequency and related values for series and parallel LC circuits.", "sec-resonance"],
  ["power-factor-correction", "Power Factor Correction Calculator", "Estimate correction capacitance and improved power factor for AC loads.", "sec-pfc"],
  ["series-parallel", "Series and Parallel Calculator", "Combine resistance, capacitance, or inductance values in series and parallel networks.", "sec-sp"],
  ["motor-calculations", "Motor Calculations", "Estimate motor current, horsepower, efficiency, and power relationships for field calculations.", "sec-motor"],
  ["transformer", "Transformer Calculator", "Calculate transformer current, turns ratio, and voltage relationships for common configurations.", "sec-xfmr"],
  ["transformer-engine", "Transformer Conductor Selection Engine", "Work through transformer conductors, OCPD, grounding, voltage drop, and conduit selection.", "sec-xfmr-engine"],
  ["conduit-fill", "Conduit Fill Calculator", "Check conductor count and raceway fill using electrical conductor and conduit areas.", "sec-conduit"],
  ["conduit-fill-mixed", "Mixed Conduit Fill Calculator", "Calculate raceway fill for mixed conductor sizes and common EMT, PVC, IMC, and RMC systems.", "sec-conduit-adv"],
  ["wire-size-ampacity", "Wire Size and Ampacity Calculator", "Select conductors using ampacity, derating, termination temperature, and voltage drop constraints.", "sec-wire-select"],
  ["conductor-cost-optimizer", "Conductor Cost Optimizer", "Compare compliant conductor sizes and parallel runs using average or manual material pricing to find the lowest modeled cost.", "sec-wire-select"],
  ["short-circuit", "Short-Circuit Current Calculator", "Estimate available fault current and interrupting requirements for electrical distribution systems.", "sec-sc"],
  ["ups-sizing", "UPS Sizing Calculator", "Estimate UPS capacity and runtime requirements from connected electrical loads.", "sec-ups"],
  ["generator-sizing", "Generator Sizing Calculator", "Estimate generator capacity from motor, continuous, and mixed electrical loads.", "sec-gen"],
  ["hybrid-generator", "Hybrid Generator Calculator", "Explore generator and battery load-sharing options for resilient power systems.", "sec-hybrid"],
  ["ebike-drivetrain", "E-Bike Drivetrain Calculator", "Calculate e-bike torque, RPM, sprocket ratios, wheel speed, and drivetrain performance.", "sec-ebike-tools"],
  ["nec-circuit", "NEC Circuit Calculator", "Size branch-circuit conductors and overcurrent protection using practical NEC-based inputs.", "sec-nec"],
  ["lighting-voltage-drop", "Lighting Voltage Drop Optimizer", "Compare conductor options and voltage drop for lighting circuits and long branch runs.", "sec-lighting-opt"],
  ["building-load", "Building Load Calculator", "Estimate building electrical load from connected, continuous, and demand load inputs.", "sec-bldg-load"],
  ["load-factors-capacity", "Load Factors and Capacity Calculator", "Calculate demand, diversity, coincidence, load, and capacity-utilization factors from known electrical load data.", "sec-load-factors"],
  ["lsi-breaker", "LSI Breaker Visualizer", "Explore long-time, short-time, and instantaneous breaker protection settings visually.", "sec-lsi"],
  ["bess-peak-shave", "BESS Peak-Shave Calculator", "Model battery energy storage peak shaving and demand reduction for facility loads.", "sec-bess"],
  ["tap-changer", "Tap-Changer Calculator", "Calculate transformer tap changes and resulting secondary voltage adjustments.", "sec-tap"],
  ["harmonics", "Harmonics Tool", "Review harmonic distortion and practical electrical power-quality relationships.", "sec-harmonics"],
  ["hazardous-area", "Hazardous Area Lookup", "Reference hazardous-area classifications and equipment selection concepts for electrical work.", "sec-haz"],
  ["intrinsically-safe-loop", "Intrinsic Safety Loop Verifier", "Check intrinsic-safety loop inputs and identify common instrumentation constraints.", "sec-isloop"],
  ["555-timer", "555 Timer Calculator", "Calculate astable frequency, duty cycle, monostable pulse width, and timing values.", "sec-555"],
  ["unit-conversions", "Electrical Unit Conversions", "Convert common electrical engineering units quickly in the field.", "sec-convert"],
  ["circular-mils", "Circular Mils Calculator", "Calculate conductor area and compare circular-mil values for electrical sizing work.", "sec-cm"],
  ["photometrics", "Photometrics Calculator", "Estimate lighting levels and photometric relationships for practical design checks.", "sec-photometrics"],
  ["digital-logic-workbench", "Digital Logic Workbench", "Build combinational logic diagrams, simulate gate outputs, generate truth tables, and convert Boolean expressions to and from gate diagrams.", "sec-digital"],
  ["analog-design-workbench", "Analog Design Workbench", "Calculate common op-amp stages and design RC, RLC, Sallen-Key, state-variable, notch, band-pass, and all-pass filters with a live response plot.", "sec-analog-design"],
  ["battery-build-designer", "Battery Build Designer", "Plan 18650 series-parallel battery packs, C-rate, grid or honeycomb layouts, and nickel-strip cross-section current estimates.", "sec-battery-build"],
  ["panel-schedule-load-analyzer", "Panel Schedule Load Analyzer", "Extract an editable panel schedule from a photo and estimate circuit demand, panel current, diversity, and capacity.", "sec-panel-schedule"],
  ["megger-tdr-analyzer", "Megger TDR Trace Analyzer", "Analyze a Megger TDR500 screen image for velocity factor, range, impedance, and cable fault reflections.", "sec-tdr"],
  ["smith-chart", "Smith Chart Tool", "Explore transmission-line impedance matching, reflection coefficient, VSWR, and return loss.", "sec-smith-chart"],
  ["transformer-design", "Transformer Design Wizard", "Work through transformer type, kVA, winding, protection, and conductor design choices.", "sec-xfmr-wizard"],
];

const categories = [
  ["fundamentals", "Electrical Fundamentals", "Start with voltage, current, power, resistance, and core circuit relationships.", "sec-ohm"],
  ["ac-circuits", "AC Circuits", "Analyze reactance, impedance, resonance, and power factor in AC networks.", "sec-reactance"],
  ["distribution", "Power Distribution", "Size conductors, transformers, conduit, and protection for electrical distribution systems.", "sec-vdrop"],
  ["power-systems", "Power Systems", "Estimate UPS, generator, hybrid power, and facility load requirements.", "sec-ups"],
  ["nec-calculations", "NEC Calculations", "Use field-focused NEC reference calculators for circuits, ampacity, grounding, and raceway fill.", "sec-nec"],
  ["field-test-fault-locating", "Field Test and Fault Locating", "Use field tools for panel OCR and Megger TDR cable fault locating.", "sec-tdr"],
  ["reference-tables", "Electrical Reference Tables", "Browse conductor, motor, conduit, enclosure, IP rating, and NEC reference information.", "sec-wire-ref"],
];

const escapeXml = (value) => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&apos;");
const page = ({ title, description, path, toolPath, eyebrow = "Beckify Electrical Engineering Toolbox", showAds = true, kind = "tool" }) => {
  const canonicalUrl = `${siteUrl}${path}`;
  const schema = [
    {
      "@context": "https://schema.org",
      "@type": kind === "tool" ? ["SoftwareApplication", "WebApplication"] : "CollectionPage",
      name: title,
      description,
      url: canonicalUrl,
      ...(kind === "tool" ? {
        operatingSystem: "All",
        applicationCategory: "EngineeringApplication",
        isAccessibleForFree: true,
      } : {}),
      publisher: { "@type": "Organization", name: "Beckify", url: siteUrl },
    },
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Beckify", item: siteUrl },
        { "@type": "ListItem", position: 2, name: "Toolbox", item: `${siteUrl}/toolbox/` },
        { "@type": "ListItem", position: 3, name: title, item: canonicalUrl },
      ],
    },
  ];
  const subject = kind === "tool" ? "calculator" : "tool collection";
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeXml(`${title} | Beckify`)}</title><meta name="description" content="${escapeXml(description)}"><meta name="robots" content="index,follow">
<link rel="canonical" href="${canonicalUrl}"><meta property="og:title" content="${escapeXml(`${title} | Beckify`)}"><meta property="og:description" content="${escapeXml(description)}"><meta property="og:type" content="website"><meta property="og:site_name" content="Beckify"><meta property="og:url" content="${canonicalUrl}"><meta property="og:image" content="${siteUrl}/opengraph.jpg"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${escapeXml(`${title} | Beckify`)}"><meta name="twitter:description" content="${escapeXml(description)}"><meta name="twitter:image" content="${siteUrl}/opengraph.jpg">
${showAds ? `<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-5333275222472637" crossorigin="anonymous"></script>` : ""}
<script async src="https://www.googletagmanager.com/gtag/js?id=G-ZVFZ9X595E"></script><script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-ZVFZ9X595E');</script>
<script type="application/ld+json">${JSON.stringify(schema)}</script>
<style>body{margin:0;background:#05060f;color:#eef0fa;font:16px/1.6 system-ui,sans-serif}main{max-width:860px;margin:auto;padding:32px 22px 48px}a{color:#b7abff}h1{font-size:clamp(2rem,5vw,3.5rem);line-height:1.1;margin:.35rem 0 1.1rem}h2{font-size:1.15rem;margin:0 0 .45rem}.eyebrow{color:#9b8cff;text-transform:uppercase;letter-spacing:.12em;font-size:.75rem;font-weight:700}.crumbs{font-size:.86rem;margin-bottom:2.5rem}.intro{font-size:1.12rem;color:#d5d7e8;max-width:720px}.panel{background:#111326;border:1px solid #30304a;border-radius:14px;padding:20px 22px;margin:24px 0}.panel p{margin:.4rem 0;color:#b7bad2;max-width:720px}.cta{display:inline-block;margin:4px 0 0;padding:12px 18px;border-radius:9px;background:#8b7bff;color:#fff;text-decoration:none;font-weight:700}.links{display:flex;gap:18px;flex-wrap:wrap;margin-top:14px;font-size:.93rem}iframe{width:100%;height:720px;border:1px solid #30304a;border-radius:14px;margin-top:22px;background:#111326}</style></head>
<body><main><nav class="crumbs" aria-label="Breadcrumb"><a href="/">Beckify</a> / <a href="/toolbox/">Toolbox</a> / ${escapeXml(title)}</nav><div class="eyebrow">${escapeXml(eyebrow)}</div><h1>${escapeXml(title)}</h1><p class="intro">${escapeXml(description)}</p><section class="panel" aria-labelledby="about-tool"><h2 id="about-tool">About this ${subject}</h2><p>Use this free browser-based ${subject} to work through the relevant electrical inputs, review the result, and compare it with field conditions.</p><p>For design, installation, or safety decisions, verify assumptions against the applicable code edition, equipment documentation, and site requirements.</p><a class="cta" href="${toolPath}">Open the interactive ${kind === "tool" ? "tool" : "collection"}</a><div class="links"><a href="/toolbox/">Browse all electrical tools</a><a href="/sitemap">Browse the Beckify site map</a></div></section><iframe src="/toolbox/index.html#${toolPath.split("#")[1]}" title="${escapeXml(title)}" loading="lazy"></iframe></main></body></html>`;
};

const urls = [
  ["/", "weekly", "1.0"], ["/about", "monthly", "0.7"], ["/games", "weekly", "0.7"], ["/games/cosmic-cadet", "monthly", "0.7"], ["/games/booty-butt-scooter", "monthly", "0.7"], ["/games/finger-runner", "monthly", "0.7"], ["/games/toot-troopers", "monthly", "0.7"], ["/games/pup-planet", "monthly", "0.7"], ["/games/hexgl", "monthly", "0.7"], ["/projects", "weekly", "0.8"], ["/projects/vespa-p200e", "monthly", "0.8"], ["/gear", "weekly", "0.9"], ["/toolbox/", "weekly", "1.0"], ["/sitemap", "monthly", "0.7"],
  ...categories.map(([slug], index) => [`/toolbox/category/${slug}/`, index === 5 ? "weekly" : "monthly", "0.8"]),
  ...tools.map(([slug], index) => [`/toolbox/${slug}/`, index === 36 ? "weekly" : "monthly", index === 36 ? "0.9" : "0.8"]),
];
const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map(([path, changefreq, priority]) => `  <url>\n    <loc>${escapeXml(`${siteUrl}${path}`)}</loc>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`).join("\n")}\n</urlset>\n`;
await writeFile(resolve(root, "public/sitemap.xml"), xml);

if (process.argv.includes("--dist")) {
  const output = resolve(root, "dist/public");
  await writeFile(resolve(output, "sitemap.xml"), xml);
  for (const [slug, title, description, anchor] of tools) {
    const directory = resolve(output, "toolbox", slug);
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "index.html"), page({ title, description, path: `/toolbox/${slug}/`, toolPath: `/toolbox/#${anchor}`, showAds: !["smith-chart", "lsi-breaker"].includes(slug) }));
  }
  for (const [slug, title, description, anchor] of categories) {
    const directory = resolve(output, "toolbox/category", slug);
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "index.html"), page({ title, description, path: `/toolbox/category/${slug}/`, toolPath: `/toolbox/#${anchor}`, eyebrow: "Beckify Toolbox Category", kind: "category" }));
  }
}
