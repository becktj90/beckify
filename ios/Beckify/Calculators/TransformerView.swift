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
    @State private var system: ElectricalSystem = .threePhase
    @State private var loadKind: LoadKind = .kw
    @State private var load = "38"
    @State private var pf = "90"
    @State private var vp = "480"
    @State private var vs = "208"
    @State private var continuous = true
    @State private var jobName = "Transformer"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "I = kVA × 1000 ÷ (√3 × V)    OCPD per 450.3(B)",
                    citation: "Note 1 allows the next standard size up only on 125% rows. 167% and 300% are ceilings."
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

                NumberField(title: "Connected load", unit: loadKind.rawValue, text: $load)
                if loadKind == .kw {
                    NumberField(title: "Power factor", unit: "%", text: $pf)
                }
                NumberField(title: "Primary voltage", unit: "V", text: $vp)
                NumberField(title: "Secondary voltage", unit: "V", text: $vs)
                Toggle("Continuous load (size at 125%)", isOn: $continuous)
                    .tint(Theme.accent)

                switch calc {
                case .success(let r):
                    ResultCard(title: "Transformer") {
                        ResultRow(label: "Connected", value: "\(Format.number(r.loadKVA, digits: 2)) kVA")
                        ResultRow(label: "Design", value: "\(Format.number(r.designKVA, digits: 2)) kVA")
                        ResultRow(label: "Standard rating", value: "\(Format.number(r.selectedKVA, digits: 1)) kVA", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Primary FLA", value: Format.amps(r.primaryFLA), emphasis: true)
                        ResultRow(label: "Secondary FLA", value: Format.amps(r.secondaryFLA), emphasis: true)
                        ResultRow(label: "Turns ratio", value: "\(Format.number(r.turnsRatio, digits: 3)) : 1")
                    }
                    ResultCard(title: "Method 1 — primary only") {
                        ocpdRows(r.primaryOnly)
                    }
                    ResultCard(title: "Method 2 — primary + secondary") {
                        ResultRow(label: "Primary 250%", value: device(r.primaryWithSecondary), emphasis: true)
                        ocpdRows(r.secondaryProtection)
                    }
                    ResultCard(title: "Conductor minimum") {
                        ResultRow(label: "Primary 125%", value: Format.amps(r.primaryConductorMinAmps))
                        ResultRow(label: "Secondary 125%", value: Format.amps(r.secondaryConductorMinAmps))
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) {
                        jobs.save(SavedJob(
                            name: jobName,
                            toolID: .transformer,
                            inputs: [
                                "system": system.displayName,
                                "loadKind": loadKind.rawValue,
                                "load": load,
                                "pf": pf,
                                "vp": vp,
                                "vs": vs,
                                "continuous": continuous ? "yes" : "no",
                            ],
                            outputs: ["kVA": "\(r.selectedKVA)", "Ip": Format.amps(r.primaryFLA), "Is": Format.amps(r.secondaryFLA)]
                        ))
                    }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Transformer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if system == .dc { system = .threePhase }
        }
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

    private var calc: Result<TransformerSizingResult, CalcError> {
        do {
            let kind: TransformerLoad
            switch loadKind {
            case .kva: kind = .kVA(load.parsedDouble ?? .nan)
            case .kw: kind = .kW(load.parsedDouble ?? .nan, powerFactor: (pf.parsedDouble ?? .nan) / 100)
            case .amps: kind = .amps(load.parsedDouble ?? .nan)
            }
            return .success(try TransformerSizing.size(
                system: system == .dc ? .threePhase : system,
                load: kind,
                primaryVolts: vp.parsedDouble ?? .nan,
                secondaryVolts: vs.parsedDouble ?? .nan,
                continuous: continuous
            ))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }
}
