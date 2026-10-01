import SwiftUI
import BeckifyMath

struct TransformerView: View {
    enum LoadKind: String, CaseIterable, Identifiable {
        case kva = "kVA"
        case kw = "kW"
        case amps = "A"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.transformer, "system", default: ElectricalSystem.threePhase) private var system
    @StoredChoice(.transformer, "loadKind", default: LoadKind.kw) private var loadKind
    @StoredInput(.transformer, "load", default: "38") private var load
    @StoredInput(.transformer, "pf", default: "90") private var pf
    @StoredInput(.transformer, "vp", default: "480") private var vp
    @StoredInput(.transformer, "vs", default: "208") private var vs
    @StoredChoice(.transformer, "connection", default: TransformerConnection.deltaWye) private var connection
    @StoredToggle(.transformer, "continuous", default: true) private var continuous
    @StoredInput(.transformer, "zR", default: "8") private var zR
    @StoredInput(.transformer, "zX", default: "6") private var zX
    @StoredInput(.transformer, "lineR", default: "0.25") private var lineR
    @StoredInput(.transformer, "jobName", default: "Transformer") private var jobName
    @State private var session = ExplicitCalculationState<TransformerRun>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(system)|\(loadKind)|\(load)|\(pf)|\(vp)|\(vs)|\(connection)|\(continuous)|\(zR)|\(zX)|\(lineR)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .transformer,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .transformer,
                symbolic: system == .threePhase
                    ? "I = kVA × 1000 ÷ (√3 × V)    OCPD per 450.3(B)"
                    : "I = kVA × 1000 ÷ V    OCPD per 450.3(B)",
                substituted: substituted,
                meaning: "Standard kVA is the next catalog rating at or above the design kVA. 450.3(B) sizes the transformer OCPD — Note 1 allows the next standard size up only on 125% rows. Fault current comes from %Z and the source, not from 450.3. High-leg and corner-ground change the bond. A separately derived system grounding electrode conductor is 250.30. The equipment ground is 250.122.",
                citation: "NEC 450.3(B) including Note 1. GEC 250.30. EGC Table 250.122. Available fault is %Z, not 450.3."
            )
            Picker("System", selection: $system) {
                Text("1Ø").tag(ElectricalSystem.singlePhase)
                Text("3Ø").tag(ElectricalSystem.threePhase)
            }
            .segmentedControlStyle()
            Picker("Load", selection: $loadKind) {
                ForEach(LoadKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()

            NumberField(title: "Connected load", unit: loadKind.rawValue, text: $load, fieldID: "load", onSubmit: calculate)
            if loadKind == .kw {
                NumberField(title: "Power factor", unit: "%", text: $pf, fieldID: "pf", onSubmit: calculate)
            }
            NumberField(title: "Primary voltage", unit: "V", text: $vp, fieldID: "vp", onSubmit: calculate)
            NumberField(title: "Secondary voltage", unit: "V", text: $vs, fieldID: "vs", onSubmit: calculate)
            Picker("Connection", selection: $connection) {
                ForEach(TransformerConnection.allowed(system)) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.menu)
            NumberField(title: "Secondary resistance", unit: "Ω", text: $zR, fieldID: "zR", onSubmit: calculate)
            NumberField(title: "Secondary reactance", unit: "Ω", text: $zX, fieldID: "zX", onSubmit: calculate)
            NumberField(title: "Line conductor resistance", unit: "Ω", text: $lineR, fieldID: "lineR", onSubmit: calculate)
            Text("Z' = Z × (Np/Ns)². Ideal ratio. Magnetizing current is left out. Line loss holds the same watts and leaves out transformer loss.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            TransformerConnectionDiagram(
                connection: resolvedConnection,
                secondaryVolts: vs.parsedDouble ?? 0,
                primaryVolts: vp.parsedDouble ?? 0,
                referral: session.isStale ? nil : referralCaption
            )
            Toggle("Continuous load (size at 125%)", isOn: $continuous)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    system = .threePhase
                    loadKind = .kw
                    load = "38"
                    pf = "90"
                    vp = "480"
                    vs = "208"
                    connection = .deltaWye
                    continuous = true
                    zR = "8"
                    zX = "6"
                    lineR = "0.25"
                    session.prepareForNewInputs()
                },
                exampleTitle: "38 kW, 480/208 V 3Ø, PF 90%"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let run = session.displayedResult {
                let r = run.sizing
                ResultCard(title: "Transformer", copyText: copyText) {
                    ResultRow(label: "Connected", value: "\(Format.number(r.loadKVA, digits: 2)) kVA")
                    ResultRow(label: "Design", value: "\(Format.number(r.designKVA, digits: 2)) kVA")
                    ResultRow(label: "Standard rating", value: "\(Format.number(r.selectedKVA, digits: 1)) kVA", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Primary FLA", value: Format.amps(r.primaryFLA), emphasis: true)
                    ResultRow(label: "Secondary FLA", value: Format.amps(r.secondaryFLA), emphasis: true)
                    ResultRow(label: "Turns ratio", value: "\(Format.number(r.turnsRatio, digits: 3)) : 1")
                }
                .opacity(session.isStale ? 0.72 : 1)
                ResultCard(title: "Method 1 — primary only") {
                    ocpdRows(r.primaryOnly)
                }
                .opacity(session.isStale ? 0.72 : 1)
                ResultCard(title: "Method 2 — primary + secondary") {
                    ResultRow(label: "Primary 250%", value: device(r.primaryWithSecondary), emphasis: true)
                    ocpdRows(r.secondaryProtection)
                }
                .opacity(session.isStale ? 0.72 : 1)
                ResultCard(title: "Conductor minimum") {
                    ResultRow(label: "Primary 125%", value: Format.amps(r.primaryConductorMinAmps))
                    ResultRow(label: "Secondary 125%", value: Format.amps(r.secondaryConductorMinAmps))
                }
                .opacity(session.isStale ? 0.72 : 1)
                if let primary = r.primaryWithSecondary.deviceAmps {
                    EquipmentGroundingCard(
                        title: "Primary EGC",
                        recommendation: EquipmentGrounding.recommend(
                            amps: Double(primary),
                            material: .copper,
                            context: EquipmentGroundingContext.from(system: system == .dc ? .threePhase : system),
                            ampsAreOCPDRating: true,
                            extraNote: "From the 450.3(B) primary device in the primary-and-secondary method. Confirm the device you install."
                        )
                    )
                    .opacity(session.isStale ? 0.72 : 1)
                }
                if let secondary = r.secondaryProtection.deviceAmps {
                    EquipmentGroundingCard(
                        title: "Secondary EGC",
                        recommendation: EquipmentGrounding.recommend(
                            amps: Double(secondary),
                            material: .copper,
                            context: EquipmentGroundingContext.from(system: system == .dc ? .threePhase : system),
                            ampsAreOCPDRating: true,
                            extraNote: "From the 450.3(B) secondary device. This is an equipment grounding conductor, not a grounding electrode conductor."
                        )
                    )
                    .opacity(session.isStale ? 0.72 : 1)
                }
                reflectionCards(run)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    var inputs: [String: String] = [
                        "system": system.displayName,
                        "loadKind": loadKind.rawValue,
                        "load": load,
                        "vp": vp,
                        "vs": vs,
                        "continuous": continuous ? "yes" : "no",
                    ]
                    if loadKind == .kw { inputs["pf"] = pf }
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .transformer,
                        inputs: inputs,
                        outputs: ["kVA": "\(r.selectedKVA)", "Ip": Format.amps(r.primaryFLA), "Is": Format.amps(r.secondaryFLA)]
                    ))
                }
            }
        }
        .onAppear {
            if system == .dc { system = .threePhase }
            if !TransformerConnection.allowed(system).contains(connection) {
                connection = system == .singlePhase ? .isolation : .deltaWye
            }
        }
        .onChange(of: system) { _, newValue in
            if !TransformerConnection.allowed(newValue).contains(connection) {
                connection = newValue == .singlePhase ? .isolation : .deltaWye
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    @ViewBuilder
    private func ocpdRows(_ o: TransformerOCPD) -> some View {
        ResultRow(label: "Table limit", value: "\(o.percent)%  \(o.note)")
        ResultRow(label: "Ceiling", value: Format.amps(o.ceilingAmps))
        ResultRow(label: "OCPD", value: device(o), emphasis: true, tone: o.deviceAmps == nil ? Theme.bad : Theme.good)
        ResultRow(label: "Rounding", value: o.roundsUp ? "Next size up — Note 1" : "Must not exceed ceiling")
    }

    private func device(_ o: TransformerOCPD) -> String {
        o.deviceAmps.map { "\($0) A" } ?? "No standard rating fits"
    }

    private func calculate() {
        session.calculate {
            let kind: TransformerLoad
            switch loadKind {
            case .kva: kind = .kVA(load.parsedDouble ?? .nan)
            case .kw: kind = .kW(load.parsedDouble ?? .nan, powerFactor: (pf.parsedDouble ?? .nan) / 100)
            case .amps: kind = .amps(load.parsedDouble ?? .nan)
            }
            let sizing = try TransformerSizing.size(
                system: system == .dc ? .threePhase : system,
                load: kind,
                primaryVolts: vp.parsedDouble ?? .nan,
                secondaryVolts: vs.parsedDouble ?? .nan,
                continuous: continuous
            )
            let reflected = reflect(primaryVolts: vp.parsedDouble ?? .nan, secondaryVolts: vs.parsedDouble ?? .nan)
            return TransformerRun(
                sizing: sizing,
                referred: reflected?.referred,
                lineLoss: reflected?.lineLoss,
                reflectionMessage: reflected?.message
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        load = ""
        pf = "90"
        vp = ""
        vs = ""
        zR = ""
        zX = ""
        lineR = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult?.sizing else { return nil }
        return "\(r.formula)  →  Ip \(Format.amps(r.primaryFLA))  ·  Is \(Format.amps(r.secondaryFLA))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult?.sizing else { return nil }
        return "\(Format.number(r.selectedKVA, digits: 1)) kVA  ·  Ip \(Format.amps(r.primaryFLA))  ·  Is \(Format.amps(r.secondaryFLA))"
    }

    private var copyText: String? { sticky }

    private var referralCaption: String? {
        guard let referred = session.displayedResult?.referred else { return nil }
        return "Secondary \(ohms(referred.load)) refers to the primary as \(ohms(referred.referred)). Np/Ns \(Format.number(referred.turnsRatio, digits: 3))."
    }

    private func reflect(primaryVolts: Double, secondaryVolts: Double) -> (referred: ReferredImpedance?, lineLoss: StepUpLineLoss?, message: String?)? {
        let rBlank = zR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let xBlank = zX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !rBlank || !xBlank else { return nil }
        let load = ComplexOhms(
            resistance: rBlank ? 0 : (zR.parsedDouble ?? .nan),
            reactance: xBlank ? 0 : (zX.parsedDouble ?? .nan)
        )
        let conductor = lineR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : (lineR.parsedDouble ?? .nan)
        do {
            let referred = try ImpedanceReflection.refer(
                load: load,
                primaryVolts: primaryVolts,
                secondaryVolts: secondaryVolts,
                basis: turnsBasis
            )
            let loss = try ImpedanceReflection.compareLineLoss(
                system: system == .dc ? .threePhase : system,
                load: load,
                secondaryVolts: secondaryVolts,
                primaryVolts: primaryVolts,
                conductorOhms: conductor
            )
            return (referred, loss, nil)
        } catch let error as CalcError {
            let referred = try? ImpedanceReflection.refer(
                load: load,
                primaryVolts: primaryVolts,
                secondaryVolts: secondaryVolts,
                basis: turnsBasis
            )
            return (referred, nil, error.message)
        } catch {
            return (nil, nil, CalcError.missing("values").message)
        }
    }

    private var turnsBasis: TurnsRatioBasis {
        switch resolvedConnection {
        case .zigzag, .autotransformer, .buckBoost:
            return .approximateLineVoltages
        case .wyeDelta:
            return .wyePrimaryDeltaSecondary
        case .deltaWye, .groundedWye:
            return .deltaPrimaryWyeSecondary
        case .wyeWye, .resistanceGround, .reactanceGround, .deltaDelta, .openDelta, .ungroundedDelta, .highLeg, .cornerGrounded, .isolation:
            return .lineVoltages
        }
    }

    @ViewBuilder
    private func reflectionCards(_ run: TransformerRun) -> some View {
        let stale = session.isStale
        if let referred = run.referred {
            ResultCard(title: "Referred impedance") {
                ResultRow(label: "Z secondary", value: ohms(referred.load))
                ResultRow(label: "Np/Ns", value: Format.number(referred.turnsRatio, digits: 3), emphasis: true)
                ResultRow(label: "Z primary", value: ohms(referred.referred), emphasis: true, tone: Theme.good)
                ResultRow(label: "|Z'|", value: "\(Format.number(referred.referred.magnitude, digits: 3)) Ω")
                ResultRow(label: "Angle", value: Format.degrees(referred.referred.angleDegrees))
                Text(referred.formula)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                Text(referred.basis.note)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(stale ? 0.72 : 1)
        }
        if let loss = run.lineLoss {
            ResultCard(title: "Line loss, same load power") {
                ResultRow(label: "Load", value: "\(Format.watts(loss.loadWatts))  ·  PF \(Format.percent(loss.powerFactor * 100))")
                ResultRow(label: "At \(Format.number(loss.lowVolts, digits: 0)) V", value: "\(Format.amps(loss.currentLow))  ·  \(Format.watts(loss.lossLowWatts))")
                ResultRow(
                    label: "At \(Format.number(loss.highVolts, digits: 0)) V",
                    value: "\(Format.amps(loss.currentHigh))  ·  \(Format.watts(loss.lossHighWatts))",
                    emphasis: true,
                    tone: Theme.good
                )
                ForEach(loss.assumptions, id: \.self) { line in
                    Text(line)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(stale ? 0.72 : 1)
        } else if let message = run.reflectionMessage {
            Text(message)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.warn)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resolvedConnection: TransformerConnection {
        let allowed = TransformerConnection.allowed(system)
        return allowed.contains(connection) ? connection : (system == .singlePhase ? .isolation : .deltaWye)
    }
}

private struct TransformerRun: Equatable, Sendable {
    var sizing: TransformerSizingResult
    var referred: ReferredImpedance?
    var lineLoss: StepUpLineLoss?
    var reflectionMessage: String?
}

private func ohms(_ z: ComplexOhms) -> String {
    let sign = z.reactance < 0 ? "−" : "+"
    return "\(Format.number(z.resistance, digits: 3)) \(sign) j\(Format.number(abs(z.reactance), digits: 3)) Ω"
}

enum TransformerConnection: String, CaseIterable, Identifiable {
    case isolation
    case deltaWye = "delta-wye"
    case wyeDelta = "wye-delta"
    case deltaDelta = "delta-delta"
    case wyeWye = "wye-wye"
    case openDelta = "open-delta"
    case zigzag
    case highLeg = "high-leg"
    case cornerGrounded = "corner-grounded"
    case ungroundedDelta = "ungrounded-delta"
    case groundedWye = "grounded-wye"
    case autotransformer
    case buckBoost = "buck-boost"
    case resistanceGround = "resistance-ground"
    case reactanceGround = "reactance-ground"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .isolation: return "Isolation"
        case .deltaWye: return "Delta–wye"
        case .wyeDelta: return "Wye–delta"
        case .deltaDelta: return "Delta–delta"
        case .wyeWye: return "Wye–wye"
        case .openDelta: return "Open delta"
        case .zigzag: return "Zig-zag grounding"
        case .highLeg: return "High-leg delta"
        case .cornerGrounded: return "Corner-grounded delta"
        case .ungroundedDelta: return "Ungrounded delta"
        case .groundedWye: return "Solidly grounded wye"
        case .autotransformer: return "Autotransformer"
        case .buckBoost: return "Buck-boost"
        case .resistanceGround: return "Resistance grounding"
        case .reactanceGround: return "Reactance grounding"
        }
    }

    var singlePhase: Bool {
        switch self {
        case .isolation, .autotransformer, .buckBoost: return true
        default: return false
        }
    }

    static func allowed(_ system: ElectricalSystem) -> [TransformerConnection] {
        if system == .singlePhase {
            return [.isolation, .autotransformer, .buckBoost]
        }
        return allCases.filter { !$0.singlePhase || $0 != .isolation }
    }
}

private struct TransformerLead: Identifiable {
    var name: String
    var colorName: String
    var color: Color
    var code: Bool
    var id: String { name + colorName }
}

private struct TransformerConnectionDiagram: View {
    var connection: TransformerConnection
    var secondaryVolts: Double
    var primaryVolts: Double
    var referral: String? = nil

    private var summary: String {
        let base = "\(connection.title) winding diagram. \(callouts.joined(separator: " ")) Common North American practice. The AHJ and the project spec win."
        if let referral { return "\(base) \(referral)" }
        return base
    }

    var body: some View {
        DiagramCard(title: "Windings and phasors", accessibilitySummary: summary, exportName: "transformer-connection") {
            VStack(alignment: .leading, spacing: 10) {
                Canvas { context, size in
                    drawSchematic(context: context, size: size)
                }
                .frame(height: 230)
                .accessibilityHidden(true)

                Canvas { context, size in
                    drawPhasors(context: context, size: size)
                }
                .frame(height: 180)
                .accessibilityHidden(true)

                ForEach(leads) { lead in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(lead.color)
                            .overlay(Circle().stroke(Theme.foreground.opacity(0.35), lineWidth: 1))
                            .frame(width: 12, height: 12)
                        Text("\(lead.name)  \(lead.colorName)  \(lead.code ? "(code)" : "(practice)")")
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.foreground)
                    }
                }
                ForEach(callouts, id: \.self) { line in
                    Text(line)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Common North American practice. The AHJ and the project spec win. 450.3(B) below still uses line current.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let referral {
                    Text(referral)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var is480: Bool { secondaryVolts >= 360 }

    private var leads: [TransformerLead] {
        let hot: [TransformerLead] = is480
            ? [
                TransformerLead(name: "A", colorName: "Brown", color: Color(red: 124 / 255, green: 74 / 255, blue: 30 / 255), code: false),
                TransformerLead(name: "B", colorName: "Orange", color: Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255), code: false),
                TransformerLead(name: "C", colorName: "Yellow", color: Color(red: 234 / 255, green: 179 / 255, blue: 8 / 255), code: false),
            ]
            : [
                TransformerLead(name: "A", colorName: "Black", color: Color(red: 0.16, green: 0.16, blue: 0.16), code: false),
                TransformerLead(name: "B", colorName: "Red", color: Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255), code: false),
                TransformerLead(name: "C", colorName: "Blue", color: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255), code: false),
            ]
        let neutral = TransformerLead(name: "N", colorName: "White or gray", color: Color(red: 0.96, green: 0.96, blue: 0.96), code: true)
        let ground = TransformerLead(name: "EGC", colorName: "Green, green-yellow, or bare", color: Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255), code: true)
        switch connection {
        case .highLeg:
            return [
                TransformerLead(name: "A", colorName: "Black", color: Color(red: 0.16, green: 0.16, blue: 0.16), code: false),
                TransformerLead(name: "B high-leg", colorName: "Orange", color: Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255), code: true),
                TransformerLead(name: "C", colorName: "Blue", color: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255), code: false),
                neutral, ground,
            ]
        case .cornerGrounded:
            let pair = is480
                ? (Color(red: 124 / 255, green: 74 / 255, blue: 30 / 255), "Brown", Color(red: 234 / 255, green: 179 / 255, blue: 8 / 255), "Yellow")
                : (Color(red: 0.16, green: 0.16, blue: 0.16), "Black", Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255), "Red")
            return [
                TransformerLead(name: "Ungrounded", colorName: pair.1, color: pair.0, code: false),
                TransformerLead(name: "Ungrounded", colorName: pair.3, color: pair.2, code: false),
                TransformerLead(name: "Grounded phase", colorName: "White or gray", color: Color(red: 0.96, green: 0.96, blue: 0.96), code: true),
                ground,
            ]
        case .isolation, .autotransformer, .buckBoost:
            return [
                TransformerLead(name: "L1", colorName: "Black", color: Color(red: 0.16, green: 0.16, blue: 0.16), code: false),
                TransformerLead(name: "L2", colorName: "Red", color: Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255), code: false),
                neutral, ground,
            ]
        case .deltaDelta, .openDelta, .wyeDelta, .ungroundedDelta:
            return hot + [ground]
        default:
            return hot + [neutral, ground]
        }
    }

    private var callouts: [String] {
        let vs = secondaryVolts
        switch connection {
        case .highLeg:
            let half = vs > 0 ? Format.volts(vs / 2) : "half the line voltage"
            let wild = vs > 0 ? Format.volts(vs * 1.73205080757 / 2) : "line × √3/2"
            return [
                "Center tap is the neutral. A–N and C–N are \(half).",
                "B–N is \(wild). Tag that conductor orange. B is not grounded.",
            ]
        case .cornerGrounded:
            let line = vs > 0 ? Format.volts(vs) : "full line voltage"
            return [
                "Grounded phase is 0 V to ground and still carries current. White or gray, not green, not orange.",
                "The other phases are \(line) to the enclosure. No high leg and no 120 V neutral.",
            ]
        case .zigzag:
            return ["Grounding transformer. This neutral is not a 120 V receptacle bus."]
        case .openDelta:
            return ["Dashed winding is the missing unit. Capacity is about 57.7% of three equal units."]
        case .isolation:
            return ["Two windings. The gap is the isolation. Draw the center tap only on a 120/240 V secondary."]
        case .autotransformer, .buckBoost:
            return ["One shared winding. Not isolation and not a new color code."]
        case .resistanceGround, .reactanceGround:
            return ["The impedance sits between neutral and ground. Ohms come from a study, not from kVA."]
        case .ungroundedDelta:
            return ["No phase is bonded. The first ground fault does not trip. A detector has to tell you."]
        default:
            if vs > 0 {
                return ["Phase-to-neutral is \(Format.volts(vs / 1.73205080757)). \(is480 ? "480Y brown, orange, and yellow are practice. That orange is not a high leg." : "Under 250 V, black, red, and blue are practice.")"]
            }
            return [is480 ? "480Y brown, orange, and yellow are practice. That orange is not a high leg." : "Hot colors are practice. White or gray is the grounded conductor. Green is the equipment ground."]
        }
    }

    private func drawSchematic(context: GraphicsContext, size: CGSize) {
        let primary = CGRect(x: 8, y: 8, width: size.width * 0.48 - 12, height: size.height - 16)
        let secondary = CGRect(x: size.width * 0.52, y: 8, width: size.width * 0.48 - 8, height: size.height - 16)
        strokeFrame(context, primary, "Primary")
        strokeFrame(context, secondary, "Secondary")
        drawBank(context, rect: primary, kind: primaryKind, accent: Theme.accent)
        drawBank(context, rect: secondary, kind: secondaryKind, accent: Theme.energized)
    }

    private var primaryKind: BankKind {
        switch connection {
        case .wyeDelta, .wyeWye, .resistanceGround, .reactanceGround: return .wye
        case .isolation: return .single
        case .autotransformer, .buckBoost: return .auto
        case .zigzag: return .zigzag
        case .openDelta: return .openDelta
        default: return .delta
        }
    }

    private var secondaryKind: BankKind {
        switch connection {
        case .highLeg: return .highLeg
        case .cornerGrounded: return .corner
        case .openDelta: return .openDelta
        case .zigzag: return .zigzag
        case .ungroundedDelta, .deltaDelta, .wyeDelta: return .delta
        case .isolation: return .singleTap
        case .autotransformer, .buckBoost: return .auto
        case .resistanceGround: return .resistor
        case .reactanceGround: return .reactor
        default: return .wye
        }
    }

    private enum BankKind { case delta, openDelta, wye, highLeg, corner, zigzag, single, singleTap, auto, resistor, reactor }

    private func strokeFrame(_ context: GraphicsContext, _ rect: CGRect, _ title: String) {
        let path = Path(roundedRect: rect, cornerRadius: 8)
        context.stroke(path, with: .color(Theme.border), lineWidth: 1)
        context.draw(Text(title).font(.caption2).foregroundColor(Theme.muted), at: CGPoint(x: rect.minX + 36, y: rect.minY + 12))
    }

    private func drawBank(_ context: GraphicsContext, rect: CGRect, kind: BankKind, accent: Color) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        switch kind {
        case .delta, .openDelta, .corner, .highLeg:
            coil(context, p(0.18, 0.28), p(0.82, 0.28), accent, dashed: false)
            coil(context, p(0.82, 0.28), p(0.50, 0.82), accent, dashed: kind == .openDelta)
            coil(context, p(0.50, 0.82), p(0.18, 0.28), accent, dashed: false)
            terminal(context, p(0.18, 0.28), "A")
            terminal(context, p(0.82, 0.28), "B")
            terminal(context, p(0.50, 0.82), "C")
            if kind == .highLeg {
                let tap = p(0.34, 0.55)
                terminal(context, tap, "N")
                ground(context, tap)
            }
            if kind == .corner { ground(context, p(0.18, 0.28)) }
        case .wye, .resistor, .reactor:
            coil(context, p(0.50, 0.48), p(0.50, 0.18), accent, dashed: false)
            coil(context, p(0.50, 0.48), p(0.18, 0.78), accent, dashed: false)
            coil(context, p(0.50, 0.48), p(0.82, 0.78), accent, dashed: false)
            terminal(context, p(0.50, 0.18), "A")
            terminal(context, p(0.18, 0.78), "B")
            terminal(context, p(0.82, 0.78), "C")
            terminal(context, p(0.50, 0.48), "N")
            if kind == .wye { ground(context, p(0.50, 0.48)) }
            if kind == .resistor || kind == .reactor {
                let box = CGRect(x: p(0.50, 0.48).x - 12, y: p(0.50, 0.48).y + 8, width: 24, height: 14)
                context.stroke(Path(box), with: .color(Theme.warn), lineWidth: 1.4)
                context.draw(Text(kind == .resistor ? "R" : "X").font(.caption2).foregroundColor(Theme.warn), at: CGPoint(x: box.midX, y: box.midY))
                ground(context, CGPoint(x: box.midX, y: box.maxY + 10))
            }
        case .zigzag:
            coil(context, p(0.50, 0.78), p(0.32, 0.48), accent, dashed: false)
            coil(context, p(0.32, 0.48), p(0.50, 0.18), accent, dashed: false)
            coil(context, p(0.50, 0.78), p(0.68, 0.48), accent, dashed: false)
            coil(context, p(0.68, 0.48), p(0.82, 0.28), accent, dashed: false)
            terminal(context, p(0.50, 0.18), "A")
            terminal(context, p(0.82, 0.28), "C")
            terminal(context, p(0.50, 0.78), "N")
            ground(context, p(0.50, 0.78))
        case .single, .singleTap:
            coil(context, p(0.50, 0.18), p(0.50, 0.82), accent, dashed: false)
            terminal(context, p(0.50, 0.18), "X1")
            terminal(context, p(0.50, 0.82), "X2")
            if kind == .singleTap {
                terminal(context, p(0.50, 0.50), "N")
                ground(context, p(0.50, 0.50))
            }
        case .auto:
            coil(context, p(0.50, 0.16), p(0.50, 0.84), accent, dashed: false)
            terminal(context, p(0.50, 0.16), "H")
            terminal(context, p(0.50, 0.50), "Tap")
            terminal(context, p(0.50, 0.84), "Common")
        }
    }

    private func coil(_ context: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ color: Color, dashed: Bool) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(1, hypot(dx, dy))
        let ux = dx / len
        let uy = dy / len
        let px = -uy
        let py = ux
        let n = max(4, Int(len / 14))
        var path = Path()
        path.move(to: a)
        let step = len / CGFloat(n)
        for i in 0..<n {
            let sx = a.x + ux * step * CGFloat(i)
            let sy = a.y + uy * step * CGFloat(i)
            let mx = sx + ux * step * 0.5 + px * 7
            let my = sy + uy * step * 0.5 + py * 7
            let ex = a.x + ux * step * CGFloat(i + 1)
            let ey = a.y + uy * step * CGFloat(i + 1)
            path.addQuadCurve(to: CGPoint(x: ex, y: ey), control: CGPoint(x: mx, y: my))
        }
        if dashed {
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
        } else {
            context.stroke(path, with: .color(color), lineWidth: 2)
        }
    }

    private func terminal(_ context: GraphicsContext, _ point: CGPoint, _ name: String) {
        let dot = Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7))
        context.fill(dot, with: .color(Theme.surface))
        context.stroke(dot, with: .color(Theme.foreground), lineWidth: 1)
        context.draw(Text(name).font(.caption2).foregroundColor(Theme.foreground), at: CGPoint(x: point.x + 12, y: point.y - 8), anchor: .leading)
    }

    private func ground(_ context: GraphicsContext, _ point: CGPoint) {
        var path = Path()
        path.move(to: point)
        path.addLine(to: CGPoint(x: point.x, y: point.y + 10))
        path.move(to: CGPoint(x: point.x - 8, y: point.y + 10))
        path.addLine(to: CGPoint(x: point.x + 8, y: point.y + 10))
        path.move(to: CGPoint(x: point.x - 5, y: point.y + 14))
        path.addLine(to: CGPoint(x: point.x + 5, y: point.y + 14))
        context.stroke(path, with: .color(Theme.good), lineWidth: 1.3)
    }

    private func drawPhasors(context: GraphicsContext, size: CGSize) {
        let frame = CGRect(x: 8, y: 4, width: size.width - 16, height: size.height - 8)
        context.stroke(Path(roundedRect: frame, cornerRadius: 8), with: .color(Theme.border), lineWidth: 1)
        context.draw(Text("Secondary phasors").font(.caption2).foregroundColor(Theme.muted), at: CGPoint(x: frame.minX + 58, y: frame.minY + 12))
        let center = CGPoint(x: frame.midX, y: frame.midY + 8)
        let radius = min(frame.width, frame.height) * 0.32
        func tip(_ deg: Double, _ mag: Double) -> CGPoint {
            let r = deg * .pi / 180
            return CGPoint(x: center.x + CGFloat(cos(r) * mag) * radius, y: center.y - CGFloat(sin(r) * mag) * radius)
        }
        switch connection {
        case .highLeg:
            let n = center
            let a = tip(180, 0.55)
            let c = tip(0, 0.55)
            let b = tip(90, 0.95)
            vector(context, n, a, Color(red: 0.16, green: 0.16, blue: 0.16), "A")
            vector(context, n, c, Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255), "C")
            vector(context, n, b, Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255), "B")
        case .cornerGrounded:
            let a = center
            let b = tip(0, 1)
            let c = tip(60, 1)
            vector(context, a, b, is480 ? Color(red: 124 / 255, green: 74 / 255, blue: 30 / 255) : Color(red: 0.16, green: 0.16, blue: 0.16), "to ground")
            vector(context, a, c, is480 ? Color(red: 234 / 255, green: 179 / 255, blue: 8 / 255) : Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255), "to ground")
            context.draw(Text("0 V").font(.caption2).foregroundColor(Theme.foreground), at: CGPoint(x: a.x, y: a.y + 14))
        default:
            let colors = leads.filter { $0.name != "EGC" && $0.name != "N" && $0.name != "Grounded phase" }
            let angles = [90.0, 210.0, 330.0]
            for index in 0..<min(3, colors.count) {
                vector(context, center, tip(angles[index], 1), colors[index].color, colors[index].name)
            }
            if connection != .deltaDelta && connection != .openDelta && connection != .wyeDelta && connection != .ungroundedDelta {
                let dot = Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
                context.fill(dot, with: .color(Color(red: 0.96, green: 0.96, blue: 0.96)))
            }
        }
    }

    private func vector(_ context: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ color: Color, _ name: String) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        let dot = Path(ellipseIn: CGRect(x: b.x - 3.5, y: b.y - 3.5, width: 7, height: 7))
        context.fill(dot, with: .color(color))
        context.draw(Text(name).font(.caption2).foregroundColor(Theme.foreground), at: CGPoint(x: b.x + 8, y: b.y - 8), anchor: .leading)
    }
}
