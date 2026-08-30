import { useMemo, useState } from "react";

type Row = Record<string, boolean> & { output: boolean };

function evaluate(expression: string, values: Record<string, boolean>) {
  const tokens = expression.toUpperCase().match(/AND|OR|NOT|[A-Z]|[()'·+]/g) ?? [];
  let cursor = 0;
  const peek = () => tokens[cursor];
  const consume = (token?: string) => {
    if (!token || peek() !== token) return false;
    cursor += 1;
    return true;
  };
  const primary = (): boolean => {
    if (consume("(")) { const value = disjunction(); consume(")"); return value; }
    const name = peek();
    if (!name || !/^[A-Z]$/.test(name)) return false;
    cursor += 1;
    const value = Boolean(values[name]);
    return consume("'") ? !value : value;
  };
  const negation = (): boolean => consume("NOT") ? !negation() : primary();
  const conjunction = (): boolean => { let value = negation(); while (consume("AND") || consume("·")) value = value && negation(); return value; };
  const disjunction = (): boolean => { let value = conjunction(); while (consume("OR") || consume("+")) value = value || conjunction(); return value; };
  const output = disjunction();
  return cursor === tokens.length ? output : false;
}

export function BooleanLogicSuite() {
  const [expression, setExpression] = useState("(A AND B) OR (NOT C)");
  const [mode, setMode] = useState<"expression" | "gates">("expression");
  const variables = useMemo(() => [...new Set(expression.toUpperCase().match(/[A-Z]/g) ?? [])].sort(), [expression]);
  const rows = useMemo<Row[]>(() => Array.from({ length: 2 ** variables.length }, (_, index) => {
    const values = Object.fromEntries(variables.map((name, position) => [name, Boolean(index & (1 << (variables.length - position - 1)))]));
    return { ...values, output: evaluate(expression, values) };
  }), [expression, variables]);

  return (
    <section className="card-surface space-y-5 p-6" aria-labelledby="boolean-suite-title">
      <div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Logic laboratory</p><h2 id="boolean-suite-title" className="font-display text-2xl font-bold">Boolean Logic Suite</h2></div><div className="flex rounded-lg border border-[var(--border)] p-1 text-xs"><button type="button" className={`rounded px-3 py-1 ${mode === "expression" ? "bg-[var(--accent-soft)] text-[var(--accent)]" : ""}`} onClick={() => setMode("expression")}>Expression</button><button type="button" className={`rounded px-3 py-1 ${mode === "gates" ? "bg-[var(--accent-soft)] text-[var(--accent)]" : ""}`} onClick={() => setMode("gates")}>Gate canvas</button></div></div>
      {mode === "expression" ? <>
        <label className="block text-sm font-semibold">Boolean expression<input className="mt-2 w-full rounded-lg border border-[var(--border)] bg-black/20 px-3 py-2 font-mono text-sm" value={expression} onChange={(event) => setExpression(event.target.value)} /></label>
        <div className="overflow-x-auto rounded-xl border border-[var(--border)]"><table className="w-full min-w-[360px] text-left text-sm"><thead><tr>{variables.map((name) => <th key={name} className="border-b border-[var(--border)] p-3">{name}</th>)}<th className="border-b border-[var(--border)] p-3 text-[var(--accent)]">OUT</th></tr></thead><tbody>{rows.map((row, index) => <tr key={index}>{variables.map((name) => <td key={name} className="border-b border-[var(--border)] p-3">{row[name] ? "1" : "0"}</td>)}<td className="border-b border-[var(--border)] p-3 font-bold text-[var(--accent)]">{row.output ? "1" : "0"}</td></tr>)}</tbody></table></div>
        <p className="text-sm text-[var(--muted)]">The table enumerates all 2<sup>{variables.length}</sup> input states. A production extension can feed this same typed truth table into Quine–McCluskey and SVG gate layout.</p>
      </> : <div className="grid gap-3 md:grid-cols-3"><div className="rounded-xl border border-[var(--border)] p-4 text-center">A <span className="text-[var(--accent)]">AND</span> B</div><div className="rounded-xl border border-[var(--border)] p-4 text-center">NOT C</div><div className="rounded-xl border border-[var(--accent)] bg-[var(--accent-soft)] p-4 text-center font-bold">OR output</div></div>}
    </section>
  );
}

export default BooleanLogicSuite;
