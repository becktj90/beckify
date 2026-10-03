# Beckify iOS

Native SwiftUI field EE toolbox for iPhone and iPad. Bundle ID `com.beckify.toolbox`, display name **Beckify**, iOS 17+.

Three more App Store products live in the same Xcode project: **Look Check** (`com.beckify.lookcheck`) — camera/library, Analyze, surprise roast — **Kestrel Heavy** (`com.beckify.kestrelheavy`) — a native SwiftUI shell that plays the Phaser 4 arcade from a local bundle — and **Beckify Drive** (`com.beckify.drive`) — a Bluetooth LE OBD-II dashboard with a native CarPlay scene. None of them is this toolbox. See [`LookCheck/README.md`](LookCheck/README.md), [`KestrelHeavy/README.md`](KestrelHeavy/README.md), and [`BeckifyDrive/README.md`](BeckifyDrive/README.md).

> **Archive / Xcode Cloud:** Archive-iOS and any Xcode Cloud Archive workflow for Toolbox **must** use scheme **Beckify** (`com.beckify.toolbox`). Do **not** archive Toolbox with scheme **LookCheck** or **KestrelHeavy**. Those are separate ASC apps with their own Archive schemes. Keep Archive workflows separate. Kestrel Heavy is not a Toolbox catalog game; the website `/games/kestrel-heavy` stays.

Home is two areas — **Field** (jobsite, first) and **Toolkit** (basics, bench, references) — not a flat grid of every tool. Search covers both and labels the area. Sensors live under Field → Instruments. Field home (not while searching) shows a **Pinned** strip: Voltage Drop, Wire Size & Ampacity, Motor FLA, Receptacle Selector, Wi-Fi Path, Conduit Fill.

**Settings** (gear on Toolbox, Favorites, and Saved Jobs) stores the electrical code, length units, and appearance on device. Default code is **NEC (US)**. **AS/NZS** is the other selectable code. IEC 60364, CEC, and BS 7671 are named and not selectable. Tools are not duplicated per code. Where AS/NZS tables are not in the app, the tool says **“AS/NZS not available for this tool yet — showing NEC”** and keeps the NEC result labeled as NEC. Appearance defaults to the system (light or dark). It does not force dark mode.

This is not a website wrapper. There is no `WKWebView` of beckify.com and no website project gallery. Calculator and sensor math helpers live in a pure Swift package so they can be tested on Linux without Xcode. Website toolbox IA is a follow-up, not this app.

## Design system

Reusable tokens live in `Beckify/Theme/Theme.swift` (surfaces, semantic accents, spacing, radius, stroke, typography, chart colors, motion). Calculator chrome — identity header, Calculate / Reset / Example, stale-result banner, diagrams, and the shared **How it works** disclosure — lives under `Beckify/Views/Components/`. About copy is data-driven in `BeckifyMath` (`ToolHowItWorksCatalog`, keyed by ToolID) so a new tool cannot forget it. Explanations and Show Work start collapsed across Field and Toolkit so the tool stays in focus.

Toolbox tiles draw the approved retro CRT set (`Assets.xcassets/Retro/<ToolID>`, original color, nearest-neighbor) through `IconWell` — grid, Pinned strip, shelf cards, search, favorites, related tools, and the tool header. Vector `ToolGlyph` remains the fallback for hidden `powerWizard`, which has no shipped tile. Every live grid tool has one. Category shelf marks stay vector. SF Symbols stay on chrome.

### Calculation modes

`ToolCalculationPolicy` / `ToolDefinition.calculationMode` is the single source of truth:

- **Live** — Unit Converter, Resistor Color, Circular Mils, Modbus Address, Number Base Converter: update when inputs are valid.
- **Explicit** — multi-input engineering tools: require **Calculate**; preserve the last success as stale while inputs change (“Inputs changed — Calculate again.”).
- **Sensor** — continuous / permission-gated instruments.

Session state (`ExplicitCalculationState`, `LiveCalculationState`) is pure Swift in BeckifyMath and covered by XCTest.

## Layout

```text
ios/
  Beckify.xcodeproj/     Xcode 15+ project — schemes Beckify, LookCheck, KestrelHeavy, BeckifyDrive
  Beckify/               SwiftUI Toolbox app (Calculators + Sensors)
  LookCheck/             Standalone Look Check App Store app (`com.beckify.lookcheck`)
  KestrelHeavy/          Standalone Kestrel Heavy App Store app (`com.beckify.kestrelheavy`)
  BeckifyDrive/          Standalone Beckify Drive app (`com.beckify.drive`) — OBD dashboard + CarPlay
  BeckifyMath/           Pure-Swift math + NEC tables + look-check JSON + XCTest
  docs/APP_STORE.md            Toolbox listing copy and App Store Connect checklist
  docs/FIVE_STAR_READINESS.md  Competitor 1★ patterns, review-ask policy, pre-submit gate
```

## Field (jobsite — opens first)

`ToolHomeAreaPolicy` owns home area + shelf. Toolbox home lists short shelf cards (Jobsite, Power, Instruments, …) that open a dedicated grid — not one long root LazyVGrid — so Field/Toolkit browsing stays stable when scrolling, starring, searching, or returning from a tool. Field home (not while searching) still shows a Pinned strip of pinned Field tools: Voltage Drop, Wire Size & Ampacity, Motor FLA, Receptacle Selector, Wi-Fi Path, Conduit Fill.

### Jobsite

- Voltage Drop. **NEC (default):** K-factor VD, parallels, target %, ampacity check, optional ampacity→VD handoff; 1Ø and 3Ø also show a NEC 2023 Table 250.122 EGC from the next standard OCPD. **AS/NZS:** metric mm² sizes, resistance-only drop from IEC 60228 maximum R (reactance omitted — not an AS/NZS 3008 mV/A·m table), AS/NZS 3000:2018 Clause 3.6.2’s 5% installation limit, and a copper earth from Table 5.1. Current-carrying capacity is not checked on the AS/NZS path. Design aid — not a PE or AEE stamp.
- Conductor Cost Optimizer (compliant size × parallel-run ranking with a planning book $/kft, per-line or uniform overrides, and optional I²R energy — not a live quote). Opt-in Include recommended EGC adds one NEC 2023 Table 250.122 ground per run into first-cost and suggested EMT. Design aid.
- Conductor Length by Resistance (length from a milliohm / mΩ reading — end-to-end or short-to-parallel; Cu/Al α compensation; estimated metal weight)
- Conduit Fill (same-size or mixed Chapter 9 fill; EMT and other Table 4 raceways, including the current EMT bores from 2½ in up). The result draws a to-scale cross-section: wall, each conductor, ID / OD / wire OD / free area, a fill bar for the nipple or longer run, and an optional Reference Library phase tint. Pinch to zoom. Share saves a PNG. Packing is illustrative and is not a jam check. Insulation names such as THHN / THWN-2 stay on their own full-width row. 1Ø, multiwire, or 3Ø plus amps shows the NEC 2023 Table 250.122 size beside the fill as soon as the amps are entered. That conductor is added only if you turn Count EGC on. When Settings is AS/NZS, Appendix C C6.2 is guidance beside the NEC pass/fail. Metric bores are not listed.
- Equipment Grounding (Field, next to Conduit Fill). Dedicated NEC 2023 Table 250.122 minimum EGC from the OCPD rating, copper or aluminum, with an optional ungrounded size for the 250.122(A) cap and 250.122(B) note. The same helper feeds Conduit Fill, Panel Directory (main rating), and Cable Schedule (optional power OCPD). AS/NZS protective earth is Table 5.1 on Voltage Drop — this tool says it is still showing NEC.
- Flexible Cable Ampacity (Field, next to Conduit Fill and Equipment Grounding). Type W and SO / SJO / STO portable cord from NEC Table 400.5, one or more conductors, size pick up to 400 A. THHN in conduit stays on Wire Size & Ampacity. Short install notes cover cord grip vs raceway and when NEMA/IP or conduit type matters — they do not assign an enclosure. Aluminum and the Type W 60/75°C columns are not transcribed. Planning aid; AHJ and manufacturer prevail.
- Cable Ladder (Field, next to Conduit Fill). Article 392 fill for ladder, ventilated trough, solid bottom, or channel, plus a NEMA VE 1 hanger check and a cross-section. AWG rows reuse Chapter 9 Table 5. Optional phase, neutral, and EGC tints match Reference Library color names and are a legend only. NEMA 250, IP wording, and the conduit chip describe the box and the drop. Planning estimate — verify the manufacturer load table and the AHJ. Not a PE stamp. AS/NZS cable-tray rules are not in this tool.
- Motor FLA (430.248 / 430.250)
- Motor Speed & Torque (sync RPM, slip, shaft torque)
- Motor Nameplate Analyzer (430.32 overload, Table 430.52 SCPD, 430.22 conductor, code-letter LRA)
- Motor Nameplate OCR (camera or library photo; on-device flatten and contrast lift, then multi-pass Vision, then heuristic field extract into the shared nameplate schema — value + confidence + reviewed; a low scan-quality score asks for a retake. Human confirm sets reviewed. Optional Analyze POSTs to `/api/analyze-nameplate` only when you tap it. MOCP and LRA are never treated as FLA. Optional seed into FLA / Analyzer / Speed)
- Look Check (camera or library photo, then Analyze Look for honest Photo assessment / Photo scores (lighting / framing / expression / sharpness) plus a surprise roast. Entertainment only — not medical, dating, or beauty authority. The photo stays on this device until you tap Analyze Look. Same `/api/analyze-look` contract as the website. Distinct from the Wi-Fi / Cellular **Online / Captive** hotspot-detect card.)
- Wire Size & Ampacity (310.16 with ambient, CCC, termination cap, continuous load, and a to-scale conductor cross-section). Construction (THHN/XHHW/RHW) is separate from the 60/75/90 °C columns. Circuit defaults to phase conductors only. Choosing 1Ø, multiwire, or 3Ø shows a NEC 2023 Table 250.122 EGC beside the phase size (provisional until OCPD is entered).
- Receptacle Selector (NEMA / IEC 60309 / international household / Meltric through 400 A, schematic pinout, cited public PNs — design aid). AS/NZS ranks AS/NZS 3112 Type I ahead of other household faces near 230 V. The list is not copied into a second tool.
- Short-Circuit Current, Circular Mils, Load & Demand Factors
- NEC Circuit Calculator (design current, derated conductor, VD, OCPD — live one-shot calc, not paperwork). When phase and amps imply a feeder ground, a NEC 2023 Table 250.122 EGC is shown. A service grounding electrode conductor is Table 250.66, not this row.
- IS Loop Verifier (Entity Concept Voc/Isc/Ca/La vs device + cable)

Wire Size & Ampacity, Flexible Cable Ampacity, Conduit Fill (including the Count EGC toggle), Cable Ladder, Equipment Grounding, Motor FLA, Conductor Cost, Conductor Length, NEC Circuit, Load Calculation Worksheet, and Motor Nameplate Analyzer stay on their NEC tables when AS/NZS is selected. The banner names that. Conduit Fill also shows the AS/NZS 3000 Appendix C C6.2 space factor as guidance and does not relabel the pass/fail. Equipment Grounding does not relabel Table 250.122 as an AS/NZS earth.

### Power (facility / distribution only)

- Power (DC identities + 1Ø / 3Ø). The formulas do not change with code. AS/NZS shows the nominal supply as 230 V single-phase and 400 V three-phase at 50 Hz. ToolID.powerWizard remains for saved jobs and is not listed.
- Three-Phase Power (Field → Power, beside Power). Balanced Y–Y, Y–Δ, Δ–Y, and Δ–Δ. Wye: V_LL = √3 Vφ and I_L = Iφ. Delta: I_L = √3 Iφ and V_LL = Vφ. P = √3 V_LL I_L cos θ, Q, and |S| = √3 V_LL I_L, with S = P + jQ. Connection diagram, line and phase arrows, and a power triangle. 480 V class defaults. A delta load is solved as Z ÷ 3. Line ohms are one conductor. AS/NZS keeps the same identities and shows 400 V at 50 Hz.
- Transformer Sizing & Protection (NEC 450.3(B) + Note 1). Connection notes cover Δ–Y, Y–Δ, Δ–Δ, Y–Y, open delta, zig-zag, isolation, autotransformer, and buck-boost, plus high-leg, corner-grounded delta, ungrounded delta, grounded wye, and high-level resistance/reactance grounding notes. The winding and phasor diagram labels common North American conductor colors as code or practice; the AHJ and the project spec win. Secondary Z refers to the primary as Z × (Np/Ns)², with the √3 winding adjustment on a mixed Y/Δ bank. A line-loss comparison holds the same load watts with and without the step-up. The step-up is ideal; transformer loss is not included. R is one conductor. AS/NZS transformer protection is not in this tool; the screen says it is still showing NEC. Same ToolID.transformer.
- Tap-Changer Calculator (DETC tap from measured secondary)
- Power Factor Correction
- Harmonics (THD) (current THD / IEEE 519 discussion bands)
- Battery Bank Sizing
- Solar Design Wizard (PV sizing, phone IMU/compass aim, optional storage)
- UPS / On-site Power (kVA, runtime, battery Ah)

### Controls

- Signal Scaling, Modbus Address, PLC Timer Preset
- E-Bus / Rack Current
- Control Systems (Field → Controls hub: plant library + custom G(s), P→PI→PID step with Ziegler–Nichols and Open/P/PI/PID overlay, Bode margins, lead compensator; educational — not commissioning)
- Control Strategies (same shelf: matrix of bang-bang, PID / gain-scheduled PID, MPC, fuzzy, sliding mode, DRL, ADRC, and NN / PINN / ML-MPC; linear vs nonlinear, SISO vs MIMO, <1 ms vs >1 s; HVAC / drives / robotics / flight / BMS examples; constraint picker. Planning plots only — not a tuner and not a trained policy. PID / Bode stays in Control Systems)
- Phasors & Impedance (same shelf): sine or cosine, lead and lag, a quick sum of 2–3 phasors, peak phasors in rectangular, polar, and exponential form, R / L / C laws, and series Z = R + jX with Y = 1/Z. Time waveforms label voltage (V) and time (s). Rotating phasors, the R–X plane, an optional admittance plane, and an XL / XC sweep. Ideal lumped parts at one frequency — not SPICE. The older Phasor Diagram is that quick sum, not a second home-screen tool.
- UL 508A Panel Lab (same shelf: SCCR planning with marked ratings or Table SB4.1-style assumed defaults, feeder and branch sizing that reuses Motor FLA, internal wire ampacity, a NEMA/IP enclosure picker with conduit and wire-type suggestions, control-transformer branch sizing, a nameplate checklist, and North American conductor-color conventions with an IEC note when AS/NZS is selected. Shop planning aid — official UL 508A, NFPA 79, the Code, the spec, and the AHJ win. Not a UL certification.)
- Switchgear Logic Lab (same shelf): offline programmable switchgear logic — map signals and breakers, run transfer scenarios with timing/explanation traces, Analyze (static lint, settled-state enumeration, latch and timer checks), autosave on device, and share JSON / CSV / HTML review packages via the system share sheet. Same engine as the website tool. Design aid — not a protection certification, not a PE stamp, and never a vendor-loadable settings file.

### Magnetics & Fields

- Magnetics Lab (Field shelf). Series core or three-leg core: reluctance, flux, ampere-turns, inductance, and stored energy. Air gap, fringing, and stacking are inputs. The path sketch labels flux and the coil. MMF, flux, and reluctance follow volts, amps, and ohms. A machine check uses that same field for a shared-flux transformer link, force on one conductor, or motional emf on one conductor. Linear µr. Saturation and leakage are called out, not modeled. Not a finite-element run and not a full machine design. The older Magnetic Circuit card stays on Toolkit → Bench.
- EM Fields (same shelf). Induced emf from flux change through a loop, with the current direction that opposes the change. Point charges in a plane: vector sum of E, force on a test charge, and a flag when the sum is nearly zero. Lorentz force F = q(E + v × B) as a straight push or a curve — an arc radius only when B dominates and a mass is entered. Vector check: Cartesian, cylindrical, and spherical; dot, cross, projection, and unit vectors; four sample fields for divergence and curl. Not a particle tracker and not a general derivative solver.

### Analysis

- Statistics (Field → Analysis). One tool: distributions (normal, uniform, exponential, binomial, Poisson) with a seeded draw beside the formula, Y = aX + b, a paired normal with a condition on X, covariance and aX + bY, and exact two-dice counts. Conditional mean and spread for the normal pair are closed form. The conditional chance is a numerical integral. Histograms and scatters are Monte Carlo. Defaults of 500 and 100 are example scores only — not an official College Board tool.

## Toolkit (basics, bench, reference)

### Basics

- Ohm's Law
- Voltage Divider (Vout, or solve R1/R2)
- Series / Parallel R and C
- Resistor Color Code (4-band and 5-band, decode + encode)
- Frequency / period / wavelength and LC resonance
- LED current-limit R and RC τ (555 astable/monostable stays in 555 Timer)
- Unit Converter (SI prefixes, dB, °C/°F, m/ft, mils/mm)
- 555 Timer (astable / monostable)

### Bench

- Electronics Lab: schematics for passive DC, RC/RL/RLC, diodes, BJT, MOSFET, op-amps, 555, LED/7-segment, a discrete CE stage and op-amp load stage, linear drop, and an ideal buck, plus complex conversion, L-match, quarter-wave, and stub length. Node voltages and branch currents use A / mA / µA (and matching SI for V), labeled on the schematic and on Breadboard meters. Solve-any-value, plus a Vin/Vout or Bode trace and a transfer function when the stage is linear. Breadboard opens fit-to-view for resistors (series/parallel/divider/Kirchhoff/Thevenin), RC/RL/RLC/filter, LED, half-wave/full-bridge/clipper/clamper, BJT/CE/MOS/CS/CMOS, 741 stages (inverting through comparator), 555, 7-segment, and linear drop, with shared annotation layers and a searchable inspector. Illustrative hookup — not a SPICE board file. Other circuits stay on the schematic. Rectifier, first-order filter, series RLC, and shunt clipper switch DC or an AC sine and edit Vdc, Vrms, or Vp. The schematic marks a sine for AC and a plus for DC. Strictly DC circuits stay a single DC source. Ideal models — not SPICE.
- Reactance & Resonance, Magnetic Circuit
- Transient Circuits (RC/RL charge/discharge + curve)
- Fiber Link / NA (numerical aperture, acceptance angle, V-number)
- Gaussian Beam (Rayleigh range, divergence, beam radius)
- Semiconductor I-V (Shockley forward current + I–V curve)
- Analog Design Workbench (op-amp golden-rule stages, RC / Sallen–Key filters, ideal Bode sketch)
- Noise & SNR (Johnson, optional shot, amp e_n / i_n, SNR, rough NF)
- Linear / LDO Regulator (LM317-style Vout, dropout, Pd, θJA → Tj)
- Instrumentation Amp (3-op-amp G = 1 + 2R/Rg, or 4-resistor difference amp)
- ADC / DAC & Sampling (LSB, quantization SNR, Nyquist, optional DAC code-to-voltage)
- RF Power & Link, Number Base Converter
- Heater Design Wizard (resistive heater current, leg R, element wire length)
- Solenoid Design Wizard (winding pack, B/L/force plots, copper loss)
- EMP / EMC Shielding (skin depth, sheet SE, Faraday loop, aperture — protection-side educational)
- E-Bike Torque / RPM (shaft torque or RPM from W / kW / hp)
- Sprocket Ratio Designer (drive/driven teeth, output RPM/torque, optional wheel speed, or invert a target)
- Range Estimator (pack V×Ah and Wh/mi → miles, km, runtime)
- Battery Pack Designer (S×P planning from a voltage/current target or a known layout — design aid, not a BMS/weld cert; Battery Bank Sizing stays the Field → Power runtime/DoD tool)
- Nickel Strip (cross-section × planning current density)

### Reference

- Reference Library (NEMA, IP, colors, hazardous areas, insulation, torque, conduit, standard sizes)
- Crew Talk (was Spanish Translator; tool id stays spanishTranslator). English → Spanish or Spanish → English. Record, type, Hey! on the English side, quick chips, or Test → Beckify AI `/api/translate` (Jobsite wording under the hood; Clean/Jobsite off this screen), or on-device Apple Translation in that direction on iOS 18+. Pick Bodie Hale (California beach English), Tito Solano (Cuban jobsite Spanish), Junie Pell (rural Alabama English), Pearl (warm English that softens a blunt ask and still makes it), or Sloane Merritt (polished HR lead who turns a blunt ask into a meeting). Every helper rewrites into a real line in their voice on device (ask stays; no stock opener glued on; slurs/insults not echoed; Sloane stays meeting-speak even when rude). The dock shows the other language; a short dialect helper sits under it for English helpers; Speak plays that dock string (speak language follows direction). Junie's speak is thicker on the same voice. One Done on the keyboard; text field and answer stay above it. That full-body 16-bit sprite stays on screen. While audio plays it holds the idle frame and flashes the talk pose on a short syllable beat, with a small bob. Pixels stay nearest-neighbor. Speak POSTs that ElevenLabs voice id and model `eleven_v3` to api.beckify.com `/api/speak`. The API key stays on the server. Apple AVSpeech if cloud TTS fails. Copy Audio / Share Audio keep that clip (temporary file only). Mic audio is not uploaded; after a successful Beckify AI translate, the short line for the selected person may POST to `/api/speak`.
- Panel Directory (camera or library photo stays on screen; local OCR default — flatten, contrast lift, multi-pass Vision, then a fuzzy grid into an editable schedule — circuit, name, trip, poles, class. Directory / Nameplate / Deadfront roles; Needs review / Conflict / Verified (not a calibrated %). Conflict queue; inferred numbers and incomplete coverage stay visible. Optional Analyze POSTs to `/api/analyze-panel` only when you tap it. Confirming the schedule is not measured load — no capacity-to-add from trips alone; trip-as-conservative-connected is a labeled scenario. Worksheet handoff previews merge or replace into Load Calculation Worksheet with provenance. FLA and kAIC reads are not measured.)
- Load Calculation Worksheet (NEC 220.42 lighting demand + category VA)
- Cable Schedule Generator (sequential IDs + CSV copy)

Selected existing calculators show **engineer plots** (Swift Charts) and can **Share / save a PNG** through the system share sheet. Examples already in this catalog: Ohm's Law load line, Frequency / LC waveform, LED / RC charge–discharge, Reactance & Resonance, Transient Circuits, Semiconductor I-V, Phasor Diagram, 555 Timer monostable capacitor charge, Analog Design Workbench Bode magnitude, Control Systems step / PID overlay / Bode / lead, and Control Strategies step / hysteresis / sliding-mode / cost sketches. Cartesian plots use axis titles with units, open full screen, and pinch-zoom with a value readout when the curve is dense. Packing diagrams keep dimension labels; Cable Ladder’s cross-section can pinch larger in full screen. Schematics, gauges, and the Wi-Fi floor plan open full screen without a fake X–Y title. This is not a new tool list.

## Instruments (Field subsection — public APIs only)

- Wi-Fi Path leads with **Online / Captive** (HTTP GET to Apple’s `captive.apple.com/hotspot-detect.html` — Success means no captive splash). Then Apple `signalStrength` 0…1 as percent/bars when `NEHotspotNetwork` returns it, optional local IPv4 from the probe’s Network `localEndpoint`, coverage heatmap, and TCP **link quality (RTT)** to the path gateway or a host such as 1.1.1.1 / beckify.com. Raw `NWPathMonitor` chrome (interface names like `en0` / `pdp_ip0`, expensive/constrained) sits behind a collapsed **Advanced path** disclosure. iOS does not expose Wi-Fi RSSI/dBm to third-party apps; this tool does not invent dBm. RTT is TCP connect time — not ICMP ping. A LAN/gateway target may prompt for Local Network. Online / Captive is a public-host HTTP probe and does not need Local Network. It is not the catalog **Look Check** photo tool.
- Cellular Path reuses the same **Online / Captive** probe, then `CTTelephonyNetworkInfo` carrier / MCC / MNC / ISO / RAT per service, `dataServiceIdentifier`, Network default + cellular path flags (collapsed under Advanced path), `CTCellularData`, and optional TCP **link quality (RTT)** while on cellular. Color gauges show **radio generation** (2G…5G from RAT) and **RTT milliseconds** — not RSRP/dBm. iOS does not expose cellular RSRP/RSRQ/SINR/dBm to third-party apps; this tool does not invent them. CTCarrier is deprecated as of iOS 16 with no public replacement.
- BLE Scanner (CoreBluetooth): advertised name, identifier, RSSI, SIG manufacturer company ID, connectable, service-data UUIDs, kind hints, live radar, plus RF activity index, room mix, and device-ID churn (unique IDs — not occupancy). Device count ≠ people.
- Noise Meter (microphone dBFS, uncalibrated, plus a live audible FFT). Same MicrophoneSpectrum tap as Acoustic Imager and RigScope. Shows fs, Nyquist, and a rough relative harmonic note — not THD, not dB SPL, not a nameplate. Freeze holds the plot. Share saves a PNG with a timestamp, not audio and not GPS.
- Acoustic Imager (Field → Instruments, next to Noise Meter). On-device microphone FFT: relative level, audible spectrum, and recent time activity. Not a Fluke acoustic camera, not ultrasonic beamforming, and not a leak locator. Audio is processed on this device, is not recorded, and is not uploaded. Same microphone usage string and the same MicrophoneSpectrum tap as Noise Meter and RigScope.
- RigScope (Field → Instruments, next to Noise Meter and Acoustic Imager; search still finds “setup check”, “room & rig”, or “RigScope”). Pick Music / Movies / Gaming (future score targets — not scored yet). Leave it open while music or a test signal plays — the meters and labeled plots stay live. Start test captures about 8 seconds (pink noise, a log sweep, tone bursts, or whatever is already playing) and explains relative level, peak, crest, clipping, level above the quiet floor, peak frequency, spectral centroid, and low/mid/high balance. Keep a pass as spot A and compare the next one. Axes are frequency, relative dBFS, and time. Not a calibrated measurement mic, not REW, not THX, and not absolute dB SPL. Most iPhones expose one mic path, so stereo balance stays blank. Share saves a PNG with a timestamp, not audio. Same microphone usage string.
- Bubble Level / plumb (CoreMotion)
- Magnetometer (heading, µT) with Mag Sweep: |B| minus a captured baseline, peak hold, and a sparkline. A slow field-variation spectrum is DC |B| only — not AC EMF and not a 50/60 Hz meter. Phone magnets dominate.
- Barometer / relative altitude
- Stillness Anomaly Watch: baseline ticks for DC |B|, pressure, mic impulses, and BLE advertiser changes, plus a timeline. “Phone moved” is a bump gate, not an anomaly. Not a ghost detector, presence meter, EMF meter, or people counter. Audio is not recorded.
- g-Force snapshot
- Coupled Vibration: user-acceleration RMS and a spectrum up to the delivered Nyquist (not a claimed 0–400 Hz band), peak frequency, relative RPM (f × 60, phone-mounted), and session A/B. Not ISO 10816, not a calibrated pickup, not a tachometer, and not a bearing-fault tool. Distinct from g-Force Snapshot.
- Position (location requested in-tool, not at launch)
- Device Health (charge, Low Power Mode, thermal meaning, free storage, model / iOS, uptime — not Battery Health %)

Field → Instruments plot notes name the axes. Coupled Vibration A/B bars are frequency bands with height |B − A| (the readout keeps the sign in g; not ISO 10816). Noise Meter’s rough-harmonics line is leftover energy outside the loudest bin (not THD, not dB SPL). RigScope’s Listening card explains crest, harmonics, loop delay, signal above background, and relative range. Acoustic Imager time activity reads left as lower frequency and bottom as newer. Catalog tools are unchanged.

Local **Saved Jobs** are on-device bench / field notes, not a synced projects product. Field jobs sort first. Standards-aware notes retain the applicable code path and its scope alongside inputs and results. Use **Jobs → Transfer notes** to export or import a versioned JSON archive; imports validate the complete file, preserve existing notes when IDs collide, and stay on device unless you explicitly choose a file destination or source. Opening a job restores matching inputs into the tool when they still map — it does not block if some fields cannot be restored. Each tool keeps last-used inputs on device, copies a numeric result, lists related tools from the same catalog, can reveal the formula with your numbers plugged in, and has a **How it works** note (toolbar About / collapsed disclosure) for what it computes, when to use it, and its limits. Explanations and formulas start collapsed so inputs and results stay primary. Tap the star on any tool (in the list or its toolbar) to pin it to the **Favorites** tab for one-tap access. Disclaimer on every tool: design aid, not a PE stamp or calibrated instrument. No ads, analytics, tracking, or phone number. Calculators stay free. Settings has optional StoreKit tips (consumable). No Stripe. A hosted share link is not charged.

## Linux (this repo)

Math tests do not need Xcode:

```bash
cd ios/BeckifyMath
swift test
```

You cannot build or run the app UI, CoreMotion, AVFoundation, or CoreBluetooth on Linux. Simulator, signing, archive, and App Store upload require a Mac. This repository does not claim those happened. The electrical-code Settings screen and in-tool banners were not exercised in Simulator or on a device.

Accessibility and field-use verification steps are tracked in [`docs/ACCESSIBILITY_QA.md`](docs/ACCESSIBILITY_QA.md). Complete them on Simulator and physical iPhone/iPad before claiming those checks passed.

## Mac — open and run

1. Install Xcode 15 or later.
2. Open `ios/Beckify.xcodeproj`.
3. Select the **Beckify** scheme (Toolbox), **LookCheck** (standalone roast app), **KestrelHeavy** (standalone arcade), or **BeckifyDrive** (OBD dashboard and CarPlay).
4. Select an iPhone or iPad simulator.
5. Signing: Debug and Release set `DEVELOPMENT_TEAM` to `9TR6R5LV8M` (Apple’s team prefix at identifier registration). Confirm that Team in Signing & Capabilities on a Mac.
6. Run.

### xcodebuild (unsigned compile check)

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -scheme Beckify \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Standalone Look Check (same project, **LookCheck** scheme):

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -scheme LookCheck \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Beckify Drive (same project, **BeckifyDrive** scheme — native CarPlay templates, not a web view). A signed device build needs the driving-task entitlement on `com.beckify.drive` first. See [`BeckifyDrive/docs/APP_STORE.md`](BeckifyDrive/docs/APP_STORE.md).

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -scheme BeckifyDrive \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Standalone Kestrel Heavy (same project, **KestrelHeavy** scheme — local Phaser pack, not beckify.com):

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -scheme KestrelHeavy \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Refresh the packed cabinet after arcade changes:

```bash
python3 ios/scripts/pack_kestrelheavy_game.py
```

### Archive → TestFlight (scheme Beckify only)

Push to `main`. Xcode Cloud then starts both Toolbox workflows:

1. `Beckify | Beckify | Build - iOS`
2. `Beckify | Beckify | Archive - iOS`

**Archive - iOS** is the TestFlight path. It must archive scheme **Beckify** (`com.beckify.toolbox`, App ID `6807908745`). A green archive is what App Store Connect can process for TestFlight. This repo does not submit that build.

Do not point either workflow at **LookCheck** (`com.beckify.lookcheck`), **KestrelHeavy** (`com.beckify.kestrelheavy`), or **BeckifyDrive** (`com.beckify.drive`). Those products keep their own Archive schemes and bundle IDs. Beckify Drive does not change Toolbox marketing **1.0.3** / build **251**.

Connect version **1.0.3** exists (Trevor created it; **1.0** and **1.0.1** are closed — Connect rejected **1.0.1 (160)** with ITMS-90186 / ITMS-90062). **1.0.2** hit **ITMS-90382** on build **230** (~2026-10-01). Repo `MARKETING_VERSION` is **1.0.3** and `CURRENT_PROJECT_VERSION` is **251**. Xcode Cloud Build and Archive on **174** failed to compile `PhasorImpedanceView.swift` and `PlotChrome.swift` and did not upload. Xcode Cloud Build - iOS on **164** failed to compile `SpectrumPlot.swift` (`showsRelativeDBFSScale` captured by a closure before initialization) and did not upload. Build **163** failed earlier on `BreathFluteView.swift` (`supportedPolarPatterns` is optional). Archive of **158** and **159** compiled and failed while preparing the App Store Connect upload. Next Archive binary is **1.0.3 (251)** (must be **>230**). A higher build on **1.0.1** will not upload.

#### Mac fallback

On a Mac, open `ios/Beckify.xcodeproj`, select scheme **Beckify**, confirm Team **9TR6R5LV8M** (already `DEVELOPMENT_TEAM` on the Beckify target), then **Product → Archive**. Distribute that archive to App Store Connect from Organizer. Or:

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -scheme Beckify \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Beckify.xcarchive \
  DEVELOPMENT_TEAM=9TR6R5LV8M \
  archive

xcodebuild \
  -exportArchive \
  -archivePath build/Beckify.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

`ExportOptions.plist` is not in this repo. Create one on the Mac only if you export with `xcodebuild -exportArchive` instead of Organizer. See `docs/APP_STORE.md`.

This Linux checkout did not run `xcodebuild`, sign a binary, install the app on a device, or upload to TestFlight. Do not treat a docs or source change as a green Archive.

## What still needs a Mac + Apple login

App Store Connect already has a Beckify record: App ID `6807908745`, bundle ID `com.beckify.toolbox`, SKU `beckify-toolbox`, privacy URL https://beckify.com/privacy (live). Price stays free to use, no ads. Optional tips in Settings are the only in-app purchases. Calculators are not paywalled. **Version 1.0 is approved** — that train is closed (**ITMS-90186** / **ITMS-90062**; Transporter rejected **1.0 (121)**). **Version 1.0.1 is also closed:** App Store Connect rejected **1.0.1 (160)** (**ITMS-90186** train '1.0.1' closed for new builds; **ITMS-90062** short version must be higher than approved **1.0.1**). Bumping the build number on **1.0.1** will not fix that. TestFlight already had **1.0.1 (149)** as of ~2026-09-17/18 (Trevor; this repo did not query App Store Connect). Connect version **1.0.3** exists (Trevor created it); next binary **1.0.3 (251)** (repo `MARKETING_VERSION` **1.0.3**, `CURRENT_PROJECT_VERSION` **251**). **1.0.2** hit **ITMS-90382** on build **230** (~2026-10-01); repo was **1.0.2** / **216**. If the Archive - iOS workflow’s next build number is not the project version, set it to **251** or higher in App Store Connect. Archive the **Beckify** scheme, not LookCheck, KestrelHeavy, or BeckifyDrive. Look Check stays **1.0 (1)**; Connect/TestFlight exists as **LookCheck5000** (Xcode display name **Look Check**; Archive scheme **LookCheck** — do not rename). Kestrel Heavy repo build is **1.0 (4)** and a TestFlight record exists — if TestFlight already has **≥4**, bump before the next Archive, otherwise the next binary is **1.0 (4)**. This Linux environment did not compile, sign, or upload **1.0.3 (251)**.

- Compile the SwiftUI target and exercise the UI on Simulator / device
- Create signing certificates / profiles for team `9TR6R5LV8M` on a Mac
- Run on a physical device at least once if not already done
- Trevor: accept the Apple Developer Program License Agreement (DPLA) if Connect still requires it
- Capture App Store screenshots at the required sizes
- Signed archive, upload, then listing screenshots / submit for review

This repository does **not** submit anything to the App Store.
