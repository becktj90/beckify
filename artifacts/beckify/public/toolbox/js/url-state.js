/* ============================================================================
   URL STATE — type-aware query-parameter binding for every calculator
   ============================================================================
   nuqs is a React hook library and this toolbox is plain DOM, so this is the
   equivalent for vanilla: register a section, and every input and select in it
   mirrors to the query string as the user types. Loading that URL restores the
   fields and runs the calculation, so a shared link lands on a computed result
   rather than an empty form.

   URL shape:  /toolbox/?t=wire-select&voltage=480&load=200#sec-wire-select

   The `t` key records which tool the parameters belong to, so one tool's state
   is never applied to another. Only the active tool's parameters are kept in
   the URL, which keeps links short and unambiguous.

   Values are coerced back to the field's own type on restore — numbers stay
   numeric, checkboxes become booleans, selects are validated against their
   real options and ignored if the value is not one of them.
   ============================================================================ */

const URL_TOOLS = {};
/** Prefixes stripped from element ids to keep parameter names readable. */
const URL_PREFIXES = ['xe_', 'ws_', 'cfa_', 'cf_', 't555_', 'pc_', 'xs_', 'sc_', 'nec_', 'bl_', 'tdr_'];
const URL_WRITE_DELAY = 250;

let urlWriteTimer = null;
let urlRestoring = false;

/** Element id → short parameter name. */
function urlParamName(id) {
  for (const p of URL_PREFIXES) {
    if (id.indexOf(p) === 0) return id.slice(p.length);
  }
  return id;
}

/** Fields worth serialising: has an id, is not a search box or report field. */
function urlFields(section) {
  return Array.prototype.slice
    .call(section.querySelectorAll('input[id], select[id]'))
    .filter(function (el) {
      if (!el.id) return false;
      if (el.type === 'button' || el.type === 'submit' || el.type === 'file') return false;
      if (/^rpt_|search/i.test(el.id)) return false;
      if (el.closest('.result')) return false;
      return true;
    });
}

function urlSerialise(el) {
  if (el.type === 'checkbox') return el.checked ? '1' : '0';
  return el.value;
}

/** Applies a string back to a field, respecting its type. Returns true if applied. */
function urlApply(el, raw) {
  if (raw == null) return false;
  if (el.type === 'checkbox') {
    el.checked = raw === '1' || raw === 'true';
    return true;
  }
  if (el.tagName === 'SELECT') {
    // Ignore anything that is not a real option rather than silently blanking
    // the select, which would make a hand-edited URL fail confusingly.
    const valid = Array.prototype.some.call(el.options, function (o) { return o.value === raw; });
    if (!valid) return false;
    el.value = raw;
    return true;
  }
  if (el.type === 'number') {
    if (raw === '' || !isFinite(Number(raw))) return false;
    el.value = raw;
    return true;
  }
  el.value = raw;
  return true;
}

/**
 * Registers a calculator for URL syncing.
 *   sectionId  section element id
 *   toolKey    short name used as ?t=
 *   run        function that recomputes the tool (optional)
 */
function registerUrlState(sectionId, toolKey, run) {
  const section = document.getElementById(sectionId);
  if (!section) return;
  URL_TOOLS[sectionId] = { key: toolKey, run: run, section: section };

  urlFields(section).forEach(function (el) {
    const handler = function () { scheduleUrlWrite(sectionId); };
    el.addEventListener('input', handler);
    el.addEventListener('change', handler);
  });
}

function scheduleUrlWrite(sectionId) {
  if (urlRestoring) return;
  clearTimeout(urlWriteTimer);
  urlWriteTimer = setTimeout(function () { writeUrlState(sectionId); }, URL_WRITE_DELAY);
}

function writeUrlState(sectionId) {
  const tool = URL_TOOLS[sectionId];
  if (!tool) return;
  // Only mirror the tool the user is actually looking at.
  const active = document.querySelector('.section.active');
  if (!active || active.id !== sectionId) return;

  try {
    const params = new URLSearchParams();
    params.set('t', tool.key);
    urlFields(tool.section).forEach(function (el) {
      const v = urlSerialise(el);
      if (v === '' || v == null) return;
      params.set(urlParamName(el.id), v);
    });
    history.replaceState(null, '', location.pathname + '?' + params.toString() + '#' + sectionId);
  } catch (_) { /* URL syncing is a convenience, never a hard failure */ }
}

/** Clears query params when moving to a tool that has no saved state. */
function clearUrlState(sectionId) {
  try {
    history.replaceState(null, '', location.pathname + (sectionId ? '#' + sectionId : ''));
  } catch (_) {}
}

/**
 * Restores fields from the query string and runs the tool.
 * Returns true when state was applied.
 */
function restoreUrlState() {
  let params;
  try { params = new URLSearchParams(location.search); } catch (_) { return false; }
  const toolKey = params.get('t');
  if (!toolKey) return false;

  const entry = Object.keys(URL_TOOLS)
    .map(function (id) { return { id: id, tool: URL_TOOLS[id] }; })
    .find(function (e) { return e.tool.key === toolKey; });
  if (!entry) return false;

  urlRestoring = true;
  let applied = 0;
  urlFields(entry.tool.section).forEach(function (el) {
    if (urlApply(el, params.get(urlParamName(el.id)))) applied++;
  });
  urlRestoring = false;

  if (!applied) return false;

  // Some tools have dependent controls (a custom-kVA box, mode toggles) that
  // only reveal themselves on change; fire one so they settle before running.
  urlFields(entry.tool.section).forEach(function (el) {
    if (el.tagName === 'SELECT') el.dispatchEvent(new Event('change', { bubbles: true }));
  });

  if (typeof entry.tool.run === 'function') {
    try { entry.tool.run(); } catch (_) {}
  }
  return true;
}

window.registerUrlState = registerUrlState;
window.restoreUrlState = restoreUrlState;
window.clearUrlState = clearUrlState;
window.writeUrlState = writeUrlState;

/* Register every calculator that has a run function, then restore. Runs after
   the other tool scripts so their globals exist. */
document.addEventListener('DOMContentLoaded', function () {
  const tools = [
    ['sec-xfmr-engine', 'xfmr-engine', 'calcXfmrEngine'],
    ['sec-wire-select', 'wire-select', 'calcWireSelection'],
    ['sec-conduit-adv', 'conduit-fill', 'calcConduitFillAdvanced'],
    ['sec-555', '555', 'calc555Astable'],
    ['sec-power-convert', 'power-convert', 'calcPowerConvert'],
    ['sec-xfmr-size', 'xfmr-size', 'calcXfmrSizing'],
    ['sec-vdrop', 'vdrop', null],
    ['sec-conductor-length', 'conductor-length', 'calcConductorLengthByResistance'],
    ['sec-ebike-tools', 'ebike-tools', 'calcEbSprocket'],
    ['sec-conduit', 'conduit', 'calcConduitFill'],
    ['sec-sc', 'short-circuit', 'calcSC'],
    ['sec-nec', 'nec-circuit', 'calcNEC'],
    ['sec-tdr', 'tdr', 'calcTdrAnalyzer'],
  ];
  tools.forEach(function (t) {
    registerUrlState(t[0], t[1], t[2] ? function () {
      if (typeof window[t[2]] === 'function') window[t[2]]();
    } : null);
  });

  // Give the tool scripts' own DOMContentLoaded handlers a tick to seed
  // defaults (the conduit-fill rows, for instance) before overwriting them.
  setTimeout(function () { restoreUrlState(); }, 80);
});
