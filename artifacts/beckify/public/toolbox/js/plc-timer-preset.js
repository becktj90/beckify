/* ============================================================================
   PLC TIMER PRESET
   ============================================================================
   TON / TOF / RTO preset counts from a desired time and a timebase
   (1 ms, 10 ms, 100 ms, 1 s, custom ms, or scan-time based). Reverse:
   counts × timebase → seconds. Visible arithmetic. Not a timing-chart IDE.
   ============================================================================ */

(function (global) {
  'use strict';

  const TIMEBASES = {
    '1ms': { label: '1 ms', ms: 1 },
    '10ms': { label: '10 ms', ms: 10 },
    '100ms': { label: '100 ms', ms: 100 },
    '1s': { label: '1 s', ms: 1000 },
    custom: { label: 'Custom (ms)', ms: null },
    scan: { label: 'Scan-time based', ms: null },
  };

  function resolveTimebaseMs(kind, customMs, scanMs) {
    if (kind === 'custom') {
      const c = Number(customMs);
      if (!isFinite(c) || c <= 0) return { ok: false, error: 'Custom timebase must be a positive number of milliseconds.' };
      return { ok: true, ms: c };
    }
    if (kind === 'scan') {
      const s = Number(scanMs);
      if (!isFinite(s) || s <= 0) return { ok: false, error: 'Scan time must be a positive number of milliseconds.' };
      return { ok: true, ms: s };
    }
    const spec = TIMEBASES[kind] || TIMEBASES['10ms'];
    return { ok: true, ms: spec.ms };
  }

  function desiredToMs(value, unit) {
    const n = Number(value);
    if (!isFinite(n) || n < 0) return { ok: false, error: 'Desired time must be a non-negative number.' };
    if (unit === 'ms') return { ok: true, ms: n };
    return { ok: true, ms: n * 1000 };
  }

  function presetFromTime(desired, unit, kind, customMs, scanMs) {
    const want = desiredToMs(desired, unit);
    if (!want.ok) return want;
    const tb = resolveTimebaseMs(kind, customMs, scanMs);
    if (!tb.ok) return tb;
    const exact = want.ms / tb.ms;
    const counts = Math.round(exact);
    const actualMs = counts * tb.ms;
    return {
      ok: true,
      kind: kind,
      timebaseMs: tb.ms,
      desiredMs: want.ms,
      exact: exact,
      counts: counts,
      actualMs: actualMs,
      actualS: actualMs / 1000,
      residualMs: actualMs - want.ms,
      math: 'preset = round(' + want.ms + ' ms / ' + tb.ms + ' ms) = round(' + exact + ') = ' + counts +
        '\nactual = ' + counts + ' × ' + tb.ms + ' ms = ' + actualMs + ' ms (' + (actualMs / 1000) + ' s)',
    };
  }

  function timeFromPreset(counts, kind, customMs, scanMs) {
    const n = Math.floor(Number(counts));
    if (!isFinite(n) || n < 0) return { ok: false, error: 'Preset counts must be a non-negative integer.' };
    const tb = resolveTimebaseMs(kind, customMs, scanMs);
    if (!tb.ok) return tb;
    const actualMs = n * tb.ms;
    return {
      ok: true,
      kind: kind,
      timebaseMs: tb.ms,
      counts: n,
      actualMs: actualMs,
      actualS: actualMs / 1000,
      math: 'time = ' + n + ' × ' + tb.ms + ' ms = ' + actualMs + ' ms (' + (actualMs / 1000) + ' s)',
    };
  }

  function el(id) { return document.getElementById(id); }

  function currentKind() {
    return (el('tmr_base') && el('tmr_base').value) || '10ms';
  }

  function renderFrom(source) {
    const kind = currentKind();
    const custom = el('tmr_custom') && el('tmr_custom').value;
    const scan = el('tmr_scan') && el('tmr_scan').value;
    const unit = (el('tmr_unit') && el('tmr_unit').value) || 's';
    const wrapCustom = el('tmr_custom_wrap');
    const wrapScan = el('tmr_scan_wrap');
    if (wrapCustom) wrapCustom.hidden = kind !== 'custom';
    if (wrapScan) wrapScan.hidden = kind !== 'scan';
    let r;
    if (source === 'counts') {
      r = timeFromPreset(el('tmr_counts') && el('tmr_counts').value, kind, custom, scan);
      if (r.ok && el('tmr_desired')) {
        el('tmr_desired').value = unit === 'ms' ? String(r.actualMs) : String(r.actualS);
      }
    } else {
      r = presetFromTime(el('tmr_desired') && el('tmr_desired').value, unit, kind, custom, scan);
      if (r.ok && el('tmr_counts')) el('tmr_counts').value = String(r.counts);
    }
    const host = el('tmr_result');
    const math = el('tmr_math');
    const status = el('tmr_status');
    if (!r.ok) {
      if (status) status.textContent = r.error;
      return;
    }
    if (status) status.textContent = '';
    if (host) {
      host.innerHTML =
        '<div class="res-row"><span class="res-label">Preset counts</span><span class="res-val">' + r.counts + '</span></div>' +
        '<div class="res-row"><span class="res-label">Timebase</span><span class="res-val">' + r.timebaseMs + ' ms</span></div>' +
        '<div class="res-row"><span class="res-label">Actual time</span><span class="res-val">' + r.actualMs + ' ms (' + r.actualS + ' s)</span></div>' +
        (r.residualMs ? ('<div class="res-row"><span class="res-label">Round-off</span><span class="res-val">' + r.residualMs + ' ms</span></div>') : '');
      host.classList.add('show');
    }
    if (math) math.textContent = r.math;
  }

  function init() {
    if (!el('sec-plc-timer-preset')) return;
    ['tmr_desired', 'tmr_counts', 'tmr_base', 'tmr_unit', 'tmr_custom', 'tmr_scan'].forEach(function (id) {
      const node = el(id);
      if (!node) return;
      node.addEventListener('input', function () {
        renderFrom(id === 'tmr_counts' ? 'counts' : 'time');
      });
      node.addEventListener('change', function () {
        renderFrom(id === 'tmr_counts' ? 'counts' : 'time');
      });
    });
    renderFrom('time');
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-plc-timer-preset', 'plc-timer-preset', function () { renderFrom('time'); });
    }
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__plcTimerPresetTestApi = {
    TIMEBASES: TIMEBASES,
    presetFromTime: presetFromTime,
    timeFromPreset: timeFromPreset,
    resolveTimebaseMs: resolveTimebaseMs,
  };
})(typeof window !== 'undefined' ? window : globalThis);
