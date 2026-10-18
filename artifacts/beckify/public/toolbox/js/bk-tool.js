/* Declarative calculator shell for ported Beckify iOS tools.
   BeckifyTool.define({ id, root, title, lede, fields, compute, example, foot })
   compute(values) -> { headline, rows:[[label,value,hot]], steps, notes, warning, svg } or throws Error. */
(function (global) {
  'use strict';
  const registry = {};
  const RANGE = 1e15;
  const PREFIX = { '-12': 'p', '-9': 'n', '-6': 'µ', '-3': 'm', '0': '', '3': 'k', '6': 'M', '9': 'G', '12': 'T' };
  const MULT = { k: 1e3, K: 1e3, M: 1e6, G: 1e9, T: 1e12 }, DIV = { p: 1e12, n: 1e9, u: 1e6, 'µ': 1e6, 'μ': 1e6, m: 1e3 };

  /** Parse "4.7k", "100n", "2e-3", "1,000" -> number, or null when blank / unreadable. */
  function parse(text) {
    if (text == null) return null;
    const s = String(text).trim().replace(/,/g, '').replace(/\s+/g, '');
    if (!s) return null;
    const m = /^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)([pnuµμmkKMGT]?)$/.exec(s);
    if (!m) return null;
    const x = parseFloat(m[1]), v = !m[2] ? x : (DIV[m[2]] ? x / DIV[m[2]] : x * MULT[m[2]]);
    return isFinite(v) ? v : null;
  }
  /** Engineering format with SI prefix and unit: 1.38 nF, 481 Hz, -2.00 V. */
  function si(value, unit, digits) {
    unit = unit || '';
    if (value == null || !isFinite(value)) return '—';
    if (value === 0) return '0' + (unit ? ' ' + unit : '');
    const mag = Math.abs(value), dec = Math.min(12, Math.max(-12, Math.floor(Math.log10(mag) / 3) * 3));
    const sc = mag / Math.pow(10, dec), d = digits != null ? digits : (sc >= 100 ? 0 : sc >= 10 ? 1 : 2);
    const body = sc.toFixed(d);
    return (value < 0 && /[1-9]/.test(body) ? '-' : '') + body + ' ' + PREFIX[String(dec)] + unit;
  }
  const fixed = (v, d, unit) => {
    if (v == null || !isFinite(v)) return '—';
    let t = v.toFixed(d); if (/^-0(\.0*)?$/.test(t)) t = t.slice(1); // never print "-0.0"
    return t + (unit ? ' ' + unit : '');
  };
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  /** Read a numeric field. Throws with the field label for blank / bad input. */
  function need(v, id, label) {
    const x = parse(v[id]);
    if (x === null) throw new Error((label || id) + ' is missing or not a number.');
    if (Math.abs(x) > RANGE) throw new Error((label || id) + ' is out of range (limit ±1e15).');
    return x;
  }
  function positive(v, id, label) { const x = need(v, id, label); if (!(x > 0)) throw new Error((label || id) + ' must be above zero.'); return x; }
  function nonNeg(v, id, label) { const x = need(v, id, label); if (x < 0) throw new Error((label || id) + ' cannot be negative.'); return x; }
  const optional = (v, id) => {
    if (String(v[id] == null ? '' : v[id]).trim() === '') return null;
    const x = parse(v[id]);
    if (x === null) throw new Error('An optional value is not a number. Clear it or enter a number.');
    if (Math.abs(x) > RANGE) throw new Error('An optional value is out of range (limit ±1e15).');
    return x;
  };

  function define(def) {
    registry[def.id] = def;
    if (typeof document !== 'undefined') mount(def);
    return def;
  }
  function defaults(def) { const o = {}; def.fields.forEach((f) => { o[f.id] = f.def == null ? '' : String(f.def); }); return o; }
  function run(def, values) {
    // A choice that is blank or unknown falls back to the field default, so a stale saved value can never crash a tool.
    const v = Object.assign({}, values);
    def.fields.forEach((f) => { if (f.choices && !f.choices.some((c) => String(c[0]) === String(v[f.id]))) v[f.id] = f.def; });
    try {
      const r = def.compute(v);
      const shown = [r.headline].concat((r.rows || []).map((x) => x[0] + ' ' + x[1]), r.steps || []).join(' ');
      if (/NaN|Infinity|undefined|e\+\d/.test(shown)) return { ok: false, error: 'The result is out of range for this tool. Check the units and magnitudes of the inputs.' };
      return { ok: true, r };
    } catch (e) { return { ok: false, error: e && e.message ? e.message : String(e) }; }
  }

  function mount(def) {
    const root = document.getElementById(def.root);
    if (!root) return;
    const key = 'bkt:' + def.id;
    let values = defaults(def);
    try { const saved = JSON.parse(localStorage.getItem(key) || 'null'); if (saved) Object.keys(values).forEach((k) => { if (saved[k] != null) values[k] = saved[k]; }); } catch (e) { /* storage blocked */ }
    const visible = (f) => (typeof f.showIf === 'function' ? !!f.showIf(values) : true);

    function fieldHtml(f) {
      const id = def.id + '_' + f.id, lab = esc(f.label) + (f.unit ? ' <span class="eb-unit">(' + esc(f.unit) + ')</span>' : '') + (f.optional ? ' <span class="eb-unit">optional</span>' : '');
      const ctl = f.choices
        ? '<select id="' + id + '" data-f="' + f.id + '">' + f.choices.map((c) => '<option value="' + esc(c[0]) + '"' + (String(values[f.id]) === String(c[0]) ? ' selected' : '') + '>' + esc(c[1]) + '</option>').join('') + '</select>'
        : '<input id="' + id + '" data-f="' + f.id + '" type="text" inputmode="decimal" autocomplete="off" spellcheck="false" value="' + esc(values[f.id]) + '">';
      return '<div class="eb-field" data-wrap="' + f.id + '"><label for="' + id + '">' + lab + '</label>' + ctl + (f.help ? '<small class="eb-help">' + esc(f.help) + '</small>' : '') + '</div>';
    }
    function resultHtml(res) {
      if (!res.ok) return '<div class="bkt-alert bkt-bad" role="alert">' + esc(res.error) + '</div>';
      const r = res.r;
      let h = '<div class="eb-headline" aria-live="polite">' + esc(r.headline) + '</div>';
      if (r.warning) h += '<div class="bkt-alert bkt-warn" role="status">' + esc(r.warning) + '</div>';
      if (r.svg) h += '<div class="bkt-fig">' + r.svg + '</div>';
      h += '<div class="eb-qty">' + (r.rows || []).map((x) => '<div class="eb-q' + (x[2] ? ' eb-q-hot' : '') + '"><span>' + esc(x[0]) + '</span><b>' + esc(x[1]) + '</b></div>').join('') + '</div>';
      if (r.steps && r.steps.length) h += '<details class="eb-work"><summary>Show work</summary><ol>' + r.steps.map((s) => '<li>' + esc(s) + '</li>').join('') + '</ol></details>';
      if (r.notes && r.notes.length) h += '<ul class="eb-notes">' + r.notes.map((s) => '<li>' + esc(s) + '</li>').join('') + '</ul>';
      return h;
    }
    function copyText(res) {
      return res.ok ? def.title + '\n' + res.r.headline + '\n' + (res.r.rows || []).map((x) => x[0] + ' = ' + x[1]).join('\n') + '\nbeckify.com/toolbox/' : res.error;
    }
    function paint() {
      root.innerHTML = '<div class="eb bkt"><div class="eb-cols"><div class="eb-inputs"><div class="eb-fields">' + def.fields.filter(visible).map(fieldHtml).join('') + '</div>' +
        '<small class="eb-help">Values accept engineering suffixes: 4.7k, 100n, 2.2u, 1M.</small>' +
        '<div class="eb-actions"><button type="button" class="btn btn-sm" data-act="example">Example</button><button type="button" class="btn btn-sm" data-act="copy">Copy result</button></div></div>' +
        '<div class="eb-view"><div class="eb-result" id="' + def.id + '_out" aria-live="polite"></div></div></div>' +
        (def.foot ? '<p class="eb-foot">' + esc(def.foot) + '</p>' : '') + '</div>';
      out();
    }
    function out() { const el = document.getElementById(def.id + '_out'); if (el) el.innerHTML = resultHtml(run(def, values)); }
    function persist() { try { localStorage.setItem(key, JSON.stringify(values)); } catch (e) { /* ignore */ } }
    root.addEventListener('input', (ev) => {
      const f = ev.target && ev.target.dataset && ev.target.dataset.f;
      if (!f) return;
      values[f] = ev.target.value; persist();
      const fd = def.fields.find((x) => x.id === f);
      if (fd && fd.choices) paint(); else out();
    });
    root.addEventListener('change', (ev) => { const f = ev.target && ev.target.dataset && ev.target.dataset.f; if (f && root.contains(ev.target) && ev.target.tagName === 'SELECT') { values[f] = ev.target.value; persist(); paint(); } });
    root.addEventListener('click', (ev) => {
      const b = ev.target.closest('[data-act]'); if (!b) return;
      if (b.dataset.act === 'example') { values = Object.assign(defaults(def), def.example || {}); persist(); paint(); }
      if (b.dataset.act === 'copy') { const t = copyText(run(def, values)); if (navigator.clipboard) navigator.clipboard.writeText(t).then(() => { b.textContent = 'Copied'; setTimeout(() => { b.textContent = 'Copy result'; }, 1200); }).catch(() => {}); }
    });
    paint();
  }

  global.BeckifyTool = { define, registry, parse, si, fixed, esc, need, positive, nonNeg, optional, run, defaults };
})(typeof window !== 'undefined' ? window : globalThis);
