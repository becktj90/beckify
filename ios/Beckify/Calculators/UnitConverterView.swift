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
    @State private var category: Category = .si
    @State private var siKind: SIKind = .volts
    @State private var fromP: SIPrefix = .kilo
    @State private var toP: SIPrefix = .none
    @State private var value = "4.7"
    @State private var dbKind: DBKind = .voltage
    @State private var dbModeRatio = true
    @State private var tempDir: TempDir = .cToF
    @State private var lengthDir: LengthDir = .ftToM
    @State private var jobName = "Unit convert"

    var resultText: Result<String, CalcError> {
        do {
            switch category {
            case .si:
                let out = try UnitConvert.si(value: value.parsedDouble ?? .nan, from: fromP, to: toP)
                return .success("\(Format.number(out, digits: 6)) \(toP.rawValue)\(siKind.rawValue)")
            case .db:
                let x = value.parsedDouble ?? .nan
                if dbModeRatio {
                    let db = dbKind == .voltage ? try UnitConvert.voltageDB(ratio: x) : try UnitConvert.powerDB(ratio: x)
                    return .success("\(Format.number(db, digits: 4)) dB")
                }
                let ratio = dbKind == .voltage ? try UnitConvert.voltageRatio(fromDB: x) : try UnitConvert.powerRatio(fromDB: x)
                return .success("ratio \(Format.number(ratio, digits: 6))")
            case .temp:
                let x = value.parsedDouble ?? .nan
                switch tempDir {
                case .cToF:
                    return .success("\(Format.number(try UnitConvert.fahrenheit(fromCelsius: x), digits: 3)) °F")
                case .fToC:
                    return .success("\(Format.number(try UnitConvert.celsius(fromFahrenheit: x), digits: 3)) °C")
                }
            case .length:
                let x = value.parsedDouble ?? .nan
                switch lengthDir {
                case .ftToM: return .success("\(Format.number(try UnitConvert.meters(fromFeet: x), digits: 4)) m")
                case .mToFt: return .success("\(Format.number(try UnitConvert.feet(fromMeters: x), digits: 4)) ft")
                case .milToMm: return .success("\(Format.number(try UnitConvert.mm(fromMils: x), digits: 4)) mm")
                case .mmToMil: return .success("\(Format.number(try UnitConvert.mils(fromMM: x), digits: 4)) mil")
                }
            }
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("value"))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(text: formula, citation: "Homework conversions. dB uses 20 log10 for voltage/current ratios and 10 log10 for power.")
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                categoryFields
                switch resultText {
                case .success(let text):
                    ResultCard {
                        ResultRow(label: "Result", value: text, emphasis: true, tone: Theme.good)
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { save(text) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Unit Converter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formula: String {
        switch category {
        case .si: return "out = in × (from prefix) / (to prefix)"
        case .db: return dbKind == .voltage ? "dB = 20 log₁₀(V₂/V₁)" : "dB = 10 log₁₀(P₂/P₁)"
        case .temp: return "°F = °C × 9/5 + 32"
        case .length: return "1 ft = 0.3048 m    1 mil = 0.0254 mm"
        }
    }

    @ViewBuilder
    private var categoryFields: some View {
        switch category {
        case .si:
            Picker("Quantity", selection: $siKind) {
                ForEach(SIKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            NumberField(title: "Value", unit: fromP.rawValue + siKind.rawValue, text: $value, allowsScientific: true)
            prefixPicker("From", selection: $fromP)
            prefixPicker("To", selection: $toP)
        case .db:
            Picker("Kind", selection: $dbKind) {
                ForEach(DBKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Direction", selection: $dbModeRatio) {
                Text("Ratio → dB").tag(true)
                Text("dB → ratio").tag(false)
            }
            .pickerStyle(.segmented)
            NumberField(title: dbModeRatio ? "Ratio" : "dB", unit: dbModeRatio ? "—" : "dB", text: $value)
        case .temp:
            Picker("From", selection: $tempDir) {
                ForEach(TempDir.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            NumberField(title: "Temperature", unit: tempDir.unit, text: $value)
        case .length:
            Picker("From", selection: $lengthDir) {
                ForEach(LengthDir.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            NumberField(title: "Length", unit: lengthDir.unit, text: $value)
        }
    }

    private func prefixPicker(_ title: String, selection: Binding<SIPrefix>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Picker(title, selection: selection) {
                ForEach(SIPrefix.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
