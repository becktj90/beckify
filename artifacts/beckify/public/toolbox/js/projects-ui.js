/* ============================================================================
   JOB PROJECTS UI
   ============================================================================
   A "Save to job" button beside every calculator result, and a Job Projects
   section listing saved work with load / delete.

   A saved run captures the tool, its inputs, its results and the deep link, so
   reopening a run restores the exact calculator state that produced it rather
   than just a screenshot of the numbers.
   ============================================================================ */

/* ---------------------------------------------------------------------------
   Saving
   --------------------------------------------------------------------------- */

function collectRun(sectionId, resultId) {
  const section = document.getElementById(sectionId);
  const scraped = typeof scrapeReport === 'function'
    ? scrapeReport(section, resultId)
    : { inputs: [], results: [] };
  const h2 = section ? section.querySelector('h2') : null;
  return {
    tool: sectionId,
    label: h2 ? h2.textContent.replace(/[^\x20-\x7E]/g, '').trim() : sectionId,
    inputs: scraped.inputs,
    results: scraped.results,
    url: location.pathname + location.search + location.hash,
  };
}

function openSaveDialog(sectionId, resultId) {
  const modal = buildSaveModal();
  const run = collectRun(sectionId, resultId);

  const status = document.getElementById('save-status');
  status.textContent = '';
  status.className = 'report-status';

  const summary = document.getElementById('save-summary');
  summary.textContent = '';
  const t = document.createElement('div');
  t.className = 'report-preview-title';
  t.textContent = run.label;
  const sub = document.createElement('div');
  sub.className = 'report-preview-sub';
  sub.textContent = run.inputs.length + ' inputs · ' + run.results.length + ' results';
  summary.appendChild(t);
  summary.appendChild(sub);

  if (!run.results.length) {
    status.textContent = 'Run the calculation first — there is nothing to save yet.';
    status.className = 'report-status warn';
  }

  const select = document.getElementById('save-project');
  LocalStore.listProjects().then(function (projects) {
    select.textContent = '';
    const nw = document.createElement('option');
    nw.value = '__new';
    nw.textContent = '➕ New job…';
    select.appendChild(nw);
    projects.forEach(function (p) {
      const o = document.createElement('option');
      o.value = p.id;
      o.textContent = p.name + '  (' + p.runs.length + ')';
      select.appendChild(o);
    });
    // Default to the most recent job so repeated saves land together.
    if (projects.length) select.value = projects[0].id;
    toggleNewName();
  }).catch(function (e) {
    status.textContent = e.message;
    status.className = 'report-status warn';
  });

  document.getElementById('save-confirm').onclick = function () { commitSave(run); };
  modal.hidden = false;
  document.body.classList.add('report-open');
}

function toggleNewName() {
  const select = document.getElementById('save-project');
  const wrap = document.getElementById('save-new-wrap');
  if (!select || !wrap) return;
  wrap.style.display = select.value === '__new' ? '' : 'none';
}

function commitSave(run) {
  const select = document.getElementById('save-project');
  const status = document.getElementById('save-status');
  const btn = document.getElementById('save-confirm');
  btn.disabled = true;
  status.className = 'report-status';
  status.textContent = 'Saving…';

  const chosen = select.value;
  const target = chosen === '__new'
    ? LocalStore.createProject(document.getElementById('save-new-name').value || 'Untitled job')
    : LocalStore.getProject(chosen);

  target
    .then(function (project) { return LocalStore.saveRun(project.id, run); })
    .then(function () {
      status.textContent = 'Saved to this device.';
      status.className = 'report-status ok';
      btn.disabled = false;
      refreshProjectsPanel();
      setTimeout(closeSaveModal, 800);
    })
    .catch(function (e) {
      status.textContent = e.message || 'Could not save.';
      status.className = 'report-status warn';
      btn.disabled = false;
    });
}

function closeSaveModal() {
  const m = document.getElementById('save-modal');
  if (m) m.hidden = true;
  document.body.classList.remove('report-open');
}

function buildSaveModal() {
  let modal = document.getElementById('save-modal');
  if (modal) return modal;

  modal = document.createElement('div');
  modal.id = 'save-modal';
  modal.className = 'report-modal';
  modal.setAttribute('role', 'dialog');
  modal.setAttribute('aria-modal', 'true');
  modal.hidden = true;

  const panel = document.createElement('div');
  panel.className = 'report-panel';

  const head = document.createElement('div');
  head.className = 'report-panel-head';
  const h3 = document.createElement('h3');
  h3.textContent = 'Save calculation to a job';
  const x = document.createElement('button');
  x.type = 'button';
  x.className = 'report-close';
  x.textContent = '✕';
  x.setAttribute('aria-label', 'Close');
  x.onclick = closeSaveModal;
  head.appendChild(h3);
  head.appendChild(x);

  const body = document.createElement('div');
  body.className = 'report-panel-body';

  const intro = document.createElement('p');
  intro.className = 'report-intro';
  intro.textContent = 'Saved on this device only — no account, no upload, and it works offline. ' +
    'Reopening a run restores the calculator exactly as it was.';
  body.appendChild(intro);

  const summary = document.createElement('div');
  summary.className = 'report-preview';
  summary.id = 'save-summary';
  body.appendChild(summary);

  const f1 = document.createElement('div');
  f1.className = 'report-field';
  f1.style.marginTop = '12px';
  const l1 = document.createElement('label');
  l1.setAttribute('for', 'save-project');
  l1.textContent = 'Job';
  const sel = document.createElement('select');
  sel.id = 'save-project';
  sel.onchange = toggleNewName;
  f1.appendChild(l1);
  f1.appendChild(sel);
  body.appendChild(f1);

  const f2 = document.createElement('div');
  f2.className = 'report-field';
  f2.id = 'save-new-wrap';
  const l2 = document.createElement('label');
  l2.setAttribute('for', 'save-new-name');
  l2.textContent = 'New job name';
  const inp = document.createElement('input');
  inp.type = 'text';
  inp.id = 'save-new-name';
  inp.placeholder = 'e.g. Site Alpha — Feeder Analysis';
  f2.appendChild(l2);
  f2.appendChild(inp);
  body.appendChild(f2);

  const status = document.createElement('p');
  status.className = 'report-status';
  status.id = 'save-status';
  body.appendChild(status);

  const foot = document.createElement('div');
  foot.className = 'report-panel-foot';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'btn btn-secondary';
  cancel.textContent = 'Cancel';
  cancel.onclick = closeSaveModal;
  const go = document.createElement('button');
  go.type = 'button';
  go.className = 'btn';
  go.id = 'save-confirm';
  go.textContent = 'Save';
  foot.appendChild(cancel);
  foot.appendChild(go);

  panel.appendChild(head);
  panel.appendChild(body);
  panel.appendChild(foot);
  modal.appendChild(panel);
  modal.addEventListener('click', function (e) { if (e.target === modal) closeSaveModal(); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !modal.hidden) closeSaveModal();
  });
  document.body.appendChild(modal);
  return modal;
}

/* ---------------------------------------------------------------------------
   Projects panel
   --------------------------------------------------------------------------- */

function refreshProjectsPanel() {
  const host = document.getElementById('projects_host');
  if (!host) return;
  host.textContent = '';

  LocalStore.listProjects().then(function (projects) {
    if (!projects.length) {
      const empty = document.createElement('p');
      empty.className = 'proj-empty';
      empty.textContent = 'No saved jobs yet. Run any calculator and choose "Save to job".';
      host.appendChild(empty);
      return;
    }

    projects.forEach(function (p) {
      const card = document.createElement('div');
      card.className = 'proj-card';

      const head = document.createElement('div');
      head.className = 'proj-head';
      const name = document.createElement('span');
      name.className = 'proj-name';
      name.textContent = p.name;
      const count = document.createElement('span');
      count.className = 'proj-count';
      count.textContent = p.runs.length + (p.runs.length === 1 ? ' run' : ' runs');
      head.appendChild(name);
      head.appendChild(count);

      const meta = document.createElement('div');
      meta.className = 'proj-meta';
      meta.textContent = 'Updated ' + new Date(p.updated).toLocaleString();
      head.appendChild(meta);

      const actions = document.createElement('div');
      actions.className = 'proj-actions';
      const ren = document.createElement('button');
      ren.type = 'button';
      ren.className = 'btn btn-secondary proj-btn';
      ren.textContent = 'Rename';
      ren.onclick = function () {
        const next = prompt('Rename job', p.name);
        if (next) LocalStore.renameProject(p.id, next).then(refreshProjectsPanel);
      };
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'btn btn-secondary proj-btn proj-danger';
      del.textContent = 'Delete job';
      del.onclick = function () {
        if (confirm('Delete "' + p.name + '" and its ' + p.runs.length + ' saved run(s)?')) {
          LocalStore.deleteProject(p.id).then(refreshProjectsPanel);
        }
      };
      actions.appendChild(ren);
      actions.appendChild(del);

      card.appendChild(head);
      card.appendChild(actions);

      p.runs.slice().reverse().forEach(function (run) {
        const row = document.createElement('div');
        row.className = 'proj-run';

        const info = document.createElement('div');
        info.className = 'proj-run-info';
        const rl = document.createElement('div');
        rl.className = 'proj-run-label';
        rl.textContent = run.label;
        const rd = document.createElement('div');
        rd.className = 'proj-run-date';
        const headline = (run.results || []).slice(0, 2)
          .map(function (r) { return r[0] + ': ' + r[1]; }).join('   ·   ');
        rd.textContent = new Date(run.saved).toLocaleString() + (headline ? '   ·   ' + headline : '');
        info.appendChild(rl);
        info.appendChild(rd);

        const btns = document.createElement('div');
        btns.className = 'proj-run-actions';
        const open = document.createElement('button');
        open.type = 'button';
        open.className = 'btn btn-secondary proj-btn';
        open.textContent = 'Open';
        open.onclick = function () { location.href = run.url; };
        const rm = document.createElement('button');
        rm.type = 'button';
        rm.className = 'btn btn-secondary proj-btn proj-danger';
        rm.textContent = '✕';
        rm.title = 'Delete this run';
        rm.onclick = function () {
          LocalStore.deleteRun(p.id, run.id).then(refreshProjectsPanel);
        };
        btns.appendChild(open);
        btns.appendChild(rm);

        row.appendChild(info);
        row.appendChild(btns);
        card.appendChild(row);
      });

      host.appendChild(card);
    });
  }).catch(function (e) {
    const err = document.createElement('p');
    err.className = 'proj-empty';
    err.textContent = e.message;
    host.appendChild(err);
  });

  LocalStore.estimate().then(function (est) {
    const el = document.getElementById('projects_usage');
    if (!el) return;
    if (!est || !est.usage) { el.textContent = 'Stored on this device only.'; return; }
    el.textContent = 'Using ' + (est.usage / 1024).toFixed(0) +
      ' kB of on-device storage. Stored on this device only.';
  }).catch(function () {});
}

/* ---------------------------------------------------------------------------
   Game statistics
   --------------------------------------------------------------------------- */

function refreshGameStats() {
  const host = document.getElementById('game_stats_host');
  if (!host) return;
  LocalStore.listGameData().then(function (rows) {
    host.textContent = '';
    const played = rows.filter(function (g) { return (g.plays || 0) > 0; });
    if (!played.length) {
      const p = document.createElement('p');
      p.className = 'proj-empty';
      p.textContent = 'No games finished yet on this device. ' +
        'New Glenn Runner records a best score and a play count here.';
      host.appendChild(p);
      return;
    }
    played.sort(function (a, b) { return (b.lastPlayed || 0) - (a.lastPlayed || 0); });
    played.forEach(function (g) {
      const row = document.createElement('div');
      row.className = 'res-row';
      const l = document.createElement('span');
      l.className = 'res-label';
      l.textContent = (window.GAME_NAMES && window.GAME_NAMES[g.id]) || g.id;
      const v = document.createElement('span');
      v.className = 'res-val';
      const avg = g.plays ? Math.round((g.totalScore || 0) / g.plays) : 0;
      v.textContent = 'best ' + (g.highScore || 0).toLocaleString() +
        '  ·  ' + g.plays + (g.plays === 1 ? ' play' : ' plays') +
        '  ·  avg ' + avg.toLocaleString();
      row.appendChild(l);
      row.appendChild(v);
      host.appendChild(row);
    });
  }).catch(function () {});
}

/* ---------------------------------------------------------------------------
   Wiring
   --------------------------------------------------------------------------- */

function attachSaveButtons() {
  document.querySelectorAll('section[id^="sec-"]').forEach(function (section) {
    section.querySelectorAll('.result').forEach(function (res) {
      if (!res.id) return;
      if (section.querySelector('.save-run-btn[data-result="' + res.id + '"]')) return;
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn btn-secondary save-run-btn';
      btn.dataset.result = res.id;
      btn.textContent = '🗂 Save to job';
      btn.onclick = function () { openSaveDialog(section.id, res.id); };

      // Both per-result buttons go in one flex row so they share a gap and wrap
      // to a common left edge on narrow screens, rather than each carrying its
      // own margin and stepping out of line when the row breaks.
      const bar = document.createElement('div');
      bar.className = 'result-actions';
      res.parentNode.insertBefore(bar, res.nextSibling);
      const exportBtn = section.querySelector('.report-export-btn[data-result="' + res.id + '"]');
      if (exportBtn) bar.appendChild(exportBtn);
      bar.appendChild(btn);
    });
  });
}

document.addEventListener('DOMContentLoaded', function () {
  attachSaveButtons();
  refreshProjectsPanel();
  refreshGameStats();

  const newBtn = document.getElementById('proj_new');
  if (newBtn) {
    newBtn.onclick = function () {
      const name = prompt('Name this job', 'Site Alpha — Feeder Analysis');
      if (name) LocalStore.createProject(name).then(refreshProjectsPanel);
    };
  }

  /* Unit toggle */
  const unitSel = document.getElementById('pref_units');
  if (unitSel) {
    unitSel.value = LocalStore.getPrefSync('units', 'imperial');
    unitSel.addEventListener('change', function () {
      LocalStore.setPref('units', unitSel.value);
      applyUnitSystem(unitSel.value);
    });
  }

  /* The stats only change while a game is being played, so refresh them when
     the panel is opened rather than polling. */
  document.querySelectorAll('[data-target="sec-projects"], a[href="#sec-projects"]')
    .forEach(function (el) {
      el.addEventListener('click', function () {
        setTimeout(function () { refreshProjectsPanel(); refreshGameStats(); }, 30);
      });
    });
});

window.refreshProjectsPanel = refreshProjectsPanel;
window.refreshGameStats = refreshGameStats;
window.openSaveDialog = openSaveDialog;
