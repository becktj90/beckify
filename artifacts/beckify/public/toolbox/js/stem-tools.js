(function () {
  'use strict';

  const SVG_NS = 'http://www.w3.org/2000/svg';
  const COLORS = {
    bg: '#0d1117',
    accent: '#8b7bff',
    green: '#6ee7b7',
    red: '#ff8a8a',
    yellow: '#f5c451',
    blue: '#60a5fa',
    text: '#e6edf3',
    muted: 'rgba(230,237,243,0.7)',
    line: 'rgba(139,123,255,0.35)'
  };

  const CONST = {
    h: 6.626e-34,
    hbar: 1.055e-34,
    me: 9.109e-31,
    mp: 1.673e-27,
    mn: 1.675e-27,
    c: 2.998e8,
    e_charge: 1.602e-19,
    k_B: 1.381e-23,
    R_gas: 8.314,
    R_atm: 0.082057,
    NA: 6.022e23
  };

  const ATOMIC_MASS = {
    H: 1.008, He: 4.003, Li: 6.941, Be: 9.012, B: 10.811, C: 12.011,
    N: 14.007, O: 15.999, F: 18.998, Ne: 20.180, Na: 22.990, Mg: 24.305,
    Al: 26.982, Si: 28.086, P: 30.974, S: 32.065, Cl: 35.453, Ar: 39.948,
    K: 39.098, Ca: 40.078, Fe: 55.845, Cu: 63.546, Zn: 65.38, Br: 79.904,
    Ag: 107.868, I: 126.904, Au: 196.967, Pb: 207.2
  };

  const PERIODIC20 = [
    ['H', 'Hydrogen', 1, 1.008], ['He', 'Helium', 2, 4.003], ['Li', 'Lithium', 3, 6.941],
    ['Be', 'Beryllium', 4, 9.012], ['B', 'Boron', 5, 10.811], ['C', 'Carbon', 6, 12.011],
    ['N', 'Nitrogen', 7, 14.007], ['O', 'Oxygen', 8, 15.999], ['F', 'Fluorine', 9, 18.998],
    ['Ne', 'Neon', 10, 20.18], ['Na', 'Sodium', 11, 22.99], ['Mg', 'Magnesium', 12, 24.305],
    ['Al', 'Aluminum', 13, 26.982], ['Si', 'Silicon', 14, 28.086], ['P', 'Phosphorus', 15, 30.974],
    ['S', 'Sulfur', 16, 32.065], ['Cl', 'Chlorine', 17, 35.453], ['Ar', 'Argon', 18, 39.948],
    ['K', 'Potassium', 19, 39.098], ['Ca', 'Calcium', 20, 40.078]
  ];

  const PERIODIC_FULL = ('H Hydrogen|He Helium|Li Lithium|Be Beryllium|B Boron|C Carbon|N Nitrogen|O Oxygen|F Fluorine|Ne Neon|' +
    'Na Sodium|Mg Magnesium|Al Aluminum|Si Silicon|P Phosphorus|S Sulfur|Cl Chlorine|Ar Argon|K Potassium|Ca Calcium|' +
    'Sc Scandium|Ti Titanium|V Vanadium|Cr Chromium|Mn Manganese|Fe Iron|Co Cobalt|Ni Nickel|Cu Copper|Zn Zinc|' +
    'Ga Gallium|Ge Germanium|As Arsenic|Se Selenium|Br Bromine|Kr Krypton|Rb Rubidium|Sr Strontium|Y Yttrium|Zr Zirconium|' +
    'Nb Niobium|Mo Molybdenum|Tc Technetium|Ru Ruthenium|Rh Rhodium|Pd Palladium|Ag Silver|Cd Cadmium|In Indium|Sn Tin|' +
    'Sb Antimony|Te Tellurium|I Iodine|Xe Xenon|Cs Cesium|Ba Barium|La Lanthanum|Ce Cerium|Pr Praseodymium|Nd Neodymium|' +
    'Pm Promethium|Sm Samarium|Eu Europium|Gd Gadolinium|Tb Terbium|Dy Dysprosium|Ho Holmium|Er Erbium|Tm Thulium|Yb Ytterbium|' +
    'Lu Lutetium|Hf Hafnium|Ta Tantalum|W Tungsten|Re Rhenium|Os Osmium|Ir Iridium|Pt Platinum|Au Gold|Hg Mercury|' +
    'Tl Thallium|Pb Lead|Bi Bismuth|Po Polonium|At Astatine|Rn Radon|Fr Francium|Ra Radium|Ac Actinium|Th Thorium|' +
    'Pa Protactinium|U Uranium|Np Neptunium|Pu Plutonium|Am Americium|Cm Curium|Bk Berkelium|Cf Californium|Es Einsteinium|Fm Fermium|' +
    'Md Mendelevium|No Nobelium|Lr Lawrencium|Rf Rutherfordium|Db Dubnium|Sg Seaborgium|Bh Bohrium|Hs Hassium|Mt Meitnerium|' +
    'Ds Darmstadtium|Rg Roentgenium|Cn Copernicium|Nh Nihonium|Fl Flerovium|Mc Moscovium|Lv Livermorium|Ts Tennessine|Og Oganesson')
    .split('|').map((entry, index) => {
      const parts = entry.split(' ');
      return { symbol: parts[0], name: parts.slice(1).join(' '), number: index + 1 };
    });

  const PERIODIC_ROWS = [
    [1, 18], [3, 10], [11, 18], [19, 36], [37, 54], [55, 86], [87, 118]
  ];
  const ELEMENT_COLORS = ['#8b7bff', '#60a5fa', '#6ee7b7', '#f5c451', '#ff8a8a'];
  function elementCategory(number) {
    if ([1, 2, 6, 7, 8, 9, 15, 16, 17, 34, 35, 53].indexOf(number) >= 0) return 1;
    if ([3, 11, 19, 37, 55, 87].indexOf(number) >= 0) return 2;
    if ([4, 12, 20, 38, 56, 88].indexOf(number) >= 0) return 3;
    if (number >= 57 && number <= 71 || number >= 89 && number <= 103) return 4;
    return 0;
  }

  const REFRACTIVE = [
    ['Air', 1.0003], ['Water', 1.333], ['Glass', 1.5], ['Diamond', 2.417]
  ];

  const PHOTO_METALS = {
    Cs: 2.1,
    Na: 2.36,
    Al: 4.08,
    Cu: 4.7,
    Au: 5.1
  };

  function fmtNum(n, d) {
    if (typeof window.fmt === 'function') return window.fmt(n, d == null ? 4 : d);
    if (!isFinite(n)) return '—';
    return String(parseFloat(Number(n).toFixed(d == null ? 4 : d)));
  }

  function defined(v) { return typeof v !== 'undefined' && v !== null; }
  function finite(v) { return Number.isFinite(v); }
  function nz(v, eps) { return Math.abs(v) < (eps || 1e-10); }
  function rad(deg) { return deg * Math.PI / 180; }
  function deg(radVal) { return radVal * 180 / Math.PI; }
  function clamp(x, a, b) { return Math.min(b, Math.max(a, x)); }
  function factorial(n) { let r = 1; for (let i = 2; i <= n; i++) r *= i; return r; }
  function gcd(a, b) { a = Math.abs(a); b = Math.abs(b); while (b) { const t = b; b = a % b; a = t; } return a || 1; }

  function sanitizeExpr(expr) {
    const s0 = String(expr || '').trim();
    if (!s0) throw new Error('Enter an expression.');
    if (/[;\[\]{}\\]/.test(s0)) throw new Error('Unsupported characters in expression.');
    if (/(?:window|document|constructor|prototype|__proto__|Function|eval|fetch|XMLHttpRequest|while|for|class|=>)/i.test(s0)) {
      throw new Error('Unsupported token in expression.');
    }
    let s = s0.replace(/\^/g, '**');
    s = s.replace(/\bpi\b/gi, 'PI');
    if (!/^[0-9+\-*/().,_ %a-zA-Z]*$/.test(s)) throw new Error('Expression contains invalid characters.');
    return s;
  }

  function makeSafeEvaluator(vars, expr) {
    try {
      const clean = sanitizeExpr(expr);
      const body = [
        'const {sin,cos,tan,asin,acos,atan,atan2,sqrt,abs,pow,exp,log,log10,floor,ceil,round,max,min,PI,E} = Math;',
        'const ln = log;',
        'const sec = (u) => 1 / cos(u);',
        'const csc = (u) => 1 / sin(u);',
        'const cot = (u) => 1 / tan(u);',
        'return (' + clean + ');'
      ].join(' ');
      return new Function(...vars, body);
    } catch (err) {
      throw new Error(err && err.message ? err.message : 'Invalid expression.');
    }
  }

  function safeEvalX(expr, x) {
    try {
      const fn = makeSafeEvaluator(['x'], expr);
      const out = fn(x);
      if (!finite(out)) throw new Error('Expression is not finite at this point.');
      return out;
    } catch (err) {
      throw new Error(err.message || 'Could not evaluate f(x).');
    }
  }

  function safeEvalTY(expr, t, y) {
    try {
      const fn = makeSafeEvaluator(['t', 'y'], expr);
      const out = fn(t, y);
      if (!finite(out)) throw new Error('Expression is not finite at this step.');
      return out;
    } catch (err) {
      throw new Error(err.message || 'Could not evaluate f(t,y).');
    }
  }

  const ID_ALIASES = {
    de_ivp_expr: 'de_expr', de_ivp_y0: 'de_y0', de_ivp_t0: 'de_t0', de_ivp_tend: 'de_tend', de_ivp_h: 'de_h',
    trig_side_a: 'trig_a', trig_side_b: 'trig_b', trig_side_c: 'trig_c', trig_angle_A: 'trig_A', trig_angle_B: 'trig_B', trig_angle_C: 'trig_C',
    trig_triangle_result: 'trig_tri_result', trig_unit_circle_result: 'trig_click_result',
    la_matrix_size: 'la_size', la_matrix_op: 'la_op', la_matrixA: 'la_mat_a', la_matrixB: 'la_mat_b',
    la_matrix_result: 'la_result', la_vector_result: 'la_vec_result',
    calc_diff_expr: 'calc_f', calc_diff_a: 'calc_dx', calc_diff_result: 'calc_deriv_result',
    calc_int_expr: 'calc_fi', calc_int_a: 'calc_a', calc_int_b: 'calc_b', calc_int_n: 'calc_n',
    calc_taylor_type: 'calc_taylor_fn', calc_taylor_a: 'calc_ta', calc_taylor_n: 'calc_tn', calc_taylor_x: 'calc_tx',
    chem_molar_result: 'chem_mm_result', chem_periodic: 'chem_ptable',
    chem_gas_P: 'chem_P', chem_gas_V: 'chem_V', chem_gas_n: 'chem_n', chem_gas_T: 'chem_T',
    chem_hh_pKa: 'chem_pka', chem_hh_acid: 'chem_ca', chem_hh_base: 'chem_ha',
    opt_theta1: 'opt_t1', opt_grating_linesmm: 'opt_lmm', opt_grating_lambda: 'opt_lam', opt_grating_m: 'opt_m',
    opt_grating_result: 'opt_grat_result', opt_ds_lambda: 'opt_ds_lam',
    qp_box_particle: 'qp_particle', qp_db_preset: 'qp_db_par', qp_db_velocity: 'qp_db_v', qp_h_n: 'qp_hn', qp_pe_lambda: 'qp_pe_lam'
  };
  function byId(id) { return document.getElementById(id) || document.getElementById(ID_ALIASES[id] || ''); }
  function numVal(id) {
    const el = byId(id);
    if (!el) return NaN;
    const v = parseFloat(el.value);
    return Number.isFinite(v) ? v : NaN;
  }
  function strVal(id) {
    const el = byId(id);
    return el ? String(el.value || '').trim() : '';
  }
  function clearNode(el) {
    if (!el) return null;
    while (el.firstChild) el.removeChild(el.firstChild);
    return el;
  }
  function prepareResult(id) {
    const el = byId(id);
    if (!el) return null;
    clearNode(el);
    el.className = 'result show';
    return el;
  }
  function showError(id, msg) {
    const el = byId(id);
    if (!el) return;
    clearNode(el);
    el.className = 'result error show';
    const p = document.createElement('div');
    p.textContent = '⚠ ' + msg;
    el.appendChild(p);
  }
  function addRow(parent, label, value, opts) {
    const row = document.createElement('div');
    row.className = 'res-row';
    const l = document.createElement('span');
    l.className = 'res-label';
    l.textContent = label;
    const v = document.createElement('span');
    v.className = 'res-val';
    v.textContent = value;
    if (opts && opts.color) v.style.color = opts.color;
    if (opts && opts.bold) v.style.fontWeight = '700';
    row.appendChild(l);
    row.appendChild(v);
    parent.appendChild(row);
    return row;
  }
  function addHeading(parent, text) {
    const h = document.createElement('div');
    h.className = 'res-row';
    h.style.borderBottom = '1px solid ' + COLORS.line;
    h.style.marginTop = '0.7rem';
    const s = document.createElement('span');
    s.className = 'res-label';
    s.style.textTransform = 'uppercase';
    s.style.letterSpacing = '0.08em';
    s.style.color = COLORS.accent;
    s.textContent = text;
    h.appendChild(s);
    parent.appendChild(h);
  }
  function addText(parent, text, color) {
    const p = document.createElement('div');
    p.style.marginTop = '0.4rem';
    p.style.whiteSpace = 'pre-wrap';
    p.style.lineHeight = '1.45';
    p.style.fontSize = '0.92em';
    if (color) p.style.color = color;
    p.textContent = text;
    parent.appendChild(p);
    return p;
  }
  function addTable(parent, headers, rows) {
    const wrap = document.createElement('div');
    wrap.style.overflowX = 'auto';
    wrap.style.marginTop = '0.5rem';
    const table = document.createElement('table');
    table.style.width = '100%';
    table.style.borderCollapse = 'collapse';
    table.style.fontSize = '0.86em';
    const thead = document.createElement('thead');
    const hr = document.createElement('tr');
    headers.forEach((h) => {
      const th = document.createElement('th');
      th.textContent = h;
      th.style.textAlign = 'left';
      th.style.padding = '0.35rem';
      th.style.borderBottom = '1px solid ' + COLORS.line;
      th.style.color = COLORS.accent;
      hr.appendChild(th);
    });
    thead.appendChild(hr);
    table.appendChild(thead);
    const tbody = document.createElement('tbody');
    rows.forEach((r) => {
      const tr = document.createElement('tr');
      r.forEach((cell) => {
        const td = document.createElement('td');
        td.textContent = String(cell);
        td.style.padding = '0.3rem 0.35rem';
        td.style.borderBottom = '1px solid rgba(255,255,255,0.06)';
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    wrap.appendChild(table);
    parent.appendChild(wrap);
    return table;
  }
  function addList(parent, items) {
    const ul = document.createElement('ul');
    ul.style.margin = '0.45rem 0 0.15rem 1rem';
    ul.style.padding = '0';
    items.forEach((item) => {
      const li = document.createElement('li');
      li.style.margin = '0.2rem 0';
      li.textContent = item;
      ul.appendChild(li);
    });
    parent.appendChild(ul);
  }
  function svgEl(tag, attrs) {
    const el = document.createElementNS(SVG_NS, tag);
    Object.keys(attrs || {}).forEach((k) => el.setAttribute(k, String(attrs[k])));
    return el;
  }
  function appendSvg(parent, svg) {
    const wrap = document.createElement('div');
    wrap.style.marginTop = '0.6rem';
    wrap.style.overflowX = 'auto';
    wrap.appendChild(svg);
    parent.appendChild(wrap);
    return wrap;
  }
  function setField(el, txt) {
    if (!el) return;
    if ('value' in el) el.value = txt;
    else el.textContent = txt;
  }

  function renderMatrix(parent, matrix, title) {
    if (title) addText(parent, title, COLORS.accent);
    const wrap = document.createElement('div');
    wrap.style.display = 'inline-block';
    wrap.style.marginTop = '0.35rem';
    wrap.style.padding = '0.15rem 0.35rem';
    wrap.style.borderLeft = '2px solid ' + COLORS.accent;
    wrap.style.borderRight = '2px solid ' + COLORS.accent;
    const table = document.createElement('table');
    table.style.borderCollapse = 'collapse';
    matrix.forEach((row) => {
      const tr = document.createElement('tr');
      row.forEach((cell) => {
        const td = document.createElement('td');
        td.textContent = fmtNum(cell, 5);
        td.style.padding = '0.2rem 0.55rem';
        td.style.textAlign = 'center';
        tr.appendChild(td);
      });
      table.appendChild(tr);
    });
    wrap.appendChild(table);
    parent.appendChild(wrap);
    return wrap;
  }

  function plotSeries(series, width, height, opts) {
    const svg = svgEl('svg', { width: width, height: height, viewBox: '0 0 ' + width + ' ' + height, style: 'background:' + COLORS.bg + ';border:1px solid rgba(255,255,255,0.08);border-radius:10px' });
    const pad = { l: 42, r: 12, t: 12, b: 28 };
    let xmin = Infinity, xmax = -Infinity, ymin = Infinity, ymax = -Infinity;
    series.forEach((s) => {
      s.points.forEach((p) => {
        if (!finite(p.x) || !finite(p.y)) return;
        xmin = Math.min(xmin, p.x); xmax = Math.max(xmax, p.x); ymin = Math.min(ymin, p.y); ymax = Math.max(ymax, p.y);
      });
    });
    if (!finite(xmin) || !finite(xmax) || !finite(ymin) || !finite(ymax)) return svg;
    if (xmin === xmax) { xmin -= 1; xmax += 1; }
    if (ymin === ymax) { ymin -= 1; ymax += 1; }
    const xr = xmax - xmin; const yr = ymax - ymin;
    xmin -= xr * 0.04; xmax += xr * 0.04; ymin -= yr * 0.1; ymax += yr * 0.1;
    const px = (x) => pad.l + (x - xmin) * (width - pad.l - pad.r) / (xmax - xmin);
    const py = (y) => height - pad.b - (y - ymin) * (height - pad.t - pad.b) / (ymax - ymin);

    svg.appendChild(svgEl('line', { x1: pad.l, y1: height - pad.b, x2: width - pad.r, y2: height - pad.b, stroke: 'rgba(255,255,255,0.35)' }));
    svg.appendChild(svgEl('line', { x1: pad.l, y1: pad.t, x2: pad.l, y2: height - pad.b, stroke: 'rgba(255,255,255,0.35)' }));

    [xmin, (xmin + xmax) / 2, xmax].forEach((x, i) => {
      const xx = px(x);
      const lab = svgEl('text', { x: xx, y: height - 8, fill: COLORS.muted, 'font-size': 10, 'text-anchor': i === 0 ? 'start' : (i === 2 ? 'end' : 'middle') });
      lab.textContent = fmtNum(x, 3);
      svg.appendChild(lab);
    });
    [ymin, (ymin + ymax) / 2, ymax].forEach((y, _i) => {
      const yy = py(y);
      const lab = svgEl('text', { x: 4, y: yy + 4, fill: COLORS.muted, 'font-size': 10 });
      lab.textContent = fmtNum(y, 3);
      svg.appendChild(lab);
    });

    if (opts && opts.guides) {
      opts.guides.forEach((guide) => {
        if (!finite(guide.x) || !finite(guide.y)) return;
        svg.appendChild(svgEl('line', { x1: px(guide.x), y1: py(0), x2: px(guide.x), y2: py(guide.y), stroke: guide.color || COLORS.green, 'stroke-width': 1, 'stroke-dasharray': '3 3', opacity: 0.7 }));
      });
    }

    if (opts && opts.area && opts.area.points && opts.area.points.length) {
      const d = opts.area.points.map((p, idx) => (idx ? 'L' : 'M') + px(p.x) + ' ' + py(p.y)).join(' ');
      svg.appendChild(svgEl('path', { d: d, fill: opts.area.fill || 'rgba(110,231,183,0.18)', stroke: 'none' }));
    }

    series.forEach((s) => {
      const d = s.points.filter((p) => finite(p.x) && finite(p.y)).map((p, idx) => (idx ? 'L' : 'M') + px(p.x) + ' ' + py(p.y)).join(' ');
      svg.appendChild(svgEl('path', { d: d, fill: 'none', stroke: s.color || COLORS.accent, 'stroke-width': s.width || 2 }));
    });

    series.forEach((s, i) => {
      if (!s.label) return;
      const y = 18 + i * 14;
      svg.appendChild(svgEl('line', { x1: width - 92, y1: y - 4, x2: width - 74, y2: y - 4, stroke: s.color || COLORS.accent, 'stroke-width': 3 }));
      const t = svgEl('text', { x: width - 68, y: y, fill: COLORS.text, 'font-size': 10 });
      t.textContent = s.label;
      svg.appendChild(t);
    });
    return svg;
  }

  function calculusPlot(series, opts) {
    const svg = plotSeries(series, 520, 250, opts);
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', opts && opts.label ? opts.label : 'Calculus visualization');
    const note = svgEl('text', { x: 18, y: 238, fill: COLORS.muted, 'font-size': 11 });
    note.textContent = opts && opts.note ? opts.note : '';
    svg.appendChild(note);
    return svg;
  }

  function sampleFunction(expr, lo, hi, count) {
    const points = [];
    for (let i = 0; i <= count; i++) {
      const x = lo + (hi - lo) * i / count;
      try {
        const y = safeEvalX(expr, x);
        if (finite(y) && Math.abs(y) < 1e6) points.push({ x: x, y: y });
      } catch (_) { /* skip discontinuities */ }
    }
    return points;
  }

  function derivativeDiagram(expr, a, h, slope) {
    const span = Math.max(2, Math.abs(a) * 0.35 + 1);
    const lo = a - span, hi = a + span;
    const curve = sampleFunction(expr, lo, hi, 120);
    const fa = safeEvalX(expr, a);
    const tangent = [{ x: lo, y: fa + slope * (lo - a) }, { x: hi, y: fa + slope * (hi - a) }];
    const secant = [{ x: a - h, y: safeEvalX(expr, a - h) }, { x: a + h, y: safeEvalX(expr, a + h) }];
    return calculusPlot([
      { label: 'f(x)', color: COLORS.accent, points: curve, width: 3 },
      { label: 'tangent', color: COLORS.green, points: tangent, width: 2 },
      { label: 'secant', color: COLORS.yellow, points: secant, width: 2 }
    ], { label: 'Curve with tangent and secant lines at the selected point', note: 'As h shrinks, the secant rotates toward the tangent: slope = f′(a).' });
  }

  function integralDiagram(expr, a, b, n) {
    const lo = Math.min(a, b), hi = Math.max(a, b);
    const curve = sampleFunction(expr, lo, hi, 140);
    const area = [{ x: lo, y: 0 }].concat(curve).concat([{ x: hi, y: 0 }]);
    const guides = [];
    const step = (hi - lo) / Math.max(1, Math.min(n, 24));
    for (let i = 0; i <= Math.min(n, 24); i++) {
      const x = lo + i * step;
      guides.push({ x: x, y: safeEvalX(expr, x), color: i === 0 || i === Math.min(n, 24) ? COLORS.yellow : COLORS.green });
    }
    return calculusPlot([{ label: 'f(x)', color: COLORS.accent, points: curve, width: 3 }], {
      label: 'Area under the curve between the integration limits',
      area: { points: area, fill: 'rgba(110,231,183,0.2)' },
      guides: guides,
      note: 'The shaded region is accumulated area; more rectangles make the approximation hug the curve.'
    });
  }

  function taylorDiagram(type, a, N, x) {
    const lo = Math.min(a - 3, x - 1), hi = Math.max(a + 3, x + 1);
    let sum = 0;
    const approx = [];
    for (let i = 0; i <= 140; i++) {
      const q = lo + (hi - lo) * i / 140;
      sum = 0;
      for (let n = 0; n <= N; n++) sum += taylorDerivativeValue(type, a, n) * Math.pow(q - a, n) / factorial(n);
      approx.push({ x: q, y: sum });
    }
    const exact = sampleFunction(type === 'ln1p' ? 'log(1+x)' : type + '(x)', lo, hi, 140);
    return calculusPlot([
      { label: 'exact', color: COLORS.accent, points: exact, width: 3 },
      { label: 'Taylor N=' + N, color: COLORS.yellow, points: approx, width: 2 }
    ], { label: 'Exact function compared with its Taylor polynomial', note: 'Near a, the polynomial shadows the function; increasing N usually widens the useful neighborhood.' });
  }

  function rationalPiLabel(degrees) {
    const n = Math.round(degrees);
    if (n === 0) return '0';
    if (n === 180) return 'π';
    if (n === 360) return '2π';
    const g = gcd(n, 180);
    const num = n / g;
    const den = 180 / g;
    if (den === 1) return num === 1 ? 'π' : num + 'π';
    return (num === 1 ? 'π' : num + 'π') + '/' + den;
  }

  function trigValueText(v) {
    return finite(v) && Math.abs(v) < 1e12 ? fmtNum(v, 6) : 'undefined';
  }

  function parseChemicalFormula(formula) {
    const src = String(formula || '').trim();
    if (!src) throw new Error('Enter a chemical formula.');
    let i = 0;
    const stack = [Object.create(null)];
    function readNumber() {
      let digits = '';
      while (i < src.length && /\d/.test(src[i])) { digits += src[i++]; }
      return digits ? parseInt(digits, 10) : 1;
    }
    while (i < src.length) {
      const ch = src[i];
      if (ch === '(') {
        stack.push(Object.create(null));
        i += 1;
      } else if (ch === ')') {
        i += 1;
        const mult = readNumber();
        if (stack.length < 2) throw new Error('Unmatched parenthesis.');
        const top = stack.pop();
        const cur = stack[stack.length - 1];
        Object.keys(top).forEach((k) => { cur[k] = (cur[k] || 0) + top[k] * mult; });
      } else if (/[A-Z]/.test(ch)) {
        let sym = ch;
        i += 1;
        while (i < src.length && /[a-z]/.test(src[i])) sym += src[i++];
        if (!defined(ATOMIC_MASS[sym])) throw new Error('Unknown element: ' + sym);
        const count = readNumber();
        const cur = stack[stack.length - 1];
        cur[sym] = (cur[sym] || 0) + count;
      } else {
        throw new Error('Invalid formula near "' + ch + '".');
      }
    }
    if (stack.length !== 1) throw new Error('Unmatched parenthesis.');
    return stack[0];
  }

  function molarMassFromCounts(counts) {
    return Object.keys(counts).reduce((sum, k) => sum + ATOMIC_MASS[k] * counts[k], 0);
  }

  function solveQuadratic(a, b, c) {
    if (nz(a)) return { linear: true, root: nz(b) ? NaN : -c / b };
    const D = b * b - 4 * a * c;
    if (D >= 0) {
      const s = Math.sqrt(D);
      return { D: D, roots: [(-b + s) / (2 * a), (-b - s) / (2 * a)] };
    }
    const re = -b / (2 * a);
    const im = Math.sqrt(-D) / (2 * a);
    return { D: D, roots: [{ re: re, im: im }, { re: re, im: -im }] };
  }

  function matrixClone(A) { return A.map((r) => r.slice()); }
  function matrixIdentity(n) {
    const A = [];
    for (let i = 0; i < n; i++) {
      A[i] = [];
      for (let j = 0; j < n; j++) A[i][j] = i === j ? 1 : 0;
    }
    return A;
  }
  function matrixAdd(A, B, sgn) {
    return A.map((r, i) => r.map((v, j) => v + (sgn || 1) * B[i][j]));
  }
  function matrixMul(A, B) {
    const n = A.length;
    const out = [];
    for (let i = 0; i < n; i++) {
      out[i] = [];
      for (let j = 0; j < n; j++) {
        let sum = 0;
        for (let k = 0; k < n; k++) sum += A[i][k] * B[k][j];
        out[i][j] = sum;
      }
    }
    return out;
  }
  function matrixScalar(A, k) { return A.map((r) => r.map((v) => v * k)); }
  function matrixMinor(A, row, col) {
    return A.filter((_, i) => i !== row).map((r) => r.filter((_, j) => j !== col));
  }
  function determinant(A) {
    const n = A.length;
    if (n === 1) return A[0][0];
    if (n === 2) return A[0][0] * A[1][1] - A[0][1] * A[1][0];
    let det = 0;
    for (let j = 0; j < n; j++) det += (j % 2 ? -1 : 1) * A[0][j] * determinant(matrixMinor(A, 0, j));
    return det;
  }

  function readMatrix(prefix, size) {
    const A = [];
    for (let i = 0; i < size; i++) {
      const row = [];
      for (let j = 0; j < size; j++) {
        const v = numVal(prefix + '_' + i + '_' + j);
        if (!finite(v)) throw new Error('Fill every matrix entry.');
        row.push(v);
      }
      A.push(row);
    }
    return A;
  }

  function createMatrixGrid(containerId, prefix, size) {
    const host = byId(containerId);
    if (!host) return;
    clearNode(host);
    host.style.display = 'grid';
    host.style.gridTemplateColumns = 'repeat(' + size + ', minmax(58px, 1fr))';
    host.style.gap = '0.35rem';
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        const input = document.createElement('input');
        input.type = 'number';
        input.step = 'any';
        input.id = prefix + '_' + i + '_' + j;
        input.placeholder = prefix.toUpperCase() + (i + 1) + (j + 1);
        host.appendChild(input);
      }
    }
  }

  function solveTriangleCases(input) {
    const sols = [];
    const eps = 1e-7;

    function push(sol) {
      if (![sol.a, sol.b, sol.c, sol.A, sol.B, sol.C].every(finite)) return;
      if (Math.min(sol.a, sol.b, sol.c, sol.A, sol.B, sol.C) <= 0) return;
      if (Math.abs(sol.A + sol.B + sol.C - 180) > 1e-4) return;
      const key = [sol.a, sol.b, sol.c, sol.A, sol.B, sol.C].map((v) => Math.round(v * 1e6) / 1e6).join('|');
      if (!sols.some((s) => s.key === key)) sols.push({ key: key, val: sol });
    }

    let { a, b, c, A, B, C } = input;
    const sideCount = [a, b, c].filter(finite).length;
    const angleCount = [A, B, C].filter(finite).length;

    if (sideCount === 3) {
      A = deg(Math.acos(clamp((b * b + c * c - a * a) / (2 * b * c), -1, 1)));
      B = deg(Math.acos(clamp((a * a + c * c - b * b) / (2 * a * c), -1, 1)));
      C = 180 - A - B;
      push({ a: a, b: b, c: c, A: A, B: B, C: C });
    }

    if (angleCount >= 2 && sideCount >= 1) {
      if (!finite(A) && finite(B) && finite(C)) A = 180 - B - C;
      if (!finite(B) && finite(A) && finite(C)) B = 180 - A - C;
      if (!finite(C) && finite(A) && finite(B)) C = 180 - A - B;
      const sA = Math.sin(rad(A)), sB = Math.sin(rad(B)), sC = Math.sin(rad(C));
      if (finite(a)) push({ a: a, b: a * sB / sA, c: a * sC / sA, A: A, B: B, C: C });
      if (finite(b)) push({ a: b * sA / sB, b: b, c: b * sC / sB, A: A, B: B, C: C });
      if (finite(c)) push({ a: c * sA / sC, b: c * sB / sC, c: c, A: A, B: B, C: C });
    }

    if (finite(b) && finite(c) && finite(A)) {
      a = Math.sqrt(b * b + c * c - 2 * b * c * Math.cos(rad(A)));
      B = deg(Math.acos(clamp((a * a + c * c - b * b) / (2 * a * c), -1, 1)));
      C = 180 - A - B;
      push({ a: a, b: b, c: c, A: A, B: B, C: C });
    }
    if (finite(a) && finite(c) && finite(B)) {
      b = Math.sqrt(a * a + c * c - 2 * a * c * Math.cos(rad(B)));
      A = deg(Math.acos(clamp((b * b + c * c - a * a) / (2 * b * c), -1, 1)));
      C = 180 - A - B;
      push({ a: a, b: b, c: c, A: A, B: B, C: C });
    }
    if (finite(a) && finite(b) && finite(C)) {
      c = Math.sqrt(a * a + b * b - 2 * a * b * Math.cos(rad(C)));
      A = deg(Math.acos(clamp((b * b + c * c - a * a) / (2 * b * c), -1, 1)));
      B = 180 - A - C;
      push({ a: a, b: b, c: c, A: A, B: B, C: C });
    }

    function ssa(knownSideName, knownAngleName, otherSideName) {
      const S = input[knownSideName], Ang = input[knownAngleName], O = input[otherSideName];
      if (!finite(S) || !finite(Ang) || !finite(O)) return;
      const sinOther = O * Math.sin(rad(Ang)) / S;
      if (sinOther < -eps || sinOther > 1 + eps) return;
      const ang1 = deg(Math.asin(clamp(sinOther, -1, 1)));
      [ang1, 180 - ang1].forEach((otherAng) => {
        if (!finite(otherAng) || otherAng <= 0) return;
        const thirdAng = 180 - Ang - otherAng;
        if (thirdAng <= eps) return;
        const res = { a: NaN, b: NaN, c: NaN, A: NaN, B: NaN, C: NaN };
        res[knownSideName] = S; res[knownAngleName] = Ang;
        const otherAngName = otherSideName.toUpperCase();
        res[otherSideName] = O; res[otherAngName] = otherAng;
        const remSide = ['a', 'b', 'c'].find((k) => !finite(res[k]));
        const remAng = ['A', 'B', 'C'].find((k) => !finite(res[k]));
        res[remAng] = thirdAng;
        res[remSide] = S * Math.sin(rad(thirdAng)) / Math.sin(rad(Ang));
        push(res);
      });
    }

    ssa('a', 'A', 'b'); ssa('a', 'A', 'c');
    ssa('b', 'B', 'a'); ssa('b', 'B', 'c');
    ssa('c', 'C', 'a'); ssa('c', 'C', 'b');

    return sols.map((s) => s.val);
  }

  function solveSimplex2D(model) {
    const M = 1e6;
    const varNames = ['x1', 'x2'];
    const rows = [];
    const basis = [];
    const artificial = [];
    let slackCount = 0, surplusCount = 0, artCount = 0;

    function addVar(name, row, coeff) {
      varNames.push(name);
      rows.forEach((r) => r.coeffs.push(0));
      row.coeffs.push(coeff);
      return varNames.length - 1;
    }

    model.constraints.forEach((c) => {
      let a = c.a, b = c.b, rhs = c.c, op = c.op;
      if (rhs < 0) {
        a = -a; b = -b; rhs = -rhs;
        op = op === '<=' ? '>=' : op === '>=' ? '<=' : '=';
      }
      const row = { coeffs: new Array(varNames.length).fill(0), rhs: rhs };
      row.coeffs[0] = a; row.coeffs[1] = b;
      if (op === '<=') {
        basis.push(addVar('s' + (++slackCount), row, 1));
      } else if (op === '>=') {
        addVar('e' + (++surplusCount), row, -1);
        const ai = addVar('a' + (++artCount), row, 1);
        basis.push(ai);
        artificial.push(ai);
      } else {
        const ai = addVar('a' + (++artCount), row, 1);
        basis.push(ai);
        artificial.push(ai);
      }
      rows.push(row);
    });

    const cVec = new Array(varNames.length).fill(0);
    cVec[0] = model.mode === 'max' ? model.c1 : -model.c1;
    cVec[1] = model.mode === 'max' ? model.c2 : -model.c2;
    artificial.forEach((idx) => { cVec[idx] = -M; });

    function snapshot(rowsData, basisData, note, pivot) {
      const cB = basisData.map((idx) => cVec[idx]);
      const reduced = new Array(varNames.length).fill(0);
      let z = 0;
      for (let j = 0; j < varNames.length; j++) {
        let zj = 0;
        for (let i = 0; i < rowsData.length; i++) zj += cB[i] * rowsData[i].coeffs[j];
        reduced[j] = cVec[j] - zj;
      }
      for (let i = 0; i < rowsData.length; i++) z += cB[i] * rowsData[i].rhs;
      return {
        rows: rowsData.map((r) => ({ coeffs: r.coeffs.slice(), rhs: r.rhs })),
        basis: basisData.slice(), reduced: reduced, z: z, note: note || '', pivot: pivot || null
      };
    }

    const steps = [snapshot(rows, basis, 'Initial tableau')];
    let iter = 0;
    while (iter < 10) {
      iter += 1;
      const current = snapshot(rows, basis);
      let entering = -1;
      let best = 1e-9;
      for (let j = 0; j < varNames.length; j++) {
        if (current.reduced[j] > best) { best = current.reduced[j]; entering = j; }
      }
      if (entering === -1) break;
      let leaving = -1;
      let ratio = Infinity;
      for (let i = 0; i < rows.length; i++) {
        const aij = rows[i].coeffs[entering];
        if (aij > 1e-9) {
          const r = rows[i].rhs / aij;
          if (r < ratio - 1e-9) { ratio = r; leaving = i; }
        }
      }
      if (leaving === -1) {
        steps.push(snapshot(rows, basis, 'Unbounded objective detected.'));
        return { ok: false, reason: 'Unbounded objective.', steps: steps, varNames: varNames };
      }
      const piv = rows[leaving].coeffs[entering];
      rows[leaving].coeffs = rows[leaving].coeffs.map((v) => v / piv);
      rows[leaving].rhs /= piv;
      for (let i = 0; i < rows.length; i++) {
        if (i === leaving) continue;
        const f = rows[i].coeffs[entering];
        if (nz(f)) continue;
        rows[i].coeffs = rows[i].coeffs.map((v, j) => v - f * rows[leaving].coeffs[j]);
        rows[i].rhs -= f * rows[leaving].rhs;
      }
      basis[leaving] = entering;
      steps.push(snapshot(rows, basis, 'Pivot ' + iter + ': enter ' + varNames[entering] + ', leave row ' + (leaving + 1), { row: leaving, col: entering }));
    }

    const final = snapshot(rows, basis, 'Final tableau');
    const sol = new Array(varNames.length).fill(0);
    basis.forEach((idx, i) => { sol[idx] = rows[i].rhs; });
    const infeasible = artificial.some((idx) => basis.includes(idx) && sol[idx] > 1e-7);
    if (infeasible) return { ok: false, reason: 'Infeasible constraints.', steps: steps.concat([final]), varNames: varNames };
    const zActual = model.mode === 'max' ? final.z : -final.z;
    return { ok: true, steps: steps.concat([final]), varNames: varNames, solution: sol, objective: zActual, basis: basis.slice() };
  }

  function solveGraphicalLP(model) {
    const lines = model.constraints.map((c) => ({ a: c.a, b: c.b, c: c.c, label: c.a + 'x₁ + ' + c.b + 'x₂ ' + c.op + ' ' + c.c }));
    lines.push({ a: 1, b: 0, c: 0, axis: 'x1=0' });
    lines.push({ a: 0, b: 1, c: 0, axis: 'x2=0' });
    const pts = [];
    for (let i = 0; i < lines.length; i++) {
      for (let j = i + 1; j < lines.length; j++) {
        const L1 = lines[i], L2 = lines[j];
        const det = L1.a * L2.b - L2.a * L1.b;
        if (nz(det)) continue;
        const x = (L1.c * L2.b - L2.c * L1.b) / det;
        const y = (L1.a * L2.c - L2.a * L1.c) / det;
        if (!finite(x) || !finite(y)) continue;
        pts.push({ x: x, y: y });
      }
    }
    function feasible(p) {
      if (p.x < -1e-8 || p.y < -1e-8) return false;
      return model.constraints.every((c) => {
        const v = c.a * p.x + c.b * p.y;
        if (c.op === '<=') return v <= c.c + 1e-7;
        if (c.op === '>=') return v >= c.c - 1e-7;
        return Math.abs(v - c.c) <= 1e-7;
      });
    }
    const verts = [];
    pts.forEach((p) => {
      if (!feasible(p)) return;
      const key = Math.round(p.x * 1e7) + ':' + Math.round(p.y * 1e7);
      if (!verts.some((q) => q.key === key)) verts.push({ key: key, x: Math.max(0, p.x), y: Math.max(0, p.y) });
    });
    if (!verts.length) return { ok: false, reason: 'No feasible corner points found.' };
    const center = verts.reduce((s, p) => ({ x: s.x + p.x / verts.length, y: s.y + p.y / verts.length }), { x: 0, y: 0 });
    verts.sort((p, q) => Math.atan2(p.y - center.y, p.x - center.x) - Math.atan2(q.y - center.y, q.x - center.x));
    verts.forEach((p) => { p.z = model.c1 * p.x + model.c2 * p.y; });
    let best = verts[0];
    verts.forEach((p) => {
      if (model.mode === 'max') { if (p.z > best.z + 1e-9) best = p; }
      else if (p.z < best.z - 1e-9) best = p;
    });
    return { ok: true, vertices: verts, optimal: best };
  }

  function renderLPGraph(graph, model) {
    const w = 300, h = 300;
    const svg = svgEl('svg', { width: w, height: h, viewBox: '0 0 300 300', style: 'background:' + COLORS.bg + ';border:1px solid rgba(255,255,255,0.08);border-radius:10px' });
    if (!graph.ok) return svg;
    let xmax = Math.max(1, ...graph.vertices.map((p) => p.x));
    let ymax = Math.max(1, ...graph.vertices.map((p) => p.y));
    model.constraints.forEach((c) => {
      if (nz(c.a)) xmax = Math.max(xmax, c.c / c.a);
      if (nz(c.b)) ymax = Math.max(ymax, c.c / c.b);
    });
    xmax *= 1.15; ymax *= 1.15;
    const pad = 28;
    const px = (x) => pad + x * (w - 2 * pad) / xmax;
    const py = (y) => h - pad - y * (h - 2 * pad) / ymax;

    svg.appendChild(svgEl('line', { x1: pad, y1: h - pad, x2: w - 10, y2: h - pad, stroke: '#777' }));
    svg.appendChild(svgEl('line', { x1: pad, y1: 10, x2: pad, y2: h - pad, stroke: '#777' }));

    const poly = graph.vertices.map((p) => px(p.x) + ',' + py(p.y)).join(' ');
    svg.appendChild(svgEl('polygon', { points: poly, fill: 'rgba(110,231,183,0.18)', stroke: COLORS.green, 'stroke-width': 1.5 }));

    model.constraints.forEach((c) => {
      const pts = [];
      if (nz(c.b)) pts.push({ x: 0, y: c.c / c.b });
      if (nz(c.a)) pts.push({ x: c.c / c.a, y: 0 });
      if (pts.length >= 2) {
        svg.appendChild(svgEl('line', { x1: px(pts[0].x), y1: py(pts[0].y), x2: px(pts[1].x), y2: py(pts[1].y), stroke: COLORS.blue, 'stroke-width': 1 }));
      }
    });

    const z = graph.optimal.z;
    const objPts = [];
    if (nz(model.c2)) objPts.push({ x: 0, y: z / model.c2 });
    if (nz(model.c1)) objPts.push({ x: z / model.c1, y: 0 });
    if (objPts.length >= 2) svg.appendChild(svgEl('line', { x1: px(objPts[0].x), y1: py(objPts[0].y), x2: px(objPts[1].x), y2: py(objPts[1].y), stroke: COLORS.yellow, 'stroke-width': 2 }));

    graph.vertices.forEach((p, i) => {
      svg.appendChild(svgEl('circle', { cx: px(p.x), cy: py(p.y), r: p === graph.optimal ? 5 : 3.5, fill: p === graph.optimal ? COLORS.red : COLORS.text }));
      const t = svgEl('text', { x: px(p.x) + 6, y: py(p.y) - 6, fill: COLORS.text, 'font-size': 10 });
      t.textContent = 'V' + (i + 1) + ' (' + fmtNum(p.x, 2) + ', ' + fmtNum(p.y, 2) + ')';
      svg.appendChild(t);
    });
    return svg;
  }

  /* 1. DIFFERENTIAL EQUATIONS */
  window.calcDESecondOrder = function () {
    const a = numVal('de_a'), b = numVal('de_b'), c = numVal('de_c');
    if (![a, b, c].every(finite)) return showError('de_result', 'Enter a, b, and c.');
    if (!nz(a)) return showError('de_result', 'a must be non-zero for a second-order ODE.');
    const out = prepareResult('de_result');
    const D = b * b - 4 * a * c;
    const wn = a * c > 0 ? Math.sqrt(c / a) : NaN;
    const zeta = a * c > 0 ? b / (2 * Math.sqrt(a * c)) : NaN;
    addHeading(out, 'Characteristic equation');
    addText(out, 'Assume y = e^(rt). Then ar² + br + c = 0 → ' + fmtNum(a, 4) + 'r² + ' + fmtNum(b, 4) + 'r + ' + fmtNum(c, 4) + ' = 0');
    addRow(out, 'Discriminant D', 'b² - 4ac = ' + fmtNum(D, 6));
    addRow(out, 'Natural frequency ωₙ', finite(wn) ? fmtNum(wn, 6) + ' rad/s' : 'undefined', { color: COLORS.blue });
    addRow(out, 'Damping ratio ζ', finite(zeta) ? fmtNum(zeta, 6) : 'undefined', { color: COLORS.blue });
    addHeading(out, 'General solution');
    if (D > 1e-12) {
      const s = Math.sqrt(D);
      const r1 = (-b + s) / (2 * a), r2 = (-b - s) / (2 * a);
      addRow(out, 'Root r₁', fmtNum(r1, 6));
      addRow(out, 'Root r₂', fmtNum(r2, 6));
      addRow(out, 'Type', 'Overdamped', { bold: true, color: COLORS.green });
      addText(out, 'y(t) = C₁e^(' + fmtNum(r1, 6) + 't) + C₂e^(' + fmtNum(r2, 6) + 't)');
    } else if (Math.abs(D) <= 1e-12) {
      const r = -b / (2 * a);
      addRow(out, 'Repeated root r', fmtNum(r, 6));
      addRow(out, 'Type', 'Critically damped', { bold: true, color: COLORS.yellow });
      addText(out, 'y(t) = (C₁ + C₂t)e^(' + fmtNum(r, 6) + 't)');
    } else {
      const alpha = -b / (2 * a);
      const beta = Math.sqrt(-D) / (2 * Math.abs(a));
      addRow(out, 'α', fmtNum(alpha, 6));
      addRow(out, 'β', fmtNum(beta, 6));
      addRow(out, 'Type', 'Underdamped', { bold: true, color: COLORS.red });
      addText(out, 'y(t) = e^(' + fmtNum(alpha, 6) + 't) [C₁cos(' + fmtNum(beta, 6) + 't) + C₂sin(' + fmtNum(beta, 6) + 't)]');
    }
  };

  window.calcDEIVP = function () {
    const expr = strVal('de_ivp_expr');
    const y0 = numVal('de_ivp_y0'), t0 = numVal('de_ivp_t0'), tEnd = numVal('de_ivp_tend'), h = numVal('de_ivp_h');
    if (!expr) return showError('de_ivp_result', 'Enter f(t,y).');
    if (![y0, t0, tEnd, h].every(finite) || h <= 0 || tEnd <= t0) return showError('de_ivp_result', 'Use finite values with h > 0 and tEnd > t0.');
    let euler = [{ t: t0, y: y0 }], rk4 = [{ t: t0, y: y0 }];
    try {
      const steps = Math.max(1, Math.ceil((tEnd - t0) / h));
      let te = t0, ye = y0, tr = t0, yr = y0;
      for (let i = 0; i < steps; i++) {
        const step = Math.min(h, tEnd - te);
        const fe = safeEvalTY(expr, te, ye);
        ye += step * fe;
        te += step;
        euler.push({ t: te, y: ye });

        const k1 = safeEvalTY(expr, tr, yr);
        const k2 = safeEvalTY(expr, tr + step / 2, yr + step * k1 / 2);
        const k3 = safeEvalTY(expr, tr + step / 2, yr + step * k2 / 2);
        const k4 = safeEvalTY(expr, tr + step, yr + step * k3);
        yr += step * (k1 + 2 * k2 + 2 * k3 + k4) / 6;
        tr += step;
        rk4.push({ t: tr, y: yr });
        if (tr >= tEnd - 1e-12) break;
      }
      const out = prepareResult('de_ivp_result');
      addRow(out, 'Euler at tEnd', fmtNum(euler[euler.length - 1].y, 6), { color: COLORS.yellow, bold: true });
      addRow(out, 'RK4 at tEnd', fmtNum(rk4[rk4.length - 1].y, 6), { color: COLORS.green, bold: true });
      addText(out, 'Euler: yₙ₊₁ = yₙ + hf(tₙ,yₙ)\nRK4: yₙ₊₁ = yₙ + h(k₁+2k₂+2k₃+k₄)/6');
      appendSvg(out, plotSeries([
        { label: 'Euler', color: COLORS.yellow, points: euler },
        { label: 'RK4', color: COLORS.green, points: rk4 }
      ], 400, 200));
      const first = [];
      for (let i = 0; i < Math.min(10, euler.length); i++) {
        first.push([i, fmtNum(euler[i].t, 4), fmtNum(euler[i].y, 6), fmtNum(rk4[i].y, 6), fmtNum(rk4[i].y - euler[i].y, 6)]);
      }
      addTable(out, ['n', 't', 'Euler', 'RK4', 'Δ'], first);
    } catch (err) {
      showError('de_ivp_result', err.message || 'Could not solve IVP.');
    }
  };

  /* 2. TRIGONOMETRY */
  window.initTrigUnitCircle = function (containerId, outputId) {
    containerId = containerId || 'trig_unit_circle';
    outputId = outputId || 'trig_unit_circle_result';
    const host = byId(containerId);
    if (!host) return;
    clearNode(host);
    const w = 260, h = 260, cx = 130, cy = 130, r = 92;
    const svg = svgEl('svg', { width: w, height: h, viewBox: '0 0 260 260', style: 'background:' + COLORS.bg + ';border:1px solid rgba(255,255,255,0.08);border-radius:12px;cursor:crosshair' });
    svg.appendChild(svgEl('line', { x1: 20, y1: cy, x2: 240, y2: cy, stroke: '#555' }));
    svg.appendChild(svgEl('line', { x1: cx, y1: 20, x2: cx, y2: 240, stroke: '#555' }));
    svg.appendChild(svgEl('circle', { cx: cx, cy: cy, r: r, fill: 'none', stroke: COLORS.accent, 'stroke-width': 2 }));
    const angleSet = Array.from(new Set([0,30,45,60,90,120,135,150,180,210,225,240,270,300,315,330,360])).sort((a,b)=>a-b);
    angleSet.forEach((d) => {
      const th = rad(d);
      const x = cx + r * Math.cos(th), y = cy - r * Math.sin(th);
      svg.appendChild(svgEl('line', { x1: cx, y1: cy, x2: x, y2: y, stroke: 'rgba(255,255,255,0.08)' }));
      svg.appendChild(svgEl('circle', { cx: x, cy: y, r: 2.5, fill: COLORS.blue }));
      const tx = cx + (r + 16) * Math.cos(th), ty = cy - (r + 16) * Math.sin(th);
      const label = svgEl('text', { x: tx, y: ty, fill: COLORS.text, 'font-size': 8, 'text-anchor': 'middle' });
      label.textContent = d + '°';
      svg.appendChild(label);
    });
    [0,30,45,60,90,120,135,150,180,210,225,240,270,300,315,330].forEach((d) => {
      const th = rad(d);
      const tx = cx + (r + 34) * Math.cos(th), ty = cy - (r + 34) * Math.sin(th);
      const label = svgEl('text', { x: tx, y: ty, fill: COLORS.muted, 'font-size': 7, 'text-anchor': 'middle' });
      label.textContent = rationalPiLabel(d);
      svg.appendChild(label);
    });
    const marker = svgEl('circle', { cx: cx + r, cy: cy, r: 5, fill: COLORS.red });
    svg.appendChild(marker);
    svg.addEventListener('click', function (ev) {
      const rect = svg.getBoundingClientRect();
      const x = ev.clientX - rect.left;
      const y = ev.clientY - rect.top;
      const ang = (deg(Math.atan2(cy - y, x - cx)) + 360) % 360;
      const th = rad(ang);
      marker.setAttribute('cx', String(cx + r * Math.cos(th)));
      marker.setAttribute('cy', String(cy - r * Math.sin(th)));
      const s = Math.sin(th), c = Math.cos(th), t = Math.abs(c) < 1e-10 ? NaN : s / c;
      const out = prepareResult(outputId);
      addRow(out, 'Angle', fmtNum(ang, 3) + '° = ' + rationalPiLabel(Math.round(ang)), { bold: true });
      addRow(out, 'sin θ', trigValueText(s));
      addRow(out, 'cos θ', trigValueText(c));
      addRow(out, 'tan θ', trigValueText(t));
      addRow(out, 'csc θ', trigValueText(Math.abs(s) < 1e-10 ? NaN : 1 / s));
      addRow(out, 'sec θ', trigValueText(Math.abs(c) < 1e-10 ? NaN : 1 / c));
      addRow(out, 'cot θ', trigValueText(Math.abs(s) < 1e-10 ? NaN : c / s));
      addRow(out, '(cos θ, sin θ)', '(' + fmtNum(c, 6) + ', ' + fmtNum(s, 6) + ')');
    });
    host.appendChild(svg);
    const legend = document.createElement('div');
    legend.style.display = 'grid';
    legend.style.gridTemplateColumns = 'repeat(auto-fit, minmax(120px, 1fr))';
    legend.style.gap = '0.25rem 0.6rem';
    legend.style.marginTop = '0.45rem';
    legend.style.fontSize = '0.78em';
    [0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330].forEach((d) => {
      const item = document.createElement('div');
      const c = Math.cos(rad(d));
      const s = Math.sin(rad(d));
      item.textContent = d + '° = ' + rationalPiLabel(d) + ' → (' + fmtNum(c, 4) + ', ' + fmtNum(s, 4) + ')';
      legend.appendChild(item);
    });
    host.appendChild(legend);
  };

  window.calcTrigTriangle = function () {
    const input = {
      a: numVal('trig_side_a'), b: numVal('trig_side_b'), c: numVal('trig_side_c'),
      A: numVal('trig_angle_A'), B: numVal('trig_angle_B'), C: numVal('trig_angle_C')
    };
    const known = [input.a, input.b, input.c, input.A, input.B, input.C].filter(finite).length;
    const sides = [input.a, input.b, input.c].filter(finite).length;
    if (known < 3 || sides < 1) return showError('trig_triangle_result', 'Enter any 3 values, including at least one side.');
    const sols = solveTriangleCases(input);
    if (!sols.length) return showError('trig_triangle_result', 'No valid triangle matches those inputs.');
    const out = prepareResult('trig_triangle_result');
    sols.forEach((s, idx) => {
      addHeading(out, sols.length > 1 ? 'Solution ' + (idx + 1) : 'Triangle');
      addRow(out, 'Side a', fmtNum(s.a, 6));
      addRow(out, 'Side b', fmtNum(s.b, 6));
      addRow(out, 'Side c', fmtNum(s.c, 6));
      addRow(out, 'Angle A', fmtNum(s.A, 6) + '°');
      addRow(out, 'Angle B', fmtNum(s.B, 6) + '°');
      addRow(out, 'Angle C', fmtNum(s.C, 6) + '°');
      addRow(out, 'Area', fmtNum(0.5 * s.b * s.c * Math.sin(rad(s.A)), 6));
    });
  };

  window.renderTrigIdentities = function () {
    const host = byId('trig_identities');
    if (!host) return;
    clearNode(host);
    host.className = 'result show';
    [
      ['Pythagorean identities', ['sin²x + cos²x = 1', '1 + tan²x = sec²x', '1 + cot²x = csc²x']],
      ['Sum / difference', ['sin(A±B)=sinAcosB±cosAsinB', 'cos(A±B)=cosAcosB∓sinAsinB', 'tan(A±B)=(tanA±tanB)/(1∓tanAtanB)']],
      ['Double / half angle', ['sin2x = 2sinx cosx', 'cos2x = cos²x - sin²x = 2cos²x - 1 = 1 - 2sin²x', 'tan(x/2)=sinx/(1+cosx)=(1-cosx)/sinx']],
      ['Product to sum', ['sinA sinB = ½[cos(A-B)-cos(A+B)]', 'cosA cosB = ½[cos(A-B)+cos(A+B)]', 'sinA cosB = ½[sin(A+B)+sin(A-B)]']]
    ].forEach((section) => {
      addHeading(host, section[0]);
      addList(host, section[1]);
    });
  };

  /* 3. LINEAR ALGEBRA */
  window.renderLAMatrixInputs = function () {
    const size = parseInt(strVal('la_matrix_size') || '2', 10);
    createMatrixGrid('la_matrixA', 'la_a', size);
    createMatrixGrid('la_matrixB', 'la_b', size);
  };

  window.calcLAMatrixOp = function () {
    const size = parseInt(strVal('la_matrix_size') || '2', 10);
    const op = strVal('la_matrix_op') || 'add';
    try {
      const A = readMatrix('la_a', size);
      const out = prepareResult('la_matrix_result');
      let R;
      if (op === 'scalar') {
        const k = numVal('la_scalar_k');
        if (!finite(k)) return showError('la_matrix_result', 'Enter scalar k.');
        R = matrixScalar(A, k);
        addRow(out, 'Operation', 'kA with k = ' + fmtNum(k, 6), { bold: true });
      } else {
        const B = readMatrix('la_b', size);
        if (op === 'add') R = matrixAdd(A, B, 1);
        else if (op === 'sub') R = matrixAdd(A, B, -1);
        else R = matrixMul(A, B);
        addRow(out, 'Operation', op === 'add' ? 'A + B' : op === 'sub' ? 'A - B' : 'AB', { bold: true });
      }
      renderMatrix(out, R, 'Result');
    } catch (err) {
      showError('la_matrix_result', err.message || 'Could not compute matrix operation.');
    }
  };

  window.calcLADeterminant = function () {
    const size = parseInt(strVal('la_matrix_size') || '2', 10);
    try {
      const A = readMatrix('la_a', size);
      const out = prepareResult('la_det_result');
      const det = determinant(A);
      addRow(out, 'det(A)', fmtNum(det, 6), { bold: true, color: COLORS.green });
      if (size === 3) {
        addHeading(out, 'Cofactor expansion along row 1');
        const m11 = determinant(matrixMinor(A, 0, 0));
        const m12 = determinant(matrixMinor(A, 0, 1));
        const m13 = determinant(matrixMinor(A, 0, 2));
        addText(out,
          'det(A) = a₁₁C₁₁ + a₁₂C₁₂ + a₁₃C₁₃\n' +
          '= ' + fmtNum(A[0][0]) + '(' + fmtNum(m11) + ') - ' + fmtNum(A[0][1]) + '(' + fmtNum(m12) + ') + ' + fmtNum(A[0][2]) + '(' + fmtNum(m13) + ')\n' +
          '= ' + fmtNum(det, 6));
      }
    } catch (err) {
      showError('la_det_result', err.message || 'Could not compute determinant.');
    }
  };

  window.calcLAInverse = function () {
    const size = parseInt(strVal('la_matrix_size') || '2', 10);
    if (size > 3) return showError('la_inv_result', 'Matrix inverse is limited to 3×3 here.');
    try {
      const A = readMatrix('la_a', size);
      const out = prepareResult('la_inv_result');
      const aug = A.map((row, i) => row.concat(matrixIdentity(size)[i]));
      addHeading(out, 'Gauss-Jordan steps');
      for (let i = 0; i < size; i++) {
        let pivot = i;
        while (pivot < size && nz(aug[pivot][i])) pivot += 1;
        if (pivot === size) return showError('la_inv_result', 'Matrix is singular; no inverse exists.');
        if (pivot !== i) {
          const tmp = aug[i]; aug[i] = aug[pivot]; aug[pivot] = tmp;
          addText(out, 'Swap R' + (i + 1) + ' and R' + (pivot + 1));
          renderMatrix(out, aug, '');
        }
        const p = aug[i][i];
        for (let j = 0; j < aug[i].length; j++) aug[i][j] /= p;
        addText(out, 'Scale R' + (i + 1) + ' by 1/' + fmtNum(p, 6));
        renderMatrix(out, aug, '');
        for (let r = 0; r < size; r++) {
          if (r === i) continue;
          const f = aug[r][i];
          if (nz(f)) continue;
          for (let c = 0; c < aug[r].length; c++) aug[r][c] -= f * aug[i][c];
          addText(out, 'R' + (r + 1) + ' ← R' + (r + 1) + ' - (' + fmtNum(f, 6) + ')R' + (i + 1));
          renderMatrix(out, aug, '');
        }
      }
      const inv = aug.map((r) => r.slice(size));
      addHeading(out, 'Inverse');
      renderMatrix(out, inv, 'A⁻¹');
    } catch (err) {
      showError('la_inv_result', err.message || 'Could not invert matrix.');
    }
  };

  window.calcLAEigen = function () {
    try {
      const A = readMatrix('la_a', 2);
      const out = prepareResult('la_eigen_result');
      const tr = A[0][0] + A[1][1];
      const detA = determinant(A);
      const D = tr * tr - 4 * detA;
      addText(out, 'Characteristic polynomial: λ² - tr(A)λ + det(A) = 0');
      addRow(out, 'tr(A)', fmtNum(tr, 6));
      addRow(out, 'det(A)', fmtNum(detA, 6));
      addRow(out, 'Discriminant', fmtNum(D, 6));
      if (D < 0) {
        const re = tr / 2, im = Math.sqrt(-D) / 2;
        addRow(out, 'Eigenvalues', fmtNum(re, 6) + ' ± ' + fmtNum(im, 6) + 'i');
        addText(out, 'Complex-conjugate eigenvalues; no real eigenvectors.');
        return;
      }
      const s = Math.sqrt(D), l1 = (tr + s) / 2, l2 = (tr - s) / 2;
      [l1, l2].forEach((lam, idx) => {
        addHeading(out, 'Eigenpair ' + (idx + 1));
        addRow(out, 'λ', fmtNum(lam, 6), { bold: true });
        const a = A[0][0] - lam, b = A[0][1], c = A[1][0], d = A[1][1] - lam;
        let v;
        if (!nz(b) || !nz(a)) v = [b, -a];
        else if (!nz(d) || !nz(c)) v = [-d, c];
        else v = idx === 0 ? [1, 0] : [0, 1];
        if (nz(v[0]) && nz(v[1])) v = [1, 0];
        addText(out, '(A - λI)v = 0 with matrix [[' + fmtNum(a, 4) + ', ' + fmtNum(b, 4) + '], [' + fmtNum(c, 4) + ', ' + fmtNum(d, 4) + ']]');
        addRow(out, 'Eigenvector', '[' + fmtNum(v[0], 6) + ', ' + fmtNum(v[1], 6) + ']');
      });
    } catch (err) {
      showError('la_eigen_result', err.message || 'Eigenvalue calculation failed.');
    }
  };

  window.calcLAVectors = function () {
    const ax = numVal('la_v1_x'), ay = numVal('la_v1_y'), az = numVal('la_v1_z');
    const bx = numVal('la_v2_x'), by = numVal('la_v2_y'), bz = numVal('la_v2_z');
    if (![ax, ay, az, bx, by, bz].every(finite)) return showError('la_vector_result', 'Enter both 3D vectors.');
    const out = prepareResult('la_vector_result');
    const dot = ax * bx + ay * by + az * bz;
    const cross = [ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx];
    addRow(out, 'Dot product', fmtNum(dot, 6), { bold: true, color: COLORS.green });
    addRow(out, 'Cross product', '[' + cross.map((v) => fmtNum(v, 6)).join(', ') + ']');
    const magA = Math.hypot(ax, ay, az), magB = Math.hypot(bx, by, bz);
    addRow(out, 'Angle', (!nz(magA) && !nz(magB)) ? fmtNum(deg(Math.acos(clamp(dot / (magA * magB), -1, 1))), 6) + '°' : 'undefined');
  };

  /* 4. CHEMISTRY */
  window.calcChemMolarMass = function () {
    const formula = strVal('chem_formula');
    try {
      const counts = parseChemicalFormula(formula);
      const out = prepareResult('chem_molar_result');
      let total = 0;
      addHeading(out, 'Breakdown');
      Object.keys(counts).sort().forEach((sym) => {
        const count = counts[sym];
        const mass = ATOMIC_MASS[sym] * count;
        total += mass;
        addRow(out, sym, count + ' × ' + fmtNum(ATOMIC_MASS[sym], 4) + ' = ' + fmtNum(mass, 4));
      });
      addRow(out, 'Total molar mass', fmtNum(total, 4) + ' g/mol', { bold: true, color: COLORS.green });
      appendSvg(out, moleculeDiagram(counts, formula));
    } catch (err) {
      showError('chem_molar_result', err.message || 'Could not parse formula.');
    }
  };

  function moleculeDiagram(counts, formula) {
    const w = 520, h = 245;
    const svg = svgEl('svg', { width: w, height: h, viewBox: '0 0 ' + w + ' ' + h, role: 'img', 'aria-label': 'Ball and stick model for ' + formula, style: 'background:' + COLORS.bg + ';border:1px solid rgba(255,255,255,0.08);border-radius:10px' });
    const atoms = [];
    Object.keys(counts).forEach((symbol) => { for (let i = 0; i < counts[symbol]; i++) atoms.push(symbol); });
    const center = atoms.indexOf('C') >= 0 ? atoms.indexOf('C') : 0;
    const ordered = atoms.splice(center, 1).concat(atoms);
    const cx = 260, cy = 125;
    const positions = ordered.map((symbol, index) => {
      if (index === 0) return { symbol: symbol, x: cx, y: cy };
      const angle = -Math.PI / 2 + (index - 1) * Math.PI * 2 / Math.max(1, ordered.length - 1);
      const radius = ordered.length === 2 ? 100 : 78;
      return { symbol: symbol, x: cx + Math.cos(angle) * radius, y: cy + Math.sin(angle) * radius };
    });
    if (formula.replace(/\s/g, '') === 'H2O') { positions[0] = { symbol: 'O', x: cx, y: cy }; positions[1] = { symbol: 'H', x: 180, y: 95 }; positions[2] = { symbol: 'H', x: 340, y: 95 }; }
    if (formula.replace(/\s/g, '') === 'CO2') { positions[0] = { symbol: 'C', x: cx, y: cy }; positions[1] = { symbol: 'O', x: 145, y: cy }; positions[2] = { symbol: 'O', x: 375, y: cy }; }
    positions.slice(1).forEach((atom) => svg.appendChild(svgEl('line', { x1: positions[0].x, y1: positions[0].y, x2: atom.x, y2: atom.y, stroke: '#9aa5bd', 'stroke-width': 8, 'stroke-linecap': 'round', opacity: 0.8 })));
    positions.forEach((atom) => {
      const color = atom.symbol === 'O' ? '#ff6b78' : atom.symbol === 'N' ? '#668cff' : atom.symbol === 'H' ? '#edf2ff' : atom.symbol === 'C' ? '#6ee7b7' : '#f5c451';
      svg.appendChild(svgEl('circle', { cx: atom.x, cy: atom.y, r: atom.symbol === 'H' ? 22 : 30, fill: color, stroke: '#ffffff', 'stroke-width': 2, opacity: 0.95 }));
      const label = svgEl('text', { x: atom.x, y: atom.y + 6, fill: atom.symbol === 'H' ? '#162033' : '#071018', 'font-size': 17, 'font-weight': 700, 'text-anchor': 'middle' });
      label.textContent = atom.symbol;
      svg.appendChild(label);
    });
    const title = svgEl('text', { x: 18, y: 24, fill: COLORS.accent, 'font-size': 12, 'letter-spacing': 1.2 });
    title.textContent = 'BALL-AND-STICK MODEL · ' + formula;
    svg.appendChild(title);
    const note = svgEl('text', { x: 18, y: 226, fill: COLORS.muted, 'font-size': 11 });
    note.textContent = 'Illustrative connectivity model; bond angles are not to scale.';
    svg.appendChild(note);
    return svg;
  }

  window.calcChemIdealGas = function () {
    let P = numVal('chem_gas_P'), V = numVal('chem_gas_V'), n = numVal('chem_gas_n'), T = numVal('chem_gas_T');
    const unit = strVal('chem_gas_T_unit') || 'K';
    if (finite(T) && unit.toUpperCase() === 'C') T += 273.15;
    const known = [P, V, n, T].filter(finite).length;
    if (known < 3) return showError('chem_gas_result', 'Enter any 3 of P, V, n, T.');
    const out = prepareResult('chem_gas_result');
    const R = CONST.R_atm;
    if (!finite(P)) P = n * R * T / V;
    else if (!finite(V)) V = n * R * T / P;
    else if (!finite(n)) n = P * V / (R * T);
    else if (!finite(T)) T = P * V / (n * R);
    addText(out, 'Using PV = nRT with R = 0.082057 L·atm·mol⁻¹·K⁻¹');
    addRow(out, 'Pressure P', fmtNum(P, 6) + ' atm');
    addRow(out, 'Volume V', fmtNum(V, 6) + ' L');
    addRow(out, 'Moles n', fmtNum(n, 6) + ' mol');
    addRow(out, 'Temperature T', fmtNum(T, 6) + ' K');
  };

  window.calcChemStoichiometry = function () {
    const rc = numVal('chem_stoich_reactant_coeff');
    const pc = numVal('chem_stoich_product_coeff');
    const moles = numVal('chem_stoich_moles');
    const rf = strVal('chem_stoich_reactant_formula');
    const pf = strVal('chem_stoich_product_formula');
    if (![rc, pc, moles].every(finite) || rc <= 0 || pc <= 0 || moles < 0 || !rf || !pf) return showError('chem_stoich_result', 'Enter coefficients, formulas, and reactant moles.');
    try {
      const productCounts = parseChemicalFormula(pf);
      const mm = molarMassFromCounts(productCounts);
      const prodMoles = moles * pc / rc;
      const grams = prodMoles * mm;
      const out = prepareResult('chem_stoich_result');
      addText(out, 'Balanced ratio: ' + fmtNum(rc, 4) + ' ' + rf + ' → ' + fmtNum(pc, 4) + ' ' + pf);
      addRow(out, 'Product moles', fmtNum(prodMoles, 6) + ' mol', { bold: true, color: COLORS.green });
      addRow(out, 'Product molar mass', fmtNum(mm, 4) + ' g/mol');
      addRow(out, 'Product mass', fmtNum(grams, 6) + ' g');
    } catch (err) {
      showError('chem_stoich_result', err.message || 'Stoichiometry failed.');
    }
  };

  window.calcChemHenderson = function () {
    const pKa = numVal('chem_hh_pKa');
    const acid = numVal('chem_hh_acid');
    const base = numVal('chem_hh_base');
    const target = numVal('chem_hh_target_pH');
    if (!finite(pKa)) return showError('chem_hh_result', 'Enter pKa.');
    const out = prepareResult('chem_hh_result');
    if (finite(acid) && finite(base) && acid > 0 && base > 0) {
      const pH = pKa + Math.log10(base / acid);
      addRow(out, 'pH', fmtNum(pH, 6), { bold: true, color: COLORS.green });
      addText(out, 'pH = pKa + log([A⁻]/[HA]) = ' + fmtNum(pKa, 4) + ' + log(' + fmtNum(base, 4) + '/' + fmtNum(acid, 4) + ')');
    }
    if (finite(target)) {
      const ratio = Math.pow(10, target - pKa);
      addRow(out, 'Required [A⁻]/[HA] for target pH', fmtNum(ratio, 6), { color: COLORS.blue, bold: true });
    }
    if (!(finite(acid) && finite(base) && acid > 0 && base > 0) && !finite(target)) showError('chem_hh_result', 'Enter acid/base concentrations and/or a target pH.');
  };

  window.renderChemPeriodicTable = function () {
    const host = byId('chem_periodic');
    if (!host) return;
    clearNode(host);
    host.className = 'result show';
    host.style.display = 'grid';
    host.style.display = 'grid';
    host.style.gridTemplateColumns = 'repeat(18, minmax(34px, 1fr))';
    host.style.gap = '0.25rem';
    host.style.minWidth = '680px';
    host.style.overflowX = 'auto';
    const byNumber = Object.fromEntries(PERIODIC_FULL.map((element) => [element.number, element]));
    const addElement = (number, column, row) => {
      const e = byNumber[number];
      if (!e) return;
      const card = document.createElement('div');
      card.style.border = '1px solid ' + COLORS.line;
      card.style.borderRadius = '10px';
      card.style.padding = '0.28rem'; card.style.minHeight = '58px'; card.style.background = 'rgba(139,123,255,0.07)';
      card.style.gridColumn = String(column); card.style.gridRow = String(row);
      card.title = e.name;
      const z = document.createElement('div'); z.textContent = String(e.number); z.style.fontSize = '0.68em'; z.style.color = COLORS.yellow;
      const sym = document.createElement('div'); sym.textContent = e.symbol; sym.style.fontSize = '1.05em'; sym.style.fontWeight = '700'; sym.style.color = ELEMENT_COLORS[elementCategory(e.number)];
      const name = document.createElement('div'); name.textContent = e.name; name.style.fontSize = '0.56em'; name.style.whiteSpace = 'nowrap'; name.style.overflow = 'hidden'; name.style.textOverflow = 'ellipsis';
      card.appendChild(z); card.appendChild(sym); card.appendChild(name);
      host.appendChild(card);
    };
    PERIODIC_ROWS.forEach((range, periodIndex) => {
      for (let number = range[0]; number <= range[1]; number++) {
        let column = number, row = periodIndex + 1;
        if (periodIndex === 0) column = number === 1 ? 1 : 18;
        if (periodIndex === 1) column = number === 3 ? 1 : number === 4 ? 2 : number - 3 + 12;
        if (periodIndex === 2) column = number === 11 ? 1 : number === 12 ? 2 : number - 11 + 12;
        if (periodIndex >= 3 && periodIndex <= 4) column = number - range[0] + 1;
        if (periodIndex >= 5) column = number <= 56 || number >= 88 && number <= 103 ? (number % 2 ? 1 : 2) : number - range[0] + 1;
        if (periodIndex === 5 && number >= 57 && number <= 71 || periodIndex === 6 && number >= 89 && number <= 103) return;
        addElement(number, column, row);
      }
    });
    const fBlock = document.createElement('div');
    fBlock.style.gridColumn = '4 / span 15'; fBlock.style.gridRow = '8 / span 2'; fBlock.style.display = 'grid'; fBlock.style.gridTemplateColumns = 'repeat(15, minmax(34px, 1fr))'; fBlock.style.gap = '0.25rem';
    [57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103].forEach((number, index) => { const e = byNumber[number]; const card = document.createElement('div'); card.style.border = '1px solid ' + COLORS.line; card.style.borderRadius = '8px'; card.style.padding = '0.2rem'; card.title = e.name; card.textContent = e.symbol; card.style.color = ELEMENT_COLORS[4]; card.style.fontSize = '0.75em'; fBlock.appendChild(card); });
    host.appendChild(fBlock);
  };

  /* 5. CALCULUS */
  window.calcNumericalDerivative = function () {
    const expr = strVal('calc_diff_expr');
    const a = numVal('calc_diff_a');
    if (!expr || !finite(a)) return showError('calc_diff_result', 'Enter f(x) and x = a.');
    const h = 1e-7;
    try {
      const fp = (safeEvalX(expr, a + h) - safeEvalX(expr, a - h)) / (2 * h);
      const out = prepareResult('calc_diff_result');
      addText(out, 'Central difference: f′(a) ≈ [f(a+h) - f(a-h)] / (2h), h = 1e-7');
      addRow(out, 'f′(' + fmtNum(a, 6) + ')', fmtNum(fp, 8), { bold: true, color: COLORS.green });
      appendSvg(out, derivativeDiagram(expr, a, h, fp));
    } catch (err) {
      showError('calc_diff_result', err.message || 'Derivative failed.');
    }
  };

  window.calcNumericalIntegration = function () {
    const expr = strVal('calc_int_expr');
    const a = numVal('calc_int_a'), b = numVal('calc_int_b');
    let n = Math.max(1, Math.round(numVal('calc_int_n')));
    if (!expr || !finite(a) || !finite(b) || a === b || !finite(n)) return showError('calc_int_result', 'Enter f(x), limits, and interval count n.');
    try {
      const trap = function (m) {
        const h = (b - a) / m;
        let sum = 0.5 * (safeEvalX(expr, a) + safeEvalX(expr, b));
        for (let i = 1; i < m; i++) sum += safeEvalX(expr, a + i * h);
        return sum * h;
      };
      const midpoint = function (m) {
        const h = (b - a) / m;
        let sum = 0;
        for (let i = 0; i < m; i++) sum += safeEvalX(expr, a + (i + 0.5) * h);
        return sum * h;
      };
      const simpson = function (m) {
        if (m % 2) m += 1;
        const h = (b - a) / m;
        let sum = safeEvalX(expr, a) + safeEvalX(expr, b);
        for (let i = 1; i < m; i++) sum += safeEvalX(expr, a + i * h) * (i % 2 ? 4 : 2);
        return sum * h / 3;
      };
      const t = trap(n), s = simpson(n), m = midpoint(n);
      const refN = Math.max(200, n * 10 + (n * 10 % 2));
      const ref = simpson(refN);
      const out = prepareResult('calc_int_result');
      addRow(out, 'Trapezoid', fmtNum(t, 8), { color: COLORS.yellow });
      addRow(out, 'Simpson 1/3', fmtNum(s, 8), { color: COLORS.green, bold: true });
      addRow(out, 'Midpoint', fmtNum(m, 8), { color: COLORS.blue });
      addTable(out, ['Method', 'Estimate', '|Error vs refined Simpson|'], [
        ['Trapezoid', fmtNum(t, 8), fmtNum(Math.abs(t - ref), 8)],
        ['Simpson', fmtNum(s, 8), fmtNum(Math.abs(s - ref), 8)],
        ['Midpoint', fmtNum(m, 8), fmtNum(Math.abs(m - ref), 8)]
      ]);
      appendSvg(out, integralDiagram(expr, a, b, n));
    } catch (err) {
      showError('calc_int_result', err.message || 'Integration failed.');
    }
  };

  function taylorDerivativeValue(type, a, n) {
    if (type === 'sin') {
      const cycle = [Math.sin(a), Math.cos(a), -Math.sin(a), -Math.cos(a)];
      return cycle[n % 4];
    }
    if (type === 'cos') {
      const cycle = [Math.cos(a), -Math.sin(a), -Math.cos(a), Math.sin(a)];
      return cycle[n % 4];
    }
    if (type === 'exp') return Math.exp(a);
    if (type === 'ln1p') {
      if (n === 0) return Math.log(1 + a);
      return (n % 2 ? 1 : -1) * factorial(n - 1) / Math.pow(1 + a, n);
    }
    return NaN;
  }

  function functionExact(type, x) {
    if (type === 'sin') return Math.sin(x);
    if (type === 'cos') return Math.cos(x);
    if (type === 'exp') return Math.exp(x);
    if (type === 'ln1p') return Math.log(1 + x);
    return NaN;
  }

  window.calcTaylorSeries = function () {
    const type = (strVal('calc_taylor_type') || 'sin') === 'ln' ? 'ln1p' : (strVal('calc_taylor_type') || 'sin');
    const a = numVal('calc_taylor_a'), N = Math.max(0, Math.round(numVal('calc_taylor_n'))), x = numVal('calc_taylor_x');
    if (![a, N, x].every(finite)) return showError('calc_taylor_result', 'Enter center a, order N, and x.');
    if (type === 'ln1p' && (a <= -1 || x <= -1)) return showError('calc_taylor_result', 'ln(1+x) needs x > -1 and a > -1.');
    const out = prepareResult('calc_taylor_result');
    let sum = 0;
    const rows = [];
    for (let n = 0; n <= N; n++) {
      const deriv = taylorDerivativeValue(type, a, n);
      const term = deriv * Math.pow(x - a, n) / factorial(n);
      sum += term;
      rows.push([n, fmtNum(deriv, 8), fmtNum(term, 8), fmtNum(sum, 8)]);
    }
    const exact = functionExact(type, x);
    addRow(out, 'Approximation', fmtNum(sum, 10), { bold: true, color: COLORS.green });
    addRow(out, 'Exact value', fmtNum(exact, 10));
    addRow(out, 'Absolute error', fmtNum(Math.abs(sum - exact), 10));
    addTable(out, ['n', 'f⁽ⁿ⁾(a)', 'termₙ', 'partial sum'], rows);
    appendSvg(out, taylorDiagram(type, a, N, x));
  };

  window.calcRelatedRates = function () {
    const scenario = strVal('calc_rr_scenario') || 'ladder';
    const out = prepareResult('calc_rr_result');
    if (scenario === 'ladder') {
      const x = numVal('calc_rr_x'), y = numVal('calc_rr_y'), dxdt = numVal('calc_rr_dxdt');
      if (![x, y, dxdt].every(finite) || y <= 0) return showError('calc_rr_result', 'For ladder: enter x, y, and dx/dt.');
      const dydt = -(x / y) * dxdt;
      addText(out, 'x² + y² = L² → 2x dx/dt + 2y dy/dt = 0');
      addRow(out, 'dy/dt', fmtNum(dydt, 6) + ' units/s', { bold: true, color: COLORS.green });
    } else if (scenario === 'circle') {
      const r = numVal('calc_rr_r'), drdt = numVal('calc_rr_drdt');
      if (![r, drdt].every(finite) || r <= 0) return showError('calc_rr_result', 'For circle: enter r and dr/dt.');
      const dAdt = 2 * Math.PI * r * drdt;
      addText(out, 'A = πr² → dA/dt = 2πr dr/dt');
      addRow(out, 'dA/dt', fmtNum(dAdt, 6) + ' units²/s', { bold: true, color: COLORS.green });
    } else {
      const H = numVal('calc_rr_light_h'), h = numVal('calc_rr_person_h'), x = numVal('calc_rr_x'), dxdt = numVal('calc_rr_dxdt');
      if (![H, h, x, dxdt].every(finite) || H <= h) return showError('calc_rr_result', 'For shadow: enter lamp height, person height, x, and dx/dt with lamp taller than person.');
      const dydt = h * dxdt / (H - h);
      addText(out, 'By similar triangles, y = hx/(H-h), so dy/dt = h/(H-h) · dx/dt');
      addRow(out, 'Shadow length rate dy/dt', fmtNum(dydt, 6) + ' units/s', { bold: true, color: COLORS.green });
      addRow(out, 'Shadow tip speed', fmtNum(dxdt + dydt, 6) + ' units/s');
    }
  };

  /* 6. OPTICS */
  function lensDiagram(f, dO, dI) {
    const w = 420, h = 180, cx = 210, cy = 90;
    const svg = svgEl('svg', { width: w, height: h, viewBox: '0 0 420 180', style: 'background:' + COLORS.bg + ';border:1px solid rgba(255,255,255,0.08);border-radius:10px' });
    const maxD = Math.max(Math.abs(dO), Math.abs(dI), Math.abs(f), 1);
    const scale = 120 / maxD;
    const xObj = cx - dO * scale;
    const xImg = cx + dI * scale;
    const fR = cx + f * scale, fL = cx - f * scale;
    svg.appendChild(svgEl('line', { x1: 10, y1: cy, x2: 410, y2: cy, stroke: '#777' }));
    svg.appendChild(svgEl('line', { x1: cx, y1: 20, x2: cx, y2: 160, stroke: COLORS.accent, 'stroke-width': 3 }));
    [fL, fR].forEach((x) => svg.appendChild(svgEl('circle', { cx: x, cy: cy, r: 3, fill: COLORS.yellow })));
    const oh = 42;
    const ih = oh * (-dI / dO);
    svg.appendChild(svgEl('line', { x1: xObj, y1: cy, x2: xObj, y2: cy - oh, stroke: COLORS.green, 'stroke-width': 3 }));
    svg.appendChild(svgEl('line', { x1: xImg, y1: cy, x2: xImg, y2: cy - ih, stroke: COLORS.red, 'stroke-width': 3 }));
    svg.appendChild(svgEl('line', { x1: xObj, y1: cy - oh, x2: cx, y2: cy - oh, stroke: COLORS.blue }));
    svg.appendChild(svgEl('line', { x1: cx, y1: cy - oh, x2: xImg, y2: cy - ih, stroke: COLORS.blue }));
    svg.appendChild(svgEl('line', { x1: xObj, y1: cy - oh, x2: cx, y2: cy, stroke: COLORS.yellow }));
    svg.appendChild(svgEl('line', { x1: cx, y1: cy, x2: xImg, y2: cy - ih, stroke: COLORS.yellow }));
    return svg;
  }

  window.calcThinLens = function () {
    let f = numVal('opt_f'), dO = numVal('opt_do'), dI = numVal('opt_di');
    const known = [f, dO, dI].filter(finite).length;
    if (known < 2) return showError('opt_lens_result', 'Enter any 2 of f, do, di.');
    if (!finite(f)) f = 1 / (1 / dO + 1 / dI);
    else if (!finite(dO)) dO = 1 / (1 / f - 1 / dI);
    else if (!finite(dI)) dI = 1 / (1 / f - 1 / dO);
    const m = -dI / dO;
    const out = prepareResult('opt_lens_result');
    addRow(out, 'Focal length f', fmtNum(f, 6));
    addRow(out, 'Object distance do', fmtNum(dO, 6));
    addRow(out, 'Image distance di', fmtNum(dI, 6), { bold: true, color: COLORS.green });
    addRow(out, 'Magnification m', fmtNum(m, 6));
    addRow(out, 'Image type', dI > 0 ? 'Real' : 'Virtual');
    addRow(out, 'Orientation', m < 0 ? 'Inverted' : 'Erect');
    addRow(out, 'Size class', Math.abs(m) > 1 ? 'Magnified' : Math.abs(m) < 1 ? 'Reduced' : 'Same size');
    appendSvg(out, lensDiagram(f, dO, dI));
  };

  window.calcSnellLaw = function () {
    const n1 = numVal('opt_n1'), n2 = numVal('opt_n2'), th1 = numVal('opt_theta1');
    if (![n1, n2, th1].every(finite) || n1 <= 0 || n2 <= 0) return showError('opt_snell_result', 'Enter n1, n2, and θ1.');
    const out = prepareResult('opt_snell_result');
    const s2 = n1 * Math.sin(rad(th1)) / n2;
    if (Math.abs(s2) > 1) {
      addRow(out, 'Result', 'Total internal reflection', { bold: true, color: COLORS.red });
    } else {
      addRow(out, 'θ2', fmtNum(deg(Math.asin(s2)), 6) + '°', { bold: true, color: COLORS.green });
    }
    addRow(out, 'Critical angle θc', n1 > n2 ? fmtNum(deg(Math.asin(n2 / n1)), 6) + '°' : 'Not applicable');
  };

  window.renderOpticsRefractiveTable = function () {
    const host = byId('opt_refractive_table');
    if (!host) return;
    clearNode(host);
    host.className = 'result show';
    addTable(host, ['Material', 'n'], REFRACTIVE.map((r) => [r[0], fmtNum(r[1], 4)]));
  };

  window.calcDiffractionGrating = function () {
    let d = numVal('opt_grating_d');
    const linesMm = numVal('opt_grating_linesmm');
    let lambdaNm = numVal('opt_grating_lambda');
    const theta = numVal('opt_grating_theta');
    const m = Math.round(numVal('opt_grating_m'));
    if (finite(linesMm) && linesMm > 0) d = 1 / (linesMm * 1000);
    if (!finite(d) || !finite(m) || m === 0) return showError('opt_grating_result', 'Enter spacing d (or lines/mm) and order m.');
    const out = prepareResult('opt_grating_result');
    if (finite(lambdaNm) && !finite(theta)) {
      const s = m * lambdaNm * 1e-9 / d;
      if (Math.abs(s) > 1) return showError('opt_grating_result', 'No physical angle for these inputs.');
      addRow(out, 'θ', fmtNum(deg(Math.asin(s)), 6) + '°', { bold: true, color: COLORS.green });
    } else if (finite(theta) && !finite(lambdaNm)) {
      lambdaNm = d * Math.sin(rad(theta)) / m * 1e9;
      addRow(out, 'λ', fmtNum(lambdaNm, 6) + ' nm', { bold: true, color: COLORS.green });
    } else {
      return showError('opt_grating_result', 'Enter either λ to solve θ, or θ to solve λ.');
    }
    addRow(out, 'Spacing d', fmtNum(d, 8) + ' m');
  };

  window.calcDoubleSlit = function () {
    const lambdaNm = numVal('opt_ds_lambda'), L = numVal('opt_ds_L'), d = numVal('opt_ds_d');
    if (![lambdaNm, L, d].every(finite) || d <= 0 || L <= 0) return showError('opt_ds_result', 'Enter λ (nm), L (m), and d (m).');
    const lambda = lambdaNm * 1e-9;
    const dy = lambda * L / d;
    const out = prepareResult('opt_ds_result');
    addRow(out, 'Fringe spacing Δy', fmtNum(dy, 8) + ' m', { bold: true, color: COLORS.green });
    const rows = [];
    for (let m = 1; m <= 5; m++) rows.push([m, fmtNum(m * dy, 8) + ' m']);
    addTable(out, ['Maximum m', 'Position yₘ'], rows);
  };

  /* 7. QUANTUM PHYSICS */
  function particleMass() {
    const preset = strVal('qp_box_particle') || 'electron';
    if (preset === 'electron') return CONST.me;
    if (preset === 'proton') return CONST.mp;
    return numVal('qp_box_mass');
  }

  function psiPlot(n, Lnm) {
    const L = Lnm * 1e-9;
    const pts = [];
    for (let i = 0; i <= 150; i++) {
      const x = L * i / 150;
      const y = Math.sqrt(2 / L) * Math.sin(n * Math.PI * x / L);
      pts.push({ x: x * 1e9, y: y / 50000 });
    }
    return plotSeries([{ label: 'ψ' + n + '(x)', color: COLORS.accent, points: pts }], 400, 180);
  }

  function energyLevelsSvg(levels) {
    const w = 220, h = 150;
    const svg = svgEl('svg', { width: w, height: h, viewBox: '0 0 220 150', style: 'background:' + COLORS.bg + ';border:1px solid rgba(255,255,255,0.08);border-radius:10px' });
    const emin = Math.min.apply(null, levels.map((x) => x.E));
    const emax = Math.max.apply(null, levels.map((x) => x.E));
    const py = (E) => 20 + (emax - E) * 100 / ((emax - emin) || 1);
    levels.forEach((lvl) => {
      const y = py(lvl.E);
      svg.appendChild(svgEl('line', { x1: 50, y1: y, x2: 170, y2: y, stroke: COLORS.green, 'stroke-width': 2 }));
      const t = svgEl('text', { x: 176, y: y + 4, fill: COLORS.text, 'font-size': 10 });
      t.textContent = 'n=' + lvl.n + ', ' + fmtNum(lvl.E, 4) + ' eV';
      svg.appendChild(t);
    });
    return svg;
  }

  window.calcParticleInBox = function () {
    const Lnm = numVal('qp_box_L');
    const n = Math.max(1, Math.round(numVal('qp_box_n')));
    const m = particleMass();
    if (![Lnm, n, m].every(finite) || Lnm <= 0 || m <= 0) return showError('qp_box_result', 'Enter L, n, and particle mass/preset.');
    const L = Lnm * 1e-9;
    const EJ = n * n * CONST.h * CONST.h / (8 * m * L * L);
    const EeV = EJ / CONST.e_charge;
    const out = prepareResult('qp_box_result');
    addRow(out, 'Energy', fmtNum(EeV, 8) + ' eV', { bold: true, color: COLORS.green });
    addRow(out, 'Energy', fmtNum(EJ, 8) + ' J');
    addText(out, 'ψₙ(x) = √(2/L) sin(nπx/L)');
    appendSvg(out, psiPlot(n, Lnm));
    appendSvg(out, energyLevelsSvg([1, 2, 3].map((k) => ({ n: k, E: (k * k * CONST.h * CONST.h / (8 * m * L * L)) / CONST.e_charge }))));
  };

  window.calcHydrogenLevels = function () {
    const n = Math.max(1, Math.round(numVal('qp_h_n')));
    if (!finite(n) || n > 7) return showError('qp_h_result', 'Enter n from 1 to 7.');
    const E = -13.6 / (n * n);
    const out = prepareResult('qp_h_result');
    addRow(out, 'Energy Eₙ', fmtNum(E, 6) + ' eV', { bold: true, color: COLORS.green });
    if (n > 1) {
      const dE = Math.abs((-13.6 / ((n - 1) * (n - 1))) - E) * CONST.e_charge;
      const lambda = CONST.h * CONST.c / dE;
      addRow(out, 'n → n-1 photon λ', fmtNum(lambda * 1e9, 6) + ' nm', { color: COLORS.blue });
    }
    appendSvg(out, energyLevelsSvg([1, 2, 3, 4, 5, 6, 7].map((k) => ({ n: k, E: -13.6 / (k * k) }))));
  };

  window.calcDeBroglie = function () {
    const preset = strVal('qp_db_preset') || 'custom';
    let m = numVal('qp_db_mass');
    if (preset === 'electron') m = CONST.me;
    else if (preset === 'proton') m = CONST.mp;
    else if (preset === 'neutron') m = CONST.mn;
    const v = numVal('qp_db_velocity');
    if (![m, v].every(finite) || m <= 0 || v <= 0) return showError('qp_db_result', 'Enter mass and velocity.');
    const lambda = CONST.h / (m * v);
    const out = prepareResult('qp_db_result');
    addRow(out, 'λ', fmtNum(lambda * 1e9, 8) + ' nm', { bold: true, color: COLORS.green });
    addRow(out, 'λ', fmtNum(lambda * 1e10, 8) + ' Å');
    addRow(out, 'λ', fmtNum(lambda * 1e12, 8) + ' pm');
  };

  window.calcHeisenberg = function () {
    const dx = numVal('qp_unc_dx');
    const dp = numVal('qp_unc_dp');
    const out = prepareResult('qp_unc_result');
    if (finite(dx) && dx > 0) {
      const minDp = CONST.hbar / (2 * dx);
      addRow(out, 'Minimum Δp', fmtNum(minDp, 8) + ' kg·m/s', { bold: true, color: COLORS.green });
      addRow(out, 'Minimum Δv (electron)', fmtNum(minDp / CONST.me, 8) + ' m/s');
      addRow(out, 'Minimum Δv (proton)', fmtNum(minDp / CONST.mp, 8) + ' m/s');
    }
    if (finite(dp) && dp > 0) {
      const minDx = CONST.hbar / (2 * dp);
      addRow(out, 'Minimum Δx', fmtNum(minDx, 8) + ' m', { color: COLORS.blue, bold: true });
    }
    if (!(finite(dx) && dx > 0) && !(finite(dp) && dp > 0)) showError('qp_unc_result', 'Enter Δx or Δp.');
  };

  window.calcPhotoelectric = function () {
    const lambdaNm = numVal('qp_pe_lambda');
    const metal = strVal('qp_pe_metal') || 'Cs';
    const phi = PHOTO_METALS[metal];
    if (!finite(lambdaNm) || lambdaNm <= 0 || !finite(phi)) return showError('qp_pe_result', 'Enter wavelength and choose a metal.');
    const photonJ = CONST.h * CONST.c / (lambdaNm * 1e-9);
    const photoneV = photonJ / CONST.e_charge;
    const KE = photoneV - phi;
    const out = prepareResult('qp_pe_result');
    addRow(out, 'Photon energy', fmtNum(photoneV, 6) + ' eV');
    addRow(out, 'Work function φ', fmtNum(phi, 6) + ' eV');
    addRow(out, 'Photoelectric effect?', KE > 0 ? 'Yes' : 'No', { bold: true, color: KE > 0 ? COLORS.green : COLORS.red });
    addRow(out, 'Max kinetic energy', KE > 0 ? fmtNum(KE, 6) + ' eV' : '0 eV');
  };

  /* 8. LINEAR PROGRAMMING */
  window.renderLPConstraints = function () {
    const host = byId('lp_constraints');
    if (!host) return;
    clearNode(host);
    for (let i = 1; i <= 5; i++) {
      const row = document.createElement('div');
      row.style.display = 'grid';
      row.style.gridTemplateColumns = '1fr 1fr auto 1fr';
      row.style.gap = '0.35rem';
      row.style.marginBottom = '0.35rem';
      const a = document.createElement('input'); a.type = 'number'; a.step = 'any'; a.id = 'lp_a_' + i; a.placeholder = 'a'; a.setAttribute('aria-label', `Constraint ${i} coefficient for x1`);
      const b = document.createElement('input'); b.type = 'number'; b.step = 'any'; b.id = 'lp_b_' + i; b.placeholder = 'b'; b.setAttribute('aria-label', `Constraint ${i} coefficient for x2`);
      const op = document.createElement('select'); op.id = 'lp_op_' + i; op.setAttribute('aria-label', `Constraint ${i} operator`); ['<=', '>=', '='].forEach((v) => { const o = document.createElement('option'); o.value = v; o.textContent = v; op.appendChild(o); });
      const c = document.createElement('input'); c.type = 'number'; c.step = 'any'; c.id = 'lp_c_' + i; c.placeholder = 'c'; c.setAttribute('aria-label', `Constraint ${i} right-hand side`);
      row.appendChild(a); row.appendChild(b); row.appendChild(op); row.appendChild(c);
      host.appendChild(row);
    }
  };

  window.loadLPExample = function (exampleNumber) {
    const examples = { 1: 'production', 2: 'diet', 3: 'blending' };
    const ex = examples[exampleNumber] || strVal('lp_example') || 'production';
    const sets = {
      production: { mode: 'max', c1: 3, c2: 5, cons: [[2, 1, '<=', 18], [2, 3, '<=', 42], [3, 1, '<=', 24]] },
      diet: { mode: 'min', c1: 0.5, c2: 0.8, cons: [[1, 1, '>=', 10], [2, 1, '>=', 16]] },
      blending: { mode: 'min', c1: 8, c2: 6, cons: [[1, 1, '=', 100], [1, 0, '>=', 30], [0, 1, '>=', 20]] }
    };
    const s = sets[ex] || sets.production;
    if (byId('lp_obj_type')) byId('lp_obj_type').value = s.mode;
    if (byId('lp_c1')) byId('lp_c1').value = s.c1;
    if (byId('lp_c2')) byId('lp_c2').value = s.c2;
    for (let i = 1; i <= 5; i++) {
      const a = byId('lp_a_' + i), b = byId('lp_b_' + i), op = byId('lp_op_' + i), c = byId('lp_c_' + i);
      if (!a || !b || !op || !c) continue;
      const row = s.cons[i - 1];
      setField(a, row ? row[0] : '');
      setField(b, row ? row[1] : '');
      setField(op, row ? row[2] : '<=');
      setField(c, row ? row[3] : '');
    }
  };

  window.solveLinearProgram = function () {
    const model = { mode: strVal('lp_obj_type') || 'max', c1: numVal('lp_c1'), c2: numVal('lp_c2'), constraints: [] };
    if (![model.c1, model.c2].every(finite)) return showError('lp_result', 'Enter objective coefficients c1 and c2.');
    for (let i = 1; i <= 5; i++) {
      const a = numVal('lp_a_' + i), b = numVal('lp_b_' + i), c = numVal('lp_c_' + i), op = strVal('lp_op_' + i) || '<=';
      if ([a, b, c].every(finite)) model.constraints.push({ a: a, b: b, c: c, op: op });
    }
    if (!model.constraints.length) return showError('lp_result', 'Enter at least one constraint.');
    const graph = solveGraphicalLP(model);
    const simplex = solveSimplex2D(model);
    const out = prepareResult('lp_result');
    addHeading(out, 'Graphical method');
    if (!graph.ok) {
      addText(out, graph.reason, COLORS.red);
    } else {
      addRow(out, 'Optimal point', '(' + fmtNum(graph.optimal.x, 6) + ', ' + fmtNum(graph.optimal.y, 6) + ')', { bold: true, color: COLORS.green });
      addRow(out, 'Objective value', fmtNum(graph.optimal.z, 6));
      addTable(out, ['Vertex', 'x1', 'x2', 'Objective'], graph.vertices.map((p, i) => ['V' + (i + 1), fmtNum(p.x, 6), fmtNum(p.y, 6), fmtNum(p.z, 6)]));
      appendSvg(out, renderLPGraph(graph, model));
    }
    addHeading(out, 'Simplex tableau');
    if (!simplex.ok) {
      addText(out, simplex.reason, COLORS.red);
    }
    simplex.steps.forEach((step, idx) => {
      addText(out, (idx + 1) + '. ' + step.note);
      const headers = ['Basis'].concat(simplex.varNames || []).concat(['RHS']);
      const rows = step.rows.map((r, i) => [simplex.varNames[step.basis[i]]].concat(r.coeffs.map((v) => fmtNum(v, 4))).concat([fmtNum(r.rhs, 4)]));
      rows.push(['Cj-Zj'].concat(step.reduced.map((v) => fmtNum(v, 4))).concat([fmtNum(step.z, 4)]));
      addTable(out, headers, rows);
    });
    if (simplex.ok && simplex.solution) {
      addRow(out, 'Simplex x1', fmtNum(simplex.solution[0], 6));
      addRow(out, 'Simplex x2', fmtNum(simplex.solution[1], 6));
      addRow(out, 'Simplex objective', fmtNum(simplex.objective, 6), { bold: true, color: COLORS.green });
    }
  };

  window.initStemTools = function () {
    window.renderTrigIdentities();
    window.renderChemPeriodicTable();
    window.renderOpticsRefractiveTable();
    if (byId('la_matrix_size')) window.renderLAMatrixInputs();
    if (byId('lp_constraints')) window.renderLPConstraints();
    if (byId('trig_unit_circle')) window.initTrigUnitCircle();
    const laSize = byId('la_matrix_size');
    if (laSize && !laSize.__stemBound) {
      laSize.__stemBound = true;
      laSize.addEventListener('change', window.renderLAMatrixInputs);
    }
    const lpExample = byId('lp_example');
    if (lpExample && !lpExample.__stemBound) {
      lpExample.__stemBound = true;
      lpExample.addEventListener('change', window.loadLPExample);
    }
  };

  window.StemTools = {
    calcDESecondOrder: window.calcDESecondOrder,
    calcDEIVP: window.calcDEIVP,
    initTrigUnitCircle: window.initTrigUnitCircle,
    calcTrigTriangle: window.calcTrigTriangle,
    renderTrigIdentities: window.renderTrigIdentities,
    renderLAMatrixInputs: window.renderLAMatrixInputs,
    calcLAMatrixOp: window.calcLAMatrixOp,
    calcLADeterminant: window.calcLADeterminant,
    calcLAInverse: window.calcLAInverse,
    calcLAEigen: window.calcLAEigen,
    calcLAVectors: window.calcLAVectors,
    calcChemMolarMass: window.calcChemMolarMass,
    calcChemIdealGas: window.calcChemIdealGas,
    calcChemStoichiometry: window.calcChemStoichiometry,
    calcChemHenderson: window.calcChemHenderson,
    renderChemPeriodicTable: window.renderChemPeriodicTable,
    calcNumericalDerivative: window.calcNumericalDerivative,
    calcNumericalIntegration: window.calcNumericalIntegration,
    calcTaylorSeries: window.calcTaylorSeries,
    calcRelatedRates: window.calcRelatedRates,
    calcThinLens: window.calcThinLens,
    calcSnellLaw: window.calcSnellLaw,
    renderOpticsRefractiveTable: window.renderOpticsRefractiveTable,
    calcDiffractionGrating: window.calcDiffractionGrating,
    calcDoubleSlit: window.calcDoubleSlit,
    calcParticleInBox: window.calcParticleInBox,
    calcHydrogenLevels: window.calcHydrogenLevels,
    calcDeBroglie: window.calcDeBroglie,
    calcHeisenberg: window.calcHeisenberg,
    calcPhotoelectric: window.calcPhotoelectric,
    renderLPConstraints: window.renderLPConstraints,
    loadLPExample: window.loadLPExample,
    solveLinearProgram: window.solveLinearProgram,
    init: window.initStemTools
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', window.initStemTools);
  } else {
    window.initStemTools();
  }
})();
