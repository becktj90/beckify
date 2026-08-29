/* ============================================================================
   NEC REFERENCE DATA — Chapter 9 tables, Table 310.16 ampacity, 310.15 factors
   ============================================================================
   Every table below is transcribed from the published NEC so the calculators
   in wire-tools.js have a single auditable source. Each block cites its table.

   Sizes use a common key set so the tables can be cross-indexed:
   14 … 1 AWG, then 1/0 … 4/0, then kcmil as bare numbers (250 … 1000).
   ============================================================================ */

/* Ordered smallest → largest. JS object key order can't be trusted for
   "1/0" vs "250", so ordering is explicit everywhere it matters. */
const WIRE_SIZE_ORDER = [
  '14', '12', '10', '8', '6', '4', '3', '2', '1',
  '1/0', '2/0', '3/0', '4/0',
  '250', '300', '350', '400', '500', '600', '700', '750', '800', '900', '1000',
];

const KCMIL_SET = new Set(['250', '300', '350', '400', '500', '600', '700', '750', '800', '900', '1000']);

function wireSizeLabel(size) {
  return size + (KCMIL_SET.has(size) ? ' kcmil' : ' AWG');
}

/* Circular mils — NEC Ch.9 Table 8. Used for the K-factor voltage-drop check
   and for the 1/0 minimum on parallel sets (310.10(G)). */
const WIRE_CMIL = {
  '14': 4110, '12': 6530, '10': 10380, '8': 16510, '6': 26240,
  '4': 41740, '3': 52620, '2': 66360, '1': 83690,
  '1/0': 105600, '2/0': 133100, '3/0': 167800, '4/0': 211600,
  '250': 250000, '300': 300000, '350': 350000, '400': 400000, '500': 500000,
  '600': 600000, '700': 700000, '750': 750000, '800': 800000, '900': 900000, '1000': 1000000,
};

/* ---------------------------------------------------------------------------
   NEC Chapter 9, Table 4 — total internal cross-sectional area (in²)
   Fill percentages are applied by the calculator, so these are the FULL areas,
   never the pre-computed 40% column.
   --------------------------------------------------------------------------- */
const CONDUIT_TYPES = {
  EMT: {
    label: 'EMT (Electrical Metallic Tubing)',
    areas: {
      '1/2': 0.304, '3/4': 0.533, '1': 0.864, '1-1/4': 1.496, '1-1/2': 2.036,
      '2': 3.356, '2-1/2': 4.788, '3': 7.393, '3-1/2': 9.893, '4': 12.720,
    },
  },
  IMC: {
    label: 'IMC (Intermediate Metal Conduit)',
    areas: {
      '1/2': 0.342, '3/4': 0.586, '1': 0.959, '1-1/4': 1.647, '1-1/2': 2.225,
      '2': 3.630, '2-1/2': 5.135, '3': 7.922, '3-1/2': 10.584, '4': 13.631,
    },
  },
  RMC: {
    label: 'RMC (Rigid Metal Conduit)',
    areas: {
      '1/2': 0.314, '3/4': 0.549, '1': 0.887, '1-1/4': 1.526, '1-1/2': 2.071,
      '2': 3.408, '2-1/2': 4.866, '3': 7.499, '3-1/2': 10.010, '4': 12.882,
      '5': 20.212, '6': 29.158,
    },
  },
  PVC40: {
    label: 'PVC Schedule 40',
    areas: {
      '1/2': 0.285, '3/4': 0.508, '1': 0.832, '1-1/4': 1.453, '1-1/2': 1.986,
      '2': 3.291, '2-1/2': 4.695, '3': 7.268, '3-1/2': 9.737, '4': 12.554,
      '5': 19.761, '6': 28.567,
    },
  },
  PVC80: {
    label: 'PVC Schedule 80',
    areas: {
      '1/2': 0.217, '3/4': 0.409, '1': 0.688, '1-1/4': 1.237, '1-1/2': 1.711,
      '2': 2.874, '2-1/2': 4.119, '3': 6.442, '3-1/2': 8.688, '4': 11.258,
      '5': 17.855, '6': 25.598,
    },
  },
  ENT: {
    label: 'ENT (Electrical Nonmetallic Tubing)',
    areas: {
      '1/2': 0.285, '3/4': 0.508, '1': 0.832, '1-1/4': 1.453, '1-1/2': 1.986, '2': 3.291,
    },
  },
  FMC: {
    label: 'FMC (Flexible Metal Conduit)',
    areas: {
      '1/2': 0.317, '3/4': 0.533, '1': 0.817, '1-1/4': 1.277, '1-1/2': 1.858,
      '2': 3.269, '2-1/2': 4.909, '3': 7.069, '3-1/2': 9.621, '4': 12.566,
    },
  },
  LFMC: {
    label: 'LFMC (Liquidtight Flexible Metal)',
    areas: {
      '1/2': 0.314, '3/4': 0.541, '1': 0.873, '1-1/4': 1.528, '1-1/2': 1.981,
      '2': 3.246, '2-1/2': 4.881, '3': 7.475, '3-1/2': 9.731, '4': 12.692,
    },
  },
};

/* Trade sizes in ascending order — used when searching for the smallest
   conduit that will hold a given bundle. */
const CONDUIT_TRADE_ORDER = ['1/2', '3/4', '1', '1-1/4', '1-1/2', '2', '2-1/2', '3', '3-1/2', '4', '5', '6'];

/* ---------------------------------------------------------------------------
   NEC Chapter 9, Table 5 — conductor area including insulation (in²)
   --------------------------------------------------------------------------- */
const INSULATION_TYPES = {
  THHN: {
    label: 'THHN / THWN-2',
    tempRating: 90,
    areas: {
      '14': 0.0097, '12': 0.0133, '10': 0.0211, '8': 0.0366, '6': 0.0507,
      '4': 0.0824, '3': 0.0973, '2': 0.1158, '1': 0.1562,
      '1/0': 0.1855, '2/0': 0.2223, '3/0': 0.2679, '4/0': 0.3237,
      '250': 0.3970, '300': 0.4608, '350': 0.5242, '400': 0.5863, '500': 0.7073,
      '600': 0.8676, '700': 0.9887, '750': 1.0496, '800': 1.1085, '900': 1.2311, '1000': 1.3478,
    },
  },
  XHHW: {
    label: 'XHHW / XHHW-2',
    tempRating: 90,
    areas: {
      '14': 0.0139, '12': 0.0181, '10': 0.0243, '8': 0.0437, '6': 0.0590,
      '4': 0.0814, '3': 0.0962, '2': 0.1146, '1': 0.1534,
      '1/0': 0.1825, '2/0': 0.2190, '3/0': 0.2642, '4/0': 0.3197,
      '250': 0.3904, '300': 0.4536, '350': 0.5166, '400': 0.5782, '500': 0.6984,
      '600': 0.8709, '700': 0.9923, '750': 1.0532, '800': 1.1122, '900': 1.2351, '1000': 1.3519,
    },
  },
  RHW: {
    label: 'RHH / RHW / RHW-2',
    tempRating: 90,
    areas: {
      '14': 0.0293, '12': 0.0353, '10': 0.0437, '8': 0.0835, '6': 0.1041,
      '4': 0.1333, '3': 0.1521, '2': 0.1750, '1': 0.2660,
      '1/0': 0.3039, '2/0': 0.3505, '3/0': 0.4072, '4/0': 0.4754,
      '250': 0.6291, '300': 0.7088, '350': 0.7870, '400': 0.8626, '500': 1.0082,
      '600': 1.2135, '700': 1.3561, '750': 1.4272, '800': 1.4957, '900': 1.6377, '1000': 1.7719,
    },
  },
};

/* ---------------------------------------------------------------------------
   NEC Table 310.16 — allowable ampacity, not more than three current-carrying
   conductors in a raceway, 30°C ambient. [60°C, 75°C, 90°C]
   null = size not recognised for that material.
   --------------------------------------------------------------------------- */
const AMPACITY = {
  cu: {
    '14': [15, 20, 25], '12': [20, 25, 30], '10': [30, 35, 40], '8': [40, 50, 55],
    '6': [55, 65, 75], '4': [70, 85, 95], '3': [85, 100, 115], '2': [95, 115, 130],
    '1': [110, 130, 145], '1/0': [125, 150, 170], '2/0': [145, 175, 195],
    '3/0': [165, 200, 225], '4/0': [195, 230, 260], '250': [215, 255, 290],
    '300': [240, 285, 320], '350': [260, 310, 350], '400': [280, 335, 380],
    '500': [320, 380, 430], '600': [350, 420, 475], '700': [385, 460, 520],
    '750': [400, 475, 535], '800': [410, 490, 555], '900': [435, 520, 585],
    '1000': [455, 545, 615],
  },
  al: {
    '14': null, '12': [15, 20, 25], '10': [25, 30, 35], '8': [35, 40, 45],
    '6': [40, 50, 55], '4': [55, 65, 75], '3': [65, 75, 85], '2': [75, 90, 100],
    '1': [85, 100, 115], '1/0': [100, 120, 135], '2/0': [115, 135, 150],
    '3/0': [130, 155, 175], '4/0': [150, 180, 205], '250': [170, 205, 230],
    '300': [195, 230, 260], '350': [210, 250, 280], '400': [225, 270, 305],
    '500': [260, 310, 350], '600': [285, 340, 385], '700': [315, 375, 425],
    '750': [320, 385, 435], '800': [330, 395, 445], '900': [355, 425, 480],
    '1000': [375, 445, 500],
  },
};

const TEMP_COLUMN_INDEX = { 60: 0, 75: 1, 90: 2 };

/* ---------------------------------------------------------------------------
   NEC Ch.9 Table 8 — DC resistance at 75°C, stranded, uncoated (Ω per 1000 ft)
   --------------------------------------------------------------------------- */
const DC_RESISTANCE = {
  cu: {
    '14': 3.14, '12': 1.98, '10': 1.24, '8': 0.778, '6': 0.491, '4': 0.308,
    '3': 0.245, '2': 0.194, '1': 0.154, '1/0': 0.122, '2/0': 0.0967,
    '3/0': 0.0766, '4/0': 0.0608, '250': 0.0515, '300': 0.0429, '350': 0.0367,
    '400': 0.0321, '500': 0.0258, '600': 0.0214, '700': 0.0184, '750': 0.0171,
    '800': 0.0161, '900': 0.0143, '1000': 0.0129,
  },
  al: {
    '14': null, '12': 3.25, '10': 2.04, '8': 1.28, '6': 0.808, '4': 0.508,
    '3': 0.403, '2': 0.319, '1': 0.253, '1/0': 0.201, '2/0': 0.159,
    '3/0': 0.126, '4/0': 0.100, '250': 0.0847, '300': 0.0707, '350': 0.0605,
    '400': 0.0529, '500': 0.0424, '600': 0.0353, '700': 0.0303, '750': 0.0282,
    '800': 0.0265, '900': 0.0235, '1000': 0.0212,
  },
};

/* NEC Ch.9 Table 9 — inductive reactance, Ω per 1000 ft. Nearly independent of
   material, so one column serves both. Only used when power factor < 1. */
const REACTANCE = {
  '14': 0.058, '12': 0.054, '10': 0.050, '8': 0.052, '6': 0.051, '4': 0.048,
  '3': 0.047, '2': 0.045, '1': 0.046, '1/0': 0.044, '2/0': 0.043, '3/0': 0.042,
  '4/0': 0.041, '250': 0.041, '300': 0.041, '350': 0.040, '400': 0.040,
  '500': 0.039, '600': 0.039, '700': 0.038, '750': 0.038, '800': 0.037,
  '900': 0.037, '1000': 0.037,
};

/* ---------------------------------------------------------------------------
   NEC Table 310.15(C)(1) — adjustment for more than three current-carrying
   conductors in a raceway.
   --------------------------------------------------------------------------- */
function cccAdjustmentFactor(count) {
  if (count <= 3) return 1.0;
  if (count <= 6) return 0.8;
  if (count <= 9) return 0.7;
  if (count <= 20) return 0.5;
  if (count <= 30) return 0.45;
  if (count <= 40) return 0.4;
  return 0.35;
}

/* NEC Table 310.15(B)(1) — ambient correction, based on a 30°C table.
   Returns 0 when the ambient exceeds the insulation's usable range, which the
   caller must treat as "this insulation cannot be used here". */
function ambientCorrectionFactor(ambientC, tempRating) {
  const tables = {
    60: [[25, 1.08], [30, 1.0], [35, 0.91], [40, 0.82], [45, 0.71], [50, 0.58], [55, 0.41]],
    75: [[25, 1.05], [30, 1.0], [35, 0.94], [40, 0.88], [45, 0.82], [50, 0.75],
         [55, 0.67], [60, 0.58], [65, 0.47], [70, 0.33]],
    90: [[25, 1.04], [30, 1.0], [35, 0.96], [40, 0.91], [45, 0.87], [50, 0.82],
         [55, 0.76], [60, 0.71], [65, 0.65], [70, 0.58], [75, 0.50], [80, 0.41], [85, 0.29]],
  };
  const table = tables[tempRating] || tables[75];
  for (const [maxTemp, factor] of table) {
    if (ambientC <= maxTemp) return factor;
  }
  return 0;
}

/* NEC 240.6(A) — standard overcurrent device ratings. */
const STD_OCPD_RATINGS = [
  15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200,
  225, 250, 300, 350, 400, 450, 500, 600, 700, 800, 1000, 1200, 1600, 2000,
  2500, 3000, 4000, 5000, 6000,
];

function nextStandardOCPD(amps) {
  return STD_OCPD_RATINGS.find((r) => r >= amps) || null;
}

/* NEC 240.4(D) — small-conductor overcurrent limits, applied regardless of the
   ampacity table. */
const SMALL_CONDUCTOR_MAX_OCPD = { '14': 15, '12': 20, '10': 30 };

/* NEC 310.10(G) — conductors may only be paralleled in sizes 1/0 and larger. */
const MIN_PARALLEL_SIZE_CMIL = WIRE_CMIL['1/0'];

/* ---------------------------------------------------------------------------
   NEC Table 250.122 — minimum equipment grounding conductor, sized from the
   rating of the overcurrent device ahead of the circuit (not from the phase
   conductor). Sizes are AWG/kcmil keyed to WIRE_SIZE_ORDER.
   --------------------------------------------------------------------------- */
const EGC_250_122 = [
  { maxOCPD: 15, cu: '14', al: '12' },
  { maxOCPD: 20, cu: '12', al: '10' },
  { maxOCPD: 60, cu: '10', al: '8' },
  { maxOCPD: 100, cu: '8', al: '6' },
  { maxOCPD: 200, cu: '6', al: '4' },
  { maxOCPD: 300, cu: '4', al: '2' },
  { maxOCPD: 400, cu: '3', al: '1' },
  { maxOCPD: 500, cu: '2', al: '1/0' },
  { maxOCPD: 600, cu: '1', al: '2/0' },
  { maxOCPD: 800, cu: '1/0', al: '3/0' },
  { maxOCPD: 1000, cu: '2/0', al: '4/0' },
  { maxOCPD: 1200, cu: '3/0', al: '250' },
  { maxOCPD: 1600, cu: '4/0', al: '350' },
  { maxOCPD: 2000, cu: '250', al: '400' },
  { maxOCPD: 2500, cu: '350', al: '600' },
  { maxOCPD: 3000, cu: '400', al: '600' },
  { maxOCPD: 4000, cu: '500', al: '800' },
  { maxOCPD: 5000, cu: '700', al: '1000' },
  { maxOCPD: 6000, cu: '800', al: '1000' },
];

function egcForOCPD(ocpdAmps, material) {
  const row = EGC_250_122.find((r) => ocpdAmps <= r.maxOCPD);
  if (!row) return null;
  return { size: material === 'al' ? row.al : row.cu, maxOCPD: row.maxOCPD };
}

/* ---------------------------------------------------------------------------
   NEC Table 250.66 — grounding electrode conductor, sized from the largest
   ungrounded conductor (or the equivalent area of a parallel set). For a
   separately derived system this is the derived secondary conductor, per
   250.30(A)(5). Thresholds are expressed in circular mils so parallel sets
   can be compared on total area.
   --------------------------------------------------------------------------- */
const GEC_250_66 = [
  // Cu service conductor 2 AWG or smaller / Al 1/0 or smaller
  { maxCmilCu: WIRE_CMIL['2'], maxCmilAl: WIRE_CMIL['1/0'], cu: '8', al: '6' },
  // 1 or 1/0 Cu / 2/0 or 3/0 Al
  { maxCmilCu: WIRE_CMIL['1/0'], maxCmilAl: WIRE_CMIL['3/0'], cu: '6', al: '4' },
  // 2/0 or 3/0 Cu / 4/0 or 250 Al
  { maxCmilCu: WIRE_CMIL['3/0'], maxCmilAl: WIRE_CMIL['250'], cu: '4', al: '2' },
  // Over 3/0 through 350 Cu / over 250 through 500 Al
  { maxCmilCu: WIRE_CMIL['350'], maxCmilAl: WIRE_CMIL['500'], cu: '2', al: '1/0' },
  // Over 350 through 600 Cu / over 500 through 900 Al
  { maxCmilCu: WIRE_CMIL['600'], maxCmilAl: WIRE_CMIL['900'], cu: '1/0', al: '3/0' },
  // Over 600 through 1100 Cu / over 900 through 1750 Al
  { maxCmilCu: 1100000, maxCmilAl: 1750000, cu: '2/0', al: '4/0' },
  // Over 1100 Cu / over 1750 Al
  { maxCmilCu: Infinity, maxCmilAl: Infinity, cu: '3/0', al: '250' },
];

function gecForConductor(totalCmil, material) {
  const key = material === 'al' ? 'maxCmilAl' : 'maxCmilCu';
  const row = GEC_250_66.find((r) => totalCmil <= r[key]);
  if (!row) return null;
  return { size: material === 'al' ? row.al : row.cu };
}
