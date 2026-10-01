# Toolbox visualization audit

Audit only. No feature work in this change. Retro CRT home tiles stay a separate pass. Look Check stays out of the field-graphics queue.

Source of truth: `ToolboxCatalog` / `ToolID` on `main` (`d7a5358`), routed by `CalculatorHostView`. Shelf names come from `ToolHomeAreaPolicy`, which owns home area. Category color bags in the catalog are not the shelf.

Reviewed in code, not by running the app: each tool’s primary SwiftUI view, plus `PlotChrome`, `SpectrumPlot`, `EngineeringDiagrams`, `ConduitFillDiagram`, `MagneticsDiagrams`, `BreadboardCanvas`, and the receptacle face canvas.

## How to read a row

| Tag | Meaning |
| --- | --- |
| **viz_now** | What the result screen draws today. |
| **viz_target** | The one picture to ship, or “keep” when the current picture is the result. |
| **Gap** | Strong (the picture is the result), Partial (a picture exists and is not yet that result), None (numbers and forms). |
| **tier** | **P0** next train · **P1** second train · **P2** later · **Hold** already strong enough — do not rebuild. |
| **blockers** | Honesty limits, missing inputs, or “do not staff.” |
| **reuse** | Existing SwiftUI to extend. Original drawing only. Do not copy a textbook figure or a web canvas. |

Rules for every new picture:

- One primary visual per tool. A mode switch may change which picture is primary. A second chart beside it is a miss.
- Axes go through `LabeledPlotChrome` (`PlotChrome.swift`). VoiceOver reads the numbers first; the canvas is not the accessible value.
- The drawing updates from the same inputs as the numbers. It does not invent a result.
- Motion is purposeful (`TimelineView`) and respects Reduce Motion.
- Pass / warn / fail use `Theme.good`, `Theme.warn`, `Theme.bad`.
- Field voice. No homework, course, or lab-assignment captions.
- Honest claims. No fake dBm, RSRP, sound-level, or EMF accuracy. No SPICE editor. No Smith-chart tool (there is no Smith `ToolID` on iOS).

## Executive summary

The toolbox is not uniformly text. Raceway and tray sections, transformer windings, phasor and control plots, the electronics schematic and breadboard, solenoid and magnetics sketches, and the instrument spectra are already the result on those screens. Rebuilding them would thrash working graphics.

The holes that still matter in the field are narrower:

1. **Phasors & Impedance** draws a time waveform inside `LabeledPlotChrome`, but the chrome is not a real volts-versus-seconds scale (see P0). Several other pictures sit on the same station.
2. **Reactance** series is the XL/XC sweep, with a marker at the entered frequency, including when only L or only C is set. Resonance is the |Z| curve, with f0 and the Q bandwidth when R is set. Phasors & Impedance stays the phasor home.
3. **Power factor** draws one triangle: existing kVAR and target kVAR on a fixed kW leg. Bank µF is a label. Reduce Motion skips the shrink.
4. **Jobsite cluster:** voltage drop is one run strip — supply, one-way length, load, drop in volts, informational 3% and 5% marks, and the preferred target. Motor FLA is one plate titled Table FLA: horsepower, table-column volts, phase, table FLA, and 125% conductor current. Nameplate FLA stays on Motor Nameplate. The receptacle face is one plate: round for locking and IEC, rectangular for straight blade and household blade faces. Isolated ground and GFCI stay callouts. Short-circuit current is one callout: available fault amps, kA when the fault is at least 1 kA, and the method line “Infinite-bus secondary. Isc = FLA × 100 / %Z.” None of these tools collect a gear AIC, so a pass/fail against interrupting rating is not a drawing task. Wire Size & Ampacity is one derating stack: 310.16 base, ambient, bundling, and the 110.14(C) terminal limit, with required current marked. The final stage is good when usable ampacity meets that required current and bad when it is short. NEC Circuit Calculator is that same voltage-drop strip, with an ampacity chip on it. The chip is good when usable ampacity meets design current and bad when it is short. This tool has no preferred drop target. Design current, conductor, drop, and OCPD stay rows.
5. **Electronics Lab** is already strong. Typeset transfer text and a clearer DC versus AC source are in flight elsewhere. This audit does not open a second lab PR.

Textbook ship-order items that are **not** Hold move to **P1**: harmonics bars, heater Δ/Y sketch, UPS runtime tank, load-worksheet bars, and a protection-side skin-depth / aperture sketch. The ampacity derating stack has shipped on Wire Size & Ampacity. **Conduit fill is Hold.** It already draws a to-scale bore, conductor circles, and fill percent against the Chapter 9 Table 1 allowance (including the nipple case). Do not put it on a rebuild wave.

## Reconciliation

| Brief | What this audit does with it |
| --- | --- |
| Trevor — many tools have no graphics | Inventory covers all 91 `ToolID`s. Text-only tools are Gap **None**. Tools that already draw the result are **Hold**. |
| Textbook metaphors | Used as the *idea* of the picture (triangle, strip, stack, tank, spectrum bars). Figures are not copied. Conduit, transformer windings, 555 timing, transients, diode I–V, control plots, and magnetics sketches are already on iOS, so they are not re-specified as new research. |
| Gregory — one picture, PlotChrome, P0/P1/P2/Hold | Tiers below use those names. P0 is the next train. Hold means do not staff. |

Preferred textbook order, after removing Hold work: voltage-drop strip and the rest of the jobsite cluster are P0; ampacity stack, motor card (P0, not a second torque curve), and fault callout are as Gregory ordered; power triangle for **correction** is P0; the plain Power tool’s triangle is P1 so it reuses the same component.

## Merge queue

One queue for implementers. One tool per PR unless the note says a kit lands first. Do not start P1 by rebuilding a Hold screen.

**P0 — staff in this order**

1. `phasorImpedance` — time waveform chrome only.
2. `reactance` — XL/XC versus frequency as the only picture (resonance mode: the \|Z\| peak instead).
3. `powerFactor` — before/after triangle on the existing component.
4. `voltageDrop` — turn the existing run into the 3% / 5% strip. Not a second chart.
5. `motorFLA` — table-current card.
6. `receptacleSelector` — family outline on the existing face canvas.
7. `shortCircuit` — one callout, method named.

Do **not** staff `electronicsLab` from this document. Residual transfer typesetting and the DC/AC source mark are already in flight.

**P1 — after those land**

`necCircuit` shipped as the voltage-drop strip plus an ampacity chip (the derating stack is not redrawn). Harmonics bars. IS-loop margin gauge. Heater Δ/Y using the transformer connection drawing. UPS tank. Load-worksheet bars. EMP protection sketch. Power-tool triangle (reuse the PF component; do not draw another Y/Δ). Basics sketches for divider, series/parallel, and resistor bands. Pack cell matrix. Signal-scaling marker on the curve that already exists. Statistics is a design check of charts that already exist, not a new plot kit.

**Do not staff**

Conduit fill, cable ladder, transformer windings, breath flute, instrument spectra and gauges listed as Hold, the hidden phasor-sum screen as a new home, Look Check, retro tiles, a Smith chart, or a second phasor on Reactance.

## Inventory

91 tools, including hidden `powerWizard` and `phasorDiagram`. Shelf is `ToolHomeAreaPolicy`.

| Tool | ID | Shelf | viz_now | Gap | viz_target | tier | blockers | reuse |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ohm's Law | `ohmsLaw` | Basics | V–I load line (`OhmsLawLoadLineChart`) | Strong | Keep the load line. No second schematic. | Hold | — | `EngineerLinePlot` |
| Power | `power` | Power & AC | Result rows only | None | One P–Q triangle for the AC result | P1 | DC mode stays numbers. Do not add a Y/Δ here. | `PowerTriangleDiagram` after the PF pass |
| Three-Phase Power | `threePhasePower` | Power & AC | Power triangle, connection canvas, line/phase arrows | Strong | Keep. Connection glyph already covers Y and Δ. | Hold | Several pictures already; do not add another. | Existing canvases |
| Power Wizard | `powerWizard` | Power & AC | Hidden deep link. Rows only. | None | No picture of its own | P2 | Off the grid. Waveforms, if any, belong on Power. | — |
| Voltage Drop | `voltageDrop` | Jobsite | Run strip: supply, one-way length, load, drop in volts, 3% and 5% informational marks, preferred target | Shipped | One run strip colored within 3%, between 3% and 5%, or over 5%. | Done | Bands stay informational. Parallels and the preferred target use the same numbers as the rows. | `VoltageDropDiagram` |
| Conduit Fill | `conduitFill` | Jobsite | To-scale bore, wall, conductor circles, fill bar vs allowed percent (Table 1, including nipple) | Strong | Keep | Hold | Do not rebuild. Jam and packing notes stay text. | `ConduitFillDiagram` is the cross-section kit |
| Cable Ladder | `cableLadder` | Jobsite | Tray cross-section plus support elevation | Strong | Keep | Hold | — | Sibling of the conduit section, not a copy |
| Equipment Grounding | `equipmentGround` | Jobsite | Table 250.122 rows | None | Optional size callout only | P2 | Low field impact beside ampacity and conduit | Callout kit, later |
| Transformer Sizing | `transformer` | Power & AC | Winding canvas: Δ, Y, high-leg, corner-ground, open delta, zig-zag, buck-boost | Strong | Keep | Hold | Colors are common practice; the spec wins. Do not redraw. | `TransformerView` connection canvas is the connection kit |
| 555 Timer | `timer555` | Basics | Astable waveform and monostable charge curve | Strong | Keep | Hold | Ideal timing, not a scope capture | `Timer555WaveformDiagram`, `MonostableCapChargeChart` |
| Motor FLA Tables | `motorFLA` | Jobsite | Plate titled Table FLA: HP, table-column volts, phase, table FLA, 125% conductor current | Shipped | One plate. Not a motor photo and not nameplate amps. | Done | Nameplate FLA stays on Motor Nameplate. 480 V systems use the 460 V column. | `TableFLAPlateCard` in `MotorFLAView` |
| Wire Size & Ampacity | `wireAmpacity` | Jobsite | One derating stack: 310.16 base, ambient, bundling, and the 110.14(C) terminal limit, with required current marked | Shipped | Horizontal stages from the same trace. Final stage is good when usable meets required and bad when it is short. | Done | No new factors. A cooler ambient can lengthen that stage. Pass or fail is only against required ampacity. | `DeratingStack` |
| Flexible Cable Ampacity | `flexibleCable` | Jobsite | Bar chart of table ampacity vs size | Strong | Keep | Hold | Table 400.5 column, not a measured cable | Swift Charts bar |
| Conductor Cost Optimizer | `conductorCost` | Jobsite | Horizontal first-cost bars, recommended size marked | Strong | Keep | Hold | Book dollars plus overrides, not a quote | `ConductorCostRankingDiagram` |
| Conductor Length by Resistance | `conductorLength` | Jobsite | DMM measurement sketch (end-to-end or shorted parallel) | Strong | Keep | Hold | Path factor is labeled on the sketch | `ConductorLengthView` diagram |
| Voltage Divider | `voltageDivider` | Basics | Rows only | None | One series string, Vin and Vout marked | P1 | Two resistors. Not a full schematic editor. | Basics sketch kit |
| Series / Parallel | `seriesParallel` | Basics | Rows only | None | One string or ladder of the parts just solved | P1 | Resistors or capacitors, series or parallel, matching the mode | Basics sketch kit |
| Resistor Color Code | `resistorColor` | Basics | Band names as text | None | Drawn bands in the decoded colors, value beside them | P1 | 4-band and 5-band. The picture is the code, not a product photo. | Basics sketch kit |
| Unit Converter | `unitConverter` | Basics | Converted numbers | None | None | P2 | A picture would not change the conversion | — |
| Frequency / LC | `frequencyWave` | Basics | Sine over one period (`SineWaveChart`) | Strong | Keep | Hold | Ideal sine, not a captured waveform | `EngineerLinePlot` |
| LED / RC | `ledRC` | Basics | Charge/discharge curve around τ | Strong | Keep | Hold | — | `RCChargeDischargeChart` |
| Wi-Fi Path | `wifiStatus` | Instruments | Strength gauge (Apple percent / bars) and RTT plot | Strong | Keep | Hold | Not a dBm meter. Do not add a heatmap. | `WiFiStrengthGauge`, `LabeledPlotChrome` |
| Cellular Path | `cellularStatus` | Instruments | Generation arc and TCP RTT arc | Strong | Keep | Hold | Not RSRP, RSRQ, SINR, or dBm | `CellularArcGauge` |
| BLE Scanner | `bluetoothScan` | Instruments | Radar of advertisers, RSSI as range | Strong | Keep | Hold | Device count is not people | Radar canvas |
| Noise Meter | `noiseMeter` | Instruments | dBFS sparkline and audible-band spectrum | Strong | Keep | Hold | Uncalibrated. Not an SLM. | `SpectrumPlot`, `TraceSparkline` |
| Acoustic Imager | `acousticImager` | Instruments | Level, spectrum, time activity | Strong | Keep | Hold | Not a sound camera | `SpectrumPlot` |
| Room & Rig Check | `setupCheck` | Instruments | Relative spectrum, traces, crest | Strong | Keep | Hold | Listen-test aid, not a lab mic | `SpectrumPlot`, `LabeledPlotChrome` |
| Bubble Level | `bubbleLevel` | Instruments | Face-up bubble; plumb angle | Strong | Keep | Hold | Phone gravity, not a machinist level | Existing bubble |
| Magnetometer | `magnetometer` | Instruments | Heading, \|B\| in µT, Mag Sweep sparkline and spectrum | Strong | Keep | Hold | DC field on the phone. Not an AC EMF survey. | `SpectrumPlot`, `TraceSparkline` |
| Barometer | `barometer` | Instruments | Pressure and relative altitude rows | None | None on this train | P2 | Phone altimeter, not a weather station | `TraceSparkline` only if a trace is added later |
| g-Force Snapshot | `motionSnapshot` | Instruments | Gravity and user-acceleration numbers | None | None | P2 | The tool says it is not a machine spectrum. Do not add an FFT. | — |
| Stillness Anomaly Watch | `stillnessWatch` | Instruments | Baseline ticks; mic impulse spectrum | Strong | Keep | Hold | Not a presence meter | `SpectrumPlot` |
| Breath Flute | `breathFlute` | Instruments | Relic flute canvas, covered holes, breath | Strong | Keep | Hold | Toy. Out of the field-result queue. Do not restyle. | `RelicFluteCanvas` |
| Coupled Vibration | `coupledVibration` | Instruments | RMS and spectrum of user acceleration | Strong | Keep | Hold | Phone on the machine. Relative A/B only. | `SpectrumPlot` |
| Position | `fieldPosition` | Instruments | Coordinates, speed, altitude, distance | None | None | P2 | A map is a new surface, not a result sketch | — |
| Device Health | `deviceHealth` | Instruments | Battery, thermal, storage, uptime rows | None | None | P2 | Diagnostics of this phone, not a plant meter | Battery fill only if it reuses the tank kit later |
| Receptacle Selector | `receptacleSelector` | Jobsite | One face: round locking and IEC, rectangular straight blade and household blades. IEC clock on the round face. | Shipped | One faceplate. Pins from the catalog face. | Done | Schematic, not a photo. Isolated ground and GFCI stay callouts. Hazardous remains a flag. | `ReceptacleFaceView` |
| Reactance & Resonance | `reactance` | Bench | Series: XL and/or XC vs f, marker at the entered f. Resonance: \|Z\| with f0 and Q bandwidth when R is set. | Shipped | One picture per mode. No phasor on this tool. | Done | Ideal lumped parts. Phasors & Impedance stays the phasor home. | `ReactanceSweepChart`, `ResonanceImpedanceChart` |
| Power Factor Correction | `powerFactor` | Power & AC | One triangle, existing and target kVAR, fixed kW leg, bank µF label | Shipped | Before and after on the same kW leg. | Done | Reduce Motion shows both legs with no shrink. Stale inputs dim with the result card. | `PowerTriangleDiagram` |
| Short-Circuit Current | `shortCircuit` | Jobsite | One callout: available fault amps, kA at 1 kA and up, method “Infinite-bus secondary. Isc = FLA × 100 / %Z.” | Shipped | One callout. No AIC bar. | Done | No gear AIC field. The picture does not pass or fail an interrupting rating. | `ShortCircuitDiagram` |
| Circular Mils | `circularMils` | Jobsite | Diameter and area as numbers | None | Optional circle scaled to diameter | P2 | Low impact | Cross-section kit, later |
| Load & Demand Factors | `loadFactors` | Jobsite | Average / peak / capacity bars | Strong | Keep | Hold | Metered inputs, not a load study | `LoadFactorChart` |
| Signal Scaling | `signalScaling` | Controls | 4–20 transfer curve, linear or square-root | Partial | Keep that curve as the one picture; mark the live milliamp and engineering unit on it | P1 | A separate gauge would be a second picture. Square-root stays on the curve. | `SignalScalingChart` |
| Modbus Address | `modbusAddress` | Controls | Offset, entity, and function-code rows | None | None | P2 | An address diagram would not change the mapping | — |
| PLC Timer Preset | `plcTimer` | Controls | Preset counts and quantisation error | None | Optional preset-versus-timebase bar | P2 | The error in time is the result; a bar is optional | Fill bar, later |
| Panel Directory | `panelDirectory` | Reference | Photo of the schedule, confirmable rows | Partial | Keep the photo | Hold | Trip rating is not measured load. No demand chart until the operator confirms rows. | Camera capture |
| Motor Speed & Torque | `motorSpeed` | Jobsite | Torque-versus-speed curve and rated point | Strong | Keep the curve | Hold | Constant-horsepower sketch, not a tested speed-torque curve. The load dial belongs on Motor FLA. | `MotorTorqueCurveChart` |
| RF Power & Link | `rfLink` | Bench | Free-space loss versus distance, point at the entered range | Strong | Keep | Hold | Free-space model, not a surveyed link | `PathLossDistanceChart` |
| Quick sum | `phasorDiagram` | Controls | Hidden. Polar plot of 2–3 phasors and the resultant. Same form is embedded on Phasors → Sum. | Strong | Keep the polar plot. Do not open a second phasor home. | Hold | Off the grid on purpose | `PhasorPolarDiagram` |
| Number Base Converter | `numberBase` | Bench | Bases and signed widths as text | None | None | P2 | Bit pictures do not change the conversion | — |
| Battery Bank Sizing | `batteryBank` | Power & AC | Usable versus nameplate watt-hours bar | Strong | Keep | Hold | The runtime tank gap is UPS, not this bar | `BatteryBankChart` |
| Reference Library | `referenceLibrary` | Reference | Searchable tables (NEMA, IP, colors, areas, torque, conduit) | None | None on this train | P2 | A glyph per rating is optional later, not a redraw of the tables | — |
| Magnetic Circuit | `magneticCircuit` | Bench | Reluctance, flux, and B as rows | None | None | P2 | Core pictures already live on Magnetics Lab. Do not draw a second core. | — |
| Fiber Link / NA | `fiberLink` | Bench | NA, acceptance angle, V-number as rows | None | One acceptance cone, angle labeled | P2 | Ideal step-index. Original geometry, not a copied figure. | New cone on `DiagramCard` |
| Gaussian Beam | `gaussianBeam` | Bench | Rayleigh range, divergence, w(z) as rows | None | One beam envelope, waist and w(z) marked | P2 | Ideal Gaussian, not a measured profile | `EngineerLinePlot` or a simple path |
| Transient Circuits | `transientCircuit` | Bench | RC/RL step curve with the time marker | Strong | Keep | Hold | Ideal lumped step | `TransientResponseChart` |
| E-Bus / Rack Current | `rackCurrent` | Controls | Sum versus bus rating as rows | None | One headroom bar, percent of bus | P2 | Devices are typed currents, not a live rack | Fill bar kit |
| Semiconductor I-V | `diodeIV` | Bench | Shockley forward curve and operating point | Strong | Keep | Hold | Ideal equation, not a curve tracer | `DiodeIVChart` |
| IS Loop Verifier | `isLoopVerifier` | Jobsite | Four entity comparisons as rows | None | One gauge: the worst margin (Voc, Isc, C, or L), pass or fail | P1 | Entity concept check. Not a certified loop drawing. One gauge, not four. | Gauge kit, `Theme.good` / `Theme.bad` |
| Tap-Changer Calculator | `tapChanger` | Power & AC | Ranked taps as rows | None | Optional tap ladder with the recommended step marked | P2 | Nameplate schedule still wins | — |
| Harmonics (THD) | `harmonicsTHD` | Power & AC | THD, dominant order, and a status row | None | Bars I1…Ih, THD called out, triplen orders tinted | P1 | Entered harmonics, not a meter capture. IEEE 519 stays discussion text. | `LabeledPlotChrome` bar series. Not `SpectrumPlot` (that is a mic FFT). |
| UPS / On-site Power | `upsSizing` | Power & AC | kVA, kWh, Ah, runtime as rows | None | One tank: runtime energy against the design load | P1 | Planning energy, not a tested autonomy | Fill / tank kit |
| Motor Nameplate Analyzer | `motorNameplate` | Jobsite | Overload, SCPD, conductor, and code-letter rows | None | None | P2 | A drawn plate would collide with Motor FLA’s card and with the OCR photo | — |
| Motor Nameplate OCR | `motorNameplateOCR` | Jobsite | Camera photo, Vision text, confirm fields | Partial | Keep the photo | Hold | Human confirm. Do not draw a plate over the picture. MOCP and LRA are not FLA. | Camera |
| Look Check | `lookCheck` | Jobsite | Photo and an entertainment verdict | Partial | None | Hold | Out of scope. Not a field graphic. | — |
| Heater Design Wizard | `heaterDesign` | Bench | Line current, leg R, and wire length as rows | None | One three-leg sketch, Δ or Y matching the mode | P1 | Resistive planning model. Not a thermal photo. | Transformer connection kit (`BankKind` delta / wye) |
| EMP / EMC Shielding | `empEmc` | Bench | Skin depth, sheet SE, loop voltage, aperture SE as rows | None | One protection sketch: wall thickness against skin depth, and the longest aperture | P1 | Protection-side only. Ideal sheet and worst-dimension aperture. Not a coupling weapon and not a free-space field map. | New sketch on `DiagramCard` |
| NEC Circuit Calculator | `necCircuit` | Jobsite | One voltage-drop strip with an ampacity chip. Design current, conductor, drop, and OCPD stay rows. | Shipped | The strip is the run. The chip is usable versus design current: good when it meets, bad when it is short. 3% and 5% stay informational. | Done | No preferred target on this tool. No derating stack and no third graphic. | `VoltageDropDiagram` |
| Load Calculation Worksheet | `loadWorksheet` | Reference | Lighting demand and VA totals as rows | None | Stacked bars of the VA groups, 80% line where the worksheet uses it | P1 | The 80% mark is the continuous-load planning line the tool already applies. Not a service calculation stamp. | Bar series on `LabeledPlotChrome` |
| Cable Schedule Generator | `cableSchedule` | Reference | ID list and CSV | None | None | P2 | A schedule is a list | — |
| Solenoid Design Wizard | `solenoidDesign` | Bench | Coil cross-section, B vs I, axial B(z), force vs gap | Strong | Keep the cross-section as the primary. Extra curves stay on their modes. | Hold | Ideal coil. Do not add a fourth chart. | `SolenoidCrossSectionDiagram` and the three charts |
| Solar Design Wizard | `solarDesign` | Power & AC | Tilt and azimuth numbers from the phone, array kW as rows | Partial | Optional aim error (tilt and azimuth versus the target) | P2 | Phone IMU and compass. Not a shade study or a survey. | — |
| Analog Design Workbench | `analogWorkbench` | Bench | Ideal magnitude Bode for the selected stage | Strong | Keep | Hold | Golden-rule magnitude sketch, not a measured Bode | `EngineerLinePlot` |
| Noise & SNR | `noiseSNR` | Bench | Referred noise, SNR, and a rough NF as rows | None | Optional one-bar noise budget | P2 | Johnson / shot / amp model. Easy to over-draw. | — |
| Linear / LDO Regulator | `linearRegulator` | Bench | Vout, dropout, Pd, and θJA estimate as rows | None | Optional dropout and dissipation callout | P2 | θJA estimate, not a thermal image | Callout kit |
| Instrumentation Amp | `instrumentationAmp` | Bench | Gain and swing versus rails as rows | None | One 3-op-amp or difference-amp sketch, gain on Rg | P2 | Ideal gain. CMRR is not drawn as a measured plot. | Basics sketch kit |
| ADC / DAC & Sampling | `adcDac` | Bench | LSB, code count, ideal SNR, Nyquist as rows | None | Optional code staircase for the entered code | P2 | Ideal quantization. Do not imply measured ENOB. | `EngineerLinePlot` |
| E-Bike Torque / RPM | `eBikeTorqueRPM` | Bench | Torque or RPM as rows | None | None on this train | P2 | Motor Speed already has the torque curve | — |
| Sprocket Ratio Designer | `eBikeSprocket` | Bench | Ratio, output RPM, and wheel speed as rows | None | Optional two sprockets with tooth counts | P2 | Low field impact | — |
| Range Estimator | `eBikeRange` | Bench | Miles, runtime, implied speed as rows | None | Optional energy tank | P2 | Wh/mi planning, not a trip log | Tank kit if UPS builds it |
| Battery Pack Designer | `eBikePackDesigner` | Bench | Series/parallel counts as rows. Grid vs honeycomb is a picker, not a drawing. | None | One cell matrix, S and P labeled, voltage and current on the pack | P1 | Planning layout from cell ratings. Not a BMS schematic. | Pack matrix |
| Nickel Strip | `nickelStrip` | Bench | Cross-section area and planning current as rows | None | One strip section, width and thickness to scale | P2 | Planning current, not a tested ampacity | Cross-section kit after conduit’s geometry helper, not a raceway redraw |
| Control Systems | `controlSystems` | Controls | Unit-step overlays, Bode magnitude and phase, lead | Strong | Keep | Hold | Approximations (RK4, log sweep). Not a commissioning record. Copy tone is a separate pass. | `EngineerLinePlot` |
| Control Strategies | `controlStrategies` | Controls | Strategy comparison plots (step and effort) | Strong | Keep | Hold | Comparison tool, not a tuner. Several plots are the product; do not collapse them in this train. | `EngineerLinePlot` |
| Electronics Lab | `electronicsLab` | Bench | Schematic with node volts and branch currents, solderless breadboard, meters, monospaced transfer text, line plots where a circuit has them | Strong | Typeset transfer expression and a DC versus AC source mark on the existing schematic | P0 | **In flight elsewhere. Do not open a second PR from this audit.** | Existing schematic canvas and `BreadboardCanvas` |
| Phasors & Impedance | `phasorImpedance` | Controls | Per station: time waveform in `LabeledPlotChrome`, plus a raw complex-plane canvas, a series sketch, and often an XL/XC sweep | Partial | Waves / phasor / RLC / Z: one time waveform whose chrome is the sample scale in volts and seconds, with a readout | P0 | See the shortlist. Sum keeps `PhasorPolarDiagram` only. Do not add a phasor home. | `LabeledPlotChrome`, `WaveformCard` |
| UL 508A Panel Lab | `ul508aPanelLab` | Controls | Feeder–panel one-line and path kA list (`PanelOneLineDiagram`) | Partial | Keep that one-line | P2 | Checklist and calculators, not a panel-layout editor | Existing one-line |
| Magnetics Lab | `magneticsLab` | Magnetics & Fields | Core path, three-leg path, machine role sketch | Strong | Keep | Hold | Ideal magnetic circuit. Not a finite-element plot. | `MagneticsDiagrams` |
| EM Fields | `emFields` | Magnetics & Fields | Faraday loop, charge plane, Lorentz sketch, sample-field arrows | Strong | Keep | Hold | Sketches of the entered vectors. Not a measured field. | `MagneticsDiagrams` |
| Statistics | `statistics` | Analysis | Density, rescale, scatter, and combination charts on `LabeledPlotChrome` | Strong | One distribution picture per station — already the case. Design-check only. | P1 | Do not add a second chart family. Example parameters stay labeled as examples. | `DensityChart`, `ScatterChart` |
| Spanish Translator | `spanishTranslator` | Reference | Speech in, speech out | None | None | P2 | A waveform would not change the translation | — |

## Shared kits

Build these once. Later tools take them. Do not add a one-off canvas when the kit exists.

| Kit | Status | First users | Later users |
| --- | --- | --- | --- |
| `LabeledPlotChrome` | Shipped. Tick labels, expand, optional inspect readout. | Phasor time waveform must use it as the scale, `inspection: .inspect`, readout in volts and seconds. | Harmonics bars, load-worksheet bars, any new line plot |
| `EngineerLinePlot` | Shipped. Used by load line, sine, reactance sweep, Bode, control, diode, transients. | Reactance keeps `ReactanceSweepChart` / `ResonanceImpedanceChart`. | Do not fork a third line plot |
| `DiagramCard` | Shipped frame, summary, export. | Every new picture | — |
| `PowerTriangleDiagram` | Shipped. Before/after Q on one kW leg. Single-Q mode remains. | Power factor correction | Power tool AC result |
| Raceway cross-section | Shipped as `ConduitFillDiagram` | Nobody new in P0. It is finished. | Nickel strip and circular mils may share **geometry helpers** later. Do not generalize by rewriting conduit. |
| Connection drawing | Shipped inside `TransformerView` (delta, wye, high-leg, corner, open delta). Three-phase has its own canvas. | Heater Δ/Y should call the same winding sketch, not a new one | — |
| Run strip | Shipped as `VoltageDropDiagram`. Supply, one-way length, load, volt drop, informational 3% and 5% marks, preferred target when the tool has one. | Voltage drop | NEC circuit: same strip, ampacity chip in the target slot. Shipped. |
| Derating stack | Shipped as `DeratingStack`. 310.16 base, ambient, bundling, 110.14(C), required-current mark. | Wire ampacity | NEC circuit uses the usable-versus-required verdict as a chip. It does not mount the stack. |
| Callout card | Motor FLA plate shipped in `MotorFLAView`. Short-circuit callout shipped as `ShortCircuitDiagram`: fault amps, kA when readable, method line. No AIC bar. | Motor FLA, short-circuit | Grounding size, regulator Pd |
| Gauge / tank | Partial. Cellular arcs and the conduit fill bar exist. Wi-Fi gauge exists. | IS-loop worst margin; UPS tank | Rack headroom, e-bike range. Never a fake RF dBm arc. |
| Discrete spectrum bars | Not shipped. `SpectrumPlot` is a microphone FFT with a dBFS scale. | Harmonics orders | Do not point entered harmonics at `SpectrumPlot` |
| Faceplate | Shipped as `ReceptacleFaceView`. Round for locking and IEC. Rectangular for straight blade and household blade faces. | Receptacle family outline | — |
| Basics sketch | Not shipped | Divider, series/parallel, resistor bands | In-amp sketch at P2 |
| Pack matrix | Not shipped | Battery pack designer | — |
| Phasor plane | Two implementations: `PhasorPolarDiagram` (quick sum) and `ComplexPlaneCanvas` (Phasors stations). | Do not add a third. P0 does not restyle the plane. | — |

`SpectrumPlot` stays the instrument spectrum. Control and analog Bode stay on `EngineerLinePlot`. Breadboard stays `BreadboardCanvas`.

## P0 shortlist

Enough for a follow-up implementer. One picture each. Original SwiftUI (`Canvas` / `Path` / `Shape`). Numbers remain the accessibility value.

### 1. Phasors & Impedance — `phasorImpedance`

**Now.** `WaveformCard` wraps `LabeledPlotChrome` with Time (s) and Voltage (V). The canvas then draws its own grid and scales itself. `inspection` is `.look`, so there is no drag readout. The y title is always “Voltage”, including stations that also plot current. Phasor, R L C, and Z also stack a raw plane (`PlaneCard` / `ComplexPlaneCanvas` has no PlotChrome), a series sketch, and often `sweepCard`.

**Target.** One time waveform. Chrome start, mid, and end match the samples. Readout reports volts and seconds. If a current trace is on that station, give it its own scale or leave it off this picture — do not plot amps on a volt axis. Sum station keeps the existing polar plot and does not gain a waveform twin.

**Files.** `PhasorImpedanceView.swift` (`WaveformCard`, `WaveformCanvas`). `PlotChrome.swift`.

**Done when.** One picture per station, VoiceOver leads with the sentence and the readout, Reduce Motion leaves the cursor still, and Quick sum is untouched.

### 2. Reactance & Resonance — `reactance`

**Now.** Series mode draws `ReactanceSweepChart` only: XL, XC, or both, with a marker at the entered f. Resonance mode draws `ResonanceImpedanceChart` (\|Z\|, f0, and the Q bandwidth when R is present). No phasor on this tool.

**Target.** Met on this screen. Phasors & Impedance stays the phasor home. Captions stay “ideal lumped parts.”

**Files.** `FieldCalculatorViews.swift` (`ReactanceView`). `EngineeringDiagrams.swift` (`ReactanceSweepChart`, `ResonanceImpedanceChart`).

**Done when.** Changing f moves the marker. The phasor view is not on screen. Captions stay “ideal lumped parts.”

### 3. Power factor correction — `powerFactor`

**Now.** One `PowerTriangleDiagram`. The long leg is kW at one length for the existing kVAR leg and the target kVAR leg. The target leg shrinks into place when Reduce Motion is off. Bank microfarads are a label. Stale inputs dim the picture with the result card.

**Target.** Met on this screen. Both Q values stay visible, kW does not change length, and the caption does not claim a utility bill.

**Files.** `FieldCalculatorViews.swift` (`PowerFactorView`). `EngineeringDiagrams.swift` (`PowerTriangleDiagram`).

**Done when.** Both Q values are visible, kW does not change length between them, and the caption does not say the utility bill dropped.

### 4. Voltage drop — `voltageDrop`

**Now.** One `VoltageDropDiagram` strip. Supply node, one-way length, parallel runs, load node, and the drop in volts on the run. Marks at 3% and 5% are labeled informational. The preferred target uses the same meets / over tone as the result row. Within 3% is good, between 3% and 5% is warn, over 5% is bad. Stale inputs dim the picture with the result card.

**Target.** Met on this screen. No second chart. Bands stay informational.

**Files.** `VoltageDropView.swift`. `EngineeringDiagrams.swift` (`VoltageDropDiagram`).

**Done when.** The strip and the result rows agree, including parallels and the preferred target. Bands stay labeled informational.

### 5. Motor FLA — `motorFLA`

**Now.** One plate, `TableFLAPlateCard`, titled “Table FLA”. Horsepower, the table-column voltage, phase, table FLA, and 125% of table FLA for the conductor are on that plate. A line sends nameplate FLA to Motor Nameplate. 480 V systems use the 460 V column. Stale inputs dim the plate with the result card. No motor drawing and no torque curve.

**Target.** Met on this screen. The card stays table current.

**Files.** `MotorFLAView.swift` (`TableFLAPlateCard`). Readout strings in `MotorFLA.swift` (`TableFLAPlate`).

**Done when.** The card cannot be read as a photo of a motor or as nameplate amps.

### 6. Receptacle faceplate — `receptacleSelector`

**Now.** `ReceptacleFaceView` draws one face on the existing canvas. The outline is round for locking and IEC, including pin-and-sleeve, and rectangular for straight blade and household blade faces. Pins still come from `FaceDiagram`. The IEC clock stays on the round face when `kind == .iecClock`. The caption under the face is `face.caption`. VoiceOver leads with the configuration, amps, and voltage, then that caption. Isolated ground and GFCI stay notes and catalog rows.

**Target.** Met on this screen. One face. No manufacturer photo and no second diagram.

**Files.** `ReceptacleSelectorView.swift` (`ReceptacleFaceView`, `ReceptacleFaceCard`). Outline on `FaceDiagram`.

**Done when.** Switching family changes the outline, the caption still matches `face.caption`, and isolated-ground / GFCI stay callouts rather than a different face.

### 7. Short-circuit callout — `shortCircuit`

**Now.** One `ShortCircuitDiagram` callout. Large available fault amps, and kA when the fault is at least 1 kA. The method line “Infinite-bus secondary. Isc = FLA × 100 / %Z.” is on the card. The scaffold disclaimer and Show Work still say infinite-bus secondary, motor contribution, X/R, and 110.9–110.10. Stale inputs dim the card with the result card. VoiceOver leads with the amps, then the method. No AIC bar and no pass or fail.

**Target.** Met on this screen. No gear-rating bar unless a later change adds an optional interrupting-rating input.

**Files.** `FieldCalculatorViews.swift` (`ShortCircuitView`). `EngineeringDiagrams.swift` (`ShortCircuitDiagram`). Readout strings in `FieldCalcs.swift` (`ShortCircuitCallout`).

**Done when.** The method is visible without opening Show Work, and there is still no pass/fail against equipment that was not entered.

### 8. Electronics Lab — do not staff

**Now.** Schematic canvas (node volts, branch currents, animated source), fullscreen breadboard with meters, monospaced transfer string (`LabResponseCard`), and `EngineerLinePlot` where a circuit defines plots.

**Target already in flight.** Typeset the transfer expression and mark DC versus AC on the source that is already drawn. A second PR will duplicate that work. Leave `BreadboardCanvas` alone.

## P1 notes

Staff only after the P0 kits exist. Each item is still one picture.

| ID | Picture | Honesty |
| --- | --- | --- |
| `wireAmpacity` | Shipped. Horizontal stages from the trace, required current marked | Bundling and the terminal stage stay at or under the prior stage. Ambient can grow when its factor is above 1. |
| `necCircuit` | Shipped. Voltage-drop strip with an ampacity chip | Chip is usable versus design current. No derating stack and no third graphic. |
| `harmonicsTHD` | Order bars, triplens tinted, THD beside them | Typed spectrum, not a capture. Not `SpectrumPlot`. |
| `isLoopVerifier` | Worst of the four margins | Fail if any entity check fails. Not a loop CAD. |
| `power` | P–Q triangle on the AC result | Reuse the PF component. No new Y/Δ. |
| `heaterDesign` | Three legs, Δ or Y | Reuse the transformer winding sketch |
| `upsSizing` | Tank of watt-hours versus runtime | Planning energy |
| `loadWorksheet` | Stacked VA, 80% line when that rule is in the result | Not a stamped service calc |
| `empEmc` | Thickness versus skin depth, and the aperture | Protection-side estimates already in the tool |
| `voltageDivider` | Two resistors in series | — |
| `seriesParallel` | The combination just solved | — |
| `resistorColor` | Painted bands | — |
| `eBikePackDesigner` | Cell matrix | Not a BMS drawing |
| `signalScaling` | Marker on the existing transfer curve | No added gauge |
| `statistics` | Design check only | Charts already use PlotChrome |

## Hold (do not thrash)

Conduit fill, cable ladder, transformer windings, 555 waveform, flexible-cable bars, conductor-cost bars, conductor-length sketch, frequency sine, LED/RC curve, Ohm’s-law load line, Wi-Fi and cellular gauges, BLE radar, noise / acoustic / rig-check / coupled-vibration / magnetometer / stillness spectra, bubble level, breath flute, three-phase connection and triangle, battery-bank bar, load-factor bars, motor torque curve, RF loss curve, quick-sum polar plot, transient curve, diode I–V, analog Bode, control step and Bode, control-strategy plots, solenoid section, magnetics and EM sketches, panel-directory photo, nameplate OCR photo, Look Check.

## Out of this audit

- Retro CRT tile icons.
- Look Check verdict art.
- Web-only pictures with no iOS tool (Smith chart, a second circuit simulator). Electronics Lab is the iOS schematic and breadboard.
- Copy rewrites. Control Systems already says its plots are approximations; changing that sentence is not a visualization change.
- Any graphic that needs a new input (gear AIC, a measured harmonic capture, a shade study) before it can be honest.
