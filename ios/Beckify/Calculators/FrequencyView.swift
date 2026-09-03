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
    @State private var session = ExplicitCalculationSession<FrequencyResult>()
    @State private var successTick = 0

    private var fingerprint: String {
        "\(mode.rawValue)|\(frequency)|\(period)|\(wavelength)|\(inductance)|\(capacitance)"
    }
    private var display: ExplicitCalculationSession<FrequencyResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .frequencyWave,
            stickyAnswer: sticky,
            copyText: copyText,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.lastError,
                    successTick: successTick,
                    onCalculate: calculate,
                    onReset: reset
                )
            }
        ) {
            ShowWorkCard(
                toolID: .frequencyWave,
                symbolic: mode == .lc ? "f = 1 / (2π √(LC))" : "T = 1/f    λ = c/f    c = 2.99792458×10⁸ m/s",
                substituted: substituted,
                meaning: "Free-space wavelength. Not a transmission-line velocity factor. LC is lossless resonance."
            )
            TryExampleButton(title: mode == .lc ? "100 µH · 100 pF resonance" : "1 MHz → T and λ") {
                applyExample()
            }
            Picker("Known", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            switch mode {
            case .freq: NumberField(title: "Frequency", unit: "Hz", text: $frequency, allowsScientific: true)
            case .period: NumberField(title: "Period", unit: "s", text: $period, allowsScientific: true)
            case .wavelength: NumberField(title: "Wavelength", unit: "m", text: $wavelength, allowsScientific: true)
            case .lc:
                NumberField(title: "L", unit: "H", text: $inductance, allowsScientific: true)
                NumberField(title: "C", unit: "F", text: $capacitance, allowsScientific: true)
            }
            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Frequency", value: Format.frequency(r.frequency), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Period", value: Format.time(r.period), emphasis: true)
                    ResultRow(label: "Wavelength", value: Format.meters(r.wavelength))
                }
                SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
            case .idle:
                ToolEmptyState(
                    title: "Enter a known value",
                    detail: "Choose f, T, λ, or LC, then Calculate.",
                    systemImage: "waveform"
                )
            case .failed:
                EmptyView()
            }
        }
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            switch mode {
            case .freq: return try Wave.fromFrequency(frequency.parsedDouble ?? .nan)
            case .period: return try Wave.fromPeriod(period.parsedDouble ?? .nan)
            case .wavelength: return try Wave.fromWavelength(wavelength.parsedDouble ?? .nan)
            case .lc: return try Wave.lcResonance(inductance: inductance.parsedDouble ?? .nan, capacitance: capacitance.parsedDouble ?? .nan)
            }
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        mode = .freq
        frequency = "1000000"
        period = "1e-6"
        wavelength = "300"
        inductance = "0.0001"
        capacitance = "1e-10"
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
        guard case .current(let r) = display else { return nil }
        if mode == .lc {
            return "f = 1 / (2π √(\(inductance) × \(capacitance))) = \(Format.frequency(r.frequency))"
        }
        return "T = 1 / \(Format.frequency(r.frequency)) = \(Format.time(r.period))    λ = c / f = \(Format.meters(r.wavelength))"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "\(Format.frequency(r.frequency))  ·  \(Format.time(r.period))"
        default:
            return nil
        }
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
