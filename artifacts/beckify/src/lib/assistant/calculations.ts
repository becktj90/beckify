export type CalculationRequest = { tool: "ohms-law" | "voltage-drop" | "conduit-fill" | "power"; inputs: Record<string, number> };
export type CalculationResult = { tool: CalculationRequest["tool"]; values: Record<string, number>; units: Record<string, string>; explanation: string };

const finite = (value: unknown, name: string) => { const number = Number(value); if (!Number.isFinite(number)) throw new Error(`${name} must be a finite number`); return number; };

export function executeCalculation(request: CalculationRequest): CalculationResult {
  const i = request.inputs;
  if (request.tool === "ohms-law") {
    const voltage = i.voltage ?? (i.current !== undefined && i.resistance !== undefined ? finite(i.current, "current") * finite(i.resistance, "resistance") : undefined);
    const current = i.current ?? (i.voltage !== undefined && i.resistance !== undefined ? finite(i.voltage, "voltage") / finite(i.resistance, "resistance") : undefined);
    const resistance = i.resistance ?? (i.voltage !== undefined && i.current !== undefined ? finite(i.voltage, "voltage") / finite(i.current, "current") : undefined);
    if (voltage === undefined || current === undefined || resistance === undefined) throw new Error("Provide any two of voltage, current, or resistance");
    const v = finite(voltage, "voltage"), a = finite(current, "current"), r = finite(resistance, "resistance");
    return { tool: request.tool, values: { voltage: v, current: a, resistance: r, power: v * a }, units: { voltage: "V", current: "A", resistance: "Ω", power: "W" }, explanation: "Ohm's law is V = I × R; power follows from P = V × I." };
  }
  if (request.tool === "power") {
    const voltage = finite(i.voltage, "voltage"); const current = finite(i.current, "current");
    return { tool: request.tool, values: { power: voltage * current }, units: { power: "W" }, explanation: "For a DC or resistive load, power is P = V × I." };
  }
  if (request.tool === "voltage-drop") {
    const current = finite(i.current, "current"); const resistance = finite(i.resistance, "resistance"); const length = finite(i.length, "length"); const conductors = i.conductors === undefined ? 2 : finite(i.conductors, "conductors");
    const drop = current * resistance * length * conductors;
    return { tool: request.tool, values: { drop }, units: { drop: "V" }, explanation: "This quick check uses ΔV = I × R × path length. Confirm conductor impedance and phase topology in the full calculator." };
  }
  const fillArea = finite(i.conductorArea, "conductorArea") * finite(i.conductorCount, "conductorCount"); const conduitArea = finite(i.conduitArea, "conduitArea");
  return { tool: request.tool, values: { fillPercent: (fillArea / conduitArea) * 100 }, units: { fillPercent: "%" }, explanation: "Raceway fill is the conductor area divided by the usable conduit area." };
}

export function inferCalculation(query: string): CalculationRequest | null {
  const numbers = [...query.matchAll(/(\d+(?:\.\d+)?)\s*(v|a|amps?|ohms?|ω|ft|feet|w|watts?)/gi)].map((match) => [Number(match[1]), match[2].toLowerCase()] as const);
  if (numbers.length < 2) return null;
  const inputs: Record<string, number> = {};
  numbers.forEach(([value, unit]) => { if (unit === "v") inputs.voltage = value; else if (unit === "a" || unit.startsWith("amp")) inputs.current = value; else if (unit === "w" || unit.startsWith("watt")) inputs.power = value; else if (unit === "ft" || unit === "feet") inputs.length = value; else inputs.resistance = value; });
  if (/ohm|voltage|current|resistance/i.test(query) && inputs.voltage !== undefined && inputs.current !== undefined && inputs.resistance === undefined) return { tool: "ohms-law", inputs };
  if (/power|watt/i.test(query) && inputs.voltage !== undefined && inputs.current !== undefined) return { tool: "power", inputs };
  return null;
}
