# App Store scaffolding — Beckify

Listing copy for the native SwiftUI **Beckify Toolbox** app (iPhone + iPad, no ads). Standalone **Look Check** (`com.beckify.lookcheck`) and **Kestrel Heavy** (`com.beckify.kestrelheavy`) are separate products — see [`../LookCheck/docs/APP_STORE.md`](../LookCheck/docs/APP_STORE.md) and [`../KestrelHeavy/docs/APP_STORE.md`](../KestrelHeavy/docs/APP_STORE.md). Trevor Beck enrolled in the **Apple Developer Program** on 2026-09-02. An **App Store Connect record exists**. **Version 1.0 is approved** — that pre-release train is closed. Transporter rejected **1.0 (121)** (**ITMS-90186** Invalid Pre-Release Train, **ITMS-90062** `CFBundleShortVersionString` must be higher than approved **1.0**). Next Connect version is **1.0.1**, build **159**. TestFlight already had **1.0.1 (149)** as of ~2026-09-17/18 (Trevor; this repo did not query App Store Connect). Repo `CURRENT_PROJECT_VERSION` is **159**, past main’s **158** (Archive EditButton #187) and the failed Xcode Cloud build **157**. Earlier tip was 156 (Settings #184). Xcode Cloud Build 155 failed to compile and did not upload. Xcode Cloud may auto-bump; if TestFlight or Cloud already has **≥159**, bump again before the next Archive. Trevor must **create or select version 1.0.1** in App Store Connect before uploading. Archive the **Beckify** scheme (`com.beckify.toolbox`), not LookCheck or KestrelHeavy. Xcode Cloud Archive-iOS for Toolbox stays on **Beckify** only.

This Linux environment has not compiled the SwiftUI or CoreMotion/AVFoundation UI, signed a binary, captured screenshots, archived, or uploaded a build.

**Five-star / review-risk plan:** [`FIVE_STAR_READINESS.md`](FIVE_STAR_READINESS.md) — competitor 1★ patterns, first-open/trust punch list, Connect checklist, respectful `requestReview` timing, and honesty constraints (no fake Wi‑Fi/cellular dBm). Use the ITMS-90382 cooldown to finish that list before the next upload.

## Listing copy

**Name:** Beckify  
**Subtitle:** Field EE toolbox  
**App ID (Apple ID):** `6807908745`  
**Bundle ID:** `com.beckify.toolbox`  
**SKU:** `beckify-toolbox`  
**Connect status:** **1.0 approved** (train closed). Next version **1.0.1** (create or select in Connect before upload); next binary **1.0.1 (159)**. TestFlight already processed **1.0.1 (149)** (~2026-09-17/18). Repo build is **159**.
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

• Voltage Drop — code follows Settings. NEC (default) is K-factor VD with parallels, target %, ampacity check, and optional ampacity→VD handoff. 1Ø and 3Ø also show a NEC 2023 Table 250.122 equipment grounding conductor from the next standard OCPD. AS/NZS uses metric sizes, a resistance-only drop (IEC 60228 maximum R, reactance omitted — not AS/NZS 3008 mV/A·m), Clause 3.6.2’s 5% limit, and a Table 5.1 copper earth. AS/NZS current-carrying capacity is not checked. Design aid; confirm the standard / AHJ; not a PE or AEE stamp.
• Conductor Cost Optimizer — compares compliant sizes and parallel runs using a user-entered or default planning $/kft and optional I²R energy. Planning allowance only — not LME or a bid
• Conductor Length by Resistance — estimate length from a milliohm (mΩ) reading, end-to-end or short-to-parallel, with copper/aluminum temperature compensation, AWG/kcmil or custom circular mils, and estimated copper or aluminum weight (book lb/kft × one-way length, not a scale reading)
• Conduit fill — same-size or mixed conductor sizes; Chapter 9 Table 1 vs Table 4 raceways and Table 5 areas (EMT, IMC, RMC, PVC, ENT, FMC, LFMC). When you pick 1Ø, multiwire, or 3Ø and enter an OCPD or load, a NEC 2023 Table 250.122 EGC is shown beside the fill. It is counted in the raceway only if you turn Count EGC on. Mixed fill math is otherwise unchanged.
• Motor full-load current from NEC Tables 430.248 and 430.250
• Motor Speed & Torque — synchronous RPM, slip from a nameplate, and shaft torque from HP
• Motor Nameplate Analyzer — overload (430.32), Table 430.52 SCPD, 430.22 conductor, code-letter LRA (typed or seeded from a confirmed OCR review)
• Motor Nameplate OCR — camera or photo library, on-device flatten and contrast lift, then multi-pass Vision, then heuristic field extract into the shared nameplate schema (value + confidence + reviewed). A low scan-quality score asks for a retake. Optional **Analyze** POSTs the photo to `/api/analyze-nameplate` only when you tap it. Confirm marks reviewed. MOCP and LRA are never used as FLA. Optional seed into Motor FLA / Analyzer / Speed.
• Look Check — camera or photo library, then Analyze Look for a playful look verdict plus lighting / framing / expression / sharpness metrics and a roast. Entertainment only — not medical, dating, or beauty authority. The photo stays on this device until you tap Analyze Look. Same `/api/analyze-look` contract as the website. Not the Wi-Fi / Cellular Online / Captive connectivity card.
• Wire Size & Ampacity — NEC Table 310.16 with ambient correction, CCC adjustment, termination cap, and continuous load. Circuit starts as phase conductors only. Choosing 1Ø, multiwire, or 3Ø shows a NEC 2023 Table 250.122 EGC beside the phase size (design aid; not a PE stamp)
• Receptacle Selector — NEMA / IEC 60309 / international household / Meltric best-fit faces through 400 A, schematic pinout, cited public PNs (design aid; not a UL listing or distributor cross). AS/NZS ranks AS/NZS 3112 Type I ahead of other household faces near 230 V. One catalog, not a second tool.
• Short-circuit current, circular mils, load & demand factors
• NEC Circuit Calculator — design current, derated conductor, voltage drop, and OCPD in one pass (live one-shot calc, not paperwork). When phase and amps imply a feeder ground, a NEC 2023 Table 250.122 EGC is shown. A service grounding electrode conductor stays Table 250.66.
• IS Loop Verifier — Entity Concept check of barrier Voc/Isc/Ca/La against the field device and cable (design aid)

Power — facility and distribution energy only (saved Power Wizard jobs still open; Power Wizard is not listed):

• Power — DC identities (P=VI, I²R, V²/R) and 1Ø / 3Ø kVA, kW, kVAR. Formulas do not change with code. AS/NZS labels the nominal supply as 230 V single-phase and 400 V three-phase at 50 Hz.
• Transformer sizing and overcurrent protection (NEC 450.3(B), including Note 1). Selecting AS/NZS does not switch this tool; it says the result is still NEC.
• Tap-Changer Calculator — DETC tap recommendation from measured secondary voltage
• Power-factor correction
• Harmonics (THD) — current THD, dominant order, and IEEE 519 discussion bands (informational)
• Battery Bank Sizing — series/parallel cells to bank voltage, amp-hours, and runtime
• Solar Design Wizard — size PV from rooftop to utility, aim panels with phone sensors, optional energy storage
• UPS / On-site Power — design kVA, runtime, and battery Ah from critical load

Settings (gear) chooses NEC (US), the default, or AS/NZS, plus length units and appearance (system, light, or dark — system is the default and does not force dark mode). Wire ampacity, conduit fill, motor FLA, conductor cost, conductor length, the NEC circuit calculator, the load worksheet, and the motor nameplate analyzer do not yet have AS/NZS tables. Those screens say “AS/NZS not available for this tool yet — showing NEC” and keep the NEC labels, including Table 250.122 and the conduit Count EGC toggle. IEC 60364, CEC, and BS 7671 are not selectable.

Controls:

• Signal scaling (4–20 mA), Modbus address forms, PLC timer presets
• E-Bus / Rack Current — sum device currents against a bus rating for headroom
• Control Systems — pocket servo lab: plant library or custom G(s), P→PI→PID step metrics with Ziegler–Nichols (Ku/Pu and FOPDT) and an Open / P / PI / PID overlay so you can simulate different responses, Bode margins (PM, GM, ωc, ωb), and a lead compensator with analog R/C suggestion. Educational approximations — not for safety-critical commissioning. State-space LQR/Kalman design stays on the website.
• Control Strategies — comparison for field techs: bang-bang / hysteresis, PID and gain-scheduled PID, MPC, fuzzy / ANFIS, sliding mode, DRL / physics-informed RL, ADRC, and NN adaptive / PINN / ML-MPC. Matrix (model, tuning, settling, overshoot, ess, chatter, disturbance, compute, field care), linear vs nonlinear, SISO vs MIMO, sub-millisecond vs process loops, examples for HVAC, motor drives, robotics, flight/launch, and BMS, plus a constraint picker. Teaching plots (step overlay, hysteresis, sliding-mode chatter, cost vs tracking). Design aid — not a tuner and not a guarantee of stability. DRL / PINN / ML-MPC are when-to-use notes only; nothing is trained on or off this device. PID, Bode, and lead stay in Control Systems.

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
• Panel Directory — camera or photo library (preview stays on screen). On-device pipeline: perspective flatten when a page rectangle is found, contrast / glare lift, multi-pass Vision (electrical vocabulary, second pass with language correction off when the first read is weak), then a fuzzy grid into an editable schedule (circuit, name, trip, poles, class — value + confidence + reviewed). A 0–1 scan-quality score can ask for a retake. It is not a confidence interval and not a PE stamp. Odd/even circuit numbers may be inferred when the print is missing — confirm them. Optional **Analyze** POSTs the photo to `/api/analyze-panel` only when you tap it. Confirm marks reviewed. Demand and capacity-to-add use breaker trip as a conservative connected-amp estimate through the same NEC 220.42 worksheet as Load Calculation Worksheet — not a stamped load calc. FLA and kAIC shown from the photo are reads, not measurements.
• Load Calculation Worksheet — NEC 220.42 lighting demand plus motor/continuous VA totals
• Cable Schedule Generator — sequential cable IDs from a type catalog with CSV copy

Instruments (Field subsection) — measure with public Apple APIs (not private APIs):

• Wi-Fi path: **Online / Captive** first (HTTP GET to Apple’s `captive.apple.com/hotspot-detect.html` — Success means no captive portal; redirect/login HTML is called captive; a path that cannot reach that host is local-only). Then Apple’s public 0…1 `signalStrength` shown as percent/bars when `NEHotspotNetwork` returns it, optional local IPv4 from the probe’s Network `localEndpoint`, an on-device coverage heatmap (GPS walk or tap-on-floor), and **link quality (RTT)** via TCP connect time to the path gateway or a user-chosen host (1.1.1.1 / beckify.com). Raw path chrome (`en0`, `pdp_ip0`, expensive/constrained) is behind a collapsed Advanced path disclosure. iOS does not give third-party apps Wi-Fi RSSI in dBm; this tool will not invent dBm. RTT is not ICMP ping. A LAN/gateway target may prompt for Local Network. Online / Captive to Apple’s public host does not. Current SSID needs location plus, on a signed team, Access Wi-Fi Information. Catalog **Look Check** is a separate photo tool on Jobsite.
• Cellular path (CoreTelephony + Network.framework): the same **Online / Captive** probe, then color arc gauges for **radio generation** (2G…5G from RAT — not signal bars and not RSRP) and **TCP RTT milliseconds**, plus a carrier / RAT chip board for the identified data service (type, generation, RAT, PLMN, MCC/MNC, carrier). Per-service carrier name, MCC/MNC, ISO country, radio-access technology (5G NR / LTE / 3G / …), data-service identity, default-path vs cellular-required path flags (collapsed under Advanced path), and optional **link quality (RTT)** via TCP connect while the default path uses cellular. iOS does not give third-party apps cellular RSRP, RSRQ, SINR, RSSI, or dBm; this tool will not invent those. CTCarrier is deprecated as of iOS 16 with no public replacement — empty subscriber fields stay blank. A collapsed reference sheet explains typical RSRP/RSRQ/SINR bands and is labeled as not measured on this device.
• BLE scanner (CoreBluetooth): name, identifier, RSSI, SIG manufacturer company ID, TX power, connectable, service-data UUIDs, kind hints, a live radar layout, plus an **RF activity index**, **room mix**, and **device-ID churn**. Those insights are unique-advertisement / RF-density notes — not occupancy or a people count. Device count ≠ people. Apple rotates identifiers. Radius is a rough RSSI→distance estimate (not calibrated ranging). Advertised TX is output, not RSSI at 1 m. Angle is a stable layout slot, not angle-of-arrival — iOS does not expose BLE AoA to third-party apps.
• Noise meter (microphone): uncalibrated dBFS plus a live audible-band FFT (relative dBFS, Hann/Hamming/Blackman window, fs and Nyquist shown). Rough harmonic % is leftover mic-FFT energy — not THD, not dB SPL, not a transformer nameplate. Freeze holds the plot. Share saves a PNG with a timestamp, not audio and not GPS. Not an SLM, not OSHA legal. Same on-device MicrophoneSpectrum tap as Acoustic Imager and Setup Check.
• Acoustic Imager (microphone, Field → Instruments, next to Noise Meter): on-device audible spectrum, relative level, and recent time activity from a public AVAudio tap and Accelerate FFT. Not a Fluke acoustic camera, not ultrasonic beamforming, and not a leak position. Audio stays on this device, is not recorded, and is not uploaded. Same microphone usage string and the same MicrophoneSpectrum tap as Noise Meter and Setup Check, so these screens do not start a second engine.
• Setup Check (microphone, Field → Instruments): one room-and-rig analyzer for a listening spot or a field rig. Live FFT, a short spectrogram, approximate 1/3-octave RTA, level versus time, crest factor, relative dynamic range, clipping, and rough harmonic energy. Optional pink noise, a log sweep, or tone bursts play from the phone speaker through the same AVAudioEngine tap — not a second FFT. A sweep draws an unsmoothed shape plus a 1/3-octave smooth, peak-normalized, not a calibration curve. Loop delay is a rough speaker-to-mic gap when a burst rises out of the room. Most iPhones expose one mic path, so stereo balance stays blank unless a second channel arrives. Phone speaker plus mic is not a calibrated measurement microphone, not REW, not THX, and not absolute dB SPL. Audio is not recorded or uploaded. Same microphone usage string. Noise Meter and Acoustic Imager link to it. Share saves a PNG with a timestamp, not audio.
• Breath Flute (play tool, Field → Instruments, not on the Quick row): blow gates a local tone; touch or a fret sets pitch. A tiny relative spectrum is for play, not a meter. Nothing is recorded or uploaded. Same microphone usage string as Noise Meter.
• Bubble level / plumb (CoreMotion)
• Magnetometer: heading, |B| in µT, and Mag Sweep (|B| minus a captured baseline, peak hold, sparkline). Optional slow field-variation spectrum is DC |B| change only — not AC EMF and not a 50/60 Hz power-line meter. Phone magnets dominate. Not a stud finder or a live-wire detector.
• Barometer / relative altitude — unavailable empty state (no crash) if the sensor is missing, Motion & Fitness is off, or Core Motion errors
• Stillness Anomaly Watch: while the phone sits still, ticks for DC |B|, pressure, a mic impulse, and BLE advertiser changes, plus a timeline. A bump is labeled “phone moved” and is not an anomaly. Not a ghost detector, presence meter, EMF meter, Trifield, live-wire finder, or RF/5G meter. BLE means advertisers changed, not occupancy and not people. Mic audio is not recorded.
• g-force snapshot
• Coupled Vibration: phone pressed to a machine or duct. User-acceleration RMS (magnitude and x/y/z), a spectrum that stops at the delivered Nyquist (fs/2 — not a claimed 0–400 Hz band), peak frequency, and a relative RPM label (frequency × 60) marked phone-mounted. Session A/B compare. Not ISO 10816, not a calibrated pickup, not a tachometer, and not a bearing-fault diagnosis. Share saves a PNG, not a track. Distinct from g-Force Snapshot.
• Position (GPS) when that tool is opened — not at launch
• Device Health — charge, Low Power Mode, free storage, model / iOS, uptime, and a one-line thermal meaning. Diagnostics only — not Apple Battery Health %, not a charger tester, not a health score

Search Field and Toolkit (try “setup check”, “pink noise”, “ampacity”, “ebike”, “sprocket”, “range”, “18650”, “conductor cost”, “conductor length”, “milliohm”, “shorted parallel”, “conduit”, “tap”, “THD”, “UPS”, “nameplate”, “ocr”, “look check”, “analyze look”, “roast”, “heater”, “solar”, “pv”, “op amp”, “lm317”, “snr”, “adc”, “pid”, “bode”, “mpc”, “adrc”, “receptacle”, “motor”, “phasor”, “fiber”, “LED”, “wifi”, “captive”, “cellular”, “lte”, “5g”). Results show which area a tool lives in. Each existing tool keeps last-used inputs on this device, copies a numeric result, can show the formula with your numbers plugged in, and lists related tools from the same toolbox. Every catalog tool also has a short **How it works** note (toolbar About / collapsed disclosure — open by default on homework tools) covering what it computes, when to use it, and honesty limits. Instruments state public-API limits (no invented Wi‑Fi/cellular dBm). Selected existing calculators show engineer plots (Swift Charts) and can Share or save a PNG through the system share sheet. Save named jobs on device as homework or field notes; Field jobs sort first, and Open in tool restores matching inputs when they still map. No account, no ads, no analytics, no tracking.

This app is a design aid. It is not a PE stamp, an AEE stamp, a permit, an inspection, a calibrated instrument, or a substitute for the National Electrical Code, AS/NZS 3000, AS/NZS 3008, or a qualified engineer.

**Keywords (100 characters max, comma-separated draft):**
electrical,NEC,ampacity,THD,UPS,tap,heater,nameplate,ocr,ohm,motor,solar,pid,bode,adc,ebike,cellular

**What's New (draft for next Connect upload — 1.0.1 build 159):**
Setup Check sits on Field → Instruments with Noise Meter and Acoustic Imager. It is one room-and-rig screen: live FFT, a short spectrogram, approximate RTA bands, level versus time, crest factor, clipping, and optional pink noise, a log sweep, or tone bursts from the phone speaker. Relative A/B only — not a calibrated measurement mic, not REW, not THX, and not absolute dB SPL. Audio is not recorded or uploaded. Share saves a PNG with a timestamp. Settings (gear) adds an electrical code: NEC (US) stays the default, and AS/NZS is selectable. Voltage Drop can run a metric resistance check with a Table 5.1 earth. Power shows 230/400 V at 50 Hz. Receptacle Selector prefers AS/NZS 3112 Type I near 230 V. Other NEC-table tools say so instead of relabeling NEC results. Design aid — not a PE or AEE stamp. Panel Directory and Motor Nameplate OCR preprocess the photo on this device (flatten a page rectangle when one is found, lift faded ink, compress glare) and read it with a second Vision pass when the first is weak. Panel Directory shows a scan-quality score and can infer odd-left / even-right circuit numbers when the print is missing. Confirm every row — this is not a PE stamp. Acoustic Imager sits next to Noise Meter: an on-device microphone spectrum, relative level, and recent time activity. Not a sound camera and not a leak locator. Audio is not recorded or uploaded. Conduit Fill, Wire Size & Ampacity, Voltage Drop, and NEC Circuit can show a NEC 2023 Table 250.122 equipment grounding conductor when phase and amps imply one. It is a design aid — confirm the Code and the AHJ. Conduit fill counts that conductor only if you turn it on. BLE Scanner still shows RF activity, room mix, and device-ID churn — unique advertisements, not occupancy. Device Health is a field snapshot — not Battery Health %. Control Strategies sits with Control Systems: a matrix, plant examples, a constraint picker, and teaching plots for bang-bang, PID, MPC, ADRC, and the rest. It does not tune your loop or train a policy. PID / Bode stays in Control Systems. Field instruments: Stillness Anomaly Watch (baseline ticks and a timeline — not a ghost detector or a presence meter), Mag Sweep on the Magnetometer (DC |B| change, not a 60 Hz EMF meter), Breath Flute (a play tool; nothing recorded), and Coupled Vibration (relative phone-mounted spectrum and A/B, not ISO 10816). Noise Meter now shows the same audible FFT as Acoustic Imager, with fs, Nyquist, a rough relative harmonic note (not THD or SPL), and a PNG share. BLE marks are advertisers, not people. Submit **1.0.1 (159)** — must be a new Connect version above approved **1.0**; do not retry closed-train **1.0 (121)** or the already-processed TestFlight build **1.0.1 (149)**. If TestFlight or Xcode Cloud already has **≥159**, bump `CURRENT_PROJECT_VERSION` before Archive. Create or select **1.0.1** in Connect first. Archive scheme **Beckify**, not LookCheck or KestrelHeavy. Free, no IAP, no ads.

**Support URL:** https://beckify.com  
**Marketing URL:** https://beckify.com  
**Copyright:** 2026 Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com

**Privacy Policy URL:** https://beckify.com/privacy (live; also served at https://beckify.com/privacy/). App Store Connect needs this public HTTPS URL. Source text: [`PRIVACY.md`](PRIVACY.md). Look Check **Analyze Look**, Motor Nameplate **Analyze**, and Panel Directory **Analyze** are user-initiated photo uploads; the App Privacy nutrition label is Photos (App Functionality, not linked, not tracking).

## Cellular App Store limitation (honest)

Public iOS APIs do **not** provide cellular RSRP, RSRQ, SINR, RSSI, or dBm to third-party apps. `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology` reports RAT strings (`CTRadioAccessTechnologyNR`, `LTE`, …). `dataServiceIdentifier` marks the data SIM. `serviceSubscriberCellularProviders` still returns `CTCarrier` fields (name, MCC, MNC, ISO country, `allowsVOIP`) but **CTCarrier is deprecated as of iOS 16 with no public replacement** — values may be empty. `NWPathMonitor` (default and `requiredInterfaceType: .cellular`) reports path status, `usesCellular`, expensive/constrained, interface names, and IPv4/IPv6/DNS support. `CTCellularData` reports whether the app’s cellular data is restricted. Complementary **link quality (RTT)** is TCP connect time while the default path uses cellular — not ICMP ping, not RSRP. Color arc gauges map **radio generation** (2G…5G from RAT) and measured TCP **RTT milliseconds** only — never fabricated RSRP. Do not add private APIs or status-bar scraping to fake a field-strength meter.

## Wi-Fi App Store limitation (honest)

Public iOS APIs do **not** provide Wi-Fi RSSI or dBm to third-party apps (Apple DTS). **Online / Captive** is an HTTP GET to `captive.apple.com/hotspot-detect.html` over Network.framework TCP (not URLSession cleartext, so no ATS exception). A `Success` body is “no captive portal”; a redirect or login HTML is “captive portal”; a satisfied path that cannot reach the host is “local only.” Optional local IPv4 is the probe connection’s `localEndpoint` when it is IPv4 — not a public-IP service and not RSSI. `NWPathMonitor` reports path status; interface names stay behind Advanced path. `NEHotspotNetwork.fetchCurrent` may return SSID/BSSID and a **0.0–1.0** `signalStrength` after location (and Access Wi-Fi Information on a signed team). That 0–1 value is often 0.0; it is not calibrated dBm and is shown as percent/bars only. The in-app heatmap sketches Apple’s 0–1 strength versus GPS or a tapped floor plan. Complementary **link quality (RTT)** is TCP connect time (refused RST still counts) to `NWPath.gateways` or a user-chosen host — not ICMP ping, which App Store apps cannot send. A LAN/gateway target may show the Local Network prompt; without that permission the probe fails honestly. Online / Captive to Apple’s public host does not need Local Network. iOS does not always publish a gateway. Do not add private APIs to fake a dBm meter. On a Mac with a paid team, optionally add the **Access Wi-Fi Information** capability if SSID is empty in review devices. Catalog **Look Check** is a separate photo tool and is not this probe.

## App privacy (nutrition label)

Data collection: **Photos** only when the user taps **Analyze Look** in Look Check, **Analyze** in Motor Nameplate OCR, or **Analyze** in Panel Directory (see [`PRIVACY.md`](PRIVACY.md)). Not linked to identity. Not used for tracking.

- No analytics
- No tracking
- No advertising identifier
- No account
- Saved jobs, last-used tool inputs, and Settings (electrical code, length units, appearance) use on-device storage only (`UserDefaults`)
- Microphone, Bluetooth, location, and CoreTelephony radio identity are processed on device inside those tools; numeric snapshots are saved only if the user taps Save
- Look Check, Motor Nameplate OCR, and Panel Directory photos stay on device until the user taps Analyze / Analyze Look

Privacy manifest: `Beckify/PrivacyInfo.xcprivacy`  
- `NSPrivacyTracking` = false  
- Photos or Videos collected for App Functionality, not linked, not used for tracking  
- UserDefaults accessed with reason CA92.1 (app functionality: saved jobs, last-used inputs, and settings)

Usage strings (generated Info.plist via `INFOPLIST_KEY_*` on the Beckify target, Debug + Release): microphone, Bluetooth Always / Peripheral, location When In Use, Local Network (Wi-Fi Path or Cellular Path TCP RTT to a LAN host), camera, **Motion** (`NSMotionUsageDescription` — Barometer / relative altitude, Bubble Level, Magnetometer, g-Force Snapshot, Stillness Anomaly Watch, Coupled Vibration, optional Solar Design Wizard panel aim). Microphone and Bluetooth strings are unchanged: Noise Meter, Acoustic Imager, Setup Check, Breath Flute, and Stillness share the existing mic sentence; Stillness reuses the BLE Scanner sentence. Photo Library full access is not requested; Look Check, Motor Nameplate OCR, and Panel Directory use the system picker and/or camera. Cellular Path does not request location. Build **113** crashed in App Review (`TCC` / `kTCCServiceMotion`) because this Motion key was missing.

## Export compliance

The app uses HTTPS for optional links the user taps (beckify.com, mailto) and for user-initiated Analyze calls (`https://api.beckify.com/api/analyze-look`, `/api/analyze-nameplate`, `/api/analyze-panel`, or a user-entered HTTPS endpoint). **Online / Captive** also opens a cleartext HTTP GET to Apple’s public captive-portal detect host (`captive.apple.com`) — the standard hotspot-detect technique; the request carries no user content. It does not implement custom cryptography. Info.plist includes `ITSAppUsesNonExemptEncryption = NO`. In App Store Connect, answer **No** to “Does your app use encryption?” except the standard HTTPS exemption if the form still appears.

## Screenshots (required sizes)

Not captured in this repository. This Linux environment has not run an iOS Simulator UI build, signed the app, or submitted to the App Store. TestFlight already had **1.0.1 (149)** as of ~2026-09-17/18; this checkout did not upload that build. On a Mac with Xcode, capture Simulator screenshots at the sizes below. Do **not** ship website screenshots.

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
5. Motor Nameplate OCR review (photo + highlighted fields) or Panel Directory (schedule photo + editable rows + demand / capacity-to-add)
6. Receptacle Selector (NEMA 5-15R or L16-30, or Meltric / international household schematic pinout + cited public PNs)
7. Saved Jobs list (Field jobs first; Open in tool)
8. Favorites list (starred tools pinned for one-tap access)
9. A calculator showing an engineer plot with the Share control (Ohm's Law V–I load line, LED/RC charge/discharge, Transient Circuits response, or Phasor Diagram)
10. Solar Design Wizard — panel aim readouts (tilt/heading) and/or a sizing result with optional storage (do not claim sensors were live in Simulator if they were not)
11. Toolkit → Bench e-bike tools — Torque/RPM, Sprocket Ratio, Range Estimator, or Pack Designer result (design-aid framing visible; not Field)
12. Cellular Path — Online / Captive verdict plus color arc gauges for radio generation (2G…5G from RAT) and TCP RTT ms, plus the carrier / RAT chip board (do not imply RSRP/dBm; this is a suggested shot, not a captured screenshot)
13. Wi-Fi Path — Online / Captive first (no captive portal / local only / captive), Apple strength %/bars when available, no dBm row (suggested shot, not captured)
14. Look Check — photo preview plus Analyze Look metrics and roast (entertainment disclaimer visible)
15. Device Health — charge, Low Power Mode, free storage, model / iOS, uptime, and thermal meaning (do not imply Apple Battery Health % or a charger tester; suggested shot, not captured)

Pick a 3–8 subset and include the plot + Share shot if you have room.

The app follows the system light or dark appearance; it does not force dark. System appearance shots are fine — do not require dark-only screenshots. Do not claim outdoor/high-contrast beyond what Settings actually does. Do not show ads, Amazon, games, or a phone number.

## App icon

App icon is `Beckify/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (opaque 1024×1024 RGB, single catalog slot). White tunnel refine of Trevor’s preferred mark: **four** nested pure-white (`#FFFFFF`) rings on opaque black (`#000000`), sharing a single **bottom tangent** (tunnel / aperture — not concentric, not copper). Heavier strokes at 1024 — outer 56px, inners 40 / 28 / 24px, no hairlines — so the mark still reads at ~60pt home-screen size. Regenerated by `ios/scripts/generate_app_icon.py` (even black gaps at the top of the stack; ~10% safe margin from canvas edge to the outer stroke). Full-bleed square — do not pre-round corners or add alpha; Apple applies the squircle. No wordmark, no SF Symbol, no photo, no glow, no gradients, no copper/teal accents. Do not use a photograph of a real person.

## Path: push `main` → Xcode Cloud Archive → TestFlight

Toolbox only. Scheme **Beckify**. Bundle ID `com.beckify.toolbox`. Team `9TR6R5LV8M`. App ID `6807908745`.

A push to `main` starts both Xcode Cloud workflows for that app:

1. `Beckify | Beckify | Build - iOS` — compile check.
2. `Beckify | Beckify | Archive - iOS` — the TestFlight path. It must archive scheme **Beckify**. A green archive is what Connect can process for TestFlight.

This repository does not submit the build. This checkout did not confirm an App Store Connect or TestFlight upload, and it did not run the app on a device.

Do not point either workflow at scheme **LookCheck** (`com.beckify.lookcheck`) or **KestrelHeavy** (`com.beckify.kestrelheavy`). Those products keep their own Archive schemes, bundle IDs, and version numbers.

Before that archive can land on TestFlight:

- Create or select Connect version **1.0.1**. The **1.0** train is closed.
- Repo `CURRENT_PROJECT_VERSION` is **159**. If TestFlight or Xcode Cloud already has **≥159**, raise that number before the next push to `main`.

### Mac fallback

On a Mac with Xcode, open `ios/Beckify.xcodeproj`, select scheme **Beckify**, confirm Signing & Capabilities shows Team **9TR6R5LV8M**, then **Product → Archive**. Distribute the archive to App Store Connect from Organizer (TestFlight). Command-line equivalent:

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
```

`ExportOptions.plist` is not in this repo. Create one on the Mac only if you export with `xcodebuild -exportArchive` instead of Organizer. This Linux environment did not run that archive or install the result on a device.

## Remaining steps (Mac + App Store Connect)

**Next binary / App Store upload:** Toolbox `MARKETING_VERSION` (`CFBundleShortVersionString`) is **1.0.1**. `CURRENT_PROJECT_VERSION` (CFBundleVersion) is **159**. **1.0 is approved** — that train is closed (**ITMS-90186** / **ITMS-90062**). Transporter rejected **1.0 (121)** for that reason. TestFlight already had **1.0.1 (149)** as of ~2026-09-17/18 (Trevor; this repo did not query App Store Connect). The next Connect upload must be **1.0.1** with build **159**. If Xcode Cloud has auto-bumped past **159**, or TestFlight already shows a build **≥159**, raise `CURRENT_PROJECT_VERSION` above that build before the next Archive — do not re-upload **149** or the stale repo floor **126**. Trevor must **create or select version 1.0.1** in App Store Connect before uploading. Archive the **Beckify** scheme, not LookCheck or KestrelHeavy. Look Check (`com.beckify.lookcheck`) stays **1.0 (1)**; Connect/TestFlight exists under the display name **LookCheck5000** (Xcode display name stays **Look Check**; Archive scheme **LookCheck**). Kestrel Heavy (`com.beckify.kestrelheavy`) repo build is **1.0 (4)** and a TestFlight record exists — if TestFlight already has **≥4**, bump before the next Archive, otherwise the next binary is **1.0 (4)**. Wait **one day** between upload storms (**ITMS-90382**). This repo has no `ci_scripts` / `.xcode-cloud` start-number file.

**Apple Developer Program:** signed up as Trevor Beck (stated 2026-09-02). Enrollment is no longer a blocker.

**App Store Connect record (exists — recorded Connect facts only; do not invent more):**

| Field | Value |
| --- | --- |
| Status | **1.0 approved** (train closed). Create or select **1.0.1** before the next upload |
| Binary | 1.0 approved; 1.0 (113) was rejected by Review (Guideline 2.1, 2026-09-09); 1.0 (121) rejected by Transporter (ITMS-90186 / ITMS-90062). TestFlight already had **1.0.1 (149)** (~2026-09-17/18). Repo build **159**. Next upload **1.0.1 (159)** |
| App ID (Apple ID) | `6807908745` |
| Bundle ID | `com.beckify.toolbox` |
| SKU | `beckify-toolbox` |
| Privacy Policy URL | https://beckify.com/privacy (live) |
| Team prefix | `9TR6R5LV8M` |
| Price | Free ($0), no IAP, no ads (Trevor’s v1 decision) |

The app is native SwiftUI, iPhone + iPad. **Price:** Free, no in-app purchases, no ads. **1.0 is approved.** Transporter rejected **1.0 (121)** because that train is closed. This Linux environment did not compile, sign, or upload **1.0.1 (159)**. Archive scheme **Beckify**, not LookCheck or KestrelHeavy.

Still needed (Mac + Trevor; not done in this Linux environment):

1. Create the app record — already done (see table). On a Mac, open `ios/Beckify.xcodeproj` and set **Team** / confirm Signing & Capabilities shows Team **9TR6R5LV8M** (already in Debug and Release `DEVELOPMENT_TEAM`). Automatic signing still creates certificates/profiles on that Mac.
2. Optionally add **Access Wi-Fi Information** if you want SSID from `NEHotspotNetwork.fetchCurrent` on device. Wi-Fi Path still uses Online / Captive plus Apple’s public 0–1 `signalStrength` (percent/bars) plus TCP RTT, not dBm.
3. Run on a physical device at least once if not already done (capability / provisioning / sensor check). This Linux CI job does not do that.
4. **DPLA:** Trevor must accept the Apple Developer Program License Agreement in App Store Connect / developer.apple.com if it is still pending. This environment cannot do that.
5. Capture screenshots at the sizes below. Do **not** ship website screenshots.
6. Archive scheme **Beckify** only. Preferred path: push to `main` so Xcode Cloud runs `Beckify | Beckify | Archive - iOS` (Build - iOS runs too). Mac fallback: Product → Archive, or `xcodebuild archive`, with Team **9TR6R5LV8M**. Do not archive Toolbox with **LookCheck** or **KestrelHeavy**. Steps are in **Path: push `main` → Xcode Cloud Archive → TestFlight** above.
7. In App Store Connect, **create or select version 1.0.1** (the 1.0 train is closed). The Archive - iOS workflow (or the Mac archive above) must be scheme **Beckify** (`com.beckify.toolbox`). Upload a signed **1.0.1 (159)** archive (Organizer, Xcode Cloud, or Transporter). Wait for processing. Do not re-upload **1.0.1 (149)**, closed-train **1.0 (121)**, or rejected **1.0 (113)**. If TestFlight or Xcode Cloud is already at or above **159**, bump `CURRENT_PROJECT_VERSION` first. This checkout did not upload.
8. Attach screenshots, review the encryption and content-rights questions, then submit for review (not done).
9. Answer App Review if they ask about NEC table transcription, microphone/Bluetooth/location/Motion strings, or “design aid” disclaimers.
10. Work the [`FIVE_STAR_READINESS.md`](FIVE_STAR_READINESS.md) Connect + device gate before Submit. After ITMS-90382, upload the **1.0.1 / 159** tuple once — do not retry TestFlight **1.0.1 (149)**, closed-train **1.0 (121)**, or rejected **1.0 (113)**.

**1.0 is approved** (train closed). The next binary to upload is **1.0.1 (159)** after Trevor creates or selects that Connect version. TestFlight already had **1.0.1 (149)** (~2026-09-17/18). Archive scheme **Beckify**, not LookCheck or KestrelHeavy. This Linux environment did not compile, sign, or upload 159.
