import { TOOLS, TOOL_ALIASES, REFERENCE_TABLES } from "@/data/toolbox-tools.mjs";

export type AssistantDocument = { id: string; title: string; description: string; href: string; tags: string[]; concepts: string[]; kind: "tool" | "page" | "reference" };
export type SearchResult = AssistantDocument & { score: number; matched: string[] };

const STOPWORDS = new Set(["the", "and", "for", "with", "using", "from", "use", "a", "an", "to", "of", "in", "on", "or", "is", "are", "this", "that", "into", "per"]);
const significantWords = (text: string) =>
  Array.from(new Set(text.toLowerCase().split(/[^a-z0-9.]+/).filter((word) => word.length > 2 && !STOPWORDS.has(word))));

/**
 * A handful of the busiest tools get hand-picked synonyms — abbreviations,
 * code references, and field jargon a title/description won't naturally
 * contain (e.g. "310.16" for the ampacity table, "awg" for wire sizing).
 * Everything else is still fully searchable on its title and description
 * alone; this only adds extra ways to find the few tools people search for
 * by a name other than their own.
 */
const EXTRA_TAGS: Record<string, string[]> = {
  "ohms-law": ["ohms law", "v i r"],
  "magnetic-circuit": ["reluctance", "mmf", "flux", "air gap", "fringing", "magnetostatics", "ampere", "magnetic circuit"],
  "transient-circuits": ["rc transient", "rl transient", "rlc transient", "overdamped", "underdamped", "time constant", "source free"],
  "phasor-diagram": ["phasor", "voltage triangle", "current triangle", "polar", "delta wye", "lead lag", "power factor"],
  "voltage-drop": ["feeder", "branch", "wire", "awg", "distance"],
  "conduit-fill": ["emt", "raceway", "chapter 9", "40 percent"],
  "wire-size-ampacity": ["wire size", "ampacity", "awg", "derating", "310.16", "termination"],
  "transformer": ["kva", "primary", "secondary", "450.3", "transformer sizing", "xfmr", "note 1"],
  "transformer-sizing": ["kva", "primary", "secondary", "450.3"],
  "conductors": ["voltage drop", "ampacity", "awg", "310.16", "mv cable", "lighting"],
  "motor": ["fla", "430.248", "430.250", "horsepower"],
  "on-site-power": ["ups", "generator", "hybrid", "bess"],
  "megger-tdr-analyzer": ["megger", "tdr", "cable", "open", "short", "fault locating", "velocity factor"],
  "emp-emc-shielding": ["emp", "emc", "hemp", "faraday", "shielding", "skin depth", "aperture", "cage", "esd", "61000", "62305"],
  "panel-power-study": ["panel schedule", "ocr", "breaker", "series", "poles", "circuit class", "main rating", "positions", "demand factor", "diversity factor"],
  "heater-wizard": ["nichrome", "kanthal", "resistance wire", "wye", "delta", "industrial heater", "duct heater", "immersion heater", "coil", "awg"],
  "solar-wizard": ["solar", "photovoltaic", "pv", "panel tilt", "azimuth", "peak sun hours", "battery storage", "bess", "array sizing", "orientation"],
  "analog-design-workbench": ["op amp", "lead network", "lead compensator", "sallen key", "analog computer"],
  "semiconductor-iv": ["shockley", "diode iv", "bjt", "mosfet", "nmos", "q-point", "square law", "device physics"],
  "fiber-link": ["numerical aperture", "fiber optic", "acceptance angle", "link budget", "palais"],
  "gaussian-beam": ["gaussian beam", "rayleigh range", "beam waist", "confocal", "saleh teich"],
  "lp-optimizer": ["linear programming", "simplex", "feasible region", "blending", "product mix", "operations research"],
  "number-base-converter": ["hex", "hexadecimal", "decimal", "octal", "binary", "radix", "two's complement", "bit field", "nibble"],
  "io-list-generator": ["io list", "i/o list", "ethercat", "beckhoff", "el1819", "plc io", "channel list", "card slot", "io-link", "controllogix", "compactlogix", "et 200sp", "generic io", "instrument takeoff", "tag suffix", "control zone"],
  "signal-scaling": ["4-20ma", "4-20 mA", "signal scaling", "process value", "transmitter", "engineering units", "live zero", "pt100", "raw counts", "4 to 20", "square root", "dp flow"],
  "ebus-budget": ["ebus", "e-bus", "rack current", "el9410", "milliamp budget", "coupler current"],
  "modbus-address": ["modbus", "40001", "400001", "holding register", "function code", "coil address", "pdu"],
  "plc-timer-preset": ["ton", "tof", "rto", "timer preset", "timebase", "plc timer"],
  "pitch-hum-identifier": ["hum", "60 hz", "50 hz", "120 hz", "mains", "pitch", "autocorrelation", "transformer buzz"],
  "audio-spectrum-analyzer": ["fft", "spectrum", "harmonics", "audio analyzer", "hann", "peak hold"],
  "sound-level-meter": ["spl", "dbfs", "a-weighting", "leq", "sound level", "noise meter"],
  "lux-light-meter": ["lux", "light meter", "photometer", "flicker", "led retrofit", "luminance"],
  "nema-wiring": ["nema 5-15", "5-15", "nema 5-20", "nema 6-20", "l5-30", "l14-30", "twist lock", "color code", "200.6", "250.119", "receptacle"],
  "cable-schedule": ["cable schedule", "cable id", "tray", "conductor count", "xlsx"],
  "battery-bank": ["battery bank", "depth of discharge", "lfp", "lifepo4", "agm", "series parallel", "backup duration", "c-rate"],
  "ebike-drivetrain": ["ebike", "e-bike", "sprocket", "torque", "range", "wh per mile", "battery designer"],
  "motor-nameplate": ["motor nameplate", "430.32", "430.52", "fla", "locked rotor", "service factor", "ocr"],
  "building-load": ["load calculation", "nec 220", "220.42", "demand factor", "feeder load", "service load", "worksheet"],
  "load-calculation-worksheet": ["load calculation", "nec 220", "220.42", "220.82", "demand factor", "worksheet"],
  "torque-lookup": ["torque", "lug", "terminal", "ul 486", "in-lb", "tightening torque", "split bolt"],
  "wire-colors": ["wire color", "nec 200.6", "250.119", "110.15", "high-leg", "ul 508a", "yellow interlock", "control panel"],
};

/**
 * The toolbox tool/reference registry (scripts/generate-sitemap.mjs's source
 * of truth) drives this list directly, so a tool can never again exist on
 * the site without being searchable — previously this file hand-maintained
 * its own copy that drifted to 8 of 44 real tools.
 */
const TOOL_DOCUMENTS: AssistantDocument[] = [
  ...TOOLS.map(([slug, title, description, anchor]) => ({
    id: slug,
    title,
    description,
    href: `/toolbox/#${anchor}`,
    tags: [...significantWords(title), ...(EXTRA_TAGS[slug] ?? [])],
    concepts: significantWords(description).slice(0, 8),
    kind: "tool" as const,
  })),
  ...TOOL_ALIASES.map(([slug, title, description, anchor]) => ({
    id: slug,
    title,
    description,
    href: `/toolbox/#${anchor}`,
    tags: [...significantWords(title), ...(EXTRA_TAGS[slug] ?? [])],
    concepts: significantWords(description).slice(0, 8),
    kind: "tool" as const,
  })),
];

const REFERENCE_DOCUMENTS: AssistantDocument[] = REFERENCE_TABLES.map(([slug, title, description, anchor]) => ({
  id: slug,
  title,
  description,
  href: `/toolbox/#${anchor}`,
  tags: Array.from(new Set([...significantWords(title), ...(EXTRA_TAGS[slug] ?? [])])),
  concepts: significantWords(description).slice(0, 8),
  kind: "reference" as const,
}));

/** Pages outside the toolbox registry: the rest of the Beckify site. */
const PAGE_DOCUMENTS: AssistantDocument[] = [
  { id: "control-systems", title: "Control System Toolbox", description: "Undergraduate servo analysis: plant modeling, open- vs closed-loop P control, root locus, lead compensators, PID with Ziegler–Nichols and anti-windup, Bode GM/PM/ωb, and state-feedback pole placement.", href: "/control-systems", tags: ["control systems", "bode", "root locus", "pid", "lqr", "kalman", "mpc", "state space", "lead compensator", "ziegler nichols", "anti-windup", "type number", "kv", "phase margin", "pole placement"], concepts: ["feedback", "dynamics", "stability", "optimal control", "compensator"], kind: "page" },
  { id: "battery-designer", title: "Battery Pack Designer", description: "Beckify visual pack layout for e-bike and custom lithium builds: paint cells into series groups, hit a parallel target, inspect the pack in 3D, and read live voltage, capacity, energy, and C-rate.", href: "/toolbox/#sec-ebike-tools", tags: ["battery designer", "battery pack designer", "pack layout", "series parallel", "cell layout", "ebike battery", "e-bike pack", "18650 layout", "21700", "3d"], concepts: ["battery", "pack layout", "e-bike", "cells", "3d"], kind: "page" },
  { id: "projects", title: "Projects & Build Logs", description: "Hands-on engineering builds, including the Vespa P200E EV conversion.", href: "/projects", tags: ["build", "project", "vespa", "electric vehicle", "battery"], concepts: ["fabrication", "prototype", "engineering"], kind: "page" },
  { id: "vespa", title: "Vespa P200E EV Conversion", description: "A 72 V 20S10P electric Vespa build with a custom swingarm and hub motor.", href: "/projects/vespa-p200e", tags: ["vespa", "p200e", "72v", "20s10p", "hub motor", "swingarm"], concepts: ["electric vehicle", "battery", "fabrication"], kind: "page" },
  { id: "games", title: "Beckify Games", description: "Play Cosmic Cadet, Pup Planet, Finger Runner, Toot Troopers, New Glenn Runner, Apollo & Rocco Run, and other browser games.", href: "/games", tags: ["games", "cosmic cadet", "finger runner", "space shooter", "runner", "pup planet", "webgl", "toot troopers", "new glenn", "apollo rocco run"], concepts: ["arcade", "play", "webgl"], kind: "page" },
  { id: "booty-butt-scooter", title: "Booty Butt Scooter", description: "Crossy-style scooter hopper with cartoon riders Blaze and Spark, fart boosts, and traffic dodges.", href: "/games/booty-butt-scooter", tags: ["booty butt scooter", "blaze", "spark", "scooter", "crossy", "fart boost"], concepts: ["arcade", "runner", "play"], kind: "page" },
  { id: "apollo-rocco-run", title: "Apollo & Rocco Run", description: "Original Beckify backyard runner with cartoon heroes Blaze and Spark. Three-lane trail with jump, slide, and a local best on this device.", href: "/games/apollo-rocco-run", tags: ["apollo rocco run", "balloon run", "blaze", "spark", "runner", "jump", "slide", "kid", "cadet"], concepts: ["arcade", "runner", "play"], kind: "page" },
  { id: "finger-runner", title: "Finger Runner", description: "Jump over hazards in a quick, touch-friendly endless runner.", href: "/games/finger-runner", tags: ["finger runner", "runner", "jump", "arcade", "touch"], concepts: ["arcade", "reflexes", "play"], kind: "page" },
  { id: "pup-planet", title: "Pup Planet", description: "Play as Blaze or Spark, mining and building on a seeded planet in this first-person WebGL sandbox.", href: "/games/pup-planet", tags: ["pup planet", "blaze", "spark", "voxel", "sandbox", "build", "mine", "block", "webgl", "first person", "ipad"], concepts: ["sandbox", "building", "play", "webgl"], kind: "page" },
  { id: "new-glenn-runner", title: "New Glenn Runner", description: "A stylized vertical launch arcade with KID, CADET, and PAD RAT difficulty and local scoring.", href: "/games/new-glenn-runner", tags: ["new glenn", "runner", "arcade", "launch", "kid", "cadet", "pad rat"], concepts: ["arcade", "runner", "play"], kind: "page" },
  { id: "gear", title: "Recommended Electrical Test Equipment", description: "Model-specific hand tools, multimeters, clamp meters, insulation testers, oscilloscopes, cable testers, RF gear, and budget picks.", href: "/gear", tags: ["gear", "electrical test equipment", "hand tools", "multimeter", "clamp meter", "insulation tester", "oscilloscope", "rf analyzer", "budget tools"], concepts: ["tools", "field work", "bench work", "measurement"], kind: "reference" },
  { id: "made-in-america", title: "American-Made Electrical Tools & Supplies", description: "Verified made-in-America electrical hand tools — Klein strippers, CHANNELLOCK pliers, Daniels crimp frames, and 3M Scotch tape with exact model numbers and sourcing notes.", href: "/made-in-america", tags: ["made in america", "american made", "usa made", "usa-made", "domestic", "klein tools", "channellock", "american manufacturing", "buy american"], concepts: ["sourcing", "hand tools", "field work", "domestic manufacturing"], kind: "reference" },
];

export const ASSISTANT_DOCUMENTS: AssistantDocument[] = [...TOOL_DOCUMENTS, ...REFERENCE_DOCUMENTS, ...PAGE_DOCUMENTS];

const tokenize = (value: string) => value.toLowerCase().split(/[^a-z0-9.]+/).filter(Boolean);
const vector = (value: string) => new Set(tokenize(value));
const similarity = (a: Set<string>, b: Set<string>) => { let shared = 0; a.forEach((token) => { if (b.has(token)) shared += 1; }); return shared / Math.sqrt(Math.max(1, a.size * b.size)); };

export function searchAssistant(query: string, limit = 6): SearchResult[] {
  const terms = tokenize(query); const queryVector = vector(query); if (!terms.length) return ASSISTANT_DOCUMENTS.slice(0, limit).map((doc) => ({ ...doc, score: 0, matched: [] }));
  return ASSISTANT_DOCUMENTS.map((doc) => {
    const corpus = tokenize(`${doc.title} ${doc.description} ${doc.tags.join(" ")}`); const counts = new Map(corpus.map((term) => [term, corpus.filter((item) => item === term).length]));
    const lexical = terms.reduce((score, term) => score + (counts.get(term) ? 1.4 + Math.log1p(counts.get(term)!) : 0), 0);
    const semantic = similarity(queryVector, vector(`${doc.concepts.join(" ")} ${doc.description}`)) * 3;
    const matched = doc.tags.filter((tag) => terms.some((term) => tag.includes(term) || term.includes(tag)));
    return { ...doc, score: lexical + semantic, matched };
  }).filter((result) => result.score > 0).sort((a, b) => b.score - a.score).slice(0, limit);
}
