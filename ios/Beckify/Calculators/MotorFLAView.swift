import SwiftUI
import BeckifyMath

struct MotorFLAView: View {
    private struct LookupResult: Equatable {
        var column: String
        var fla: Double
        var horsepower: String
        var threePhase: Bool

        var article: String { threePhase ? "430.250" : "430.248" }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredToggle(.motorFLA, "threePhase", default: true) private var threePhase
    @StoredInput(.motorFLA, "hp", default: "10") private var hp
    @StoredInput(.motorFLA, "systemVolts", default: "480") private var systemVolts
    @StoredInput(.motorFLA, "jobName", default: "Motor FLA") private var jobName
    @State private var session = ExplicitCalculationState<LookupResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var table: [MotorFLARow] {
        threePhase ? MotorFLA.table430_250 : MotorFLA.table430_248
    }

    private var voltages: [String] {
        threePhase ? MotorFLA.threePhaseVoltages : MotorFLA.singlePhaseVoltages
    }

    private var hpOptions: [String] { table.map(\.horsepower) }

    private var inputFingerprint: String { "\(threePhase)|\(hp)|\(systemVolts)" }

    var body: some View {
        ToolScaffold(
            toolID: .motorFLA,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .motorFLA,
                symbolic: "Table FLA for 430.22 and Table 430.52. Overload is 430.32 on the nameplate.",
                substituted: substituted,
                meaning: "480 V systems use the 460 V column. Conductors are at least 125% of table FLA (430.22). SCPD percent is Table 430.52 of that table FLA (430.6(A)(1)). Overload is 430.32 on nameplate FLA — not 430.52.",
                citation: "NEC 430.6(A)(1) · 430.22 · 430.32 · Table 430.52 · Tables 430.248 / 430.250."
            )
            Picker("Table", selection: $threePhase) {
                Text("430.248 1Ø").tag(false)
                Text("430.250 3Ø").tag(true)
            }
            .segmentedControlStyle()

            MenuField(title: "Horsepower", selection: $hp, options: hpOptions) { "\($0) HP" }
            NumberField(title: "System voltage", unit: "V", text: $systemVolts, fieldID: "systemVolts", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    threePhase = true
                    hp = "10"
                    systemVolts = "480"
                    session.prepareForNewInputs()
                },
                exampleTitle: "10 HP, 480 V 3Ø"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                if let plate = plate(for: r) {
                    TableFLAPlateCard(plate: plate)
                        .opacity(session.isStale ? 0.72 : 1)
                }
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Table column", value: plate(for: r)?.voltageLabel ?? "\(r.column) V", tone: Theme.muted)
                    ResultRow(label: "Table FLA", value: plate(for: r)?.tableFLALabel ?? Format.amps(r.fla), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Conductor min (430.22)", value: plate(for: r)?.conductorLabel ?? Format.amps(MotorFLA.conductorAmps(fla: r.fla)))
                }
                .opacity(session.isStale ? 0.72 : 1)
                EquipmentGroundingCard(
                    recommendation: EquipmentGrounding.recommend(
                        amps: MotorFLA.conductorAmps(fla: r.fla),
                        material: .copper,
                        context: r.threePhase ? .threePhase : .singlePhase,
                        ampsAreOCPDRating: false,
                        extraNote: "Basis is the next standard device at or above 125% table FLA (430.22). A 430.52 breaker is often larger — use that device for the EGC."
                    )
                )
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .motorFLA,
                        inputs: ["HP": r.horsepower, "V": systemVolts, "table": r.article],
                        outputs: ["FLA": Format.amps(r.fla)]
                    ))
                }
            }

            ResultCard(title: threePhase ? "NEC Table 430.250" : "NEC Table 430.248") {
                ForEach(table, id: \.horsepower) { row in
                    HStack {
                        Text("\(row.horsepower) HP")
                            .font(.caption.weight(.semibold))
                            .frame(minWidth: 64, alignment: .leading)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(voltages, id: \.self) { v in
                                    VStack(spacing: 2) {
                                        Text("\(v) V").font(.caption2).foregroundStyle(Theme.muted)
                                        Text(row.amps(at: v).map { Format.number($0, digits: 1) } ?? "—")
                                            .font(.caption.monospacedDigit())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onChange(of: threePhase) { _, _ in
            let opts = hpOptions
            if !opts.contains(hp) { hp = opts.first ?? hp }
            session.markInputsChanged()
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            guard let col = MotorFLA.tableVoltage(forSystemVolts: systemVolts.parsedDouble ?? .nan, threePhase: threePhase),
                  let fla = MotorFLA.lookup(horsepower: hp, voltageColumn: col, threePhase: threePhase) else {
                throw CalcError.missing("a listed HP / voltage combination")
            }
            return LookupResult(column: col, fla: fla, horsepower: hp, threePhase: threePhase)
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        hp = "10"
        systemVolts = ""
        session.reset()
    }

    private func plate(for result: LookupResult) -> TableFLAPlate? {
        TableFLAPlate(
            horsepower: result.horsepower,
            columnVolts: result.column,
            systemVolts: systemVolts.parsedDouble,
            threePhase: result.threePhase,
            tableAmps: result.fla
        )
    }

    private var substituted: String? {
        guard let r = session.displayedResult, let plate = plate(for: r) else { return nil }
        return "Table \(plate.article), \(plate.horsepowerLabel) @ \(plate.voltageLabel) column = \(plate.tableFLALabel). Conductor min = 125% of table FLA = \(plate.conductorLabel)."
    }

    private var sticky: String? {
        guard let r = session.displayedResult, let plate = plate(for: r) else { return nil }
        return "\(plate.tableFLALabel)  ·  \(plate.horsepowerLabel) @ \(plate.voltageLabel)"
    }

    private var copyText: String? { sticky }
}

/// One plate for NEC table current. Horsepower, table-column volts, phase, table FLA, and 125% conductor current.
private struct TableFLAPlateCard: View {
    let plate: TableFLAPlate

    var body: some View {
        DiagramCard(title: "Table FLA", accessibilitySummary: plate.announcement, exportName: "table-fla") {
            VStack(alignment: .leading, spacing: 8) {
                plateFace
                Text(TableFLAPlate.nameplateRedirect)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("motorFLA.tablePlate")
    }

    private var plateFace: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Table \(plate.article)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                spec("HP", plate.horsepowerLabel)
                Spacer(minLength: 8)
                spec("Table column", plate.voltageLabel)
                Spacer(minLength: 8)
                spec("Phase", plate.phaseLabel)
            }
            Rectangle()
                .fill(Theme.border)
                .frame(height: Theme.Stroke.hairline)
            callout(plate.tableFLALabel, "Table FLA", tone: Theme.good, prominent: true)
            callout(plate.conductorLabel, "125% conductor", tone: Theme.energized, prominent: false)
            if let note = plate.columnNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Canvas { context, size in
                platePath(in: context, size: size)
            }
        }
        .accessibilityHidden(true)
    }

    private func spec(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func callout(_ value: String, _ caption: String, tone: Color, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(prominent ? .title2.monospacedDigit().weight(.bold) : .title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Drawn plate: double border and corner ticks. No motor body, no screw heads, no brand block.
    private func platePath(in context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.25, dy: 1.25)
        let outer = Path(roundedRect: rect, cornerRadius: 8)
        context.fill(outer, with: .color(Theme.surface))
        context.stroke(outer, with: .color(Theme.foreground.opacity(0.88)), lineWidth: Theme.Stroke.emphasis)
        let inner = Path(roundedRect: rect.insetBy(dx: 5, dy: 5), cornerRadius: 4)
        context.stroke(inner, with: .color(Theme.border), lineWidth: Theme.Stroke.hairline)
        let tick: CGFloat = 9
        let inset: CGFloat = 9
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX + inset, y: rect.minY + inset), 1, 1),
            (CGPoint(x: rect.maxX - inset, y: rect.minY + inset), -1, 1),
            (CGPoint(x: rect.minX + inset, y: rect.maxY - inset), 1, -1),
            (CGPoint(x: rect.maxX - inset, y: rect.maxY - inset), -1, -1),
        ]
        for (origin, sx, sy) in corners {
            var path = Path()
            path.move(to: CGPoint(x: origin.x, y: origin.y + sy * tick))
            path.addLine(to: origin)
            path.addLine(to: CGPoint(x: origin.x + sx * tick, y: origin.y))
            context.stroke(path, with: .color(Theme.accent), style: StrokeStyle(lineWidth: Theme.Stroke.hairline, lineCap: .round, lineJoin: .round))
        }
    }
}
