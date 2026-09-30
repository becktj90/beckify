import Foundation

/// Short, scannable “how it works” copy for a catalog tool.
///
/// Keep this data-driven and keyed by `ToolID.rawValue` so a new tool cannot
/// ship without an entry (see `ToolHowItWorksTests`). UI stays in ToolUX —
/// do not paste this prose into each calculator view.
public struct ToolHowItWorks: Equatable, Sendable {
    /// One or two sentences: what the tool computes.
    public var summary: String
    /// Brief field or student framing — when to open it.
    public var context: String
    /// Optional assumptions, units, and honesty limits. Keep to a few short lines.
    public var bullets: [String]

    public init(summary: String, context: String, bullets: [String] = []) {
        self.summary = summary
        self.context = context
        self.bullets = bullets
    }
}

/// Sibling to `ToolboxCatalog` / `ToolHomeAreaPolicy`. Keys match `ToolID.rawValue`.
public enum ToolHowItWorksCatalog {
    public static func copy(forToolID id: String) -> ToolHowItWorks? {
        entries[id]
    }

    /// Homework-kind tools default the About disclosure open (same idea as Show Work).
    /// Field calculators and instruments stay collapsed so inputs stay first.
    public static func defaultExpanded(forToolID id: String) -> Bool {
        homeworkIDs.contains(id)
    }

    public static var coveredToolIDs: [String] {
        ToolCalculationPolicy.knownToolIDs.filter { entries[$0] != nil }
    }

    // MARK: - Homework IDs (match `ToolKind.homework` on the iOS catalog)

    private static let homeworkIDs: Set<String> = [
        "voltageDivider", "seriesParallel", "resistorColor", "frequencyWave", "ledRC",
        "phasorDiagram", "fiberLink", "gaussianBeam", "transientCircuit", "diodeIV",
        "analogWorkbench", "noiseSNR", "instrumentationAmp",
    ]

    // MARK: - Copy

    private static let entries: [String: ToolHowItWorks] = [
        "ohmsLaw": ToolHowItWorks(
            summary: "Solves any two of V, I, and R, then reports power from P = V × I.",
            context: "First-stop DC identity — leave the unknown blank.",
            bullets: [
                "Ohm’s law only: a single resistance, not a network.",
                "Power is a follow-on, not a fourth independent unknown.",
            ]
        ),
        "power": ToolHowItWorks(
            summary: "DC identities (P = VI, I²R, V²/R) plus 1Ø / 3Ø kVA, kW, and kVAR.",
            context: "Nameplate or feeder power when you already have volts, amps, and PF.",
            bullets: [
                "3Ø uses √3. Enter PF to split kW and kVAR from kVA.",
                "The identities do not change with code. AS/NZS shows 230 V / 400 V at 50 Hz as the nominal supply.",
                "Design aid — not a billing meter or a demand study.",
            ]
        ),
        "powerWizard": ToolHowItWorks(
            summary: "Asks for the knowns (amps, kW, kVA, or HP) and fills DC, 1Ø, or 3Ø power.",
            context: "Saved-job deep link. New work uses Power on the Field shelf.",
            bullets: [
                "Same identities as Power; kept so old jobs still open.",
                "Not a separate product — results are planning numbers.",
            ]
        ),
        "voltageDrop": ToolHowItWorks(
            summary: "Voltage drop for the code in Settings. NEC is the K-factor path. AS/NZS is a metric resistance path.",
            context: "Feeder or branch check before you pull wire.",
            bullets: [
                "NEC: VD uses K, circular mils, current, and one-way length. 3Ø uses √3. 3% and 5% are informational.",
                "NEC ampacity is a companion check. 1Ø and 3Ø show a Table 250.122 EGC from the next standard OCPD.",
                "AS/NZS: mm² sizes, IEC 60228 maximum R, Clause 3.6.2’s 5% limit, and a Table 5.1 copper earth. Not an AS/NZS 3008 mV/A·m or current-carrying-capacity table.",
                "Design aid — not a PE or AEE stamp, and not a bid length.",
            ]
        ),
        "conduitFill": ToolHowItWorks(
            summary: "Same-size or mixed THHN (and other Table 5) fill against Chapter 9 Table 1 / Table 4.",
            context: "Raceway pick on the truck — EMT, IMC, RMC, PVC, ENT, FMC, LFMC.",
            bullets: [
                "Fill % is area of conductors ÷ raceway area. 40% is the usual >2-wire limit.",
                "3Ø or multiwire can show one Table 250.122 EGC (NEC 2023). Fill counts it only if Count EGC is on. Confirm Code / AHJ.",
                "Transcription of published tables — not a substitute for the NEC book.",
            ]
        ),
        "transformer": ToolHowItWorks(
            summary: "Picks a standard kVA and 450.3(B) primary/secondary OCPD, including Note 1.",
            context: "Dry-type or small power transformer sizing on a job.",
            bullets: [
                "kVA from volts and amps (√3 on 3Ø). Protection follows 450.3(B).",
                "Primary and secondary EGC rows use NEC 2023 Table 250.122 from those OCPDs. Confirm AHJ.",
                "Not a coordination study, inrush calc, or utility-transformer spec.",
            ]
        ),
        "timer555": ToolHowItWorks(
            summary: "Astable period/duty and monostable pulse width from the classic ln(2) / ln(3) identities.",
            context: "Bench 555 homework — not a PLC timer (that is PLC Timer Preset).",
            bullets: [
                "Astable: t_high = ln(2)·(R_A+R_B)·C, t_low = ln(2)·R_B·C.",
                "Ideal NE555 math. Real parts, leakage, and rail sag shift the edge.",
            ]
        ),
        "motorFLA": ToolHowItWorks(
            summary: "Looks up NEC Table 430.248 (1Ø) or 430.250 (3Ø) full-load current from HP and volts.",
            context: "Conductor and OCPD starting point when the nameplate FLA is missing.",
            bullets: [
                "Table current, not the nameplate. Use Motor Nameplate Analyzer when you have the plate.",
                "EGC uses Table 250.122 from the next device ≥ 125% FLA. 430.52 breakers are often larger.",
                "Squirrel-cage / induction tables only — not DC, wound-rotor, or servo.",
            ]
        ),
        "wireAmpacity": ToolHowItWorks(
            summary: "NEC Table 310.16 ampacity with ambient correction, CCC adjustment, termination cap, and continuous load.",
            context: "Pick a copper or aluminum size that still carries the load after derating.",
            bullets: [
                "Smallest size whose derated ampacity ≥ required amps (125% continuous when checked).",
                "1Ø, multiwire, and 3Ø show a Table 250.122 EGC beside the phase size. Confirm Code / AHJ.",
                "Termination temperature caps the column. Design aid — verify the edition you are under.",
            ]
        ),
        "conductorCost": ToolHowItWorks(
            summary: "Ranks compliant sizes and parallel runs using a planning $/kft and optional I²R energy.",
            context: "When two legal sizes both work and you want a cheaper planning pick.",
            bullets: [
                "Uses your $/kft or a default book — not LME, not a distributor quote.",
                "EGC size is NEC 2023 Table 250.122 from the design current. It is not in the $/kft rank.",
                "I²R is optional energy, not a life-cycle study. Design aid only.",
            ]
        ),
        "conductorLength": ToolHowItWorks(
            summary: "Estimates conductor length from a milliohm reading — end-to-end or short-to-parallel — plus metal weight from book lb/kft.",
            context: "Field length or distance-to-short from a Kelvin / milliohm meter; weight is one-way book mass.",
            bullets: [
                "R = ρL/CM with a linear α temperature compensation.",
                "Short-to-parallel: path to the short is length ÷ 2.",
                "Not a TDR, cable locator, or bid length — contact R and stranding shift the number.",
                "Weight is book lb/kft × one-way length. Cu 8.89 g/cm³, Al 2.70. Not a scale reading.",
            ]
        ),
        "voltageDivider": ToolHowItWorks(
            summary: "Vout from Vin, R1, and R2 — or solves the missing resistor.",
            context: "Homework unloaded divider. A load on Vout changes the answer.",
            bullets: [
                "Vout = Vin · R2 / (R1 + R2). Leave one unknown blank.",
                "Ideal DC, no source resistance. Not a potentiometer taper model.",
            ]
        ),
        "seriesParallel": ToolHowItWorks(
            summary: "Equivalent R or C for two or more parts in series or parallel.",
            context: "Lab combo networks before you reach for Ohm’s law.",
            bullets: [
                "Series R adds. Parallel R is the reciprocal sum. C swaps those rules.",
                "Two-terminal equivalents only — not a mesh or nodal solver.",
            ]
        ),
        "resistorColor": ToolHowItWorks(
            summary: "Decodes or encodes 4-band and 5-band resistor color codes, including tolerance.",
            context: "Parts drawer / lab kit — tap bands or type a value.",
            bullets: [
                "4-band: two digits + multiplier + tolerance. 5-band adds a third digit.",
                "Standard E-series colors. Not a capacitor or inductor code.",
            ]
        ),
        "unitConverter": ToolHowItWorks(
            summary: "SI prefixes for V/A/Ω/W, plus dB ratio, °C/°F, m/ft, and mils/mm.",
            context: "Quick unit hop while another tool is open.",
            bullets: [
                "Live — updates as you type a valid number.",
                "dB is a power or voltage ratio, not an absolute sound level.",
            ]
        ),
        "frequencyWave": ToolHowItWorks(
            summary: "Frequency, period, free-space wavelength, and LC resonance f = 1/(2π√(LC)).",
            context: "Homework wave / tank-circuit identities.",
            bullets: [
                "λ = c/f uses c = 3×10⁸ m/s in free space, not in cable.",
                "LC is the ideal lossless tank. Real ESR and stray C move f₀.",
            ]
        ),
        "ledRC": ToolHowItWorks(
            summary: "LED current-limit resistor from supply, Vf, and If, plus τ = RC.",
            context: "Indicator LED or a simple RC time-constant lab.",
            bullets: [
                "R = (Vsupply − Vf) / If, then the nearest E24. τ is a separate RC.",
                "555 astable/monostable timing stays in the 555 tool.",
            ]
        ),
        "wifiStatus": ToolHowItWorks(
            summary: "Online / Captive (local / online), Apple 0…1 strength %/bars when given, and TCP RTT.",
            context: "Field connectivity first. Not a dBm meter or a site survey.",
            bullets: [
                "iOS does not give third-party apps Wi-Fi RSSI or dBm — this tool will not invent dBm.",
                "Online / Captive GETs Apple’s hotspot-detect page. Success means no captive splash — not a speed test.",
                "RTT is TCP connect time, not ICMP ping. A LAN/gateway target may prompt for Local Network.",
                "SSID and strength need location, plus Access Wi-Fi Information on a signed team.",
            ]
        ),
        "cellularStatus": ToolHowItWorks(
            summary: "Online / Captive, radio generation from RAT (2G…5G), optional TCP RTT, and carrier / PLMN chips.",
            context: "Which radio and whether the path is online — not a field-strength meter.",
            bullets: [
                "iOS does not expose RSRP, RSRQ, SINR, RSSI, or dBm to third-party apps. Nothing here is invented.",
                "Gauges are generation (from RAT) and TCP RTT milliseconds — not signal bars.",
                "Online / Captive is the same HTTP hotspot-detect probe as Wi-Fi Path — captive vs online, not RSRP.",
                "CTCarrier is deprecated as of iOS 16 with no public replacement; empty subscriber fields stay blank.",
            ]
        ),
        "bluetoothScan": ToolHowItWorks(
            summary: "CoreBluetooth scan: public ads, RSSI radar, RF activity index, room mix, and device-ID churn.",
            context: "Find a nearby peripheral. Activity, mix, and churn are RF density — not occupancy. Radar is an RSSI estimate; angle is layout, not bearing.",
            bullets: [
                "RSSI is the phone’s BLE reading, uncalibrated. Meter bands and the RF activity index are estimates, not occupancy.",
                "Radar angle is a stable slot from the identifier, not angle-of-arrival. iOS third-party BLE has no public AoA.",
                "Names, SIG company IDs, and services are advertised fields only. No private scan APIs or Continuity payload decoding.",
                "Device count ≠ people. One person can carry many radios; cars, printers, and mesh inflate counts. Apple rotates identifiers.",
            ]
        ),
        "noiseMeter": ToolHowItWorks(
            summary: "Uncalibrated microphone level and an audible-band FFT in dBFS — relative, not SPL.",
            context: "Homework / field note: louder vs quieter, and which band is up, on this phone.",
            bullets: [
                "Not an SLM, not OSHA-legal, not A-weighted dB(A). Bars are relative dBFS, not sound pressure.",
                "Same on-device FFT tap as Acoustic Imager. This screen is the meter plus spectrum, not a sound camera.",
                "Rough harmonic % is leftover mic-FFT energy, not THD and not SPL. Freeze holds the plot. Share saves a PNG, not audio.",
                "Save stores the numeric dBFS snapshot only — never a recording.",
            ]
        ),
        "acousticImager": ToolHowItWorks(
            summary: "Live spectrum and time activity from the microphone using an on-device FFT.",
            context: "Level, spectrum, and recent bands. Not a sound camera or a leak locator.",
            bullets: [
                "AVAudioEngine tap plus Accelerate FFT. Not ultrasonic beamforming or a Fluke-style imager.",
                "Not a calibrated SPL meter, and not a gas-leak certification tool.",
                "One microphone shows level, spectrum, and recent time activity. It cannot place a leak.",
                "Audio stays on device. Save stores numbers, never a recording.",
            ]
        ),
        "bubbleLevel": ToolHowItWorks(
            summary: "Pitch, roll, and plumb from CoreMotion gravity.",
            context: "Conduit, panel, or phone-on-the-rail check — not a machinist level.",
            bullets: [
                "Gravity vector from the IMU. Case sit and calibration offset the bubble.",
                "Homework / field-ish. Not a survey instrument.",
            ]
        ),
        "magnetometer": ToolHowItWorks(
            summary: "Magnetic heading, |B| in µT, and Mag Sweep: |B| minus a captured baseline with peak hold.",
            context: "Rough heading, or a walk to find steel, magnets, or speakers.",
            bullets: [
                "DC field only. Not a survey compass, stud finder, live-wire detector, or 60 Hz EMF meter.",
                "The phone’s own magnets and case dominate |B|. A slow |B| spectrum is field variation only, not a 50/60 Hz meter.",
                "Heading needs location/heading permission when iOS asks.",
            ]
        ),
        "barometer": ToolHowItWorks(
            summary: "CMAltimeter pressure and relative altitude from the current reference.",
            context: "Relative height change on a floor or a shaft — not surveyed elevation.",
            bullets: [
                "Relative to where you started the tool, not NAVD88 / MSL.",
                "Weather and HVAC pressure shifts the number. Not a PE stamp.",
            ]
        ),
        "motionSnapshot": ToolHowItWorks(
            summary: "Device-motion gravity and user acceleration as a g-force snapshot.",
            context: "Quick IMU read. Not a vibration analyzer or a ride logger.",
            bullets: [
                "CoreMotion user acceleration, not a calibrated accelerometer chain.",
                "A snapshot, not a spectrum. Coupled Vibration is the separate relative A/B tool.",
            ]
        ),
        "stillnessWatch": ToolHowItWorks(
            summary: "While the phone sits still, marks which of |B|, pressure, a mic impulse, or BLE advertisers crossed a session baseline.",
            context: "A stillness log for a room or a machine bay. Not a ghost detector or a presence meter.",
            bullets: [
                "Not a ghost detector, presence meter, EMF meter, Trifield, live-wire finder, or RF/5G meter. DC field only.",
                "Mic marks are impulses above this session’s noise floor, plus a small relative spectrum. Not recorded.",
                "BLE marks mean advertiser IDs or RSSI changed. Not occupancy and not people.",
                "If user acceleration crosses the bump gate, the row is “phone moved” and is not an anomaly.",
            ]
        ),
        "breathFlute": ToolHowItWorks(
            summary: "A play tool: blowing into the mic gates a local tone. Finger height or a fret sets the pitch.",
            context: "A toy on the Instruments shelf. Not a meter, tuner, or recorder.",
            bullets: [
                "RMS or peak above this phone’s noise floor opens the gate. Quiet air stays silent.",
                "The tone is generated on device. Audio is not recorded and is not uploaded.",
                "Same microphone permission as Noise Meter. Not an SLM and not a pitch reference.",
            ]
        ),
        "coupledVibration": ToolHowItWorks(
            summary: "User-acceleration RMS and a short spectrum while the phone is pressed to a machine or duct, with session A/B compare.",
            context: "A relative signature of this phone on a surface. Not a vibration analyzer.",
            bullets: [
                "Not ISO 10816 and not a calibrated pickup. Units are this phone’s user acceleration.",
                "Distinct from g-Force Snapshot, which is one gravity and user-g reading without a spectrum.",
                "Bandwidth stops at the delivered Nyquist (fs/2), not a claimed 0–400 Hz band.",
                "Frequency × 60 is a relative RPM label for this phone mount, not a tachometer.",
            ]
        ),
        "fieldPosition": ToolHowItWorks(
            summary: "GPS coordinates, speed, and altitude, plus a homework haversine distance.",
            context: "Pin a location when you open the tool — location is not requested at launch.",
            bullets: [
                "Accuracy is the phone GNSS. Indoor fixes are often several meters off.",
                "Haversine is great-circle homework, not a legal property line.",
            ]
        ),
        "deviceHealth": ToolHowItWorks(
            summary: "Charge, Low Power Mode, thermal throttle band, free storage, model / iOS, and uptime from public APIs.",
            context: "Why the phone is slow, hot, or almost full — not a charger tester or pack health %.",
            bullets: [
                "Not Apple Battery Health (Maximum Capacity). Third-party apps cannot read that.",
                "utsname.machine is Apple’s internal code — iPhone18,1 is iPhone 17 Pro, not “iPhone 18”. Unmapped ids stay raw.",
                "Thermal is Apple’s throttle band, not a thermometer. Storage is FileManager volume capacity.",
                "Simulator often reports batteryLevel −1. Unavailable rows stay blank rather than inventing a value.",
            ]
        ),
        "receptacleSelector": ToolHowItWorks(
            summary: "Best-fit NEMA, IEC 60309, household, or Meltric face from volts, amps, poles, and phase — schematic pinout and cited PNs.",
            context: "Which receptacle family matches the circuit, before you order.",
            bullets: [
                "Amp presets through 400 A. Public Meltric/Hubbell PNs only when a catalog page is cited.",
                "Household faces are schematic. AS/NZS ranks Type I (3112) first near 230 V. The catalog is not copied per code.",
                "EGC row is NEC 2023 Table 250.122 from the amp rating you entered. Confirm the breaker.",
                "Not a UL listing, distributor cross, or classified-area stamp. Confirm current catalog.",
            ]
        ),
        "reactance": ToolHowItWorks(
            summary: "X_L, X_C, series Z and angle, or LC resonance with Q and bandwidth.",
            context: "AC homework / filter ballpark from R, L, C, and f.",
            bullets: [
                "X_L = 2πfL, X_C = 1/(2πfC). Resonance f₀ = 1/(2π√(LC)).",
                "Ideal lumped parts. Not a measured impedance or a Smith chart.",
            ]
        ),
        "powerFactor": ToolHowItWorks(
            summary: "Capacitor kVAR (and bank µF) to move from a measured PF to a target PF.",
            context: "Utility PF penalty / correction sizing from kW and the two PFs.",
            bullets: [
                "Qc = P (tan θ1 − tan θ2). Capacitance from kVAR and volts.",
                "Balanced 3Ø assumption. Not a harmonic filter or a switching study.",
            ]
        ),
        "shortCircuit": ToolHowItWorks(
            summary: "Infinite-bus secondary fault current from transformer kVA, volts, and %Z.",
            context: "First-pass AIC / available fault at the secondary terminals.",
            bullets: [
                "Isc = FLA × 100 / %Z. A real study adds source and conductor impedance.",
                "That extra impedance lowers this number. Not a stamped short-circuit study.",
            ]
        ),
        "circularMils": ToolHowItWorks(
            summary: "Round-conductor area: diameter ↔ circular mils ↔ square inches.",
            context: "Quick CM / kcmil conversion for VD or custom wire.",
            bullets: [
                "CM = d_mils². Live — updates as you type.",
                "Round solid geometry. Not a stranded / compact / sector correction.",
            ]
        ),
        "loadFactors": ToolHowItWorks(
            summary: "Demand, load, diversity, and capacity utilisation from metered kW and peaks.",
            context: "Talk through a utility bill or a feeder load study with the definitions in front of you.",
            bullets: [
                "Ratios only — you enter the metered numbers.",
                "Not NEC Article 220 demand (that is Load Calculation Worksheet).",
            ]
        ),
        "signalScaling": ToolHowItWorks(
            summary: "Maps 4–20 mA (or the reverse) to engineering units. Linear, or √ for DP flow.",
            context: "Transmitter / PLC scale when you know LRV, URV, and the live mA.",
            bullets: [
                "Live zero: 4 mA is LRV, 20 mA is URV. √ mode is for DP flow.",
                "Not an ADC code tool (that is ADC / DAC) and not a 0–10 V scaler.",
            ]
        ),
        "modbusAddress": ToolHowItWorks(
            summary: "PDU offset, entity number, 40001 / 400001 forms, and the usual function code.",
            context: "When a vendor sheet, a PLC tag, and a tester disagree on “register 40001”.",
            bullets: [
                "Live conversion between the common address writings.",
                "Does not poll a device. Function code is the typical one for that table.",
            ]
        ),
        "plcTimer": ToolHowItWorks(
            summary: "TON/TOF preset counts at a timebase, with the quantisation error of that tick.",
            context: "Ladder timer math — not a 555 (that is the 555 tool).",
            bullets: [
                "Preset = ceil(desired / timebase). Error is up to one tick.",
                "Does not model scan time or a specific PLC brand’s accumulator.",
            ]
        ),
        "panelDirectory": ToolHowItWorks(
            summary: "Take a picture of a panel schedule. On-device Vision fills an editable table and shows a scan-quality score. Optional Analyze, then confirm demand.",
            context: "Directory photo or typed legend — verify rows. A low score means retake. Analyze uploads only if you tap it.",
            bullets: [
                "On-device flatten, contrast, and two Vision passes when the first read is weak. Analyze POSTs to /api/analyze-panel only if you tap it.",
                "Odd/even circuit numbers can be inferred when the print is missing. Yellow rows are guesses — confirm them.",
                "Trip is not measured load. FLA and kAIC reads are not measured. Demand uses the same 220.42 worksheet as Load Calculation Worksheet.",
            ]
        ),
        "motorSpeed": ToolHowItWorks(
            summary: "Synchronous RPM, slip from a nameplate RPM, and shaft torque from HP (5252 rule).",
            context: "Nameplate poles / RPM / HP — the curve is a teaching sketch.",
            bullets: [
                "n_s = 120 f / poles. Torque (lb·ft) ≈ 5252 × HP / RPM.",
                "Not a torque-speed lab measurement or a VFD model.",
            ]
        ),
        "rfLink": ToolHowItWorks(
            summary: "dBm ↔ watts, VSWR / return loss, and free-space path loss versus distance.",
            context: "Radio homework / a first-pass link budget — not a site survey.",
            bullets: [
                "FSPL is the Friis free-space model. Terrain, antennas, and fade are on you.",
                "Not a substitute for the Wi-Fi or Cellular path instruments.",
            ]
        ),
        "phasorDiagram": ToolHowItWorks(
            summary: "Plots 2–3 phasors and their sum. The balanced 3-phase set is one tap away.",
            context: "Homework vector addition — polar in, resultant out.",
            bullets: [
                "Ideal phasors at one frequency. Not a measured oscilloscope capture.",
                "Balanced 3Ø is 120° apart at equal magnitude.",
            ]
        ),
        "numberBase": ToolHowItWorks(
            summary: "Binary, octal, decimal, hex — plus an 8/16/32-bit signed read of the same bits.",
            context: "Register / Modbus / homework bit patterns. Live as you type.",
            bullets: [
                "Signed view is two’s complement of the width you pick.",
                "Not a floating-point decoder or a PLC data-type catalog.",
            ]
        ),
        "batteryBank": ToolHowItWorks(
            summary: "Series/parallel cells to bank voltage, amp-hours, and runtime at a load, with optional DoD.",
            context: "Stationary / inverter bank planning. E-bike packs have their own designer.",
            bullets: [
                "Runtime uses usable Ah (DoD) and optional inverter efficiency.",
                "Not a BMS design, Peukert lab, or thermal model.",
            ]
        ),
        "referenceLibrary": ToolHowItWorks(
            summary: "On-device tables: NEMA, IP, conductor colors, hazardous areas, insulation, torque, conduit, standard sizes.",
            context: "Look up a rating or a color — not a calculator.",
            bullets: [
                "Transcriptions for field notes. Confirm the edition you are under.",
                "Not a PE stamp and not the NEC book.",
            ]
        ),
        "magneticCircuit": ToolHowItWorks(
            summary: "Reluctance, flux, and flux density from mmf, path length, area, and µr.",
            context: "Homework magnetic Ohm’s law for a simple core.",
            bullets: [
                "ℜ = ℓ / (µr µ0 A), Φ = ℱ / ℜ, B = Φ / A.",
                "Linear µr, no leakage or saturation curve.",
            ]
        ),
        "fiberLink": ToolHowItWorks(
            summary: "Numerical aperture and acceptance angle from core/cladding index, plus V-number.",
            context: "Photonics homework — will this fiber be single-mode at this λ?",
            bullets: [
                "NA = √(n_core² − n_clad²). V = 2π a NA / λ.",
                "Step-index ideal. Not an OTDR or a link-loss budget.",
            ]
        ),
        "gaussianBeam": ToolHowItWorks(
            summary: "Rayleigh range, divergence, and beam radius at a distance from a waist.",
            context: "Laser / photonics homework from w₀ and λ.",
            bullets: [
                "z_R = π w₀² / λ. w(z) = w₀ √(1 + (z/z_R)²).",
                "Fundamental Gaussian, free space. Not a measured M².",
            ]
        ),
        "transientCircuit": ToolHowItWorks(
            summary: "RC or RL charge/discharge — value at a time, percent complete, and the curve.",
            context: "Homework step response. τ = RC or L/R.",
            bullets: [
                "First-order only. v(t) or i(t) from the classic exponential.",
                "Not RLC ringing and not a SPICE transient.",
            ]
        ),
        "rackCurrent": ToolHowItWorks(
            summary: "Sums device currents against a DC bus rating for headroom and percent utilization.",
            context: "24 V / 5 V rack or e-bus current budget.",
            bullets: [
                "Arithmetic sum vs the rating you enter. No diversity, no inrush.",
                "Planning headroom — not a thermal or fuse coordination study.",
            ]
        ),
        "diodeIV": ToolHowItWorks(
            summary: "Shockley diode forward current and an I–V curve from Is, n, and Vt.",
            context: "Semiconductor homework — the exponential, not a curve tracer.",
            bullets: [
                "I = Is (e^{V/(n Vt)} − 1). Series R and self-heating are omitted.",
                "Not a datasheet SPICE model.",
            ]
        ),
        "isLoopVerifier": ToolHowItWorks(
            summary: "Entity Concept check: barrier Voc/Isc/Ca/La against the field device and cable.",
            context: "IS loop paperwork — the four inequalities, not the control drawing.",
            bullets: [
                "Pass means the four Entity inequalities hold with the numbers you typed.",
                "Not a substitute for the system control drawing or a qualified-person sign-off.",
            ]
        ),
        "tapChanger": ToolHowItWorks(
            summary: "DETC tap recommendation from measured secondary voltage and the tap table.",
            context: "Field tap check when the bus is high or low and the DETC is off-load.",
            bullets: [
                "Picks the tap that lands the secondary closest to the target.",
                "Not an OLTC controller, not a utility LTC study.",
            ]
        ),
        "harmonicsTHD": ToolHowItWorks(
            summary: "Current THD, dominant order, and IEEE 519 discussion bands from harmonic amps.",
            context: "Talk through a PQ snapshot — informational bands, not a compliance stamp.",
            bullets: [
                "THD-I from the harmonic series you enter. 519 bands are discussion only.",
                "Not a power-quality meter and not a filter design.",
            ]
        ),
        "upsSizing": ToolHowItWorks(
            summary: "UPS kVA, runtime, and battery Ah from a critical / IT load.",
            context: "On-site power first pass — autonomy at a stated load.",
            bullets: [
                "kVA from kW and PF. Ah from runtime, volts, and efficiency.",
                "Not a vendor sizer, generator study, or battery-room design.",
            ]
        ),
        "motorNameplate": ToolHowItWorks(
            summary: "Overload (430.32), Table 430.52 SCPD, 430.22 conductor, and code-letter LRA from the plate.",
            context: "You have HP, FLA, SF, and code letter — this walks the usual 430 picks.",
            bullets: [
                "MOCP and LRA are never treated as FLA.",
                "EGC uses NEC 2023 Table 250.122 from the Table 430.52 device, not from FLA.",
                "Table picks are a design aid. Confirm the edition and the controller type.",
            ]
        ),
        "motorNameplateOCR": ToolHowItWorks(
            summary: "Take a picture of a plate; on-device Vision fills a shared schema. Optional Analyze, then you confirm.",
            context: "Seed FLA / Analyzer / Speed after you review. Analyze uploads only if you tap it.",
            bullets: [
                "Heuristic extract first. Confirm marks reviewed. Analyze POSTs to /api/analyze-nameplate.",
                "MOCP and LRA are never used as FLA. Recognition can misread a stamped plate.",
            ]
        ),
        "lookCheck": ToolHowItWorks(
            summary: "Camera or library photo, then Analyze Look for a playful look verdict, lighting metrics, and a roast.",
            context: "Entertainment only. The photo stays on this device until you tap Analyze Look.",
            bullets: [
                "Not medical or dating advice. Anyone who appears under 18 is not rated and gets no roast.",
                "Analyze Look POSTs the same /api/analyze-look JSON as the website. Taking or choosing a photo does not upload it.",
            ]
        ),
        "heaterDesign": ToolHowItWorks(
            summary: "Resistive heater line current, leg resistance, and resistance-wire length.",
            context: "Nichrome / Kanthal element planning for wye or delta.",
            bullets: [
                "I and R from watts and volts. Length from resistivity and gauge.",
                "Not a thermal FEM or a listing. Verify the alloy datasheet.",
            ]
        ),
        "empEmc": ToolHowItWorks(
            summary: "Skin depth, sheet shielding effectiveness, Faraday-loop voltage, and aperture leakage.",
            context: "Protection-side EMC homework — not pulse-source or weapon design.",
            bullets: [
                "Textbook skin depth and SE / aperture estimates.",
                "Educational. Not a TEMPEST, MIL-STD, or enclosure qualification.",
            ]
        ),
        "necCircuit": ToolHowItWorks(
            summary: "One pass: design current, derated conductor, voltage drop, and OCPD.",
            context: "Branch or feeder when you want ampacity, VD, and breaker together.",
            bullets: [
                "Chains the same identities as the standalone ampacity and VD tools.",
                "Feeder EGC is NEC 2023 Table 250.122 from the OCPD. A service GEC is Table 250.66.",
                "Design aid — not a panel schedule or a stamped calc package.",
            ]
        ),
        "loadWorksheet": ToolHowItWorks(
            summary: "NEC 220.42 lighting demand plus motor and continuous VA totals.",
            context: "Service / feeder worksheet from lighting VA and added loads.",
            bullets: [
                "Lighting demand follows 220.42. Other rows are the VA you enter.",
                "Not a full dwelling 220.82 optional calc or a utility service study.",
            ]
        ),
        "cableSchedule": ToolHowItWorks(
            summary: "Sequential cable IDs from a type catalog, with CSV copy.",
            context: "From–to list for a tray or a pull — IDs, not ampacity.",
            bullets: [
                "You pick the type and count; the tool stamps IDs.",
                "Not a routing, tray-fill, or voltage-drop schedule.",
            ]
        ),
        "solenoidDesign": ToolHowItWorks(
            summary: "Winding pack, center B, inductance, copper loss, axial field, and plunger force.",
            context: "Air-core / simple plunger coil first pass.",
            bullets: [
                "Ampere-turns and textbook B / force estimates. Plots are teaching sketches.",
                "Not a saturated FEM or a valve-vendor sizer.",
            ]
        ),
        "solarDesign": ToolHowItWorks(
            summary: "PV from rooftop to utility: array size, phone-sensor aim, optional storage.",
            context: "Planning a roof or a small ground mount. IMU/compass are the phone’s.",
            bullets: [
                "Energy from watts, peak sun hours, and derates you enter.",
                "Not a shade study, PE stamp, or interconnection model.",
            ]
        ),
        "analogWorkbench": ToolHowItWorks(
            summary: "Ideal op-amp golden-rule stages and RC / Sallen–Key filters with a magnitude Bode sketch.",
            context: "AoE-style homework — inverting, follower, integrator, and the usual 2nd-order set.",
            bullets: [
                "Ideal op-amp (infinite gain, no offset). Filters use textbook magnitude.",
                "Not a SPICE run, not layout parasitics, not a measured Bode.",
            ]
        ),
        "noiseSNR": ToolHowItWorks(
            summary: "Johnson and optional shot noise, amp e_n / i_n, total referred noise, SNR, and a rough NF.",
            context: "Spot / brick-wall input-referred estimate for a homework front end.",
            bullets: [
                "√(4kTRB) plus the terms you enable. Bandwidth is a hard brick wall.",
                "Not a SPICE .noise run and not a measured spectrum.",
            ]
        ),
        "linearRegulator": ToolHowItWorks(
            summary: "LM317-style Vout from R1/R2, dropout, Pd, and a θJA junction-temperature estimate.",
            context: "Linear / LDO thermal ballpark — not a switch-mode converter.",
            bullets: [
                "Vout ≈ 1.25 (1 + R2/R1) + Iadj·R2. Tj from Pd and θJA (or θJC+θSA).",
                "Tj is not a measured case temperature.",
            ]
        ),
        "instrumentationAmp": ToolHowItWorks(
            summary: "3-op-amp InAmp gain from Rg, or a 4-resistor difference amp, plus swing vs rails.",
            context: "Bridge / thermocouple front-end homework.",
            bullets: [
                "Classic G = 1 + 2R/Rg. Difference amp is the 4-resistor ratio.",
                "Ideal resistors and user-entered rails. Not a measured CMRR.",
            ]
        ),
        "adcDac": ToolHowItWorks(
            summary: "LSB, code count, ideal quantization SNR, Nyquist, and optional DAC code → voltage.",
            context: "Converter homework. 4–20 mA scaling stays in Signal Scaling.",
            bullets: [
                "LSB = FS / 2ⁿ. Ideal SNR ≈ 6.02 n + 1.76 dB. Nyquist is fs/2.",
                "Not ENOB, INL, or an anti-alias filter design.",
            ]
        ),
        "eBikeTorqueRPM": ToolHowItWorks(
            summary: "Shaft torque or RPM from mechanical power — W, kW, or hp.",
            context: "Hub or mid-drive ballpark from a power number.",
            bullets: [
                "P = τ ω. Same identity as Motor Speed; units are the e-bike ones.",
                "Not a dyno and not a controller current limit.",
            ]
        ),
        "eBikeSprocket": ToolHowItWorks(
            summary: "Drive/driven teeth → ratio, output RPM/torque, optional wheel speed — or invert a target.",
            context: "Chain or belt ratio before you order sprockets.",
            bullets: [
                "Ratio = driven / drive. Wheel speed needs a tire diameter.",
                "Ideal mesh. Not belt slip, not a cassette CAD.",
            ]
        ),
        "eBikeRange": ToolHowItWorks(
            summary: "Pack V × Ah and Wh/mi → miles, kilometers, runtime, and implied speed.",
            context: "Envelope range from a consumption number — not GPS.",
            bullets: [
                "No DoD or Peukert. Real range moves with mass, grade, wind, and assist.",
                "Use Battery Bank Sizing when you need usable DoD and inverter efficiency.",
            ]
        ),
        "eBikePackDesigner": ToolHowItWorks(
            summary: "Series/parallel pack planning from cell ratings or a voltage/current target.",
            context: "18650 / 21700 layout sketch. Battery Bank Sizing stays the runtime/DoD tool.",
            bullets: [
                "S × Vcell and P × Icell. Planning only — not a BMS or weld certification.",
                "Verify datasheet, fusing, nickel strip, and enclosure before you build.",
            ]
        ),
        "nickelStrip": ToolHowItWorks(
            summary: "Strip cross-section → planning continuous and short-pulse current.",
            context: "Pack bus / spot-weld strip first pass.",
            bullets: [
                "I ≈ J × width × thickness. Derate for plated steel, path, welds, and rise.",
                "Not a weld cert or a substitute for the cell/BMS datasheet.",
            ]
        ),
        "controlSystems": ToolHowItWorks(
            summary: "Pocket servo lab: plant library or G(s), PID overlays, Bode margins, and a lead compensator.",
            context: "Field → Controls teaching lab. Simulate Open / P / PI / PID on one chart.",
            bullets: [
                "Ziegler–Nichols from Ku/Pu or an FOPDT fit. Bode is a log sweep.",
                "Educational RK4 / Durand–Kerner approximations — not safety-critical commissioning.",
                "Bang-bang, MPC, ADRC, sliding mode, and learned methods are Control Strategies. This lab stays PID, Bode, and lead. State-space LQR / Kalman design stays on the website.",
            ]
        ),
        "controlStrategies": ToolHowItWorks(
            summary: "Compares bang-bang, PID, MPC, fuzzy, sliding mode, ADRC, and learned methods, then suggests one from your constraints.",
            context: "Field → Controls, next to the Control Systems lab. Open the lab when the pick is PID.",
            bullets: [
                "Matrix, plant examples, and plots are teaching sketches — not a commissioned loop.",
                "No cloud training. DRL, PINN, and ML-MPC stay explanatory.",
                "Does not replace Signal Scaling, PLC Timer, or the PID / Bode lab.",
            ]
        ),
    ]
}
