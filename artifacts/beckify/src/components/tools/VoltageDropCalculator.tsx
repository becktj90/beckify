import { useMemo } from "react";
import {
  AlertTriangle,
  Cable,
  Calculator,
  ChevronDown,
  CircleAlert,
  Gauge,
  Sigma,
  Zap,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import type { Values } from "@/lib/ee/types";
import {
  VOLTAGE_DROP_AWG_OPTIONS,
  VOLTAGE_DROP_DEFAULTS,
  VOLTAGE_DROP_MM2_OPTIONS,
  computeVoltageDrop,
  type VoltageDropCableUnit,
  type VoltageDropDistanceUnit,
  type VoltageDropFormValues,
  type VoltageDropLoadUnit,
  type VoltageDropPhase,
} from "@/lib/ee/voltage-drop";
import { fmt } from "@/lib/ee/format";

interface VoltageDropCalculatorProps {
  values?: Values;
  onValuesChange?: (values: Values) => void;
}

const phaseOptions: { value: VoltageDropPhase; label: string }[] = [
  { value: "1ph", label: "1-Phase AC" },
  { value: "3ph", label: "3-Phase AC" },
  { value: "dc", label: "DC" },
];

const loadUnitOptions: { value: VoltageDropLoadUnit; label: string }[] = [
  { value: "a", label: "Current (A)" },
  { value: "kw", label: "Real Power (kW)" },
  { value: "kva", label: "Apparent Power (kVA)" },
  { value: "hp", label: "Horsepower (hp)" },
];

const distanceUnitOptions: { value: VoltageDropDistanceUnit; label: string }[] = [
  { value: "m", label: "Meters" },
  { value: "ft", label: "Feet" },
];

const cableUnitOptions: { value: VoltageDropCableUnit; label: string }[] = [
  { value: "mm2", label: "Metric (mm²)" },
  { value: "awg", label: "AWG / kcmil" },
];

function normalizeValues(values?: Values): VoltageDropFormValues {
  return {
    ...VOLTAGE_DROP_DEFAULTS,
    ...(values ?? {}),
  } as VoltageDropFormValues;
}

function updateValues(
  current: VoltageDropFormValues,
  updates: Partial<VoltageDropFormValues>,
  onValuesChange?: (values: Values) => void
) {
  onValuesChange?.({ ...current, ...updates });
}

function InputBlock({
  label,
  value,
  onChange,
  type = "number",
  unit,
  help,
  min,
  max,
  step,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: "number" | "text";
  unit?: string;
  help?: string;
  min?: number;
  max?: number;
  step?: string;
}) {
  return (
    <label className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        <span className="text-sm font-medium text-[var(--foreground)]">{label}</span>
        {unit && <span className="text-xs font-mono text-[var(--muted)]">{unit}</span>}
      </div>
      <Input
        type={type}
        value={value}
        min={min}
        max={max}
        step={step ?? "any"}
        onChange={(event) => onChange(event.target.value)}
        className="h-11 border-[var(--border)] bg-[var(--background)]"
      />
      {help && <p className="text-xs text-[var(--muted)]">{help}</p>}
    </label>
  );
}

function SelectBlock<T extends string>({
  label,
  value,
  onChange,
  options,
  help,
}: {
  label: string;
  value: T;
  onChange: (value: T) => void;
  options: { value: T; label: string }[];
  help?: string;
}) {
  return (
    <label className="space-y-2">
      <span className="text-sm font-medium text-[var(--foreground)]">{label}</span>
      <select
        value={value}
        onChange={(event) => onChange(event.target.value as T)}
        className="h-11 w-full rounded-xl border border-[var(--border)] bg-[var(--background)] px-3 text-sm text-[var(--foreground)] outline-none transition focus:border-[var(--accent)] focus:ring-2 focus:ring-[var(--accent-ring)]"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
      {help && <p className="text-xs text-[var(--muted)]">{help}</p>}
    </label>
  );
}

function MetricCard({
  label,
  value,
  unit,
  icon: Icon,
  tone = "accent",
}: {
  label: string;
  value: string;
  unit: string;
  icon: typeof Zap;
  tone?: "accent" | "warning";
}) {
  const toneClasses =
    tone === "warning"
      ? "border-amber-500/30 bg-amber-500/10 text-amber-200"
      : "border-[var(--border)] bg-[var(--surface)] text-[var(--foreground)]";

  return (
    <div className={`rounded-2xl border p-4 ${toneClasses}`}>
      <div className="mb-3 flex items-center gap-2 text-xs uppercase tracking-[0.2em] text-[var(--muted)]">
        <Icon className="h-4 w-4" />
        <span>{label}</span>
      </div>
      <div className="flex items-end gap-2">
        <span className="text-3xl font-semibold">{value}</span>
        <span className="pb-1 text-sm text-[var(--muted)]">{unit}</span>
      </div>
    </div>
  );
}

export function VoltageDropCalculator({
  values,
  onValuesChange,
}: VoltageDropCalculatorProps) {
  const formValues = normalizeValues(values);
  const computation = useMemo(() => computeVoltageDrop(formValues), [formValues]);
  const cableOptions =
    formValues.cableUnit === "mm2" ? VOLTAGE_DROP_MM2_OPTIONS : VOLTAGE_DROP_AWG_OPTIONS;
  const result = computation.result;
  const showPowerFactor =
    formValues.phase !== "dc" &&
    (formValues.loadUnit === "kw" || formValues.loadUnit === "hp");

  return (
    <section className="grid gap-6 xl:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)]">
      <aside className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 md:p-6">
        <div className="mb-6 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.28em] text-[var(--accent)]">
              Input Panel
            </p>
            <h2 className="mt-2 text-2xl font-semibold text-[var(--foreground)]">
              AC/DC Voltage Drop
            </h2>
            <p className="mt-2 text-sm text-[var(--muted)]">
              Reactive conductor drop calculator with direct formula substitution.
            </p>
          </div>
          <div className="rounded-2xl border border-[var(--border)] bg-[var(--background)] p-3 text-[var(--accent)]">
            <Cable className="h-6 w-6" />
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <SelectBlock
            label="Phase model"
            value={formValues.phase}
            options={phaseOptions}
            onChange={(phase) =>
              updateValues(
                formValues,
                {
                  phase,
                  powerFactor: phase === "dc" ? "1" : formValues.powerFactor || "0.9",
                },
                onValuesChange
              )
            }
          />
          <InputBlock
            label="Nominal voltage"
            value={formValues.voltage}
            unit="V"
            min={0}
            onChange={(voltage) => updateValues(formValues, { voltage }, onValuesChange)}
          />
          <SelectBlock
            label="Load basis"
            value={formValues.loadUnit}
            options={loadUnitOptions}
            onChange={(loadUnit) => updateValues(formValues, { loadUnit }, onValuesChange)}
            help="Supports current, real power, apparent power, or horsepower."
          />
          <InputBlock
            label="Load value"
            value={formValues.loadValue}
            unit={
              formValues.loadUnit === "a"
                ? "A"
                : formValues.loadUnit === "kw"
                  ? "kW"
                  : formValues.loadUnit === "kva"
                    ? "kVA"
                    : "hp"
            }
            min={0}
            onChange={(loadValue) => updateValues(formValues, { loadValue }, onValuesChange)}
          />
          <InputBlock
            label="Power factor"
            value={formValues.powerFactor}
            unit="pf"
            min={0.01}
            max={1}
            step="0.01"
            onChange={(powerFactor) =>
              updateValues(formValues, { powerFactor }, onValuesChange)
            }
            help={
              showPowerFactor
                ? "Required for AC kW and hp loads."
                : "Not used for DC, kVA, or direct-current inputs."
            }
          />
          <InputBlock
            label="Voltage-drop limit"
            value={formValues.limitPercent}
            unit="%"
            min={0.1}
            step="0.1"
            onChange={(limitPercent) =>
              updateValues(formValues, { limitPercent }, onValuesChange)
            }
          />
          <InputBlock
            label="One-way distance"
            value={formValues.distance}
            unit={formValues.distanceUnit}
            min={0}
            onChange={(distance) => updateValues(formValues, { distance }, onValuesChange)}
          />
          <SelectBlock
            label="Distance unit"
            value={formValues.distanceUnit}
            options={distanceUnitOptions}
            onChange={(distanceUnit) =>
              updateValues(formValues, { distanceUnit }, onValuesChange)
            }
          />
          <SelectBlock
            label="Cable sizing system"
            value={formValues.cableUnit}
            options={cableUnitOptions}
            onChange={(cableUnit) =>
              updateValues(
                formValues,
                {
                  cableUnit,
                  cableSize:
                    cableUnit === "mm2"
                      ? VOLTAGE_DROP_MM2_OPTIONS[6]
                      : VOLTAGE_DROP_AWG_OPTIONS[4],
                },
                onValuesChange
              )
            }
          />
          <SelectBlock
            label="Cable size"
            value={formValues.cableSize}
            options={cableOptions.map((option) => ({
              value: option,
              label: formValues.cableUnit === "mm2" ? `${option} mm²` : option,
            }))}
            onChange={(cableSize) => updateValues(formValues, { cableSize }, onValuesChange)}
          />
        </div>
      </aside>

      <section className="space-y-6 rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 md:p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.28em] text-[var(--accent)]">
              Results Panel
            </p>
            <h3 className="mt-2 text-2xl font-semibold text-[var(--foreground)]">
              Live engineering output
            </h3>
            <p className="mt-2 text-sm text-[var(--muted)]">
              Uses the selected conductor size and distance to resolve voltage loss in real time.
            </p>
          </div>
          {result && (
            <div className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 text-right">
              <p className="text-xs uppercase tracking-[0.2em] text-[var(--muted)]">
                Active model
              </p>
              <p className="mt-1 text-sm font-medium text-[var(--foreground)]">
                {result.phaseLabel} · {result.cableLabel}
              </p>
            </div>
          )}
        </div>

        {computation.error ? (
          <div className="rounded-2xl border border-red-500/30 bg-red-500/10 p-4">
            <div className="flex items-center gap-2 text-sm font-semibold text-red-300">
              <CircleAlert className="h-4 w-4" />
              Validation required
            </div>
            <p className="mt-2 text-sm text-red-200/90">{computation.error}</p>
          </div>
        ) : (
          result && (
            <>
              <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                <MetricCard
                  label="Load current"
                  value={fmt(result.currentA, 3)}
                  unit="A"
                  icon={Gauge}
                />
                <MetricCard
                  label="Voltage drop"
                  value={fmt(result.voltageDropV, 3)}
                  unit="V"
                  icon={Zap}
                />
                <MetricCard
                  label="Drop percentage"
                  value={fmt(result.voltageDropPercent, 3)}
                  unit="%"
                  icon={Sigma}
                  tone={result.limitExceeded ? "warning" : "accent"}
                />
                <MetricCard
                  label="Receiving voltage"
                  value={fmt(result.receivingVoltageV, 3)}
                  unit="V"
                  icon={Calculator}
                />
              </div>

              <div
                className={`rounded-2xl border p-4 ${
                  result.limitExceeded
                    ? "border-amber-500/30 bg-amber-500/10"
                    : "border-emerald-500/30 bg-emerald-500/10"
                }`}
              >
                <div className="flex items-start gap-3">
                  <AlertTriangle
                    className={`mt-0.5 h-5 w-5 ${
                      result.limitExceeded ? "text-amber-300" : "text-emerald-300"
                    }`}
                  />
                  <div>
                    <p
                      className={`text-sm font-semibold ${
                        result.limitExceeded ? "text-amber-200" : "text-emerald-200"
                      }`}
                    >
                      {result.limitExceeded
                        ? `Voltage drop exceeds the ${fmt(result.limitPercent, 2)}% design target.`
                        : `Voltage drop stays within the ${fmt(result.limitPercent, 2)}% design target.`}
                    </p>
                    <p className="mt-1 text-sm text-[var(--muted)]">
                      {result.conductorValueLabel} = {fmt(result.conductorValuePer1000, 6)}{" "}
                      {result.conductorUnitLabel} · conductor area = {fmt(result.areaMm2, 3)} mm²
                    </p>
                  </div>
                </div>
              </div>

              <div className="grid gap-4 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
                <div className="rounded-2xl border border-[var(--border)] bg-[var(--background)] p-4">
                  <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--accent)]">
                    Formula
                  </p>
                  <p className="mt-3 font-mono text-sm text-[var(--foreground)]">
                    {result.formula}
                  </p>
                  <p className="mt-3 font-mono text-xs leading-6 text-[var(--muted)]">
                    {result.formulaSubstitution}
                  </p>
                </div>

                <div className="rounded-2xl border border-[var(--border)] bg-[var(--background)] p-4">
                  <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--accent)]">
                    Assumptions
                  </p>
                  <ul className="mt-3 space-y-2 text-sm text-[var(--muted)]">
                    {result.assumptions.map((assumption) => (
                      <li key={assumption} className="flex gap-2">
                        <span className="mt-1 h-1.5 w-1.5 rounded-full bg-[var(--accent)]" />
                        <span>{assumption}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              <details className="group rounded-2xl border border-[var(--border)] bg-[var(--background)] p-4">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--accent)]">
                      View step-by-step formula
                    </p>
                    <p className="mt-1 text-sm text-[var(--muted)]">
                      Exact substitutions for current, conductor impedance, voltage drop, and delivered voltage.
                    </p>
                  </div>
                  <ChevronDown className="h-5 w-5 text-[var(--muted)] transition group-open:rotate-180" />
                </summary>

                <div className="mt-4 space-y-3">
                  {result.steps.map((step) => (
                    <div
                      key={step.label}
                      className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-4"
                    >
                      <div className="flex flex-wrap items-center justify-between gap-3">
                        <p className="text-sm font-semibold text-[var(--foreground)]">
                          {step.label}
                        </p>
                        <p className="text-sm font-semibold text-[var(--accent)]">
                          {fmt(step.value, 6)} {step.unit}
                        </p>
                      </div>
                      <p className="mt-2 font-mono text-xs leading-6 text-[var(--muted)]">
                        {step.expression}
                      </p>
                      {step.note && (
                        <p className="mt-2 text-xs text-[var(--muted)]">{step.note}</p>
                      )}
                    </div>
                  ))}
                </div>
              </details>
            </>
          )
        )}
      </section>
    </section>
  );
}
