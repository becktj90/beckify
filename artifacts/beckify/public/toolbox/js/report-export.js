/* ============================================================================
   CALCULATION REPORT EXPORT — PDF submittal sheets
   ============================================================================
   Any calculator can register a report source; a shared modal then collects
   project metadata and renders a submittal sheet with jsPDF.

   jsPDF is ~366 KB, so it is fetched on the first export rather than on every
   toolbox visit. Until someone actually exports, the toolbox pays nothing.

   A calculator registers itself with:

     registerReport('cfa_result', {
       title: 'Conduit Fill',
       inputs:   () => [['Raceway', 'EMT 2 in'], ...],
       results:  () => [['Fill', '31.2 %', 'pass'], ...],   // 3rd item optional
       formula:  () => 'Fill% = ...',
       codeRefs: () => ['NEC Ch.9 Table 1 — fill limits', ...],
     });

   Every getter is called at export time so the sheet reflects the values on
   screen at that moment.
   ============================================================================ */

const JSPDF_SRC = 'js/vendor/jspdf.umd.min.js';
const REPORTS = {};

let jsPdfPromise = null;

/** Loads jsPDF once and resolves with the jsPDF constructor. */
function loadJsPdf() {
  if (jsPdfPromise) return jsPdfPromise;
  jsPdfPromise = new Promise(function (resolve, reject) {
    if (window.jspdf && window.jspdf.jsPDF) return resolve(window.jspdf.jsPDF);
    const s = document.createElement('script');
    s.src = JSPDF_SRC;
    s.onload = function () {
      if (window.jspdf && window.jspdf.jsPDF) resolve(window.jspdf.jsPDF);
      else reject(new Error('jsPDF loaded but did not register'));
    };
    s.onerror = function () {
      jsPdfPromise = null; // allow a retry
      reject(new Error('Could not load the PDF library'));
    };
    document.head.appendChild(s);
  });
  return jsPdfPromise;
}

/** Registers a report source against the calculator's result element id. */
function registerReport(resultId, spec) {
  REPORTS[resultId] = spec;
}

/* ---------------------------------------------------------------------------
   Generic fallback: scrape whatever the calculator already rendered.
   Lets every calculator export something useful without bespoke wiring.
   --------------------------------------------------------------------------- */
function scrapeReport(section, resultId) {
  const el = document.getElementById(resultId);
  const rows = [];
  if (el) {
    el.querySelectorAll('.res-row').forEach(function (r) {
      const label = r.querySelector('.res-label');
      const value = r.querySelector('.res-val');
      if (!label) return;
      const l = label.textContent.trim();
      const v = value ? value.textContent.trim() : '';
      if (!v) return; // section heading inside the result list
      let status = '';
      const lower = v.toLowerCase();
      if (lower.indexOf('pass') >= 0 || v.indexOf('✔') >= 0) status = 'pass';
      else if (lower.indexOf('fail') >= 0 || v.indexOf('✘') >= 0) status = 'fail';
      rows.push([l, v, status]);
    });
  }

  const inputs = [];
  if (section) {
    section.querySelectorAll('input, select').forEach(function (field) {
      if (field.type === 'button' || field.type === 'submit') return;
      if (field.closest('.result')) return;
      const id = field.id || '';
      if (/search/i.test(id)) return;
      // Find the field's visible label.
      let labelText = '';
      const wrap = field.closest('div');
      const lab = wrap ? wrap.querySelector('label') : null;
      if (lab) labelText = lab.textContent.trim();
      if (!labelText && id) labelText = id;
      if (!labelText) return;
      let value;
      if (field.type === 'checkbox') value = field.checked ? 'Yes' : 'No';
      else if (field.tagName === 'SELECT') {
        const opt = field.options[field.selectedIndex];
        value = opt ? opt.textContent.trim() : field.value;
      } else value = field.value;
      if (value === '' || value == null) return;
      inputs.push([labelText, String(value)]);
    });
  }

  const formulaEl = section ? section.querySelector('.formula-box') : null;
  const infoEl = section ? section.querySelector('.section-info-body') : null;

  return {
    inputs: inputs,
    results: rows,
    formula: formulaEl ? formulaEl.textContent.replace(/\s+/g, ' ').trim() : '',
    codeRefs: infoEl ? extractCodeRefs(infoEl.textContent) : [],
  };
}

/** Pulls NEC/IEC/IEEE citations out of an info panel's prose. */
function extractCodeRefs(text) {
  const found = [];
  const seen = {};
  const patterns = [
    /NEC\s+(?:Table\s+)?[0-9]+\.[0-9]+(?:\([A-Z0-9]\))*(?:\([0-9]\))*/g,
    /NEC\s+(?:Chapter|Ch\.)\s*[0-9]+(?:,?\s*Tables?\s*[0-9, &]+)?/g,
    /NEC\s+Annex\s+[A-Z](?:,\s*Table\s*[A-Z0-9.]+)?/g,
    /(?:Table|Article)\s+[0-9]+\.[0-9]+(?:\([A-Z0-9]\))*/g,
    /IEC\s+[0-9]+/g,
    /IEEE\s+[0-9.]+/g,
    /NEMA\s+[0-9]+/g,
    /\b[0-9]{3}\.[0-9]+(?:\([A-Z]\))?(?:\([0-9]\))?(?:\([a-z]\))?/g,
  ];
  patterns.forEach(function (re) {
    let m;
    while ((m = re.exec(text)) !== null) {
      const s = m[0].replace(/\s+/g, ' ').trim();
      if (!seen[s]) { seen[s] = 1; found.push(s); }
    }
  });
  // "Table 310.16" is noise once "NEC Table 310.16" is listed, so drop any
  // reference wholly contained in a longer one.
  const labelled = found.map(function (r) {
    return /^[0-9]/.test(r) ? 'NEC ' + r : r;
  });
  const deduped = labelled.filter(function (a) {
    return !labelled.some(function (b) { return b !== a && b.indexOf(a) >= 0; });
  });
  return deduped.slice(0, 12);
}

/* ---------------------------------------------------------------------------
   Modal
   --------------------------------------------------------------------------- */

const META_KEY = 'toolbox-report-meta';

function loadMeta() {
  try {
    return JSON.parse(localStorage.getItem(META_KEY) || '{}') || {};
  } catch (_) { return {}; }
}

function saveMeta(meta) {
  try { localStorage.setItem(META_KEY, JSON.stringify(meta)); } catch (_) {}
}

function buildModal() {
  let modal = document.getElementById('report-modal');
  if (modal) return modal;

  modal = document.createElement('div');
  modal.id = 'report-modal';
  modal.className = 'report-modal';
  modal.setAttribute('role', 'dialog');
  modal.setAttribute('aria-modal', 'true');
  modal.setAttribute('aria-labelledby', 'report-modal-title');
  modal.hidden = true;

  const panel = document.createElement('div');
  panel.className = 'report-panel';

  const h = document.createElement('div');
  h.className = 'report-panel-head';
  const title = document.createElement('h3');
  title.id = 'report-modal-title';
  title.textContent = 'Export calculation submittal';
  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'report-close';
  close.setAttribute('aria-label', 'Close');
  close.textContent = '✕';
  close.onclick = closeReportModal;
  h.appendChild(title);
  h.appendChild(close);

  const body = document.createElement('div');
  body.className = 'report-panel-body';

  const intro = document.createElement('p');
  intro.className = 'report-intro';
  intro.textContent =
    'These details appear in the submittal header. They are remembered on this ' +
    'device so you do not have to retype them for the next calculation.';
  body.appendChild(intro);

  const fields = [
    ['rpt_project', 'Project / Site Name', 'e.g. LC-9 3/4 Power Distribution'],
    ['rpt_engineer', 'Engineer / Technician', 'e.g. T. Beck, PE'],
    ['rpt_job', 'Job / Permit Number', 'e.g. JOB-2026-0142'],
  ];
  fields.forEach(function (f) {
    const wrap = document.createElement('div');
    wrap.className = 'report-field';
    const lab = document.createElement('label');
    lab.setAttribute('for', f[0]);
    lab.textContent = f[1];
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.id = f[0];
    inp.placeholder = f[2];
    wrap.appendChild(lab);
    wrap.appendChild(inp);
    body.appendChild(wrap);
  });

  const preview = document.createElement('div');
  preview.className = 'report-preview';
  preview.id = 'report-preview';
  body.appendChild(preview);

  const status = document.createElement('p');
  status.className = 'report-status';
  status.id = 'report-status';
  body.appendChild(status);

  const foot = document.createElement('div');
  foot.className = 'report-panel-foot';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'btn btn-secondary';
  cancel.textContent = 'Cancel';
  cancel.onclick = closeReportModal;
  const go = document.createElement('button');
  go.type = 'button';
  go.className = 'btn';
  go.id = 'report-generate';
  go.textContent = 'Generate PDF';
  foot.appendChild(cancel);
  foot.appendChild(go);

  panel.appendChild(h);
  panel.appendChild(body);
  panel.appendChild(foot);
  modal.appendChild(panel);

  modal.addEventListener('click', function (e) {
    if (e.target === modal) closeReportModal();
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !modal.hidden) closeReportModal();
  });

  document.body.appendChild(modal);
  return modal;
}

function closeReportModal() {
  const modal = document.getElementById('report-modal');
  if (modal) modal.hidden = true;
  document.body.classList.remove('report-open');
}

window.openReportModal = function (sectionId, resultId) {
  const modal = buildModal();
  const section = document.getElementById(sectionId);
  const spec = REPORTS[resultId] || {};

  const scraped = scrapeReport(section, resultId);
  const data = {
    title: spec.title || (section && section.querySelector('h2')
      ? section.querySelector('h2').textContent.replace(/[^\x20-\x7E]/g, '').trim()
      : 'Calculation'),
    inputs: (spec.inputs && spec.inputs()) || scraped.inputs,
    results: (spec.results && spec.results()) || scraped.results,
    formula: (spec.formula && spec.formula()) || scraped.formula,
    codeRefs: (spec.codeRefs && spec.codeRefs()) || scraped.codeRefs,
  };

  const preview = document.getElementById('report-preview');
  preview.textContent = '';
  const pt = document.createElement('div');
  pt.className = 'report-preview-title';
  pt.textContent = data.title;
  preview.appendChild(pt);
  const ps = document.createElement('div');
  ps.className = 'report-preview-sub';
  ps.textContent = data.inputs.length + ' input parameter' + (data.inputs.length === 1 ? '' : 's') +
    ' · ' + data.results.length + ' result' + (data.results.length === 1 ? '' : 's') +
    ' · ' + data.codeRefs.length + ' code reference' + (data.codeRefs.length === 1 ? '' : 's');
  preview.appendChild(ps);

  const statusEl = document.getElementById('report-status');
  statusEl.textContent = '';
  statusEl.className = 'report-status';

  if (!data.results.length) {
    statusEl.textContent = 'Run the calculation first — there are no results to export yet.';
    statusEl.className = 'report-status warn';
  }

  const meta = loadMeta();
  ['rpt_project', 'rpt_engineer', 'rpt_job'].forEach(function (id) {
    const el = document.getElementById(id);
    if (el) el.value = meta[id] || '';
  });

  // The generate handler closes over `data`, so there is no need to stash it.
  document.getElementById('report-generate').onclick = function () { generateReport(data); };

  modal.hidden = false;
  document.body.classList.add('report-open');
  const first = document.getElementById('rpt_project');
  if (first) first.focus();
};

/* ---------------------------------------------------------------------------
   PDF rendering
   ---------------------------------------------------------------------------
   jsPDF's built-in fonts are WinAnsi/Latin-1, so anything outside that range
   (x, sqrt, <=, delta, theta, ohm, arrows, tick marks) renders as mojibake and
   throws the glyph spacing off. Everything drawn goes through pdfText() first.
   --------------------------------------------------------------------------- */

const PAGE = { w: 612, h: 792, margin: 48, footer: 26 };

const GLYPHS = [
  [/[\u2713\u2714]/g, 'PASS'], [/[\u2717\u2718]/g, 'FAIL'],
  [/\u00d7/g, 'x'], [/\u00f7/g, '/'], [/\u221a/g, 'sqrt'],
  [/\u2264/g, '<='], [/\u2265/g, '>='], [/\u2260/g, '!='], [/\u2248/g, '~='],
  [/\u0394/g, 'delta'], [/\u03b8/g, 'theta'], [/\u03c6|\u00d8/g, 'ph'],
  [/\u03a9/g, 'ohm'], [/\u00b5|\u03bc/g, 'u'], [/\u03a3/g, 'sum'],
  [/\u2190/g, '<-'], [/\u2192/g, '->'], [/\u21d2/g, '=>'], [/\u2194|\u21c4/g, '<->'],
  [/\u2022/g, '-'], [/[\u2013\u2014]/g, '-'], [/[\u2018\u2019]/g, "'"], [/[\u201c\u201d]/g, '"'],
  [/\u00b2/g, '2'], [/\u00b3/g, '3'], [/\u00b0/g, ' deg'], [/\u2026/g, '...'],
  [/\u00b1/g, '+/-'], [/\u2044/g, '/'], [/\u00a0/g, ' '],
];

/** Makes a string safe for jsPDF's Latin-1 core fonts. */
function pdfText(value) {
  let s = String(value == null ? '' : value);
  GLYPHS.forEach(function (g) { s = s.replace(g[0], g[1]); });
  // Anything still outside Latin-1 would render as a blank box.
  s = s.replace(/[^\x20-\x7E\xA1-\xFF]/g, '');
  // Substitution can leave gaps such as "( degC)"; close them back up.
  return s.replace(/\(\s+/g, '(').replace(/\s+\)/g, ')').replace(/[ \t]{2,}/g, ' ');
}

/** Shared cursor so page breaks are visible to every drawing helper. */
function makeCursor(doc) {
  return {
    doc: doc,
    y: PAGE.margin,
    limit: PAGE.h - PAGE.margin - PAGE.footer,
    need: function (h) {
      if (this.y + h <= this.limit) return;
      drawFooter(this.doc);
      this.doc.addPage();
      this.y = PAGE.margin;
    },
  };
}

function generateReport(data) {
  const statusEl = document.getElementById('report-status');
  const btn = document.getElementById('report-generate');
  statusEl.className = 'report-status';
  statusEl.textContent = 'Preparing PDF...';
  btn.disabled = true;

  const meta = {
    rpt_project: (document.getElementById('rpt_project') || {}).value || '',
    rpt_engineer: (document.getElementById('rpt_engineer') || {}).value || '',
    rpt_job: (document.getElementById('rpt_job') || {}).value || '',
  };
  saveMeta(meta);

  loadJsPdf().then(function (JsPDF) {
    const doc = new JsPDF({ unit: 'pt', format: 'letter' });
    renderSubmittal(doc, data, meta);
    const stamp = new Date().toISOString().slice(0, 10);
    const slug = pdfText(data.title).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    doc.save('beckify-' + (slug || 'calculation') + '-' + stamp + '.pdf');
    statusEl.textContent = 'PDF downloaded.';
    statusEl.className = 'report-status ok';
    btn.disabled = false;
    setTimeout(closeReportModal, 900);
  }).catch(function (err) {
    statusEl.textContent = err && err.message ? err.message : 'PDF export failed.';
    statusEl.className = 'report-status warn';
    btn.disabled = false;
  });
}

const INK = [17, 20, 32];
const MUTED = [110, 115, 140];
const ACCENT = [92, 78, 214];
const PASS_RGB = [22, 121, 78];
const FAIL_RGB = [178, 44, 44];

function renderSubmittal(doc, data, meta) {
  const M = PAGE.margin;
  const right = PAGE.w - M;
  const cur = makeCursor(doc);

  /* ── Brand header ── */
  doc.setFillColor(17, 20, 32);
  doc.rect(0, 0, PAGE.w, 74, 'F');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(17);
  doc.setTextColor(255, 255, 255);
  const brand = 'BECKIFY.COM';
  doc.text(brand, M, 34);
  // Measure rather than guess, so the subtitle never collides with the wordmark.
  const brandW = doc.getTextWidth(brand);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  doc.setTextColor(168, 170, 200);
  doc.text('Engineering Tools', M + brandW + 10, 34);

  doc.setFontSize(8);
  doc.text(pdfText('Generated ' + new Date().toLocaleString()), right, 26, { align: 'right' });
  doc.text('Calculation submittal sheet', right, 38, { align: 'right' });

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.setTextColor(255, 255, 255);
  doc.text(pdfText(data.title), M, 58);

  cur.y = 74 + 26;

  /* ── Project metadata ── */
  sectionHeading(cur, 'Project');
  doc.setFontSize(9);
  [['Project / Site', meta.rpt_project || '-'],
   ['Engineer / Technician', meta.rpt_engineer || '-'],
   ['Job / Permit No.', meta.rpt_job || '-']].forEach(function (r) {
    cur.need(16);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(MUTED[0], MUTED[1], MUTED[2]);
    doc.text(pdfText(r[0]), M, cur.y);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(INK[0], INK[1], INK[2]);
    doc.text(pdfText(r[1]), M + 150, cur.y);
    cur.y += 15;
  });

  if (data.inputs.length) {
    sectionHeading(cur, 'Input parameters');
    drawTable(cur, data.inputs, false);
  }

  if (data.results.length) {
    sectionHeading(cur, 'Calculated results');
    drawTable(cur, data.results, true);
  }

  if (data.formula) {
    sectionHeading(cur, 'Formula & methodology');
    doc.setFont('courier', 'normal');
    doc.setFontSize(8.5);
    const lines = doc.splitTextToSize(pdfText(data.formula), right - M - 20);
    // Break the box as a unit when it fits on a fresh page, else let it flow.
    const boxH = lines.length * 11 + 16;
    if (boxH < cur.limit - PAGE.margin) cur.need(boxH + 6);
    doc.setFillColor(244, 245, 250);
    doc.rect(M, cur.y - 10, right - M, boxH, 'F');
    doc.setTextColor(INK[0], INK[1], INK[2]);
    doc.text(lines, M + 10, cur.y + 2);
    cur.y += boxH + 6;
  }

  if (data.codeRefs.length) {
    sectionHeading(cur, 'Governing code references');
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    data.codeRefs.forEach(function (ref) {
      const wrapped = doc.splitTextToSize(pdfText(ref), right - M - 18);
      cur.need(wrapped.length * 12 + 2);
      doc.setTextColor(ACCENT[0], ACCENT[1], ACCENT[2]);
      doc.text('-', M + 2, cur.y);
      doc.setTextColor(INK[0], INK[1], INK[2]);
      doc.text(wrapped, M + 14, cur.y);
      cur.y += wrapped.length * 12;
    });
  }

  /* ── Disclaimer ── */
  doc.setFont('helvetica', 'italic');
  doc.setFontSize(7.6);
  const disclaimer = doc.splitTextToSize(
    'This sheet records the inputs and outputs of an engineering aid. Values must be ' +
    'checked against the governing edition of the NEC and the authority having ' +
    'jurisdiction before being used for construction or permitting. It is not a ' +
    'substitute for a design sealed by a licensed professional engineer.',
    right - M);
  cur.need(disclaimer.length * 10 + 20);
  cur.y += 10;
  doc.setDrawColor(220, 222, 232);
  doc.setLineWidth(0.6);
  doc.line(M, cur.y, right, cur.y);
  cur.y += 14;
  doc.setTextColor(MUTED[0], MUTED[1], MUTED[2]);
  doc.text(disclaimer, M, cur.y);

  drawFooter(doc);
}

function sectionHeading(cur, text) {
  const doc = cur.doc;
  const M = PAGE.margin;
  cur.need(40);
  cur.y += 6;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.setTextColor(ACCENT[0], ACCENT[1], ACCENT[2]);
  doc.text(pdfText(text).toUpperCase(), M, cur.y);
  cur.y += 6;
  doc.setDrawColor(ACCENT[0], ACCENT[1], ACCENT[2]);
  doc.setLineWidth(0.8);
  doc.line(M, cur.y, PAGE.w - M, cur.y);
  cur.y += 14;
}

/** Two-column table. With `withStatus`, a row's third item ('pass'/'fail')
    colours the value. Page breaks go through the shared cursor, so a long
    table continues correctly on the next page instead of running under the
    footer. */
function drawTable(cur, rows, withStatus) {
  const doc = cur.doc;
  const M = PAGE.margin;
  const right = PAGE.w - M;
  const valueX = M + 250;
  doc.setFontSize(9);

  rows.forEach(function (r, i) {
    doc.setFont('helvetica', 'normal');
    const labelLines = doc.splitTextToSize(pdfText(r[0]), valueX - M - 12);
    doc.setFont('helvetica', 'bold');
    const valueLines = doc.splitTextToSize(pdfText(r[1]), right - valueX);
    const rowH = Math.max(labelLines.length, valueLines.length) * 12 + 6;

    cur.need(rowH);

    if (i % 2 === 0) {
      doc.setFillColor(248, 249, 252);
      doc.rect(M, cur.y - 9, right - M, rowH, 'F');
    }

    doc.setFont('helvetica', 'normal');
    doc.setTextColor(MUTED[0], MUTED[1], MUTED[2]);
    doc.text(labelLines, M + 4, cur.y);

    doc.setFont('helvetica', 'bold');
    const status = withStatus ? r[2] : '';
    if (status === 'pass') doc.setTextColor(PASS_RGB[0], PASS_RGB[1], PASS_RGB[2]);
    else if (status === 'fail') doc.setTextColor(FAIL_RGB[0], FAIL_RGB[1], FAIL_RGB[2]);
    else doc.setTextColor(INK[0], INK[1], INK[2]);
    doc.text(valueLines, valueX, cur.y);

    cur.y += rowH;
  });

  cur.y += 4;
}

function drawFooter(doc) {
  const M = PAGE.margin;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(150, 153, 175);
  doc.text('beckify.com - Engineering Tools', M, PAGE.h - PAGE.footer);
  doc.text('Page ' + doc.internal.getNumberOfPages(), PAGE.w - M, PAGE.h - PAGE.footer, { align: 'right' });
}

/* ---------------------------------------------------------------------------
   Wire an Export button into every calculator that renders a .result element.
   --------------------------------------------------------------------------- */
function attachExportButtons() {
  document.querySelectorAll('section[id^="sec-"]').forEach(function (section) {
    const results = section.querySelectorAll('.result');
    if (!results.length) return;
    // One button per result element, placed right after it.
    results.forEach(function (res) {
      if (!res.id) return;
      if (section.querySelector('.report-export-btn[data-result="' + res.id + '"]')) return;
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn btn-secondary report-export-btn';
      btn.dataset.result = res.id;
      btn.dataset.section = section.id;
      btn.textContent = '⭳ Export PDF submittal';
      btn.onclick = function () { window.openReportModal(section.id, res.id); };
      res.parentNode.insertBefore(btn, res.nextSibling);
    });
  });
}

window.registerReport = registerReport;
window.attachExportButtons = attachExportButtons;

document.addEventListener('DOMContentLoaded', attachExportButtons);
