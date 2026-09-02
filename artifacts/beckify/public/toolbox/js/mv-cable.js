/* ============================================================================
   MV CABLE — medium-voltage feeder selection (Conductors family mode)
   ============================================================================
   Ampacity: transcribed from the published NEC 2001–35 000 V solid-dielectric
   tables (2020 numbering Table 310.60(C)(67)–(84); 2023 moved the same
   values into Article 311.60). Source used for the numbers: Fehr, Industrial
   Power Distribution, 2nd ed., IEEE/Wiley 2016, Appendix E reprints of
   NEC Tables 310–69 through 310–84, cross-checked against OmniCable’s
   published Table 310.60(C)(69) reprint. The rest of this toolbox cites
   NEC 2023 for Table 310.16; these MV rows are the 310.60 / 311.60 series,
   not 310.16.

   R/X: Southwire SPEC 46503 (CU 25 kV 133% NL-EPR 1/C, Table 2, updated
   2024-12-31) AC resistance @ 90 °C and inductive reactance @ 60 Hz.
   Not Chapter 9 LV cable. Aluminum and sizes missing from that sheet need
   a user Ω/kft. Shield short-circuit check is omitted — no ICEA P54-6
   implementation here.

   Design aid. Not a PE stamp, manufacturer ampacity letter, or pulling study.
   ============================================================================ */

const MV_SIZES = ['2', '1', '1/0', '2/0', '3/0', '4/0', '250', '350', '500', '750', '1000'];

const MV_CLASS_PRESETS = [4.16, 4.8, 12.47, 13.2, 13.8, 23.0, 23.2, 24.9, 34.5];

/** Voltage class (kV) that is at least 100% of system kV. */
function mvSuggestedClassKv(systemKv) {
  const classes = [5, 8, 15, 25, 35];
  return classes.find(function (c) { return c + 1e-9 >= systemKv; }) || 35;
}

function mvVoltageBand(classKv) {
  if (classKv <= 5) return 'low';
  if (classKv <= 15) return 'mid';
  return 'high';
}

/*
  Each row is [90 °C, 105 °C] for the voltage band used.
  duct_3x1c / duct_3c: 20 °C earth, one-circuit Detail 1 (NEC 310.60(C)(77)/(78)
  and (79)/(80) — Fehr E.15–E.18). Columns: 2001–5000 V then 5001–35 000 V.
  air_1c: isolated in air, 40 °C (310.60(C)(69)/(70) — Fehr E.7–E.8).
    low = 2001–5000, mid = 5001–15 000, high = 15 001–35 000.
  conduit_3x1c: isolated conduit in air (310.60(C)(73)/(74) — Fehr E.11–E.12).
    2001–5000 then 5001–35 000.
  bury_1c: direct-buried 1/C flat, one circuit (310.60(C)(81)/(82) — Fehr E.19–E.20).
    2001–5000 then 5001–35 000.
*/
function mvPair(table, size, band, tempC) {
  const row = table[size];
  if (!row) return null;
  const pair = row[band] || row.high || row.mid || row.low;
  if (!pair) return null;
  const amp = tempC >= 105 ? pair[1] : pair[0];
  return typeof amp === 'number' ? amp : null;
}

function mvBandFromTwoCol(lowPair, highPair, band) {
  return {
    low: lowPair,
    mid: highPair,
    high: highPair,
  };
}

/* Fehr E.15 / NEC 310.60(C)(77) Cu, one circuit, 3 singles per duct. */
const MV_DUCT_3X1C_CU = {
  '2': mvBandFromTwoCol([145, 155], [155, 165]),
  '1': mvBandFromTwoCol([170, 180], [175, 185]),
  '1/0': mvBandFromTwoCol([195, 210], [200, 215]),
  '2/0': mvBandFromTwoCol([220, 235], [230, 245]),
  '3/0': mvBandFromTwoCol([250, 270], [260, 275]),
  '4/0': mvBandFromTwoCol([290, 310], [295, 315]),
  '250': mvBandFromTwoCol([320, 345], [325, 345]),
  '350': mvBandFromTwoCol([385, 415], [390, 415]),
  '500': mvBandFromTwoCol([470, 505], [465, 500]),
  '750': mvBandFromTwoCol([585, 630], [565, 610]),
  '1000': mvBandFromTwoCol([670, 720], [640, 690]),
};

/* Fehr E.16 / NEC 310.60(C)(78) Al, one circuit, 3 singles per duct. */
const MV_DUCT_3X1C_AL = {
  '2': mvBandFromTwoCol([115, 125], [120, 130]),
  '1': mvBandFromTwoCol([130, 140], [135, 145]),
  '1/0': mvBandFromTwoCol([150, 160], [155, 165]),
  '2/0': mvBandFromTwoCol([170, 185], [175, 190]),
  '3/0': mvBandFromTwoCol([195, 210], [200, 215]),
  '4/0': mvBandFromTwoCol([225, 245], [230, 245]),
  '250': mvBandFromTwoCol([250, 270], [250, 270]),
  '350': mvBandFromTwoCol([305, 325], [305, 330]),
  '500': mvBandFromTwoCol([370, 400], [370, 400]),
  '750': mvBandFromTwoCol([470, 505], [455, 490]),
  '1000': mvBandFromTwoCol([545, 590], [525, 565]),
};

/* Fehr E.17 / NEC 310.60(C)(79) Cu 3/C, one circuit, one cable per duct. */
const MV_DUCT_3C_CU = {
  '2': mvBandFromTwoCol([135, 145], [150, 160]),
  '1': mvBandFromTwoCol([155, 165], [170, 185]),
  '1/0': mvBandFromTwoCol([175, 190], [195, 210]),
  '2/0': mvBandFromTwoCol([200, 220], [220, 235]),
  '3/0': mvBandFromTwoCol([230, 250], [250, 270]),
  '4/0': mvBandFromTwoCol([265, 285], [285, 305]),
  '250': mvBandFromTwoCol([290, 315], [310, 335]),
  '350': mvBandFromTwoCol([355, 380], [375, 400]),
  '500': mvBandFromTwoCol([430, 460], [450, 485]),
  '750': mvBandFromTwoCol([530, 570], [545, 585]),
  '1000': mvBandFromTwoCol([600, 645], [615, 660]),
};

/* Fehr E.18 / NEC 310.60(C)(80) Al 3/C, one circuit. */
const MV_DUCT_3C_AL = {
  '2': mvBandFromTwoCol([105, 110], [115, 125]),
  '1': mvBandFromTwoCol([120, 130], [135, 145]),
  '1/0': mvBandFromTwoCol([140, 150], [150, 165]),
  '2/0': mvBandFromTwoCol([160, 170], [170, 185]),
  '3/0': mvBandFromTwoCol([180, 195], [195, 210]),
  '4/0': mvBandFromTwoCol([205, 220], [220, 240]),
  '250': mvBandFromTwoCol([230, 245], [245, 265]),
  '350': mvBandFromTwoCol([280, 310], [295, 315]),
  '500': mvBandFromTwoCol([340, 365], [355, 385]),
  '750': mvBandFromTwoCol([425, 460], [440, 475]),
  '1000': mvBandFromTwoCol([495, 535], [510, 545]),
};

/* Fehr E.7 / OmniCable 310.60(C)(69) Cu isolated in air. Three voltage bands. */
const MV_AIR_1C_CU = {
  '2': { low: [190, 215], mid: [195, 215], high: null },
  '1': { low: [225, 250], mid: [225, 250], high: [225, 250] },
  '1/0': { low: [260, 290], mid: [260, 290], high: [260, 290] },
  '2/0': { low: [300, 330], mid: [300, 335], high: [300, 330] },
  '3/0': { low: [345, 385], mid: [345, 385], high: [345, 380] },
  '4/0': { low: [400, 445], mid: [400, 445], high: [395, 445] },
  '250': { low: [445, 495], mid: [445, 495], high: [440, 490] },
  '350': { low: [550, 615], mid: [550, 610], high: [545, 605] },
  '500': { low: [695, 775], mid: [685, 765], high: [680, 755] },
  '750': { low: [900, 1000], mid: [885, 990], high: [870, 970] },
  '1000': { low: [1075, 1200], mid: [1060, 1185], high: [1040, 1160] },
};

/* Fehr E.8 / NEC 310.60(C)(70) Al isolated in air. */
const MV_AIR_1C_AL = {
  '2': { low: [150, 165], mid: [150, 170], high: null },
  '1/0': { low: [200, 225], mid: [200, 225], high: [200, 225] },
  '2/0': { low: [230, 260], mid: [235, 260], high: [230, 260] },
  '3/0': { low: [270, 300], mid: [270, 300], high: [270, 300] },
  '4/0': { low: [310, 350], mid: [310, 350], high: [310, 345] },
  '250': { low: [345, 385], mid: [345, 385], high: [345, 380] },
  '350': { low: [430, 480], mid: [430, 480], high: [430, 475] },
  '500': { low: [545, 605], mid: [535, 600], high: [530, 590] },
  '750': { low: [710, 790], mid: [700, 780], high: [685, 765] },
  '1000': { low: [855, 950], mid: [840, 940], high: [825, 920] },
};

/* Fehr E.11 / NEC 310.60(C)(73) Cu 3×1/C isolated conduit in air. */
const MV_CONDUIT_3X1C_CU = {
  '2': mvBandFromTwoCol([130, 145], [150, 165]),
  '1': mvBandFromTwoCol([155, 175], [170, 190]),
  '1/0': mvBandFromTwoCol([180, 200], [195, 215]),
  '2/0': mvBandFromTwoCol([205, 225], [225, 255]),
  '3/0': mvBandFromTwoCol([240, 270], [260, 290]),
  '4/0': mvBandFromTwoCol([280, 305], [295, 330]),
  '250': mvBandFromTwoCol([315, 355], [330, 365]),
  '350': mvBandFromTwoCol([385, 430], [395, 440]),
  '500': mvBandFromTwoCol([475, 530], [480, 535]),
  '750': mvBandFromTwoCol([600, 665], [585, 655]),
  '1000': mvBandFromTwoCol([690, 770], [675, 755]),
};

/* Fehr E.12 / NEC 310.60(C)(74) Al 3×1/C isolated conduit in air. */
const MV_CONDUIT_3X1C_AL = {
  '2': mvBandFromTwoCol([100, 115], [115, 130]),
  '1': mvBandFromTwoCol([120, 135], [130, 150]),
  '1/0': mvBandFromTwoCol([140, 155], [150, 170]),
  '2/0': mvBandFromTwoCol([160, 175], [175, 200]),
  '3/0': mvBandFromTwoCol([190, 210], [200, 225]),
  '4/0': mvBandFromTwoCol([215, 240], [230, 260]),
  '250': mvBandFromTwoCol([250, 280], [255, 290]),
  '350': mvBandFromTwoCol([305, 340], [310, 350]),
  '500': mvBandFromTwoCol([380, 425], [385, 430]),
  '750': mvBandFromTwoCol([490, 545], [485, 540]),
  '1000': mvBandFromTwoCol([580, 645], [565, 640]),
};

/* Fehr E.19 / NEC 310.60(C)(81) Cu 1/C direct bury, one circuit. */
const MV_BURY_1C_CU = {
  '2': mvBandFromTwoCol([230, 250], [210, 225]),
  '1': mvBandFromTwoCol([260, 280], [240, 260]),
  '1/0': mvBandFromTwoCol([295, 320], [275, 295]),
  '2/0': mvBandFromTwoCol([335, 365], [310, 335]),
  '3/0': mvBandFromTwoCol([385, 415], [355, 380]),
  '4/0': mvBandFromTwoCol([435, 465], [405, 435]),
  '250': mvBandFromTwoCol([470, 510], [440, 475]),
  '350': mvBandFromTwoCol([570, 615], [535, 575]),
  '500': mvBandFromTwoCol([690, 745], [650, 700]),
  '750': mvBandFromTwoCol([845, 910], [805, 865]),
  '1000': mvBandFromTwoCol([980, 1055], [930, 1005]),
};

/* Fehr E.20 / NEC 310.60(C)(82) Al 1/C direct bury, one circuit. */
const MV_BURY_1C_AL = {
  '2': mvBandFromTwoCol([180, 195], [165, 175]),
  '1': mvBandFromTwoCol([205, 220], [185, 200]),
  '1/0': mvBandFromTwoCol([230, 250], [215, 230]),
  '2/0': mvBandFromTwoCol([265, 285], [245, 260]),
  '3/0': mvBandFromTwoCol([300, 320], [275, 295]),
  '4/0': mvBandFromTwoCol([340, 365], [315, 340]),
  '250': mvBandFromTwoCol([370, 395], [345, 370]),
  '350': mvBandFromTwoCol([445, 480], [415, 450]),
  '500': mvBandFromTwoCol([540, 580], [510, 545]),
  '750': mvBandFromTwoCol([665, 720], [635, 680]),
  '1000': mvBandFromTwoCol([780, 840], [740, 795]),
};

const MV_TABLE_CITE = {
  duct_3x1c_cu: 'NEC 2020 Table 310.60(C)(77) / 2023 Art. 311.60 — 3×1/C Cu in UG duct, one circuit, 20 °C earth',
  duct_3x1c_al: 'NEC 2020 Table 310.60(C)(78) / 2023 Art. 311.60 — 3×1/C Al in UG duct, one circuit, 20 °C earth',
  duct_3c_cu: 'NEC 2020 Table 310.60(C)(79) / 2023 Art. 311.60 — 3/C Cu in UG duct, one circuit, 20 °C earth',
  duct_3c_al: 'NEC 2020 Table 310.60(C)(80) / 2023 Art. 311.60 — 3/C Al in UG duct, one circuit, 20 °C earth',
  air_1c_cu: 'NEC 2020 Table 310.60(C)(69) / 2023 Art. 311.60 — 1/C Cu isolated in air, 40 °C',
  air_1c_al: 'NEC 2020 Table 310.60(C)(70) / 2023 Art. 311.60 — 1/C Al isolated in air, 40 °C',
  conduit_3x1c_cu: 'NEC 2020 Table 310.60(C)(73) / 2023 Art. 311.60 — 3×1/C Cu in isolated conduit in air, 40 °C',
  conduit_3x1c_al: 'NEC 2020 Table 310.60(C)(74) / 2023 Art. 311.60 — 3×1/C Al in isolated conduit in air, 40 °C',
  bury_1c_cu: 'NEC 2020 Table 310.60(C)(81) / 2023 Art. 311.60 — 1/C Cu direct bury, one circuit, 20 °C earth',
  bury_1c_al: 'NEC 2020 Table 310.60(C)(82) / 2023 Art. 311.60 — 1/C Al direct bury, one circuit, 20 °C earth',
};

function mvTableKey(install, construction, material) {
  const mat = material === 'al' ? 'al' : 'cu';
  const multi = construction === '3c' ? '3c' : '3x1c';
  if (install === 'duct') return 'duct_' + multi + '_' + mat;
  if (install === 'air') return construction === '3c' ? null : 'air_1c_' + mat;
  if (install === 'conduit') return construction === '3c' ? null : 'conduit_3x1c_' + mat;
  if (install === 'bury') return construction === '3c' ? null : 'bury_1c_' + mat;
  return null;
}

const MV_TABLES = {
  duct_3x1c_cu: MV_DUCT_3X1C_CU,
  duct_3x1c_al: MV_DUCT_3X1C_AL,
  duct_3c_cu: MV_DUCT_3C_CU,
  duct_3c_al: MV_DUCT_3C_AL,
  air_1c_cu: MV_AIR_1C_CU,
  air_1c_al: MV_AIR_1C_AL,
  conduit_3x1c_cu: MV_CONDUIT_3X1C_CU,
  conduit_3x1c_al: MV_CONDUIT_3X1C_AL,
  bury_1c_cu: MV_BURY_1C_CU,
  bury_1c_al: MV_BURY_1C_AL,
};

function mvLookupAmpacity(opts) {
  const key = mvTableKey(opts.install, opts.construction, opts.material);
  if (!key) {
    return { ampacity: null, cite: null, reason: 'This installation/construction is not in the transcribed 310.60 / 311.60 excerpt. Enter ampacity from the cable datasheet.' };
  }
  const table = MV_TABLES[key];
  const band = mvVoltageBand(opts.classKv);
  const amp = mvPair(table, opts.size, band, opts.tempC);
  if (amp == null) {
    return { ampacity: null, cite: MV_TABLE_CITE[key], reason: wireSizeLabel(opts.size) + ' is not listed in this voltage-class column. Enter a datasheet ampacity or pick another size.' };
  }
  return { ampacity: amp, cite: MV_TABLE_CITE[key], reason: null };
}

/* Southwire SPEC 46503 Table 2 (2024-12-31): 25 kV 133% 1/C Cu. Ω/kft. */
const MV_RX_CU_25KV = {
  '1': { r: 0.162, x: 0.053 },
  '1/0': { r: 0.128, x: 0.051 },
  '2/0': { r: 0.102, x: 0.049 },
  '3/0': { r: 0.081, x: 0.047 },
  '4/0': { r: 0.065, x: 0.045 },
  '250': { r: 0.056, x: 0.044 },
  '350': { r: 0.041, x: 0.042 },
  '500': { r: 0.030, x: 0.040 },
  '750': { r: 0.023, x: 0.038 },
  '1000': { r: 0.019, x: 0.036 },
};

function mvRx(size, material, userR, userX) {
  if (isPos(userR) && isNum(userX)) return { r: userR, x: userX, source: 'user-entered Ω/kft' };
  if (material === 'cu' && MV_RX_CU_25KV[size]) {
    return { r: MV_RX_CU_25KV[size].r, x: MV_RX_CU_25KV[size].x, source: 'Southwire SPEC 46503 Table 2 (25 kV 133% 1/C Cu, 2024-12-31)' };
  }
  return { r: null, x: null, source: null };
}

function mvLoadAmps(opts) {
  const kv = opts.systemKv;
  const volts = kv * 1000;
  const mult = opts.phase === '1ph' ? 1 : Math.sqrt(3);
  if (opts.loadUnit === 'a') return { amps: opts.loadValue, basis: 'Entered directly' };
  if (opts.loadUnit === 'kw') {
    const pf = opts.powerFactor;
    const amps = (opts.loadValue * 1000) / (mult * volts * pf);
    return { amps: amps, basis: opts.phase === '1ph' ? 'I = kW×1000 / (V × PF)' : 'I = kW×1000 / (√3 × V × PF)' };
  }
  const amps = (opts.loadValue * 1000) / (mult * volts);
  return { amps: amps, basis: opts.phase === '1ph' ? 'I = kVA×1000 / V' : 'I = kVA / (√3 × kV)' };
}

function mvVoltageDrop(amps, lengthFt, r, x, phase, systemKv, pf) {
  const z = r * pf + x * Math.sqrt(Math.max(0, 1 - pf * pf));
  const mult = phase === '1ph' ? 2 : Math.sqrt(3);
  const volts = (mult * amps * lengthFt * z) / 1000;
  const systemV = systemKv * 1000;
  return { z: z, volts: volts, percent: (volts / systemV) * 100 };
}

function mvTypeString(pick) {
  const construction = pick.construction === '3c' ? '3/C'
    : pick.cn === '1/3' ? '3-1/C, 1/3 CN'
    : pick.cn === '1/6' ? '3-1/C, 1/6 CN'
    : pick.cn === 'full' ? '3-1/C, full CN'
    : '3-1/C';
  const insul = pick.insulation === 'epr' ? 'EPR' : 'TR-XLPE';
  const mat = pick.material === 'al' ? 'Al' : 'Cu';
  return construction + ' ' + wireSizeLabel(pick.size) + ' ' + mat + ' ' +
    pick.classKv + ' kV ' + pick.level + '% ' + insul + ' MV-' + pick.tempC;
}

function mvSelect(opts) {
  const load = mvLoadAmps(opts);
  const required = opts.continuous ? load.amps * 1.25 : load.amps;
  const suggestedClass = mvSuggestedClassKv(opts.systemKv);
  const classLow = opts.classKv + 1e-9 < opts.systemKv;
  const ranked = [];
  for (let i = 0; i < MV_SIZES.length; i++) {
    const size = MV_SIZES[i];
    const look = mvLookupAmpacity({
      size: size,
      material: opts.material,
      install: opts.install,
      construction: opts.construction,
      classKv: opts.classKv,
      tempC: opts.tempC,
    });
    const ampacity = opts.manualAmpacity > 0 && size === opts.manualSize ? opts.manualAmpacity : look.ampacity;
    if (ampacity == null) continue;
    if (ampacity < required) continue;
    const rx = mvRx(size, opts.material, opts.userR, opts.userX);
    let vd = null;
    if (rx.r != null) {
      vd = mvVoltageDrop(load.amps, opts.lengthFt, rx.r, rx.x, opts.phase, opts.systemKv, opts.powerFactor);
      if (vd.percent > opts.maxVdPct) continue;
    } else if (opts.requireVd) {
      continue;
    }
    ranked.push({
      size: size,
      ampacity: ampacity,
      cite: look.cite,
      vd: vd,
      rx: rx,
      typeString: mvTypeString({
        size: size,
        material: opts.material,
        classKv: opts.classKv,
        level: opts.level,
        insulation: opts.insulation,
        tempC: opts.tempC,
        construction: opts.construction,
        cn: opts.cn,
      }),
    });
  }
  return {
    load: load,
    required: required,
    suggestedClass: suggestedClass,
    classLow: classLow,
    ranked: ranked,
    selected: ranked.find(function (row) { return row.vd; }) || ranked[0] || null,
  };
}

window.mvSuggestedClassKv = mvSuggestedClassKv;
window.mvLoadAmps = mvLoadAmps;
window.mvVoltageDrop = mvVoltageDrop;
window.mvTypeString = mvTypeString;
window.mvSelect = mvSelect;
window.mvLookupAmpacity = mvLookupAmpacity;
window.MV_SIZES = MV_SIZES;
window.MV_CLASS_PRESETS = MV_CLASS_PRESETS;

window.loadMvTrevorExample = function () {
  const set = function (id, value) {
    const el = document.getElementById(id);
    if (el) el.value = value;
  };
  const check = function (id, on) {
    const el = document.getElementById(id);
    if (el) el.checked = on;
  };
  set('mv_phase', '3ph');
  set('mv_load_unit', 'kva');
  set('mv_load', '4000');
  set('mv_kv', '23.2');
  set('mv_length', '300');
  set('mv_class', '25');
  set('mv_insul', 'xlpe');
  set('mv_level', '133');
  set('mv_material', 'cu');
  set('mv_construction', '3x1c');
  set('mv_cn', '1/3');
  set('mv_temp', '105');
  set('mv_install', 'duct');
  set('mv_maxvd', '3');
  set('mv_pf', '0.9');
  check('mv_continuous', true);
  window.calcMvCable();
};

window.calcMvCable = function () {
  const el = typeof wtClear === 'function' ? wtClear('mv_result') : document.getElementById('mv_result');
  if (!el) return;

  const phase = document.getElementById('mv_phase').value;
  const loadUnit = document.getElementById('mv_load_unit').value;
  const loadValue = val('mv_load');
  const systemKv = val('mv_kv');
  const lengthFt = val('mv_length');
  const classKv = parseFloat(document.getElementById('mv_class').value);
  const insulation = document.getElementById('mv_insul').value;
  const level = parseInt(document.getElementById('mv_level').value, 10);
  const material = document.getElementById('mv_material').value;
  const construction = document.getElementById('mv_construction').value;
  const cn = document.getElementById('mv_cn').value;
  const tempC = parseInt(document.getElementById('mv_temp').value, 10);
  const install = document.getElementById('mv_install').value;
  const continuous = document.getElementById('mv_continuous').checked;
  const maxVdPct = val('mv_maxvd');
  const pf = val('mv_pf');
  const userR = val('mv_user_r');
  const userX = val('mv_user_x');
  const manualAmpacity = val('mv_manual_amp');

  if (!isPos(loadValue)) return showError('mv_result', 'Enter a load greater than zero.');
  if (!isPos(systemKv)) return showError('mv_result', 'Enter a system voltage in kV.');
  if (!isPos(lengthFt)) return showError('mv_result', 'Enter a one-way length.');
  if (!isPos(maxVdPct)) return showError('mv_result', 'Enter a maximum voltage-drop percent.');
  if (!isPos(pf) || pf > 1) return showError('mv_result', 'Power factor must be between 0 and 1.');
  if (install === 'tray') {
    if (!isPos(manualAmpacity)) {
      return showError('mv_result', 'Tray is not in the transcribed 310.60 / 311.60 excerpt. Enter ampacity from the cable datasheet.');
    }
  }

  const result = mvSelect({
    phase: phase,
    loadUnit: loadUnit,
    loadValue: loadValue,
    systemKv: systemKv,
    lengthFt: lengthFt,
    classKv: classKv,
    insulation: insulation,
    level: level,
    material: material,
    construction: construction,
    cn: cn,
    tempC: tempC,
    install: install,
    continuous: continuous,
    maxVdPct: maxVdPct,
    powerFactor: pf,
    userR: userR,
    userX: userX,
    requireVd: false,
    manualAmpacity: manualAmpacity,
    manualSize: document.getElementById('mv_manual_size') ? document.getElementById('mv_manual_size').value : '',
  });

  el.className = 'result show';
  wtHeading(el, 'Load current');
  wtRow(el, 'I_load', fmt(result.load.amps, 2) + ' A', { bold: true, color: PASS_COLOR });
  wtRow(el, 'Basis', result.load.basis + (loadUnit === 'kva' && phase === '3ph'
    ? ' = ' + fmt(loadValue, 1) + ' / (√3 × ' + fmt(systemKv, 2) + ')'
    : ''));
  if (continuous) wtRow(el, 'Required ampacity (×1.25)', fmt(result.required, 2) + ' A', { bold: true });
  else wtRow(el, 'Required ampacity', fmt(result.required, 2) + ' A');

  wtHeading(el, 'Voltage class');
  wtRow(el, 'System', fmt(systemKv, 2) + ' kV L-L');
  wtRow(el, 'Suggested class (≥ 100% of system)', result.suggestedClass + ' kV');
  wtRow(el, 'Selected class', classKv + ' kV',
    result.classLow ? { bold: true, color: FAIL_COLOR } : { bold: true, color: PASS_COLOR });
  if (result.classLow) {
    wtRow(el, 'Class check', classKv + ' kV is below system ' + fmt(systemKv, 2) + ' kV — too low',
      { bold: true, color: FAIL_COLOR });
  }

  wtHeading(el, 'Insulation level (you picked)');
  wtRow(el, 'Level', level + '%');
  wtRow(el, 'Meaning', level === 100
    ? '100% — typical solidly grounded wye, ground fault cleared ≤ 1 min'
    : '133% — ungrounded / impedance-grounded / longer ground-fault duration');

  if (!result.selected) {
    wtHeading(el, 'Selection');
    wtRow(el, 'Result', 'No listed size passes ampacity' + (maxVdPct ? ' and the VD limit' : ''),
      { color: FAIL_COLOR, bold: true });
    wtNote(el, 'Enter a datasheet ampacity, relax VD, or change installation. Tray and some 3/C + air/bury combinations are not in this excerpt.');
    appendCopyBtn(el);
    return;
  }

  const pick = result.selected;
  wtHeading(el, 'Selected conductor');
  el.lastElementChild.classList.add('cost-optimum');
  wtRow(el, 'Type string', pick.typeString, { bold: true, color: PASS_COLOR });
  wtRow(el, 'Table ampacity', fmt(pick.ampacity, 0) + ' A');
  wtRow(el, 'Ampacity source', pick.cite);
  if (pick.vd) {
    wtRow(el, 'Voltage drop', fmt(pick.vd.volts, 2) + ' V  (' + fmt(pick.vd.percent, 3) + ' %)');
    wtRow(el, 'VD math', 'ΔV = ' + (phase === '1ph' ? '2' : '√3') +
      ' × I × L × (R cosθ + X sinθ) / 1000');
    wtRow(el, 'R / X', fmt(pick.rx.r, 4) + ' / ' + fmt(pick.rx.x, 4) + ' Ω/kft  (' + pick.rx.source + ')');
  } else {
    wtRow(el, 'Voltage drop', 'Enter Ω/kft — no published R/X for this size/material',
      { color: WARN_COLOR });
  }

  wtHeading(el, 'Sizes that pass');
  result.ranked.slice(0, 8).forEach(function (row) {
    const vdText = row.vd ? fmt(row.vd.percent, 3) + '% VD' : 'no R/X';
    wtRow(el, row.typeString, fmt(row.ampacity, 0) + ' A  ·  ' + vdText,
      row === pick ? { color: PASS_COLOR, bold: true } : undefined);
  });

  wtNote(el,
    'Modeled comparison from the cited NEC 310.60 / 311.60 excerpt and optional Southwire R/X. ' +
    'Not a PE stamp, manufacturer ampacity letter, or bid. Pulling tension, sidewall pressure, ' +
    'and soil rho are not calculated. Related: transformer primary OCPD is 450.3 — that lives ' +
    'on the Transformer tool, not in this ampacity table. 110.40 termination temperature and ' +
    '300.37 / 300.50 installation rules still apply in the field.');
  appendCopyBtn(el);
};
