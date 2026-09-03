import SwiftUI
import BeckifyMath

struct WireAmpacityView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.wireAmpacity, "amps", default: "95") private var amps
    @StoredChoice(.wireAmpacity, "material", default: ConductorMaterial.copper) private var material
    @StoredInput(.wireAmpacity, "jobName", default: "Wire size") private var jobName
    @State private var session = ExplicitCalculationState<WireSizeResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(amps)|\(material)" }

    var body: some View {
        ToolScaffold(
            toolID: .wireAmpacity,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .wireAmpacity,
                symbolic: "NEC Table 310.16 · 75 °C column",
                substituted: substituted,
                meaning: "Smallest size whose 75 °C ampacity is at least the load. Not more than three current-carrying conductors in a raceway, 30 °C ambient. Termination temperature still applies (110.14(C)).",
                citation: "NEC Table 310.16, 75 °C column."
            )
            Picker("Material", selection: $material) {
                ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            NumberField(title: "Load current", unit: "A", text: $amps, fieldID: "amps", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    amps = "95"
                    material = .copper
                    session.prepareForNewInputs()
                },
                exampleTitle: "95 A copper"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Smallest size", value: r.label, emphasis: true, tone: Theme.good)
                    ResultRow(label: "Ampacity 75 °C", value: Format.amps(Double(r.ampacity)))
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .wireAmpacity,
                        inputs: ["I": amps, "mat": material.displayName],
                        outputs: ["size": r.label, "amp": "\(r.ampacity) A"]
                    ))
                }
            }

            ResultCard(title: "310.16 75 °C") {
                ForEach(WireAmpacity.table310_16_75C, id: \.size) { row in
                    HStack {
                        Text(row.label)
                            .font(.subheadline.monospacedDigit())
                        Spacer()
                        Text(row.copper75C.map { "Cu \($0) A" } ?? "—")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(material == .copper ? Theme.foreground : Theme.muted)
                        Text(row.aluminum75C.map { "Al \($0) A" } ?? "Al —")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(material == .aluminum ? Theme.foreground : Theme.muted)
                            .frame(minWidth: 72, alignment: .trailing)
                    }
                    .padding(.vertical, 3)
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
            try WireAmpacity.smallestConductor(loadAmps: amps.parsedDouble ?? .nan, material: material)
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        amps = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "Smallest \(r.material.displayName) at 75 °C with ampacity ≥ \(Format.amps(r.loadAmps)) is \(r.label) (\(r.ampacity) A)."
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.label)  ·  \(r.ampacity) A @ 75 °C"
    }

    private var copyText: String? { sticky }
}
