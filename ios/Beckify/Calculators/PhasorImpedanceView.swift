import SwiftUI
import BeckifyMath

/// Field tool for sinusoids, peak phasors, element laws, and Z / Y.
struct PhasorImpedanceView: View {
    private enum Station: String, CaseIterable, Identifiable {
        case waves
        case phasor
        case sum
        case elements
        case impedance

        var id: String { rawValue }

        var title: String {
            switch self {
            case .waves: return "Waves"
            case .phasor: return "Phasor"
            case .sum: return "Sum"
            case .elements: return "R L C"
            case .impedance: return "Z / Y"
            }
        }
    }

    @EnvironmentObject private var jobs: JobStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StoredChoice(.phasorImpedance, "station", default: Station.waves) private var station
    @StoredInput(.phasorImpedance, "jobName", default: "Phasor note") private var jobName
    @StoredNumber(.phasorImpedance, "cycle", default: 0) private var cycle

    @StoredChoice(.phasorImpedance, "basisA", default: PhasorImpedance.WaveBasis.cosine) private var basisA
    @StoredInput(.phasorImpedance, "peakA", default: "120") private var peakA
    @StoredInput(.phasorImpedance, "phaseA", default: "0") private var phaseA
    @StoredChoice(.phasorImpedance, "basisB", default: PhasorImpedance.WaveBasis.cosine) private var basisB
    @StoredInput(.phasorImpedance, "peakB", default: "80") private var peakB
    @StoredInput(.phasorImpedance, "phaseB", default: "-30") private var phaseB
    @StoredInput(.phasorImpedance, "waveHz", default: "60") private var waveHz
    @StoredToggle(.phasorImpedance, "showSum", default: true) private var showSum

    @StoredChoice(.phasorImpedance, "phasorBasis", default: PhasorImpedance.WaveBasis.cosine) private var phasorBasis
    @StoredInput(.phasorImpedance, "phasorPeak", default: "170") private var phasorPeak
    @StoredInput(.phasorImpedance, "phasorPhase", default: "30") private var phasorPhase
    @StoredInput(.phasorImpedance, "phasorHz", default: "60") private var phasorHz

    @StoredChoice(.phasorImpedance, "element", default: PhasorImpedance.ElementKind.inductor) private var element
    @StoredInput(.phasorImpedance, "elementValue", default: "0.05") private var elementValue
    @StoredInput(.phasorImpedance, "elementHz", default: "60") private var elementHz
    @StoredInput(.phasorImpedance, "elementPeak", default: "120") private var elementPeak
    @StoredInput(.phasorImpedance, "elementPhase", default: "0") private var elementPhase

    @StoredInput(.phasorImpedance, "ohms", default: "10") private var ohms
    @StoredToggle(.phasorImpedance, "useL", default: true) private var useL
    @StoredInput(.phasorImpedance, "henries", default: "0.04") private var henries
    @StoredToggle(.phasorImpedance, "useC", default: false) private var useC
    @StoredInput(.phasorImpedance, "farads", default: "100e-6") private var farads
    @StoredInput(.phasorImpedance, "zHz", default: "60") private var zHz
    @StoredInput(.phasorImpedance, "zPeak", default: "120") private var zPeak
    @StoredInput(.phasorImpedance, "zPhase", default: "0") private var zPhase
    @StoredToggle(.phasorImpedance, "showY", default: false) private var showY

    @State private var spinning = false
    @State private var spinDate = Date()

    var body: some View {
        ToolScaffold(
            toolID: .phasorImpedance,
            stickyAnswer: sticky,
            copyText: copyText
        ) {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Picker("Section", selection: $station) {
                    ForEach(Station.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("phasorImpedance.station")

                switch station {
                case .waves: wavesStation
                case .phasor: phasorStation
                case .sum: sumStation
                case .elements: elementStation
                case .impedance: impedanceStation
                }

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !spinning || reduceMotion)) { timeline in
                    Color.clear
                        .frame(width: 0, height: 0)
                        .onChange(of: timeline.date) { _, date in
                            spinDate = date
                        }
                }
                .accessibilityHidden(true)

                Text("Ideal parts at one frequency. The drawn wave is the real-axis projection of the rotating peak phasor. Not SPICE.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                saveBar
            }
        }
    }

    // MARK: - Stations

    private var wavesStation: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("v(t) = Vm sin(ωt + φ) or Vm cos(ωt + φ). ω = 2πf. The signal that peaks first is leading.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            NumberField(title: "Frequency", unit: "Hz", text: $waveHz, allowsScientific: true, fieldID: "waveHz")
            signalFields(title: "Signal A", basis: $basisA, peak: $peakA, phase: $phaseA, peakID: "peakA", phaseID: "phaseA")
            signalFields(title: "Signal B", basis: $basisB, peak: $peakB, phase: $phaseB, peakID: "peakB", phaseID: "phaseB")
            Toggle("Show A + B", isOn: $showSum)
                .tint(Theme.accent)

            stationResult(wavesResult) { snapshot in
                Text(snapshot.sentence)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("phasorImpedance.leadLag")
                equationBlock(snapshot.equations)
                cycleControls
                WaveformCard(
                    traces: snapshot.traces,
                    hertz: snapshot.hertz,
                    cycle: displayedCycle
                )
            }
        }
    }

    private var sumStation: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Quick sum of two or three phasors. The balanced three-phase set is one tap away.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            PhasorQuickSumForm(stickyText: .constant(nil), resultStale: .constant(false))
        }
    }

    private var phasorStation: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("One sinusoid becomes one complex amplitude. Rectangular, polar, and exponential forms are the same number.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            basisPicker($phasorBasis)
            NumberField(title: "Peak Vm", unit: "V", text: $phasorPeak, fieldID: "phasorPeak")
            NumberField(title: "Phase φ", unit: "°", text: $phasorPhase, fieldID: "phasorPhase")
            NumberField(title: "Frequency", unit: "Hz", text: $phasorHz, allowsScientific: true, fieldID: "phasorHz")

            stationResult(phasorResult) { snapshot in
                equationBlock(snapshot.equations)
                formCard(snapshot.forms, rms: snapshot.rmsLine)
                cycleControls
                WaveformCard(
                    traces: snapshot.traces,
                    hertz: snapshot.hertz,
                    cycle: displayedCycle
                )
                PlaneCard(
                    title: "Phasor",
                    xTitle: "Real",
                    yTitle: "Imag",
                    vectors: snapshot.vectors(at: displayedCycle),
                    summary: "Peak phasor \(snapshot.forms.polar). Real axis projection matches the waveform."
                )
            }
        }
    }

    private var elementStation: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("V = IR. V = jωL I, a short at DC and an open at high frequency. I = jωC V, an open at DC and a short at high frequency.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Part", selection: $element) {
                Text("R").tag(PhasorImpedance.ElementKind.resistor)
                Text("L").tag(PhasorImpedance.ElementKind.inductor)
                Text("C").tag(PhasorImpedance.ElementKind.capacitor)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("phasorImpedance.element")

            NumberField(
                title: element.valueName,
                unit: element.unit,
                text: $elementValue,
                allowsScientific: element != .resistor,
                fieldID: "elementValue"
            )
            NumberField(title: "Frequency", unit: "Hz", text: $elementHz, allowsScientific: true, fieldID: "elementHz")
            NumberField(title: "Voltage peak", unit: "V", text: $elementPeak, fieldID: "elementPeak")
            NumberField(title: "Voltage phase", unit: "°", text: $elementPhase, fieldID: "elementPhase")

            stationResult(elementResult) { snapshot in
                Text(snapshot.law)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(snapshot.ends)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                formCard(snapshot.forms, rms: snapshot.currentLine)
                SeriesSketch(
                    parts: snapshot.parts,
                    voltageText: snapshot.voltageText,
                    summary: snapshot.law
                )
                cycleControls
                WaveformCard(
                    traces: snapshot.traces,
                    hertz: snapshot.hertz,
                    cycle: displayedCycle
                )
                PlaneCard(
                    title: "V and I",
                    xTitle: "Real",
                    yTitle: "Imag",
                    vectors: snapshot.vectors(at: displayedCycle),
                    summary: snapshot.law
                )
                sweepCard(snapshot.sweep, hertz: snapshot.hertz, includeInductor: snapshot.includeInductor, includeCapacitor: snapshot.includeCapacitor)
            }
        }
    }

    private var impedanceStation: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Z = R + jX. Positive X is inductive and lagging. Negative X is capacitive and leading. Y = 1/Z = G + jB.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            NumberField(title: "Resistance", unit: "Ω", text: $ohms, fieldID: "ohms")
            Toggle("Series inductor", isOn: $useL).tint(Theme.accent)
            if useL {
                NumberField(title: "Inductance", unit: "H", text: $henries, allowsScientific: true, fieldID: "henries")
            }
            Toggle("Series capacitor", isOn: $useC).tint(Theme.accent)
            if useC {
                NumberField(title: "Capacitance", unit: "F", text: $farads, allowsScientific: true, fieldID: "farads")
            }
            Text("A part left off is absent from the string. It is not an open circuit in series.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            NumberField(title: "Frequency", unit: "Hz", text: $zHz, allowsScientific: true, fieldID: "zHz")
            NumberField(title: "Voltage peak", unit: "V", text: $zPeak, fieldID: "zPeak")
            NumberField(title: "Voltage phase", unit: "°", text: $zPhase, fieldID: "zPhase")
            Toggle("Show admittance plane", isOn: $showY).tint(Theme.accent)

            stationResult(impedanceResult) { snapshot in
                Text(snapshot.headline)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("phasorImpedance.impedance")
                formCard(snapshot.zForms, rms: "Y  \(snapshot.yLine)")
                SeriesSketch(parts: snapshot.parts, voltageText: snapshot.voltageText, summary: snapshot.headline)
                cycleControls
                WaveformCard(
                    traces: snapshot.traces,
                    hertz: snapshot.hertz,
                    cycle: displayedCycle
                )
                PlaneCard(
                    title: "V and I",
                    xTitle: "Real",
                    yTitle: "Imag",
                    vectors: snapshot.vectors(at: displayedCycle),
                    summary: snapshot.headline
                )
                PlaneCard(
                    title: "Impedance",
                    xTitle: "R",
                    yTitle: "X",
                    vectors: [snapshot.zVector],
                    showComponents: true,
                    summary: "Impedance \(snapshot.zForms.polar). \(snapshot.planeHint)"
                )
                Text(snapshot.planeHint)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if showY {
                    PlaneCard(
                        title: "Admittance",
                        xTitle: "G",
                        yTitle: "B",
                        vectors: [snapshot.yVector],
                        showComponents: true,
                        summary: "Admittance \(snapshot.yLine)."
                    )
                }
                sweepCard(snapshot.sweep, hertz: snapshot.hertz, includeInductor: snapshot.includeInductor, includeCapacitor: snapshot.includeCapacitor)
            }
        }
    }

    // MARK: - Chrome

    private var displayedCycle: Double {
        let base = cycle.isFinite ? min(1, max(0, cycle)) : 0
        guard spinning, !reduceMotion else { return base }
        let turn = spinDate.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
        return (base + turn).truncatingRemainder(dividingBy: 1)
    }

    private var cycleControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("POSITION IN THE CYCLE")
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                Button(spinning && !reduceMotion ? "Stop" : "Spin") {
                    spinning.toggle()
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
                .accessibilityIdentifier("phasorImpedance.spin")
            }
            Slider(value: $cycle, in: 0...1, onEditingChanged: { editing in
                if editing { spinning = false }
            })
            .accessibilityLabel("Position in the cycle")
            .accessibilityValue("\(Int((min(1, max(0, cycle)) * 100).rounded())) percent")
            if reduceMotion {
                Text("Motion is reduced, so the cursor and the vectors stay where you park them.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAVE A NOTE")
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            Text("On-device field note.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                TextField("Name", text: $jobName)
                    .textInputAutocapitalization(.words)
                    .formFieldFocus("jobName")
                    .frame(minHeight: Theme.touchTarget)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                    .disabled(jobName.trimmingCharacters(in: .whitespaces).isEmpty || copyText == nil)
            }
        }
    }

    private var sticky: String? {
        switch station {
        case .waves: return (try? wavesResult.get())?.sentence
        case .phasor: return (try? phasorResult.get())?.forms.polar
        case .elements: return (try? elementResult.get())?.law
        case .impedance: return (try? impedanceResult.get())?.headline
        // Quick sum publishes its own sticky and save. The parent note stays empty.
        case .sum: return nil
        }
    }

    private var copyText: String? { sticky }

    // MARK: - Solved snapshots

    private struct WavesSnapshot {
        var sentence: String
        var equations: [String]
        var traces: [PhasorImpedance.TimeTrace]
        var hertz: Double
    }

    private struct PhasorSnapshot {
        var sinusoid: PhasorImpedance.Sinusoid
        var equations: [String]
        var forms: PhasorForms
        var rmsLine: String
        var traces: [PhasorImpedance.TimeTrace]
        var hertz: Double

        func vectors(at cycle: Double) -> [PlaneVector] {
            let time = cycle * sinusoid.period
            let spun = PhasorImpedance.rotate(sinusoid.peakPhasor, hertz: hertz, time: time)
            return [PlaneVector(id: "v", name: "Vm", real: spun.real, imaginary: spun.imaginary, color: Theme.chartPrimary)]
        }
    }

    private struct ElementSnapshot {
        var law: String
        var ends: String
        var forms: PhasorForms
        var currentLine: String
        var parts: [SketchPart]
        var voltageText: String
        var traces: [PhasorImpedance.TimeTrace]
        var hertz: Double
        var voltage: PhasorImpedance.ComplexAmplitude
        var current: PhasorImpedance.ComplexAmplitude
        var sweep: [PhasorImpedance.SweepPoint]
        var includeInductor: Bool
        var includeCapacitor: Bool

        func vectors(at cycle: Double) -> [PlaneVector] {
            let time = cycle / hertz
            let v = PhasorImpedance.rotate(voltage, hertz: hertz, time: time)
            let i = PhasorImpedance.rotate(current, hertz: hertz, time: time)
            return [
                PlaneVector(id: "v", name: "V", real: v.real, imaginary: v.imaginary, color: Theme.chartPrimary),
                PlaneVector(id: "i", name: "I", real: i.real, imaginary: i.imaginary, color: Theme.chartSecondary),
            ]
        }
    }

    private struct ImpedanceSnapshot {
        var headline: String
        var zForms: PhasorForms
        var yLine: String
        var planeHint: String
        var parts: [SketchPart]
        var voltageText: String
        var traces: [PhasorImpedance.TimeTrace]
        var hertz: Double
        var voltage: PhasorImpedance.ComplexAmplitude
        var current: PhasorImpedance.ComplexAmplitude
        var zVector: PlaneVector
        var yVector: PlaneVector
        var sweep: [PhasorImpedance.SweepPoint]
        var includeInductor: Bool
        var includeCapacitor: Bool

        func vectors(at cycle: Double) -> [PlaneVector] {
            let time = cycle / hertz
            let v = PhasorImpedance.rotate(voltage, hertz: hertz, time: time)
            let i = PhasorImpedance.rotate(current, hertz: hertz, time: time)
            return [
                PlaneVector(id: "v", name: "V", real: v.real, imaginary: v.imaginary, color: Theme.chartPrimary),
                PlaneVector(id: "i", name: "I", real: i.real, imaginary: i.imaginary, color: Theme.chartSecondary),
            ]
        }
    }

    private var wavesResult: Result<WavesSnapshot, CalcError> {
        CalcCatch.run {
            let hertz = try positive(waveHz, name: "Frequency")
            let a = try PhasorImpedance.makeSinusoid(
                peak: try nonNegative(peakA, name: "Signal A peak"),
                hertz: hertz,
                phaseDegrees: try finite(phaseA, name: "Signal A phase"),
                basis: basisA
            )
            let b = try PhasorImpedance.makeSinusoid(
                peak: try nonNegative(peakB, name: "Signal B peak"),
                hertz: hertz,
                phaseDegrees: try finite(phaseB, name: "Signal B phase"),
                basis: basisB
            )
            let lead = try PhasorImpedance.leadLag(first: a, firstName: "A", second: b, secondName: "B")
            var signals: [(name: String, sinusoid: PhasorImpedance.Sinusoid, unit: String)] = [
                (name: "A", sinusoid: a, unit: "V"),
                (name: "B", sinusoid: b, unit: "V"),
            ]
            if showSum {
                let sum = try PhasorImpedance.sinusoid(from: a.peakPhasor + b.peakPhasor, hertz: hertz, basis: .cosine)
                signals.append((name: "A+B", sinusoid: sum, unit: "V"))
            }
            return WavesSnapshot(
                sentence: leadSentence(lead),
                equations: [equation(a, symbol: "A"), equation(b, symbol: "B"), "ω = 2π · \(Format.frequency(hertz))"],
                traces: try PhasorImpedance.traces(signals),
                hertz: hertz
            )
        }
    }

    private var phasorResult: Result<PhasorSnapshot, CalcError> {
        CalcCatch.run {
            let wave = try PhasorImpedance.makeSinusoid(
                peak: try nonNegative(phasorPeak, name: "Peak"),
                hertz: try positive(phasorHz, name: "Frequency"),
                phaseDegrees: try finite(phasorPhase, name: "Phase"),
                basis: phasorBasis
            )
            let phasor = wave.peakPhasor
            return PhasorSnapshot(
                sinusoid: wave,
                equations: [equation(wave, symbol: "v")],
                forms: PhasorForms(phasor, unit: "V"),
                rmsLine: "RMS  \(PhasorForms(wave.rmsPhasor, unit: "V").polar)",
                traces: try PhasorImpedance.traces([(name: "v", sinusoid: wave, unit: "V")]),
                hertz: wave.hertz
            )
        }
    }

    private var elementResult: Result<ElementSnapshot, CalcError> {
        CalcCatch.run {
            let hertz = try positive(elementHz, name: "Frequency")
            let peak = try nonNegative(elementPeak, name: "Voltage peak")
            let phase = try finite(elementPhase, name: "Voltage phase")
            let voltageWave = try PhasorImpedance.makeSinusoid(peak: peak, hertz: hertz, phaseDegrees: phase, basis: .cosine)
            let law = try PhasorImpedance.element(
                kind: element,
                value: try positive(elementValue, name: element.valueName),
                hertz: hertz,
                voltage: voltageWave.peakPhasor
            )
            let currentWave = try PhasorImpedance.sinusoid(from: law.current, hertz: hertz, basis: .cosine)
            let value = try positive(elementValue, name: element.valueName)
            return ElementSnapshot(
                law: elementLawSentence(law),
                ends: elementEndSentence(law),
                forms: PhasorForms(law.impedance, unit: "Ω"),
                currentLine: "I  \(PhasorForms(law.current, unit: "A").polar)",
                parts: [sketchPart(for: element, value: value)],
                voltageText: PhasorForms(law.voltage, unit: "V").polar,
                traces: try PhasorImpedance.traces([
                    (name: "V", sinusoid: voltageWave, unit: "V"),
                    (name: "I", sinusoid: currentWave, unit: "A"),
                ]),
                hertz: hertz,
                voltage: law.voltage,
                current: law.current,
                sweep: PhasorImpedance.sweep(
                    resistance: element == .resistor ? value : 0,
                    inductanceHenries: element == .inductor ? value : nil,
                    capacitanceFarads: element == .capacitor ? value : nil,
                    aroundHertz: hertz
                ),
                includeInductor: element == .inductor,
                includeCapacitor: element == .capacitor
            )
        }
    }

    private var impedanceResult: Result<ImpedanceSnapshot, CalcError> {
        CalcCatch.run {
            let hertz = try positive(zHz, name: "Frequency")
            let voltageWave = try PhasorImpedance.makeSinusoid(
                peak: try nonNegative(zPeak, name: "Voltage peak"),
                hertz: hertz,
                phaseDegrees: try finite(zPhase, name: "Voltage phase"),
                basis: .cosine
            )
            let resistance = try nonNegative(ohms, name: "Resistance")
            let inductance = useL ? try positive(henries, name: "Inductance") : nil
            let capacitance = useC ? try positive(farads, name: "Capacitance") : nil
            let solved = try PhasorImpedance.series(
                resistance: resistance,
                inductanceHenries: inductance,
                capacitanceFarads: capacitance,
                hertz: hertz,
                voltage: voltageWave.peakPhasor
            )
            let currentWave = try PhasorImpedance.sinusoid(from: solved.current, hertz: hertz, basis: .cosine)
            var parts = [sketchPart(for: .resistor, value: resistance)]
            if let inductance { parts.append(sketchPart(for: .inductor, value: inductance)) }
            if let capacitance { parts.append(sketchPart(for: .capacitor, value: capacitance)) }
            let yForms = PhasorForms(solved.admittance, unit: "S")
            return ImpedanceSnapshot(
                headline: impedanceHeadline(solved),
                zForms: PhasorForms(solved.impedance, unit: "Ω"),
                yLine: "\(yForms.rectangular)   \(yForms.polar)",
                planeHint: planeHint(solved.character),
                parts: parts,
                voltageText: PhasorForms(solved.voltage, unit: "V").polar,
                traces: try PhasorImpedance.traces([
                    (name: "V", sinusoid: voltageWave, unit: "V"),
                    (name: "I", sinusoid: currentWave, unit: "A"),
                ]),
                hertz: hertz,
                voltage: solved.voltage,
                current: solved.current,
                zVector: PlaneVector(id: "z", name: "Z", real: solved.impedance.real, imaginary: solved.impedance.imaginary, color: Theme.chartPrimary),
                yVector: PlaneVector(id: "y", name: "Y", real: solved.admittance.real, imaginary: solved.admittance.imaginary, color: Theme.chartTertiary),
                sweep: PhasorImpedance.sweep(
                    resistance: resistance,
                    inductanceHenries: inductance,
                    capacitanceFarads: capacitance,
                    aroundHertz: hertz
                ),
                includeInductor: inductance != nil,
                includeCapacitor: capacitance != nil
            )
        }
    }

    // MARK: - Fields

    private func signalFields(
        title: String,
        basis: Binding<PhasorImpedance.WaveBasis>,
        peak: Binding<String>,
        phase: Binding<String>,
        peakID: String,
        phaseID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            sectionLabel(title)
            basisPicker(basis)
            NumberField(title: "Peak", unit: "V", text: peak, fieldID: peakID)
            NumberField(title: "Phase", unit: "°", text: phase, fieldID: phaseID)
        }
    }

    private func basisPicker(_ basis: Binding<PhasorImpedance.WaveBasis>) -> some View {
        Picker("Form", selection: basis) {
            Text("Sine").tag(PhasorImpedance.WaveBasis.sine)
            Text("Cosine").tag(PhasorImpedance.WaveBasis.cosine)
        }
        .pickerStyle(.segmented)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.TypeRole.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
    }

    private func stationResult<Snapshot, Content: View>(
        _ result: Result<Snapshot, CalcError>,
        @ViewBuilder content: (Snapshot) -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            switch result {
            case .failure(let error):
                ErrorText(message: error.message)
            case .success(let snapshot):
                content(snapshot)
            }
        }
    }

    private func equationBlock(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func formCard(_ forms: PhasorForms, rms: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            metric("Rectangular", forms.rectangular)
            metric("Polar", forms.polar)
            metric("Exponential", forms.exponential)
            Text(rms)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
        )
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func sweepCard(
        _ points: [PhasorImpedance.SweepPoint],
        hertz: Double,
        includeInductor: Bool,
        includeCapacitor: Bool
    ) -> some View {
        let series = sweepSeries(points, includeInductor: includeInductor, includeCapacitor: includeCapacitor)
        return DiagramCard(
            title: "Reactance vs frequency",
            accessibilitySummary: "Ideal XL and XC around \(Format.frequency(hertz)). Not a measured sweep.",
            exportName: "phasors-reactance-sweep"
        ) {
            if series.isEmpty {
                Text("Enter a frequency to draw the sweep.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                EngineerLinePlot(
                    series: series,
                    xLabel: "Frequency (Hz)",
                    yLabel: "Ohms",
                    xGuides: [EngineerGuide(value: hertz, label: "f", axis: .x)],
                    yGuides: [EngineerGuide(value: 0, label: "0", axis: .y)],
                    logX: true,
                    height: 200,
                    smooth: true
                )
                Text("XL rises with frequency. XC falls toward zero. The marker is the frequency above. Lumped ideal parts only.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sweepSeries(
        _ points: [PhasorImpedance.SweepPoint],
        includeInductor: Bool,
        includeCapacitor: Bool
    ) -> [EngineerSeries] {
        guard points.count >= 2 else { return [] }
        var series: [EngineerSeries] = []
        if includeInductor {
            series.append(EngineerSeries(
                name: "XL",
                points: points.map { PlotPoint(x: $0.hertz, y: $0.inductiveReactance) },
                color: Theme.chartSecondary
            ))
        }
        if includeCapacitor {
            series.append(EngineerSeries(
                name: "XC",
                points: points.map { PlotPoint(x: $0.hertz, y: $0.capacitiveReactance) },
                color: Theme.chartTertiary
            ))
        }
        series.append(EngineerSeries(
            name: "|Z|",
            points: points.map { PlotPoint(x: $0.hertz, y: $0.impedanceMagnitude) },
            color: Theme.chartPrimary,
            fills: series.isEmpty
        ))
        return series
    }

    // MARK: - Copy

    private func equation(_ wave: PhasorImpedance.Sinusoid, symbol: String) -> String {
        let name = wave.basis == .sine ? "sin" : "cos"
        let phase = wave.phaseDegrees
        let phaseText: String
        if abs(phase) < 0.05 {
            phaseText = ""
        } else if phase > 0 {
            phaseText = " + \(Format.number(phase, digits: 2))°"
        } else {
            phaseText = " − \(Format.number(abs(phase), digits: 2))°"
        }
        return "\(symbol)(t) = \(Format.number(wave.peak, digits: 3)) \(name)(ωt\(phaseText))"
    }

    private func leadSentence(_ lead: PhasorImpedance.LeadLag) -> String {
        switch lead.relation {
        case .inPhase:
            return "\(lead.firstName) and \(lead.secondName) are in phase."
        case .leads:
            return "\(lead.firstName) leads \(lead.secondName) by \(Format.degrees(lead.deltaDegrees)). It peaks \(Format.time(lead.earlierBySeconds)) earlier."
        case .lags:
            let later = abs(lead.earlierBySeconds)
            return "\(lead.firstName) lags \(lead.secondName) by \(Format.degrees(abs(lead.deltaDegrees))). It peaks \(Format.time(later)) later."
        }
    }

    private func elementLawSentence(_ law: PhasorImpedance.ElementLaw) -> String {
        switch law.kind {
        case .resistor:
            return "V = IR. Voltage and current share an angle."
        case .inductor:
            return "V = jωL I. Voltage leads current by \(Format.degrees(law.voltageLeadsCurrentDegrees))."
        case .capacitor:
            return "I = jωC V. Current leads voltage by \(Format.degrees(abs(law.voltageLeadsCurrentDegrees)))."
        }
    }

    private func elementEndSentence(_ law: PhasorImpedance.ElementLaw) -> String {
        switch law.kind {
        case .resistor:
            return "In this model the resistance does not change with frequency."
        case .inductor:
            return "Toward DC, ωL goes to a short. As frequency rises, ωL goes to an open circuit."
        case .capacitor:
            return "Toward DC, 1/(ωC) goes to an open circuit. As frequency rises, it goes to a short."
        }
    }

    private func impedanceHeadline(_ result: PhasorImpedance.ImpedanceResult) -> String {
        let forms = PhasorForms(result.impedance, unit: "Ω")
        switch result.character {
        case .resistive:
            return "\(forms.rectangular). Resistive — voltage and current are in phase."
        case .lagging:
            return "\(forms.rectangular). Inductive — current lags voltage."
        case .leading:
            return "\(forms.rectangular). Capacitive — current leads voltage."
        }
    }

    private func planeHint(_ character: PhasorImpedance.ReactanceSign) -> String {
        switch character {
        case .resistive: return "X is about zero, so the point sits on the resistance axis."
        case .lagging: return "Above the R axis: X > 0, inductive, current lagging."
        case .leading: return "Below the R axis: X < 0, capacitive, current leading."
        }
    }

    private func sketchPart(for kind: PhasorImpedance.ElementKind, value: Double) -> SketchPart {
        switch kind {
        case .resistor: return SketchPart(kind: .resistor, label: "\(Format.number(value, digits: 3)) Ω")
        case .inductor: return SketchPart(kind: .inductor, label: "\(Format.number(value, digits: 4)) H")
        case .capacitor: return SketchPart(kind: .capacitor, label: "\(Format.number(value, digits: 4)) F")
        }
    }

    private func positive(_ text: String, name: String) throws -> Double {
        guard let value = text.parsedDouble else { throw CalcError.missing(name) }
        guard value > 0 else { throw CalcError.nonPositive(name) }
        return value
    }

    private func nonNegative(_ text: String, name: String) throws -> Double {
        guard let value = text.parsedDouble else { throw CalcError.missing(name) }
        guard value >= 0 else { throw CalcError.outOfRange("\(name) must be zero or positive.") }
        return value
    }

    private func finite(_ text: String, name: String) throws -> Double {
        guard let value = text.parsedDouble, value.isFinite else { throw CalcError.missing(name) }
        return value
    }

    private func save() {
        guard let headline = copyText else { return }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .phasorImpedance,
            inputs: [
                "station": station.rawValue,
                "waveHz": waveHz,
                "peakA": peakA,
                "phaseA": phaseA,
                "peakB": peakB,
                "phaseB": phaseB,
            ],
            outputs: ["headline": headline]
        ))
    }
}

private extension PhasorImpedance.ElementKind {
    var unit: String {
        switch self {
        case .resistor: return "Ω"
        case .inductor: return "H"
        case .capacitor: return "F"
        }
    }
}

private struct PhasorForms: Equatable {
    var rectangular: String
    var polar: String
    var exponential: String

    init(_ value: PhasorImpedance.ComplexAmplitude, unit: String) {
        let sign = value.imaginary >= 0 ? "+" : "−"
        rectangular = "\(Format.number(value.real, digits: 3)) \(sign) j\(Format.number(abs(value.imaginary), digits: 3)) \(unit)"
        polar = "\(Format.number(value.magnitude, digits: 3)) \(unit) ∠ \(Format.number(value.angleDegrees, digits: 2))°"
        exponential = "\(Format.number(value.magnitude, digits: 3)) \(unit)  e^{j \(Format.number(value.angleDegrees, digits: 2))°}"
    }
}

// MARK: - Drawings

private struct PlaneVector: Identifiable {
    var id: String
    var name: String
    var real: Double
    var imaginary: Double
    var color: Color
}

private struct WaveformCard: View {
    var traces: [PhasorImpedance.TimeTrace]
    var hertz: Double
    var cycle: Double

    private var voltTraces: [PhasorImpedance.TimeTrace] {
        traces.filter { $0.unit == "V" }
    }

    private var ampTraces: [PhasorImpedance.TimeTrace] {
        traces.filter { $0.unit == "A" }
    }

    /// Voltage traces, then current. Anything else stays off both axes.
    private var plotted: [PhasorImpedance.TimeTrace] {
        voltTraces + ampTraces
    }

    private var timeWindow: PhasorImpedance.SampleWindow {
        PhasorImpedance.timeWindow(of: plotted)
    }

    private var voltWindow: PhasorImpedance.SampleWindow? {
        guard !voltTraces.isEmpty else { return nil }
        return PhasorImpedance.symmetricAmplitudeWindow(of: voltTraces)
    }

    private var ampWindow: PhasorImpedance.SampleWindow? {
        guard !ampTraces.isEmpty else { return nil }
        return PhasorImpedance.symmetricAmplitudeWindow(of: ampTraces)
    }

    /// Parked cycle cursor. Nil when frequency is not a positive number.
    private var cursorTime: Double? {
        guard hertz.isFinite, hertz > 0, cycle.isFinite else { return nil }
        return min(1, max(0, cycle)) / hertz
    }

    private var scaleNote: String {
        if voltTraces.isEmpty {
            return "Current versus time."
        }
        if ampTraces.isEmpty {
            return "Voltage versus time."
        }
        return "Volts on the left scale, amps on the right."
    }

    private var parkedDescription: String {
        describe(at: cursorTime ?? timeWindow.start)
    }

    var body: some View {
        DiagramCard(title: "Waveform", accessibilitySummary: parkedDescription, exportName: "phasors-waveform") {
            LabeledPlotChrome(
                xAxis: PlotAxis(
                    title: "Time",
                    unit: "s",
                    start: tick(timeWindow.start, digits: 4),
                    mid: tick(timeWindow.mid, digits: 4),
                    end: tick(timeWindow.end, digits: 4)
                ),
                yAxis: primaryAxis,
                secondaryYAxis: secondaryAxis,
                accessibilityLabel: parkedDescription,
                inspection: .inspect,
                plotHeight: 220,
                fullscreenTitle: "Time waveform",
                readout: { x, _ in
                    describe(at: timeWindow.value(atFraction: Double(x)))
                }
            ) {
                WaveformCanvas(
                    voltTraces: voltTraces,
                    ampTraces: ampTraces,
                    time: timeWindow,
                    volts: voltWindow,
                    amps: ampWindow,
                    cursorTime: cursorTime
                )
            }
            Text(parkedDescription)
                .font(Theme.TypeRole.hud)
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            legend
        }
    }

    private var primaryAxis: PlotAxis {
        if let voltWindow {
            return amplitudeAxis(title: "Voltage", unit: "V", window: voltWindow)
        }
        return amplitudeAxis(title: "Current", unit: "A", window: ampWindow ?? PhasorImpedance.symmetricAmplitudeWindow(of: []))
    }

    private var secondaryAxis: PlotAxis? {
        guard voltWindow != nil, let ampWindow else { return nil }
        return amplitudeAxis(title: "Current", unit: "A", window: ampWindow)
    }

    private func amplitudeAxis(title: String, unit: String, window: PhasorImpedance.SampleWindow) -> PlotAxis {
        PlotAxis(
            title: title,
            unit: unit,
            start: tick(window.start, digits: 2),
            mid: tick(window.mid, digits: 2),
            end: tick(window.end, digits: 2)
        )
    }

    private func tick(_ value: Double, digits: Int) -> String {
        Format.number(value, digits: digits)
    }

    /// Numbers first, then which scale those numbers use.
    private func describe(at time: Double) -> String {
        var parts = ["\(Format.number(time, digits: 4)) s"]
        if voltTraces.count == 1, ampTraces.isEmpty, let trace = voltTraces.first {
            parts.append(Format.volts(trace.value(at: time)))
        } else {
            for trace in voltTraces {
                parts.append("\(trace.name) \(Format.volts(trace.value(at: time)))")
            }
            for trace in ampTraces {
                parts.append("\(trace.name) \(Format.amps(trace.value(at: time)))")
            }
        }
        return "\(parts.joined(separator: ", ")). \(scaleNote)"
    }

    private func color(at index: Int) -> Color {
        let palette = [Theme.chartPrimary, Theme.chartSecondary, Theme.chartTertiary, Theme.good]
        return palette[index % palette.count]
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(Array(plotted.enumerated()), id: \.element.name) { index, trace in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color(at: index))
                        .frame(width: 8, height: 8)
                    Text("\(trace.name) (\(trace.unit))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WaveformCanvas: View {
    var voltTraces: [PhasorImpedance.TimeTrace]
    var ampTraces: [PhasorImpedance.TimeTrace]
    var time: PhasorImpedance.SampleWindow
    var volts: PhasorImpedance.SampleWindow?
    var amps: PhasorImpedance.SampleWindow?
    var cursorTime: Double?

    var body: some View {
        Canvas { context, size in
            let zeroWindow = volts ?? amps
            if let zeroWindow {
                var zero = Path()
                let y = y(0, in: zeroWindow, height: size.height)
                zero.move(to: CGPoint(x: 0, y: y))
                zero.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(zero, with: .color(Theme.muted.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            if let volts {
                for (index, trace) in voltTraces.enumerated() {
                    stroke(trace, in: volts, color: color(at: index), context: &context, size: size)
                }
            }
            if let amps {
                for (index, trace) in ampTraces.enumerated() {
                    stroke(trace, in: amps, color: color(at: voltTraces.count + index), context: &context, size: size)
                }
            }

            if let cursorTime {
                var cursor = Path()
                let x = x(cursorTime, width: size.width)
                cursor.move(to: CGPoint(x: x, y: 0))
                cursor.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(cursor, with: .color(Theme.foreground.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
        }
        .accessibilityHidden(true)
    }

    private func stroke(
        _ trace: PhasorImpedance.TimeTrace,
        in window: PhasorImpedance.SampleWindow,
        color: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        var path = Path()
        for (index, sample) in trace.samples.enumerated() {
            let point = CGPoint(x: x(sample.time, width: size.width), y: y(sample.value, in: window, height: size.height))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )
        if let peak = trace.samples.max(by: { $0.value < $1.value }) {
            let peakPoint = CGPoint(x: x(peak.time, width: size.width), y: y(peak.value, in: window, height: size.height))
            let marker = Path(ellipseIn: CGRect(x: peakPoint.x - 3.5, y: peakPoint.y - 3.5, width: 7, height: 7))
            context.fill(marker, with: .color(color))
        }
    }

    private func x(_ time: Double, width: CGFloat) -> CGFloat {
        CGFloat(self.time.fraction(time)) * width
    }

    private func y(_ value: Double, in window: PhasorImpedance.SampleWindow, height: CGFloat) -> CGFloat {
        (1 - CGFloat(window.fraction(value))) * height
    }

    private func color(at index: Int) -> Color {
        let palette = [Theme.chartPrimary, Theme.chartSecondary, Theme.chartTertiary, Theme.good]
        return palette[index % palette.count]
    }
}

private struct PlaneCard: View {
    var title: String
    var xTitle: String
    var yTitle: String
    var vectors: [PlaneVector]
    var showComponents: Bool = false
    var summary: String

    var body: some View {
        DiagramCard(title: title, accessibilitySummary: summary, exportName: "phasors-\(title.lowercased())") {
            ComplexPlaneCanvas(xTitle: xTitle, yTitle: yTitle, vectors: vectors, showComponents: showComponents)
                .frame(height: 260)
        }
    }
}

private struct ComplexPlaneCanvas: View {
    var xTitle: String
    var yTitle: String
    var vectors: [PlaneVector]
    var showComponents: Bool

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 36, y: 16, width: max(1, size.width - 52), height: max(1, size.height - 36))
            let maxAbs = vectors.reduce(1e-6) { partial, vector in
                max(partial, abs(vector.real), abs(vector.imaginary))
            }
            let span = maxAbs * 1.25
            let xMin = -span
            let xMax = span
            let yMin = -span
            let yMax = span
            func map(_ real: Double, _ imaginary: Double) -> CGPoint {
                let fx = (real - xMin) / (xMax - xMin)
                let fy = (imaginary - yMin) / (yMax - yMin)
                return CGPoint(x: plot.minX + CGFloat(fx) * plot.width, y: plot.maxY - CGFloat(fy) * plot.height)
            }
            let origin = map(0, 0)

            var axes = Path()
            axes.move(to: CGPoint(x: plot.minX, y: origin.y))
            axes.addLine(to: CGPoint(x: plot.maxX, y: origin.y))
            axes.move(to: CGPoint(x: origin.x, y: plot.minY))
            axes.addLine(to: CGPoint(x: origin.x, y: plot.maxY))
            context.stroke(axes, with: .color(Theme.muted.opacity(0.85)), lineWidth: 1.2)

            let xLabel = context.resolve(Text(xTitle).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted))
            let yLabel = context.resolve(Text(yTitle).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted))
            context.draw(xLabel, at: CGPoint(x: plot.maxX, y: origin.y - 8), anchor: .bottomTrailing)
            context.draw(yLabel, at: CGPoint(x: origin.x + 8, y: plot.minY), anchor: .topLeading)

            for vector in vectors {
                let tip = map(vector.real, vector.imaginary)
                if showComponents {
                    var legs = Path()
                    legs.move(to: origin)
                    legs.addLine(to: map(vector.real, 0))
                    legs.addLine(to: tip)
                    context.stroke(legs, with: .color(vector.color.opacity(0.45)), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
                var shaft = Path()
                shaft.move(to: origin)
                shaft.addLine(to: tip)
                context.stroke(shaft, with: .color(vector.color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                arrowHead(in: context, tip: tip, from: origin, color: vector.color)
                let name = context.resolve(
                    Text(vector.name).font(.system(size: 12, weight: .bold)).foregroundColor(vector.color)
                )
                let dx = tip.x - origin.x
                let dy = tip.y - origin.y
                let length = max(hypot(dx, dy), 1)
                let place = CGPoint(x: tip.x + dx / length * 14, y: tip.y + dy / length * 14)
                context.draw(name, at: place, anchor: .center)
            }

            let dot = Path(ellipseIn: CGRect(x: origin.x - 3, y: origin.y - 3, width: 6, height: 6))
            context.fill(dot, with: .color(Theme.foreground))
        }
        .accessibilityHidden(true)
    }

    private func arrowHead(in context: GraphicsContext, tip: CGPoint, from origin: CGPoint, color: Color) {
        let angle = atan2(tip.y - origin.y, tip.x - origin.x)
        let length: CGFloat = 11
        let spread: CGFloat = 0.45
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread)))
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread)))
        context.stroke(head, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }
}

private struct SketchPart: Identifiable {
    var id: String { label }
    var kind: PhasorImpedance.ElementKind
    var label: String
}

private struct SeriesSketch: View {
    var parts: [SketchPart]
    var voltageText: String
    var summary: String

    var body: some View {
        DiagramCard(title: "Circuit", accessibilitySummary: summary, exportName: "phasors-circuit") {
            Canvas { context, size in
                let top = size.height * 0.38
                let bottom = size.height * 0.78
                let left = size.width * 0.08
                let right = size.width * 0.92
                var wire = Path()
                wire.move(to: CGPoint(x: left, y: top))
                wire.addLine(to: CGPoint(x: right, y: top))
                wire.addLine(to: CGPoint(x: right, y: bottom))
                wire.addLine(to: CGPoint(x: left, y: bottom))
                wire.closeSubpath()
                context.stroke(wire, with: .color(Theme.foreground), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                let source = CGPoint(x: left, y: (top + bottom) / 2)
                let radius = min(size.height * 0.12, 16)
                let circle = Path(ellipseIn: CGRect(x: source.x - radius, y: source.y - radius, width: radius * 2, height: radius * 2))
                context.fill(circle, with: .color(Theme.inputFill))
                context.stroke(circle, with: .color(Theme.accent), lineWidth: 1.8)
                let sine = sineGlyph(center: source, radius: radius * 0.62)
                context.stroke(sine, with: .color(Theme.accent), lineWidth: 1.4)

                let slots = max(parts.count, 1)
                for (index, part) in parts.enumerated() {
                    let centerX = left + (right - left) * (CGFloat(index) + 1) / CGFloat(slots + 1)
                    let center = CGPoint(x: centerX, y: top)
                    draw(part, at: center, in: context)
                }

                let voltage = context.resolve(
                    Text(voltageText).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.accent)
                )
                context.draw(voltage, at: CGPoint(x: source.x + radius + 8, y: source.y), anchor: .leading)
            }
            .frame(height: 132)
            .accessibilityHidden(true)
        }
    }

    private func draw(_ part: SketchPart, at center: CGPoint, in context: GraphicsContext) {
        let cover = Path(roundedRect: CGRect(x: center.x - 28, y: center.y - 16, width: 56, height: 32), cornerRadius: 4)
        context.fill(cover, with: .color(Theme.inputFill))
        var path = Path()
        switch part.kind {
        case .resistor:
            path.move(to: CGPoint(x: center.x - 26, y: center.y))
            let step: CGFloat = 8
            for tooth in 0..<6 {
                let x = center.x - 22 + CGFloat(tooth) * step
                let y = center.y + (tooth % 2 == 0 ? -8 : 8)
                path.addLine(to: CGPoint(x: x, y: tooth == 5 ? center.y : y))
            }
            path.addLine(to: CGPoint(x: center.x + 26, y: center.y))
        case .inductor:
            path.move(to: CGPoint(x: center.x - 26, y: center.y))
            path.addLine(to: CGPoint(x: center.x - 18, y: center.y))
            for hump in 0..<3 {
                path.addArc(
                    center: CGPoint(x: center.x - 12 + CGFloat(hump) * 12, y: center.y),
                    radius: 6,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            }
            path.addLine(to: CGPoint(x: center.x + 26, y: center.y))
        case .capacitor:
            path.move(to: CGPoint(x: center.x - 26, y: center.y))
            path.addLine(to: CGPoint(x: center.x - 4, y: center.y))
            path.move(to: CGPoint(x: center.x - 4, y: center.y - 12))
            path.addLine(to: CGPoint(x: center.x - 4, y: center.y + 12))
            path.move(to: CGPoint(x: center.x + 4, y: center.y - 12))
            path.addLine(to: CGPoint(x: center.x + 4, y: center.y + 12))
            path.move(to: CGPoint(x: center.x + 4, y: center.y))
            path.addLine(to: CGPoint(x: center.x + 26, y: center.y))
        }
        context.stroke(path, with: .color(Theme.foreground), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
        let label = context.resolve(Text(part.label).font(.system(size: 10, weight: .medium)).foregroundColor(Theme.muted))
        context.draw(label, at: CGPoint(x: center.x, y: center.y - 22), anchor: .bottom)
    }

    private func sineGlyph(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let start = CGPoint(x: center.x - radius, y: center.y)
        path.move(to: start)
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y),
            control: CGPoint(x: center.x - radius * 0.5, y: center.y - radius)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x + radius, y: center.y),
            control: CGPoint(x: center.x + radius * 0.5, y: center.y + radius)
        )
        return path
    }
}
