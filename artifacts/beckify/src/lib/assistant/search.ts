export type AssistantDocument = { id: string; title: string; description: string; href: string; tags: string[]; concepts: string[]; kind: "tool" | "page" | "reference" };
export type SearchResult = AssistantDocument & { score: number; matched: string[] };

export const ASSISTANT_DOCUMENTS: AssistantDocument[] = [
  { id: "ohms-law", title: "Ohm's Law", description: "Solve voltage, current, resistance, and power relationships.", href: "/toolbox/#sec-ohm", tags: ["ohms law", "voltage", "current", "resistance", "power", "v i r"], concepts: ["circuit", "fundamentals", "electrical"], kind: "tool" },
  { id: "voltage-drop", title: "Voltage Drop", description: "Check voltage drop for branch circuits, feeders, and long runs.", href: "/toolbox/#sec-vdrop", tags: ["voltage drop", "feeder", "branch", "wire", "awg", "distance"], concepts: ["conductor sizing", "loss", "circuit"], kind: "tool" },
  { id: "conduit-fill", title: "Conduit Fill", description: "Calculate raceway fill for conductors and conduit types.", href: "/toolbox/#sec-conduit", tags: ["conduit fill", "emt", "raceway", "conductors", "chapter 9", "40 percent"], concepts: ["installation", "conduit", "nec"], kind: "tool" },
  { id: "wire-size", title: "Wire Size & Ampacity", description: "Select conductors using ampacity, derating, termination temperature, and voltage drop.", href: "/toolbox/#sec-wire-select", tags: ["wire size", "ampacity", "awg", "derating", "310.16", "termination"], concepts: ["conductor sizing", "safety", "nec"], kind: "tool" },
  { id: "transformer", title: "Transformer Sizing", description: "Select transformer size, primary and secondary protection, and conductor options.", href: "/toolbox/#sec-xfmr-size", tags: ["transformer", "kva", "primary", "secondary", "450.3"], concepts: ["power systems", "distribution", "protection"], kind: "tool" },
  { id: "tdr", title: "Megger TDR Trace Analyzer", description: "Analyze TDR screen values and locate open or short cable faults.", href: "/toolbox/#sec-tdr", tags: ["megger", "tdr", "cable", "open", "short", "fault locating", "velocity factor"], concepts: ["field test", "fault locating", "reflection"], kind: "tool" },
  { id: "panel-power-study", title: "Panel Schedule Power Study", description: "OCR a panel schedule image, review metadata and circuits, and calculate demand, diversity, and expansion room.", href: "/toolbox/#sec-panel-power-study", tags: ["panel schedule", "ocr", "breaker", "series", "poles", "circuit class", "main rating", "positions", "demand factor", "diversity factor"], concepts: ["power study", "panel analysis", "load planning"], kind: "tool" },
  { id: "control-systems", title: "Control System Toolbox", description: "Interactive system modeling, Bode plots, root locus, PID tuning, LQR/LQG design, and MPC visualizers.", href: "/control-systems", tags: ["control systems", "bode", "root locus", "pid", "lqr", "kalman", "mpc", "state space"], concepts: ["feedback", "dynamics", "stability", "optimal control"], kind: "page" },
  { id: "projects", title: "Projects & Build Logs", description: "Hands-on engineering builds, including the Vespa P200E EV conversion.", href: "/projects", tags: ["build", "project", "vespa", "electric vehicle", "battery"], concepts: ["fabrication", "prototype", "engineering"], kind: "page" },
  { id: "vespa", title: "Vespa P200E EV Conversion", description: "A 72 V 20S10P electric Vespa build with a custom swingarm and hub motor.", href: "/projects/vespa-p200e", tags: ["vespa", "p200e", "72v", "20s10p", "hub motor", "swingarm"], concepts: ["electric vehicle", "battery", "fabrication"], kind: "page" },
  { id: "games", title: "Beckify Games", description: "Play Cosmic Cadet, Pup Planet, HexGL, Finger Runner, and other browser games.", href: "/games", tags: ["games", "cosmic cadet", "finger runner", "space shooter", "runner", "pup planet", "hexgl", "webgl"], concepts: ["arcade", "play", "webgl"], kind: "page" },
  { id: "booty-butt-scooter", title: "Booty Butt Scooter", description: "Crossy-style scooter hopper starring Apollo and Rocco, with fart boosts and traffic dodges.", href: "/games/booty-butt-scooter", tags: ["booty butt scooter", "apollo", "rocco", "scooter", "crossy", "fart boost"], concepts: ["arcade", "runner", "play"], kind: "page" },
  { id: "finger-runner", title: "Finger Runner", description: "Jump over hazards in a quick, touch-friendly endless runner.", href: "/games/finger-runner", tags: ["finger runner", "runner", "jump", "arcade", "touch"], concepts: ["arcade", "reflexes", "play"], kind: "page" },
  { id: "pup-planet", title: "Pup Planet", description: "Play as Apollo or Rocco, the space pups, mining and building on a seeded planet in this first-person WebGL sandbox.", href: "/games/pup-planet", tags: ["pup planet", "apollo", "rocco", "voxel", "sandbox", "build", "mine", "block", "webgl", "first person", "ipad"], concepts: ["sandbox", "building", "play", "webgl"], kind: "page" },
  { id: "hexgl", title: "HexGL", description: "Futuristic WebGL racing game by Thibaut Despoulain (BKcore), MIT licensed.", href: "/games/hexgl", tags: ["hexgl", "racing", "webgl", "bkcore", "racer"], concepts: ["racing", "webgl", "play"], kind: "page" },
  { id: "gear", title: "Recommended Electrical Test Equipment", description: "Model-specific hand tools, multimeters, clamp meters, insulation testers, oscilloscopes, cable testers, RF gear, and budget picks.", href: "/gear", tags: ["gear", "electrical test equipment", "hand tools", "multimeter", "clamp meter", "insulation tester", "oscilloscope", "rf analyzer", "budget tools"], concepts: ["tools", "field work", "bench work", "measurement"], kind: "reference" },
];

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
