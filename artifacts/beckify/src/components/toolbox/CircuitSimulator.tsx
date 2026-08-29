import { useEffect, useRef, useState } from "react";

interface SolverResult {
  sourceVoltage: number;
  resistance: number;
  current: number;
  power: number;
}

const DEFAULT_RESULT: SolverResult = { sourceVoltage: 12, resistance: 100, current: 0.12, power: 1.44 };

export function CircuitSimulator() {
  const [voltage, setVoltage] = useState(12);
  const [resistance, setResistance] = useState(100);
  const [result, setResult] = useState(DEFAULT_RESULT);
  const [running, setRunning] = useState(true);
  const workerRef = useRef<Worker | null>(null);

  useEffect(() => {
    const worker = new Worker(new URL("./circuitSolver.worker.ts", import.meta.url), { type: "module" });
    worker.onmessage = (event: MessageEvent<SolverResult>) => setResult(event.data);
    workerRef.current = worker;
    return () => worker.terminate();
  }, []);

  useEffect(() => {
    if (running) workerRef.current?.postMessage({ resistance, sourceVoltage: voltage });
  }, [resistance, running, voltage]);

  return (
    <section className="card-surface space-y-5 p-6" aria-labelledby="circuit-simulator-title">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">MNA workbench</p>
        <h2 id="circuit-simulator-title" className="font-display text-2xl font-bold">Circuit Simulator</h2>
        <p className="mt-2 text-sm text-[var(--muted)]">A responsive DC circuit sandbox. Matrix solving runs in a Web Worker so controls stay responsive.</p>
      </div>
      <div className="grid gap-5 lg:grid-cols-[1fr_1.4fr]">
        <div className="space-y-5 rounded-xl border border-[var(--border)] bg-black/20 p-4">
          <label className="block text-sm">Source voltage <strong>{voltage.toFixed(1)} V</strong>
            <input className="mt-3 w-full accent-[var(--accent)]" type="range" min="0" max="48" step="0.1" value={voltage} onChange={(event) => setVoltage(Number(event.target.value))} />
          </label>
          <label className="block text-sm">Resistance <strong>{resistance.toFixed(0)} Ω</strong>
            <input className="mt-3 w-full accent-[var(--accent)]" type="range" min="1" max="1000" step="1" value={resistance} onChange={(event) => setResistance(Number(event.target.value))} />
          </label>
          <button type="button" className="rounded-lg border border-[var(--border)] px-3 py-2 text-sm" onClick={() => setRunning((value) => !value)}>{running ? "Pause solver" : "Resume solver"}</button>
        </div>
        <div className="rounded-xl border border-[var(--border)] bg-[#07111b] p-4">
          <svg viewBox="0 0 520 230" className="h-auto w-full" role="img" aria-label="Voltage source connected to resistor and ground">
            <defs><linearGradient id="wire-gradient" x1="0" x2="1"><stop stopColor="#4f8bff" /><stop offset="1" stopColor="#6ee7b7" /></linearGradient></defs>
            <path d="M80 115H145M215 115H375V175H80V115M80 115V175" fill="none" stroke="url(#wire-gradient)" strokeWidth="5" strokeLinecap="round" />
            <path d="M145 90V140M215 90V140" stroke="#8b7bff" strokeWidth="7" />
            <rect x="145" y="92" width="70" height="46" rx="8" fill="#162334" stroke="#8b7bff" strokeWidth="2" />
            <text x="180" y="121" textAnchor="middle" fill="#eef0fa" fontSize="15">R</text>
            <circle cx="80" cy="115" r="10" fill="#6ee7b7" /><path d="M350 175h50M358 183h34M366 191h18" stroke="#eef0fa" strokeWidth="3" />
            <text x="80" y="83" textAnchor="middle" fill="#eef0fa" fontSize="15">{voltage.toFixed(1)} V</text>
            <text x="380" y="105" fill="#6ee7b7" fontSize="14">I = {result.current.toFixed(3)} A</text>
          </svg>
          <div className="mt-3 grid grid-cols-3 gap-2 text-center text-sm">
            <div><strong className="block text-lg text-[var(--accent)]">{result.current.toFixed(3)}</strong>A</div>
            <div><strong className="block text-lg text-[var(--accent)]">{result.power.toFixed(2)}</strong>W</div>
            <div><strong className="block text-lg text-[var(--accent)]">{result.sourceVoltage.toFixed(1)}</strong>V node</div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default CircuitSimulator;
