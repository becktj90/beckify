# Wire Size & Ampacity — conductor visualization (build 240)

PR1: verified geometry model + orthographic 2D cross-section + parameter inspector + review fixes. **3D cutaway deferred to PR2.**

## What shipped

1. **Conductor cross-section card** — orthographic end view from numeric dimensions (Table 8 metal Ø, Table 5 overall Ø). Scale bar labeled **Drawn to scale** (never “Actual size”).
2. **Construction vs temp** — THHN / XHHW / RHW construction profile is separate from the 60/75/90 °C ampacity columns. Insulation is never invented from the temp rating.
3. **Equivalent-area fallback** — when Table 5 area is unavailable for the selected construction, the drawing uses a metal-only equivalent-area circle and says so.
4. **Parallel equals + EGC** — parallel phase conductors are individual equals; optional EGC (circuit opt-in) shares the same scale.
5. **Collision-aware leaders** + inspector separating **Geometry** vs **Ampacity** callouts.
6. **Review fixes** — CCC/parallel whole-count (no Int truncation / no parallel clamp-to-1), ambient domain, parallel eligibility (1/0+), 240.4(B) next-size prerequisites, material-specific 240.4(D) small-conductor limits, provisional vs entered OCPD for Table 250.122 EGC.
7. **State / handoff** — stale marking, Calculate, tool IDs, and Voltage Drop handoff preserved.

## Sources

| Quantity | Source |
| --- | --- |
| Metal circular mils / Ø | NEC Chapter 9 Table 8 (`√CM / 1000` in) |
| Insulated area / overall Ø | NEC Chapter 9 Table 5 → equivalent circle |
| Ampacity / ambient / CCC | Table 310.16, 310.15(B)(1), 310.15(C)(1), 110.14(C) |
| Small-conductor OCPD | 240.4(D) Cu 14/12/10 · Al 12/10 |
| Parallel eligibility | 310.10(H) ≥ 1/0 |
| EGC | Table 250.122 (entered OCPD, or provisional from load) |

## Limitations

- Cross-section is illustrative packing of equal parallels — not a raceway jam check (use Conduit Fill).
- Construction type must be chosen; it is not inferred from temperature columns.
- Equivalent-area mode is metal-only when Table 5 is unavailable — not a jacketed OD.
- 240.4(B) next-size-up is flagged when usable ampacity falls between standard ratings; confirm Code exceptions.
- Design aid — confirm the Code and the AHJ. Not a PE stamp.
- 3D cutaway not in this PR.

## Tests

```bash
cd ios/BeckifyMath && swift test --filter AmpacityDeratingTests
cd ios/BeckifyMath && swift test --filter ConductorGeometryTests
cd ios/BeckifyMath && swift test --filter EquipmentGroundingTests
```
