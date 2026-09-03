# Beckify iOS

Native SwiftUI field EE toolbox for iPhone and iPad. Bundle ID `com.beckify.toolbox`, display name **Beckify**, iOS 17+.

This is not a website wrapper. There is no `WKWebView` of beckify.com and no website project gallery. Calculator and sensor math helpers live in a pure Swift package so they can be tested on Linux without Xcode.

## Design system

Reusable tokens live in `Beckify/Theme/Theme.swift` (surfaces, semantic accents, spacing, radius, stroke, typography, chart colors, motion). Calculator chrome — identity header, Calculate / Reset / Example, stale-result banner, diagrams — lives under `Beckify/Views/Components/`.

Every primary tool has an original vector `ToolGlyph` (not a shared SF Symbol). Open **Icon Gallery** from the toolbox toolbar to review them together.

### Calculation modes

`ToolCalculationPolicy` / `ToolDefinition.calculationMode` is the single source of truth:

- **Live** — Unit Converter, Resistor Color, Circular Mils, Modbus Address: update when inputs are valid.
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

## Calculators (v1)

- Ohm's Law
- Power (DC identities + 1Ø / 3Ø). ToolID.powerWizard remains for saved jobs and is not listed.
- Voltage Drop (3% / 5% informational, 310.16 ampacity cross-check)
- Conduit Fill (THHN / EMT, Chapter 9 Table 1)
- Transformer Sizing & Protection (NEC 450.3(B) + Note 1)
- 555 Timer (astable / monostable)
- Motor FLA (430.248 / 430.250)
- Wire Size & Ampacity (310.16 75 °C)
- Receptacle Selector (NEMA / IEC 60309 best-fit, schematic pinout, public catalog PNs when cited)
- Unit Converter (SI prefixes, dB, °C/°F, m/ft, mils/mm)
- Reactance & Resonance, Power Factor Correction, Short-Circuit Current
- Circular Mils, Load & Demand Factors
- Signal Scaling, Modbus Address, PLC Timer Preset
- Panel Directory (paste/OCR schedule text)

## Homework calculators

- Voltage Divider (Vout, or solve R1/R2)
- Series / Parallel R and C
- Resistor Color Code (4-band and 5-band, decode + encode)
- Frequency / period / wavelength and LC resonance
- LED current-limit R and RC τ (555 astable/monostable stays in 555 Timer)

## Sensors (public APIs only)

- Wi-Fi Path (`NWPathMonitor` + `NEHotspotNetwork.signalStrength` 0…1 heatmap). **No Wi-Fi dBm** — iOS does not expose RSSI to third-party apps.
- BLE Scanner (CoreBluetooth)
- Noise Meter (microphone dBFS, uncalibrated)
- Bubble Level / plumb (CoreMotion)
- Magnetometer (heading, µT)
- Barometer / relative altitude
- g-Force snapshot
- Position (location requested in-tool, not at launch)
- Device battery / thermal diagnostics

Local **Saved Jobs** are on-device homework / field notes, not a projects product. Each tool keeps last-used inputs on device, copies a numeric result, lists related tools from the same catalog, and can show the formula with your numbers plugged in (expanded on homework tools, collapsed on field lookups). Tap the star on any tool (in the list or its toolbar) to pin it to the **Favorites** tab for one-tap access. Disclaimer on every tool: design aid, not a PE stamp or calibrated instrument. No ads, analytics, tracking, games, store, or phone number. App Store v1 is **free** ($0): no IAP, no StoreKit.

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
