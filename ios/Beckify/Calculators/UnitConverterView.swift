import SwiftUI
import BeckifyMath

struct UnitConverterView: View {
    enum Category: String, CaseIterable, Identifiable {
        case si = "SI"
        case db = "dB"
        case temp = "Temp"
        case length = "Length"
        var id: String { rawValue }
    }

    enum SIKind: String, CaseIterable, Identifiable {
        case volts = "V"
        case amps = "A"
        case ohms = "Ω"
        case watts = "W"
        var id: String { rawValue }
    }

    enum DBKind: String, CaseIterable, Identifiable {
        case voltage = "20 log (V)"
        case power = "10 log (P)"
        var id: String { rawValue }
    }

    enum TempDir: String, CaseIterable, Identifiable {
        case cToF
        case fToC
        var id: String { rawValue }
        var label: String { self == .cToF ? "°C → °F" : "°F → °C" }
        var unit: String { self == .cToF ? "°C" : "°F" }
    }

    enum LengthDir: String, CaseIterable, Identifiable {
        case ftToM
        case mToFt
        case milToMm
        case mmToMil
        var id: String { rawValue }
        var label: String {
            switch self {
            case .ftToM: return "ft → m"
            case .mToFt: return "m → ft"
            case .milToMm: return "mil → mm"
            case .mmToMil: return "mm → mil"
            }
        }
        var unit: String {
            switch self {
            case .ftToM: return "ft"
            case .mToFt: return "m"
            case .milToMm: return "mil"
            case .mmToMil: return "mm"
            }
        }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.unitConverter, "category", default: Category.si) private var category
    @StoredChoice(.unitConverter, "siKind", default: SIKind.volts) private var siKind
    @StoredChoice(.unitConverter, "fromP", default: SIPrefix.kilo) private var fromP
    @StoredChoice(.unitConverter, "toP", default: SIPrefix.none) private var toP
    @StoredInput(.unitConverter, "value", default: "4.7") private var value
    @StoredChoice(.unitConverter, "dbKind", default: DBKind.voltage) private var dbKind
    @StoredToggle(.unitConverter, "dbModeRatio", default: true) private var dbModeRatio
    @StoredChoice(.unitConverter, "tempDir", default: TempDir.cToF) private var tempDir
    @StoredChoice(.unitConverter, "lengthDir", default: LengthDir.ftToM) private var lengthDir
    @StoredInput(.unitConverter, "jobName", default: "Unit convert") private var jobName
    @State private var live = LiveCalculationState<String>()

    private var inputFingerprint: String {
        "\(category)|\(siKind)|\(fromP)|\(toP)|\(value)|\(dbKind)|\(dbModeRatio)|\(tempDir)|\(lengthDir)"
    }

    var body: some View {
        ToolScaffold(toolID: .unitConverter, stickyAnswer: sticky, copyText: copyText) {
            ShowWorkCard(
                toolID: .unitConverter,
                symbolic: formula,
                substituted: substituted,
                meaning: "Homework conversions. dB uses 20 log10 for voltage/current ratios and 10 log10 for power."
            )
            TryExampleButton(title: exampleTitle) {
                applyExample()
                live.update { try computeResult() }
            }
            Picker("Category", selection: $category) {
                ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()
            categoryFields

            if let error = live.error {
                ErrorText(message: error.message)
            } else if let text = live.result {
                ResultCard(copyText: text) {
                    ResultRow(label: "Result", value: text, emphasis: true, tone: Theme.good)
                }
                SaveJobBar(jobName: $jobName, canSave: true) { save(text) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            live.update { try computeResult() }
        }
        .onAppear {
            live.update { try computeResult() }
        }
    }

    private func computeResult() throws -> String {
        switch category {
        case .si:
            let out = try UnitConvert.si(value: value.parsedDouble ?? .nan, from: fromP, to: toP)
            return "\(Format.number(out, digits: 6)) \(toP.rawValue)\(siKind.rawValue)"
        case .db:
            let x = value.parsedDouble ?? .nan
            if dbModeRatio {
                let db = dbKind == .voltage ? try UnitConvert.voltageDB(ratio: x) : try UnitConvert.powerDB(ratio: x)
                return "\(Format.number(db, digits: 4)) dB"
            }
            let ratio = dbKind == .voltage ? try UnitConvert.voltageRatio(fromDB: x) : try UnitConvert.powerRatio(fromDB: x)
            return "ratio \(Format.number(ratio, digits: 6))"
        case .temp:
            let x = value.parsedDouble ?? .nan
            switch tempDir {
            case .cToF:
                return "\(Format.number(try UnitConvert.fahrenheit(fromCelsius: x), digits: 3)) °F"
            case .fToC:
                return "\(Format.number(try UnitConvert.celsius(fromFahrenheit: x), digits: 3)) °C"
            }
        case .length:
            let x = value.parsedDouble ?? .nan
            switch lengthDir {
            case .ftToM: return "\(Format.number(try UnitConvert.meters(fromFeet: x), digits: 4)) m"
            case .mToFt: return "\(Format.number(try UnitConvert.feet(fromMeters: x), digits: 4)) ft"
            case .milToMm: return "\(Format.number(try UnitConvert.mm(fromMils: x), digits: 4)) mm"
            case .mmToMil: return "\(Format.number(try UnitConvert.mils(fromMM: x), digits: 4)) mil"
            }
        }
    }

    private var formula: String {
        switch category {
        case .si: return "out = in × (from prefix) / (to prefix)"
        case .db: return dbKind == .voltage ? "dB = 20 log₁₀(V₂/V₁)" : "dB = 10 log₁₀(P₂/P₁)"
        case .temp: return "°F = °C × 9/5 + 32"
        case .length: return "1 ft = 0.3048 m    1 mil = 0.0254 mm"
        }
    }

    private var substituted: String? {
        guard let text = live.result else { return nil }
        return "\(value)  →  \(text)"
    }

    private var sticky: String? { live.result }

    private var copyText: String? { sticky }

    private var exampleTitle: String {
        switch category {
        case .si: return "4.7 kV → V"
        case .db: return "Voltage ratio 2 → dB"
        case .temp: return "20 °C → °F"
        case .length: return "10 ft → m"
        }
    }

    private func applyExample() {
        switch category {
        case .si:
            siKind = .volts
            fromP = .kilo
            toP = .none
            value = "4.7"
        case .db:
            dbKind = .voltage
            dbModeRatio = true
            value = "2"
        case .temp:
            tempDir = .cToF
            value = "20"
        case .length:
            lengthDir = .ftToM
            value = "10"
        }
    }

    @ViewBuilder
    private var categoryFields: some View {
        switch category {
        case .si:
            Picker("Quantity", selection: $siKind) {
                ForEach(SIKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()
            NumberField(title: "Value", unit: fromP.rawValue + siKind.rawValue, text: $value, allowsScientific: true)
            MenuField(title: "From", selection: $fromP, options: Array(SIPrefix.allCases)) { $0.label }
            MenuField(title: "To", selection: $toP, options: Array(SIPrefix.allCases)) { $0.label }
        case .db:
            Picker("Kind", selection: $dbKind) {
                ForEach(DBKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()
            Picker("Direction", selection: $dbModeRatio) {
                Text("Ratio → dB").tag(true)
                Text("dB → ratio").tag(false)
            }
            .segmentedControlStyle()
            NumberField(title: dbModeRatio ? "Ratio" : "dB", unit: dbModeRatio ? "—" : "dB", text: $value)
        case .temp:
            Picker("From", selection: $tempDir) {
                ForEach(TempDir.allCases) { Text($0.label).tag($0) }
            }
            .segmentedControlStyle()
            NumberField(title: "Temperature", unit: tempDir.unit, text: $value)
        case .length:
            Picker("From", selection: $lengthDir) {
                ForEach(LengthDir.allCases) { Text($0.label).tag($0) }
            }
            .segmentedControlStyle()
            NumberField(title: "Length", unit: lengthDir.unit, text: $value)
        }
    }

    private func save(_ text: String) {
        var inputs: [String: String] = [
            "cat": category.rawValue,
            "value": value,
        ]
        switch category {
        case .si:
            inputs["quantity"] = siKind.rawValue
            inputs["from"] = fromP.label
            inputs["to"] = toP.label
        case .db:
            inputs["kind"] = dbKind.rawValue
            inputs["direction"] = dbModeRatio ? "ratio→dB" : "dB→ratio"
        case .temp:
            inputs["dir"] = tempDir.label
        case .length:
            inputs["dir"] = lengthDir.label
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .unitConverter,
            inputs: inputs,
            outputs: ["out": text]
        ))
    }
}

/// A `NumberField`-styled text entry that accepts hex letters — `NumberField`
/// pins the keyboard to digits-only, which makes A–F, O, and B unreachable.
private struct BaseValueField: View {
    let title: String
    let unit: String
    let validCharacters: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.TypeRole.fieldLabel)
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline) {
                TextField("0", text: $text)
                    .keyboardType(.asciiCapable)
                    .font(.title3.monospaced().weight(.medium))
                    .foregroundStyle(Theme.foreground)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .formFieldFocus(title)
                    .accessibilityLabel(title)
                    .accessibilityHint(validCharacters + (unit.isEmpty ? "." : ", optionally prefixed \(unit)."))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: Theme.touchTarget)
            .background(Theme.inputFill, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
            )
        }
    }
}

// MARK: - Number base converter

struct NumberBaseView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.numberBase, "base", default: NumberBase.decimal) private var base
    @StoredInput(.numberBase, "value", default: "202") private var value
    @StoredInput(.numberBase, "jobName", default: "Number base") private var jobName
    @State private var live = LiveCalculationState<NumberBaseResult>()

    private var inputFingerprint: String { "\(base)|\(value)" }

    var body: some View {
        ToolScaffold(toolID: .numberBase, stickyAnswer: sticky, copyText: sticky) {
            ShowWorkCard(
                toolID: .numberBase,
                symbolic: "entity(base) → same bits → binary · octal · decimal · hex",
                substituted: substituted,
                meaning: "It's one bit pattern read four ways. The signed rows re-read that same pattern as two's complement at 8, 16, or 32 bits — the width your register or Modbus word actually is."
            )
            TryExampleButton(title: "0xCA — one byte, sign bit set") {
                base = .hexadecimal
                value = "CA"
            }

            MenuField(title: "Enter as", selection: $base, options: NumberBase.allCases) { $0.displayName }
            BaseValueField(title: base.displayName, unit: base.prefix, validCharacters: base.validCharactersDescription, text: $value)

            if let error = live.error {
                ErrorText(message: error.message)
            } else if let r = live.result {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Binary", value: NumberBaseConvert.groupedBinary(r.binary), emphasis: base == .binary, tone: base == .binary ? Theme.good : Theme.foreground)
                    ResultRow(label: "Octal", value: r.octal, emphasis: base == .octal, tone: base == .octal ? Theme.good : Theme.foreground)
                    ResultRow(label: "Decimal", value: r.decimal, emphasis: base == .decimal, tone: base == .decimal ? Theme.good : Theme.foreground)
                    ResultRow(label: "Hex", value: r.hexadecimal, emphasis: base == .hexadecimal, tone: base == .hexadecimal ? Theme.good : Theme.foreground)
                }
                ResultCard(title: "Signed (two's complement)") {
                    ResultRow(label: "8-bit", value: "\(r.signed8)")
                    ResultRow(label: "16-bit", value: "\(r.signed16)")
                    ResultRow(label: "32-bit", value: "\(r.signed32)")
                }
                SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in refresh() }
        .onAppear { refresh() }
    }

    private func refresh() {
        live.update {
            try NumberBaseConvert.parse(value, from: base)
        }
    }

    private var substituted: String? {
        guard let r = live.result else { return nil }
        return "\(NumberBaseConvert.groupedBinary(r.binary))  ·  \(r.decimal)  ·  0x\(r.hexadecimal)"
    }

    private var sticky: String? {
        guard let r = live.result else { return nil }
        return "0x\(r.hexadecimal)  ·  \(r.decimal)  ·  \(NumberBaseConvert.groupedBinary(r.binary))"
    }

    private func save(_ r: NumberBaseResult) {
        let alreadyPrefixed = !base.prefix.isEmpty && value.lowercased().hasPrefix(base.prefix.lowercased())
        let entered = alreadyPrefixed ? value : "\(base.prefix)\(value)"
        jobs.save(SavedJob(
            name: jobName,
            toolID: .numberBase,
            inputs: ["entered": entered],
            outputs: ["bin": r.binary, "dec": r.decimal, "hex": r.hexadecimal]
        ))
    }
}
