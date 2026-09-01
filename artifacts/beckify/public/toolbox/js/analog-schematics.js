/* Circuit schematics and transfer functions for the analog design workbench.
   Pure string-building SVG so it works offline with no dependencies. */
(function () {
  'use strict';

  const C = {
    wire: '#8fa3bf',
    part: '#e2e8f0',
    amp: '#8b7bff',
    label: '#94a3b8',
    hot: '#f5c451',
    node: '#cbd5f5',
  };

  // ── primitives ──────────────────────────────────────────────────────────
  const w = (x1, y1, x2, y2) => `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${C.wire}" stroke-width="2" stroke-linecap="round"/>`;
  /** Polyline through [x,y] pairs. */
  const poly = (pts) => `<polyline points="${pts.map((p) => p.join(',')).join(' ')}" fill="none" stroke="${C.wire}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>`;
  const dot = (x, y) => `<circle cx="${x}" cy="${y}" r="3.5" fill="${C.node}"/>`;
  const txt = (x, y, s, opts = {}) =>
    `<text x="${x}" y="${y}" fill="${opts.fill || C.label}" font-size="${opts.size || 12}" text-anchor="${opts.anchor || 'start'}" font-family="ui-monospace,SFMono-Regular,Menlo,monospace"${opts.weight ? ` font-weight="${opts.weight}"` : ''}>${s}</text>`;

  /** Horizontal resistor, 44 px long, centred on y. */
  const resH = (x, y, label) =>
    `<path d="M${x},${y} h7 l4,-9 l7,18 l7,-18 l7,18 l4,-9 h8" fill="none" stroke="${C.part}" stroke-width="2" stroke-linejoin="round"/>` +
    (label ? txt(x + 22, y - 14, label, { anchor: 'middle', fill: C.part }) : '');

  /** Vertical resistor, 44 px long, centred on x. */
  const resV = (x, y, label) =>
    `<path d="M${x},${y} v7 l-9,4 l18,7 l-18,7 l18,7 l-9,4 v8" fill="none" stroke="${C.part}" stroke-width="2" stroke-linejoin="round"/>` +
    (label ? txt(x + 14, y + 26, label, { fill: C.part }) : '');

  /** Horizontal capacitor, 26 px long. */
  const capH = (x, y, label) =>
    `<path d="M${x},${y} h10 M${x + 10},${y - 10} v20 M${x + 16},${y - 10} v20 M${x + 16},${y} h10" fill="none" stroke="${C.part}" stroke-width="2" stroke-linecap="round"/>` +
    (label ? txt(x + 13, y - 16, label, { anchor: 'middle', fill: C.part }) : '');

  /** Vertical capacitor, 26 px long. `left` puts the label on the other side. */
  const capV = (x, y, label, left) =>
    `<path d="M${x},${y} v10 M${x - 10},${y + 10} h20 M${x - 10},${y + 16} h20 M${x},${y + 16} v10" fill="none" stroke="${C.part}" stroke-width="2" stroke-linecap="round"/>` +
    (label ? txt(left ? x - 14 : x + 14, y + 20, label, { fill: C.part, anchor: left ? 'end' : 'start' }) : '');

  /** Horizontal inductor, 44 px long. */
  const indH = (x, y, label) =>
    `<path d="M${x},${y} h6 a6,6 0 0 1 8,0 a6,6 0 0 1 8,0 a6,6 0 0 1 8,0 a6,6 0 0 1 8,0 h6" fill="none" stroke="${C.part}" stroke-width="2"/>` +
    (label ? txt(x + 22, y - 12, label, { anchor: 'middle', fill: C.part }) : '');

  /** Ground symbol hanging from (x, y). */
  const gnd = (x, y) =>
    w(x, y, x, y + 12) +
    `<path d="M${x - 11},${y + 12} h22 M${x - 7},${y + 17} h14 M${x - 3},${y + 22} h6" stroke="${C.wire}" stroke-width="2" stroke-linecap="round"/>`;

  // A vertical resistor is 44 px tall and a vertical capacitor 26 px. Pairing a
  // component with its ground by hand meant guessing that length, which left
  // floating gaps; these place the ground exactly where the part ends.
  const RES_V_LEN = 44;
  const CAP_V_LEN = 26;
  const resVGnd = (x, y, label) => resV(x, y, label) + gnd(x, y + RES_V_LEN);
  const capVGnd = (x, y, label, left) => capV(x, y, label, left) + gnd(x, y + CAP_V_LEN);

  /**
   * Op-amp triangle with the input pins at (x, y-18) and (x, y+18) and the
   * output at (x+64, y). `invertTop` puts the − pin on top, which is how an
   * inverting stage is normally drawn.
   */
  const amp = (x, y, invertTop = true) => {
    const top = invertTop ? '−' : '+';
    const bottom = invertTop ? '+' : '−';
    return (
      `<path d="M${x},${y - 34} L${x},${y + 34} L${x + 64},${y} Z" fill="rgba(139,123,255,0.10)" stroke="${C.amp}" stroke-width="2" stroke-linejoin="round"/>` +
      txt(x + 9, y - 13, top, { fill: C.amp, size: 15, weight: 700 }) +
      txt(x + 9, y + 22, bottom, { fill: C.amp, size: 15, weight: 700 })
    );
  };

  /** Labelled block, for stages drawn functionally rather than device-by-device. */
  const block = (x, y, bw, bh, label, sub) =>
    `<rect x="${x}" y="${y}" width="${bw}" height="${bh}" rx="8" fill="rgba(139,123,255,0.10)" stroke="${C.amp}" stroke-width="2"/>` +
    txt(x + bw / 2, y + (sub ? bh / 2 : bh / 2 + 5), label, { anchor: 'middle', fill: C.part, size: 15, weight: 700 }) +
    (sub ? txt(x + bw / 2, y + bh / 2 + 18, sub, { anchor: 'middle', size: 11 }) : '');

  /** Arrowhead pointing right at (x, y). */
  const arrow = (x, y) => `<path d="M${x - 8},${y - 5} L${x},${y} L${x - 8},${y + 5}" fill="none" stroke="${C.wire}" stroke-width="2" stroke-linejoin="round"/>`;

  /** Labelled terminal marker. */
  const term = (x, y, label, anchor) =>
    `<circle cx="${x}" cy="${y}" r="4" fill="none" stroke="${C.hot}" stroke-width="2"/>` +
    txt(anchor === 'end' ? x - 9 : x + 9, y + 4, label, { fill: C.hot, anchor: anchor === 'end' ? 'end' : 'start' });

  const svg = (body, h = 260) =>
    `<svg viewBox="0 0 560 ${h}" role="img" aria-label="Circuit schematic" preserveAspectRatio="xMidYMid meet">${body}</svg>`;

  // ── op-amp schematics ───────────────────────────────────────────────────
  // Shared geometry: inverting node at x=210, op-amp body starts x=250,
  // output rail at x=360.
  const AX = 250; // amp left edge
  const AY = 120; // amp centre line
  const NEG = AY - 18; // inverting pin y
  const POS = AY + 18; // non-inverting pin y
  const OUT = AX + 64; // output x

  /**
   * Feedback path from the inverting node up, through the component, and back
   * down to the output. x1/x2 are where the component itself starts and ends,
   * so the connecting wires actually meet it instead of floating.
   */
  const feedback = (part, x1, x2) =>
    poly([[210, NEG], [210, 40]]) +
    w(210, 40, x1, 40) +
    part +
    w(x2, 40, 380, 40) +
    poly([[380, 40], [380, AY]]) +
    w(OUT, AY, 380, AY) +
    dot(380, AY);

  const opAmpSchematics = {
    inverting: () =>
      svg(
        term(40, NEG, 'Vin', 'end') + w(44, NEG, 90, NEG) + resH(90, NEG, 'Rin') + w(134, NEG, 210, NEG) + dot(210, NEG) +
        feedback(resH(268, 40, 'Rf'), 268, 312) +
        w(210, NEG, AX, NEG) + amp(AX, AY) +
        w(AX, POS, 200, POS) + gnd(200, POS) +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 232, 'Vout = −(Rf / Rin) · Vin', { fill: C.part, size: 13 }),
      ),
    noninverting: () =>
      svg(
        term(40, POS, 'Vin', 'end') + w(44, POS, AX, POS) + amp(AX, AY, true) +
        feedback(resH(268, 40, 'Rf'), 268, 312) +
        w(210, NEG, AX, NEG) + dot(210, NEG) +
        poly([[210, NEG], [150, NEG]]) + poly([[150, NEG], [150, 168]]) + resVGnd(150, 168, 'Rg') +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 244, 'Vout = (1 + Rf / Rg) · Vin', { fill: C.part, size: 13 }),
        270,
      ),
    difference: () =>
      svg(
        term(30, NEG, 'V₁', 'end') + w(34, NEG, 80, NEG) + resH(80, NEG, 'R₁') + w(124, NEG, 210, NEG) + dot(210, NEG) +
        feedback(resH(268, 40, 'R₂'), 268, 312) +
        w(210, NEG, AX, NEG) + amp(AX, AY) +
        term(30, POS, 'V₂', 'end') + w(34, POS, 80, POS) + resH(80, POS, 'R₃') + w(124, POS, AX, POS) + dot(180, POS) +
        poly([[180, POS], [180, 186]]) + resVGnd(180, 186, 'R₄') +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 282, 'Vout = (R₂/R₁)(V₂ − V₁) when R₂/R₁ = R₄/R₃', { fill: C.part, size: 13 }),
        300,
      ),
    summing: () =>
      svg(
        term(30, 70, 'V₁', 'end') + w(34, 70, 78, 70) + resH(78, 70, 'R₁') + w(122, 70, 210, 70) +
        term(30, 120, 'V₂', 'end') + w(34, 120, 78, 120) + resH(78, 120, 'R₂') + w(122, 120, 210, 120) +
        poly([[210, 70], [210, NEG]]) + poly([[210, 120], [210, NEG]]) + dot(210, 70) + dot(210, 120) + dot(210, NEG) +
        feedback(resH(268, 40, 'Rf'), 268, 312) +
        w(210, NEG, AX, NEG) + amp(AX, AY) +
        w(AX, POS, 200, POS) + gnd(200, POS) +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 240, 'Vout = −Rf · (V₁/R₁ + V₂/R₂)', { fill: C.part, size: 13 }),
        265,
      ),
    transimpedance: () =>
      svg(
        `<circle cx="70" cy="${NEG}" r="16" fill="none" stroke="${C.hot}" stroke-width="2"/>` +
        `<path d="M70,${NEG - 8} v16 M64,${NEG + 2} l6,6 l6,-6" fill="none" stroke="${C.hot}" stroke-width="2"/>` +
        txt(70, NEG + 34, 'Iin', { anchor: 'middle', fill: C.hot }) +
        w(86, NEG, 210, NEG) + dot(210, NEG) +
        poly([[210, NEG], [210, 40]]) + w(210, 40, 268, 40) + resH(268, 40, 'Rf') + w(312, 40, 380, 40) + poly([[380, 40], [380, AY]]) +
        poly([[210, NEG], [210, 78]]) + w(210, 78, 268, 78) + capH(268, 78, 'Cf') + w(294, 78, 380, 78) + poly([[380, 78], [380, AY]]) +
        w(OUT, AY, 380, AY) + dot(380, AY) +
        w(210, NEG, AX, NEG) + amp(AX, AY) +
        w(AX, POS, 200, POS) + gnd(200, POS) +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 232, 'Vout = −Iin · Rf   ·   pole at 1 / (2π Rf Cf)', { fill: C.part, size: 13 }),
      ),
    integrator: () =>
      svg(
        term(40, NEG, 'Vin', 'end') + w(44, NEG, 90, NEG) + resH(90, NEG, 'R') + w(134, NEG, 210, NEG) + dot(210, NEG) +
        feedback(capH(277, 40, 'C'), 277, 303) +
        w(210, NEG, AX, NEG) + amp(AX, AY) +
        w(AX, POS, 200, POS) + gnd(200, POS) +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 232, 'Vout = −(1 / RC) ∫ Vin dt      H(s) = −1 / (sRC)', { fill: C.part, size: 13 }),
      ),
    differentiator: () =>
      svg(
        term(40, NEG, 'Vin', 'end') + w(44, NEG, 99, NEG) + capH(99, NEG, 'C') + w(125, NEG, 210, NEG) + dot(210, NEG) +
        feedback(resH(268, 40, 'Rf'), 268, 312) +
        w(210, NEG, AX, NEG) + amp(AX, AY) +
        w(AX, POS, 200, POS) + gnd(200, POS) +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 232, 'Vout = −Rf C dVin/dt      H(s) = −sRf C', { fill: C.part, size: 13 }),
      ),
    comparator: () =>
      svg(
        term(40, POS, 'Vin', 'end') + w(44, POS, AX, POS) +
        term(40, NEG, 'Vref', 'end') + w(44, NEG, AX, NEG) +
        amp(AX, AY) +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 232, 'Vout = HIGH when Vin > Vref, otherwise LOW', { fill: C.part, size: 13 }),
      ),
    schmitt: () =>
      svg(
        term(40, NEG, 'Vin', 'end') + w(44, NEG, AX, NEG) +
        amp(AX, AY) +
        // positive feedback divider: output → R_top → (+) node → R_bottom → gnd
        w(AX, POS, 170, POS) + dot(170, POS) +
        poly([[170, POS], [170, 60]]) + w(170, 60, 268, 60) + resH(268, 60, 'R top') + w(312, 60, 400, 60) + poly([[400, 60], [400, AY]]) +
        w(OUT, AY, 400, AY) + dot(400, AY) +
        poly([[170, POS], [170, 186]]) + resVGnd(170, 186, 'R bottom') +
        w(OUT, AY, 470, AY) + term(474, AY, 'Vout') +
        txt(20, 282, 'β = R_bottom / (R_top + R_bottom);  thresholds = β · Vout', { fill: C.part, size: 13 }),
        300,
      ),
    instrumentation: () =>
      svg(
        // Input stage drawn at component level, since RG is what sets the gain;
        // the matched difference stage that follows is shown as a block.
        term(30, 42, 'V₂', 'end') + w(34, 42, 150, 42) + amp(150, 60, false) +
        term(30, 228, 'V₁', 'end') + w(34, 228, 150, 228) + amp(150, 210, true) +
        // RG bridges the two inverting inputs
        w(150, 78, 110, 78) + dot(110, 78) + poly([[110, 78], [110, 101]]) + resV(110, 101, 'RG') +
        poly([[110, 145], [110, 192]]) + dot(110, 192) + w(110, 192, 150, 192) +
        // matched feedback resistors, one per buffer
        poly([[214, 60], [214, 26]]) + w(214, 26, 160, 26) + resH(116, 26, 'R') + w(110, 26, 116, 26) + poly([[110, 26], [110, 78]]) +
        poly([[214, 210], [214, 244]]) + w(214, 244, 160, 244) + resH(116, 244, 'R') + w(110, 244, 116, 244) + poly([[110, 244], [110, 192]]) +
        dot(214, 60) + dot(214, 210) +
        // into the difference stage
        w(214, 60, 300, 60) + arrow(306, 60) +
        w(214, 210, 300, 210) + arrow(306, 210) +
        block(308, 100, 108, 70, 'Diff amp', 'unity, matched R') +
        w(416, 135, 470, 135) + term(474, 135, 'Vout') +
        poly([[306, 60], [306, 100]]) + poly([[306, 210], [306, 170]]) +
        txt(20, 288, 'Vout = (1 + 2R / RG) · (V₂ − V₁)', { fill: C.part, size: 13 }),
        305,
      ),
  };

  // ── filter schematics ───────────────────────────────────────────────────
  const filterSchematics = {
    'rc-low': () =>
      svg(
        term(40, 90, 'Vin', 'end') + w(44, 90, 130, 90) + resH(130, 90, 'R') + w(174, 90, 300, 90) + dot(300, 90) +
        poly([[300, 90], [300, 116]]) + capVGnd(300, 116, 'C') +
        w(300, 90, 440, 90) + term(444, 90, 'Vout') +
        txt(20, 215, 'H(s) = 1 / (1 + sRC)        f₀ = 1 / (2πRC)', { fill: C.part, size: 13 }),
        240,
      ),
    'rc-high': () =>
      svg(
        term(40, 90, 'Vin', 'end') + w(44, 90, 139, 90) + capH(139, 90, 'C') + w(165, 90, 300, 90) + dot(300, 90) +
        poly([[300, 90], [300, 116]]) + resVGnd(300, 116, 'R') +
        w(300, 90, 440, 90) + term(444, 90, 'Vout') +
        txt(20, 225, 'H(s) = sRC / (1 + sRC)        f₀ = 1 / (2πRC)', { fill: C.part, size: 13 }),
        250,
      ),
    'sk-low': () =>
      svg(
        term(24, 110, 'Vin', 'end') + w(28, 110, 70, 110) + resH(70, 110, 'R₁') + w(114, 110, 150, 110) + dot(150, 110) +
        resH(150, 110, 'R₂') + w(194, 110, 250, 110) + dot(226, 110) +
        // C2 from the + node to ground
        poly([[226, 110], [226, 140]]) + capVGnd(226, 140, 'C₂', true) +
        // C1 from the mid node up to the output (the Sallen-Key feedback)
        poly([[150, 110], [150, 46]]) + capH(240, 46, 'C₁') + poly([[266, 46], [400, 46]]) + poly([[400, 46], [400, 128]]) +
        w(150, 46, 240, 46) +
        // Unity-gain buffer: the inverting input ties to the output, not ground.
        amp(250, 128, false) +
        poly([[250, 146], [244, 146]]) + poly([[244, 146], [244, 218]]) + poly([[244, 218], [400, 218]]) + poly([[400, 218], [400, 128]]) +
        w(314, 128, 400, 128) + dot(400, 128) + w(400, 128, 470, 128) + term(474, 128, 'Vout') +
        txt(20, 246, 'H(s) = K ω₀² / (s² + (ω₀/Q)s + ω₀²)', { fill: C.part, size: 13 }),
        270,
      ),
    'sk-high': () =>
      svg(
        term(24, 110, 'Vin', 'end') + w(28, 110, 79, 110) + capH(79, 110, 'C₁') + w(105, 110, 150, 110) + dot(150, 110) +
        capH(150, 110, 'C₂') + w(176, 110, 250, 110) + dot(226, 110) +
        poly([[226, 110], [226, 140]]) + resVGnd(226, 140, 'R₂') +
        poly([[150, 110], [150, 46]]) + resH(230, 46, 'R₁') + poly([[274, 46], [400, 46]]) + poly([[400, 46], [400, 128]]) +
        w(150, 46, 230, 46) +
        // Unity-gain buffer: the inverting input ties to the output, not ground.
        amp(250, 128, false) +
        poly([[250, 146], [244, 146]]) + poly([[244, 146], [244, 232]]) + poly([[244, 232], [400, 232]]) + poly([[400, 232], [400, 128]]) +
        w(314, 128, 400, 128) + dot(400, 128) + w(400, 128, 470, 128) + term(474, 128, 'Vout') +
        txt(20, 266, 'H(s) = K s² / (s² + (ω₀/Q)s + ω₀²)', { fill: C.part, size: 13 }),
        290,
      ),
    'rlc-band': () =>
      svg(
        term(30, 80, 'Vin', 'end') + w(34, 80, 90, 80) + indH(90, 80, 'L') + w(134, 80, 170, 80) +
        capH(170, 80, 'C') + w(196, 80, 320, 80) + dot(320, 80) +
        poly([[320, 80], [320, 106]]) + resVGnd(320, 106, 'R') +
        w(320, 80, 450, 80) + term(454, 80, 'Vout') +
        txt(20, 214, 'H(s) = (ω₀/Q)s / (s² + (ω₀/Q)s + ω₀²)   ·   output across R', { fill: C.part, size: 13 }) +
        txt(20, 234, 'ω₀ = 1/√(LC),  Q = (1/R)·√(L/C)', { fill: C.label, size: 12 }),
        250,
      ),
    'rlc-notch': () =>
      svg(
        term(30, 80, 'Vin', 'end') + w(34, 80, 90, 80) + resH(90, 80, 'R') + w(134, 80, 320, 80) + dot(320, 80) +
        // parallel LC trap to ground
        poly([[320, 80], [270, 80]]) + poly([[270, 80], [270, 112]]) + resV(270, 112, '') +
        poly([[320, 80], [370, 80]]) + poly([[370, 80], [370, 112]]) +
        indH(248, 130, 'L') + capV(370, 112, 'C') +
        poly([[270, 156], [270, 178]]) + poly([[370, 148], [370, 178]]) + w(270, 178, 370, 178) + gnd(320, 178) +
        w(320, 80, 450, 80) + term(454, 80, 'Vout') +
        txt(20, 228, 'H(s) = (s² + ω₀²) / (s² + (ω₀/Q)s + ω₀²)', { fill: C.part, size: 13 }),
        250,
      ),
    'mfb-band': () =>
      svg(
        term(24, 96, 'Vin', 'end') + w(28, 96, 64, 96) + resH(64, 96, 'R₁') + w(108, 96, 150, 96) + dot(150, 96) +
        poly([[150, 96], [150, 140]]) + resVGnd(150, 140, 'R₂') +
        w(150, 96, 176, 96) + capH(176, 96, 'C₁') + w(202, 96, 230, 96) + dot(230, 96) +
        // C2 and R3 feedback around the amp
        poly([[230, 96], [230, 40]]) + capH(290, 40, 'C₂') + poly([[316, 40], [404, 40]]) + poly([[404, 40], [404, 114]]) +
        w(230, 40, 290, 40) +
        poly([[230, 96], [230, 68]]) + w(230, 68, 268, 68) + resH(268, 68, 'R₃') + w(312, 68, 404, 68) + dot(404, 68) +
        // amp centred at 114 so the inverting pin lands on the 96 signal rail
        w(230, 96, 254, 96) + amp(254, 114) + w(254, 132, 218, 132) + poly([[218, 132], [218, 190]]) + gnd(218, 190) +
        w(318, 114, 404, 114) + dot(404, 114) + w(404, 114, 470, 114) + term(474, 114, 'Vout') +
        txt(20, 246, 'H(s) = −K (ω₀/Q)s / (s² + (ω₀/Q)s + ω₀²)', { fill: C.part, size: 13 }),
        265,
      ),
    'state-variable': () =>
      svg(
        // Drawn as the signal-flow structure it is: one summer, two cascaded
        // integrators, and feedback from the BP and LP taps setting Q and ω₀.
        term(24, 90, 'Vin', 'end') + w(28, 90, 78, 90) + arrow(84, 90) +
        block(86, 62, 66, 56, 'Σ', 'summer') +
        w(152, 90, 186, 90) + arrow(192, 90) + dot(170, 90) +
        poly([[170, 90], [170, 40]]) + term(170, 36, 'HP', 'start') +
        block(194, 62, 66, 56, '∫', '1 / sRC') +
        w(260, 90, 300, 90) + arrow(306, 90) + dot(284, 90) +
        poly([[284, 90], [284, 40]]) + term(284, 36, 'BP', 'start') +
        block(308, 62, 66, 56, '∫', '1 / sRC') +
        w(374, 90, 430, 90) + dot(408, 90) + term(434, 90, 'LP') +
        // feedback: BP sets Q, LP closes the resonant loop
        poly([[284, 90], [284, 158]]) + poly([[284, 158], [119, 158]]) + poly([[119, 158], [119, 118]]) + arrow(119, 116) +
        txt(196, 154, 'Q feedback', { size: 11 }) +
        poly([[408, 90], [408, 196]]) + poly([[408, 196], [104, 196]]) + poly([[104, 196], [104, 118]]) + arrow(104, 116) +
        txt(230, 192, 'ω₀ feedback', { size: 11 }) +
        txt(20, 238, 'One resonator, three simultaneous outputs sharing ω₀ and Q', { fill: C.part, size: 12 }) +
        txt(20, 256, 'H_BP(s) = K (ω₀/Q)s / (s² + (ω₀/Q)s + ω₀²)', { fill: C.part, size: 13 }),
        275,
      ),
    'twin-t': () =>
      svg(
        term(24, 74, 'Vin', 'end') + w(28, 74, 70, 74) + dot(70, 74) +
        // top branch: R - R with C/2 to ground at the midpoint
        w(70, 74, 110, 74) + resH(110, 74, 'R') + w(154, 74, 190, 74) + dot(190, 74) + resH(190, 74, 'R') + w(234, 74, 330, 74) +
        poly([[190, 74], [190, 100]]) + capVGnd(190, 100, '2C') +
        // bottom branch: C - C with 2R to ground at the midpoint
        poly([[70, 74], [70, 168]]) + w(70, 168, 119, 168) + capH(119, 168, 'C') + w(145, 168, 190, 168) + dot(190, 168) +
        capH(190, 168, 'C') + w(216, 168, 330, 168) +
        poly([[190, 168], [190, 194]]) + resVGnd(190, 194, 'R/2') +
        poly([[330, 74], [330, 168]]) + dot(330, 121) +
        w(330, 121, 460, 121) + term(464, 121, 'Vout') +
        txt(20, 288, 'H(s) = (s² + ω₀²) / (s² + (ω₀/Q)s + ω₀²)      ω₀ = 1 / (2πRC)', { fill: C.part, size: 13 }),
        310,
      ),
    allpass: () =>
      svg(
        // Amp centred at 108: inverting pin at 90, non-inverting at 126.
        term(24, 90, 'Vin', 'end') + w(28, 90, 60, 90) + dot(60, 90) +
        // inverting side: series R into the summing node, equal R in feedback
        w(60, 90, 96, 90) + resH(96, 90, 'R') + w(140, 90, 210, 90) + dot(210, 90) + w(210, 90, 250, 90) +
        poly([[210, 90], [210, 26]]) + w(210, 26, 268, 26) + resH(268, 26, 'R') + w(312, 26, 400, 26) + poly([[400, 26], [400, 108]]) +
        // non-inverting side: R₁ to the + pin with C to ground — this RC sets the phase
        poly([[60, 90], [60, 126]]) + w(60, 126, 118, 126) + resH(118, 126, 'R₁') + w(162, 126, 250, 126) + dot(214, 126) +
        poly([[214, 126], [214, 150]]) + capVGnd(214, 150, 'C') +
        amp(250, 108) +
        w(314, 108, 400, 108) + dot(400, 108) + w(400, 108, 470, 108) + term(474, 108, 'Vout') +
        txt(20, 236, 'H(s) = (1 − sR₁C) / (1 + sR₁C)   ·   flat gain, phase sweeps 0° → −180°', { fill: C.part, size: 12 }),
        260,
      ),
  };

  // ── transfer functions ──────────────────────────────────────────────────
  const opAmpTransfer = {
    inverting: { h: 'Vout / Vin = − Rf / Rin', note: 'Ideal, frequency-independent below the gain-bandwidth limit.' },
    noninverting: { h: 'Vout / Vin = 1 + Rf / Rg', note: 'Gain can never be less than 1 in this topology.' },
    difference: { h: 'Vout = (R₂/R₁)(V₂ − V₁)', note: 'Only valid while R₂/R₁ = R₄/R₃; mismatch is what limits CMRR.' },
    summing: { h: 'Vout = −Rf (V₁/R₁ + V₂/R₂)', note: 'Each input scales independently — a weighted analog sum.' },
    transimpedance: { h: 'Vout / Iin = −Rf,   pole at f = 1 / (2π Rf Cf)', note: 'Cf sets the bandwidth and stabilises the stage against the source capacitance.' },
    integrator: { h: 'H(s) = −1 / (s R C)', note: 'Gain falls at −20 dB/decade; a DC path around C is needed in practice.' },
    differentiator: { h: 'H(s) = −s Rf C', note: 'Gain rises at +20 dB/decade, so it amplifies high-frequency noise.' },
    comparator: { h: 'Vout = HIGH if Vin > Vref, else LOW', note: 'No linear transfer function — the device is saturated by design.' },
    schmitt: { h: 'V_TH = β·V_HIGH,  V_TL = β·V_LOW,  β = R_bottom / (R_top + R_bottom)', note: 'Positive feedback splits the threshold into two, giving noise immunity.' },
    instrumentation: { h: 'Vout = (1 + 2R / RG)(V₂ − V₁)', note: 'A single resistor sets gain while keeping both inputs high-impedance.' },
  };

  const filterTransfer = {
    'rc-low': { h: 'H(s) = 1 / (1 + sRC)', order: 1, roll: '−20 dB/decade above f₀' },
    'rc-high': { h: 'H(s) = sRC / (1 + sRC)', order: 1, roll: '+20 dB/decade below f₀' },
    'sk-low': { h: 'H(s) = K·ω₀² / (s² + (ω₀/Q)s + ω₀²)', order: 2, roll: '−40 dB/decade above f₀' },
    'sk-high': { h: 'H(s) = K·s² / (s² + (ω₀/Q)s + ω₀²)', order: 2, roll: '+40 dB/decade below f₀' },
    'rlc-band': { h: 'H(s) = K·(ω₀/Q)s / (s² + (ω₀/Q)s + ω₀²)', order: 2, roll: '−20 dB/decade either side of f₀' },
    'rlc-notch': { h: 'H(s) = K·(s² + ω₀²) / (s² + (ω₀/Q)s + ω₀²)', order: 2, roll: 'deep null at f₀, flat elsewhere' },
    'mfb-band': { h: 'H(s) = −K·(ω₀/Q)s / (s² + (ω₀/Q)s + ω₀²)', order: 2, roll: '−20 dB/decade either side of f₀' },
    'state-variable': { h: 'H_BP(s) = K·(ω₀/Q)s / (s² + (ω₀/Q)s + ω₀²)', order: 2, roll: 'LP, BP and HP available at once' },
    'twin-t': { h: 'H(s) = K·(s² + ω₀²) / (s² + (ω₀/Q)s + ω₀²)', order: 2, roll: 'deep null at f₀, flat elsewhere' },
    allpass: { h: 'H(s) = (1 − sR₁C) / (1 + sR₁C)', order: 1, roll: 'flat magnitude, phase 0° → −180°' },
  };

  /** Substitute the designed ω₀, Q and K into the symbolic form. */
  function substituted(type, f0, q, gain) {
    const w0 = 2 * Math.PI * f0;
    const n = (v) => Number(v).toLocaleString('en-US', { maximumFractionDigits: 1 });
    const info = filterTransfer[type];
    if (!info) return '';
    if (info.order === 1) {
      if (type === 'allpass') return `H(s) = (1 − s/${n(w0)}) / (1 + s/${n(w0)})`;
      const tau = 1 / w0;
      return type === 'rc-low'
        ? `H(s) = 1 / (1 + ${tau.toExponential(2)}·s)`
        : `H(s) = ${tau.toExponential(2)}·s / (1 + ${tau.toExponential(2)}·s)`;
    }
    const bw = w0 / q;
    const w0sq = w0 * w0;
    if (type === 'rlc-notch' || type === 'twin-t') return `H(s) = ${n(gain)}·(s² + ${n(w0sq)}) / (s² + ${n(bw)}s + ${n(w0sq)})`;
    if (type === 'sk-high') return `H(s) = ${n(gain)}·s² / (s² + ${n(bw)}s + ${n(w0sq)})`;
    if (type === 'sk-low') return `H(s) = ${n(gain * w0sq)} / (s² + ${n(bw)}s + ${n(w0sq)})`;
    // The state-variable filter has three simultaneous outputs, so name the one
    // being plotted rather than implying a single H(s).
    const name = type === 'state-variable' ? 'H_BP(s)' : 'H(s)';
    const sign = type === 'mfb-band' ? '−' : ''; // multiple-feedback band-pass inverts
    return `${name} = ${sign}${n(gain * bw)}·s / (s² + ${n(bw)}s + ${n(w0sq)})`;
  }

  /** Phase in degrees at normalised frequency x = f / f₀. */
  function phaseDeg(type, x, q) {
    const deg = (r) => (r * 180) / Math.PI;
    const quad = Math.atan2(x / q, 1 - x * x); // phase of the 2nd-order denominator
    if (type === 'rc-low') return -deg(Math.atan(x));
    if (type === 'rc-high') return 90 - deg(Math.atan(x));
    if (type === 'allpass') return -2 * deg(Math.atan(x));
    if (type === 'sk-low') return -deg(quad);
    if (type === 'sk-high') return 180 - deg(quad);
    if (type === 'rlc-notch' || type === 'twin-t') return (1 - x * x >= 0 ? 0 : 180) - deg(quad);
    if (type === 'mfb-band') return 180 + 90 - deg(quad); // inverting band-pass
    return 90 - deg(quad); // band-pass family
  }

  window.AnalogSchematics = {
    opAmp: (type) => (opAmpSchematics[type] || (() => ''))(),
    filter: (type) => (filterSchematics[type] || (() => ''))(),
    opAmpTransfer: (type) => opAmpTransfer[type] || null,
    filterTransfer: (type) => filterTransfer[type] || null,
    substituted,
    phaseDeg,
  };
}());
