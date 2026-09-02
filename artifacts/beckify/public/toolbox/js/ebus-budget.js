/* ============================================================================
   E-BUS / RACK CURRENT BUDGET
   ============================================================================
   Running remaining current down a rack. Coupler/adapter supply is a positive
   mA contribution; terminals draw (negative). A power-refresh module resets
   remaining to its own supply. Flag when remaining is negative or below a
   user-set reserve.

   Beckhoff E-bus figures are typical published consumption / 2000 mA supply.
   Other brands: enter mA from the datasheet — this tool does not invent SKUs.

   Design aid only. Not a thermal study or a PE stamp.
   ============================================================================ */

(function (global) {
  'use strict';

  const SEED_MODULES = [
    { pn: 'EK1100', name: 'EtherCAT Coupler (supply)', ma: 2000, widthMm: '44', signalType: 'Coupler', reset: false },
    { pn: 'EK1110', name: 'EtherCAT Extension', ma: -220, widthMm: '44', signalType: 'Coupler', reset: false },
    { pn: 'EL9410', name: 'E-bus power refresh', ma: 2000, widthMm: '12', signalType: 'Power', reset: true },
    { pn: 'EL1819', name: '16ch DI 24VDC', ma: -100, widthMm: '12', signalType: 'DI', reset: false },
    { pn: 'EL2828', name: '8ch DO 24VDC', ma: -140, widthMm: '12', signalType: 'DO', reset: false },
    { pn: 'EL3048', name: '8ch AI 0–20mA', ma: -130, widthMm: '12', signalType: 'AI', reset: false },
    { pn: 'EL4024', name: '4ch AO 4–20mA', ma: -180, widthMm: '12', signalType: 'AO', reset: false },
    { pn: 'EL3214', name: '4ch RTD', ma: -170, widthMm: '12', signalType: 'RTD', reset: false },
    { pn: 'EL3318', name: '8ch thermocouple', ma: -200, widthMm: '12', signalType: 'TC', reset: false },
    { pn: 'EL6224', name: '4ch IO-Link', ma: -120, widthMm: '24', signalType: 'IO-Link', reset: false },
    { pn: 'Custom', name: 'Enter from datasheet', ma: 0, widthMm: '', signalType: 'DI', reset: false },
  ];

  function computeBudget(modules, opts) {
    const reserve = opts && isFinite(Number(opts.reserve)) ? Number(opts.reserve) : 200;
    const list = Array.isArray(modules) ? modules : [];
    const rows = [];
    let remaining = 0;
    let widthMm = 0;
    let flagged = false;
    for (let i = 0; i < list.length; i++) {
      const m = list[i] || {};
      const contrib = Number(m.ma);
      const ma = isFinite(contrib) ? contrib : 0;
      const reset = !!m.reset || String(m.signalType || '').toUpperCase() === 'POWER';
      if (reset) remaining = ma;
      else remaining += ma;
      const w = Number(m.widthMm);
      if (isFinite(w)) widthMm += w;
      const negative = remaining < 0;
      const low = remaining < reserve;
      if (negative || low) flagged = true;
      rows.push({
        slot: i + 1,
        pn: String(m.pn || ''),
        name: String(m.name || ''),
        signalType: String(m.signalType || ''),
        widthMm: m.widthMm === undefined || m.widthMm === null ? '' : String(m.widthMm),
        contributionMa: ma,
        remainingMa: remaining,
        reset: reset,
        negative: negative,
        lowReserve: low && !negative,
        flag: negative ? 'NEGATIVE' : (low ? 'LOW RESERVE' : ''),
      });
    }
    return {
      rows: rows,
      remaining: remaining,
      widthMm: widthMm,
      reserve: reserve,
      flagged: flagged,
      ok: !flagged,
    };
  }

  let rows = [
    Object.assign({}, SEED_MODULES[0]),
    Object.assign({}, SEED_MODULES[3]),
  ];

  function el(id) { return document.getElementById(id); }

  function escapeHtml(s) {
    return String(s === undefined || s === null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function familyClass(signalType) {
    const u = String(signalType || '').toUpperCase();
    if (u.indexOf('DI') === 0) return 'iol-sig-di';
    if (u.indexOf('DO') === 0) return 'iol-sig-do';
    if (u.indexOf('AI') === 0) return 'iol-sig-ai';
    if (u.indexOf('AO') === 0) return 'iol-sig-ao';
    if (u.indexOf('RTD') === 0) return 'iol-sig-rtd';
    if (u.indexOf('TC') === 0) return 'iol-sig-tc';
    if (u.indexOf('IO') === 0) return 'iol-sig-iolink';
    if (u.indexOf('POWER') === 0) return 'iol-sig-power';
    if (u.indexOf('COUPLER') === 0 || u.indexOf('ADAPTER') === 0) return 'iol-sig-coupler';
    return 'iol-sig-other';
  }

  function seedOptions() {
    return SEED_MODULES.map(function (m, i) {
      return '<option value="' + i + '">' + escapeHtml(m.pn + ' — ' + m.name + ' (' + m.ma + ' mA)') + '</option>';
    }).join('');
  }

  function render() {
    const host = el('ebus_rows');
    const sum = el('ebus_summary');
    if (!host) return;
    const reserve = Number((el('ebus_reserve') && el('ebus_reserve').value) || 200);
    const budget = computeBudget(rows, { reserve: reserve });
    let html = '<div class="ref-table-wrap iol-table-wrap"><table class="ref-table iol-table" aria-label="E-bus current budget">';
    html += '<thead><tr><th>Slot</th><th>Part</th><th>Name</th><th>Type</th><th>Width mm</th><th>mA (signed)</th><th>Reset</th><th>Remaining mA</th><th>Flag</th><th></th></tr></thead><tbody>';
    for (let i = 0; i < budget.rows.length; i++) {
      const r = budget.rows[i];
      const src = rows[i];
      html += '<tr class="' + familyClass(src.signalType) + (r.negative ? ' ebus-neg' : (r.lowReserve ? ' ebus-low' : '')) + '">';
      html += '<td>' + r.slot + '</td>';
      html += '<td><input type="text" data-ebus="pn" data-i="' + i + '" value="' + escapeHtml(src.pn) + '" aria-label="Part number"></td>';
      html += '<td><input type="text" data-ebus="name" data-i="' + i + '" value="' + escapeHtml(src.name) + '" aria-label="Name"></td>';
      html += '<td><input type="text" data-ebus="signalType" data-i="' + i + '" value="' + escapeHtml(src.signalType) + '" aria-label="Type"></td>';
      html += '<td><input type="text" data-ebus="widthMm" data-i="' + i + '" value="' + escapeHtml(src.widthMm) + '" aria-label="Width mm"></td>';
      html += '<td><input type="number" step="1" data-ebus="ma" data-i="' + i + '" value="' + src.ma + '" aria-label="Contribution mA"></td>';
      html += '<td><input type="checkbox" data-ebus="reset" data-i="' + i + '"' + (src.reset ? ' checked' : '') + ' aria-label="Reset remaining"></td>';
      html += '<td>' + r.remainingMa + '</td>';
      html += '<td>' + escapeHtml(r.flag) + '</td>';
      html += '<td><button type="button" class="btn-remove" data-ebus-del="' + i + '" aria-label="Remove slot">×</button></td>';
      html += '</tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
    if (sum) {
      sum.innerHTML =
        '<div class="res-row"><span class="res-label">Remaining</span><span class="res-val">' + budget.remaining + ' mA</span></div>' +
        '<div class="res-row"><span class="res-label">Reserve</span><span class="res-val">' + budget.reserve + ' mA</span></div>' +
        '<div class="res-row"><span class="res-label">Width (sum of entered mm)</span><span class="res-val">' + budget.widthMm + '</span></div>' +
        '<div class="res-row"><span class="res-label">Status</span><span class="res-val">' + (budget.ok ? 'OK' : 'Check flags') + '</span></div>';
      sum.classList.add('show');
    }
  }

  function init() {
    if (!el('sec-ebus-budget')) return;
    const addSel = el('ebus_add_pn');
    if (addSel) addSel.innerHTML = seedOptions();
    render();
    const section = el('sec-ebus-budget');
    section.addEventListener('click', function (ev) {
      const t = ev.target;
      if (!t || !t.getAttribute) return;
      if (t.getAttribute('data-ebus-del') !== null) {
        rows.splice(Number(t.getAttribute('data-ebus-del')), 1);
        render();
      }
    });
    section.addEventListener('input', function (ev) {
      const t = ev.target;
      if (!t || !t.getAttribute) return;
      if (t.id === 'ebus_reserve') { render(); return; }
      if (t.getAttribute('data-ebus') !== null) {
        const i = Number(t.getAttribute('data-i'));
        const f = t.getAttribute('data-ebus');
        if (!rows[i]) return;
        if (f === 'reset') rows[i].reset = !!t.checked;
        else if (f === 'ma') rows[i].ma = Number(t.value) || 0;
        else rows[i][f] = t.value;
        if (f === 'ma' || f === 'reset' || f === 'widthMm' || f === 'signalType') render();
      }
    });
    section.addEventListener('change', function (ev) {
      const t = ev.target;
      if (t && t.getAttribute && t.getAttribute('data-ebus') === 'reset') {
        const i = Number(t.getAttribute('data-i'));
        if (rows[i]) rows[i].reset = !!t.checked;
        render();
      }
    });
    const addBtn = el('ebus_add');
    if (addBtn) addBtn.addEventListener('click', function () {
      const sel = el('ebus_add_pn');
      const idx = sel ? Number(sel.value) : 0;
      const src = SEED_MODULES[idx] || SEED_MODULES[SEED_MODULES.length - 1];
      rows.push(Object.assign({}, src));
      render();
    });
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-ebus-budget', 'ebus-budget', null);
    }
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__ebusBudgetTestApi = {
    SEED_MODULES: SEED_MODULES,
    computeBudget: computeBudget,
  };
})(typeof window !== 'undefined' ? window : globalThis);
