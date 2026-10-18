/* Ported from the Beckify iOS app (UL508APanelMath.swift): panel-builder core. Control transformer protection, transformer secondary
   short-circuit current, and disconnect sizing. Feeder sizing, SCCR aggregation, enclosure and wire-color guides stay in the iOS app. */
(function (global) {
  'use strict';
  const T = global.BeckifyTool, si = T.si, fx = T.fixed;
  const OCPD = [10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500, 600, 700, 800, 1000, 1200, 1600, 2000, 2500, 3000, 4000, 5000, 6000];
  const next = (a) => OCPD.find((o) => o >= a - 1e-9), below = (a) => OCPD.slice().reverse().find((o) => o <= a + 1e-9);
  function panel(v) {
    if (v.mode === 'isc') {
      const va = T.positive(v, 'va', 'Transformer VA'), V = T.positive(v, 'sv', 'Secondary voltage'), ph = v.phases === '3' ? 3 : 1, zRaw = T.optional(v, 'z');
      if (zRaw != null && !(zRaw > 0)) throw new Error('Impedance % must be positive.');
      const assumed = zRaw == null || zRaw < 2.1, z = assumed ? 2.1 : zRaw;
      const fla = va / (ph === 3 ? Math.sqrt(3) * V : V), isc = fla / (z / 100);
      return { headline: 'Isc ≈ ' + fx(isc / 1000, 2) + ' kA at the secondary', rows: [['Full-load current', fx(fla, 2, 'A')], ['%Z used', fx(z, 2, '%')], ['Secondary Isc', si(isc, 'A'), true], ['Secondary Isc', fx(isc / 1000, 2, 'kA')]], warning: assumed ? 'Impedance is unmarked or under 2.1 %, so the planning value 2.1 % is used.' : '', steps: ['FLA = VA / (' + (ph === 3 ? '√3 · ' : '') + 'V) = ' + fx(fla, 2) + ' A', 'Isc ≈ FLA / %Z = ' + fx(fla, 2) + ' / ' + fx(z / 100, 4) + ' = ' + fx(isc, 0) + ' A', 'Infinite-bus primary assumed.'], notes: ['Infinite-bus estimate. Real available current is lower once source impedance counts.', 'Compare against the SCCR of the devices on the secondary.'] };
    }
    if (v.mode === 'disc') {
      const a = T.positive(v, 'amps', 'Calculated load');
      const notes = ['Size the disconnect at least as large as the calculated panel load.', 'Supply side, operable from outside the enclosure, and able to be locked open.', 'A through-the-door handle is the usual shop build. Confirm the listing for the enclosure type.'];
      if (v.motor === 'yes') notes.push('When the disconnect switches a motor, it also needs a horsepower rating for that motor.');
      const std = next(a);
      return { headline: 'Disconnect at least ' + fx(a, 1) + ' A', rows: [['Minimum rating', fx(a, 1, 'A'), true], ['Next standard size', std ? std + ' A' : 'Above 6000 A']], steps: ['Disconnect ≥ calculated load = ' + fx(a, 1) + ' A'], notes };
    }
    const va = T.positive(v, 'va', 'Transformer VA'), pv = T.positive(v, 'pv', 'Primary voltage'), sv = T.positive(v, 'sv', 'Secondary voltage');
    const pri = va / pv, sec = va / sv, pct = pri <= 2 ? 500 : pri <= 9 ? 167 : 125, up = pct !== 125;
    const pc = pri * pct / 100, pd = up ? next(pc) : below(pc), sc = sec * 1.25, sd = below(sc) || next(sc);
    return { headline: 'Primary ' + (pd ? pd + ' A' : 'n/a') + ' · secondary ' + (sd ? sd + ' A' : 'n/a'), rows: [['Primary current', fx(pri, 2, 'A')], ['Secondary current', fx(sec, 2, 'A')], ['Primary band', pct + ' %'], ['Primary ceiling', fx(pc, 2, 'A')], ['Primary device', pd ? pd + ' A' : 'None under the ceiling', true], ['Secondary ceiling (125 %)', fx(sc, 2, 'A')], ['Secondary device', sd ? sd + ' A' : 'n/a', true]], warning: pd ? '' : 'No standard device fits under the 125 % ceiling.', steps: ['Primary FLA = VA / Vp = ' + fx(pri, 2) + ' A', pct + ' % band: ' + (up ? 'next standard size up' : 'largest standard size not above') + ' ' + fx(pc, 2) + ' A', 'Secondary ≤ 125 % of ' + fx(sec, 2) + ' A'], notes: ['Control power tapped from the feeder: the primary device is part of the power-circuit SCCR; devices on its load side are not.', 'A Class 2 or limited-energy secondary is a different circuit. Do not size it like a power branch.', 'Power transformers with primary and secondary protection belong in Transformer Sizing (450.3(B)).'] };
  }
  T.define({ id: 'ul508aPanelLab', root: 'bk-panel-root', title: 'Control panel (UL 508A) core', lede: 'Control transformer protection, transformer secondary fault current, and disconnect sizing for an industrial control panel.',
    fields: [{ id: 'mode', label: 'Calculate', choices: [['ctrl', 'Control transformer protection'], ['isc', 'Transformer secondary fault current'], ['disc', 'Disconnect minimum']], def: 'ctrl' },
      { id: 'va', label: 'Transformer VA', unit: 'VA', def: '500', showIf: (v) => v.mode !== 'disc' }, { id: 'pv', label: 'Primary voltage', unit: 'V', def: '480', showIf: (v) => v.mode === 'ctrl' }, { id: 'sv', label: 'Secondary voltage', unit: 'V', def: '120', showIf: (v) => v.mode !== 'disc' },
      { id: 'phases', label: 'Phases', choices: [['1', 'Single-phase'], ['3', 'Three-phase']], def: '1', showIf: (v) => v.mode === 'isc' }, { id: 'z', label: 'Impedance %Z', unit: '%', def: '', optional: true, showIf: (v) => v.mode === 'isc', help: 'Blank or under 2.1 uses 2.1 %.' },
      { id: 'amps', label: 'Calculated panel load', unit: 'A', def: '45', showIf: (v) => v.mode === 'disc' }, { id: 'motor', label: 'Switches a motor', choices: [['no', 'No'], ['yes', 'Yes']], def: 'no', showIf: (v) => v.mode === 'disc' }],
    compute: panel, example: { va: '1000', pv: '480', sv: '120' }, foot: 'Planning aid for UL 508A panel builds. The standard, the component listings and the AHJ govern. Feeder sizing, SCCR aggregation and enclosure guides are in the iOS app.' });
})(typeof window !== 'undefined' ? window : globalThis);
