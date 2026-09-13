/* Offline stub — website uses /toolbox/js/local-store.js.
   Kestrel Heavy already persists scores in localStorage via js/storage.js.
   recordGameScore is a no-op so a missing toolbox IDB never breaks a flight. */
window.recordGameScore = window.recordGameScore || function () { return Promise.resolve(null); };
