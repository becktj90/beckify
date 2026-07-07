/**
 * ============================================================================
 * EE TOOLBOX — CODE CONSTANTS & LOOKUP TABLES
 * ============================================================================
 * All values here are transcribed from published NEC / IEEE / ANSI tables.
 * Each block cites its source so the numbers can be audited. These are the
 * single source of truth shared by the calculators and the reference tables.
 * ============================================================================
 */

/* Resistivity constants K (Ω·circular-mil/ft) — NEC Ch.9 Table 8/9 @ 75°C */
export const K_CU = 12.9; // Copper
export const K_AL = 21.2; // Aluminum

/* Circular-mil area by conductor size (NEC Ch.9 Table 8) */
export const WIRE_CM: Record<string, number> = {
  "14": 4110, "12": 6530, "10": 10380, "8": 16510, "6": 26240,
  "4": 41740, "3": 52620, "2": 66360, "1": 83690,
  "1/0": 105600, "2/0": 133100, "3/0": 167800, "4/0": 211600,
  "250": 250000, "300": 300000, "350": 350000, "400": 400000, "500": 500000,
};

/* Ascending size order (JS numeric key sorting can't be trusted for 1/0…4/0) */
export const WIRE_SIZES = [
  "14", "12", "10", "8", "6", "4", "3", "2", "1",
  "1/0", "2/0", "3/0", "4/0", "250", "300", "350", "400", "500",
];

export const KCMIL_SIZES = new Set(["250", "300", "350", "400", "500"]);

export function sizeLabel(s: string): string {
  return s + (KCMIL_SIZES.has(s) ? " kcmil" : " AWG");
}

/*
 * NEC Table 310.16 (2020) — 75°C column ampacity, not more than 3
 * current-carrying conductors. `al: null` = size not listed for aluminum.
 * `area` = THHN/THWN-2 cross-section in² (NEC Ch.9 Table 5).
 */
export interface Conductor {
  label: string;
  size: string;
  cu: number;
  al: number | null;
  cm: number;
  area: number;
}

export const NEC_CONDUCTORS: Conductor[] = [
  { size: "14", label: "14 AWG", cu: 20, al: null, cm: 4110, area: 0.0097 },
  { size: "12", label: "12 AWG", cu: 25, al: 20, cm: 6530, area: 0.0133 },
  { size: "10", label: "10 AWG", cu: 35, al: 30, cm: 10380, area: 0.0211 },
  { size: "8", label: "8 AWG", cu: 50, al: 40, cm: 16510, area: 0.0366 },
  { size: "6", label: "6 AWG", cu: 65, al: 50, cm: 26240, area: 0.0507 },
  { size: "4", label: "4 AWG", cu: 85, al: 65, cm: 41740, area: 0.0824 },
  { size: "3", label: "3 AWG", cu: 100, al: 75, cm: 52620, area: 0.0973 },
  { size: "2", label: "2 AWG", cu: 115, al: 90, cm: 66360, area: 0.1158 },
  { size: "1", label: "1 AWG", cu: 130, al: 100, cm: 83690, area: 0.1562 },
  { size: "1/0", label: "1/0 AWG", cu: 150, al: 120, cm: 105600, area: 0.1855 },
  { size: "2/0", label: "2/0 AWG", cu: 175, al: 135, cm: 133100, area: 0.2223 },
  { size: "3/0", label: "3/0 AWG", cu: 200, al: 155, cm: 167800, area: 0.2679 },
  { size: "4/0", label: "4/0 AWG", cu: 230, al: 180, cm: 211600, area: 0.3237 },
  { size: "250", label: "250 kcmil", cu: 255, al: 205, cm: 250000, area: 0.3970 },
  { size: "300", label: "300 kcmil", cu: 285, al: 230, cm: 300000, area: 0.4608 },
  { size: "350", label: "350 kcmil", cu: 310, al: 250, cm: 350000, area: 0.5242 },
  { size: "400", label: "400 kcmil", cu: 335, al: 270, cm: 400000, area: 0.5863 },
  { size: "500", label: "500 kcmil", cu: 380, al: 310, cm: 500000, area: 0.7073 },
  { size: "600", label: "600 kcmil", cu: 420, al: 340, cm: 600000, area: 0.8676 },
  { size: "700", label: "700 kcmil", cu: 460, al: 375, cm: 700000, area: 0.9887 },
  { size: "750", label: "750 kcmil", cu: 475, al: 385, cm: 750000, area: 1.0496 },
  { size: "800", label: "800 kcmil", cu: 490, al: 395, cm: 800000, area: 1.1085 },
  { size: "1000", label: "1000 kcmil", cu: 545, al: 445, cm: 1000000, area: 1.3478 },
];

/* Copper THHN ampacity + area (subset used for transformer conductor picks) */
export const CU_THHN = NEC_CONDUCTORS.map((c) => ({
  size: c.label,
  amps: c.cu,
  area: c.area,
}));

/* THHN/THWN-2 cross-sectional areas (in²) per NEC Ch.9 Table 5 */
export const THHN_AREAS: Record<string, number> = Object.fromEntries(
  NEC_CONDUCTORS.filter((c) => WIRE_CM[c.size] !== undefined).map((c) => [c.size, c.area]),
);

/* EMT trade sizes — internal area & 40%-fill area (NEC Ch.9 Table 4) */
export interface Conduit {
  size: string;
  area: number; // total internal area, in²
  id: number; // internal diameter, in
  fill40: number; // 40% fill area, in²
}

export const EMT_SIZES: Conduit[] = [
  { size: "1/2", area: 0.304, id: 0.622, fill40: 0.122 },
  { size: "3/4", area: 0.533, id: 0.824, fill40: 0.213 },
  { size: "1", area: 0.864, id: 1.049, fill40: 0.346 },
  { size: "1-1/4", area: 1.496, id: 1.380, fill40: 0.598 },
  { size: "1-1/2", area: 2.036, id: 1.610, fill40: 0.814 },
  { size: "2", area: 3.356, id: 2.067, fill40: 1.342 },
  { size: "2-1/2", area: 4.788, id: 2.469, fill40: 1.915 },
  { size: "3", area: 7.393, id: 3.068, fill40: 2.957 },
  { size: "3-1/2", area: 9.893, id: 3.548, fill40: 3.957 },
  { size: "4", area: 12.72, id: 4.026, fill40: 5.088 },
];

/* NEC 240.6(A) standard OCPD ratings (A) */
export const STD_OCPD = [
  15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200,
  225, 250, 300, 350, 400, 450, 500, 600, 700, 800, 1000, 1200,
];

/* NEC 240.4(D) maximum OCPD for small conductors */
export const NEC_SMALL_WIRE_MAX: Record<string, number> = {
  "14 AWG": 15,
  "12 AWG": 20,
  "10 AWG": 30,
};

/* NEC 250.122 — equipment grounding conductor sizing by OCPD rating */
export const EGC_TABLE = [
  { maxOCPD: 15, cu: "14 AWG", al: "12 AWG" },
  { maxOCPD: 20, cu: "12 AWG", al: "10 AWG" },
  { maxOCPD: 60, cu: "10 AWG", al: "8 AWG" },
  { maxOCPD: 100, cu: "8 AWG", al: "6 AWG" },
  { maxOCPD: 200, cu: "6 AWG", al: "4 AWG" },
  { maxOCPD: 300, cu: "4 AWG", al: "2 AWG" },
  { maxOCPD: 400, cu: "3 AWG", al: "1 AWG" },
  { maxOCPD: 500, cu: "2 AWG", al: "1/0" },
  { maxOCPD: 600, cu: "1 AWG", al: "2/0" },
  { maxOCPD: 800, cu: "1/0", al: "3/0" },
  { maxOCPD: 1000, cu: "2/0", al: "4/0" },
  { maxOCPD: 1200, cu: "3/0", al: "250 kcmil" },
];

/* ANSI/NEMA standard dry-type transformer kVA ratings */
export const XFMR_STD_KVA = [
  1, 1.5, 2, 3, 5, 7.5, 10, 15, 25, 37.5, 50, 75, 100, 150, 167, 200, 250, 333,
  500, 750, 1000, 1500, 2000, 2500,
];

export const MIN_PARALLEL_AMPACITY = 150; // NEC 310.10(H): parallel ≥ 1/0 AWG

export function nextStdOCPD(amps: number): number {
  return STD_OCPD.find((s) => s >= amps) || Math.ceil(amps / 100) * 100;
}

/*
 * NEC Table 310.15(B)(1) — ambient temperature correction factors, based on
 * 30°C. Keyed by insulation temp rating.
 */
export function necTempFactor(ambientC: number, insulRating: number): number {
  const f90: [number, number][] = [
    [25, 1.04], [30, 1.0], [35, 0.96], [40, 0.91], [45, 0.87],
    [50, 0.82], [55, 0.76], [60, 0.71],
  ];
  const f75: [number, number][] = [
    [25, 1.05], [30, 1.0], [35, 0.94], [40, 0.88], [45, 0.82],
    [50, 0.75], [55, 0.67], [60, 0.58],
  ];
  const tbl = insulRating >= 90 ? f90 : f75;
  for (const [temp, factor] of tbl) if (ambientC <= temp) return factor;
  return 0;
}

/* Default X/R ratio used for asymmetrical fault current when not supplied */
export const DEFAULT_SC_XR_RATIO = 6.6;

/* ────────────────────────────────────────────────────────────────────────
 * NEC MOTOR FULL-LOAD-CURRENT TABLES
 * These are the values that MUST be used for conductor/OCPD sizing per
 * NEC 430.6(A)(1) — not the nameplate current.
 * ──────────────────────────────────────────────────────────────────────── */

/* NEC Table 430.248 — single-phase AC motors (FLA in amps) */
export const MOTOR_FLA_1PH: { hp: string; v115: number; v200: number; v208: number; v230: number }[] = [
  { hp: "1/6", v115: 4.4, v200: 2.5, v208: 2.4, v230: 2.2 },
  { hp: "1/4", v115: 5.8, v200: 3.3, v208: 3.2, v230: 2.9 },
  { hp: "1/3", v115: 7.2, v200: 4.1, v208: 4.0, v230: 3.6 },
  { hp: "1/2", v115: 9.8, v200: 5.6, v208: 5.4, v230: 4.9 },
  { hp: "3/4", v115: 13.8, v200: 7.9, v208: 7.6, v230: 6.9 },
  { hp: "1", v115: 16, v200: 9.2, v208: 8.8, v230: 8.0 },
  { hp: "1-1/2", v115: 20, v200: 11.5, v208: 11, v230: 10 },
  { hp: "2", v115: 24, v200: 13.8, v208: 13.2, v230: 12 },
  { hp: "3", v115: 34, v200: 19.6, v208: 18.7, v230: 17 },
  { hp: "5", v115: 56, v200: 32.2, v208: 30.8, v230: 28 },
  { hp: "7-1/2", v115: 80, v200: 46, v208: 44, v230: 40 },
  { hp: "10", v115: 100, v200: 57.5, v208: 55, v230: 50 },
];

/* NEC Table 430.250 — three-phase squirrel-cage induction motors (FLA, amps).
   `null` = not a standard rating at that voltage. */
export const MOTOR_FLA_3PH: {
  hp: string; v115: number | null; v200: number; v208: number; v230: number; v460: number; v575: number;
}[] = [
  { hp: "1/2", v115: 4.4, v200: 2.5, v208: 2.4, v230: 2.2, v460: 1.1, v575: 0.9 },
  { hp: "3/4", v115: 6.4, v200: 3.7, v208: 3.5, v230: 3.2, v460: 1.6, v575: 1.3 },
  { hp: "1", v115: 8.4, v200: 4.8, v208: 4.6, v230: 4.2, v460: 2.1, v575: 1.7 },
  { hp: "1-1/2", v115: 12, v200: 6.9, v208: 6.6, v230: 6.0, v460: 3.0, v575: 2.4 },
  { hp: "2", v115: 13.6, v200: 7.8, v208: 7.5, v230: 6.8, v460: 3.4, v575: 2.7 },
  { hp: "3", v115: null, v200: 11, v208: 10.6, v230: 9.6, v460: 4.8, v575: 3.9 },
  { hp: "5", v115: null, v200: 17.5, v208: 16.7, v230: 15.2, v460: 7.6, v575: 6.1 },
  { hp: "7-1/2", v115: null, v200: 25.3, v208: 24.2, v230: 22, v460: 11, v575: 9.0 },
  { hp: "10", v115: null, v200: 32.2, v208: 30.8, v230: 28, v460: 14, v575: 11 },
  { hp: "15", v115: null, v200: 48.3, v208: 46.2, v230: 42, v460: 21, v575: 17 },
  { hp: "20", v115: null, v200: 62.1, v208: 59.4, v230: 54, v460: 27, v575: 22 },
  { hp: "25", v115: null, v200: 78.2, v208: 74.8, v230: 68, v460: 34, v575: 27 },
  { hp: "30", v115: null, v200: 92, v208: 88, v230: 80, v460: 40, v575: 32 },
  { hp: "40", v115: null, v200: 120, v208: 114, v230: 104, v460: 52, v575: 41 },
  { hp: "50", v115: null, v200: 150, v208: 143, v230: 130, v460: 65, v575: 52 },
  { hp: "60", v115: null, v200: 177, v208: 169, v230: 154, v460: 77, v575: 62 },
  { hp: "75", v115: null, v200: 221, v208: 211, v230: 192, v460: 96, v575: 77 },
  { hp: "100", v115: null, v200: 285, v208: 273, v230: 248, v460: 124, v575: 99 },
  { hp: "125", v115: null, v200: 359, v208: 343, v230: 312, v460: 156, v575: 125 },
  { hp: "150", v115: null, v200: 414, v208: 396, v230: 360, v460: 180, v575: 144 },
  { hp: "200", v115: null, v200: 552, v208: 528, v230: 480, v460: 240, v575: 192 },
];
