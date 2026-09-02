# Beckify iOS

Native SwiftUI field EE calculator for iPhone and iPad. Bundle ID `com.beckify.toolbox`, display name **Beckify**, iOS 17+.

This is not a website wrapper. There is no `WKWebView` of beckify.com. Calculator math lives in a pure Swift package so it can be tested on Linux without Xcode.

## Layout

```text
ios/
  Beckify.xcodeproj/     Xcode 15+ project (open this on a Mac)
  Beckify/               SwiftUI app
  BeckifyMath/           Pure-Swift math + NEC tables + XCTest
  docs/APP_STORE.md      Listing copy and App Store Connect checklist
```

## Calculators (v1)

- Ohm's Law
- DC / AC Power
- Power Wizard (DC / 1Ø / 3Ø) — spot check: 480 V 3Ø 50 kW PF 0.90 → 66.8 A
- Voltage Drop (3% / 5% informational, 310.16 ampacity cross-check)
- Conduit Fill (THHN / EMT, Chapter 9 Table 1)
- Transformer Sizing & Protection (NEC 450.3(B) + Note 1)
- 555 Timer (astable / monostable)
- Motor FLA (430.248 / 430.250)
- Wire Size & Ampacity (310.16 75 °C)

Local **Saved Jobs**. Disclaimer on every tool: design aid, not a PE stamp. No ads, analytics, tracking, games, store, or phone number.

## Linux (this repo)

Math tests do not need Xcode:

```bash
cd ios/BeckifyMath
swift test
```

You cannot build or run the app UI on Linux. Simulator, signing, archive, and App Store upload require a Mac.

## Mac — open and run

1. Install Xcode 15 or later.
2. Open `ios/Beckify.xcodeproj`.
3. Select an iPhone or iPad simulator.
4. Signing: pick Trevor's Team in the Beckify target (needs Apple Developer Program).
5. Run.

### xcodebuild (unsigned compile check)

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -scheme Beckify \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Archive for TestFlight / App Store (signed, on a Mac)

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

`ExportOptions.plist` is not in this repo until a Developer Team ID is available. Create it after signing in with the $99 Apple Developer Program account. See `docs/APP_STORE.md`.

## What still needs a Mac + Apple login

- Compile the SwiftUI target and exercise the UI on Simulator / device
- Add the Developer Team ID and create signing certificates / profiles
- Capture App Store screenshots at the required sizes
- Create the App Store Connect record, privacy nutrition label, and submit a build
- Pay / renew the Apple Developer Program ($99/year)

This repository does **not** submit anything to the App Store.
