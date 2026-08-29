/* Shared Feynman-style teaching layer for the static toolbox. */
(function () {
  'use strict';
  const LESSONS = {
    'sec-ohm': ['Think of a circuit as a water slide', 'V = I R', 'Voltage is the push, resistance is the narrowness of the slide, and current is how much charge gets through each second. Change any one and the other two have to balance.'],
    'sec-stem-tools': ['STEM tools are stories about change', "y' = \\frac{dy}{dt} \\quad \\text{and} \\quad \\Delta x \\approx v\\,\\Delta t", 'A derivative is a speedometer for a quantity. Each solver takes a small step, asks what the world is doing right now, and uses that local answer to predict the next step.'],
    'sec-circuit-sim': ['Kirchhoff is the traffic rule', '\\sum I_{in} = \\sum I_{out}', 'Charge cannot pile up at an ordinary node. The solver adjusts node voltages until every junction has balanced traffic.'],
    'sec-555': ['A capacitor is a bucket for charge', 'I = C\\frac{dV}{dt}', 'A capacitor resists sudden voltage changes because its stored charge must arrive through a finite current. That is why RC circuits make time.'],
    'sec-tdr': ['A TDR is radar for copper', 'd = \\frac{VF\\,c\\,t}{2}', 'The pulse travels out, notices a change in the cable, and returns. The divide-by-two matters because the measured time includes both trips.']
  };
  function texFallback(tex) {
    const esc = (value) => String(value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
    let html = esc(tex.trim());
    html = html.replace(/\\frac\{([^{}]+)\}\{([^{}]+)\}/g, '<span class="tex-frac"><span>$1</span><span>$2</span></span>');
    html = html.replace(/\\text\{([^{}]+)\}/g, '<span class="tex-text">$1</span>');
    html = html.replace(/\\quad/g, '<span class="tex-space"></span>');
    html = html.replace(/\\,/g, '<span class="tex-thin-space"></span>');
    html = html.replace(/\\Delta/g, '&Delta;').replace(/\\sum/g, '&sum;');
    return html;
  }
  function renderFormula(formula) {
    const tex = formula.dataset.tex || formula.textContent.replace(/^\$\$|\$\$$/g, '').trim();
    formula.dataset.tex = tex;
    formula.innerHTML = texFallback(tex);
    if (window.MathJax && typeof window.MathJax.typesetPromise === 'function') {
      formula.textContent = '$$' + tex + '$$';
      window.MathJax.typesetPromise([formula]).catch(() => {});
    }
  }
  function loadMathJax() {
    if (document.querySelector('script[data-beckify-mathjax]')) return;
    window.MathJax = { tex: { inlineMath: [['$', '$']], displayMath: [['$$', '$$']] }, startup: { typeset: false } };
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js';
    script.async = true;
    script.dataset.beckifyMathjax = '1';
    script.onload = () => document.querySelectorAll('.feynman-formula').forEach(renderFormula);
    script.onerror = () => {};
    document.head.appendChild(script);
  }
  function addLesson(section) {
    const lesson = LESSONS[section.id];
    if (!lesson || section.querySelector('.feynman-lesson')) return;
    const card = document.createElement('aside'); card.className = 'feynman-lesson';
    const title = document.createElement('div'); title.className = 'feynman-lesson-title'; title.textContent = lesson[0];
    const formula = document.createElement('div'); formula.className = 'feynman-formula'; formula.textContent = '$$' + lesson[1] + '$$'; renderFormula(formula);
    const body = document.createElement('p'); body.className = 'feynman-lesson-body'; body.textContent = lesson[2];
    card.append(title, formula, body); (section.querySelector('.section-header, .home-header') || section.firstElementChild)?.after(card);
  }
  function initLessons() { Object.keys(LESSONS).forEach((id) => { const section = document.getElementById(id); if (section) addLesson(section); }); }
  function registerWebMcp() {
    const context = document.modelContext; if (!context?.registerTool) return;
    const lifecycle = new AbortController();
    const explain = { name: 'beckify_explain_concept', title: 'Explain an engineering concept', description: 'Return a plain-language Feynman-style explanation and formula for a Beckify toolbox concept.', inputSchema: { type: 'object', properties: { concept: { type: 'string' } }, required: ['concept'], additionalProperties: false }, annotations: { readOnlyHint: true }, execute(input) { const query = String(input?.concept || '').toLowerCase(); const match = Object.entries(LESSONS).find(([id, lesson]) => id.includes(query) || lesson[0].toLowerCase().includes(query)); return match ? { ok: true, section: match[0], title: match[1][0], formula: match[1][1], explanation: match[1][2] } : { ok: false, error: 'No matching lesson found.' }; } };
    Promise.resolve(context.registerTool(explain, { signal: lifecycle.signal })).catch(() => {});
    window.addEventListener('pagehide', () => lifecycle.abort(), { once: true });
  }
  window.addEventListener('DOMContentLoaded', () => { initLessons(); registerWebMcp(); loadMathJax(); });
  if (document.readyState !== 'loading') { initLessons(); registerWebMcp(); }
})();
