import SwiftUI
import BeckifyMath

struct WireAmpacityView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.wireAmpacity, "amps", default: "95") private var amps
    @StoredChoice(.wireAmpacity, "material", default: ConductorMaterial.copper) private var material
    @StoredInput(.wireAmpacity, "jobName", default: "Wire size") private var jobName
    @State private var session = ExplicitCalculationSession<WireSizeResult>()
    @State private var successTick = 0

    private var fingerprint: String { "\(amps)|\(material.rawValue)" }
    private var display: ExplicitCalculationSession<WireSizeResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .wireAmpacity,
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
                toolID: .wireAmpacity,
                symbolic: "NEC Table 310.16 · 75 °C column",
                substituted: substituted,
                meaning: "Smallest size whose 75 °C ampacity is at least the load. Not more than three current-carrying conductors in a raceway, 30 °C ambient. Termination temperature still applies (110.14(C)).",
                citation: "NEC Table 310.16, 75 °C column."
            )
            TryExampleButton(title: "95 A copper") {
                amps = "95"
                material = .copper
            }
            Picker("Material", selection: $material) {
                ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            NumberField(title: "Load current", unit: "A", text: $amps)

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Smallest size", value: r.label, emphasis: true, tone: Theme.good)
                    ResultRow(label: "Ampacity 75 °C", value: Format.amps(Double(r.ampacity)))
                }
                SaveJobBar(jobName: $jobName, canSave: { if case .current = display { true } else { false } }()) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .wireAmpacity,
                        inputs: ["I": amps, "mat": material.displayName],
                        outputs: ["size": r.label, "amp": "\(r.ampacity) A"]
                    ))
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter load current",
                    detail: "Set amps and material, then Calculate.",
                    systemImage: "cable.connector"
                )
            case .failed:
                EmptyView()
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
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            try WireAmpacity.smallestConductor(loadAmps: amps.parsedDouble ?? .nan, material: material)
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        amps = "95"
        material = .copper
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "Smallest \(material.displayName) at 75 °C with ampacity ≥ \(Format.amps(amps.parsedDouble ?? .nan)) is \(r.label) (\(r.ampacity) A)."
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "\(r.label)  ·  \(r.ampacity) A @ 75 °C"
        default:
            return nil
        }
    }

    private var copyText: String? { sticky }
}
