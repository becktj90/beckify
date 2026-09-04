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

Trevor decided App Store v1 is **free** ($0): no IAP. Do not add a paid price or in-app purchases to listing copy or the Xcode project. There is no StoreKit target.

**Promotional text (170 characters, optional):**
Native field-EE calculators with shareable engineer plots, plus public-API sensors. Design aid — not a PE stamp or calibrated instrument.

**Description:**

Beckify is a professional field electrical toolbox for engineers, technicians, and students. It is a native iPhone and iPad app, not a website wrapper and not a project gallery.

Calculate common jobsite numbers with units, formulas, and live results:

• Ohm's Law
• Power — DC identities (P=VI, I²R, V²/R) and 1Ø / 3Ø kVA, kW, kVAR (saved Power Wizard jobs still open)
• Voltage Drop — K-factor VD with parallels, target %, ampacity check, and optional ampacity→VD handoff
• Conduit fill for THHN in EMT (NEC Chapter 9 Table 1)
• Transformer sizing and overcurrent protection (NEC 450.3(B), including Note 1)
• Tap-Changer Calculator — DETC tap recommendation from measured secondary voltage
• 555 timer (astable and monostable)
• Motor full-load current from NEC Tables 430.248 and 430.250
• Motor Speed & Torque — synchronous RPM, slip from a nameplate, and shaft torque from HP
• Motor Nameplate Analyzer — overload (430.32), Table 430.52 SCPD, 430.22 conductor, code-letter LRA
• Wire Size & Ampacity — NEC Table 310.16 with ambient correction, CCC adjustment, termination cap, and continuous load
• Heater Design Wizard — resistive heater line current, leg R, and resistance-wire length
• UPS / On-site Power — design kVA, runtime, and battery Ah from critical load
• Harmonics (THD) — current THD, dominant order, and IEEE 519 discussion bands (informational)
• NEC Circuit Calculator — design current, derated conductor, voltage drop, and OCPD in one pass
• Load Calculation Worksheet — NEC 220.42 lighting demand plus motor/continuous VA totals
• Cable Schedule Generator — sequential cable IDs from a type catalog with CSV copy
• EMP / EMC Shielding — skin depth, sheet SE, Faraday-loop voltage, and aperture leakage (protection-side educational; not pulse-source design)
• Receptacle Selector — NEMA straight/locking and IEC 60309 pin-and-sleeve best-fit faces (design aid; public catalog PNs when cited)
• IS Loop Verifier — Entity Concept check of barrier Voc/Isc/Ca/La against the field device and cable (design aid)
• Reactance & resonance, power-factor correction, short-circuit current, circular mils, load & demand factors
• RF Power & Link — dBm to watts, VSWR and return loss, free-space path loss
• Battery Bank Sizing — series/parallel cells to bank voltage, amp-hours, and runtime
• Magnetic Circuit — reluctance, flux, and flux density from mmf, path length, area, and µr
• Panel Directory — paste or on-device OCR of a panel schedule / sticker into circuit, name, trip, and poles
• Signal scaling (4–20 mA), Modbus address forms, PLC timer presets
• Number Base Converter — binary, octal, decimal, hex, plus signed 8/16/32-bit read of the same bits
• E-Bus / Rack Current — sum device currents against a bus rating for headroom
• Unit converter: SI prefixes for V/A/Ω/W, dB ratio, °C/°F, m/ft, mils/mm
• Reference Library — NEMA, IP ratings, conductor colors, hazardous areas, insulation, torque, conduit, and standard sizes

Homework calculators:

• Voltage divider (Vout, or solve R1 / R2)
• Series / parallel resistors and capacitors
• Resistor color code (4-band and 5-band, decode and encode)
• Phasor Diagram — plot 2–3 phasors and sum them (balanced 3-phase set is one tap)
• Frequency, period, free-space wavelength, and LC resonance f = 1/(2π√(LC))
• LED current-limiting resistor and RC time constant τ = RC (555 timing stays in the 555 tool)
• Transient Circuits — RC/RL charge and discharge, value at a time, and the curve
• Fiber Link / NA and Gaussian Beam — numerical aperture, V-number, Rayleigh range, and beam radius
• Semiconductor I-V — diode forward current from the Shockley equation, with the I-V curve

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

Search the toolbox (try “ampacity”, “tap”, “THD”, “UPS”, “nameplate”, “heater”, “receptacle”, “motor”, “phasor”, “fiber”, “LED”, “wifi”). Each existing tool keeps last-used inputs on this device, copies a numeric result, can show the formula with your numbers plugged in, and lists related tools from the same toolbox. Selected existing calculators show engineer plots (Swift Charts) and can Share or save a PNG through the system share sheet. Save named jobs on device as homework or field notes. No account, no ads, no analytics, no tracking.

This app is a design aid. It is not a PE stamp, permit, inspection, calibrated instrument, or a substitute for the National Electrical Code or a qualified engineer.

**Keywords (100 characters max, comma-separated draft):**
electrical,NEC,ampacity,THD,UPS,tap,heater,nameplate,ohm,motor

**What's New (draft for next Connect build — no binary uploaded):**
Facility tools: Tap-Changer, Harmonics (THD), UPS / On-site Power, Motor Nameplate, Heater Design, EMP/EMC Shielding, NEC Circuit, Load Worksheet, Cable Schedule. Wire Ampacity and Voltage Drop use ambient/CCC/termination derating with optional handoff. Selected calculators keep engineer plots (Swift Charts) with Share/save PNG. Still a design aid. Not TestFlight; no binary uploaded.

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
- Saved jobs and last-used tool inputs use on-device storage only (`UserDefaults`)
- Microphone, Bluetooth, and location are processed on device inside those tools; numeric snapshots are saved only if the user taps Save

Privacy manifest: `Beckify/PrivacyInfo.xcprivacy`  
- `NSPrivacyTracking` = false  
- No collected data types  
- UserDefaults accessed with reason CA92.1 (app functionality: saved jobs and last-used inputs)

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

1. Toolbox search / tool list (system appearance)
2. Wire Size & Ampacity waterfall (ambient / CCC / termination) or Voltage Drop with parallels + handoff
3. Power with the 480 V 3Ø 66.8 A / PF 90% identities result
4. Motor Nameplate Analyzer or Tap-Changer Calculator result card
5. Harmonics (THD) or UPS / On-site Power sizing result
6. Receptacle Selector (NEMA 5-15R or L16-30 pinout + public PNs)
7. Wi-Fi Path gauge (Apple 0…1, not dBm) and coverage heatmap
8. Saved Jobs list (on-device notes) or Favorites (starred tools)
9. A calculator showing an engineer plot with the Share control (Ohm's Law V–I load line, LED/RC charge/discharge, Transient Circuits response, or Phasor Diagram)

Pick a 3–8 subset and include the plot + Share shot if you have room.

The app follows the system light or dark appearance; it does not force dark. System appearance shots are fine — do not require dark-only screenshots. Do not claim outdoor/high-contrast beyond what Settings actually does. Do not show ads, Amazon, games, or a phone number.

## App icon

App icon is `Beckify/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (opaque 1024×1024 RGB, single catalog slot). Original stacked-rings mark: nested white circles sharing a bottom tangent (tunnel), the whole shape centered on a black square. Full-bleed square — do not pre-round corners or add alpha; Apple applies the squircle. Do not use a photograph of a real person.

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
| Price | Free ($0), no IAP, no ads (Trevor’s v1 decision) |

The app is native SwiftUI, iPhone + iPad. **Price:** Free, no in-app purchases, no ads. This repository does **not** claim TestFlight, a signed archive, or App Store submit.

Still needed (Mac + Trevor; not done in this Linux environment):

1. Create the app record — already done (see table). On a Mac, open `ios/Beckify.xcodeproj` and set **Team** / confirm Signing & Capabilities shows Team **9TR6R5LV8M** (already in Debug and Release `DEVELOPMENT_TEAM`). Automatic signing still creates certificates/profiles on that Mac.
2. Optionally add **Access Wi-Fi Information** if you want SSID from `NEHotspotNetwork.fetchCurrent` on device. Wi-Fi Path still uses Apple’s public 0–1 `signalStrength`, not dBm.
3. Run on a physical device at least once if not already done (capability / provisioning / sensor check). This Linux CI job does not do that.
4. **DPLA:** Trevor must accept the Apple Developer Program License Agreement in App Store Connect / developer.apple.com if it is still pending. This environment cannot do that.
5. Capture screenshots at the sizes below. Do **not** ship website screenshots.
6. Archive in Xcode (Product → Archive) or `xcodebuild archive` with signing enabled (`DEVELOPMENT_TEAM` `9TR6R5LV8M`).
7. Upload the signed archive (Organizer or Transporter). Wait for processing. Upload is still outstanding; that is not TestFlight distribution and not App Store submit.
8. Attach screenshots, review the encryption and content-rights questions, then submit for review (not done).
9. Answer App Review if they ask about NEC table transcription, microphone/Bluetooth/location strings, or “design aid” disclaimers.

Until those steps are done, there is **no** uploaded binary. The app is **not** on TestFlight and **not** on the App Store.
