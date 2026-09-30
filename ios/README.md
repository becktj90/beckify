# Beckify iOS

Native SwiftUI field EE toolbox for iPhone and iPad. Bundle ID `com.beckify.toolbox`, display name **Beckify**, iOS 17+.

Three more App Store products live in the same Xcode project: **Look Check** (`com.beckify.lookcheck`) — camera/library, Analyze, surprise roast — **Kestrel Heavy** (`com.beckify.kestrelheavy`) — a native SwiftUI shell that plays the Phaser 4 arcade from a local bundle — and **Beckify Drive** (`com.beckify.drive`) — a Bluetooth LE OBD-II dashboard with a native CarPlay scene. None of them is this toolbox. See [`LookCheck/README.md`](LookCheck/README.md), [`KestrelHeavy/README.md`](KestrelHeavy/README.md), and [`BeckifyDrive/README.md`](BeckifyDrive/README.md).

> **Archive / Xcode Cloud:** Archive-iOS and any Xcode Cloud Archive workflow for Toolbox **must** use scheme **Beckify** (`com.beckify.toolbox`). Do **not** archive Toolbox with scheme **LookCheck** or **KestrelHeavy**. Those are separate ASC apps with their own Archive schemes. Keep Archive workflows separate. Kestrel Heavy is not a Toolbox catalog game; the website `/games/kestrel-heavy` stays.

Home is two areas — **Field** (jobsite, first) and **Toolkit** (basics, bench homework, references) — not a flat grid of every tool. Search covers both and labels the area. Sensors live under Field → Instruments. Field home (not while searching) shows a **Quick** strip: Voltage Drop, Wire Size & Ampacity, Motor FLA, Receptacle Selector, Wi-Fi Path, Conduit Fill.

**Settings** (gear on Toolbox, Favorites, and Saved Jobs) stores the electrical code, length units, and appearance on device. Default code is **NEC (US)**. **AS/NZS** is the other selectable code. IEC 60364, CEC, and BS 7671 are named and not selectable. Tools are not duplicated per code. Where AS/NZS tables are not in the app, the tool says **“AS/NZS not available for this tool yet — showing NEC”** and keeps the NEC result labeled as NEC. Appearance defaults to the system (light or dark). It does not force dark mode.

This is not a website wrapper. There is no `WKWebView` of beckify.com and no website project gallery. Calculator and sensor math helpers live in a pure Swift package so they can be tested on Linux without Xcode. Website toolbox IA is a follow-up, not this app.

## Design system

Reusable tokens live in `Beckify/Theme/Theme.swift` (surfaces, semantic accents, spacing, radius, stroke, typography, chart colors, motion). Calculator chrome — identity header, Calculate / Reset / Example, stale-result banner, diagrams, and the shared **How it works** disclosure — lives under `Beckify/Views/Components/`. About copy is data-driven in `BeckifyMath` (`ToolHowItWorksCatalog`, keyed by ToolID) so a new tool cannot forget it. Field stays collapsed / inputs-first; homework tools default open like Show Work.

Every primary tool has an original vector `ToolGlyph` (not a shared SF Symbol).

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

`ToolHomeAreaPolicy` owns home area + shelf. Field home (not while searching) shows a Quick strip of pinned jobsite tools: Voltage Drop, Wire Size & Ampacity, Motor FLA, Receptacle Selector, Wi-Fi Path, Conduit Fill.

### Jobsite

- Voltage Drop. **NEC (default):** K-factor VD, parallels, target %, ampacity check, optional ampacity→VD handoff; 1Ø and 3Ø also show a NEC 2023 Table 250.122 EGC from the next standard OCPD. **AS/NZS:** metric mm² sizes, resistance-only drop from IEC 60228 maximum R (reactance omitted — not an AS/NZS 3008 mV/A·m table), AS/NZS 3000:2018 Clause 3.6.2’s 5% installation limit, and a copper earth from Table 5.1. Current-carrying capacity is not checked on the AS/NZS path. Design aid — not a PE or AEE stamp.
- Conductor Cost Optimizer (compliant size × parallel-run ranking with planning $/kft and optional I²R energy — not a live quote)
- Conductor Length by Resistance (length from a milliohm / mΩ reading — end-to-end or short-to-parallel; Cu/Al α compensation; estimated metal weight)
- Conduit Fill (same-size or mixed Chapter 9 fill; EMT and other Table 4 raceways). Insulation names such as THHN / THWN-2 stay on their own full-width row so the label does not crush. 1Ø, multiwire, or 3Ø plus amps shows the NEC 2023 Table 250.122 size beside the fill as soon as the amps are entered. That conductor is added only if you turn Count EGC on — mixed fill math is otherwise unchanged.
- Equipment Grounding (Field → Jobsite, next to Conduit Fill). Dedicated NEC 2023 Table 250.122 minimum EGC from the OCPD rating, copper or aluminum, with an optional ungrounded size for the 250.122(A) cap and 250.122(B) note. The same helper feeds Conduit Fill, Panel Directory (main rating), and Cable Schedule (optional power OCPD). AS/NZS protective earth is Table 5.1 on Voltage Drop — this tool says it is still showing NEC.
- Flexible Cable Ampacity (Field → Jobsite, next to Conduit Fill and Equipment Grounding). Type W and SO / SJO / STO portable cord from NEC Table 400.5, one or more conductors, size pick up to 400 A. THHN in conduit stays on Wire Size & Ampacity. Short install notes cover cord grip vs raceway and when NEMA/IP or conduit type matters — they do not assign an enclosure. Aluminum and the Type W 60/75°C columns are not transcribed. Planning aid; AHJ and manufacturer prevail.
- Cable Ladder (Field → Jobsite, next to Conduit Fill). Article 392 fill for ladder, ventilated trough, solid bottom, or channel, plus a NEMA VE 1 hanger check and a cross-section. AWG rows reuse Chapter 9 Table 5. Optional phase, neutral, and EGC tints match Reference Library color names and are a legend only. NEMA 250, IP wording, and the conduit chip describe the box and the drop. Planning estimate — verify the manufacturer load table and the AHJ. Not a PE stamp. AS/NZS cable-tray rules are not in this tool.
- Motor FLA (430.248 / 430.250)
- Motor Speed & Torque (sync RPM, slip, shaft torque)
- Motor Nameplate Analyzer (430.32 overload, Table 430.52 SCPD, 430.22 conductor, code-letter LRA)
- Motor Nameplate OCR (camera or library photo; on-device flatten and contrast lift, then multi-pass Vision, then heuristic field extract into the shared nameplate schema — value + confidence + reviewed; a low scan-quality score asks for a retake. Human confirm sets reviewed. Optional Analyze POSTs to `/api/analyze-nameplate` only when you tap it. MOCP and LRA are never treated as FLA. Optional seed into FLA / Analyzer / Speed)
- Look Check (camera or library photo, then Analyze Look for a playful look verdict plus lighting / framing / expression / sharpness metrics and a roast. Entertainment only — not medical, dating, or beauty authority. The photo stays on this device until you tap Analyze Look. Same `/api/analyze-look` contract as the website. Distinct from the Wi-Fi / Cellular **Online / Captive** hotspot-detect card.)
- Wire Size & Ampacity (310.16 with ambient, CCC, termination cap, continuous load). Circuit defaults to phase conductors only. Choosing 1Ø, multiwire, or 3Ø shows a NEC 2023 Table 250.122 EGC beside the phase size.
- Receptacle Selector (NEMA / IEC 60309 / international household / Meltric through 400 A, schematic pinout, cited public PNs — design aid). AS/NZS ranks AS/NZS 3112 Type I ahead of other household faces near 230 V. The list is not copied into a second tool.
- Short-Circuit Current, Circular Mils, Load & Demand Factors
- NEC Circuit Calculator (design current, derated conductor, VD, OCPD — live one-shot calc, not paperwork). When phase and amps imply a feeder ground, a NEC 2023 Table 250.122 EGC is shown. A service grounding electrode conductor is Table 250.66, not this row.
- IS Loop Verifier (Entity Concept Voc/Isc/Ca/La vs device + cable)

Wire Size & Ampacity, Flexible Cable Ampacity, Conduit Fill (including the Count EGC toggle), Cable Ladder, Equipment Grounding, Motor FLA, Conductor Cost, Conductor Length, NEC Circuit, Load Calculation Worksheet, and Motor Nameplate Analyzer stay on their NEC tables when AS/NZS is selected. The banner names that. Equipment Grounding does not relabel Table 250.122 as an AS/NZS earth. Mixed conduit fill math is unchanged.

### Power (facility / distribution only)

- Power (DC identities + 1Ø / 3Ø). The formulas do not change with code. AS/NZS shows the nominal supply as 230 V single-phase and 400 V three-phase at 50 Hz. ToolID.powerWizard remains for saved jobs and is not listed.
- Transformer Sizing & Protection (NEC 450.3(B) + Note 1). Connection teach covers Δ–Y, Y–Δ, Δ–Δ, Y–Y, open delta, zig-zag, isolation, autotransformer, and buck-boost, plus high-leg, corner-grounded delta, ungrounded delta, grounded wye, and high-level resistance/reactance grounding notes. The winding and phasor diagram labels common North American conductor colors as code or practice; the AHJ and the project spec win. AS/NZS transformer protection is not in this tool; the screen says it is still showing NEC. Same ToolID.transformer.
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
- Control Strategies (same shelf: matrix of bang-bang, PID / gain-scheduled PID, MPC, fuzzy, sliding mode, DRL, ADRC, and NN / PINN / ML-MPC; linear vs nonlinear, SISO vs MIMO, <1 ms vs >1 s; HVAC / drives / robotics / flight / BMS examples; constraint picker. Teaching plots only — not a tuner and not a trained policy. PID / Bode stays in Control Systems)
- Electronics Lab (same shelf): college schematics for passive DC, RC/RL/RLC, diodes, BJT, MOSFET, op-amps, 555, LED/7-segment, a class-A and op-amp load stage, linear drop, and an ideal buck, plus complex conversion, L-match, quarter-wave, and stub length. Node voltages, branch currents, solve-any-value. Ideal models — not SPICE.
- UL 508A Panel Lab (same shelf: SCCR planning with marked ratings or Table SB4.1-style assumed defaults, feeder and branch sizing that reuses Motor FLA, internal wire ampacity, a NEMA/IP enclosure picker with conduit and wire-type suggestions, control-transformer branch sizing, a nameplate checklist, and North American conductor-color conventions with an IEC note when AS/NZS is selected. Shop planning aid — official UL 508A, NFPA 79, the Code, the spec, and the AHJ win. Not a UL certification.)

## Toolkit (basics, bench / homework, reference)

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

- Reactance & Resonance, Phasor Diagram, Magnetic Circuit
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
- Panel Directory (camera or library photo stays on screen; on-device flatten, contrast lift, and multi-pass Vision, then a fuzzy grid into an editable schedule — circuit, name, trip, poles, class — value + confidence + reviewed. A 0–1 scan-quality score can ask for a retake. Odd/even numbers may be inferred when the print is missing. Optional Analyze POSTs to `/api/analyze-panel` only when you tap it; confirm, then demand / capacity-to-add via the same 220.42 worksheet as Load Calculation Worksheet. Trip is not measured load. FLA and kAIC reads are not measured. Optional seed into Load Calculation Worksheet)
- Load Calculation Worksheet (NEC 220.42 lighting demand + category VA)
- Cable Schedule Generator (sequential IDs + CSV copy)

Selected existing calculators show **engineer plots** (Swift Charts) and can **Share / save a PNG** through the system share sheet. Examples already in this catalog: Ohm's Law load line, Frequency / LC waveform, LED / RC charge–discharge, Reactance & Resonance, Transient Circuits, Semiconductor I-V, Phasor Diagram, 555 Timer monostable capacitor charge, Analog Design Workbench Bode magnitude, Control Systems step / PID overlay / Bode / lead, and Control Strategies step / hysteresis / sliding-mode / cost sketches. Cartesian plots use axis titles with units, open full screen, and pinch-zoom with a value readout when the curve is dense. Packing diagrams keep dimension labels; Cable Ladder’s cross-section can pinch larger in full screen. Schematics, gauges, and the Wi-Fi floor plan open full screen without a fake X–Y title. This is not a new tool list.

## Instruments (Field subsection — public APIs only)

- Wi-Fi Path leads with **Online / Captive** (HTTP GET to Apple’s `captive.apple.com/hotspot-detect.html` — Success means no captive splash). Then Apple `signalStrength` 0…1 as percent/bars when `NEHotspotNetwork` returns it, optional local IPv4 from the probe’s Network `localEndpoint`, coverage heatmap, and TCP **link quality (RTT)** to the path gateway or a host such as 1.1.1.1 / beckify.com. Raw `NWPathMonitor` chrome (interface names like `en0` / `pdp_ip0`, expensive/constrained) sits behind a collapsed **Advanced path** disclosure. iOS does not expose Wi-Fi RSSI/dBm to third-party apps; this tool does not invent dBm. RTT is TCP connect time — not ICMP ping. A LAN/gateway target may prompt for Local Network. Online / Captive is a public-host HTTP probe and does not need Local Network. It is not the catalog **Look Check** photo tool.
- Cellular Path reuses the same **Online / Captive** probe, then `CTTelephonyNetworkInfo` carrier / MCC / MNC / ISO / RAT per service, `dataServiceIdentifier`, Network default + cellular path flags (collapsed under Advanced path), `CTCellularData`, and optional TCP **link quality (RTT)** while on cellular. Color gauges show **radio generation** (2G…5G from RAT) and **RTT milliseconds** — not RSRP/dBm. iOS does not expose cellular RSRP/RSRQ/SINR/dBm to third-party apps; this tool does not invent them. CTCarrier is deprecated as of iOS 16 with no public replacement.
- BLE Scanner (CoreBluetooth): advertised name, identifier, RSSI, SIG manufacturer company ID, connectable, service-data UUIDs, kind hints, live radar, plus RF activity index, room mix, and device-ID churn (unique IDs — not occupancy). Device count ≠ people.
- Noise Meter (microphone dBFS, uncalibrated, plus a live audible FFT). Same MicrophoneSpectrum tap as Acoustic Imager and Room & Rig Check. Shows fs, Nyquist, and a rough relative harmonic note — not THD, not dB SPL, not a nameplate. Freeze holds the plot. Share saves a PNG with a timestamp, not audio and not GPS.
- Acoustic Imager (Field → Instruments, next to Noise Meter). On-device microphone FFT: relative level, audible spectrum, and recent time activity. Not a Fluke acoustic camera, not ultrasonic beamforming, and not a leak locator. Audio is processed on this device, is not recorded, and is not uploaded. Same microphone usage string and the same MicrophoneSpectrum tap as Noise Meter and Room & Rig Check.
- Room & Rig Check (Field → Instruments, next to Noise Meter and Acoustic Imager; search still finds “setup check”). Leave it open while music or a test signal plays — the meters and labeled plots stay live. Start test captures about 8 seconds (pink noise, a log sweep, tone bursts, or whatever is already playing) and explains relative level, peak, crest, clipping, level above the quiet floor, peak frequency, spectral centroid, and low/mid/high balance. Keep a pass as spot A and compare the next one. Axes are frequency, relative dBFS, and time. Not a calibrated measurement mic, not REW, not THX, and not absolute dB SPL. Most iPhones expose one mic path, so stereo balance stays blank. Share saves a PNG with a timestamp, not audio. Same microphone usage string.
- Breath Flute (play tool on Instruments, not on the Quick row). Three steps: blow the bottom edge of the phone, cover the big finger holes, sound only while you blow. A harder blow is louder. The bottom built-in mic is preferred when iOS lists one. Not a calibrated wind instrument. Nothing recorded or uploaded. Same microphone usage string as Noise Meter.
- Bubble Level / plumb (CoreMotion)
- Magnetometer (heading, µT) with Mag Sweep: |B| minus a captured baseline, peak hold, and a sparkline. A slow field-variation spectrum is DC |B| only — not AC EMF and not a 50/60 Hz meter. Phone magnets dominate.
- Barometer / relative altitude
- Stillness Anomaly Watch: baseline ticks for DC |B|, pressure, mic impulses, and BLE advertiser changes, plus a timeline. “Phone moved” is a bump gate, not an anomaly. Not a ghost detector, presence meter, EMF meter, or people counter. Audio is not recorded.
- g-Force snapshot
- Coupled Vibration: user-acceleration RMS and a spectrum up to the delivered Nyquist (not a claimed 0–400 Hz band), peak frequency, relative RPM (f × 60, phone-mounted), and session A/B. Not ISO 10816, not a calibrated pickup, not a tachometer, and not a bearing-fault tool. Distinct from g-Force Snapshot.
- Position (location requested in-tool, not at launch)
- Device Health (charge, Low Power Mode, thermal meaning, free storage, model / iOS, uptime — not Battery Health %)

Local **Saved Jobs** are on-device homework / field notes, not a projects product. Field jobs sort first. Opening a job restores matching inputs into the tool when they still map — it does not block if some fields cannot be restored. Each tool keeps last-used inputs on device, copies a numeric result, lists related tools from the same catalog, can show the formula with your numbers plugged in (expanded on homework tools, collapsed on field lookups), and has a short **How it works** note (toolbar About / collapsed disclosure) for what it computes and its limits. Tap the star on any tool (in the list or its toolbar) to pin it to the **Favorites** tab for one-tap access. Disclaimer on every tool: design aid, not a PE stamp or calibrated instrument. No ads, analytics, tracking, games, store, or phone number. App Store v1 is **free** ($0): no IAP, no StoreKit.

## Linux (this repo)

Math tests do not need Xcode:

```bash
cd ios/BeckifyMath
swift test
```

You cannot build or run the app UI, CoreMotion, AVFoundation, or CoreBluetooth on Linux. Simulator, signing, archive, and App Store upload require a Mac. This repository does not claim those happened. The electrical-code Settings screen and in-tool banners were not exercised in Simulator or on a device.

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

Do not point either workflow at **LookCheck** (`com.beckify.lookcheck`), **KestrelHeavy** (`com.beckify.kestrelheavy`), or **BeckifyDrive** (`com.beckify.drive`). Those products keep their own Archive schemes and bundle IDs. Beckify Drive does not change Toolbox marketing **1.0.2** / build **170**.

Connect version **1.0.2** must already exist (**1.0** and **1.0.1** are closed — Connect rejected **1.0.1 (160)** with ITMS-90186 / ITMS-90062). Repo `MARKETING_VERSION` is **1.0.2** and `CURRENT_PROJECT_VERSION` is **170**, past repo tip **169**. Xcode Cloud Build - iOS on **164** failed to compile `SpectrumPlot.swift` (`showsRelativeDBFSScale` captured by a closure before initialization) and did not upload. Build **163** failed earlier on `BreathFluteView.swift` (`supportedPolarPatterns` is optional). Archive of **158** and **159** compiled and failed while preparing the App Store Connect upload. If TestFlight or a previous Cloud upload is already **≥170**, bump that number before the next push. A higher build on **1.0.1** will not upload.

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

App Store Connect already has a Beckify record: App ID `6807908745`, bundle ID `com.beckify.toolbox`, SKU `beckify-toolbox`, privacy URL https://beckify.com/privacy (live). Price stays **Free, no in-app purchases, no ads** (Trevor: v1 is $0, no IAP). **Version 1.0 is approved** — that train is closed (**ITMS-90186** / **ITMS-90062**; Transporter rejected **1.0 (121)**). **Version 1.0.1 is also closed:** App Store Connect rejected **1.0.1 (160)** (**ITMS-90186** train '1.0.1' closed for new builds; **ITMS-90062** short version must be higher than approved **1.0.1**). Bumping the build number on **1.0.1** will not fix that. TestFlight already had **1.0.1 (149)** as of ~2026-09-17/18 (Trevor; this repo did not query App Store Connect). Next Connect version is **1.0.2**, build **170** (repo `MARKETING_VERSION` **1.0.2**, `CURRENT_PROJECT_VERSION` **170**). Xcode Cloud may auto-bump; if TestFlight or Cloud already has **≥170**, bump again before the next Archive. If the Archive - iOS workflow’s next build number is not the project version, set it to **170** or higher in App Store Connect. Trevor must **create version 1.0.2** in Connect before uploading. Archive the **Beckify** scheme, not LookCheck, KestrelHeavy, or BeckifyDrive. Look Check stays **1.0 (1)**; Connect/TestFlight exists as **LookCheck5000** (Xcode display name **Look Check**; Archive scheme **LookCheck** — do not rename). Kestrel Heavy repo build is **1.0 (4)** and a TestFlight record exists — if TestFlight already has **≥4**, bump before the next Archive, otherwise the next binary is **1.0 (4)**. This Linux environment did not compile, sign, or upload 170.

- Compile the SwiftUI target and exercise the UI on Simulator / device
- Create signing certificates / profiles for team `9TR6R5LV8M` on a Mac
- Run on a physical device at least once if not already done
- Trevor: accept the Apple Developer Program License Agreement (DPLA) if Connect still requires it
- Capture App Store screenshots at the required sizes
- Signed archive, upload, then listing screenshots / submit for review

This repository does **not** submit anything to the App Store.
