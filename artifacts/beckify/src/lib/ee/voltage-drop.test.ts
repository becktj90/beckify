import assert from "node:assert/strict";
import test from "node:test";
import {
  VOLTAGE_DROP_DEFAULTS,
  computeVoltageDrop,
  type VoltageDropFormValues,
} from "./voltage-drop.ts";

function buildValues(
  overrides: Partial<VoltageDropFormValues>
): VoltageDropFormValues {
  return { ...VOLTAGE_DROP_DEFAULTS, ...overrides };
}

test("computes three-phase voltage drop from kW load", () => {
  const computation = computeVoltageDrop(
    buildValues({
      phase: "3ph",
      voltage: "480",
      loadUnit: "kw",
      loadValue: "30",
      powerFactor: "0.9",
      distance: "75",
      distanceUnit: "m",
      cableUnit: "mm2",
      cableSize: "35",
      limitPercent: "3",
    })
  );

  assert.ok(computation.result);
  assert.equal(computation.error, undefined);
  assert.ok(Math.abs(computation.result.currentA - 40.093768) < 0.0001);
  assert.ok(Math.abs(computation.result.voltageDropV - 2.565625) < 0.0001);
  assert.ok(Math.abs(computation.result.voltageDropPercent - 0.534505) < 0.0001);
  assert.equal(computation.result.limitExceeded, false);
});

test("computes dc voltage drop from direct current input", () => {
  const computation = computeVoltageDrop(
    buildValues({
      phase: "dc",
      voltage: "125",
      loadUnit: "a",
      loadValue: "80",
      powerFactor: "1",
      distance: "200",
      distanceUnit: "ft",
      cableUnit: "awg",
      cableSize: "2",
      limitPercent: "5",
    })
  );

  assert.ok(computation.result);
  assert.equal(computation.result.conductorValueLabel, "Rc");
  assert.ok(Math.abs(computation.result.voltageDropV - 5.001079) < 0.0001);
  assert.ok(Math.abs(computation.result.receivingVoltageV - 119.998921) < 0.0001);
});

test("rejects invalid power factor for AC real-power loads", () => {
  const computation = computeVoltageDrop(
    buildValues({
      phase: "1ph",
      voltage: "240",
      loadUnit: "kw",
      loadValue: "12",
      powerFactor: "0",
      distance: "60",
      distanceUnit: "m",
      cableUnit: "mm2",
      cableSize: "16",
      limitPercent: "3",
    })
  );

  assert.equal(
    computation.error,
    "Power factor must be between 0 and 1 for kW and hp loads"
  );
});
