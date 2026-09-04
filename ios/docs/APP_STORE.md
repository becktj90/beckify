# App Store scaffolding — Beckify

Listing copy for the native SwiftUI Beckify app (iPhone + iPad, no ads). Trevor Beck enrolled in the **Apple Developer Program** on 2026-09-02. An **App Store Connect record exists** (status **Prepare for Submission**). No binary has been uploaded. This is **not** TestFlight and **not** an App Store submit.

This Linux environment has not compiled the SwiftUI or CoreMotion/AVFoundation UI, signed a binary, captured screenshots, archived, or uploaded a build.

**Five-star / review-risk plan:** [`FIVE_STAR_READINESS.md`](FIVE_STAR_READINESS.md) — competitor 1★ patterns, first-open/trust punch list, Connect checklist, respectful `requestReview` timing, and honesty constraints (no fake Wi‑Fi/cellular dBm). Use the ITMS-90382 cooldown to finish that list before the next upload.

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
Field jobsite tools and a Toolkit for basics and bench homework. Shareable engineer plots. Design aid — not a PE stamp or calibrated instrument.

**Description:**

Beckify is a professional field electrical toolbox for engineers, technicians, and students. It is a native iPhone and iPad app, not a website wrapper and not a project gallery. The home screen is two areas: **Field** (jobsite tools, opens first) and **Toolkit** (basics, bench homework, and references). Search covers both and shows which area a result belongs to.

Field — jobsite calculators, wizards, and instruments. Field home (not while searching) includes a Quick strip: an avatar row of pinned jobsite tools (Voltage Drop, Wire Size & Ampacity, Motor FLA, Receptacle Selector, Wi-Fi Path, Conduit Fill).

Jobsite:

• Voltage Drop — K-factor VD with parallels, target %, ampacity check, and optional ampacity→VD handoff
• Conductor Cost Optimizer — compares compliant sizes and parallel runs using a user-entered or default planning $/kft and optional I²R energy. Planning allowance only — not LME or a bid
• Conductor Length by Resistance — estimate length from a milliohm (mΩ) reading, end-to-end or short-to-parallel, with copper/aluminum temperature compensation and AWG/kcmil or custom circular mils
• Conduit fill — same-size or mixed conductor sizes; Chapter 9 Table 1 vs Table 4 raceways and Table 5 areas (EMT, IMC, RMC, PVC, ENT, FMC, LFMC)
• Motor full-load current from NEC Tables 430.248 and 430.250
• Motor Speed & Torque — synchronous RPM, slip from a nameplate, and shaft torque from HP
• Motor Nameplate Analyzer — overload (430.32), Table 430.52 SCPD, 430.22 conductor, code-letter LRA (typed or seeded from a confirmed OCR review)
• Motor Nameplate OCR — camera or photo library, on-device Vision, heuristic field extract into the shared nameplate schema (value + confidence + reviewed). Confirm marks reviewed. MOCP and LRA are never used as FLA. Optional seed into Motor FLA / Analyzer / Speed. No cloud upload.
• Look Check — camera or photo library, then Analyze Look for a playful good-or-bad verdict plus lighting / framing / expression / sharpness metrics. Entertainment only — not medical or dating advice. The photo stays on this device until you tap Analyze Look. Same `/api/analyze-look` contract as the website. Not the Wi-Fi / Cellular Online / Captive connectivity card.
• Wire Size & Ampacity — NEC Table 310.16 with ambient correction, CCC adjustment, termination cap, and continuous load
• Receptacle Selector — NEMA straight/locking and IEC 60309 pin-and-sleeve best-fit faces (design aid; public catalog PNs when cited)
• Short-circuit current, circular mils, load & demand factors
• NEC Circuit Calculator — design current, derated conductor, voltage drop, and OCPD in one pass (live one-shot calc, not paperwork)
• IS Loop Verifier — Entity Concept check of barrier Voc/Isc/Ca/La against the field device and cable (design aid)

Power — facility and distribution energy only (saved Power Wizard jobs still open; Power Wizard is not listed):

• Power — DC identities (P=VI, I²R, V²/R) and 1Ø / 3Ø kVA, kW, kVAR
• Transformer sizing and overcurrent protection (NEC 450.3(B), including Note 1)
• Tap-Changer Calculator — DETC tap recommendation from measured secondary voltage
• Power-factor correction
• Harmonics (THD) — current THD, dominant order, and IEEE 519 discussion bands (informational)
• Battery Bank Sizing — series/parallel cells to bank voltage, amp-hours, and runtime
• Solar Design Wizard — size PV from rooftop to utility, aim panels with phone sensors, optional energy storage
• UPS / On-site Power — design kVA, runtime, and battery Ah from critical load

Controls:

• Signal scaling (4–20 mA), Modbus address forms, PLC timer presets
• E-Bus / Rack Current — sum device currents against a bus rating for headroom
• Control Systems — pocket servo lab: plant library or custom G(s), P→PI→PID step metrics with Ziegler–Nichols (Ku/Pu and FOPDT) and an Open / P / PI / PID overlay so you can simulate different responses, Bode margins (PM, GM, ωc, ωb), and a lead compensator with analog R/C suggestion. Educational approximations — not for safety-critical commissioning. State-space LQR/Kalman/MPC stays on the website.

Toolkit — basics, bench / homework, and references:

Basics:

• Ohm's Law
• Voltage divider (Vout, or solve R1 / R2)
• Series / parallel resistors and capacitors
• Resistor color code (4-band and 5-band, decode and encode)
• Frequency, period, free-space wavelength, and LC resonance f = 1/(2π√(LC))
• LED current-limiting resistor and RC time constant τ = RC (555 timing stays in the 555 tool)
• 555 timer (astable and monostable)
• Unit converter: SI prefixes for V/A/Ω/W, dB ratio, °C/°F, m/ft, mils/mm

Bench:

• Reactance & resonance, Phasor Diagram, Magnetic Circuit
• Transient Circuits — RC/RL charge and discharge, value at a time, and the curve
• Fiber Link / NA and Gaussian Beam — numerical aperture, V-number, Rayleigh range, and beam radius
• Semiconductor I-V — diode forward current from the Shockley equation, with the I-V curve
• Analog Design Workbench — ideal op-amp stages (inverting, noninverting, follower, difference, summing, integrator, differentiator) and RC / Sallen–Key filters with a magnitude Bode sketch
• Noise & SNR — Johnson noise, optional shot, amplifier e_n / i_n, total referred noise, SNR, and a rough noise figure (not a SPICE .noise run)
• Linear / LDO Regulator — LM317-style Vout from R1/R2 (or solve R2), dropout, Pd, and a θJA junction-temperature estimate
• Instrumentation Amp — 3-op-amp gain G = 1 + 2R/Rg, or a 4-resistor difference amp, with output swing vs rails
• ADC / DAC & Sampling — LSB, code count, ideal quantization SNR, Nyquist, optional DAC code-to-voltage (not the 4–20 mA scaler)
• RF Power & Link — dBm to watts, VSWR and return loss, free-space path loss
• Number Base Converter — binary, octal, decimal, hex, plus signed 8/16/32-bit read of the same bits
• Heater Design Wizard — resistive heater line current, leg R, and resistance-wire length
• Solenoid Design Wizard — winding pack, center B, inductance, copper loss, axial field plot, and plunger force
• EMP / EMC Shielding — skin depth, sheet SE, Faraday-loop voltage, and aperture leakage (protection-side educational; not pulse-source design)
• E-Bike Torque / RPM — shaft torque or RPM from mechanical power (W, kW, or hp)
• Sprocket Ratio Designer — drive/driven teeth to ratio, output RPM/torque, and optional wheel speed, or invert a target
• Range Estimator — pack V×Ah and Wh/mi to miles, kilometers, and runtime (not a GPS speed)
• Battery Pack Designer — series/parallel pack planning from cell ratings or a voltage/current target (design aid; verify datasheet, BMS, and fusing before you build — not a weld cert). Use Battery Bank Sizing (Field → Power) for usable DoD and runtime
• Nickel Strip — strip cross-section to planning continuous and short-pulse current (derate for alloy, path, and welds)

Reference:

• Reference Library — NEMA, IP ratings, conductor colors, hazardous areas, insulation, torque, conduit, and standard sizes
• Panel Directory — paste or on-device OCR of a panel schedule / sticker into circuit, name, trip, and poles
• Load Calculation Worksheet — NEC 220.42 lighting demand plus motor/continuous VA totals
• Cable Schedule Generator — sequential cable IDs from a type catalog with CSV copy

Instruments (Field subsection) — measure with public Apple APIs (not private APIs):

• Wi-Fi path: **Online / Captive** first (HTTP GET to Apple’s `captive.apple.com/hotspot-detect.html` — Success means no captive portal; redirect/login HTML is called captive; a path that cannot reach that host is local-only). Then Apple’s public 0…1 `signalStrength` shown as percent/bars when `NEHotspotNetwork` returns it, optional local IPv4 from the probe’s Network `localEndpoint`, an on-device coverage heatmap (GPS walk or tap-on-floor), and **link quality (RTT)** via TCP connect time to the path gateway or a user-chosen host (1.1.1.1 / beckify.com). Raw path chrome (`en0`, `pdp_ip0`, expensive/constrained) is behind a collapsed Advanced path disclosure. iOS does not give third-party apps Wi-Fi RSSI in dBm; this tool will not invent dBm. RTT is not ICMP ping. A LAN/gateway target may prompt for Local Network. Online / Captive to Apple’s public host does not. Current SSID needs location plus, on a signed team, Access Wi-Fi Information. Catalog **Look Check** is a separate photo tool on Jobsite.
• Cellular path (CoreTelephony + Network.framework): the same **Online / Captive** probe, then color arc gauges for **radio generation** (2G…5G from RAT — not signal bars and not RSRP) and **TCP RTT milliseconds**, plus a carrier / RAT chip board for the identified data service (type, generation, RAT, PLMN, MCC/MNC, carrier). Per-service carrier name, MCC/MNC, ISO country, radio-access technology (5G NR / LTE / 3G / …), data-service identity, default-path vs cellular-required path flags (collapsed under Advanced path), and optional **link quality (RTT)** via TCP connect while the default path uses cellular. iOS does not give third-party apps cellular RSRP, RSRQ, SINR, RSSI, or dBm; this tool will not invent those. CTCarrier is deprecated as of iOS 16 with no public replacement — empty subscriber fields stay blank. A collapsed reference sheet explains typical RSRP/RSRQ/SINR bands and is labeled as not measured on this device.
• BLE scanner (CoreBluetooth): name, identifier, RSSI, advertised services
• Noise meter (microphone): uncalibrated dBFS. Not an SLM, not OSHA legal
• Bubble level / plumb (CoreMotion)
• Magnetometer: heading and |B| in µT
• Barometer / relative altitude
• g-force snapshot
• Position (GPS) when that tool is opened — not at launch
• Device battery and thermal diagnostics

Search Field and Toolkit (try “ampacity”, “ebike”, “sprocket”, “range”, “18650”, “conductor cost”, “conductor length”, “milliohm”, “shorted parallel”, “conduit”, “tap”, “THD”, “UPS”, “nameplate”, “ocr”, “look check”, “analyze look”, “heater”, “solar”, “pv”, “op amp”, “lm317”, “snr”, “adc”, “pid”, “bode”, “receptacle”, “motor”, “phasor”, “fiber”, “LED”, “wifi”, “captive”, “cellular”, “lte”, “5g”). Results show which area a tool lives in. Each existing tool keeps last-used inputs on this device, copies a numeric result, can show the formula with your numbers plugged in, and lists related tools from the same toolbox. Every catalog tool also has a short **How it works** note (toolbar About / collapsed disclosure — open by default on homework tools) covering what it computes, when to use it, and honesty limits. Instruments state public-API limits (no invented Wi‑Fi/cellular dBm). Selected existing calculators show engineer plots (Swift Charts) and can Share or save a PNG through the system share sheet. Save named jobs on device as homework or field notes; Field jobs sort first, and Open in tool restores matching inputs when they still map. No account, no ads, no analytics, no tracking.

This app is a design aid. It is not a PE stamp, permit, inspection, calibrated instrument, or a substitute for the National Electrical Code or a qualified engineer.

**Keywords (100 characters max, comma-separated draft):**
electrical,NEC,ampacity,THD,UPS,tap,heater,nameplate,ocr,ohm,motor,solar,pid,bode,adc,ebike,cellular

**What's New (draft for next Connect build — no binary uploaded):**
**Look Check** is now a first-class Jobsite tool: take or choose a photo, preview it on device, then tap **Analyze Look** to upload for a playful good-or-bad verdict plus lighting / framing / expression / sharpness metrics. Entertainment only — not medical or dating advice. Taking or choosing a photo does not upload it. The Wi-Fi / Cellular connectivity probe is labeled **Online / Captive** so it is not confused with this photo product. iOS still cannot read Wi-Fi or cellular dBm — this build does not invent RSSI/RSRP. No tools removed. No ads, no IAP. Not TestFlight; no binary uploaded; not App Store submit.

**Support URL:** https://beckify.com  
**Marketing URL:** https://beckify.com  
**Copyright:** 2026 Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com

**Privacy Policy URL:** https://beckify.com/privacy (live; also served at https://beckify.com/privacy/). App Store Connect needs this public HTTPS URL. Source text: [`PRIVACY.md`](PRIVACY.md). Look Check Analyze Look is a user-initiated photo upload; update the App Privacy nutrition label to Photos (App Functionality, not linked, not tracking).

## Cellular App Store limitation (honest)

Public iOS APIs do **not** provide cellular RSRP, RSRQ, SINR, RSSI, or dBm to third-party apps. `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology` reports RAT strings (`CTRadioAccessTechnologyNR`, `LTE`, …). `dataServiceIdentifier` marks the data SIM. `serviceSubscriberCellularProviders` still returns `CTCarrier` fields (name, MCC, MNC, ISO country, `allowsVOIP`) but **CTCarrier is deprecated as of iOS 16 with no public replacement** — values may be empty. `NWPathMonitor` (default and `requiredInterfaceType: .cellular`) reports path status, `usesCellular`, expensive/constrained, interface names, and IPv4/IPv6/DNS support. `CTCellularData` reports whether the app’s cellular data is restricted. Complementary **link quality (RTT)** is TCP connect time while the default path uses cellular — not ICMP ping, not RSRP. Color arc gauges map **radio generation** (2G…5G from RAT) and measured TCP **RTT milliseconds** only — never fabricated RSRP. Do not add private APIs or status-bar scraping to fake a field-strength meter.

## Wi-Fi App Store limitation (honest)

Public iOS APIs do **not** provide Wi-Fi RSSI or dBm to third-party apps (Apple DTS). **Online / Captive** is an HTTP GET to `captive.apple.com/hotspot-detect.html` over Network.framework TCP (not URLSession cleartext, so no ATS exception). A `Success` body is “no captive portal”; a redirect or login HTML is “captive portal”; a satisfied path that cannot reach the host is “local only.” Optional local IPv4 is the probe connection’s `localEndpoint` when it is IPv4 — not a public-IP service and not RSSI. `NWPathMonitor` reports path status; interface names stay behind Advanced path. `NEHotspotNetwork.fetchCurrent` may return SSID/BSSID and a **0.0–1.0** `signalStrength` after location (and Access Wi-Fi Information on a signed team). That 0–1 value is often 0.0; it is not calibrated dBm and is shown as percent/bars only. The in-app heatmap sketches Apple’s 0–1 strength versus GPS or a tapped floor plan. Complementary **link quality (RTT)** is TCP connect time (refused RST still counts) to `NWPath.gateways` or a user-chosen host — not ICMP ping, which App Store apps cannot send. A LAN/gateway target may show the Local Network prompt; without that permission the probe fails honestly. Online / Captive to Apple’s public host does not need Local Network. iOS does not always publish a gateway. Do not add private APIs to fake a dBm meter. On a Mac with a paid team, optionally add the **Access Wi-Fi Information** capability if SSID is empty in review devices. Catalog **Look Check** is a separate photo tool and is not this probe.

## App privacy (nutrition label)

Data collection: **Photos** only when the user taps **Analyze Look** in Look Check (see [`PRIVACY.md`](PRIVACY.md)). Not linked to identity. Not used for tracking.

- No analytics
- No tracking
- No advertising identifier
- No account
- Saved jobs and last-used tool inputs use on-device storage only (`UserDefaults`)
- Microphone, Bluetooth, location, and CoreTelephony radio identity are processed on device inside those tools; numeric snapshots are saved only if the user taps Save
- Look Check photos stay on device until Analyze Look; Motor Nameplate OCR and Panel Directory photos never upload

Privacy manifest: `Beckify/PrivacyInfo.xcprivacy`  
- `NSPrivacyTracking` = false  
- Photos or Videos collected for App Functionality, not linked, not used for tracking  
- UserDefaults accessed with reason CA92.1 (app functionality: saved jobs and last-used inputs)

Usage strings (generated Info.plist): microphone, Bluetooth Always / Peripheral, location When In Use, Local Network (Wi-Fi Path or Cellular Path TCP RTT to a LAN host), camera — see the Beckify target build settings. Photo Library full access is not requested; Look Check, Motor Nameplate OCR, and Panel Directory use the system picker and/or camera. Cellular Path does not request location.

## Export compliance

The app uses HTTPS for optional links the user taps (beckify.com, mailto) and for Look Check **Analyze Look** (`https://beckify.com/api/analyze-look` or a user-entered HTTPS endpoint). **Online / Captive** also opens a cleartext HTTP GET to Apple’s public captive-portal detect host (`captive.apple.com`) — the standard hotspot-detect technique; the request carries no user content. It does not implement custom cryptography. Info.plist includes `ITSAppUsesNonExemptEncryption = NO`. In App Store Connect, answer **No** to “Does your app use encryption?” except the standard HTTPS exemption if the form still appears.

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

1. Field home (Jobsite / Power / Controls / Instruments) with Field | Toolkit control and the Quick strip (avatar row of pinned jobsite tools). First-open / marketing: no Recents row, no tool-count pills or shelf totals.
2. Toolkit home (Basics / Bench / Reference)
3. Search results labeled Field vs Toolkit
4. Wire Size & Ampacity waterfall, Conductor Cost Optimizer ranking, or Voltage Drop with parallels + handoff
5. Motor Nameplate OCR review (photo + highlighted fields) or Motor Nameplate Analyzer result card
6. Receptacle Selector (NEMA 5-15R or L16-30 pinout + public PNs)
7. Saved Jobs list (Field jobs first; Open in tool)
8. Favorites list (starred tools pinned for one-tap access)
9. A calculator showing an engineer plot with the Share control (Ohm's Law V–I load line, LED/RC charge/discharge, Transient Circuits response, or Phasor Diagram)
10. Solar Design Wizard — panel aim readouts (tilt/heading) and/or a sizing result with optional storage (do not claim sensors were live in Simulator if they were not)
11. Toolkit → Bench e-bike tools — Torque/RPM, Sprocket Ratio, Range Estimator, or Pack Designer result (design-aid framing visible; not Field)
12. Cellular Path — Online / Captive verdict plus color arc gauges for radio generation (2G…5G from RAT) and TCP RTT ms, plus the carrier / RAT chip board (do not imply RSRP/dBm; this is a suggested shot, not a captured screenshot)
13. Wi-Fi Path — Online / Captive first (no captive portal / local only / captive), Apple strength %/bars when available, no dBm row (suggested shot, not captured)
14. Look Check — photo preview plus Analyze Look metrics (entertainment disclaimer visible)

Pick a 3–8 subset and include the plot + Share shot if you have room.

The app follows the system light or dark appearance; it does not force dark. System appearance shots are fine — do not require dark-only screenshots. Do not claim outdoor/high-contrast beyond what Settings actually does. Do not show ads, Amazon, games, or a phone number.

## App icon

App icon is `Beckify/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (opaque 1024×1024 RGB, single catalog slot). White tunnel refine of Trevor’s preferred mark: **four** nested pure-white (`#FFFFFF`) rings on opaque black (`#000000`), sharing a single **bottom tangent** (tunnel / aperture — not concentric, not copper). Heavier strokes at 1024 — outer 56px, inners 40 / 28 / 24px, no hairlines — so the mark still reads at ~60pt home-screen size. Regenerated by `ios/scripts/generate_app_icon.py` (even black gaps at the top of the stack; ~10% safe margin from canvas edge to the outer stroke). Full-bleed square — do not pre-round corners or add alpha; Apple applies the squircle. No wordmark, no SF Symbol, no photo, no glow, no gradients, no copper/teal accents. Do not use a photograph of a real person.

## Remaining steps (Mac + App Store Connect)

**Next binary / App Store upload:** `CURRENT_PROJECT_VERSION` (CFBundleVersion) must be **≥ 79**. App Store Connect rejected **1.0 build 78** on **2026-09-04** with **ITMS-90382** (daily upload limit). Next upload after ~2026-09-05. Wait **one day** between upload storms. Xcode Cloud has been minting high numbers independently of the old pbxproj `1`; if a Cloud workflow start build number exists in ASC, set it to **79** so Cloud does not collide. This repo has no `ci_scripts` / `.xcode-cloud` start-number file.

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
2. Optionally add **Access Wi-Fi Information** if you want SSID from `NEHotspotNetwork.fetchCurrent` on device. Wi-Fi Path still uses Online / Captive plus Apple’s public 0–1 `signalStrength` (percent/bars) plus TCP RTT, not dBm.
3. Run on a physical device at least once if not already done (capability / provisioning / sensor check). This Linux CI job does not do that.
4. **DPLA:** Trevor must accept the Apple Developer Program License Agreement in App Store Connect / developer.apple.com if it is still pending. This environment cannot do that.
5. Capture screenshots at the sizes below. Do **not** ship website screenshots.
6. Archive in Xcode (Product → Archive) or `xcodebuild archive` with signing enabled (`DEVELOPMENT_TEAM` `9TR6R5LV8M`).
7. Upload the signed archive (Organizer or Transporter). Wait for processing. Upload is still outstanding; that is not TestFlight distribution and not App Store submit.
8. Attach screenshots, review the encryption and content-rights questions, then submit for review (not done).
9. Answer App Review if they ask about NEC table transcription, microphone/Bluetooth/location strings, or “design aid” disclaimers.
10. Work the [`FIVE_STAR_READINESS.md`](FIVE_STAR_READINESS.md) Connect + device gate before Submit. After ITMS-90382 (~2026-09-05), upload a **new** version/build tuple once — do not retry the same binary.

Until those steps are done, there is **no** uploaded binary. The app is **not** on TestFlight and **not** on the App Store.
