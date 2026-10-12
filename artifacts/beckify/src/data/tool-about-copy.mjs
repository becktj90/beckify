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
  ],
};

/** Hub cross-links: the transformer hub points at its three focused views. */
export const RELATED_TOOLS = {
  transformer: {
    heading: "Related transformer tools",
    links: [
      { slug: "transformer-sizing", label: "Transformer kVA sizing and NEC 450.3(B) protection" },
      { slug: "transformer-engine", label: "Transformer conductor and OCPD sizing" },
      { slug: "transformer-design", label: "Transformer connections training wizard" },
    ],
  },
};
