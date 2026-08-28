import assert from "node:assert/strict";
import test from "node:test";
import {
  computeVoltageDrop,
  computeConduitFill,
  computeLightingVdOptimizer,
  computeMinWireSize,
} from "./conductors.ts";
import type { ResultRow } from "./format.ts";

/** Pulls one result row's value out by a substring of its label. */
function rowValue(rows: ResultRow[], labelFragment: string): string {
  const row = rows.find((r) => r.label.toLowerCase().includes(labelFragment.toLowerCase()));
  assert.ok(row, `no row matching "${labelFragment}" in ${rows.map((r) => r.label).join(", ")}`);
  return String(row.value);
}

function expectRows(result: ReturnType<typeof computeVoltageDrop>): ResultRow[] {
  assert.equal(result.error, undefined, `unexpected error: ${result.error}`);
  assert.ok(result.rows, "expected rows");
  return result.rows;
}

/* ── Voltage drop ─────────────────────────────────────────────────────────
   These previously reported a 1,172 V drop on a 240 V circuit: the one-way
   distance was doubled before a formula that already accounts for the return
   path, and the resulting volts were then multiplied by the supply voltage as
   though they were a ratio. */

test("single-phase voltage drop matches the hand calculation", () => {
  // VD = 2 x 12.9 x 100 A x 100 ft / 105,600 cmil = 2.443 V on 240 V = 1.02 %
  const rows = expectRows(
    computeVoltageDrop({
      phase: "1ph",
      voltage: "240",
      current: "100",
      distance: "100",
      wireSize: "1/0",
    }),
  );
  assert.ok(Math.abs(Number(rowValue(rows, "Voltage Drop %")) - 1.02) < 0.02);
  assert.ok(Math.abs(parseFloat(rowValue(rows, "Voltage Drop")) - 2.443) < 0.01);
});

test("three-phase voltage drop uses sqrt(3), not 2", () => {
  // VD = 1.732 x 12.9 x 100 x 100 / 105,600 = 2.116 V on 480 V = 0.44 %
  const rows = expectRows(
    computeVoltageDrop({
      phase: "3ph",
      voltage: "480",
      current: "100",
      distance: "100",
      wireSize: "1/0",
    }),
  );
  assert.ok(Math.abs(parseFloat(rowValue(rows, "Voltage Drop")) - 2.116) < 0.01);
  assert.ok(Math.abs(Number(rowValue(rows, "Voltage Drop %")) - 0.44) < 0.02);
});

test("voltage at load never exceeds the supply voltage", () => {
  const rows = expectRows(
    computeVoltageDrop({
      phase: "1ph",
      voltage: "240",
      current: "100",
      distance: "100",
      wireSize: "1/0",
    }),
  );
  const atLoad = parseFloat(rowValue(rows, "Voltage at Load").replace(/,/g, ""));
  assert.ok(atLoad > 0 && atLoad < 240, `voltage at load was ${atLoad}`);
});

test("aluminum drops more than copper for the same run", () => {
  const base = { phase: "1ph", voltage: "240", current: "100", distance: "100", wireSize: "1/0" };
  const cu = parseFloat(rowValue(expectRows(computeVoltageDrop(base)), "Voltage Drop"));
  const al = parseFloat(
    rowValue(expectRows(computeVoltageDrop({ ...base, material: "al" })), "Voltage Drop"),
  );
  assert.ok(al > cu, `aluminum ${al} should exceed copper ${cu}`);
});

/* ── Conduit fill ─────────────────────────────────────────────────────────
   This previously treated the pre-computed 40%-fill column as the total
   internal area and then discounted it again, and used 31% for three or more
   conductors where NEC Ch.9 Table 1 calls for 40%. */

test("conduit fill applies the Table 1 limit to the full internal area", () => {
  // 3 x #12 THHN = 0.0399 in2 in 1/2" EMT (0.304 in2). 40% allows 0.1216 in2.
  const rows = expectRows(
    computeConduitFill({ conductorCount: "3", wireSize: "12", conduitSize: "1/2" }),
  );
  assert.equal(rowValue(rows, "Fill Limit"), "40%");
  assert.ok(Math.abs(parseFloat(rowValue(rows, "Conduit Area")) - 0.304) < 0.001);
  assert.ok(Math.abs(parseFloat(rowValue(rows, "Allowable Fill Area")) - 0.1216) < 0.001);
  assert.ok(rowValue(rows, "Result").startsWith("PASS"));
});

test("conduit fill uses 53% for one conductor and 31% for two", () => {
  const one = expectRows(
    computeConduitFill({ conductorCount: "1", wireSize: "12", conduitSize: "1/2" }),
  );
  assert.equal(rowValue(one, "Fill Limit"), "53%");

  const two = expectRows(
    computeConduitFill({ conductorCount: "2", wireSize: "12", conduitSize: "1/2" }),
  );
  assert.equal(rowValue(two, "Fill Limit"), "31%");
});

test("conduit fill fails an overfilled raceway and names a larger one", () => {
  // 10 x #12 THHN = 0.133 in2, over the 0.1216 in2 allowed in 1/2" EMT.
  const rows = expectRows(
    computeConduitFill({ conductorCount: "10", wireSize: "12", conduitSize: "1/2" }),
  );
  assert.ok(rowValue(rows, "Result").startsWith("FAIL"));
  const note = rows.find((r) => r.label === "Result")?.note ?? "";
  assert.match(note, /3\/4/);
});

test("conduit fill agrees with NEC Annex C.1 at the 1/2\" EMT limit", () => {
  // Annex C.1 allows 9 x #12 THHN in 1/2" EMT; the tenth must fail.
  const nine = expectRows(
    computeConduitFill({ conductorCount: "9", wireSize: "12", conduitSize: "1/2" }),
  );
  assert.ok(rowValue(nine, "Result").startsWith("PASS"));
});

/* ── Lighting voltage-drop optimiser ──────────────────────────────────────
   Inherited the doubled-distance bug, so it recommended 4 AWG where 8 AWG
   already met the limit — two sizes of unnecessary copper. */

test("lighting optimiser picks the smallest size that meets the limit", () => {
  // 2400 W at 120 V = 20 A over 100 ft at 3% needs 14,333 cmil -> 8 AWG (16,510).
  const rows = expectRows(
    computeLightingVdOptimizer({
      totalWattage: "2400",
      voltage: "120",
      maxVd: "3",
      distance: "100",
    }),
  );
  assert.equal(rowValue(rows, "Recommended Wire Size"), "8 AWG");
  assert.ok(Number(rowValue(rows, "Voltage Drop at That Size")) <= 3);
});

test("lighting optimiser reports an error when nothing fits", () => {
  const result = computeLightingVdOptimizer({
    totalWattage: "50000",
    voltage: "120",
    maxVd: "1",
    distance: "5000",
  });
  assert.ok(result.error, "expected an error rather than a silent fallback");
});

/* ── Minimum wire size ───────────────────────────────────────────────────── */

test("minimum wire size picks the first conductor at or above the load", () => {
  const rows = expectRows(computeMinWireSize({ current: "100", material: "cu", insulation: "thhn" }));
  assert.equal(rowValue(rows, "Minimum Wire Size"), "3 AWG");
});
