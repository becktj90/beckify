/* Offline combinational-logic workbench and standard parallel-resistor finder. */
(function () {
  'use strict';

  const vars = ['A', 'B', 'C', 'D'];
  const operators = ['AND', 'OR', 'XOR', 'NAND', 'NOR'];
  let gates = [{ id: 'G1', op: 'AND', a: 'A', b: 'B' }];
  let activeAst = null;

  const byId = (id) => document.getElementById(id);
  const create = (tag, attrs, value) => {
    const node = document.createElement(tag);
    Object.entries(attrs || {}).forEach(([key, val]) => node.setAttribute(key, String(val)));
    if (value != null) node.textContent = value;
    return node;
  };
  const setStatus = (id, message, isError) => {
    const node = byId(id);
    if (!node) return;
    node.textContent = message;
    node.style.color = isError ? '#ff8a8a' : '';
  };

  function tokenize(text) {
    const source = String(text || '').trim();
    const tokens = [];
    let index = 0;
    while (index < source.length) {
      const char = source[index];
      if (/\s/.test(char)) { index += 1; continue; }
      if ('()!~*+&|^'.includes(char)) { tokens.push(char); index += 1; continue; }
      const match = source.slice(index).match(/^[A-Za-z][A-Za-z0-9_]*/);
      if (!match) throw new Error(`Unexpected character “${char}”.`);
      const word = match[0].toUpperCase();
      tokens.push(['AND', 'OR', 'XOR', 'NOT'].includes(word) ? word : word);
      index += match[0].length;
    }
    return tokens;
  }

  function parseExpression(text) {
    const tokens = tokenize(text);
    let cursor = 0;
    const peek = () => tokens[cursor];
    const take = () => tokens[cursor++];
    const is = (value) => peek() === value;
    const parsePrimary = () => {
      if (is('(')) { take(); const node = parseOr(); if (!is(')')) throw new Error('Missing closing parenthesis.'); take(); return node; }
      const token = take();
      if (!token || ['AND', 'OR', 'XOR', 'NOT', ')', '*', '+', '&', '|', '^'].includes(token)) throw new Error('Expected an input name or opening parenthesis.');
      return { type: 'var', name: token };
    };
    const parseUnary = () => {
      if (is('!') || is('~') || is('NOT')) { take(); return { type: 'not', input: parseUnary() }; }
      return parsePrimary();
    };
    const parseAnd = () => {
      let node = parseUnary();
      while (is('AND') || is('*') || is('&')) { take(); node = { type: 'gate', op: 'AND', left: node, right: parseUnary() }; }
      return node;
    };
    const parseXor = () => {
      let node = parseAnd();
      while (is('XOR') || is('^')) { take(); node = { type: 'gate', op: 'XOR', left: node, right: parseAnd() }; }
      return node;
    };
    const parseOr = () => {
      let node = parseXor();
      while (is('OR') || is('+') || is('|')) { take(); node = { type: 'gate', op: 'OR', left: node, right: parseXor() }; }
      return node;
    };
    const ast = parseOr();
    if (cursor !== tokens.length) throw new Error(`Unexpected token “${peek()}”.`);
    return ast;
  }

  function astExpression(node) {
    if (node.type === 'var') return node.name;
    if (node.type === 'not') return `NOT (${astExpression(node.input)})`;
    return `(${astExpression(node.left)} ${node.op} ${astExpression(node.right)})`;
  }
  function astVariables(node, output) {
    if (node.type === 'var') output.add(node.name);
    else if (node.type === 'not') astVariables(node.input, output);
    else { astVariables(node.left, output); astVariables(node.right, output); }
  }
  function evaluate(node, values) {
    if (node.type === 'var') return Boolean(values[node.name]);
    if (node.type === 'not') return !evaluate(node.input, values);
    const left = evaluate(node.left, values); const right = evaluate(node.right, values);
    if (node.op === 'AND') return left && right;
    if (node.op === 'OR') return left || right;
    if (node.op === 'XOR') return left !== right;
    if (node.op === 'NAND') return !(left && right);
    if (node.op === 'NOR') return !(left || right);
    return false;
  }

  function circuitAst() {
    const entries = new Map(gates.map((gate) => [gate.id, gate]));
    const visiting = new Set();
    const resolve = (name) => {
      if (vars.includes(name)) return { type: 'var', name };
      const gate = entries.get(name);
      if (!gate) throw new Error(`Unknown signal ${name}.`);
      if (visiting.has(name)) throw new Error('Gate diagrams cannot contain a feedback loop.');
      visiting.add(name);
      const left = resolve(gate.a); const right = resolve(gate.b);
      visiting.delete(name);
      const normal = { type: 'gate', op: gate.op === 'NAND' ? 'AND' : gate.op === 'NOR' ? 'OR' : gate.op, left, right };
      return gate.op === 'NAND' || gate.op === 'NOR' ? { type: 'not', input: normal } : normal;
    };
    return resolve(gates[gates.length - 1].id);
  }

  function renderGateEditor() {
    const host = byId('logic-gate-editor');
    if (!host) return;
    host.replaceChildren();
    gates.forEach((gate, index) => {
      const row = create('div', { class: 'logic-gate-row' });
      row.append(create('span', { class: 'logic-gate-name' }, gate.id));
      const addSelect = (options, selected, label) => {
        const select = create('select', { 'aria-label': `${gate.id} ${label}` });
        options.forEach((option) => { const item = create('option', { value: option }, option); item.selected = option === selected; select.append(item); });
        return select;
      };
      const sourceOptions = vars.concat(gates.slice(0, index).map((item) => item.id));
      const op = addSelect(operators, gate.op, 'operator');
      const a = addSelect(sourceOptions, gate.a, 'first input');
      const b = addSelect(sourceOptions, gate.b, 'second input');
      [op, a, b].forEach((select) => select.addEventListener('change', () => { gate.op = op.value; gate.a = a.value; gate.b = b.value; syncCircuit(); }));
      row.append(op, a, b);
      const remove = create('button', { type: 'button', class: 'btn btn-sm logic-remove', 'aria-label': `Remove ${gate.id}` }, '×');
      remove.disabled = gates.length === 1;
      remove.addEventListener('click', () => { gates.splice(index, 1); renderGateEditor(); syncCircuit(); });
      row.append(remove); host.append(row);
    });
  }

  function renderDiagram(ast) {
    const host = byId('logic-diagram');
    if (!host) return;
    host.replaceChildren();
    const NS = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 700 300'); svg.setAttribute('aria-hidden', 'true');
    const nodes = []; let leaf = 0;
    const walk = (node, depth) => {
      const item = { node, depth, x: 0, y: 0 };
      nodes.push(item);
      if (node.type === 'var') { item.y = 40 + leaf * 58; leaf += 1; }
      else if (node.type === 'not') { const child = walk(node.input, depth + 1); item.y = child.y; }
      else { const left = walk(node.left, depth + 1); const right = walk(node.right, depth + 1); item.y = (left.y + right.y) / 2; }
      item.x = 640 - depth * 138;
      return item;
    };
    const root = walk(ast, 0);
    const byNode = new Map(nodes.map((item) => [item.node, item]));
    const line = (x1, y1, x2, y2, color) => { const node = document.createElementNS(NS, 'line'); node.setAttribute('x1', x1); node.setAttribute('y1', y1); node.setAttribute('x2', x2); node.setAttribute('y2', y2); node.setAttribute('stroke', color); node.setAttribute('stroke-width', '3'); svg.append(node); };
    nodes.forEach((item) => {
      const children = item.node.type === 'not' ? [item.node.input] : item.node.type === 'gate' ? [item.node.left, item.node.right] : [];
      children.forEach((child) => { const next = byNode.get(child); line(next.x + 42, next.y, item.x - 42, item.y, '#64748b'); });
    });
    nodes.forEach((item) => {
      const value = evaluate(item.node, inputValues());
      const group = document.createElementNS(NS, 'g');
      const box = document.createElementNS(NS, 'rect'); box.setAttribute('x', item.x - 42); box.setAttribute('y', item.y - 20); box.setAttribute('width', '84'); box.setAttribute('height', '40'); box.setAttribute('rx', item.node.type === 'var' ? '20' : '7'); box.setAttribute('fill', value ? '#174c43' : '#182035'); box.setAttribute('stroke', value ? '#6ee7b7' : '#64748b'); box.setAttribute('stroke-width', '2');
      const label = document.createElementNS(NS, 'text'); label.setAttribute('x', item.x); label.setAttribute('y', item.y + 5); label.setAttribute('text-anchor', 'middle'); label.setAttribute('fill', '#eef0fa'); label.setAttribute('font-size', '12'); label.setAttribute('font-family', 'JetBrains Mono, monospace'); label.textContent = item.node.type === 'var' ? item.node.name : item.node.type === 'not' ? 'NOT' : item.node.op;
      group.append(box, label); svg.append(group);
    });
    const output = document.createElementNS(NS, 'text'); output.setAttribute('x', root.x + 58); output.setAttribute('y', root.y + 5); output.setAttribute('fill', '#8b7bff'); output.setAttribute('font-size', '14'); output.setAttribute('font-family', 'JetBrains Mono, monospace'); output.textContent = `Y = ${evaluate(ast, inputValues()) ? 1 : 0}`; svg.append(output);
    host.append(svg);
  }

  function inputValues() { return Object.fromEntries(vars.map((name) => [name, Boolean(byId(`logic-input-${name.toLowerCase()}`)?.checked)])); }
  function renderTruthTable(ast) {
    const host = byId('logic-truth-table'); if (!host) return;
    const referenced = new Set(); astVariables(ast, referenced);
    const used = Array.from(referenced).filter((name) => vars.includes(name));
    const table = create('table'); const head = create('thead'); const hrow = create('tr'); used.concat('Y').forEach((name) => hrow.append(create('th', {}, name))); head.append(hrow); table.append(head);
    const body = create('tbody');
    for (let row = 0; row < 2 ** used.length; row += 1) {
      const values = {}; used.forEach((name, index) => { values[name] = Boolean(row & (1 << (used.length - index - 1))); });
      const tr = create('tr'); used.forEach((name) => tr.append(create('td', { class: values[name] ? 'logic-on' : 'logic-off' }, values[name] ? '1' : '0'))); const result = evaluate(ast, values); tr.append(create('td', { class: result ? 'logic-on' : 'logic-off' }, result ? '1' : '0')); body.append(tr);
    }
    table.append(body); host.replaceChildren(table);
  }
  function updateLive(ast) { const result = evaluate(ast, inputValues()); const output = byId('logic-live-output'); if (output) { output.textContent = `Y = ${result ? 1 : 0}`; output.className = `logic-output ${result ? 'logic-on' : 'logic-off'}`; } }
  function applyAst(ast, message) { activeAst = ast; renderDiagram(ast); renderTruthTable(ast); updateLive(ast); if (message) setStatus('logic-expression-status', message, false); }
  function syncCircuit() { try { const ast = circuitAst(); applyAst(ast); setStatus('logic-gate-status', `Diagram output: Y = ${astExpression(ast)}`, false); } catch (error) { setStatus('logic-gate-status', error.message, true); } }
  function buildExpression() { try { const ast = parseExpression(byId('logic-expression').value); applyAst(ast, `Diagram created: Y = ${astExpression(ast)}`); } catch (error) { setStatus('logic-expression-status', error.message, true); } }

  function formatOhms(value) { return value >= 1e6 ? `${(value / 1e6).toFixed(3)} MΩ` : value >= 1e3 ? `${(value / 1e3).toFixed(3)} kΩ` : `${value.toFixed(value < 10 ? 3 : 2)} Ω`; }
  window.calcParallelTarget = function () {
    const target = Number(byId('pt_target')?.value); const series = byId('pt_series')?.value || 'E24'; const host = byId('pt_result');
    if (!host) return;
    if (!Number.isFinite(target) || target <= 0) { host.textContent = 'Enter a target resistance greater than zero.'; return; }
    const bases = series === 'E12' ? [10, 12, 15, 18, 22, 27, 33, 39, 47, 56, 68, 82] : [10, 11, 12, 13, 15, 16, 18, 20, 22, 24, 27, 30, 33, 36, 39, 43, 47, 51, 56, 62, 68, 75, 82, 91];
    const values = [];
    const targetDecade = Math.floor(Math.log10(target));
    for (let power = targetDecade - 1; power <= targetDecade + 3; power += 1) bases.forEach((base) => values.push(base * 10 ** power));
    const candidates = [];
    for (let i = 0; i < values.length; i += 1) for (let j = i; j < values.length; j += 1) {
      const a = values[i]; const b = values[j];
      if (a <= target || b / a > 20) continue;
      const rt = a * b / (a + b);
      candidates.push({ a, b, rt, error: Math.abs(rt - target) / target * 100, balance: b / a });
    }
    candidates.sort((left, right) => left.error - right.error || left.balance - right.balance || left.b - right.b);
    const table = create('table'); const head = create('thead'); const row = create('tr'); ['R₁', 'R₂', 'Parallel RT', 'Error'].forEach((label) => row.append(create('th', {}, label))); head.append(row); table.append(head); const body = create('tbody');
    candidates.slice(0, 8).forEach((item) => { const tr = create('tr'); [formatOhms(item.a), formatOhms(item.b), formatOhms(item.rt), `${item.error.toFixed(2)}%`].forEach((value) => tr.append(create('td', {}, value))); body.append(tr); }); table.append(body); host.replaceChildren(table, create('p', { class: 'note' }, `Closest balanced ${series} pairs near ${formatOhms(target)}. Nominal values only; include tolerance, power rating, and temperature coefficient in the final design.`));
  };

  function init() {
    if (!byId('sec-digital')) return;
    renderGateEditor(); buildExpression();
    vars.forEach((name) => byId(`logic-input-${name.toLowerCase()}`)?.addEventListener('change', () => { if (activeAst) { renderDiagram(activeAst); updateLive(activeAst); } }));
    byId('logic-build-expression')?.addEventListener('click', buildExpression);
    byId('logic-example')?.addEventListener('click', () => { byId('logic-expression').value = '(A XOR B) AND (NOT C)'; buildExpression(); });
    byId('logic-add-gate')?.addEventListener('click', () => { gates.push({ id: `G${gates.length + 1}`, op: 'OR', a: gates[gates.length - 1].id, b: 'C' }); renderGateEditor(); syncCircuit(); });
    byId('logic-extract-gates')?.addEventListener('click', () => { try { const ast = circuitAst(); byId('logic-expression').value = astExpression(ast); applyAst(ast, `Expression extracted from gate diagram: Y = ${astExpression(ast)}`); } catch (error) { setStatus('logic-gate-status', error.message, true); } });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
}());
