/* ============================================================================
   LAST-USED INPUTS — localStorage only, never photos or files
   ============================================================================
   Mirrors typed values for a toolbox section so a return visit on this device
   starts where the user left off. File inputs, camera captures, and object
   URLs are skipped on purpose: photos must not leave the browser session.
   ============================================================================ */
(function (global) {
  'use strict';

  var PREFIX = 'beckify-last-used-';
  var SKIP_TYPES = { file: true, button: true, submit: true, reset: true, image: true, hidden: true };

  function bindLastUsed(sectionId, toolKey) {
    var section = document.getElementById(sectionId);
    if (!section || !toolKey) return;
    var key = PREFIX + toolKey;
    restore(section, key);
    var timer = null;
    function schedule() {
      clearTimeout(timer);
      timer = setTimeout(function () { save(section, key); }, 200);
    }
    section.addEventListener('input', schedule);
    section.addEventListener('change', schedule);
  }

  function fields(section) {
    return Array.prototype.slice.call(section.querySelectorAll('input[id], select[id], textarea[id]'))
      .filter(function (el) {
        if (!el.id) return false;
        if (SKIP_TYPES[el.type]) return false;
        if (el.getAttribute('data-no-persist') !== null) return false;
        return true;
      });
  }

  function save(section, key) {
    var data = {};
    fields(section).forEach(function (el) {
      if (el.type === 'checkbox') data[el.id] = el.checked ? '1' : '0';
      else data[el.id] = el.value;
    });
    try { localStorage.setItem(key, JSON.stringify(data)); } catch (_) { /* private mode */ }
  }

  function restore(section, key) {
    var raw;
    try { raw = localStorage.getItem(key); } catch (_) { return; }
    if (!raw) return;
    var data;
    try { data = JSON.parse(raw); } catch (_) { return; }
    if (!data || typeof data !== 'object') return;
    fields(section).forEach(function (el) {
      if (!Object.prototype.hasOwnProperty.call(data, el.id)) return;
      var val = data[el.id];
      if (el.type === 'checkbox') {
        el.checked = val === '1' || val === true || val === 'true';
        return;
      }
      if (el.tagName === 'SELECT') {
        var ok = Array.prototype.some.call(el.options, function (o) { return o.value === val; });
        if (ok) el.value = val;
        return;
      }
      el.value = val;
    });
  }

  global.bindLastUsed = bindLastUsed;
})(typeof window !== 'undefined' ? window : globalThis);
