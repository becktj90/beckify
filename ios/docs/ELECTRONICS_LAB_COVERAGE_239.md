# Electronics Lab coverage matrix (build 239)

| Circuit | Bench mode | Status | Note |
|---|---|---|---|
| Series resistors (`seriesResistors`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Parallel resistors (`parallelResistors`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Voltage divider (`voltageDivider`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Kirchhoff loop (`kirchhoffLoop`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Thevenin and Norton (`theveninNorton`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| RC step (`rcStep`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| RL step (`rlStep`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| First-order filter (`firstOrderFilter`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Series RLC (`seriesRLC`) | Breadboard + schematic | priority | Illustrative solderless hookup + schematic |
| Half-wave rectifier (`halfWave`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Full-wave bridge (`fullBridge`) | Breadboard + schematic | priority | Illustrative solderless hookup + schematic |
| Shunt clipper (`shuntClipper`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Diode clamper (`clamper`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| LED and series R (`ledSeries`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Divider bias (`bjtBias`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Common-emitter amp (`ceAmp`) | Breadboard + schematic | priority | Illustrative solderless hookup + schematic |
| BJT switch (`bjtSwitch`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Common-source amp (`csAmp`) | Breadboard + schematic | priority | Illustrative solderless hookup + schematic |
| MOSFET switch (`mosSwitch`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| CMOS inverter (`cmosInverter`) | Breadboard + schematic | priority | Illustrative solderless hookup + schematic |
| Inverting amp (`invertingAmp`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Non-inverting amp (`nonInvertingAmp`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Summing amp (`summingAmp`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Difference amp (`diffAmp`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Integrator (`integrator`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Differentiator (`differentiator`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Comparator (`comparator`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| 555 astable (`astable555`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| 555 monostable (`monostable555`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| LED flasher (`ledFlasher`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| 7-segment drive (`sevenSegment`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Class overview (`classOverview`) | Module / conceptual | deferred | Schematic/module bench; instruments/remaining polish in PR2 |
| Discrete CE stage (`discretePower`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Op-amp load amp (`opAmpPower`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Linear regulator drop (`linearDrop`) | Breadboard + schematic | ready | Illustrative solderless hookup + schematic |
| Ideal buck (`idealBuck`) | Module / conceptual | deferred | Schematic/module bench; instruments/remaining polish in PR2 |
| Complex convert (`complexConvert`) | Module / conceptual | deferred | Schematic/module bench; instruments/remaining polish in PR2 |
| Series / parallel Z (`impedanceCombo`) | Module / conceptual | deferred | Schematic/module bench; instruments/remaining polish in PR2 |
| L-section match (`lMatch`) | Module / conceptual | deferred | Schematic/module bench; instruments/remaining polish in PR2 |
| Quarter-wave match (`quarterWave`) | Module / conceptual | deferred | Schematic/module bench; instruments/remaining polish in PR2 |
| Stub length (`stubCancel`) | Module / conceptual | deferred | Schematic/module bench; instruments/remaining polish in PR2 |

## Solver limitations

- Ideal lumped models — not SPICE.
- DC nodal / AC phasor; BJT uses fixed 0.7 V Vbe and constant β; MOSFET square law.
- No fabricated oscilloscope transients from DC-only circuits.
- Annotation layer **All** is inspector-only; board uses Minimal / Values / Measurements.
- Virtual bench instruments (PSU, FG, scope, DMM) deferred to PR2.
