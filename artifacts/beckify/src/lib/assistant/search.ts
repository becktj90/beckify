export type AssistantDocument = { id: string; title: string; description: string; href: string; tags: string[]; concepts: string[]; kind: "tool" | "page" | "reference" };
export type SearchResult = AssistantDocument & { score: number; matched: string[] };

export const ASSISTANT_DOCUMENTS: AssistantDocument[] = [
  { id: "ohms-law", title: "Ohm's Law", description: "Solve voltage, current, resistance, and power relationships.", href: "/toolbox/#sec-ohm", tags: ["ohms law", "voltage", "current", "resistance", "power", "v i r"], concepts: ["circuit", "fundamentals", "electrical"], kind: "tool" },
  { id: "voltage-drop", title: "Voltage Drop", description: "Check voltage drop for branch circuits, feeders, and long runs.", href: "/toolbox/#sec-vdrop", tags: ["voltage drop", "feeder", "branch", "wire", "awg", "distance"], concepts: ["conductor sizing", "loss", "circuit"], kind: "tool" },
  { id: "conduit-fill", title: "Conduit Fill", description: "Calculate raceway fill for conductors and conduit types.", href: "/toolbox/#sec-conduit", tags: ["conduit fill", "emt", "raceway", "conductors", "chapter 9", "40 percent"], concepts: ["installation", "conduit", "nec"], kind: "tool" },
  { id: "wire-size", title: "Wire Size & Ampacity", description: "Select conductors using ampacity, derating, termination temperature, and voltage drop.", href: "/toolbox/#sec-wire-select", tags: ["wire size", "ampacity", "awg", "derating", "310.16", "termination"], concepts: ["conductor sizing", "safety", "nec"], kind: "tool" },
  { id: "transformer", title: "Transformer Sizing", description: "Select transformer size, primary and secondary protection, and conductor options.", href: "/toolbox/#sec-xfmr-size", tags: ["transformer", "kva", "primary", "secondary", "450.3"], concepts: ["power systems", "distribution", "protection"], kind: "tool" },
  { id: "tdr", title: "Megger TDR Trace Analyzer", description: "Analyze TDR screen values and locate open or short cable faults.", href: "/toolbox/#sec-tdr", tags: ["megger", "tdr", "cable", "open", "short", "fault locating", "velocity factor"], concepts: ["field test", "fault locating", "reflection"], kind: "tool" },
  { id: "projects", title: "Projects & Build Logs", description: "Hands-on engineering builds, including the Vespa P200E EV conversion.", href: "/projects", tags: ["build", "project", "vespa", "electric vehicle", "battery"], concepts: ["fabrication", "prototype", "engineering"], kind: "page" },
  { id: "vespa", title: "Vespa P200E EV Conversion", description: "A 72 V 20S10P electric Vespa build with a custom swingarm and hub motor.", href: "/projects/vespa-p200e", tags: ["vespa", "p200e", "72v", "20s10p", "hub motor", "swingarm"], concepts: ["electric vehicle", "battery", "fabrication"], kind: "page" },
  { id: "games", title: "Beckify Games", description: "Play Cosmic Cadet, Finger Runner, and other browser arcade games.", href: "/games", tags: ["games", "cosmic cadet", "finger runner", "space shooter", "runner"], concepts: ["arcade", "play"], kind: "page" },
  { id: "booty-butt-scooter", title: "Booty Butt Scooter", description: "Ride a responsive lane runner with swipe controls, jump timing, and local high scores.", href: "/games/booty-butt-scooter", tags: ["booty butt scooter", "scooter", "lane runner", "swipe", "jump", "arcade"], concepts: ["arcade", "runner", "play"], kind: "page" },
  { id: "finger-runner", title: "Finger Runner", description: "Jump over hazards in a quick, touch-friendly endless runner.", href: "/games/finger-runner", tags: ["finger runner", "runner", "jump", "arcade", "touch"], concepts: ["arcade", "reflexes", "play"], kind: "page" },
  { id: "gear", title: "Recommended Electrical Gear", description: "Technically justified tools for termination, prototyping, and field diagnostics.", href: "/gear", tags: ["gear", "crimper", "multimeter", "megger", "diagnostics"], concepts: ["tools", "field work", "measurement"], kind: "reference" },
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
