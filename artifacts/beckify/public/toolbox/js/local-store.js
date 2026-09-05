/* ============================================================================
   LOCAL-FIRST STORAGE — IndexedDB, no backend
   ============================================================================
   Everything the toolbox remembers lives on the device. Nothing is uploaded,
   there is no account, and it all keeps working with the network off.

   Three stores:
     projects  — named jobs, each holding saved calculation runs
     gamedata  — high scores, keybindings, play stats
     prefs     — unit system, theme, and other site preferences

   Written against raw IndexedDB rather than RxDB or Dexie. Those are excellent
   libraries, but they are ES modules aimed at a bundler and this toolbox is
   plain <script> tags with no build step — adding one would mean either a
   vendored UMD bundle of a few hundred kB or a build pipeline, for an API
   surface this small. Roughly 120 lines of promise wrapper covers it.

   Preferences also mirror to localStorage so the very first paint can read
   them synchronously, before IndexedDB has opened.
   ============================================================================ */

const LS_DB_NAME = 'beckify-toolbox';
const LS_DB_VERSION = 1;
const LS_PREFS_MIRROR = 'beckify-prefs';

let lsDbPromise = null;

function lsOpen() {
  if (lsDbPromise) return lsDbPromise;
  lsDbPromise = new Promise(function (resolve, reject) {
    if (!('indexedDB' in window)) {
      reject(new Error('This browser has no IndexedDB, so saving is unavailable.'));
      return;
    }
    const req = indexedDB.open(LS_DB_NAME, LS_DB_VERSION);
    req.onupgradeneeded = function (e) {
      const db = e.target.result;
      if (!db.objectStoreNames.contains('projects')) {
        const s = db.createObjectStore('projects', { keyPath: 'id' });
        s.createIndex('updated', 'updated');
        s.createIndex('name', 'name');
      }
      if (!db.objectStoreNames.contains('gamedata')) {
        db.createObjectStore('gamedata', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('prefs')) {
        db.createObjectStore('prefs', { keyPath: 'key' });
      }
    };
    req.onsuccess = function () { resolve(req.result); };
    req.onerror = function () {
      lsDbPromise = null;
      reject(req.error || new Error('Could not open local storage'));
    };
  });
  return lsDbPromise;
}

function lsTx(storeName, mode, fn) {
  return lsOpen().then(function (db) {
    return new Promise(function (resolve, reject) {
      const tx = db.transaction(storeName, mode);
      const store = tx.objectStore(storeName);
      let result;
      try { result = fn(store); } catch (e) { reject(e); return; }
      tx.oncomplete = function () {
        resolve(result && result.__req ? result.__req.result : result);
      };
      tx.onerror = function () { reject(tx.error); };
      tx.onabort = function () { reject(tx.error); };
    });
  });
}

/** Wraps an IDBRequest so lsTx can resolve with its result after commit. */
function lsReq(request) { return { __req: request }; }

function lsId(prefix) {
  return prefix + '-' + Date.now().toString(36) + '-' +
    Math.random().toString(36).slice(2, 8);
}

/* ---------------------------------------------------------------------------
   Job projects — a named job holding saved calculation runs
   --------------------------------------------------------------------------- */

const LocalStore = {
  /** All projects, most recently updated first. */
  listProjects: function () {
    return lsTx('projects', 'readonly', function (s) { return lsReq(s.getAll()); })
      .then(function (rows) {
        return (rows || []).sort(function (a, b) { return b.updated - a.updated; });
      });
  },

  getProject: function (id) {
    return lsTx('projects', 'readonly', function (s) { return lsReq(s.get(id)); });
  },

  createProject: function (name) {
    const now = Date.now();
    const project = {
      id: lsId('proj'), name: String(name || 'Untitled job').trim() || 'Untitled job',
      created: now, updated: now, runs: [],
    };
    return lsTx('projects', 'readwrite', function (s) { s.put(project); return project; });
  },

  renameProject: function (id, name) {
    return this.getProject(id).then(function (p) {
      if (!p) throw new Error('Project not found');
      p.name = String(name || '').trim() || p.name;
      p.updated = Date.now();
      return lsTx('projects', 'readwrite', function (s) { s.put(p); return p; });
    });
  },

  deleteProject: function (id) {
    return lsTx('projects', 'readwrite', function (s) { s.delete(id); return true; });
  },

  /** Appends a calculation run. `run` is {tool, label, inputs, results, url}. */
  saveRun: function (projectId, run) {
    return this.getProject(projectId).then(function (p) {
      if (!p) throw new Error('Project not found');
      const entry = Object.assign({ id: lsId('run'), saved: Date.now() }, run);
      p.runs.push(entry);
      p.updated = Date.now();
      return lsTx('projects', 'readwrite', function (s) { s.put(p); return entry; });
    });
  },

  deleteRun: function (projectId, runId) {
    return this.getProject(projectId).then(function (p) {
      if (!p) return false;
      p.runs = p.runs.filter(function (r) { return r.id !== runId; });
      p.updated = Date.now();
      return lsTx('projects', 'readwrite', function (s) { s.put(p); return true; });
    });
  },

  /* -------------------------------------------------------------------------
     Game data — high scores, keybindings, play stats
     ------------------------------------------------------------------------- */

  getGameData: function (gameId) {
    return lsTx('gamedata', 'readonly', function (s) { return lsReq(s.get(gameId)); })
      .then(function (row) {
        return row || { id: gameId, highScore: 0, plays: 0, totalScore: 0, keys: {} };
      });
  },

  /** Records a play. Returns the record, flagging whether it set a new best. */
  recordScore: function (gameId, score) {
    return this.getGameData(gameId).then(function (d) {
      const isBest = score > (d.highScore || 0);
      d.highScore = Math.max(d.highScore || 0, score);
      d.plays = (d.plays || 0) + 1;
      d.totalScore = (d.totalScore || 0) + score;
      d.lastScore = score;
      d.lastPlayed = Date.now();
      return lsTx('gamedata', 'readwrite', function (s) { s.put(d); return d; })
        .then(function (saved) { saved.isBest = isBest; return saved; });
    });
  },

  setKeybindings: function (gameId, keys) {
    return this.getGameData(gameId).then(function (d) {
      d.keys = Object.assign({}, d.keys, keys);
      return lsTx('gamedata', 'readwrite', function (s) { s.put(d); return d; });
    });
  },

  listGameData: function () {
    return lsTx('gamedata', 'readonly', function (s) { return lsReq(s.getAll()); })
      .then(function (r) { return r || []; });
  },

  /* -------------------------------------------------------------------------
     Preferences
     ------------------------------------------------------------------------- */

  getPref: function (key, fallback) {
    return lsTx('prefs', 'readonly', function (s) { return lsReq(s.get(key)); })
      .then(function (row) { return row ? row.value : fallback; })
      .catch(function () { return fallback; });
  },

  setPref: function (key, value) {
    // Mirror so the next first paint can read it before IndexedDB opens.
    try {
      const mirror = JSON.parse(localStorage.getItem(LS_PREFS_MIRROR) || '{}');
      mirror[key] = value;
      localStorage.setItem(LS_PREFS_MIRROR, JSON.stringify(mirror));
    } catch (_) {}
    // The mirror above already holds the value, so a private-mode IndexedDB
    // refusal should not surface as an unhandled rejection.
    return lsTx('prefs', 'readwrite', function (s) {
      s.put({ key: key, value: value });
      return value;
    }).catch(function () { return value; });
  },

  /** Synchronous read of the localStorage mirror, for first paint. */
  getPrefSync: function (key, fallback) {
    try {
      const mirror = JSON.parse(localStorage.getItem(LS_PREFS_MIRROR) || '{}');
      return key in mirror ? mirror[key] : fallback;
    } catch (_) { return fallback; }
  },

  /** Rough footprint, for the storage panel. */
  estimate: function () {
    if (navigator.storage && navigator.storage.estimate) return navigator.storage.estimate();
    return Promise.resolve(null);
  },
};

/* ---------------------------------------------------------------------------
   Unit system — imperial or metric
   ---------------------------------------------------------------------------
   Conversions are applied for display only. The calculators work in the units
   the NEC tables are published in, so switching to metric converts the
   presentation rather than re-deriving the code tables in millimetres.
   --------------------------------------------------------------------------- */

const UNIT_CONVERSIONS = {
  ft: { to: 'm', factor: 0.3048, decimals: 1 },
  'in²': { to: 'cm²', factor: 6.4516, decimals: 2 },
  'sq in': { to: 'cm²', factor: 6.4516, decimals: 2 },
  '°C': { to: '°F', factor: null, decimals: 0 }, // handled specially
};

function applyUnitSystem(system) {
  document.body.dataset.units = system;
  const badge = document.getElementById('unit-badge');
  if (badge) badge.textContent = system === 'metric' ? 'Metric' : 'Imperial';
}

/* ---------------------------------------------------------------------------
   Game bridge
   ---------------------------------------------------------------------------
   The games are self-contained IIFEs that already persist their own settings to
   localStorage, and rewriting their save layers would be a large change for no
   gain. Instead they call this one function when a run ends, so the toolbox can
   keep a cross-game record of bests and play counts without owning their state.

   Deliberately forgiving: a game must never break because storage is
   unavailable, so every failure path is a silent no-op.
   --------------------------------------------------------------------------- */

const GAME_NAMES = {
  'kestrel-heavy': '🚀 Kestrel Heavy',
  'new-glenn-runner': '🚀 Kestrel Heavy',
};

function recordGameScore(gameId, score) {
  const n = Number(score);
  if (!isFinite(n)) return Promise.resolve(null);
  try {
    return LocalStore.recordScore(gameId, n).catch(function () { return null; });
  } catch (_) {
    return Promise.resolve(null);
  }
}

window.LocalStore = LocalStore;
window.applyUnitSystem = applyUnitSystem;
window.UNIT_CONVERSIONS = UNIT_CONVERSIONS;
window.recordGameScore = recordGameScore;
window.GAME_NAMES = GAME_NAMES;

/* Apply the stored unit preference before anything renders. */
applyUnitSystem(LocalStore.getPrefSync('units', 'imperial'));
