/* ============================================================================
   NUMBER-BASE CONVERTER  (hex / dec / oct / bin)
   ============================================================================
   Convert an integer among hexadecimal, decimal, octal, and binary. Typing in
   any base updates the others. A bit-width of 8 / 16 / 32 / 64 wraps the value
   to that unsigned range; optional two's-complement signed decimal shows the
   same bit pattern interpreted with the high bit as sign.

   Visuals:
     - place-value chips  n = Σ d_i · b^i  for the field being edited
     - bit field grouped by nibble (4) and byte (8), with the bits that just
       changed highlighted

   Shareable URL via the toolbox url-state binder. Live recompute on input.

   Arithmetic uses BigInt so 64-bit values are exact (Number cannot hold
   integers past 2^53 − 1).
   ============================================================================ */

(function (global) {
  'use strict';

  const WIDTHS = [8, 16, 32, 64];
  const BASES = { hex: 16, dec: 10, oct: 8, bin: 2 };
  const DIGITS = '0123456789ABCDEF';

  let lastUnsigned = 0n;
  let lastChangedMask = 0n;
  let applying = false;
  let sourceBase = 'dec';

  function maskFor(width) {
    const w = BigInt(width);
    return (1n << w) - 1n;
  }

  function wrapWidth(value, width) {
    const m = maskFor(width);
    // Two's-complement wrap of a possibly-negative BigInt into 0 .. 2^w-1.
    return ((value % (m + 1n)) + (m + 1n)) % (m + 1n);
  }

  function toSigned(unsigned, width) {
    const u = wrapWidth(unsigned, width);
    const signBit = 1n << (BigInt(width) - 1n);
    if (u & signBit) return u - (1n << BigInt(width));
    return u;
  }

  function fromSigned(signed, width) {
    return wrapWidth(signed, width);
  }

  function stripPrefix(str, base) {
    let s = String(str || '').trim().replace(/[\s_]/g, '');
    if (base === 16) s = s.replace(/^0x/i, '');
    if (base === 8) s = s.replace(/^0o/i, '');
    if (base === 2) s = s.replace(/^0b/i, '');
    return s;
  }

  function parseBase(str, base, width, signedDec) {
    const raw = stripPrefix(str, base);
    if (raw === '' || raw === '+' || raw === '-') {
      throw new Error('Enter a value.');
    }
    if (base === 10 && signedDec) {
      if (!/^[+-]?[0-9]+$/.test(raw)) throw new Error('Decimal must be an integer.');
      const n = BigInt(raw);
      const min = -(1n << (BigInt(width) - 1n));
      const max = (1n << (BigInt(width) - 1n)) - 1n;
      if (n < min || n > max) {
        throw new Error('Signed ' + width + '-bit decimal is outside ' + min.toString() + ' … ' + max.toString() + '.');
      }
      return fromSigned(n, width);
    }
    const re = base === 16 ? /^[0-9A-Fa-f]+$/
      : base === 10 ? /^[0-9]+$/
      : base === 8 ? /^[0-7]+$/
      : /^[01]+$/;
    const body = base === 10 && raw.charAt(0) === '+' ? raw.slice(1) : raw;
    if (!re.test(body)) {
      throw new Error('Not a valid ' + ({ 16: 'hexadecimal', 10: 'decimal', 8: 'octal', 2: 'binary' }[base]) + ' integer.');
    }
    const n = BigInt(base === 16 ? '0x' + body : base === 8 ? '0o' + body : base === 2 ? '0b' + body : body);
    return wrapWidth(n, width);
  }

  function formatBase(unsigned, base, width, signedDec) {
    const u = wrapWidth(unsigned, width);
    if (base === 10) {
      if (signedDec) return toSigned(u, width).toString(10);
      return u.toString(10);
    }
    const bits = Number(width);
    let digits;
    if (base === 16) digits = Math.ceil(bits / 4);
    else if (base === 8) digits = Math.ceil(bits / 3);
    else digits = bits;
    let s = u.toString(base).toUpperCase();
    if (s.length < digits) s = new Array(digits - s.length + 1).join('0') + s;
    return s;
  }

  function groupHex(str) {
    const s = str.replace(/\s/g, '').toUpperCase();
    const parts = [];
    for (let i = s.length; i > 0; i -= 4) parts.unshift(s.slice(Math.max(0, i - 4), i));
    return parts.join(' ');
  }

  function groupBin(str, group) {
    const s = str.replace(/\s/g, '');
    const g = group || 4;
    const parts = [];
    for (let i = s.length; i > 0; i -= g) parts.unshift(s.slice(Math.max(0, i - g), i));
    return parts.join(' ');
  }

  function placeValues(unsigned, base, width) {
    let digits = formatBase(unsigned, base, width, false);
    digits = digits.replace(/^0+(?=\w)/, '') || '0';
    const out = [];
    const chars = digits.split('');
    for (let i = 0; i < chars.length; i++) {
      const power = chars.length - 1 - i;
      const d = parseInt(chars[i], base);
      out.push({
        digit: chars[i],
        value: d,
        power: power,
        weight: BigInt(base) ** BigInt(power),
        contrib: BigInt(d) * (BigInt(base) ** BigInt(power)),
      });
    }
    return out;
  }

  function identityString(places, base) {
    const live = places.filter((p) => p.value !== 0);
    if (!live.length) return 'n = 0';
    const parts = live.map((p) => p.value + ' × ' + base + '^' + p.power);
    return 'n = ' + parts.join(' + ');
  }

  function roundTrip(str, fromBase, width, signedDec) {
    const u = parseBase(str, fromBase, width, signedDec);
    return {
      unsigned: u,
      hex: formatBase(u, 16, width, false),
      dec: formatBase(u, 10, width, false),
      signed: formatBase(u, 10, width, true),
      oct: formatBase(u, 8, width, false),
      bin: formatBase(u, 2, width, false),
    };
  }

  /* -------------------------------------------------------------------------
     DOM
     ------------------------------------------------------------------------- */

  function byId(id) { return document.getElementById(id); }

  function currentWidth() {
    const v = parseInt((byId('nbc_width') || {}).value, 10);
    return WIDTHS.indexOf(v) >= 0 ? v : 8;
  }

  function currentSigned() {
    return !!(byId('nbc_signed') && byId('nbc_signed').checked);
  }

  function setField(id, value) {
    const el = byId(id);
    if (el) el.value = value;
  }

  function renderVisuals(unsigned, width, base) {
    const chipHost = byId('nbc_chips');
    const bitHost = byId('nbc_bits');
    const idEl = byId('nbc_identity');
    if (!chipHost || !bitHost) return;

    const places = placeValues(unsigned, base, width);
    chipHost.innerHTML = '';
    chipHost.setAttribute('aria-label', 'Place-value chips for base ' + base);
    places.forEach((p) => {
      const chip = document.createElement('div');
      chip.className = 'nbc-chip' + (p.value ? '' : ' nbc-chip-zero');
      chip.innerHTML =
        '<span class="nbc-chip-digit">' + p.digit + '</span>' +
        '<span class="nbc-chip-place">× ' + base + '<sup>' + p.power + '</sup></span>' +
        '<span class="nbc-chip-val">' + p.contrib.toString(10) + '</span>';
      chipHost.appendChild(chip);
    });

    if (idEl) idEl.textContent = identityString(places, base) +
      '   (grouped hex ' + groupHex(formatBase(unsigned, 16, width, false)) +
      '  ·  grouped bin ' + groupBin(formatBase(unsigned, 2, width, false), 4) + ')';

    const bits = Number(width);
    const u = wrapWidth(unsigned, width);
    bitHost.innerHTML = '';
    bitHost.setAttribute('aria-label', bits + '-bit field, grouped in nibbles');
    const row = document.createElement('div');
    row.className = 'nbc-bit-row';
    for (let i = bits - 1; i >= 0; i--) {
      if ((i + 1) % 8 === 0 && i !== bits - 1) {
        const gap = document.createElement('span');
        gap.className = 'nbc-byte-gap';
        gap.setAttribute('aria-hidden', 'true');
        row.appendChild(gap);
      }
      const bit = (u >> BigInt(i)) & 1n;
      const changed = ((lastChangedMask >> BigInt(i)) & 1n) === 1n;
      const cell = document.createElement('button');
      cell.type = 'button';
      cell.className = 'nbc-bit' + (bit ? ' nbc-bit-on' : '') + (changed ? ' nbc-bit-changed' : '');
      cell.dataset.bit = String(i);
      cell.setAttribute('aria-pressed', bit ? 'true' : 'false');
      cell.setAttribute('aria-label', 'Bit ' + i + ' (2^' + i + '), currently ' + bit);
      cell.innerHTML = '<span class="nbc-bit-idx">' + i + '</span><span class="nbc-bit-val">' + (bit ? '1' : '0') + '</span>';
      cell.addEventListener('click', onBitToggle);
      row.appendChild(cell);
    }
    bitHost.appendChild(row);
  }

  function onBitToggle(ev) {
    const btn = ev.currentTarget;
    const i = parseInt(btn.dataset.bit, 10);
    if (!isFinite(i)) return;
    const width = currentWidth();
    const next = wrapWidth(lastUnsigned ^ (1n << BigInt(i)), width);
    applyUnsigned(next, width, 'bin');
  }

  function applyUnsigned(unsigned, width, fromBase) {
    applying = true;
    lastChangedMask = lastUnsigned ^ unsigned;
    lastUnsigned = unsigned;
    sourceBase = fromBase || sourceBase;
    const signed = currentSigned();
    setField('nbc_hex', groupHex(formatBase(unsigned, 16, width, false)));
    setField('nbc_oct', formatBase(unsigned, 8, width, false));
    setField('nbc_bin', groupBin(formatBase(unsigned, 2, width, false), 4));
    setField('nbc_dec', formatBase(unsigned, 10, width, signed));
    const range = byId('nbc_range');
    if (range) {
      if (signed) {
        const min = -(1n << (BigInt(width) - 1n));
        const max = (1n << (BigInt(width) - 1n)) - 1n;
        range.textContent = width + '-bit two’s-complement decimal range: ' + min.toString() + ' … ' + max.toString();
      } else {
        range.textContent = width + '-bit unsigned range: 0 … ' + maskFor(width).toString();
      }
    }
    const status = byId('nbc_status');
    if (status) {
      status.className = 'result show';
      const rows = [
        ['Width', width + ' bits'],
        ['Unsigned decimal', formatBase(unsigned, 10, width, false)],
        ['Signed decimal (two’s complement)', formatBase(unsigned, 10, width, true)],
        ['Hexadecimal', '0x' + groupHex(formatBase(unsigned, 16, width, false))],
        ['Octal', '0o' + formatBase(unsigned, 8, width, false)],
        ['Binary', '0b' + groupBin(formatBase(unsigned, 2, width, false), 8)],
      ];
      status.innerHTML = rows.map((r) =>
        '<div class="res-row"><span class="res-label">' + r[0] + '</span><span class="res-val">' + r[1] + '</span></div>'
      ).join('');
      if (typeof appendCopyBtn === 'function') appendCopyBtn(status);
    }
    renderVisuals(unsigned, width, BASES[fromBase] || 10);
    applying = false;
    if (typeof writeUrlState === 'function') writeUrlState('sec-base-converter');
  }

  function convertFrom(which) {
    if (applying) return;
    const width = currentWidth();
    const signed = currentSigned();
    const map = { hex: 16, dec: 10, oct: 8, bin: 2 };
    const ids = { hex: 'nbc_hex', dec: 'nbc_dec', oct: 'nbc_oct', bin: 'nbc_bin' };
    const el = byId(ids[which]);
    if (!el) return;
    try {
      const u = parseBase(el.value, map[which], width, which === 'dec' && signed);
      applyUnsigned(u, width, which);
    } catch (err) {
      const status = byId('nbc_status');
      if (status) {
        status.className = 'result error show';
        status.textContent = err.message || String(err);
      }
    }
  }

  function recomputeFromCurrent() {
    convertFrom(sourceBase || 'dec');
  }

  window.nbcConvert = convertFrom;
  window.loadBaseConverterExample = function () {
    if (byId('nbc_width')) byId('nbc_width').value = '8';
    if (byId('nbc_signed')) byId('nbc_signed').checked = true;
    applying = false;
    sourceBase = 'hex';
    setField('nbc_hex', 'FF');
    convertFrom('hex');
  };

  function init() {
    if (!byId('sec-base-converter')) return;
    ['nbc_hex', 'nbc_dec', 'nbc_oct', 'nbc_bin'].forEach((id) => {
      const el = byId(id);
      if (!el) return;
      const which = id.slice(4);
      el.addEventListener('input', function () { convertFrom(which); });
    });
    const width = byId('nbc_width');
    if (width) width.addEventListener('change', function () { recomputeFromCurrent(); });
    const signed = byId('nbc_signed');
    if (signed) signed.addEventListener('change', function () { recomputeFromCurrent(); });

    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-base-converter', 'number-base-converter', function () {
        // Prefer hex as the source of truth after a URL restore so grouped
        // spaces and prefixes round-trip cleanly.
        sourceBase = 'hex';
        convertFrom('hex');
      });
    }
    if (typeof registerReport === 'function') {
      registerReport('nbc_status', {
        title: 'Number-base conversion',
        formula: function () { return 'n = Σ d_i · b^i   with wrap at 2^w; signed decimal is two’s complement'; },
        codeRefs: function () {
          return [
            'Place-value identity n = Σ d_i b^i for b ∈ {2, 8, 10, 16}',
            'Unsigned wrap: n mod 2^w',
            'Two’s-complement signed: if n ≥ 2^{w−1} then n − 2^w',
          ];
        },
      });
    }

    applyUnsigned(0n, currentWidth(), 'dec');
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();

  global.__baseConverterTestApi = {
    parseBase: parseBase,
    formatBase: formatBase,
    wrapWidth: wrapWidth,
    toSigned: toSigned,
    fromSigned: fromSigned,
    roundTrip: roundTrip,
    groupHex: groupHex,
    groupBin: groupBin,
    placeValues: placeValues,
    identityString: identityString,
    maskFor: maskFor,
  };
})(typeof window !== 'undefined' ? window : globalThis);
