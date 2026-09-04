import SwiftUI
import BeckifyMath

// MARK: - Shared analog formatting

private enum AnalogFormat {
    static func ohms(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if abs(value) >= 1e6 { return "\(Format.number(value / 1e6, digits: 3)) MΩ" }
        if abs(value) >= 1e3 { return "\(Format.number(value / 1e3, digits: 3)) kΩ" }
        return "\(Format.number(value, digits: 3)) Ω"
    }

    static func farads(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "—" }
        if value >= 1e-3 { return "\(Format.number(value * 1e3, digits: 3)) mF" }
        if value >= 1e-6 { return "\(Format.number(value * 1e6, digits: 3)) µF" }
        if value >= 1e-9 { return "\(Format.number(value * 1e9, digits: 3)) nF" }
        return "\(Format.number(value * 1e12, digits: 3)) pF"
    }

    static func voltsPerVolt(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return "\(Format.number(value, digits: 3)) V/V"
    }

    static func rms(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let absv = abs(value)
        if absv >= 1 { return "\(Format.number(value, digits: 3)) Vrms" }
        if absv >= 1e-3 { return "\(Format.number(value * 1e3, digits: 3)) mVrms" }
        if absv >= 1e-6 { return "\(Format.number(value * 1e6, digits: 3)) µVrms" }
        return "\(Format.number(value * 1e9, digits: 3)) nVrms"
    }
}

private struct BodeMagnitudeChart: View {
    let points: [PlotPoint]
    let cornerHz: Double

    private var summary: String {
        "Ideal magnitude Bode sketch, log frequency. Corner \(Format.frequency(cornerHz)). Not a measured network-analyzer plot."
    }

    var body: some View {
        DiagramCard(title: "Magnitude Bode", accessibilitySummary: summary, exportName: "analog-bode") {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "|H|", points: points, color: Theme.chartPrimary, fills: true),
                ],
                xLabel: "Hz",
                yLabel: "dB",
                xGuides: [
                    EngineerGuide(value: cornerHz, label: "fc", axis: .x),
                ],
                yGuides: [
                    EngineerGuide(value: -3, label: "−3 dB", axis: .y),
                ],
                logX: true,
                height: 220
            )
        }
    }
}

// MARK: - Analog Design Workbench

struct AnalogDesignWorkbenchView: View {
    enum Panel: String, CaseIterable, Identifiable {
        case stages = "Op-amp stages"
        case filters = "Filters"
        var id: String { rawValue }
    }

    private enum Output: Equatable {
        case stage(OpAmpStageResult)
        case filter(AnalogFilterResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.analogWorkbench, "panel", default: Panel.stages) private var panel
    @StoredChoice(.analogWorkbench, "topology", default: OpAmpTopology.inverting) private var topology
    @StoredChoice(.analogWorkbench, "filter", default: AnalogFilterFamily.sallenKeyLowpass) private var filter
    @StoredToggle(.analogWorkbench, "e24", default: true) private var nearestE24
    @StoredInput(.analogWorkbench, "vin", default: "1") private var vin
    @StoredInput(.analogWorkbench, "v1", default: "1") private var v1
    @StoredInput(.analogWorkbench, "v2", default: "2") private var v2
    @StoredInput(.analogWorkbench, "rin", default: "10000") private var rin
    @StoredInput(.analogWorkbench, "rf", default: "47000") private var rf
    @StoredInput(.analogWorkbench, "rg", default: "10000") private var rg
    @StoredInput(.analogWorkbench, "r1", default: "10000") private var r1
    @StoredInput(.analogWorkbench, "r2", default: "10000") private var r2
    @StoredInput(.analogWorkbench, "capNF", default: "100") private var capNF
    @StoredInput(.analogWorkbench, "freq", default: "1000") private var frequency
    @StoredInput(.analogWorkbench, "filterR", default: "10000") private var filterR
    @StoredInput(.analogWorkbench, "filterCNF", default: "15.9") private var filterCNF
    @StoredInput(.analogWorkbench, "filterGain", default: "1") private var filterGain
    @StoredInput(.analogWorkbench, "filterQ", default: "0.707") private var filterQ
    @StoredInput(.analogWorkbench, "jobName", default: "Analog workbench") private var jobName
    @State private var session = ExplicitCalculationState<Output>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var capFarads: Double { (capNF.parsedDouble ?? .nan) * 1e-9 }
    private var filterFarads: Double { (filterCNF.parsedDouble ?? .nan) * 1e-9 }

    private var inputFingerprint: String {
        "\(panel)|\(topology)|\(filter)|\(nearestE24)|\(vin)|\(v1)|\(v2)|\(rin)|\(rf)|\(rg)|\(r1)|\(r2)|\(capNF)|\(frequency)|\(filterR)|\(filterCNF)|\(filterGain)|\(filterQ)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .analogWorkbench,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Ideal op-amp golden rules and textbook filter magnitude only — not a SPICE run, not layout parasitics, not a measured Bode plot."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .analogWorkbench,
                symbolic: symbolic,
                substituted: substituted,
                meaning: meaning
            )

            Picker("Panel", selection: $panel) {
                ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if panel == .stages {
                stagesFields
            } else {
                filterFields
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: loadExample,
                exampleTitle: exampleTitle
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                if case .filter(let r) = output, !r.bode.isEmpty {
                    BodeMagnitudeChart(points: r.bode, cornerHz: r.cornerHz)
                        .opacity(session.isStale ? 0.72 : 1)
                }
                ResultCard(copyText: sticky) { rows(for: output) }
                    .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(output) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    @ViewBuilder
    private var stagesFields: some View {
        MenuField(title: "Stage", selection: $topology, options: OpAmpTopology.allCases) { $0.displayName }
        Toggle("Nearest E24 resistors", isOn: $nearestE24)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)

        switch topology {
        case .inverting:
            NumberField(title: "Vin", unit: "V", text: $vin, fieldID: "vin", onSubmit: calculate)
            NumberField(title: "Rin", unit: "Ω", text: $rin, fieldID: "rin", onSubmit: calculate)
            NumberField(title: "Rf", unit: "Ω", text: $rf, fieldID: "rf", onSubmit: calculate)
        case .noninverting:
            NumberField(title: "Vin", unit: "V", text: $vin, fieldID: "vin", onSubmit: calculate)
            NumberField(title: "Rg (to GND)", unit: "Ω", text: $rg, fieldID: "rg", onSubmit: calculate)
            NumberField(title: "Rf", unit: "Ω", text: $rf, fieldID: "rf", onSubmit: calculate)
        case .follower:
            NumberField(title: "Vin", unit: "V", text: $vin, fieldID: "vin", onSubmit: calculate)
        case .difference:
            NumberField(title: "V2 (non-inverting)", unit: "V", text: $v2, fieldID: "v2", onSubmit: calculate)
            NumberField(title: "V1 (inverting)", unit: "V", text: $v1, fieldID: "v1", onSubmit: calculate)
            NumberField(title: "Rin", unit: "Ω", text: $rin, fieldID: "rin", onSubmit: calculate)
            NumberField(title: "Rf (matched pair)", unit: "Ω", text: $rf, fieldID: "rf", onSubmit: calculate)
        case .summing:
            NumberField(title: "V1", unit: "V", text: $v1, fieldID: "v1", onSubmit: calculate)
            NumberField(title: "R1", unit: "Ω", text: $r1, fieldID: "r1", onSubmit: calculate)
            NumberField(title: "V2", unit: "V", text: $v2, fieldID: "v2", onSubmit: calculate)
            NumberField(title: "R2", unit: "Ω", text: $r2, fieldID: "r2", onSubmit: calculate)
            NumberField(title: "Rf", unit: "Ω", text: $rf, fieldID: "rf", onSubmit: calculate)
        case .integrator:
            NumberField(title: "Vin (step)", unit: "V", text: $vin, fieldID: "vin", onSubmit: calculate)
            NumberField(title: "Rin", unit: "Ω", text: $rin, fieldID: "rin", onSubmit: calculate)
            NumberField(title: "Feedback C", unit: "nF", text: $capNF, fieldID: "cap", onSubmit: calculate)
        case .differentiator:
            NumberField(title: "Vin amplitude", unit: "V", text: $vin, fieldID: "vin", onSubmit: calculate)
            NumberField(title: "Input C", unit: "nF", text: $capNF, fieldID: "cap", onSubmit: calculate)
            NumberField(title: "Rf", unit: "Ω", text: $rf, fieldID: "rf", onSubmit: calculate)
            NumberField(title: "Frequency", unit: "Hz", text: $frequency, fieldID: "freq", onSubmit: calculate)
        }
    }

    @ViewBuilder
    private var filterFields: some View {
        MenuField(title: "Family", selection: $filter, options: AnalogFilterFamily.allCases) { $0.displayName }
        NumberField(title: "Design / center frequency", unit: "Hz", text: $frequency, fieldID: "f0", onSubmit: calculate)
        NumberField(title: "Reference R", unit: "Ω", text: $filterR, fieldID: "filterR", onSubmit: calculate)
        NumberField(title: "Reference C", unit: "nF", text: $filterCNF, helpText: "Used for 1st-order fc. 2nd-order families size C from R and the design frequency.", fieldID: "filterC", onSubmit: calculate)
        NumberField(title: "Passband gain", unit: "V/V", text: $filterGain, fieldID: "gain", onSubmit: calculate)
        if filter == .sallenKeyLowpass || filter == .sallenKeyHighpass || filter == .twinTNotch {
            NumberField(title: "Q", unit: "", text: $filterQ, helpText: "0.707 is Butterworth for Sallen–Key. Twin-T passive notch is much shallower unless you raise Q.", fieldID: "q", onSubmit: calculate)
        }
    }

    @ViewBuilder
    private func rows(for output: Output) -> some View {
        switch output {
        case .stage(let r):
            if r.gainVV.isFinite {
                ResultRow(label: "Gain", value: AnalogFormat.voltsPerVolt(r.gainVV), emphasis: true, tone: Theme.good)
            }
            if r.outputVolts.isFinite {
                ResultRow(label: "Vout", value: Format.volts(r.outputVolts), emphasis: r.gainVV.isNaN, tone: Theme.good)
            }
            if let tau = r.timeConstantSeconds {
                ResultRow(label: "τ = RC", value: Format.time(tau))
            }
            if let slope = r.slopeVoltsPerSecond {
                ResultRow(label: "Output slope", value: "\(Format.number(slope, digits: 3)) V/s")
            }
            if let f = r.unityGainHz {
                ResultRow(label: "Unity-gain f", value: Format.frequency(f))
            }
            ForEach(r.resistorPicks, id: \.name) { pick in
                ResultRow(label: "\(pick.name) E24", value: AnalogFormat.ohms(pick.nearest))
            }
        case .filter(let r):
            ResultRow(label: "Family", value: r.family.displayName)
            ResultRow(label: "fc / f0", value: Format.frequency(r.cornerHz), emphasis: true, tone: Theme.good)
            ResultRow(label: "Q", value: Format.number(r.qualityFactor, digits: 3))
            ResultRow(label: "Passband gain", value: AnalogFormat.voltsPerVolt(r.passbandGainVV))
            if let k = r.sallenKeyK {
                ResultRow(label: "Sallen–Key K", value: Format.number(k, digits: 3))
            }
            ResultRow(label: "C for design f (this R)", value: AnalogFormat.farads(r.suggestedCapacitance))
        }
    }

    private func calculate() {
        session.calculate {
            switch panel {
            case .stages:
                return .stage(try stageResult())
            case .filters:
                return .filter(try AnalogFilter.solve(
                    family: filter,
                    designFrequency: frequency.parsedDouble ?? .nan,
                    resistance: filterR.parsedDouble ?? .nan,
                    capacitance: filterFarads,
                    passbandGain: filterGain.parsedDouble ?? .nan,
                    quality: filterQ.parsedDouble ?? .nan
                ))
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func stageResult() throws -> OpAmpStageResult {
        switch topology {
        case .inverting:
            return try OpAmpGolden.inverting(vin: vin.parsedDouble ?? .nan, rin: rin.parsedDouble ?? .nan, rf: rf.parsedDouble ?? .nan, nearestE24: nearestE24)
        case .noninverting:
            return try OpAmpGolden.noninverting(vin: vin.parsedDouble ?? .nan, rg: rg.parsedDouble ?? .nan, rf: rf.parsedDouble ?? .nan, nearestE24: nearestE24)
        case .follower:
            return try OpAmpGolden.follower(vin: vin.parsedDouble ?? .nan)
        case .difference:
            return try OpAmpGolden.difference(v1: v1.parsedDouble ?? .nan, v2: v2.parsedDouble ?? .nan, rin: rin.parsedDouble ?? .nan, rf: rf.parsedDouble ?? .nan, nearestE24: nearestE24)
        case .summing:
            return try OpAmpGolden.summing(v1: v1.parsedDouble ?? .nan, r1: r1.parsedDouble ?? .nan, v2: v2.parsedDouble ?? .nan, r2: r2.parsedDouble ?? .nan, rf: rf.parsedDouble ?? .nan, nearestE24: nearestE24)
        case .integrator:
            return try OpAmpGolden.integrator(vin: vin.parsedDouble ?? .nan, rin: rin.parsedDouble ?? .nan, capacitance: capFarads, nearestE24: nearestE24)
        case .differentiator:
            return try OpAmpGolden.differentiator(vin: vin.parsedDouble ?? .nan, capacitance: capFarads, rf: rf.parsedDouble ?? .nan, frequency: frequency.parsedDouble ?? .nan, nearestE24: nearestE24)
        }
    }

    private func reset() {
        vin = ""; v1 = ""; v2 = ""; rin = ""; rf = ""; rg = ""; r1 = ""; r2 = ""
        capNF = ""; frequency = ""; filterR = ""; filterCNF = ""; filterGain = ""; filterQ = ""
        session.reset()
    }

    private func loadExample() {
        if panel == .stages {
            topology = .inverting
            vin = "1"; rin = "10000"; rf = "47000"
        } else {
            filter = .sallenKeyLowpass
            frequency = "1000"; filterR = "10000"; filterCNF = "15.9"; filterGain = "1"; filterQ = "0.707"
        }
        session.prepareForNewInputs()
    }

    private var exampleTitle: String {
        panel == .stages ? "Inverting ×−4.7" : "1 kHz Butterworth Sallen–Key"
    }

    private var symbolic: String {
        if panel == .filters {
            return AnalogFilter.symbolicFormula(for: filter)
        }
        switch topology {
        case .inverting: return "Vout = −(Rf / Rin) · Vin"
        case .noninverting: return "Vout = (1 + Rf / Rg) · Vin"
        case .follower: return "Vout = Vin"
        case .difference: return "Vout = (Rf / Rin) · (V2 − V1)"
        case .summing: return "Vout = −Rf · (V1/R1 + V2/R2)"
        case .integrator: return "Vout = −(1/RC) ∫ Vin dt"
        case .differentiator: return "|H| = 2π f Rf C"
        }
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .stage(let r):
            if r.outputVolts.isFinite, r.gainVV.isFinite {
                return "\(Format.volts(r.outputVolts)) = \(AnalogFormat.voltsPerVolt(r.gainVV)) × Vin"
            }
            if let tau = r.timeConstantSeconds, let slope = r.slopeVoltsPerSecond {
                return "τ = \(Format.time(tau))    slope = \(Format.number(slope, digits: 3)) V/s"
            }
            return r.formula
        case .filter(let r):
            return "fc = \(Format.frequency(r.cornerHz))    Q = \(Format.number(r.qualityFactor, digits: 3))"
        }
    }

    private var meaning: String {
        panel == .filters
            ? "The Bode sketch is the ideal transfer-function magnitude on a log-f axis. Use it to compare families, then check the real op-amp GBW and component tolerances."
            : "Ideal op-amp: the inputs stay at the same voltage and draw no current. Real parts have offset, finite GBW, and output swing — this tool does not model those."
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .stage(let r):
            if r.outputVolts.isFinite { return "Vout \(Format.volts(r.outputVolts))" }
            if let f = r.unityGainHz { return "f_unity \(Format.frequency(f))" }
            return r.topology.displayName
        case .filter(let r):
            return "\(r.family.displayName)  ·  \(Format.frequency(r.cornerHz))"
        }
    }

    private func save(_ output: Output) {
        var outputs: [String: String] = [:]
        switch output {
        case .stage(let r):
            outputs["gain"] = AnalogFormat.voltsPerVolt(r.gainVV)
            outputs["Vout"] = Format.volts(r.outputVolts)
        case .filter(let r):
            outputs["fc"] = Format.frequency(r.cornerHz)
            outputs["Q"] = Format.number(r.qualityFactor, digits: 3)
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .analogWorkbench,
            inputs: ["panel": panel.rawValue, "stage": topology.rawValue, "filter": filter.rawValue],
            outputs: outputs
        ))
    }
}

// MARK: - Noise & SNR

struct NoiseSNRView: View {
    enum BandwidthKind: String, CaseIterable, Identifiable {
        case brickWall = "Hz (already noise BW)"
        case firstOrder = "3 dB BW × π/2"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.noiseSNR, "bwKind", default: BandwidthKind.brickWall) private var bwKind
    @StoredInput(.noiseSNR, "resistance", default: "10000") private var resistance
    @StoredInput(.noiseSNR, "temperature", default: "290") private var temperature
    @StoredInput(.noiseSNR, "bandwidth", default: "10000") private var bandwidth
    @StoredInput(.noiseSNR, "en", default: "5") private var enNV
    @StoredInput(.noiseSNR, "in", default: "1") private var inPA
    @StoredInput(.noiseSNR, "shot", default: "") private var shotMA
    @StoredInput(.noiseSNR, "signal", default: "1") private var signalMV
    @StoredToggle(.noiseSNR, "includeShot", default: false) private var includeShot
    @StoredToggle(.noiseSNR, "includeSNR", default: true) private var includeSNR
    @StoredInput(.noiseSNR, "jobName", default: "Noise SNR") private var jobName
    @State private var session = ExplicitCalculationState<NoiseSNRResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(bwKind)|\(resistance)|\(temperature)|\(bandwidth)|\(enNV)|\(inPA)|\(shotMA)|\(signalMV)|\(includeShot)|\(includeSNR)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .noiseSNR,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Spot / brick-wall input-referred estimate. Not a SPICE .noise run and not a measured spectrum."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .noiseSNR,
                symbolic: "vn = √(4kTRB)    in,shot = √(2qIB)    vn,tot = √(Σ v²)    SNR = 20 log10(Vsig / vn,tot)",
                substituted: substituted,
                meaning: "Johnson noise is the resistor. Shot is optional diode/bias current. Amplifier e_n and i_n are datasheet densities, assumed white across B. NF here is just 10 log10(v_tot² / v_thermal²)."
            )

            MenuField(title: "Bandwidth meaning", selection: $bwKind, options: BandwidthKind.allCases) { $0.rawValue }
            NumberField(title: "Source resistance", unit: "Ω", text: $resistance, fieldID: "r", onSubmit: calculate)
            NumberField(title: "Temperature", unit: "K", text: $temperature, fieldID: "t", onSubmit: calculate)
            NumberField(title: bwKind == .brickWall ? "Noise bandwidth" : "3 dB bandwidth", unit: "Hz", text: $bandwidth, fieldID: "b", onSubmit: calculate)
            NumberField(title: "Amp e_n", unit: "nV/√Hz", text: $enNV, fieldID: "en", onSubmit: calculate)
            NumberField(title: "Amp i_n", unit: "pA/√Hz", text: $inPA, fieldID: "in", onSubmit: calculate)
            Toggle("Include shot noise", isOn: $includeShot)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            if includeShot {
                NumberField(title: "Bias / diode current", unit: "mA", text: $shotMA, fieldID: "shot", onSubmit: calculate)
            }
            Toggle("Compute SNR from signal", isOn: $includeSNR)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            if includeSNR {
                NumberField(title: "Signal amplitude (RMS)", unit: "mVrms", text: $signalMV, fieldID: "sig", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    resistance = "10000"; temperature = "290"; bandwidth = "10000"
                    enNV = "5"; inPA = "1"; includeShot = false; includeSNR = true; signalMV = "1"
                    bwKind = .brickWall
                    session.prepareForNewInputs()
                },
                exampleTitle: "10 kΩ, 10 kHz, 5 nV/√Hz"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Noise BW", value: Format.frequency(r.noiseBandwidthHz))
                    ResultRow(label: "Johnson vn", value: AnalogFormat.rms(r.johnsonVrms))
                    ResultRow(label: "Amp e_n · √B", value: AnalogFormat.rms(r.ampVoltageVrms))
                    ResultRow(label: "Amp i_n R · √B", value: AnalogFormat.rms(r.ampCurrentVrms))
                    if r.shotIrms > 0 {
                        ResultRow(label: "Shot in", value: "\(Format.number(r.shotIrms * 1e12, digits: 3)) pArms")
                        ResultRow(label: "Shot through R", value: AnalogFormat.rms(r.shotVrms))
                    }
                    ResultRow(label: "Total referred", value: AnalogFormat.rms(r.totalReferredVrms), emphasis: true, tone: Theme.good)
                    if let snr = r.snrDB {
                        ResultRow(label: "SNR", value: "\(Format.number(snr, digits: 2)) dB", emphasis: true)
                    }
                    if let nf = r.noiseFigureDB {
                        ResultRow(label: "Rough NF", value: "\(Format.number(nf, digits: 2)) dB")
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            let hz = bandwidth.parsedDouble ?? .nan
            let factor = bwKind == .firstOrder ? NoiseSNR.firstOrderNoiseBandwidthFactor : 1
            let b = try NoiseSNR.noiseBandwidth(hz3dB: hz, factor: factor)
            let shot: Double? = includeShot ? (shotMA.parsedDouble ?? .nan) * 1e-3 : nil
            let signal: Double? = includeSNR ? (signalMV.parsedDouble ?? .nan) * 1e-3 : nil
            return try NoiseSNR.solve(
                resistance: resistance.parsedDouble ?? .nan,
                temperatureKelvin: temperature.parsedDouble ?? .nan,
                bandwidthHz: b,
                ampEn: (enNV.parsedDouble ?? .nan) * 1e-9,
                ampIn: (inPA.parsedDouble ?? .nan) * 1e-12,
                shotCurrent: shot,
                signalVrms: signal
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        resistance = ""; temperature = ""; bandwidth = ""; enNV = ""; inPA = ""; shotMA = ""; signalMV = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        var parts = [
            "√(4kTRB) = \(AnalogFormat.rms(r.johnsonVrms))",
            "vn,tot = \(AnalogFormat.rms(r.totalReferredVrms))",
        ]
        if let snr = r.snrDB {
            parts.append("SNR = \(Format.number(snr, digits: 2)) dB")
        }
        return parts.joined(separator: "    ")
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        if let snr = r.snrDB {
            return "\(AnalogFormat.rms(r.totalReferredVrms))  ·  SNR \(Format.number(snr, digits: 1)) dB"
        }
        return AnalogFormat.rms(r.totalReferredVrms)
    }

    private func save(_ r: NoiseSNRResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .noiseSNR,
            inputs: ["R": resistance, "T": temperature, "B": bandwidth, "en": enNV, "in": inPA],
            outputs: [
                "vn,tot": AnalogFormat.rms(r.totalReferredVrms),
                "SNR": r.snrDB.map { "\(Format.number($0, digits: 2)) dB" } ?? "—",
            ]
        ))
    }
}

// MARK: - Linear / LDO regulator + thermal

struct LinearRegulatorView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case fromResistors = "R1 / R2 → Vout"
        case solveR2 = "Target Vout → R2"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.linearRegulator, "mode", default: Mode.fromResistors) private var mode
    @StoredInput(.linearRegulator, "vin", default: "12") private var vin
    @StoredInput(.linearRegulator, "vout", default: "5") private var vout
    @StoredInput(.linearRegulator, "r1", default: "240") private var r1
    @StoredInput(.linearRegulator, "r2", default: "720") private var r2
    @StoredInput(.linearRegulator, "vref", default: "1.25") private var vref
    @StoredInput(.linearRegulator, "iadj", default: "50") private var iadjUA
    @StoredInput(.linearRegulator, "dropout", default: "2") private var dropout
    @StoredInput(.linearRegulator, "load", default: "0.5") private var load
    @StoredInput(.linearRegulator, "ambient", default: "25") private var ambient
    @StoredInput(.linearRegulator, "thja", default: "50") private var thetaJA
    @StoredInput(.linearRegulator, "thjc", default: "5") private var thetaJC
    @StoredInput(.linearRegulator, "thsa", default: "") private var thetaSA
    @StoredInput(.linearRegulator, "jobName", default: "Linear regulator") private var jobName
    @State private var session = ExplicitCalculationState<LinearRegulatorResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(vin)|\(vout)|\(r1)|\(r2)|\(vref)|\(iadjUA)|\(dropout)|\(load)|\(ambient)|\(thetaJA)|\(thetaJC)|\(thetaSA)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .linearRegulator,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Linear / LDO thermal estimate only — not a switch-mode converter design, and Tj is not a measured case temperature."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .linearRegulator,
                symbolic: "Vout = Vref(1 + R2/R1) + Iadj·R2    Pd = (Vin − Vout)·I    Tj = Ta + Pd·θJA",
                substituted: substituted,
                meaning: "An LM317-style adjustable regulator (or a generic LDO with the same divider math). Headroom below the dropout you typed will not regulate. Junction above ~125 °C is an AoE-style silicon warning, not the part’s datasheet limit."
            )

            MenuField(title: "Solve", selection: $mode, options: Mode.allCases) { $0.rawValue }
            NumberField(title: "Vin", unit: "V", text: $vin, fieldID: "vin", onSubmit: calculate)
            if mode == .solveR2 {
                NumberField(title: "Target Vout", unit: "V", text: $vout, fieldID: "vout", onSubmit: calculate)
            }
            NumberField(title: "R1", unit: "Ω", text: $r1, helpText: "LM317 datasheets often start at 240 Ω between OUT and ADJ.", fieldID: "r1", onSubmit: calculate)
            if mode == .fromResistors {
                NumberField(title: "R2", unit: "Ω", text: $r2, fieldID: "r2", onSubmit: calculate)
            }
            NumberField(title: "Vref", unit: "V", text: $vref, fieldID: "vref", onSubmit: calculate)
            NumberField(title: "Iadj", unit: "µA", text: $iadjUA, helpText: "Typical 50 µA. Enter 0 to ignore.", fieldID: "iadj", onSubmit: calculate)
            NumberField(title: "Dropout / minimum headroom", unit: "V", text: $dropout, fieldID: "do", onSubmit: calculate)
            NumberField(title: "Load current", unit: "A", text: $load, fieldID: "i", onSubmit: calculate)
            NumberField(title: "Ambient", unit: "°C", text: $ambient, fieldID: "ta", onSubmit: calculate)
            NumberField(title: "Package θJA (free air)", unit: "°C/W", text: $thetaJA, fieldID: "thja", onSubmit: calculate)
            NumberField(title: "Heatsink θSA", unit: "°C/W", text: $thetaSA, optional: true, helpText: "If set, Tj uses θJC + θSA instead of free-air θJA.", fieldID: "thsa", onSubmit: calculate)
            if !thetaSA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NumberField(title: "θJC", unit: "°C/W", text: $thetaJC, fieldID: "thjc", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    mode = .fromResistors
                    vin = "12"; vout = "5"; r1 = "240"; r2 = "720"; vref = "1.25"; iadjUA = "50"
                    dropout = "2"; load = "0.5"; ambient = "25"; thetaJA = "50"; thetaSA = ""
                    session.prepareForNewInputs()
                },
                exampleTitle: "12 V → 5 V, 240/720 Ω, 0.5 A"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Vout", value: Format.volts(r.vout), emphasis: true, tone: Theme.good)
                    ResultRow(label: "R1", value: AnalogFormat.ohms(r.r1))
                    ResultRow(label: "R2", value: AnalogFormat.ohms(r.r2), emphasis: mode == .solveR2)
                    ResultRow(label: "R1 E24", value: AnalogFormat.ohms(r.r1NearestE24))
                    ResultRow(label: "R2 E24", value: AnalogFormat.ohms(r.r2NearestE24))
                    ResultRow(label: "Headroom Vin−Vout", value: Format.volts(r.headroom), tone: r.dropoutMargin < 0 ? Theme.bad : Theme.foreground)
                    ResultRow(label: "Dropout margin", value: Format.volts(r.dropoutMargin), tone: r.dropoutMargin < 0 ? Theme.bad : Theme.good)
                    ResultRow(label: "Pd", value: Format.watts(r.powerDissipation), emphasis: true)
                    ResultRow(label: "θ used", value: "\(Format.number(r.thetaJAUsed, digits: 2)) °C/W")
                    ResultRow(
                        label: "Tj estimate",
                        value: "\(Format.number(r.junctionC, digits: 1)) °C",
                        emphasis: true,
                        tone: r.junctionHigh ? Theme.bad : Theme.good
                    )
                    if r.dropoutMargin < 0 {
                        ResultRow(label: "Headroom", value: "Below dropout — will not regulate", tone: Theme.bad)
                    }
                    if r.junctionHigh {
                        ResultRow(label: "Thermal", value: "Tj ≥ 125 °C (AoE-style silicon warning)", tone: Theme.bad)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            let saText = thetaSA.trimmingCharacters(in: .whitespacesAndNewlines)
            let sa = saText.isEmpty ? nil : (thetaSA.parsedDouble ?? .nan)
            // θJC is only in play with a heatsink. Blank or junk must not become the solver default.
            let jc: Double? = saText.isEmpty ? nil : (thetaJC.parsedDouble ?? .nan)
            return try LinearRegulator.solve(
                vin: vin.parsedDouble ?? .nan,
                voutOrTarget: vout.parsedDouble ?? .nan,
                r1: r1.parsedDouble ?? .nan,
                r2: r2.parsedDouble,
                vref: vref.parsedDouble ?? .nan,
                iadj: (iadjUA.parsedDouble ?? .nan) * 1e-6,
                dropout: dropout.parsedDouble ?? .nan,
                loadCurrent: load.parsedDouble ?? .nan,
                ambientC: ambient.parsedDouble ?? .nan,
                thetaJA: thetaJA.parsedDouble ?? .nan,
                thetaJC: jc,
                thetaSA: sa,
                solveResistors: mode == .solveR2
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        vin = ""; vout = ""; r1 = ""; r2 = ""; vref = ""; iadjUA = ""
        dropout = ""; load = ""; ambient = ""; thetaJA = ""; thetaSA = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "Vout \(Format.volts(r.vout))    Pd \(Format.watts(r.powerDissipation))    Tj \(Format.number(r.junctionC, digits: 1)) °C"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "Vout \(Format.volts(r.vout))  ·  Pd \(Format.watts(r.powerDissipation))  ·  Tj \(Format.number(r.junctionC, digits: 0)) °C"
    }

    private func save(_ r: LinearRegulatorResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .linearRegulator,
            inputs: ["Vin": vin, "R1": r1, "R2": r2, "I": load],
            outputs: [
                "Vout": Format.volts(r.vout),
                "Pd": Format.watts(r.powerDissipation),
                "Tj": "\(Format.number(r.junctionC, digits: 1)) °C",
            ]
        ))
    }
}

// MARK: - Instrumentation / difference amp

struct InstrumentationAmpView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.instrumentationAmp, "mode", default: InAmpMode.threeOpAmp) private var mode
    @StoredInput(.instrumentationAmp, "v2", default: "2.05") private var v2
    @StoredInput(.instrumentationAmp, "v1", default: "2.00") private var v1
    @StoredInput(.instrumentationAmp, "r", default: "25000") private var r
    @StoredInput(.instrumentationAmp, "rg", default: "1000") private var rg
    @StoredInput(.instrumentationAmp, "vref", default: "0") private var vref
    @StoredInput(.instrumentationAmp, "railP", default: "5") private var railP
    @StoredInput(.instrumentationAmp, "railN", default: "0") private var railN
    @StoredInput(.instrumentationAmp, "cmMin", default: "0") private var cmMin
    @StoredInput(.instrumentationAmp, "cmMax", default: "4") private var cmMax
    @StoredInput(.instrumentationAmp, "jobName", default: "InAmp") private var jobName
    @State private var session = ExplicitCalculationState<InstrumentationAmpResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(v2)|\(v1)|\(r)|\(rg)|\(vref)|\(railP)|\(railN)|\(cmMin)|\(cmMax)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .instrumentationAmp,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Ideal resistor ratios and user-entered rails. Not a measured CMRR and not a SPICE common-mode sweep."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .instrumentationAmp,
                symbolic: mode == .threeOpAmp
                    ? "G = 1 + 2R / Rg    Vout = G·(V2 − V1) + Vref"
                    : "G = Rf / Rin    Vout = G·(V2 − V1) + Vref",
                substituted: substituted,
                meaning: mode == .threeOpAmp
                    ? "The first stage raises the difference before the subtractor, which is why CMRR is much less sensitive to the output-stage resistor match than a lone difference amp. This tool does not compute a numeric CMRR from tolerance — match the four output resistors if you care."
                    : "Four resistors, two ratios. CMRR collapses if Rf/Rin on one side does not match the other. 0.1 % parts are a common starting point; this is not a lab CMRR figure."
            )

            MenuField(title: "Topology", selection: $mode, options: InAmpMode.allCases) { $0.displayName }
            NumberField(title: "V2 (non-inverting / +in)", unit: "V", text: $v2, fieldID: "v2", onSubmit: calculate)
            NumberField(title: "V1 (inverting / −in)", unit: "V", text: $v1, fieldID: "v1", onSubmit: calculate)
            if mode == .threeOpAmp {
                NumberField(title: "R (each gain-leg resistor)", unit: "Ω", text: $r, helpText: "Classic form uses 2R in 1 + 2R/Rg. 25 kΩ → 50 kΩ / Rg.", fieldID: "r", onSubmit: calculate)
                NumberField(title: "Rg", unit: "Ω", text: $rg, fieldID: "rg", onSubmit: calculate)
            } else {
                NumberField(title: "Rf", unit: "Ω", text: $r, fieldID: "rf", onSubmit: calculate)
                NumberField(title: "Rin", unit: "Ω", text: $rg, fieldID: "rin", onSubmit: calculate)
            }
            NumberField(title: "Vref", unit: "V", text: $vref, fieldID: "vref", onSubmit: calculate)
            NumberField(title: "+ rail", unit: "V", text: $railP, fieldID: "rp", onSubmit: calculate)
            NumberField(title: "− rail", unit: "V", text: $railN, fieldID: "rn", onSubmit: calculate)
            NumberField(title: "Allowed CM min", unit: "V", text: $cmMin, fieldID: "cmin", onSubmit: calculate)
            NumberField(title: "Allowed CM max", unit: "V", text: $cmMax, fieldID: "cmax", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    mode = .threeOpAmp
                    v2 = "2.05"; v1 = "2.00"; r = "25000"; rg = "1000"; vref = "0"
                    railP = "5"; railN = "0"; cmMin = "0"; cmMax = "4"
                    session.prepareForNewInputs()
                },
                exampleTitle: "G = 51, 50 mV differential"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Gain", value: AnalogFormat.voltsPerVolt(r.gain), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Vdiff", value: Format.volts(r.differentialIn))
                    ResultRow(label: "Vcm", value: Format.volts(r.commonMode), tone: r.inputCMInRange ? Theme.foreground : Theme.bad)
                    ResultRow(label: "Vout", value: Format.volts(r.vout), emphasis: true, tone: r.outputInSwing ? Theme.good : Theme.bad)
                    ResultRow(label: "+ swing left", value: Format.volts(r.outputHighHeadroom), tone: r.outputHighHeadroom < 0 ? Theme.bad : Theme.foreground)
                    ResultRow(label: "− swing left", value: Format.volts(r.outputLowHeadroom), tone: r.outputLowHeadroom < 0 ? Theme.bad : Theme.foreground)
                    ResultRow(label: "CM window", value: r.inputCMInRange ? "Inside the limits you typed" : "Outside the CM limits you typed", tone: r.inputCMInRange ? Theme.good : Theme.warn)
                    ResultRow(label: "Output vs rails", value: r.outputInSwing ? "Inside rails" : "Clipped vs rails", tone: r.outputInSwing ? Theme.good : Theme.bad)
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            try InstrumentationAmp.solve(
                mode: mode,
                v2: v2.parsedDouble ?? .nan,
                v1: v1.parsedDouble ?? .nan,
                r: r.parsedDouble ?? .nan,
                rg: rg.parsedDouble ?? .nan,
                vref: vref.parsedDouble ?? .nan,
                railPos: railP.parsedDouble ?? .nan,
                railNeg: railN.parsedDouble ?? .nan,
                cmMin: cmMin.parsedDouble ?? .nan,
                cmMax: cmMax.parsedDouble ?? .nan
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        v2 = ""; v1 = ""; r = ""; rg = ""; vref = ""; railP = ""; railN = ""; cmMin = ""; cmMax = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "G = \(Format.number(r.gain, digits: 3))    Vout = \(Format.volts(r.vout))    Vdiff = \(Format.volts(r.differentialIn))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "G \(Format.number(r.gain, digits: 2))  ·  Vout \(Format.volts(r.vout))"
    }

    private func save(_ r: InstrumentationAmpResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .instrumentationAmp,
            inputs: ["mode": mode.rawValue, "V2": v2, "V1": v1, "R": self.r, "Rg": rg],
            outputs: ["G": AnalogFormat.voltsPerVolt(r.gain), "Vout": Format.volts(r.vout)]
        ))
    }
}

// MARK: - ADC / DAC & sampling

struct ADCDACView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.adcDac, "bits", default: "12") private var bits
    @StoredInput(.adcDac, "fs", default: "5") private var fullScale
    @StoredInput(.adcDac, "sample", default: "1000") private var sampleRate
    @StoredInput(.adcDac, "code", default: "") private var dacCode
    @StoredInput(.adcDac, "jobName", default: "ADC DAC") private var jobName
    @State private var session = ExplicitCalculationState<SamplingConverterResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(bits)|\(fullScale)|\(sampleRate)|\(dacCode)" }

    var body: some View {
        ToolScaffold(
            toolID: .adcDac,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Ideal uniform quantization and sampling limits. Not a 4–20 mA scaler (that is Signal Scaling) and not an ENOB / INL lab measurement."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .adcDac,
                symbolic: "LSB = FS / 2ⁿ    Ncodes = 2ⁿ    SNR_ideal ≈ 6.02n + 1.76 dB    Nyquist = Fs/2",
                substituted: substituted,
                meaning: "The SNR formula is the textbook full-scale sine into an ideal quantizer — it is not the SNR of your front-end, and it is not ENOB. Suggested anti-alias fc is 0.4·Fs, a starting corner below Nyquist, not a filter order."
            )

            NumberField(title: "Bits n", unit: "", text: $bits, fieldID: "bits", onSubmit: calculate)
            NumberField(title: "Full-scale span", unit: "V", text: $fullScale, helpText: "Unipolar span 0…FS. Sibling to Signal Scaling — this tool does not map 4–20 mA.", fieldID: "fs", onSubmit: calculate)
            NumberField(title: "Sample rate Fs", unit: "Hz", text: $sampleRate, fieldID: "fsamp", onSubmit: calculate)
            NumberField(title: "DAC code (optional)", unit: "", text: $dacCode, optional: true, helpText: "0 … 2ⁿ−1. V = code · LSB.", fieldID: "code", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    bits = "12"; fullScale = "5"; sampleRate = "1000"; dacCode = "2048"
                    session.prepareForNewInputs()
                },
                exampleTitle: "12-bit, 5 V, 1 kS/s, mid-scale"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "LSB", value: "\(Format.number(r.lsb, digits: 6)) V", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Codes", value: "\(r.codeCount)")
                    ResultRow(label: "Ideal quantization SNR", value: "\(Format.number(r.idealQuantizationSNRdB, digits: 2)) dB")
                    ResultRow(label: "Nyquist", value: Format.frequency(r.nyquistHz))
                    ResultRow(label: "Suggested anti-alias fc", value: Format.frequency(r.suggestedAntiAliasHz))
                    if let dac = r.dacVoltage {
                        ResultRow(label: "DAC voltage", value: Format.volts(dac), emphasis: true)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            let codeText = dacCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let code = codeText.isEmpty ? nil : dacCode.parsedDouble
            return try SamplingConverter.solve(
                bits: bits.parsedDouble ?? .nan,
                fullScale: fullScale.parsedDouble ?? .nan,
                sampleRate: sampleRate.parsedDouble ?? .nan,
                dacCode: code
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        bits = ""; fullScale = ""; sampleRate = ""; dacCode = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        var text = "LSB = \(Format.volts(r.fullScale)) / 2^\(r.bits) = \(Format.volts(r.lsb))    SNR ≈ \(Format.number(r.idealQuantizationSNRdB, digits: 2)) dB"
        if let dac = r.dacVoltage {
            text += "    VDAC = \(Format.volts(dac))"
        }
        return text
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "LSB \(Format.volts(r.lsb))  ·  SNR \(Format.number(r.idealQuantizationSNRdB, digits: 1)) dB"
    }

    private func save(_ r: SamplingConverterResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .adcDac,
            inputs: ["n": bits, "FS": fullScale, "Fs": sampleRate, "code": dacCode],
            outputs: [
                "LSB": Format.volts(r.lsb),
                "SNR": "\(Format.number(r.idealQuantizationSNRdB, digits: 2)) dB",
            ]
        ))
    }
}
