import SwiftUI
import BeckifyMath

// MARK: - Receptacles per circuit (NEMA 5-20R daisy chain)

struct ReceptacleCircuitView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.receptacleCircuit, "breaker", default: "20") private var breaker
    @StoredInput(.receptacleCircuit, "volts", default: "120") private var volts
    @StoredInput(.receptacleCircuit, "occupancy", default: ReceptacleOccupancy.nonDwelling.rawValue) private var occupancy
    @StoredToggle(.receptacleCircuit, "continuous", default: true) private var continuous
    @StoredInput(.receptacleCircuit, "size", default: "12") private var size
    @StoredInput(.receptacleCircuit, "material", default: ConductorMaterial.copper.rawValue) private var material
    @StoredInput(.receptacleCircuit, "dist", default: "75") private var dist
    @StoredInput(.receptacleCircuit, "plannedVA", default: "") private var plannedVA
    @StoredInput(.receptacleCircuit, "feed", default: ReceptacleFeedMethod.pigtail.rawValue) private var feed
    @StoredInput(.receptacleCircuit, "jobName", default: "Receptacle circuit") private var jobName
    @State private var session = ExplicitCalculationState<ReceptacleCircuitResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sizes = ["14", "12", "10", "8", "6"]

    private var inputFingerprint: String {
        "\(breaker)|\(volts)|\(occupancy)|\(continuous)|\(size)|\(material)|\(dist)|\(plannedVA)|\(feed)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .receptacleCircuit,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .receptacleCircuit,
                symbolic: "N = ⌊A × V × (0.8 if continuous) ÷ 180 VA⌋; VD = 2·K·I·L/CM",
                substituted: substituted,
                meaning: "How many NEMA 5-20R yokes one 120 V general-purpose branch circuit carries. Commercial counts use 180 VA per yoke. Dwellings have no NEC count limit, so the tool shows common practice and checks your planned load and the drop at the last receptacle.",
                citation: "NEC 2023 220.14(I), 220.14(J), 210.11(C), 210.19(A), 210.21(B)(3), 210.23(A), 240.4(D), 314.16. The AHJ governs. Design aid.",
                referenceTool: .voltageDrop
            )

            MenuField(title: "Circuit rating", selection: $breaker, options: ["20", "15"]) { "\($0) A" }
            NumberField(title: "Voltage", unit: "V", text: $volts, fieldID: "volts", onSubmit: calculate)
            MenuField(title: "Occupancy", selection: $occupancy, options: ReceptacleOccupancy.allCases.map(\.rawValue)) {
                ReceptacleOccupancy(rawValue: $0)?.displayName ?? $0
            }
            Toggle("Treat as continuous (80 %)", isOn: $continuous)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            MenuField(title: "Wire size", selection: $size, options: Self.sizes) { NECTables.wireLabel($0) }
            MenuField(title: "Material", selection: $material, options: ConductorMaterial.allCases.map(\.rawValue)) {
                ConductorMaterial(rawValue: $0)?.displayName ?? $0
            }
            NumberField(title: "One-way length to last receptacle", unit: "ft", text: $dist, fieldID: "dist", onSubmit: calculate)
            NumberField(
                title: "Planned connected load",
                unit: "VA",
                text: $plannedVA,
                optional: true,
                helpText: "Leave blank to check drop at the usable circuit capacity.",
                fieldID: "plannedVA",
                onSubmit: calculate
            )
            MenuField(title: "Daisy chain", selection: $feed, options: ReceptacleFeedMethod.allCases.map(\.rawValue)) {
                ReceptacleFeedMethod(rawValue: $0)?.displayName ?? $0
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    breaker = "20"; volts = "120"; occupancy = ReceptacleOccupancy.nonDwelling.rawValue; continuous = true
                    size = "12"; material = ConductorMaterial.copper.rawValue; dist = "75"; plannedVA = ""
                    feed = ReceptacleFeedMethod.pigtail.rawValue
                    session.reset()
                },
                onExample: {
                    breaker = "20"; volts = "120"; occupancy = ReceptacleOccupancy.nonDwelling.rawValue; continuous = true
                    size = "12"; material = ConductorMaterial.copper.rawValue; dist = "90"; plannedVA = "1440"
                    feed = ReceptacleFeedMethod.pigtail.rawValue
                    session.prepareForNewInputs()
                },
                exampleTitle: "20 A office run, 12 AWG Cu, 90 ft, 1,440 VA"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                let vd = r.voltageDrop
                if let diagram = VoltageDropDiagram.model(
                    supply: r.input.volts,
                    drop: vd.dropVolts,
                    receiving: vd.receivingVolts,
                    dropPercent: vd.dropPercent,
                    oneWayLength: "\(Format.number(r.input.oneWayFeet)) ft",
                    parallelRuns: 1,
                    targetPercent: 3,
                    meetsTarget: vd.meets3Percent,
                    ampacityChip: VoltageDropAmpacityChip(
                        line: "\(vd.conductorLabel) · \(r.input.breakerAmps) A breaker",
                        meets: r.conductorOK
                    ),
                    dropFill: vd.dropPercent > 3 ? Theme.warn : Theme.chartPrimary,
                    spokenSummary: "Last receptacle sees \(Format.volts(vd.receivingVolts)), \(Format.percent(vd.dropPercent)) drop at \(Format.amps(r.vdAmps)).",
                    exportName: "receptacle-circuit-run",
                    accessibilityID: "receptacleCircuit.runStrip"
                ) {
                    diagram.opacity(session.isStale ? 0.72 : 1)
                }

                ResultCard(copyText: copyText) {
                    switch r.input.occupancy {
                    case .nonDwelling:
                        ResultRow(
                            label: r.input.continuous ? "Max yokes (80 %, 220.14(I))" : "Max yokes (100 %, 220.14(I))",
                            value: "\(r.nonDwellingCount)",
                            emphasis: true,
                            tone: Theme.copper
                        )
                        ResultRow(label: "At 100 % / at 80 %", value: "\(r.nonDwellingCountFull) / \(r.nonDwellingCountContinuous)")
                    case .dwelling:
                        ResultRow(label: "NEC count limit", value: "None for general-purpose", emphasis: true)
                        ResultRow(
                            label: "Common practice",
                            value: "\(r.dwellingGuidance.lowerBound)–\(r.dwellingGuidance.upperBound) receptacles",
                            tone: Theme.copper
                        )
                    }
                    ResultRow(label: "Circuit capacity", value: "\(Format.number(r.circuitVA)) VA")
                    ResultRow(
                        label: r.input.continuous ? "Usable (80 %)" : "Usable (100 %)",
                        value: "\(Format.number(r.usableVA)) VA · \(Format.amps(r.usableVA / r.input.volts))"
                    )
                    if let amps = r.plannedAmps, let pct = r.plannedPercentOfCircuit, let fits = r.plannedFitsUsable {
                        ResultRow(
                            label: "Planned load",
                            value: "\(Format.amps(amps)) · \(Format.percent(pct)) of rating",
                            emphasis: true,
                            tone: fits ? Theme.good : Theme.bad
                        )
                    }
                    ResultRow(
                        label: "NEMA 5-20R",
                        value: r.nema520Permitted ? "Permitted on 20 A" : "Not with 2+ on 15 A",
                        tone: r.nema520Permitted ? Theme.good : Theme.bad
                    )
                    ResultRow(
                        label: "Conductor (240.4(D))",
                        value: r.conductorOK ? "\(vd.conductorLabel) OK" : "Needs \(r.minimumConductorLabel) min",
                        tone: r.conductorOK ? Theme.good : Theme.bad
                    )
                    ResultRow(
                        label: r.vdUsesPlannedLoad ? "Drop at planned load" : "Drop at usable capacity",
                        value: "\(Format.volts(vd.dropVolts)) (\(Format.percent(vd.dropPercent)))",
                        tone: vd.meets3Percent ? Theme.foreground : (vd.meets5Percent ? Theme.warn : Theme.bad)
                    )
                    ResultRow(
                        label: "3 % / 5 % guidance",
                        value: "\(vd.meets3Percent ? "meets" : "over") 3 % · \(vd.meets5Percent ? "meets" : "over") 5 %",
                        tone: Theme.muted
                    )
                }
                .opacity(session.isStale ? 0.72 : 1)

                ResultCard(title: "Code notes") {
                    ForEach(Array(r.notes.enumerated()), id: \.offset) { _, note in
                        Text(note)
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .padding(.vertical, 2)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .receptacleCircuit,
                        inputs: ["A": breaker, "V": volts, "ft": dist, "VA": plannedVA, "size": size],
                        outputs: ["count": "\(r.headlineCount)", "VD%": Format.percent(vd.dropPercent)]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        let trimmedLoad = plannedVA.trimmingCharacters(in: .whitespacesAndNewlines)
        session.calculate {
            try ReceptacleCircuit.solve(ReceptacleCircuitInput(
                breakerAmps: Int(breaker) ?? 20,
                volts: volts.parsedDouble ?? .nan,
                occupancy: ReceptacleOccupancy(rawValue: occupancy) ?? .nonDwelling,
                continuous: continuous,
                size: size,
                material: ConductorMaterial(rawValue: material) ?? .copper,
                oneWayFeet: dist.parsedDouble ?? .nan,
                plannedLoadVA: trimmedLoad.isEmpty ? nil : (trimmedLoad.parsedDouble ?? .nan),
                feed: ReceptacleFeedMethod(rawValue: feed) ?? .pigtail
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        let factor = r.input.continuous ? " × 0.8" : ""
        return "⌊\(r.input.breakerAmps) A × \(Format.number(r.input.volts)) V\(factor) ÷ 180⌋ = \(r.input.continuous ? r.nonDwellingCountContinuous : r.nonDwellingCountFull)"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        let count = r.input.occupancy == .nonDwelling
            ? "\(r.nonDwellingCount) yokes"
            : "\(r.dwellingGuidance.lowerBound)–\(r.dwellingGuidance.upperBound) typical"
        return "\(count) · \(r.input.breakerAmps) A · \(Format.percent(r.voltageDrop.dropPercent)) VD"
    }

    private var copyText: String? { sticky }
}
