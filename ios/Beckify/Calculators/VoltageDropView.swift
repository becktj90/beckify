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
    @State private var session = ExplicitCalculationState<VoltageDropResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sizes: [String] {
        NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil }
    }

    private var inputFingerprint: String {
        "\(system)|\(voltage)|\(current)|\(length)|\(material)|\(size)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .voltageDrop,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .voltageDrop,
                symbolic: "VD = (M × K × I × L) / CM",
                substituted: substituted,
                meaning: "M is 2 for 1Ø/DC or √3 for 3Ø. K is 12.9 Cu / 21.2 Al at 75 °C. 3% and 5% are informational notes, not hard NEC limits.",
                citation: "NEC Chapter 9 Table 9 K-factor. Ampacity cross-check uses Table 310.16, 75 °C.",
                referenceTool: .wireAmpacity
            )
            Picker("System", selection: $system) {
                ForEach(ElectricalSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Material", selection: $material) {
                ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            NumberField(title: "Supply voltage", unit: "V", text: $voltage, fieldID: "voltage", onSubmit: calculate)
            NumberField(title: "Load current", unit: "A", text: $current, fieldID: "current", onSubmit: calculate)
            NumberField(title: "One-way length", unit: "ft", text: $length, fieldID: "length", onSubmit: calculate)
            MenuField(title: "Conductor", selection: $size, options: sizes, label: NECTables.wireLabel)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    system = .threePhase
                    voltage = "480"
                    current = "45"
                    length = "250"
                    material = .copper
                    size = "4"
                    session.prepareForNewInputs()
                },
                exampleTitle: "480 V 3Ø, 45 A, 250 ft, 4 Cu"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                if let diagram = VoltageDropDiagram.model(from: r) {
                    diagram
                        .opacity(session.isStale ? 0.72 : 1)
                }
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
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .voltageDrop,
                        inputs: ["sys": system.displayName, "V": voltage, "I": current, "L": length, "size": size, "material": material.displayName],
                        outputs: ["VD": Format.volts(r.dropVolts), "%": Format.percent(r.dropPercent)]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            try VoltageDrop.calculate(
                system: system,
                current: current.parsedDouble ?? .nan,
                oneWayFeet: length.parsedDouble ?? .nan,
                supplyVolts: voltage.parsedDouble ?? .nan,
                size: size,
                material: material
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        voltage = ""
        current = ""
        length = ""
        size = "4"
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        let m = system == .threePhase ? "√3" : "2"
        let k = Format.number(material.resistivityK, digits: 1)
        let i = Format.number(current.parsedDouble ?? .nan, digits: 2)
        let l = Format.number(length.parsedDouble ?? .nan, digits: 1)
        let cm = NECTables.circularMils[size].map { Format.number($0, digits: 0) } ?? size
        return "VD = (\(m) × \(k) × \(i) × \(l)) / \(cm) = \(Format.volts(r.dropVolts))  (\(Format.percent(r.dropPercent)))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.volts(r.dropVolts))  ·  \(Format.percent(r.dropPercent))"
    }

    private var copyText: String? { sticky }
}
