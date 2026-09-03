/* ============================================================================
   TOOLBOX FAMILIES — one nav entry per job, member sections stay in the DOM
   ============================================================================
   Keep this list in step with src/data/toolbox-tools.mjs TOOL_FAMILIES.
   Tap-changer is intentionally NOT a transformer mode.
   ============================================================================ */

const TOOL_FAMILIES = [
  {
    id: 'transformer',
    navLabel: 'Transformer',
    defaultAnchor: 'sec-xfmr-size',
    modes: [
      { id: 'basics', label: 'Ratio & current', slug: 'transformer', anchor: 'sec-xfmr' },
      { id: 'sizing', label: 'Sizing & 450.3', slug: 'transformer-sizing', anchor: 'sec-xfmr-size' },
      { id: 'conductors', label: 'Conductors / OCPD / VD', slug: 'transformer-engine', anchor: 'sec-xfmr-engine' },
      { id: 'design', label: 'Type & winding', slug: 'transformer-design', anchor: 'sec-xfmr-wizard' },
    ],
  },
  {
    id: 'conductors',
    navLabel: 'Conductors',
    defaultAnchor: 'sec-wire-select',
    modes: [
      { id: 'ampacity-cost', label: 'Ampacity & cost', slug: 'conductor-cost-optimizer', anchor: 'sec-wire-select' },
      { id: 'vd', label: 'Voltage drop', slug: 'voltage-drop', anchor: 'sec-vdrop' },
      { id: 'lighting', label: 'Lighting run', slug: 'lighting-voltage-drop', anchor: 'sec-lighting-opt' },
      { id: 'length', label: 'Length from R', slug: 'conductor-length-resistance', anchor: 'sec-conductor-length' },
      { id: 'mv', label: 'MV cable', slug: 'mv-cable', anchor: 'sec-mv-cable' },
    ],
  },
  {
    id: 'conduit',
    navLabel: 'Conduit Fill',
    defaultAnchor: 'sec-conduit',
    modes: [
      { id: 'same-size', label: 'Same size', slug: 'conduit-fill', anchor: 'sec-conduit' },
      { id: 'mixed', label: 'Mixed sizes', slug: 'conduit-fill-mixed', anchor: 'sec-conduit-adv' },
    ],
  },
  {
    id: 'power',
    navLabel: 'Power',
    defaultAnchor: 'sec-power-wizard',
    modes: [
      { id: 'wizard', label: 'DC / 1Ø / 3Ø', slug: 'power-wizard', anchor: 'sec-power-wizard' },
      { id: 'dc', label: 'DC identities', slug: 'dc-power', anchor: 'sec-power-dc' },
    ],
  },
  {
    id: 'motor',
    navLabel: 'Motor',
    defaultAnchor: 'sec-motor-ref',
    modes: [
      { id: 'fla', label: 'FLA tables', slug: 'motor-ref', anchor: 'sec-motor-ref' },
      { id: 'formula', label: 'HP / kW / amps', slug: 'motor-calculations', anchor: 'sec-motor' },
    ],
  },
  {
    id: 'panel',
    navLabel: 'Panel Schedule',
    defaultAnchor: 'sec-panel-schedule',
    modes: [
      { id: 'load', label: 'Load analyzer', slug: 'panel-schedule-load-analyzer', anchor: 'sec-panel-schedule' },
      { id: 'study', label: 'Power study', slug: 'panel-power-study', anchor: 'sec-panel-power-study' },
    ],
  },
  {
    id: 'on-site-power',
    navLabel: 'On-site power',
    defaultAnchor: 'sec-ups',
    modes: [
      { id: 'ups', label: 'UPS', slug: 'ups-sizing', anchor: 'sec-ups' },
      { id: 'generator', label: 'Generator', slug: 'generator-sizing', anchor: 'sec-gen' },
      { id: 'hybrid', label: 'Hybrid', slug: 'hybrid-generator', anchor: 'sec-hybrid' },
      { id: 'bess', label: 'BESS', slug: 'bess-peak-shave', anchor: 'sec-bess' },
    ],
  },
  {
    id: 'rlc',
    navLabel: 'Reactance & Resonance',
    defaultAnchor: 'sec-reactance',
    modes: [
      { id: 'xz', label: 'X / Z', slug: 'reactance-impedance', anchor: 'sec-reactance' },
      { id: 'resonance', label: 'Resonance', slug: 'resonance', anchor: 'sec-resonance' },
    ],
  },
];

const FAMILY_BY_ANCHOR = {};
const FAMILY_DEFAULTS = {};
TOOL_FAMILIES.forEach(function (family) {
  FAMILY_DEFAULTS[family.id] = family.defaultAnchor;
  family.modes.forEach(function (mode) {
    FAMILY_BY_ANCHOR[mode.anchor] = family;
  });
});

function familyForSection(sectionId) {
  return FAMILY_BY_ANCHOR[sectionId] || null;
}

function navTargetForSection(sectionId) {
  const family = familyForSection(sectionId);
  return family ? family.defaultAnchor : sectionId;
}

function injectFamilyTabs() {
  TOOL_FAMILIES.forEach(function (family) {
    if (family.modes.length < 2) return;
    family.modes.forEach(function (mode) {
      const section = document.getElementById(mode.anchor);
      if (!section || section.querySelector('.family-tabs')) return;
      const bar = document.createElement('div');
      bar.className = 'family-tabs';
      bar.setAttribute('role', 'tablist');
      bar.setAttribute('aria-label', family.navLabel + ' modes');
      const title = document.createElement('div');
      title.className = 'family-tabs-title';
      title.textContent = family.navLabel;
      const tabs = document.createElement('div');
      tabs.className = 'family-tab-row';
      family.modes.forEach(function (m) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'family-tab' + (m.anchor === mode.anchor ? ' active' : '');
        btn.textContent = m.label;
        btn.setAttribute('role', 'tab');
        btn.setAttribute('aria-selected', m.anchor === mode.anchor ? 'true' : 'false');
        btn.dataset.target = m.anchor;
        btn.addEventListener('click', function () {
          if (location.hash !== '#' + m.anchor) location.hash = m.anchor;
          else if (typeof setActiveSection === 'function') setActiveSection(m.anchor);
        });
        tabs.appendChild(btn);
      });
      bar.appendChild(title);
      bar.appendChild(tabs);
      section.insertBefore(bar, section.firstChild);
    });
  });
}

const _setActiveSection = typeof setActiveSection === 'function' ? setActiveSection : null;
if (_setActiveSection) {
  window.setActiveSection = function (sectionId, opts) {
    _setActiveSection(sectionId, opts);
    const family = familyForSection(sectionId);
    const highlight = family ? family.defaultAnchor : sectionId;
    document.querySelectorAll('.nav-btn').forEach(function (btn) {
      const target = btn.dataset.target;
      const on = target === highlight || target === sectionId;
      btn.classList.toggle('active', on);
    });
  };
}

window.TOOL_FAMILIES = TOOL_FAMILIES;
window.familyForSection = familyForSection;
window.navTargetForSection = navTargetForSection;

document.addEventListener('DOMContentLoaded', function () {
  injectFamilyTabs();
  document.addEventListener('click', function (event) {
    const btn = event.target.closest('button[data-target]:not(.nav-btn):not(.family-tab)');
    if (!btn || !btn.dataset.target) return;
    const target = btn.dataset.target;
    if (location.hash !== '#' + target) location.hash = target;
    else if (typeof setActiveSection === 'function') setActiveSection(target);
  });
});
