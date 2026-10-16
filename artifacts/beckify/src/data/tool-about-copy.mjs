/**
 * Long-form "About this calculator" copy for the static tool pages written by
 * generate-sitemap.mjs. Plain ESM so the Node script can import it directly.
 *
 * Shape: slug -> sections. Each section is { heading, paragraphs?, bullets?,
 * code? }. Everything is escaped by the renderer, so write plain text. Tools
 * without an entry fall back to the registry description.
 *
 * Content only: this file never feeds the calculators themselves.
 */

export const ABOUT_DISCLAIMER =
  "For design, installation, or safety decisions, verify assumptions against the applicable code edition, equipment documentation, and site requirements.";

export const TOOL_ABOUT_COPY = {
  "voltage-drop": [
    {
      heading: "Why voltage drop matters",
      paragraphs: [
        "Every conductor has resistance, so current flowing through a run turns a little electrical energy into heat — and the voltage at the load ends up lower than at the source. Too much drop and motors run hot and weak, lights dim, and sensitive electronics misbehave. Sizing conductors for acceptable drop is one of the most common field calculations in electrical work.",
      ],
    },
    {
      heading: "The NEC K-method",
      paragraphs: [
        "This calculator uses the resistance-based K-method built on NEC Chapter 9, Table 8 conductor properties:",
      ],
      code: ["Single-phase (2-wire): VD = 2 × K × I × L ÷ CM", "Three-phase: VD = √3 × K × I × L ÷ CM"],
      after: [
        "K = 12.9 for copper or 21.2 for aluminum (ohms per circular-mil foot at 75 °C), I = load current in amps, L = one-way run length in feet, CM = conductor area in circular mils. Percent drop is VD ÷ source voltage × 100.",
      ],
    },
    {
      heading: "What the Code says",
      paragraphs: [
        "The NEC sets no hard voltage-drop limit, but 210.19(A)(1) Informational Note No. 4 and 215.2(A)(1) Informational Note No. 2 recommend sizing feeders and branch circuits so drop stays within 3%, with no more than 5% total from service to the farthest outlet. Treat these as design targets, not inspection pass/fail criteria — the enforceable requirement is that connected equipment operates within its voltage rating.",
      ],
    },
    {
      heading: "Worked example",
      paragraphs: [
        "A 3-phase, 480 V feeder carries 100 A over 200 ft in 3/0 AWG copper (167,800 cmil):",
      ],
      code: ["VD = 1.732 × 12.9 × 100 × 200 ÷ 167,800 = 2.66 V → 2.66 ÷ 480 = 0.55%"],
      after: ["Well under the 3% guideline — 3/0 is plenty for this run."],
    },
    {
      heading: "Field notes",
      bullets: [
        "When drop is too high, the usual fix is upsizing one or two conductor sizes — copper's lower K wins over aluminum at the same size.",
        "The K-method is a resistance approximation; on long runs or large conductors, AC reactance (NEC Chapter 9, Table 9) adds a correction worth checking on critical feeders.",
        "K assumes 75 °C conductor properties — hot environments still need separate ampacity derating per 310.15.",
      ],
    },
    {
      heading: "Common questions",
      faqs: [
        {
          q: "What voltage drop does the NEC require?",
          a: "The NEC does not set a hard limit. Informational notes to 210.19(A)(1) and 215.2(A)(1) recommend 3 percent on the branch or feeder and 5 percent total. The enforceable point is that the equipment still sees a voltage inside its rating.",
        },
      ],
    },
  ],
  "conduit-fill": [
    {
      heading: "Why fill limits exist",
      paragraphs: [
        "Cramming too many conductors into a raceway damages insulation during the pull, traps heat so conductors can't cool, and makes future pulls nearly impossible. NEC Chapter 9, Table 1 caps fill by conductor count: one conductor 53%, two conductors 31%, three or more 40% of the raceway's interior cross-section.",
      ],
    },
    {
      heading: "How the math works",
      paragraphs: [
        "Fill is the total conductor cross-sectional area (NEC Chapter 9, Tables 5 and 5A for insulated conductors, Table 8 for bare) divided by the raceway's interior area (Table 4), compared against the Table 1 percentage for your conductor count. This calculator handles single-size and mixed-size conductor combinations across EMT, PVC, IMC, and RMC.",
      ],
    },
    {
      heading: "Worked example",
      paragraphs: [
        "Three 4 AWG THHN conductors plus one 8 AWG bare equipment ground in 1-inch EMT:",
      ],
      bullets: [
        "4 AWG THHN ≈ 0.0824 in² each → 3 × 0.0824 = 0.2472 in²",
        "8 AWG bare ≈ 0.0130 in²",
        'Total = 0.2602 in² vs. the 1" EMT 40% allowance of 0.346 in² → passes at about 75% of allowed fill.',
      ],
    },
    {
      heading: "Field notes",
      bullets: [
        "Fill is not derating: even when fill passes, more than three current-carrying conductors triggers ampacity adjustment per 310.15(C)(1).",
        "Short nipples 24 inches or less get a 60% allowance (Chapter 9, Note 4) — derating still applies.",
        "When pulling three large conductors, check the jam ratio: conduit ID ÷ conductor OD between 2.8 and 3.2 risks jamming, so size up the raceway if you land in that window.",
      ],
    },
    {
      heading: "Common questions",
      faqs: [
        {
          q: "What does a conduit fill calculator check?",
          a: "It adds the cross-sectional area of the insulated conductors and compares that total with the raceway area allowed by NEC Chapter 9, Table 1: 53% for one conductor, 31% for two, and 40% for three or more.",
        },
        {
          q: "Does passing conduit fill mean the wires are big enough?",
          a: "No. Fill is a space check. Ampacity still comes from NEC Table 310.16, and more than three current-carrying conductors need the adjustment in 310.15(C)(1).",
        },
      ],
    },
  ],
  "wire-size-ampacity": [
    {
      heading: "How to use the ampacity calculator",
      paragraphs: [
        "Start with the load current, then pick a conductor that stays at or above that current after you apply the temperature and bundling rules. The calculator reads NEC Table 310.16 and lets you check voltage drop on the same size.",
      ],
      bullets: [
        "Use the 75 °C column only when the termination is listed for 75 °C. Otherwise, equipment rated 100 amperes or less uses the 60 °C column under 110.14(C).",
        "If the insulation is 90 °C, you may start the adjustment from the 90 °C column, then the result cannot exceed the termination column.",
        "More than three current-carrying conductors in the same raceway use the adjustment factors in 310.15(C)(1).",
      ],
    },
    {
      heading: "Worked example",
      paragraphs: [
        "Four AWG copper is 85 amperes in the 75 °C column of Table 310.16 and 95 amperes in the 90 °C column. Six current-carrying THHN conductors use the 80 percent adjustment for 4–6 conductors:",
      ],
      code: ["95 A × 0.80 = 76 A from the 90 °C column", "Termination limit at 75 °C is 85 A, so 76 A governs"],
      after: [
        "That 4 AWG run is a 76 ampere conductor after bundling, not an 85 ampere conductor. Upsize if the load is higher, then run the voltage-drop check.",
      ],
    },
    {
      heading: "Common questions",
      faqs: [
        {
          q: "Which NEC table is the ampacity calculator using?",
          a: "NEC Table 310.16 for copper and aluminum at 60 °C, 75 °C, and 90 °C, not more than three current-carrying conductors. Temperature and bundling adjustments are applied on top of that table.",
        },
        {
          q: "Is this ampacity calculator free?",
          a: "Yes. It runs in the browser with no account and no signup. It is a design aid, not a code-compliance determination.",
        },
      ],
    },
  ],
  "transformer-sizing": [
    {
      heading: "How to size the primary fuse or breaker",
      paragraphs: [
        "Find the transformer rated current, then apply NEC Table 450.3(B) for transformers 1000 volts and less. Primary protection only is 125 percent of primary current when that current is 9 amperes or more. Note 1 lets you take the next standard rating from 240.6 when 125 percent does not land on a standard fuse or breaker.",
      ],
      bullets: [
        "Primary current, three-phase: kVA × 1000 ÷ (volts × √3).",
        "Primary current, single-phase: kVA × 1000 ÷ volts.",
        "If the secondary is also protected, Table 450.3(B) allows a higher primary percentage. Read the row that matches your scheme. Do not use the 125 percent primary-only number when you are actually using primary and secondary protection.",
      ],
    },
    {
      heading: "Worked example",
      paragraphs: [
        "A 75 kVA, 480 volt, three-phase transformer, primary protection only:",
      ],
      code: [
        "I = 75,000 ÷ (480 × 1.732) = 90.2 A",
        "125% × 90.2 A = 113 A",
        "Next standard device at or above 113 A is 125 A",
      ],
      after: [
        "A 125 ampere primary fuse or breaker is the Note 1 result for this primary-only case. Secondary protection, continuous load, and the conductor ampacity are separate checks.",
      ],
    },
    {
      heading: "Common questions",
      faqs: [
        {
          q: "How do I size a transformer primary breaker?",
          a: "Divide the transformer kVA by the primary voltage (and by √3 for three-phase) to get rated current, multiply by the Table 450.3(B) percentage for your protection scheme, then pick a standard fuse or breaker. For primary-only protection at 9 amperes or more, that percentage is 125, and Note 1 allows the next size up.",
        },
        {
          q: "Does the same percentage size the secondary breaker?",
          a: "No. When both sides are protected, the secondary device is its own row in Table 450.3(B), commonly 125 percent of secondary current when that current is 9 amperes or more. Conductors are sized from the load and 310.16, not by copying the transformer percentage.",
        },
      ],
    },
  ],
  photometrics: [
    {
      heading: "How to estimate average illuminance",
      paragraphs: [
        "A photometric calculator turns lamp lumens into an average light level on the work plane. This one uses the zonal-cavity form of the lumen method:",
      ],
      code: ["lux = (number of luminaires × lumens each × CU × LLF) ÷ area in square meters"],
      after: [
        "CU is the coefficient of utilization from the luminaire report for your room cavity. LLF is the light-loss factor (lamp lumen depreciation, dirt, and similar). The result is a room average, not the light level at a desk in the corner.",
      ],
    },
    {
      heading: "Worked example",
      paragraphs: [
        "Ten luminaires, 4,000 lumens each, CU 0.60, LLF 0.80, room 50 square meters:",
      ],
      code: ["10 × 4,000 × 0.60 × 0.80 = 19,200 lumens on the plane", "19,200 ÷ 50 = 384 lux"],
    },
    {
      heading: "Common questions",
      faqs: [
        {
          q: "What is a photometric calculator?",
          a: "It estimates average illuminance from luminaire lumens, how much of that light the room actually uses, and the floor area. It does not replace a point-by-point photometric study or the manufacturer's IES file.",
        },
        {
          q: "Is the photometric calculator free?",
          a: "Yes. It runs in the browser with no signup. The phone lux meter elsewhere in the toolbox is a camera estimate, not this calculation.",
        },
      ],
    },
  ],
};

/** Hub cross-links: the transformer hub points at its three focused views. */
export const RELATED_TOOLS = {
  transformer: {
    heading: "Related transformer tools",
    links: [
      { slug: "transformer-sizing", label: "Transformer primary fuse and breaker sizing" },
      { slug: "transformer-engine", label: "Transformer conductor and OCPD sizing" },
      { slug: "transformer-design", label: "Transformer connections training wizard" },
    ],
  },
};
