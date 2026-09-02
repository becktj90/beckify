# App Store scaffolding — Beckify

Listing copy for the native SwiftUI Beckify app (iPhone + iPad, no ads). Trevor Beck enrolled in the **Apple Developer Program** on 2026-09-02. An **App Store Connect record exists** (status **Prepare for Submission**). No binary has been uploaded. This is **not** TestFlight and **not** an App Store submit.

This Linux environment has not compiled the SwiftUI or CoreMotion/AVFoundation UI, signed a binary, captured screenshots, archived, or uploaded a build.

## Listing copy

**Name:** Beckify  
**Subtitle:** Field EE toolbox  
**App ID (Apple ID):** `6807908745`  
**Bundle ID:** `com.beckify.toolbox`  
**SKU:** `beckify-toolbox`  
**Connect status:** Prepare for Submission (no binary uploaded)  
**Team prefix / `DEVELOPMENT_TEAM`:** `9TR6R5LV8M` (Apple auto-filled at identifier registration; set on the Beckify target Debug and Release in `ios/Beckify.xcodeproj`)  
**Devices:** iPhone and iPad (Xcode `TARGETED_DEVICE_FAMILY` 1,2)  
**Category:** Productivity  
**Secondary (optional):** Utilities  
**Age rating:** 4+ (no user-generated content, no unrestricted web, no violence)  
**Price:** Free, no in-app purchases, no ads

**Promotional text (170 characters, optional):**
Native field-EE calculators plus public-API sensors for homework and jobsite notes. Design aid — not a PE stamp or calibrated instrument.

**Description:**

Beckify is a professional field electrical toolbox for engineers, technicians, and students. It is a native iPhone and iPad app, not a website wrapper and not a project gallery.

Calculate common jobsite numbers with units, formulas, and live results:

• Ohm's Law
• DC and AC power
• Power Wizard for DC, single-phase, and three-phase (amps, kW, kVA, HP)
• Voltage drop with 3% / 5% informational checks and a 310.16 ampacity cross-check
• Conduit fill for THHN in EMT (NEC Chapter 9 Table 1)
• Transformer sizing and overcurrent protection (NEC 450.3(B), including Note 1)
• 555 timer (astable and monostable)
• Motor full-load current from NEC Tables 430.248 and 430.250
• Wire size from NEC Table 310.16, 75 °C column

Homework calculators:

• Voltage divider (Vout, or solve R1 / R2)
• Series / parallel resistors and capacitors
• Resistor color code (4-band and 5-band, decode and encode)
• Unit converter: SI prefixes for V/A/Ω/W, dB ratio, °C/°F, m/ft, mils/mm
• Frequency, period, free-space wavelength, and LC resonance f = 1/(2π√(LC))
• LED current-limiting resistor and RC time constant τ = RC (555 timing stays in the 555 tool)

Measure with public Apple APIs (not private APIs):

• Wi-Fi path (Network.framework) plus Apple’s public 0…1 `signalStrength` shown as percent/bars and an on-device coverage heatmap (GPS walk or tap-on-floor). iOS does not give third-party apps Wi-Fi RSSI in dBm; this tool will not invent dBm. Current SSID needs location plus, on a signed team, Access Wi-Fi Information.
• BLE scanner (CoreBluetooth): name, identifier, RSSI, advertised services
• Noise meter (microphone): uncalibrated dBFS. Not an SLM, not OSHA legal
• Bubble level / plumb (CoreMotion)
• Magnetometer: heading and |B| in µT
• Barometer / relative altitude
• g-force snapshot
• Position (GPS) when that tool is opened — not at launch
• Device battery and thermal diagnostics

Search the toolbox (try “ampacity”, “divider”, “color code”, “LED”, “wifi”). Save named jobs on device as homework or field notes. No account, no ads, no analytics, no tracking.

This app is a design aid. It is not a PE stamp, permit, inspection, calibrated instrument, or a substitute for the National Electrical Code or a qualified engineer.

**Keywords (100 characters max, comma-separated draft):**
electrical,NEC,resistor,divider,LED,ampacity,wifi,ohm

**What's New (1.0):**
First toolbox with field EE calculators, homework tools, and public-API sensors, plus local saved notes.

**Support URL:** https://beckify.com  
**Marketing URL:** https://beckify.com  
**Copyright:** 2026 Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com

**Privacy Policy URL:** https://beckify.com/privacy (live; also served at https://beckify.com/privacy/). App Store Connect needs this public HTTPS URL. Source text: [`PRIVACY.md`](PRIVACY.md) (“Data Not Collected”).

## Wi-Fi App Store limitation (honest)

Public iOS APIs do **not** provide Wi-Fi RSSI or dBm to third-party apps (Apple DTS). `NWPathMonitor` reports path status. `NEHotspotNetwork.fetchCurrent` may return SSID/BSSID and a **0.0–1.0** `signalStrength` after location (and Access Wi-Fi Information on a signed team). That 0–1 value is often 0.0; it is not calibrated dBm. The in-app heatmap sketches Apple’s 0–1 amplitude versus GPS or a tapped floor plan. Do not add private APIs to fake a dBm meter. On a Mac with a paid team, optionally add the **Access Wi-Fi Information** capability if SSID is empty in review devices.

## App privacy (nutrition label)

Data collection: **none** (see [`PRIVACY.md`](PRIVACY.md)).

- No analytics
- No tracking
- No advertising identifier
- No account
- Saved jobs use on-device storage only (`UserDefaults`)
- Microphone, Bluetooth, and location are processed on device inside those tools; numeric snapshots are saved only if the user taps Save

Privacy manifest: `Beckify/PrivacyInfo.xcprivacy`  
- `NSPrivacyTracking` = false  
- No collected data types  
- UserDefaults accessed with reason CA92.1 (app functionality: saved jobs)

Usage strings (generated Info.plist): microphone, Bluetooth Always / Peripheral, location When In Use — see the Beckify target build settings.

## Export compliance

The app uses only HTTPS for optional links the user taps (beckify.com, mailto). It does not implement custom cryptography. Info.plist includes `ITSAppUsesNonExemptEncryption = NO`. In App Store Connect, answer **No** to “Does your app use encryption?” except the standard HTTPS exemption if the form still appears.

## Screenshots (required sizes)

Not captured in this repository. This repo has not run an iOS Simulator UI build, signed the app, uploaded TestFlight, or submitted to the App Store. On a Mac with Xcode, capture Simulator screenshots at the sizes below. Do **not** ship website screenshots.

Apple's current required screenshot classes for an iPhone + iPad app (verify in App Store Connect before upload):

| Device class | Role | Common simulator | Typical pixel size |
| --- | --- | --- | --- |
| 6.9" iPhone | Required (or 6.5" set) | iPhone 16 Pro Max | 1320 × 2868 |
| 6.5" iPhone | Alternate required iPhone set | iPhone 14 Plus / 11 Pro Max | 1284 × 2778 |
| 13" iPad | Required for iPad | iPad Pro 13-inch | 2064 × 2752 |
| 12.9" iPad | Fallback only (scales to 13" if 13" is missing) | iPad Pro 12.9-inch | 2048 × 2732 |

Take 3–8 screens per size. Suggested shots:

1. Toolbox search / tool list (dark premium home)
2. Power Wizard with the 480 V 3Ø 50 kW → 66.8 A result
3. Voltage drop with 3% / 5% notes and ampacity row
4. Wi-Fi Path gauge (Apple 0…1, not dBm) and coverage heatmap
5. BLE scanner or bubble level
6. Saved Jobs list (on-device notes)
7. About (Trevor Beck, EE, beckify.com, email — no phone number)

Use dark appearance. Do not show ads, Amazon, games, or a phone number.

## App icon

Placeholder bolt/toolbox icon is in `Beckify/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024). Replace with a final design before submission if desired. Do not use a photograph of a real person.

## Remaining steps (Mac + App Store Connect)

**Apple Developer Program:** signed up as Trevor Beck (stated 2026-09-02). Enrollment is no longer a blocker.

**App Store Connect record (exists — recorded Connect facts only; do not invent more):**

| Field | Value |
| --- | --- |
| Status | Prepare for Submission |
| Binary | None uploaded |
| App ID (Apple ID) | `6807908745` |
| Bundle ID | `com.beckify.toolbox` |
| SKU | `beckify-toolbox` |
| Privacy Policy URL | https://beckify.com/privacy (live) |
| Team prefix | `9TR6R5LV8M` |

The app is native SwiftUI, iPhone + iPad, Free, no IAP, no ads. This repository does **not** claim TestFlight or App Store submit.

Still needed (Mac + Trevor; not done in this Linux environment):

1. On a Mac, open `ios/Beckify.xcodeproj` and confirm Signing & Capabilities shows Team **9TR6R5LV8M** (already in Debug and Release `DEVELOPMENT_TEAM`). Automatic signing still creates certificates/profiles on that Mac.
2. Optionally add **Access Wi-Fi Information** if you want SSID from `NEHotspotNetwork.fetchCurrent` on device. Wi-Fi Path still uses Apple’s public 0–1 `signalStrength`, not dBm.
3. Run on a physical device at least once if not already done (capability / provisioning / sensor check). This Linux CI job does not do that.
4. **DPLA:** Trevor must accept the Apple Developer Program License Agreement in App Store Connect / developer.apple.com if it is still pending. This environment cannot do that.
5. Capture screenshots at the sizes below. Do **not** ship website screenshots.
6. Archive in Xcode (Product → Archive) or `xcodebuild archive` with signing enabled (`DEVELOPMENT_TEAM` `9TR6R5LV8M`).
7. Upload the signed archive (Organizer or Transporter). Wait for processing. Upload is still outstanding; that is not TestFlight distribution and not App Store submit.
8. Attach screenshots, review the encryption and content-rights questions, then submit for review (not done).
9. Answer App Review if they ask about NEC table transcription, microphone/Bluetooth/location strings, or “design aid” disclaimers.

Until those steps are done, there is **no** uploaded binary. The app is **not** on TestFlight and **not** on the App Store.
