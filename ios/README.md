# Beckify iOS

Native SwiftUI field EE toolbox for iPhone and iPad. Bundle ID `com.beckify.toolbox`, display name **Beckify**, iOS 17+.

Home is two areas — **Field** (jobsite, first) and **Toolkit** (basics, bench homework, references) — not a flat grid of every tool. Search covers both and labels the area. Sensors live under Field → Instruments.

This is not a website wrapper. There is no `WKWebView` of beckify.com and no website project gallery. Calculator and sensor math helpers live in a pure Swift package so they can be tested on Linux without Xcode. Website toolbox IA is a follow-up, not this app.

## Design system

Reusable tokens live in `Beckify/Theme/Theme.swift` (surfaces, semantic accents, spacing, radius, stroke, typography, chart colors, motion). Calculator chrome — identity header, Calculate / Reset / Example, stale-result banner, diagrams — lives under `Beckify/Views/Components/`.

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
  Beckify.xcodeproj/     Xcode 15+ project (open this on a Mac)
  Beckify/               SwiftUI app (Calculators + Sensors)
  BeckifyMath/           Pure-Swift math + NEC tables + XCTest
  docs/APP_STORE.md      Listing copy and App Store Connect checklist
```

## Field (jobsite — opens first)

- Power (DC identities + 1Ø / 3Ø). ToolID.powerWizard remains for saved jobs and is not listed.
- Voltage Drop (K-factor VD, parallels, target %, ampacity check, optional ampacity→VD handoff)
- Conductor Cost Optimizer (compliant size × parallel-run ranking with planning $/kft and optional I²R energy — not a live quote)
- Conductor Length by Resistance (estimate one-way distance from measured Ω/mΩ with Cu/Al α compensation; single vs loop)
- Conduit Fill (same-size or mixed Chapter 9 fill; EMT and other Table 4 raceways)
- Transformer Sizing & Protection (NEC 450.3(B) + Note 1)
- Tap-Changer Calculator (DETC tap from measured secondary)
- Motor FLA (430.248 / 430.250)
- Motor Speed & Torque (sync RPM, slip, shaft torque)
- Motor Nameplate Analyzer (430.32 overload, Table 430.52 SCPD, 430.22 conductor, code-letter LRA)
- Motor Nameplate OCR (camera or library photo, on-device Vision, heuristic field extract into the shared nameplate schema — value + confidence + reviewed; human confirm sets reviewed. MOCP and LRA are never treated as FLA. Cloud VLM protocol is off. Optional seed into FLA / Analyzer / Speed)
- Wire Size & Ampacity (310.16 with ambient, CCC, termination cap, continuous load)
- Heater Design Wizard (resistive heater current, leg R, element wire length)
- UPS / On-site Power (kVA, runtime, battery Ah)
- Harmonics (THD) (current THD / IEEE 519 discussion bands)
- NEC Circuit Calculator (design current, derated conductor, VD, OCPD)
- Load Calculation Worksheet (NEC 220.42 lighting demand + category VA)
- Cable Schedule Generator (sequential IDs + CSV copy)
- Solenoid Design Wizard (winding pack, B/L/force plots, copper loss)
- EMP / EMC Shielding (skin depth, sheet SE, Faraday loop, aperture — protection-side educational)
- Receptacle Selector (NEMA / IEC 60309 best-fit, schematic pinout, public catalog PNs when cited)
- IS Loop Verifier (Entity Concept Voc/Isc/Ca/La vs device + cable)
- Power Factor Correction, Short-Circuit Current, Circular Mils, Load & Demand Factors
- Battery Bank Sizing
- E-Bike Torque / RPM (shaft torque or RPM from W / kW / hp)
- Sprocket Ratio Designer (drive/driven teeth, output RPM/torque, optional wheel speed, or invert a target)
- Range Estimator (pack V×Ah and Wh/mi → miles, km, runtime)
- Battery Pack Designer (S×P planning from a voltage/current target or a known layout — design aid, not a BMS/weld cert; Battery Bank Sizing stays the runtime/DoD tool)
- Nickel Strip (cross-section × planning current density)
- Solar Design Wizard (PV sizing, phone IMU/compass aim, optional storage)
- Signal Scaling, Modbus Address, PLC Timer Preset
- Control Systems (Field → Controls hub: plant library + custom G(s), P→PI→PID step with Ziegler–Nichols and Open/P/PI/PID overlay, Bode margins, lead compensator; educational — not commissioning)
- E-Bus / Rack Current
- Panel Directory (paste/OCR schedule text)

## Toolkit (basics, bench / homework, reference)

- Ohm's Law
- Voltage Divider (Vout, or solve R1/R2)
- Series / Parallel R and C
- Resistor Color Code (4-band and 5-band, decode + encode)
- Frequency / period / wavelength and LC resonance
- LED current-limit R and RC τ (555 astable/monostable stays in 555 Timer)
- Unit Converter (SI prefixes, dB, °C/°F, m/ft, mils/mm)
- 555 Timer (astable / monostable)
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
- Reference Library (NEMA, IP, colors, hazardous areas, insulation, torque, conduit, standard sizes)

Selected existing calculators show **engineer plots** (Swift Charts) and can **Share / save a PNG** through the system share sheet. Examples already in this catalog: Ohm's Law load line, Frequency / LC waveform, LED / RC charge–discharge, Reactance & Resonance, Transient Circuits, Semiconductor I-V, Phasor Diagram, 555 Timer monostable capacitor charge, Analog Design Workbench Bode magnitude, and Control Systems step / PID overlay / Bode / lead. This is not a new tool list.

## Instruments (Field subsection — public APIs only)

- Wi-Fi Path (`NWPathMonitor` + `NEHotspotNetwork.signalStrength` 0…1 heatmap). **No Wi-Fi dBm** — iOS does not expose RSSI to third-party apps.
- BLE Scanner (CoreBluetooth)
- Noise Meter (microphone dBFS, uncalibrated)
- Bubble Level / plumb (CoreMotion)
- Magnetometer (heading, µT)
- Barometer / relative altitude
- g-Force snapshot
- Position (location requested in-tool, not at launch)
- Device battery / thermal diagnostics

Local **Saved Jobs** are on-device homework / field notes, not a projects product. Field jobs sort first. Opening a job restores matching inputs into the tool when they still map — it does not block if some fields cannot be restored. Each tool keeps last-used inputs on device, copies a numeric result, lists related tools from the same catalog, and can show the formula with your numbers plugged in (expanded on homework tools, collapsed on field lookups). Tap the star on any tool (in the list or its toolbar) to pin it to the **Favorites** tab for one-tap access. Disclaimer on every tool: design aid, not a PE stamp or calibrated instrument. No ads, analytics, tracking, games, store, or phone number. App Store v1 is **free** ($0): no IAP, no StoreKit.

## Linux (this repo)

Math tests do not need Xcode:

```bash
cd ios/BeckifyMath
swift test
```

You cannot build or run the app UI, CoreMotion, AVFoundation, or CoreBluetooth on Linux. Simulator, signing, archive, and App Store upload require a Mac. This repository does not claim those happened.

## Mac — open and run

1. Install Xcode 15 or later.
2. Open `ios/Beckify.xcodeproj`.
3. Select an iPhone or iPad simulator.
4. Signing: Beckify Debug and Release set `DEVELOPMENT_TEAM` to `9TR6R5LV8M` (Apple’s team prefix at identifier registration). Confirm that Team in Signing & Capabilities on a Mac.
5. Run.

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

### Archive (signed, on a Mac; upload still outstanding)

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -scheme Beckify \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Beckify.xcarchive \
  archive

xcodebuild \
  -exportArchive \
  -archivePath build/Beckify.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

`ExportOptions.plist` is not in this repo. Team prefix `9TR6R5LV8M` is already in the Xcode project. Create an export plist on a Mac if you export from `xcodebuild`. See `docs/APP_STORE.md`.

## What still needs a Mac + Apple login

App Store Connect already has a Beckify record: App ID `6807908745`, bundle ID `com.beckify.toolbox`, SKU `beckify-toolbox`, status **Prepare for Submission**, privacy URL https://beckify.com/privacy (live). Price stays **Free, no in-app purchases, no ads** (Trevor: v1 is $0, no IAP). No binary is uploaded. This is not TestFlight, not a signed archive, and not an App Store submit.

- Compile the SwiftUI target and exercise the UI on Simulator / device
- Create signing certificates / profiles for team `9TR6R5LV8M` on a Mac
- Run on a physical device at least once if not already done
- Trevor: accept the Apple Developer Program License Agreement (DPLA) if Connect still requires it
- Capture App Store screenshots at the required sizes
- Signed archive, upload, then listing screenshots / submit for review

This repository does **not** submit anything to the App Store.
