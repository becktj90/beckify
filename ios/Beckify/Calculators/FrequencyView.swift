import SwiftUI
import BeckifyMath

struct FrequencyView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case freq = "f"
        case period = "T"
        case wavelength = "λ"
        case lc = "LC"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.frequencyWave, "mode", default: Mode.freq) private var mode
    @StoredInput(.frequencyWave, "frequency", default: "1000000") private var frequency
    @StoredInput(.frequencyWave, "period", default: "1e-6") private var period
    @StoredInput(.frequencyWave, "wavelength", default: "300") private var wavelength
    @StoredInput(.frequencyWave, "inductance", default: "0.0001") private var inductance
    @StoredInput(.frequencyWave, "capacitance", default: "1e-10") private var capacitance
    @StoredInput(.frequencyWave, "jobName", default: "Frequency") private var jobName
    @State private var session = ExplicitCalculationState<FrequencyResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(frequency)|\(period)|\(wavelength)|\(inductance)|\(capacitance)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .frequencyWave,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .frequencyWave,
                symbolic: mode == .lc ? "f = 1 / (2π √(LC))" : "T = 1/f    λ = c/f    c = 2.99792458×10⁸ m/s",
                substituted: substituted,
                meaning: "Free-space wavelength. Not a transmission-line velocity factor. LC is lossless resonance."
            )
            Picker("Known", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            switch mode {
            case .freq: NumberField(title: "Frequency", unit: "Hz", text: $frequency, allowsScientific: true, fieldID: "frequency", onSubmit: calculate)
            case .period: NumberField(title: "Period", unit: "s", text: $period, allowsScientific: true, fieldID: "period", onSubmit: calculate)
            case .wavelength: NumberField(title: "Wavelength", unit: "m", text: $wavelength, allowsScientific: true, fieldID: "wavelength", onSubmit: calculate)
            case .lc:
                NumberField(title: "L", unit: "H", text: $inductance, allowsScientific: true, fieldID: "inductance", onSubmit: calculate)
                NumberField(title: "C", unit: "F", text: $capacitance, allowsScientific: true, fieldID: "capacitance", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    applyExample()
                    session.prepareForNewInputs()
                },
                exampleTitle: mode == .lc ? "100 µH · 100 pF resonance" : "1 MHz → T and λ"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Frequency", value: Format.frequency(r.frequency), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Period", value: Format.time(r.period), emphasis: true)
                    ResultRow(label: "Wavelength", value: Format.meters(r.wavelength))
                }
                .opacity(session.isStale ? 0.72 : 1)
                if r.frequency.isFinite, r.frequency > 0 {
                    SineWaveChart(frequency: r.frequency)
                        .opacity(session.isStale ? 0.72 : 1)
                }
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
            switch mode {
            case .freq: return try Wave.fromFrequency(frequency.parsedDouble ?? .nan)
            case .period: return try Wave.fromPeriod(period.parsedDouble ?? .nan)
            case .wavelength: return try Wave.fromWavelength(wavelength.parsedDouble ?? .nan)
            case .lc: return try Wave.lcResonance(inductance: inductance.parsedDouble ?? .nan, capacitance: capacitance.parsedDouble ?? .nan)
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        frequency = ""
        period = ""
        wavelength = ""
        inductance = ""
        capacitance = ""
        session.reset()
    }

    private func applyExample() {
        switch mode {
        case .freq:
            frequency = "1000000"
        case .period:
            period = "1e-6"
        case .wavelength:
            wavelength = "300"
        case .lc:
            inductance = "0.0001"
            capacitance = "1e-10"
        }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.frequency(r.frequency))  ·  \(Format.time(r.period))  ·  \(Format.meters(r.wavelength))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.frequency(r.frequency))  ·  \(Format.time(r.period))"
    }

    private var copyText: String? { sticky }

    private func save(_ r: FrequencyResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .frequencyWave,
            inputs: ["mode": mode.rawValue, "f": frequency, "T": period, "λ": wavelength, "L": inductance, "C": capacitance],
            outputs: [
                "f": Format.frequency(r.frequency),
                "T": Format.time(r.period),
                "λ": Format.meters(r.wavelength),
            ]
        ))
    }
}
