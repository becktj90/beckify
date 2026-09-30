import SwiftUI
import BeckifyMath

/// Dedicated NEC Table 250.122 sizer. Conduit Fill, panels, and cable schedules
/// call the same `EquipmentGrounding.recommend` helper — this screen is the
/// obvious place to do only that job.
struct EquipmentGroundingView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.equipmentGround, "context", default: EquipmentGroundingContext.threePhase) private var context
    @StoredChoice(.equipmentGround, "material", default: ConductorMaterial.copper) private var material
    @StoredInput(.equipmentGround, "ocpd", default: "60") private var ocpd
    @StoredInput(.equipmentGround, "loadAmps", default: "") private var loadAmps
    @StoredInput(.equipmentGround, "ungrounded", default: "") private var ungrounded
    @StoredInput(.equipmentGround, "jobName", default: "Equipment grounding") private var jobName
    @State private var session = ExplicitCalculationState<EquipmentGroundingRecommendation>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var circuits: [EquipmentGroundingContext] {
        EquipmentGroundingContext.allCases.filter(\.impliesEquipmentGround)
    }

    private var sizes: [String] {
        [""] + NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil }
    }

    private var inputFingerprint: String {
        "\(context)|\(material)|\(ocpd)|\(loadAmps)|\(ungrounded)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .equipmentGround,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .equipmentGround,
                symbolic: "OCPD rating → Table 250.122 row → Cu or Al minimum",
                substituted: substituted,
                meaning: "The equipment grounding conductor is sized from the overcurrent device ahead of the equipment, not from ampacity. Enter the breaker or fuse. If you only know the load, the next standard 240.6(A) device is the basis and the label says so.",
                citation: "NEC 2023 Table 250.122. 250.122(A) cap and 250.122(B) voltage-drop note when an ungrounded size is entered. Not Table 250.66. Confirm the current Code and the AHJ."
            )

            MenuField(title: "Circuit", selection: $context, options: circuits) { $0.displayName }
            MenuField(title: "EGC material", selection: $material, options: ConductorMaterial.allCases) { $0.displayName }
            NumberField(title: "OCPD rating", unit: "A", text: $ocpd, optional: true, fieldID: "ocpd", onSubmit: calculate)
            NumberField(title: "Load current if no OCPD", unit: "A", text: $loadAmps, optional: true, fieldID: "loadAmps", onSubmit: calculate)
            MenuField(title: "Ungrounded conductors", selection: $ungrounded, options: sizes) { size in
                size.isEmpty ? "Not entered" : NECTables.wireLabel(size)
            }
            Text("Optional. 250.122(A) keeps the EGC from exceeding those conductors. 250.122(B) proportional increase for voltage drop is noted here and not applied.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: "60 A copper breaker, 3Ø"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let recommendation = session.displayedResult {
                EquipmentGroundingCard(
                    title: "Minimum equipment grounding conductor",
                    recommendation: recommendation
                )
                .opacity(session.isStale ? 0.72 : 1)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .equipmentGround,
                        inputs: [
                            "OCPD": ocpd,
                            "load": loadAmps,
                            "mat": material.rawValue,
                            "circuit": context.rawValue,
                            "phase": ungrounded,
                        ],
                        outputs: [
                            "EGC": recommendation.label,
                            "row": "\(recommendation.tableRatingAmps)",
                        ]
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
        let ocpdText = ocpd.trimmingCharacters(in: .whitespacesAndNewlines)
        let loadText = loadAmps.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicit = !ocpdText.isEmpty
        let phase = ungrounded.trimmingCharacters(in: .whitespacesAndNewlines)
        session.calculate {
            let amps: Double
            if explicit {
                amps = try Positive.require(ocpd.parsedDouble ?? .nan, name: "OCPD rating")
            } else if !loadText.isEmpty {
                amps = try Positive.require(loadAmps.parsedDouble ?? .nan, name: "Load current")
            } else {
                throw CalcError.missing("an OCPD rating or a load current")
            }
            guard let recommendation = EquipmentGrounding.recommend(
                amps: amps,
                material: material,
                context: context,
                ampsAreOCPDRating: explicit,
                ungroundedSize: phase.isEmpty ? nil : phase
            ) else {
                throw CalcError.outOfRange("No Table 250.122 row covers \(Format.amps(amps)). The transcribed table stops at 6000 A.")
            }
            return recommendation
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        context = .threePhase
        material = .copper
        ocpd = ""
        loadAmps = ""
        ungrounded = ""
        session.reset()
    }

    private func applyExample() {
        context = .threePhase
        material = .copper
        ocpd = "60"
        loadAmps = ""
        ungrounded = ""
        session.prepareForNewInputs()
    }

    private var substituted: String? {
        guard let recommendation = session.displayedResult else { return nil }
        return "Table 250.122 ≤ \(recommendation.tableRatingAmps) A → \(recommendation.label) \(recommendation.material.displayName)"
    }

    private var sticky: String? {
        guard let recommendation = session.displayedResult else { return nil }
        return "\(recommendation.label) \(recommendation.material.displayName)  ·  ≤ \(recommendation.tableRatingAmps) A"
    }

    private var copyText: String? {
        session.displayedResult?.copyLine
    }
}
