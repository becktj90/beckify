import { useEffect, useMemo, useState } from "react";

const BOM = [
  ["Industrial relay controller", "24 VDC, 16-channel", "Automation Direct"],
  ["Safety interlock relay", "Dual-channel monitored", "Phoenix Contact"],
  ["Pressure transducer", "0–3000 psi, 4–20 mA", "WIKA"],
  ["Field actuator harness", "Shielded, keyed circular", "Custom harness"],
];

export function LC934Dashboard() {
  const [filter, setFilter] = useState("");
  const [tick, setTick] = useState(0);
  useEffect(() => { const timer = window.setInterval(() => setTick((value) => value + 1), 1000); return () => window.clearInterval(timer); }, []);
  const pressure = 182 + Math.sin(tick / 4) * 3;
  const temperature = 71 + Math.sin(tick / 7) * 1.5;
  const rows = useMemo(() => BOM.filter((row) => row.some((value) => value.toLowerCase().includes(filter.toLowerCase()))), [filter]);

  return <section className="card-surface space-y-5 p-6" aria-labelledby="lc934-title">
    <div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Project telemetry</p><h2 id="lc934-title" className="font-display text-2xl font-bold">LC-9/34 Launch Complex Control System</h2><p className="mt-2 text-sm text-[var(--muted)]">A living build log for the industrial control stack: sensors, relays, power distribution, and field actuators.</p></div>
    <div className="grid gap-3 sm:grid-cols-4">{[["Pressure", `${pressure.toFixed(1)} psi`], ["Temperature", `${temperature.toFixed(1)} °F`], ["Valve A", "READY"], ["Power bus", "24.1 VDC"]].map(([label, value]) => <div className="rounded-xl border border-[var(--border)] bg-black/20 p-4" key={label}><span className="text-xs text-[var(--muted)]">{label}</span><strong className="mt-2 block text-lg text-[var(--accent)]">{value}</strong></div>)}</div>
    <div className="grid gap-5 lg:grid-cols-[1fr_1.25fr]">
      <div className="rounded-xl border border-[var(--border)] bg-[#07111b] p-4"><h3 className="mb-3 font-semibold">Signal flow</h3><svg viewBox="0 0 520 190" className="w-full" role="img" aria-label="Signal flow from sensors to controller, relays, and actuators"><path d="M30 95H140M190 95H315M365 95H490" stroke="#6ee7b7" strokeWidth="4" strokeDasharray="10 8" /><g fill="#12283a" stroke="#8b7bff" strokeWidth="2"><rect x="20" y="65" width="120" height="60" rx="10" /><rect x="140" y="65" width="100" height="60" rx="10" /><rect x="315" y="65" width="100" height="60" rx="10" /><rect x="430" y="65" width="80" height="60" rx="10" /></g><g fill="#eef0fa" fontSize="13" textAnchor="middle"><text x="80" y="100">Sensors</text><text x="190" y="100">MCU</text><text x="365" y="100">Relays</text><text x="470" y="100">Actuators</text></g></svg></div>
      <div className="rounded-xl border border-[var(--border)] p-4"><div className="mb-3 flex items-center justify-between gap-3"><h3 className="font-semibold">Bill of materials</h3><input aria-label="Filter bill of materials" className="w-40 rounded border border-[var(--border)] bg-black/20 px-2 py-1 text-xs" placeholder="Filter" value={filter} onChange={(event) => setFilter(event.target.value)} /></div><div className="overflow-x-auto"><table className="w-full text-left text-sm"><thead><tr><th className="border-b border-[var(--border)] p-2">Component</th><th className="border-b border-[var(--border)] p-2">Spec</th><th className="border-b border-[var(--border)] p-2">Source</th></tr></thead><tbody>{rows.map((row) => <tr key={row[0]}>{row.map((value) => <td className="border-b border-[var(--border)] p-2 text-[var(--muted)]" key={value}>{value}</td>)}</tr>)}</tbody></table></div></div>
    </div>
  </section>;
}

export default LC934Dashboard;
