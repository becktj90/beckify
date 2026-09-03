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
    @StoredToggle(.transformer, "continuous", default: true) private var continuous
    @StoredInput(.transformer, "jobName", default: "Transformer") private var jobName
    @State private var session = ExplicitCalculationState<TransformerSizingResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(system)|\(loadKind)|\(load)|\(pf)|\(vp)|\(vs)|\(continuous)"
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
                meaning: "Standard kVA is the next catalog rating at or above the design kVA. Note 1 allows the next standard OCPD size up only on 125% rows. 167% and 300% are ceilings.",
                citation: "NEC 450.3(B) for transformers 1000 V or less, including Note 1."
            )
            Picker("System", selection: $system) {
                Text("1Ø").tag(ElectricalSystem.singlePhase)
                Text("3Ø").tag(ElectricalSystem.threePhase)
            }
            .pickerStyle(.segmented)
            Picker("Load", selection: $loadKind) {
                ForEach(LoadKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            NumberField(title: "Connected load", unit: loadKind.rawValue, text: $load, fieldID: "load", onSubmit: calculate)
            if loadKind == .kw {
                NumberField(title: "Power factor", unit: "%", text: $pf, fieldID: "pf", onSubmit: calculate)
            }
            NumberField(title: "Primary voltage", unit: "V", text: $vp, fieldID: "vp", onSubmit: calculate)
            NumberField(title: "Secondary voltage", unit: "V", text: $vs, fieldID: "vs", onSubmit: calculate)
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
                    continuous = true
                    session.prepareForNewInputs()
                },
                exampleTitle: "38 kW, 480/208 V 3Ø, PF 90%"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
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
            return try TransformerSizing.size(
                system: system == .dc ? .threePhase : system,
                load: kind,
                primaryVolts: vp.parsedDouble ?? .nan,
                secondaryVolts: vs.parsedDouble ?? .nan,
                continuous: continuous
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
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        let v = Format.number(vp.parsedDouble ?? .nan, digits: 1)
        if system == .threePhase {
            return "Ip = \(Format.number(r.selectedKVA, digits: 1)) × 1000 ÷ (√3 × \(v)) = \(Format.amps(r.primaryFLA))"
        }
        return "Ip = \(Format.number(r.selectedKVA, digits: 1)) × 1000 ÷ \(v) = \(Format.amps(r.primaryFLA))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.selectedKVA, digits: 1)) kVA  ·  Ip \(Format.amps(r.primaryFLA))  ·  Is \(Format.amps(r.secondaryFLA))"
    }

    private var copyText: String? { sticky }
}
