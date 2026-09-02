/* ============================================================================
   MODBUS ADDRESS CONVERTER
   ============================================================================
   Function codes 01/02/03/04, 0-based PDU offset vs 1-based data-model
   number, 5-digit 00001/10001/30001/40001 and 6-digit 400001 long addressing,
   and a PLC-tag style note (40001 = holding offset 0).

   Wire / PDU: function code + 16-bit big-endian starting address (0-based).
   Not a slave simulator.
   ============================================================================ */

(function (global) {
  'use strict';

  const SPACES = {
    coil: { fc: 1, prefix5: 0, prefix6: 0, label: 'Coils (FC 01)', tag: '0x' },
    discrete: { fc: 2, prefix5: 1, prefix6: 1, label: 'Discrete inputs (FC 02)', tag: '1x' },
    input: { fc: 4, prefix5: 3, prefix6: 3, label: 'Input registers (FC 04)', tag: '3x' },
    holding: { fc: 3, prefix5: 4, prefix6: 4, label: 'Holding registers (FC 03)', tag: '4x' },
  };

  function spaceByFc(fc) {
    const n = Number(fc);
    if (n === 1) return 'coil';
    if (n === 2) return 'discrete';
    if (n === 4) return 'input';
    return 'holding';
  }

  function inferFromAddress(n) {
    const v = Math.floor(Number(n));
    if (!isFinite(v) || v < 0) return { ok: false, error: 'Address must be a non-negative integer.' };
    if (v >= 1 && v <= 9999) {
      return { ok: true, space: 'coil', oneBased: v, digits: 5 };
    }
    if (v >= 10001 && v <= 19999) {
      return { ok: true, space: 'discrete', oneBased: v - 10000, digits: 5 };
    }
    if (v >= 30001 && v <= 39999) {
      return { ok: true, space: 'input', oneBased: v - 30000, digits: 5 };
    }
    if (v >= 40001 && v <= 49999) {
      return { ok: true, space: 'holding', oneBased: v - 40000, digits: 5 };
    }
    if (v >= 1 && v <= 65536 && v >= 100000) {
      /* fall through to 6-digit */
    }
    if (v >= 100001 && v <= 165536) {
      return { ok: true, space: 'discrete', oneBased: v - 100000, digits: 6 };
    }
    if (v >= 300001 && v <= 365536) {
      return { ok: true, space: 'input', oneBased: v - 300000, digits: 6 };
    }
    if (v >= 400001 && v <= 465536) {
      return { ok: true, space: 'holding', oneBased: v - 400000, digits: 6 };
    }
    if (v >= 1 && v <= 65536) {
      /* 6-digit coil 000001–065536 — 1..65536 without a 1/3/4 prefix is coil
         when the user said 6-digit, but 1–9999 already mapped to 5-digit coil.
         000001–065536 as integer 1–65536 is ambiguous with 5-digit coil.
         Treat 6-digit only when >= 100000. */
    }
    if (v >= 0 && v <= 65535) {
      return { ok: false, error: 'Ambiguous integer. Use a 5-digit (40001) or 6-digit (400001) address, or enter a space + offset.' };
    }
    return { ok: false, error: 'Address is outside the usual 5-digit / 6-digit Modicon ranges.' };
  }

  function convert(opts) {
    const o = opts || {};
    let space = o.space || 'holding';
    if (!SPACES[space]) space = 'holding';
    let offset0;
    if (o.address !== undefined && o.address !== null && String(o.address).trim() !== '') {
      const inferred = inferFromAddress(o.address);
      if (!inferred.ok) return inferred;
      space = inferred.space;
      offset0 = inferred.oneBased - 1;
    } else if (o.oneBased !== undefined && o.oneBased !== null && String(o.oneBased).trim() !== '') {
      const one = Math.floor(Number(o.oneBased));
      if (!isFinite(one) || one < 1 || one > 65536) {
        return { ok: false, error: '1-based number must be 1…65536.' };
      }
      offset0 = one - 1;
    } else {
      const off = Math.floor(Number(o.offset0));
      if (!isFinite(off) || off < 0 || off > 65535) {
        return { ok: false, error: '0-based offset must be 0…65535.' };
      }
      offset0 = off;
    }
    const spec = SPACES[space];
    const oneBased = offset0 + 1;
    if (oneBased < 1 || oneBased > 65536) {
      return { ok: false, error: 'Offset is outside 0…65535.' };
    }
    const addr5 = spec.prefix5 * 10000 + oneBased;
    const addr6 = spec.prefix6 * 100000 + oneBased;
    const hi = (offset0 >> 8) & 0xFF;
    const lo = offset0 & 0xFF;
    const fcByte = spec.fc;
    const pdu = [
      fcByte.toString(16).padStart(2, '0'),
      hi.toString(16).padStart(2, '0'),
      lo.toString(16).padStart(2, '0'),
    ].join(' ').toUpperCase();
    return {
      ok: true,
      space: space,
      label: spec.label,
      fc: spec.fc,
      offset0: offset0,
      oneBased: oneBased,
      addr5: addr5,
      addr6: addr6,
      addr5Padded: String(addr5).padStart(5, '0'),
      addr6Padded: String(addr6).padStart(6, '0'),
      tagNote: spec.prefix5 + '0001-style ' + spec.addr5Padded + ' is 0-based offset ' + offset0,
      wire: 'PDU start: FC ' + spec.fc + ' + address ' + pdu + ' (hex, 0-based big-endian). Quantity is not included.',
      pduAddressHex: pdu,
    };
  }

  /* Fix tagNote after addr5 is known — the object above referenced itself.
     Recompute tagNote cleanly. */
  function convertFixed(opts) {
    const r = convert(opts);
    if (!r.ok) return r;
    r.tagNote = r.addr5Padded + ' = ' + r.label + ', 1-based ' + r.oneBased + ', 0-based offset ' + r.offset0 +
      (r.space === 'holding' && r.offset0 === 0 ? ' (40001 = holding 0)' : '');
    return r;
  }

  function el(id) { return document.getElementById(id); }

  function renderFrom(source) {
    const space = (el('mb_space') && el('mb_space').value) || 'holding';
    let opts = { space: space };
    if (source === 'addr5') opts.address = el('mb_addr5') && el('mb_addr5').value;
    else if (source === 'addr6') opts.address = el('mb_addr6') && el('mb_addr6').value;
    else if (source === 'one') opts.oneBased = el('mb_one') && el('mb_one').value;
    else opts.offset0 = el('mb_off') && el('mb_off').value;
    const r = convertFixed(opts);
    const status = el('mb_status');
    const out = el('mb_result');
    if (!r.ok) {
      if (status) status.textContent = r.error;
      return;
    }
    if (status) status.textContent = '';
    const applying = true;
    void applying;
    if (el('mb_space')) el('mb_space').value = r.space;
    if (el('mb_off')) el('mb_off').value = String(r.offset0);
    if (el('mb_one')) el('mb_one').value = String(r.oneBased);
    if (el('mb_addr5')) el('mb_addr5').value = r.addr5Padded;
    if (el('mb_addr6')) el('mb_addr6').value = r.addr6Padded;
    if (out) {
      out.innerHTML =
        '<div class="res-row"><span class="res-label">Space</span><span class="res-val">' + r.label + '</span></div>' +
        '<div class="res-row"><span class="res-label">Function code</span><span class="res-val">' + r.fc + '</span></div>' +
        '<div class="res-row"><span class="res-label">0-based offset</span><span class="res-val">' + r.offset0 + '</span></div>' +
        '<div class="res-row"><span class="res-label">1-based number</span><span class="res-val">' + r.oneBased + '</span></div>' +
        '<div class="res-row"><span class="res-label">5-digit</span><span class="res-val">' + r.addr5Padded + '</span></div>' +
        '<div class="res-row"><span class="res-label">6-digit (long)</span><span class="res-val">' + r.addr6Padded + '</span></div>' +
        '<div class="res-row"><span class="res-label">PLC-tag note</span><span class="res-val">' + r.tagNote + '</span></div>' +
        '<div class="res-row"><span class="res-label">Wire / PDU</span><span class="res-val">' + r.wire + '</span></div>';
      out.classList.add('show');
    }
  }

  function init() {
    if (!el('sec-modbus-address')) return;
    ['mb_space', 'mb_off', 'mb_one', 'mb_addr5', 'mb_addr6'].forEach(function (id) {
      const node = el(id);
      if (!node) return;
      node.addEventListener('input', function () {
        if (id === 'mb_space' || id === 'mb_off') renderFrom('off');
        else if (id === 'mb_one') renderFrom('one');
        else if (id === 'mb_addr5') renderFrom('addr5');
        else renderFrom('addr6');
      });
      node.addEventListener('change', function () {
        if (id === 'mb_space') renderFrom('off');
      });
    });
    renderFrom('off');
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-modbus-address', 'modbus-address', function () { renderFrom('off'); });
    }
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__modbusAddressTestApi = {
    SPACES: SPACES,
    convert: convertFixed,
    spaceByFc: spaceByFc,
    inferFromAddress: inferFromAddress,
  };
})(typeof window !== 'undefined' ? window : globalThis);
