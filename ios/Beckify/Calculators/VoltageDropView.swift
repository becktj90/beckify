import SwiftUI
import BeckifyMath

struct VoltageDropView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.voltageDrop, "system", default: ElectricalSystem.threePhase) private var system
    @StoredInput(.voltageDrop, "voltage", default: "480") private var voltage
    @StoredInput(.voltageDrop, "current", default: "45") private var current
    @StoredInput(.voltageDrop, "length", default: "250") private var length
    @StoredChoice(.voltageDrop, "material", default: ConductorMaterial.copper) private var material
    @StoredInput(.voltageDrop, "size", default: "4") private var size
    @StoredInput(.voltageDrop, "jobName", default: "Voltage drop") private var jobName
    @State private var session = ExplicitCalculationSession<VoltageDropResult>()
    @State private var successTick = 0

    private var sizes: [String] {
        NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil }
    }

    private var fingerprint: String {
        "\(system.rawValue)|\(voltage)|\(current)|\(length)|\(material.rawValue)|\(size)"
    }
    private var display: ExplicitCalculationSession<VoltageDropResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .voltageDrop,
            stickyAnswer: sticky,
            copyText: copyText,
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
                toolID: .voltageDrop,
                symbolic: "VD = (M × K × I × L) / CM",
                substituted: substituted,
                meaning: "M is 2 for 1Ø/DC or √3 for 3Ø. K is 12.9 Cu / 21.2 Al at 75 °C. 3% and 5% are informational notes, not hard NEC limits.",
                citation: "NEC Chapter 9 Table 9 K-factor. Ampacity cross-check uses Table 310.16, 75 °C.",
                referenceTool: .wireAmpacity
            )
            TryExampleButton(title: "480 V 3Ø, 45 A, 250 ft, 4 Cu") {
                system = .threePhase
                voltage = "480"
                current = "45"
                length = "250"
                material = .copper
                size = "4"
            }
            Picker("System", selection: $system) {
                ForEach(ElectricalSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Material", selection: $material) {
                ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            NumberField(title: "Supply voltage", unit: "V", text: $voltage)
            NumberField(title: "Load current", unit: "A", text: $current)
            NumberField(title: "One-way length", unit: "ft", text: $length)
            MenuField(title: "Conductor", selection: $size, options: sizes, label: NECTables.wireLabel)

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Voltage drop", value: Format.volts(r.dropVolts), emphasis: true)
                    ResultRow(label: "Drop", value: Format.percent(r.dropPercent), emphasis: true)
                    ResultRow(label: "Receiving end", value: Format.volts(r.receivingVolts))
                    ResultRow(
                        label: "≤ 3% informational",
                        value: r.meets3Percent ? "PASS" : "OVER 3%",
                        tone: r.meets3Percent ? Theme.good : Theme.warn
                    )
                    ResultRow(
                        label: "≤ 5% informational",
                        value: r.meets5Percent ? "PASS" : "OVER 5%",
                        tone: r.meets5Percent ? Theme.good : Theme.bad
                    )
                    if let amp = r.ampacity75C {
                        ResultRow(
                            label: "310.16 75 °C",
                            value: "\(amp) A" + (r.ampacityOK == true ? "  meets load" : "  undersized"),
                            tone: r.ampacityOK == true ? Theme.good : Theme.bad
                        )
                    }
                }
                if case .current = display {
                    VoltageDropRunView(
                        sourceVolts: r.receivingVolts + r.dropVolts,
                        loadVolts: r.receivingVolts
                    )
                    SaveJobBar(jobName: $jobName, canSave: true) {
                        jobs.save(SavedJob(
                            name: jobName,
                            toolID: .voltageDrop,
                            inputs: ["sys": system.displayName, "V": voltage, "I": current, "L": length, "size": size, "material": material.displayName],
                            outputs: ["VD": Format.volts(r.dropVolts), "%": Format.percent(r.dropPercent)]
                        ))
                    }
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter run and conductor",
                    detail: "Set voltage, current, length, and size, then Calculate.",
                    systemImage: "arrow.left.arrow.right"
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
            try VoltageDrop.calculate(
                system: system,
                current: current.parsedDouble ?? .nan,
                oneWayFeet: length.parsedDouble ?? .nan,
                supplyVolts: voltage.parsedDouble ?? .nan,
                size: size,
                material: material
            )
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        system = .threePhase
        voltage = "480"
        current = "45"
        length = "250"
        material = .copper
        size = "4"
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        let m = system == .threePhase ? "√3" : "2"
        let k = Format.number(material.resistivityK, digits: 1)
        let i = Format.number(current.parsedDouble ?? .nan, digits: 2)
        let l = Format.number(length.parsedDouble ?? .nan, digits: 1)
        let cm = NECTables.circularMils[size].map { Format.number($0, digits: 0) } ?? size
        return "VD = (\(m) × \(k) × \(i) × \(l)) / \(cm) = \(Format.volts(r.dropVolts))  (\(Format.percent(r.dropPercent)))"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "\(Format.volts(r.dropVolts))  ·  \(Format.percent(r.dropPercent))"
        default:
            return nil
        }
    }

    private var copyText: String? { sticky }
}
