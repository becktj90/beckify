import SwiftUI
import BeckifyMath

// MARK: - Signal scaling

struct SignalScalingView: View {
    enum Direction: String, CaseIterable, Identifiable {
        case toEngineering = "Raw → EU"
        case toRaw = "EU → raw"
        var id: String { rawValue }
    }

    enum Preset: String, CaseIterable, Identifiable {
        case current = "4–20 mA"
        case voltage = "0–10 V"
        case counts = "0–27648"
        var id: String { rawValue }

        var range: (min: String, max: String, unit: String) {
            switch self {
            case .current: return ("4", "20", "mA")
            case .voltage: return ("0", "10", "V")
            case .counts: return ("0", "27648", "counts")
            }
        }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.signalScaling, "direction", default: Direction.toEngineering) private var direction
    @StoredChoice(.signalScaling, "curve", default: SignalCurve.linear) private var curve
    @StoredToggle(.signalScaling, "liveZero", default: true) private var detectLiveZeroFault
    @StoredInput(.signalScaling, "value", default: "12") private var value
    @StoredInput(.signalScaling, "rawMin", default: "4") private var rawMin
    @StoredInput(.signalScaling, "rawMax", default: "20") private var rawMax
    @StoredInput(.signalScaling, "euMin", default: "0") private var euMin
    @StoredInput(.signalScaling, "euMax", default: "150") private var euMax
    @StoredInput(.signalScaling, "jobName", default: "Signal scaling") private var jobName
    @State private var session = ExplicitCalculationSession<SignalScalingResult>()
    @State private var successTick = 0

    private var fingerprint: String {
        // Live-zero detection only affects toEngineering; keep it out of the
        // toRaw fingerprint so toggling a hidden/irrelevant control cannot
        // mark an unchanged reverse scaling result stale.
        let liveZeroKey = direction == .toEngineering ? "\(detectLiveZeroFault)" : "-"
        return "\(direction.rawValue)|\(curve.rawValue)|\(liveZeroKey)|\(value)|\(rawMin)|\(rawMax)|\(euMin)|\(euMax)"
    }
    private var display: ExplicitCalculationSession<SignalScalingResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .signalScaling,
            stickyAnswer: sticky,
            copyText: sticky,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.visibleError(for: fingerprint),
                    successTick: successTick,
                    onCalculate: calculate,
                    onReset: reset
                )
            }
        ) {
            ShowWorkCard(
                toolID: .signalScaling,
                symbolic: curve == .squareRoot
                    ? "EU = EU_min + √((raw − raw_min)/(raw_max − raw_min)) · span"
                    : "EU = EU_min + (raw − raw_min)/(raw_max − raw_min) · span",
                substituted: substituted,
                meaning: curve == .squareRoot
                    ? "Differential-pressure flow meters put out ΔP, and flow tracks √ΔP — so half the signal span is about 71% of flow, not 50%."
                    : "Straight proportion between the signal span and the engineering span. The live zero is why 4 mA is 0%, not 20%."
            )
            TryExampleButton(title: "12 mA on a 0–150 PSI transmitter") {
                direction = .toEngineering
                curve = .linear
                detectLiveZeroFault = true
                value = "12"
                rawMin = "4"
                rawMax = "20"
                euMin = "0"
                euMax = "150"
            }

            ThumbButtonRow {
                ForEach(Preset.allCases) { preset in
                    Button(preset.rawValue) {
                        rawMin = preset.range.min
                        rawMax = preset.range.max
                        detectLiveZeroFault = preset == .current
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                }
            }

            MenuField(title: "Direction", selection: $direction, options: Direction.allCases) { $0.rawValue }
            MenuField(title: "Curve", selection: $curve, options: SignalCurve.allCases) { $0.displayName }
            NumberField(
                title: direction == .toEngineering ? "Raw signal" : "Engineering value",
                unit: direction == .toEngineering ? "raw" : "EU",
                text: $value
            )
            NumberField(title: "Raw min", unit: "raw", text: $rawMin)
            NumberField(title: "Raw max", unit: "raw", text: $rawMax)
            NumberField(title: "EU min", unit: "EU", text: $euMin)
            NumberField(title: "EU max", unit: "EU", text: $euMax)
            if direction == .toEngineering {
                Toggle("Detect a below-range live-zero fault", isOn: $detectLiveZeroFault)
            }

            switch display {
            case .current(let r), .stale(let r):
                if r.isLiveZeroFault {
                    ToolEmptyState(
                        title: "Below live zero",
                        detail: "The signal is under the bottom of its range. On a 4–20 mA loop that reads as a broken wire or a failed transmitter, not a low process value.",
                        systemImage: "exclamationmark.triangle"
                    )
                }
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Engineering", value: Format.number(r.engineeringValue, digits: 4), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Raw", value: Format.number(r.rawValue, digits: 4), emphasis: true)
                    ResultRow(label: "Percent of span", value: Format.percent(r.percentOfSpan))
                }
                if case .current = display {
                    if let rawLo = rawMin.parsedDouble,
                       let rawHi = rawMax.parsedDouble,
                       let engLo = euMin.parsedDouble,
                       let engHi = euMax.parsedDouble {
                        SignalTransferCurveView(
                            rawMin: rawLo,
                            rawMax: rawHi,
                            euMin: engLo,
                            euMax: engHi,
                            raw: r.rawValue,
                            engineering: r.engineeringValue,
                            squareRoot: curve == .squareRoot
                        )
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) {
                        jobs.save(SavedJob(
                            name: jobName,
                            toolID: .signalScaling,
                            inputs: ["dir": direction.rawValue, "curve": curve.displayName, "in": value, "raw": "\(rawMin)–\(rawMax)", "EU": "\(euMin)–\(euMax)"],
                            outputs: ["EU": Format.number(r.engineeringValue, digits: 4), "raw": Format.number(r.rawValue, digits: 4)]
                        ))
                    }
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter signal and spans",
                    detail: "Set raw/EU ranges and the input value, then Calculate.",
                    systemImage: "waveform.path.ecg"
                )
            case .failed:
                EmptyView()
            }
        }
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            if direction == .toEngineering {
                return try SignalScaling.toEngineering(
                    raw: value.parsedDouble ?? .nan,
                    rawMin: rawMin.parsedDouble ?? .nan,
                    rawMax: rawMax.parsedDouble ?? .nan,
                    engineeringMin: euMin.parsedDouble ?? .nan,
                    engineeringMax: euMax.parsedDouble ?? .nan,
                    curve: curve,
                    detectLiveZeroFault: detectLiveZeroFault
                )
            }
            return try SignalScaling.toRaw(
                engineering: value.parsedDouble ?? .nan,
                rawMin: rawMin.parsedDouble ?? .nan,
                rawMax: rawMax.parsedDouble ?? .nan,
                engineeringMin: euMin.parsedDouble ?? .nan,
                engineeringMax: euMax.parsedDouble ?? .nan,
                curve: curve
            )
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        direction = .toEngineering
        curve = .linear
        detectLiveZeroFault = true
        value = ""
        rawMin = "4"
        rawMax = "20"
        euMin = "0"
        euMax = "150"
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "\(Format.number(r.rawValue, digits: 3)) raw  →  \(Format.number(r.engineeringValue, digits: 3)) EU  (\(Format.number(r.percentOfSpan, digits: 1)) %)"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            // Both sides come from the committed result so a live direction
            // flip cannot relabel a stale sticky answer.
            return "\(Format.number(r.engineeringValue, digits: 3)) EU  ·  \(Format.number(r.rawValue, digits: 3)) raw"
        default:
            return nil
        }
    }
}

// MARK: - Modbus addressing

struct ModbusAddressView: View {
    enum Entry: String, CaseIterable, Identifiable {
        case offset = "PDU offset"
        case display = "Display address"
        var id: String { rawValue }
    }

    @StoredChoice(.modbusAddress, "table", default: ModbusTable.holdingRegister) private var table
    @StoredChoice(.modbusAddress, "entry", default: Entry.offset) private var entry
    @StoredInput(.modbusAddress, "offset", default: "0") private var offset
    @StoredInput(.modbusAddress, "display", default: "40001") private var display

    var body: some View {
        // LIVE tool — dock defaults to EmptyView via ToolScaffold extension.
        ToolScaffold(toolID: .modbusAddress, stickyAnswer: sticky, copyText: sticky) {
            ShowWorkCard(
                toolID: .modbusAddress,
                symbolic: "entity = offset + 1    display = prefix · entity",
                substituted: substituted,
                meaning: "The offset is what actually goes on the wire; 40001 is a display convention layered on top. Off-by-one between them is the classic Modbus bug."
            )
            MenuField(title: "Table", selection: $table, options: ModbusTable.allCases) { $0.displayName }
            MenuField(title: "Enter", selection: $entry, options: Entry.allCases) { $0.rawValue }
            if entry == .offset {
                NumberField(title: "PDU offset", unit: "0-based", text: $offset)
            } else {
                NumberField(title: "Display address", unit: "40001", text: $display)
            }

            switch result {
            case .success(let r):
                ResultCard(copyText: sticky) {
                    ResultRow(label: "PDU offset (wire)", value: "\(r.pduOffset)", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Entity number", value: "\(r.entityNumber)")
                    ResultRow(label: "5-digit", value: r.fiveDigit ?? "—")
                    ResultRow(label: "6-digit", value: r.sixDigit)
                    ResultRow(label: "Read function", value: "FC \(r.readFunctionCode)")
                }
            case .failure(let error):
                ErrorText(message: error.message)
            }
        }
    }

    private var result: Result<ModbusAddressResult, CalcError> {
        CalcCatch.run {
            if entry == .offset {
                let raw = offset.parsedDouble ?? .nan
                guard raw.isFinite, raw >= 0 else { throw CalcError.missing("an offset") }
                guard let offset = Int(exactly: raw) else {
                    throw CalcError.outOfRange("Offset must be a whole number in range.")
                }
                return try ModbusAddress.fromPDUOffset(offset, table: table)
            }
            return try ModbusAddress.fromDisplayAddress(display, table: table)
        }
    }

    private var substituted: String? {
        guard case .success(let r) = result else { return nil }
        let display = r.fiveDigit ?? r.sixDigit
        return "offset \(r.pduOffset) → entity \(r.entityNumber) → \(display)"
    }

    private var sticky: String? {
        guard case .success(let r) = result else { return nil }
        return "offset \(r.pduOffset)  ·  \(r.fiveDigit ?? r.sixDigit)  ·  FC \(r.readFunctionCode)"
    }
}

// MARK: - PLC timer preset

struct PLCTimerView: View {
    enum Base: String, CaseIterable, Identifiable {
        case millisecond = "1 ms"
        case tenMillisecond = "10 ms"
        case hundredMillisecond = "100 ms"
        case second = "1 s"
        var id: String { rawValue }

        var seconds: Double {
            switch self {
            case .millisecond: return 0.001
            case .tenMillisecond: return 0.01
            case .hundredMillisecond: return 0.1
            case .second: return 1
            }
        }
    }

    enum Direction: String, CaseIterable, Identifiable {
        case toPreset = "Time → preset"
        case toTime = "Preset → time"
        var id: String { rawValue }
    }

    @StoredChoice(.plcTimer, "base", default: Base.tenMillisecond) private var base
    @StoredChoice(.plcTimer, "direction", default: Direction.toPreset) private var direction
    @StoredInput(.plcTimer, "seconds", default: "5") private var seconds
    @StoredInput(.plcTimer, "preset", default: "500") private var preset
    @State private var session = ExplicitCalculationSession<TimerPresetResult>()
    @State private var successTick = 0

    private var fingerprint: String {
        "\(base.rawValue)|\(direction.rawValue)|\(seconds)|\(preset)"
    }
    private var display: ExplicitCalculationSession<TimerPresetResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .plcTimer,
            stickyAnswer: sticky,
            copyText: sticky,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.visibleError(for: fingerprint),
                    successTick: successTick,
                    onCalculate: calculate,
                    onReset: reset
                )
            }
        ) {
            ShowWorkCard(
                toolID: .plcTimer,
                symbolic: "preset = round(time / timebase)    actual = preset × timebase",
                substituted: substituted,
                meaning: "The preset is a whole count, so a coarse timebase can only land on multiples of it. The error row is how far off the nearest count actually is."
            )
            MenuField(title: "Timebase", selection: $base, options: Base.allCases) { $0.rawValue }
            MenuField(title: "Direction", selection: $direction, options: Direction.allCases) { $0.rawValue }
            if direction == .toPreset {
                NumberField(title: "Desired time", unit: "s", text: $seconds)
            } else {
                NumberField(title: "Preset", unit: "counts", text: $preset)
            }

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Preset", value: "\(r.preset)", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Actual time", value: Format.time(r.actualSeconds), emphasis: true)
                    ResultRow(
                        label: "Error",
                        value: abs(r.errorSeconds) < 1e-9 ? "exact" : Format.time(abs(r.errorSeconds)),
                        tone: abs(r.errorSeconds) < 1e-9 ? Theme.good : Theme.warn
                    )
                    ResultRow(
                        label: "Timebase",
                        value: Base.allCases.first(where: { abs($0.seconds - r.timebaseSeconds) < 1e-12 })?.rawValue
                            ?? Format.time(r.timebaseSeconds)
                    )
                }
                if case .current = display {
                    TimerTraceView(
                        preset: r.preset,
                        actualSeconds: r.actualSeconds,
                        targetSeconds: r.actualSeconds - r.errorSeconds,
                        timebaseSeconds: r.timebaseSeconds
                    )
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter time or preset",
                    detail: "Pick a timebase and direction, then Calculate.",
                    systemImage: "timer"
                )
            case .failed:
                EmptyView()
            }
        }
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            if direction == .toPreset {
                return try PLCTimer.preset(
                    seconds: seconds.parsedDouble ?? .nan,
                    timebaseSeconds: base.seconds
                )
            }
            let raw = preset.parsedDouble ?? .nan
            guard raw.isFinite, raw >= 0 else { throw CalcError.missing("a preset") }
            guard let preset = Int(exactly: raw) else {
                throw CalcError.outOfRange("Preset must be a whole number in range.")
            }
            return try PLCTimer.seconds(preset: preset, timebaseSeconds: base.seconds)
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        base = .tenMillisecond
        direction = .toPreset
        seconds = ""
        preset = ""
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "\(r.preset) × \(base.rawValue) = \(Format.time(r.actualSeconds))"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "preset \(r.preset)  ·  \(Format.time(r.actualSeconds))"
        default:
            return nil
        }
    }
}
