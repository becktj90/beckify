import SwiftUI
import BeckifyMath

// MARK: - Reactance and resonance

struct ReactanceView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case series = "Series Z"
        case resonance = "Resonance"
        var id: String { rawValue }
    }

    private enum Output: Equatable {
        case series(ReactanceResult)
        case resonance(ResonanceResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.reactance, "mode", default: Mode.series) private var mode
    @StoredInput(.reactance, "frequency", default: "60") private var frequency
    @StoredInput(.reactance, "resistance", default: "10") private var resistance
    @StoredInput(.reactance, "inductance", default: "0.1") private var inductance
    @StoredInput(.reactance, "capacitance", default: "100") private var capacitance
    @StoredInput(.reactance, "jobName", default: "Reactance") private var jobName
    @State private var session = ExplicitCalculationState<Output>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Entered in microfarads, the unit on the part.
    private var farads: Double { (capacitance.parsedDouble ?? .nan) * 1e-6 }

    private var inputFingerprint: String {
        "\(mode)|\(frequency)|\(resistance)|\(inductance)|\(capacitance)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .reactance,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .reactance,
                symbolic: mode == .series
                    ? "X_L = 2πfL    X_C = 1/(2πfC)    Z = √(R² + (X_L − X_C)²)"
                    : "f₀ = 1/(2π√(LC))    Q = (1/R)√(L/C)    BW = f₀/Q",
                substituted: substituted,
                meaning: mode == .series
                    ? "Net reactance is inductive when X_L wins, and the angle is positive — current lags."
                    : "At resonance X_L and X_C cancel and the circuit looks resistive. Q is the sharpness of that peak."
            )
            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }
            if mode == .series {
                NumberField(title: "Frequency", unit: "Hz", text: $frequency, fieldID: "frequency", onSubmit: calculate)
            }
            NumberField(title: "Resistance", unit: "Ω", text: $resistance, optional: mode == .resonance, fieldID: "resistance", onSubmit: calculate)
            NumberField(title: "Inductance", unit: "H", text: $inductance, fieldID: "inductance", onSubmit: calculate)
            NumberField(title: "Capacitance", unit: "µF", text: $capacitance, fieldID: "capacitance", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    frequency = "60"
                    resistance = "10"
                    inductance = "0.1"
                    capacitance = "100"
                    session.prepareForNewInputs()
                },
                exampleTitle: "60 Hz, 10 Ω, 100 mH, 100 µF"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                if case .series(let r) = output, r.impedance.isFinite, r.netReactance.isFinite {
                    // Derive R from the committed Z/X so a stale diagram cannot
                    // drift when the text field is edited.
                    let committedR = max(0, (r.impedance * r.impedance - r.netReactance * r.netReactance)).squareRoot()
                    ReactancePhasorDiagram(
                        resistance: committedR,
                        netReactance: r.netReactance,
                        impedance: r.impedance,
                        angleDegrees: r.phaseAngleDegrees
                    )
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
    private func rows(for output: Output) -> some View {
        switch output {
        case .series(let r):
            ResultRow(label: "X_L", value: "\(Format.number(r.inductiveReactance, digits: 3)) Ω")
            ResultRow(label: "X_C", value: r.capacitiveReactance.isFinite ? "\(Format.number(r.capacitiveReactance, digits: 3)) Ω" : "open")
            ResultRow(label: "Net X", value: r.netReactance.isFinite ? "\(Format.number(r.netReactance, digits: 3)) Ω" : "—")
            ResultRow(label: "Impedance", value: r.impedance.isFinite ? "\(Format.number(r.impedance, digits: 3)) Ω" : "open", emphasis: true, tone: Theme.good)
            ResultRow(label: "Angle", value: Format.degrees(r.phaseAngleDegrees))
        case .resonance(let r):
            ResultRow(label: "f₀", value: Format.frequency(r.frequency), emphasis: true, tone: Theme.good)
            ResultRow(label: "Q", value: r.qualityFactor.isFinite ? Format.number(r.qualityFactor, digits: 3) : "—")
            ResultRow(label: "Bandwidth", value: r.bandwidth.isFinite ? Format.frequency(r.bandwidth) : "—")
        }
    }

    private func calculate() {
        session.calculate {
            if mode == .series {
                // Series R is required — do not coerce blank/garbage text to 0 Ω.
                return .series(try Reactance.series(
                    frequency: frequency.parsedDouble ?? .nan,
                    resistance: resistance.parsedDouble ?? .nan,
                    inductance: inductance.parsedDouble ?? .nan,
                    capacitance: farads
                ))
            }
            // Resonance R is optional in the UI; blank stays 0 for Q = ∞ handling upstream.
            let resonanceR: Double
            if resistance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resonanceR = 0
            } else {
                resonanceR = resistance.parsedDouble ?? .nan
            }
            return .resonance(try Reactance.resonance(
                inductance: inductance.parsedDouble ?? .nan,
                capacitance: farads,
                resistance: resonanceR
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        frequency = ""
        resistance = ""
        inductance = ""
        capacitance = ""
        session.reset()
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .series(let r):
            return "X_L = \(Format.number(r.inductiveReactance, digits: 3)) Ω    Z = \(Format.number(r.impedance, digits: 3)) Ω ∠ \(Format.number(r.phaseAngleDegrees, digits: 2))°"
        case .resonance(let r):
            return "f₀ = \(Format.frequency(r.frequency))    Q = \(Format.number(r.qualityFactor, digits: 3))"
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .series(let r):
            return r.impedance.isFinite ? "Z \(Format.number(r.impedance, digits: 3)) Ω ∠ \(Format.number(r.phaseAngleDegrees, digits: 1))°" : "Open circuit"
        case .resonance(let r):
            return "f₀ \(Format.frequency(r.frequency))"
        }
    }

    private func save(_ output: Output) {
        var outputs: [String: String] = [:]
        switch output {
        case .series(let r):
            outputs["X_L"] = Format.number(r.inductiveReactance, digits: 3)
            outputs["Z"] = Format.number(r.impedance, digits: 3)
            outputs["angle"] = Format.degrees(r.phaseAngleDegrees)
        case .resonance(let r):
            outputs["f0"] = Format.frequency(r.frequency)
            outputs["Q"] = Format.number(r.qualityFactor, digits: 3)
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .reactance,
            inputs: ["mode": mode.rawValue, "f": frequency, "R": resistance, "L": inductance, "C µF": capacitance],
            outputs: outputs
        ))
    }
}

// MARK: - Power factor correction

struct PowerFactorView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.powerFactor, "system", default: ElectricalSystem.threePhase) private var system
    @StoredInput(.powerFactor, "kw", default: "100") private var kw
    @StoredInput(.powerFactor, "existing", default: "75") private var existing
    @StoredInput(.powerFactor, "target", default: "95") private var target
    @StoredInput(.powerFactor, "voltage", default: "480") private var voltage
    @StoredInput(.powerFactor, "frequency", default: "60") private var frequency
    @StoredInput(.powerFactor, "jobName", default: "PF correction") private var jobName
    @State private var session = ExplicitCalculationState<PowerFactorResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(system)|\(kw)|\(existing)|\(target)|\(voltage)|\(frequency)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .powerFactor,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .powerFactor,
                symbolic: "kVAR = kW·(tan θ₁ − tan θ₂)    C = Q / (2πf·V²)",
                substituted: substituted,
                meaning: "Capacitors supply the reactive power the load was drawing from the source, so current and losses drop while real power stays the same."
            )
            MenuField(title: "System", selection: $system, options: [ElectricalSystem.singlePhase, ElectricalSystem.threePhase]) { $0.displayName }
            NumberField(title: "Real power", unit: "kW", text: $kw, fieldID: "kw", onSubmit: calculate)
            NumberField(title: "Existing PF", unit: "%", text: $existing, fieldID: "existing", onSubmit: calculate)
            NumberField(title: "Target PF", unit: "%", text: $target, fieldID: "target", onSubmit: calculate)
            NumberField(title: "Voltage", unit: "V", text: $voltage, fieldID: "voltage", onSubmit: calculate)
            NumberField(title: "Frequency", unit: "Hz", text: $frequency, fieldID: "frequency", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    kw = "100"
                    existing = "75"
                    target = "95"
                    voltage = "480"
                    frequency = "60"
                    session.prepareForNewInputs()
                },
                exampleTitle: "100 kW, 0.75 → 0.95 PF at 480 V"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                if !session.isStale,
                   let kwValue = kw.parsedDouble, kwValue > 0,
                   r.targetKVAR.isFinite, r.newKVA.isFinite, r.newKVA > 0 {
                    PowerTriangleDiagram(
                        kw: kwValue,
                        kvar: r.targetKVAR,
                        kva: r.newKVA,
                        title: "After correction"
                    )
                }
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Correction", value: "\(Format.number(r.correctionKVAR, digits: 2)) kVAR", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Existing reactive", value: "\(Format.number(r.existingKVAR, digits: 2)) kVAR")
                    ResultRow(label: "After correction", value: "\(Format.number(r.targetKVAR, digits: 2)) kVAR")
                    ResultRow(label: "New apparent", value: "\(Format.number(r.newKVA, digits: 2)) kVA")
                    ResultRow(label: "Bank capacitance", value: r.capacitance.isFinite ? "\(Format.number(r.capacitance * 1e6, digits: 2)) µF" : "—")
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .powerFactor,
                        inputs: ["kW": kw, "PF1 %": existing, "PF2 %": target, "V": voltage, "system": system.displayName],
                        outputs: ["kVAR": Format.number(r.correctionKVAR, digits: 2), "kVA": Format.number(r.newKVA, digits: 2)]
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
        session.calculate {
            try PowerFactorCorrection.solve(
                realPowerKW: kw.parsedDouble ?? .nan,
                existingPowerFactor: (existing.parsedDouble ?? .nan) / 100,
                targetPowerFactor: (target.parsedDouble ?? .nan) / 100,
                voltage: voltage.parsedDouble ?? .nan,
                frequency: frequency.parsedDouble ?? .nan,
                system: system
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        kw = ""
        existing = ""
        target = ""
        voltage = ""
        frequency = "60"
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.number(r.correctionKVAR, digits: 2)) kVAR"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.correctionKVAR, digits: 2)) kVAR  ·  \(Format.number(r.newKVA, digits: 1)) kVA"
    }
}

// MARK: - Short-circuit current

struct ShortCircuitView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.shortCircuit, "system", default: ElectricalSystem.threePhase) private var system
    @StoredInput(.shortCircuit, "kva", default: "500") private var kva
    @StoredInput(.shortCircuit, "volts", default: "480") private var volts
    @StoredInput(.shortCircuit, "impedance", default: "5") private var impedance
    @StoredInput(.shortCircuit, "jobName", default: "Fault current") private var jobName
    @State private var session = ExplicitCalculationState<ShortCircuitResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(system)|\(kva)|\(volts)|\(impedance)" }

    var body: some View {
        ToolScaffold(
            toolID: .shortCircuit,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Infinite-bus estimate at the secondary terminals. A real study models source and conductor impedance, which lowers this number."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .shortCircuit,
                symbolic: system == .threePhase
                    ? "I_FLA = kVA·1000 / (√3·V)    I_SC = I_FLA × 100/%Z"
                    : "I_FLA = kVA·1000 / V    I_SC = I_FLA × 100/%Z",
                substituted: substituted,
                meaning: "Assumes an infinite source behind the transformer, so this is the worst case. Equipment interrupting ratings must exceed it."
            )
            MenuField(title: "System", selection: $system, options: [ElectricalSystem.singlePhase, ElectricalSystem.threePhase]) { $0.displayName }
            NumberField(title: "Transformer", unit: "kVA", text: $kva, fieldID: "kva", onSubmit: calculate)
            NumberField(title: "Secondary", unit: "V", text: $volts, fieldID: "volts", onSubmit: calculate)
            NumberField(title: "Impedance", unit: "%", text: $impedance, fieldID: "impedance", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    kva = "500"
                    volts = "480"
                    impedance = "5"
                    session.prepareForNewInputs()
                },
                exampleTitle: "500 kVA, 480 V, 5% Z"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ShortCircuitDiagram(faultAmps: r.availableFaultAmps)
                    .opacity(session.isStale ? 0.72 : 1)
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Available fault", value: "\(Format.number(r.availableFaultAmps, digits: 0)) A", emphasis: true, tone: Theme.bad)
                    ResultRow(label: "In kA", value: "\(Format.number(r.availableFaultAmps / 1000, digits: 2)) kA", emphasis: true)
                    ResultRow(label: "Secondary FLA", value: Format.amps(r.fullLoadAmps))
                    ResultRow(label: "Multiplier", value: "×\(Format.number(r.multiplier, digits: 2))")
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .shortCircuit,
                        inputs: ["kVA": kva, "V": volts, "%Z": impedance, "system": system.displayName],
                        outputs: ["ISC": "\(Format.number(r.availableFaultAmps, digits: 0)) A", "FLA": Format.amps(r.fullLoadAmps)]
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
        session.calculate {
            try ShortCircuit.transformerSecondary(
                kVA: kva.parsedDouble ?? .nan,
                secondaryVolts: volts.parsedDouble ?? .nan,
                impedancePercent: impedance.parsedDouble ?? .nan,
                system: system
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        kva = ""
        volts = ""
        impedance = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "I_FLA = \(Format.amps(r.fullLoadAmps))    I_SC = \(Format.amps(r.fullLoadAmps)) × \(Format.number(r.multiplier, digits: 2)) = \(Format.number(r.availableFaultAmps, digits: 0)) A"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.availableFaultAmps / 1000, digits: 2)) kA available"
    }
}

// MARK: - Circular mils (live)

struct CircularMilsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case fromDiameter = "Diameter → CM"
        case fromCircularMils = "CM → diameter"
        var id: String { rawValue }
    }

    private struct Output: Equatable {
        var circularMils: Double
        var diameterMils: Double
        var squareInches: Double
    }

    @StoredChoice(.circularMils, "mode", default: Mode.fromDiameter) private var mode
    @StoredInput(.circularMils, "diameter", default: "250") private var diameter
    @StoredInput(.circularMils, "cm", default: "62500") private var cm
    @State private var live = LiveCalculationState<Output>()

    private var inputFingerprint: String { "\(mode)|\(diameter)|\(cm)" }

    var body: some View {
        ToolScaffold(toolID: .circularMils, stickyAnswer: sticky, copyText: sticky) {
            ShowWorkCard(
                toolID: .circularMils,
                symbolic: "CM = d(mils)²    A(in²) = π·d(in)²/4",
                substituted: substituted,
                meaning: "A circular mil is the area of a circle one mil across, so the area is just the diameter squared — no π. That is the whole point of the unit."
            )
            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }
            if mode == .fromDiameter {
                NumberField(title: "Diameter", unit: "mils", text: $diameter)
            } else {
                NumberField(title: "Circular mils", unit: "CM", text: $cm)
            }

            if let error = live.error {
                ErrorText(message: error.message)
            } else if let value = live.result {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Circular mils", value: "\(Format.number(value.circularMils, digits: 1)) CM", emphasis: true, tone: Theme.good)
                    ResultRow(label: "kcmil", value: Format.number(value.circularMils / 1000, digits: 2))
                    ResultRow(label: "Diameter", value: "\(Format.number(value.diameterMils, digits: 3)) mils")
                    ResultRow(label: "Diameter", value: "\(Format.number(value.diameterMils / 1000, digits: 5)) in")
                    ResultRow(label: "Area", value: "\(Format.number(value.squareInches, digits: 6)) in²")
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            live.update {
                let circular: Double
                if mode == .fromDiameter {
                    circular = try CircularMils.fromDiameterMils(diameter.parsedDouble ?? .nan)
                } else {
                    circular = try Positive.require(cm.parsedDouble ?? .nan, name: "Circular mils")
                }
                return Output(
                    circularMils: circular,
                    diameterMils: try CircularMils.diameterMils(fromCircularMils: circular),
                    squareInches: try CircularMils.squareInches(fromCircularMils: circular)
                )
            }
        }
        .onAppear {
            live.update {
                let circular: Double
                if mode == .fromDiameter {
                    circular = try CircularMils.fromDiameterMils(diameter.parsedDouble ?? .nan)
                } else {
                    circular = try Positive.require(cm.parsedDouble ?? .nan, name: "Circular mils")
                }
                return Output(
                    circularMils: circular,
                    diameterMils: try CircularMils.diameterMils(fromCircularMils: circular),
                    squareInches: try CircularMils.squareInches(fromCircularMils: circular)
                )
            }
        }
    }

    private var substituted: String? {
        guard let value = live.result else { return nil }
        return "\(Format.number(value.diameterMils, digits: 3)) mils² = \(Format.number(value.circularMils, digits: 1)) CM"
    }

    private var sticky: String? {
        guard let value = live.result else { return nil }
        return "\(Format.number(value.circularMils, digits: 1)) CM  ·  \(Format.number(value.circularMils / 1000, digits: 2)) kcmil"
    }
}

// MARK: - Load and demand factors

struct LoadFactorsView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.loadFactors, "connected", default: "400") private var connected
    @StoredInput(.loadFactors, "demand", default: "250") private var demand
    @StoredInput(.loadFactors, "average", default: "150") private var average
    @StoredInput(.loadFactors, "individual", default: "320") private var individual
    @StoredInput(.loadFactors, "capacity", default: "500") private var capacity
    @StoredInput(.loadFactors, "jobName", default: "Load factors") private var jobName
    @State private var session = ExplicitCalculationState<LoadFactorResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(connected)|\(demand)|\(average)|\(individual)|\(capacity)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .loadFactors,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .loadFactors,
                symbolic: "DF = max demand / connected    LF = average / max demand    Diversity = Σ individual / max demand",
                substituted: substituted,
                meaning: "Demand factor says how much of the connected load actually shows up at once. Load factor says how steady it is. Leave a field blank and its ratio is skipped."
            )
            NumberField(title: "Connected load", unit: "kW", text: $connected, fieldID: "connected", onSubmit: calculate)
            NumberField(title: "Maximum demand", unit: "kW", text: $demand, fieldID: "demand", onSubmit: calculate)
            NumberField(title: "Average load", unit: "kW", text: $average, optional: true, onSubmit: calculate)
            NumberField(title: "Σ individual demands", unit: "kW", text: $individual, optional: true, onSubmit: calculate)
            NumberField(title: "System capacity", unit: "kW", text: $capacity, optional: true, onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    connected = "400"
                    demand = "250"
                    average = "150"
                    individual = "320"
                    capacity = "500"
                    session.prepareForNewInputs()
                },
                exampleTitle: "400 connected, 250 peak, 150 average"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                if !session.isStale,
                   let avg = average.parsedDouble, avg > 0,
                   let peak = demand.parsedDouble, peak > 0,
                   let cap = capacity.parsedDouble, cap > 0 {
                    LoadFactorChart(average: avg, peak: peak, capacity: cap)
                }
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Demand factor", value: Format.number(r.demandFactor, digits: 3), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Load factor", value: r.loadFactor.isFinite ? Format.number(r.loadFactor, digits: 3) : "—")
                    ResultRow(label: "Diversity factor", value: r.diversityFactor.isFinite ? Format.number(r.diversityFactor, digits: 3) : "—")
                    ResultRow(label: "Capacity used", value: r.capacityUtilization.isFinite ? Format.percent(r.capacityUtilization * 100) : "—")
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .loadFactors,
                        inputs: ["connected": connected, "demand": demand, "average": average],
                        outputs: ["DF": Format.number(r.demandFactor, digits: 3)]
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
        session.calculate {
            try LoadFactors.solve(
                connectedLoad: connected.parsedDouble ?? .nan,
                maximumDemand: demand.parsedDouble ?? .nan,
                averageLoad: average.parsedDouble ?? 0,
                sumOfIndividualDemands: individual.parsedDouble ?? 0,
                systemCapacity: capacity.parsedDouble ?? 0
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        connected = ""
        demand = ""
        average = ""
        individual = ""
        capacity = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  DF \(Format.number(r.demandFactor, digits: 3))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "DF \(Format.number(r.demandFactor, digits: 3))"
    }
}

// MARK: - Motor speed & torque

struct MotorSpeedView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case slip = "Speed & slip"
        case torque = "Torque"
        var id: String { rawValue }
    }

    enum Line: String, CaseIterable, Identifiable {
        case sixty = "60 Hz"
        case fifty = "50 Hz"
        var id: String { rawValue }
        var hertz: Double { self == .sixty ? 60 : 50 }
    }

    private enum Output: Equatable {
        case speed(MotorSpeedResult)
        case torque(MotorTorqueResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.motorSpeed, "mode", default: MotorSpeedView.Mode.slip) private var mode
    @StoredChoice(.motorSpeed, "line", default: MotorSpeedView.Line.sixty) private var line
    @StoredInput(.motorSpeed, "poles", default: "4") private var poles
    @StoredInput(.motorSpeed, "rpm", default: "1750") private var rpm
    @StoredInput(.motorSpeed, "hp", default: "10") private var horsepower
    @StoredInput(.motorSpeed, "torqueRPM", default: "1750") private var torqueRPM
    @StoredInput(.motorSpeed, "jobName", default: "Motor") private var jobName
    @State private var session = ExplicitCalculationState<Output>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(line)|\(poles)|\(rpm)|\(horsepower)|\(torqueRPM)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .motorSpeed,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .motorSpeed,
                symbolic: mode == .slip
                    ? "n_s = 120 f / p     slip = (n_s − n) / n_s"
                    : "T (lb·ft) = 5252 · HP / RPM",
                substituted: substituted,
                meaning: mode == .slip
                    ? "An induction motor's rotor always lags the rotating field — that lag is what produces torque. A nameplate 1750 on a 4-pole 60 Hz machine is 1800 synchronous minus about 2.8 % slip."
                    : "5252 is 33 000 ft·lb per minute per horsepower divided by 2π. Torque rises as speed falls for the same power, which is why a gearbox output shaft needs the bigger coupling."
            )
            TryExampleButton(title: "10 HP, 4-pole, 1750 RPM nameplate") {
                mode = .slip
                line = .sixty
                poles = "4"
                rpm = "1750"
                horsepower = "10"
                torqueRPM = "1750"
                session.prepareForNewInputs()
            }

            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }

            if mode == .slip {
                MenuField(title: "Line frequency", selection: $line, options: Line.allCases) { $0.rawValue }
                ThumbButtonRow {
                    ForEach(MotorSpeed.commonPoleCounts, id: \.self) { count in
                        Button("\(count)P") { poles = "\(count)" }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                            .frame(minHeight: Theme.touchTarget)
                    }
                }
                NumberField(title: "Poles", unit: "even", text: $poles, fieldID: "poles", onSubmit: calculate)
                NumberField(title: "Nameplate RPM", unit: "RPM", text: $rpm, fieldID: "rpm", onSubmit: calculate)
            } else {
                NumberField(title: "Horsepower", unit: "HP", text: $horsepower, fieldID: "hp", onSubmit: calculate)
                NumberField(title: "Speed", unit: "RPM", text: $torqueRPM, fieldID: "torqueRPM", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    if mode == .slip {
                        line = .sixty
                        poles = "4"
                        rpm = "1750"
                    } else {
                        horsepower = "10"
                        torqueRPM = "1750"
                    }
                    session.prepareForNewInputs()
                },
                exampleTitle: "4-pole, 1750 RPM"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                switch output {
                case .speed(let r):
                    ResultCard(copyText: sticky) {
                        ResultRow(label: "Synchronous", value: "\(Format.number(r.synchronousRPM, digits: 0)) RPM", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Rotor", value: "\(Format.number(r.rotorRPM, digits: 0)) RPM", emphasis: true)
                        ResultRow(label: "Slip", value: Format.percent(r.slipPercent))
                        ResultRow(label: "Rotor frequency", value: Format.frequency(r.slipFrequency))
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                case .torque(let r):
                    MotorTorqueCurveChart(horsepower: r.horsepower, ratedRPM: r.rpm, ratedTorqueLbFt: r.torqueLbFt)
                        .opacity(session.isStale ? 0.72 : 1)
                    ResultCard(copyText: sticky) {
                        ResultRow(label: "Torque", value: "\(Format.number(r.torqueLbFt, digits: 2)) lb·ft", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Torque", value: "\(Format.number(r.torqueNewtonMetres, digits: 2)) N·m", emphasis: true)
                        ResultRow(label: "At", value: "\(Format.number(r.rpm, digits: 0)) RPM")
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                }
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(output) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            if mode == .slip {
                let poleCount = try WholeCount.parse(poles.parsedDouble ?? .nan, name: "Poles")
                return .speed(try MotorSpeed.slip(
                    frequency: line.hertz,
                    poles: poleCount,
                    nameplateRPM: rpm.parsedDouble ?? .nan
                ))
            }
            return .torque(try MotorTorque.fromHorsepower(
                horsepower.parsedDouble ?? .nan,
                rpm: torqueRPM.parsedDouble ?? .nan
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        poles = ""
        rpm = ""
        horsepower = ""
        torqueRPM = ""
        session.reset()
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .speed(let r):
            return "120 × \(Format.number(line.hertz, digits: 0)) / \(poles) = \(Format.number(r.synchronousRPM, digits: 0)) RPM  →  slip \(Format.percent(r.slipPercent))"
        case .torque(let r):
            return "5252 × \(Format.number(r.horsepower, digits: 2)) / \(Format.number(r.rpm, digits: 0)) = \(Format.number(r.torqueLbFt, digits: 2)) lb·ft"
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .speed(let r):
            return "\(Format.number(r.synchronousRPM, digits: 0)) RPM sync  ·  \(Format.percent(r.slipPercent)) slip"
        case .torque(let r):
            return "\(Format.number(r.torqueLbFt, digits: 2)) lb·ft  ·  \(Format.number(r.torqueNewtonMetres, digits: 2)) N·m"
        }
    }

    private func save(_ output: Output) {
        var outputs: [String: String] = [:]
        switch output {
        case .speed(let r):
            outputs["sync"] = "\(Format.number(r.synchronousRPM, digits: 0)) RPM"
            outputs["slip"] = Format.percent(r.slipPercent)
        case .torque(let r):
            outputs["torque"] = "\(Format.number(r.torqueLbFt, digits: 2)) lb·ft"
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .motorSpeed,
            inputs: mode == .slip
                ? ["poles": poles, "line": line.rawValue, "nameplate": "\(rpm) RPM"]
                : ["hp": horsepower, "rpm": torqueRPM],
            outputs: outputs
        ))
    }
}

// MARK: - RF power & link

struct RFLinkView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case power = "dBm ↔ W"
        case match = "VSWR"
        case path = "Path loss"
        var id: String { rawValue }
    }

    enum PowerEntry: String, CaseIterable, Identifiable {
        case dBm = "dBm"
        case watts = "Watts"
        var id: String { rawValue }
    }

    enum MatchEntry: String, CaseIterable, Identifiable {
        case vswr = "VSWR"
        case returnLoss = "Return loss"
        var id: String { rawValue }
    }

    private enum Output: Equatable {
        case power(RFPowerResult)
        case match(MatchResult)
        case path(PathLossResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.rfLink, "mode", default: RFLinkView.Mode.power) private var mode
    @StoredChoice(.rfLink, "powerEntry", default: RFLinkView.PowerEntry.dBm) private var powerEntry
    @StoredChoice(.rfLink, "matchEntry", default: RFLinkView.MatchEntry.vswr) private var matchEntry
    @StoredInput(.rfLink, "level", default: "30") private var level
    @StoredInput(.rfLink, "impedance", default: "50") private var impedance
    @StoredInput(.rfLink, "match", default: "1.5") private var matchValue
    @StoredInput(.rfLink, "freq", default: "2400") private var frequency
    @StoredInput(.rfLink, "distance", default: "100") private var distance
    @StoredInput(.rfLink, "tx", default: "20") private var transmit
    @StoredInput(.rfLink, "txGain", default: "3") private var txGain
    @StoredInput(.rfLink, "rxGain", default: "3") private var rxGain
    @StoredInput(.rfLink, "jobName", default: "RF link") private var jobName
    @State private var session = ExplicitCalculationState<Output>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(powerEntry)|\(matchEntry)|\(level)|\(impedance)|\(matchValue)|\(frequency)|\(distance)|\(transmit)|\(txGain)|\(rxGain)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .rfLink,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .rfLink,
                symbolic: symbolic,
                substituted: substituted,
                meaning: meaning
            )
            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }

            switch mode {
            case .power: powerInputs
            case .match: matchInputs
            case .path: pathInputs
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
                resultView(for: output)
                    .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(output) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    // MARK: Inputs

    @ViewBuilder
    private var powerInputs: some View {
        MenuField(title: "Enter", selection: $powerEntry, options: PowerEntry.allCases) { $0.rawValue }
        NumberField(
            title: powerEntry == .dBm ? "Level" : "Power",
            unit: powerEntry == .dBm ? "dBm" : "W",
            text: $level,
            allowsScientific: true,
            fieldID: "level",
            onSubmit: calculate
        )
        NumberField(title: "Reference impedance", unit: "Ω", text: $impedance, fieldID: "impedance", onSubmit: calculate)
    }

    @ViewBuilder
    private var matchInputs: some View {
        MenuField(title: "Enter", selection: $matchEntry, options: MatchEntry.allCases) { $0.rawValue }
        NumberField(
            title: matchEntry == .vswr ? "VSWR" : "Return loss",
            unit: matchEntry == .vswr ? ": 1" : "dB",
            text: $matchValue,
            fieldID: "match",
            onSubmit: calculate
        )
    }

    @ViewBuilder
    private var pathInputs: some View {
        NumberField(title: "Frequency", unit: "MHz", text: $frequency, fieldID: "freq", onSubmit: calculate)
        NumberField(title: "Distance", unit: "m", text: $distance, fieldID: "distance", onSubmit: calculate)
        NumberField(title: "Transmit level", unit: "dBm", text: $transmit, optional: true, fieldID: "tx", onSubmit: calculate)
        NumberField(title: "TX antenna gain", unit: "dBi", text: $txGain, optional: true, fieldID: "txGain", onSubmit: calculate)
        NumberField(title: "RX antenna gain", unit: "dBi", text: $rxGain, optional: true, fieldID: "rxGain", onSubmit: calculate)
    }

    // MARK: Results

    @ViewBuilder
    private func resultView(for output: Output) -> some View {
        switch output {
        case .power(let r):
            ResultCard(copyText: sticky) {
                ResultRow(label: "Level", value: "\(Format.number(r.dBm, digits: 2)) dBm", emphasis: true, tone: Theme.good)
                ResultRow(label: "Power", value: "\(Format.number(r.watts, digits: 4)) W", emphasis: true)
                ResultRow(label: "Power", value: "\(Format.number(r.milliwatts, digits: 3)) mW")
                ResultRow(label: "RMS into \(Format.number(r.impedance, digits: 0)) Ω", value: Format.volts(r.voltsRMS))
            }
        case .match(let r):
            if r.vswr > 3 {
                ToolEmptyState(
                    title: "That is a poor match",
                    detail: "Above about 3:1 most transmitters start folding back power to protect the final stage. Check the connector, the feedline, and the antenna tuning before you blame the radio.",
                    systemImage: "exclamationmark.triangle"
                )
            }
            ResultCard(copyText: sticky) {
                ResultRow(
                    label: "VSWR",
                    value: r.vswr.isFinite ? "\(Format.number(r.vswr, digits: 3)) : 1" : "∞ : 1",
                    emphasis: true,
                    tone: r.vswr <= 2 ? Theme.good : Theme.warn
                )
                ResultRow(
                    label: "Return loss",
                    value: r.returnLossDB >= AntennaMatch.perfectMatchReturnLossDB
                        ? "perfect match"
                        : "\(Format.number(r.returnLossDB, digits: 2)) dB",
                    emphasis: true
                )
                ResultRow(label: "|Γ|", value: Format.number(r.reflectionCoefficient, digits: 4))
                ResultRow(label: "Power reflected", value: Format.percent(r.reflectedPowerPercent))
                ResultRow(
                    label: "Mismatch loss",
                    value: r.mismatchLossDB.isFinite ? "\(Format.number(r.mismatchLossDB, digits: 3)) dB" : "all of it"
                )
            }
        case .path(let r):
            PathLossDistanceChart(frequencyMHz: r.frequencyMHz, currentDistance: r.distanceMetres, currentLossDB: r.lossDB)
            ResultCard(copyText: sticky) {
                ResultRow(label: "Path loss", value: "\(Format.number(r.lossDB, digits: 2)) dB", emphasis: true, tone: Theme.good)
                if let received = r.receivedDBm {
                    ResultRow(label: "Received", value: "\(Format.number(received, digits: 2)) dBm", emphasis: true)
                }
                ResultRow(label: "At", value: "\(Format.number(r.frequencyMHz, digits: 0)) MHz, \(Format.meters(r.distanceMetres))")
            }
            ToolEmptyState(
                title: "Free space only",
                detail: "This is the loss with nothing in the way. Walls, floors, foliage, and ground reflections all add to it — treat the number as the best case, not the design margin.",
                systemImage: "info.circle"
            )
        }
    }

    private func calculate() {
        session.calculate {
            switch mode {
            case .power:
                let z = impedance.parsedDouble ?? .nan
                if powerEntry == .dBm {
                    return .power(try RFPower.fromDBm(level.parsedDouble ?? .nan, impedance: z))
                }
                return .power(try RFPower.fromWatts(level.parsedDouble ?? .nan, impedance: z))
            case .match:
                let value = matchValue.parsedDouble ?? .nan
                if matchEntry == .vswr {
                    return .match(try AntennaMatch.fromVSWR(value))
                }
                return .match(try AntennaMatch.fromReturnLoss(value))
            case .path:
                return .path(try FreeSpacePathLoss.loss(
                    frequencyMHz: frequency.parsedDouble ?? .nan,
                    distanceMetres: distance.parsedDouble ?? .nan,
                    transmitDBm: transmit.parsedDouble,
                    transmitGainDBi: txGain.parsedDouble ?? 0,
                    receiveGainDBi: rxGain.parsedDouble ?? 0
                ))
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        level = ""
        matchValue = ""
        frequency = ""
        distance = ""
        transmit = ""
        txGain = ""
        rxGain = ""
        session.reset()
    }

    private func loadExample() {
        switch mode {
        case .power:
            powerEntry = .dBm
            level = "30"
            impedance = "50"
        case .match:
            matchEntry = .vswr
            matchValue = "1.5"
        case .path:
            frequency = "2400"
            distance = "100"
            transmit = "20"
            txGain = "3"
            rxGain = "3"
        }
        session.prepareForNewInputs()
    }

    private var exampleTitle: String {
        switch mode {
        case .power: return "1 W into 50 Ω"
        case .match: return "1.5:1 — a decent antenna"
        case .path: return "2.4 GHz across 100 m"
        }
    }

    private var symbolic: String {
        switch mode {
        case .power: return "P(mW) = 10^(dBm/10)     V_rms = √(P · Z)"
        case .match: return "Γ = (SWR − 1)/(SWR + 1)     RL = −20·log₁₀|Γ|"
        case .path: return "FSPL(dB) = 20·log₁₀(d_km) + 20·log₁₀(f_MHz) + 32.44"
        }
    }

    private var meaning: String {
        switch mode {
        case .power:
            return "dBm is an absolute level, not a ratio — 0 dBm is exactly one milliwatt. Every 3 dB doubles the power and every 10 dB multiplies it by ten, which is why the whole trade works in logs."
        case .match:
            return "VSWR, return loss, and |Γ| are three ways of saying the same thing: how much of the forward power comes straight back at you. 2:1 is about 11 % reflected, which most gear tolerates."
        case .path:
            return "Signal spreads over a sphere, so doubling the distance costs 6 dB — and so does doubling the frequency, because a higher-frequency antenna captures a smaller area for the same gain."
        }
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .power(let r):
            return "\(Format.number(r.dBm, digits: 2)) dBm = \(Format.number(r.watts, digits: 4)) W"
        case .match(let r):
            let swr = r.vswr.isFinite ? Format.number(r.vswr, digits: 3) : "∞"
            return "SWR \(swr):1  →  |Γ| \(Format.number(r.reflectionCoefficient, digits: 3))  →  \(Format.percent(r.reflectedPowerPercent)) reflected"
        case .path(let r):
            return "\(Format.number(r.frequencyMHz, digits: 0)) MHz over \(Format.meters(r.distanceMetres)) = \(Format.number(r.lossDB, digits: 2)) dB"
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .power(let r):
            return "\(Format.number(r.dBm, digits: 2)) dBm  ·  \(Format.number(r.watts, digits: 4)) W"
        case .match(let r):
            let swr = r.vswr.isFinite ? Format.number(r.vswr, digits: 3) : "∞"
            return "\(swr):1  ·  \(Format.number(r.returnLossDB, digits: 2)) dB RL"
        case .path(let r):
            if let received = r.receivedDBm {
                return "\(Format.number(r.lossDB, digits: 2)) dB  ·  \(Format.number(received, digits: 2)) dBm received"
            }
            return "\(Format.number(r.lossDB, digits: 2)) dB"
        }
    }

    private func save(_ output: Output) {
        var outputs: [String: String] = [:]
        var inputs: [String: String] = [:]
        switch output {
        case .power(let r):
            inputs = ["entry": powerEntry.rawValue, "value": level, "Z": impedance]
            outputs = ["dBm": Format.number(r.dBm, digits: 2), "W": Format.number(r.watts, digits: 4)]
        case .match(let r):
            inputs = ["entry": matchEntry.rawValue, "value": matchValue]
            outputs = ["VSWR": r.vswr.isFinite ? Format.number(r.vswr, digits: 3) : "∞", "RL": Format.number(r.returnLossDB, digits: 2)]
        case .path(let r):
            inputs = ["f": "\(frequency) MHz", "d": "\(distance) m", "tx": "\(transmit) dBm"]
            outputs = ["loss": Format.number(r.lossDB, digits: 2)]
        }
        jobs.save(SavedJob(name: jobName, toolID: .rfLink, inputs: inputs, outputs: outputs))
    }
}

// MARK: - Phasor diagram

struct PhasorDiagramView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.phasorDiagram, "mag1", default: "120") private var mag1
    @StoredInput(.phasorDiagram, "angle1", default: "0") private var angle1
    @StoredInput(.phasorDiagram, "mag2", default: "120") private var mag2
    @StoredInput(.phasorDiagram, "angle2", default: "-120") private var angle2
    @StoredInput(.phasorDiagram, "mag3", default: "120") private var mag3
    @StoredInput(.phasorDiagram, "angle3", default: "-240") private var angle3
    @StoredToggle(.phasorDiagram, "useThird", default: true) private var useThird
    @StoredInput(.phasorDiagram, "jobName", default: "Phasor sum") private var jobName
    @State private var session = ExplicitCalculationState<PhasorSumResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mag1)|\(angle1)|\(mag2)|\(angle2)|\(mag3)|\(angle3)|\(useThird)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .phasorDiagram,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .phasorDiagram,
                symbolic: "resultant = Σ (magnitude ∠ angle)",
                substituted: substituted,
                meaning: "Each phasor is a spinning vector frozen at one instant. Adding them the way you add any vectors — real parts together, imaginary parts together — is exactly how three-phase currents combine (or cancel) on a shared neutral."
            )
            TryExampleButton(title: "Balanced 120 V three-phase set") {
                mag1 = "120"; angle1 = "0"
                mag2 = "120"; angle2 = "-120"
                mag3 = "120"; angle3 = "-240"
                useThird = true
                session.prepareForNewInputs()
            }

            NumberField(title: "Phasor 1 magnitude", unit: "", text: $mag1, fieldID: "mag1", onSubmit: calculate)
            NumberField(title: "Phasor 1 angle", unit: "°", text: $angle1, fieldID: "angle1", onSubmit: calculate)
            NumberField(title: "Phasor 2 magnitude", unit: "", text: $mag2, fieldID: "mag2", onSubmit: calculate)
            NumberField(title: "Phasor 2 angle", unit: "°", text: $angle2, fieldID: "angle2", onSubmit: calculate)

            Toggle("Add a third phasor", isOn: $useThird)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            if useThird {
                NumberField(title: "Phasor 3 magnitude", unit: "", text: $mag3, fieldID: "mag3", onSubmit: calculate)
                NumberField(title: "Phasor 3 angle", unit: "°", text: $angle3, fieldID: "angle3", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    mag1 = "120"; angle1 = "0"
                    mag2 = "120"; angle2 = "-120"
                    mag3 = "120"; angle3 = "-240"
                    useThird = true
                    session.prepareForNewInputs()
                },
                exampleTitle: "Balanced 3-phase"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                PhasorPolarDiagram(
                    phasors: r.phasors,
                    resultantMagnitude: r.resultantMagnitude,
                    resultantAngleDegrees: r.resultantAngleDegrees
                )
                .opacity(session.isStale ? 0.72 : 1)
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Resultant magnitude", value: Format.number(r.resultantMagnitude, digits: 3), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Resultant angle", value: Format.degrees(r.resultantAngleDegrees))
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
            var phasors = [
                Phasor(id: 0, label: "1", magnitude: mag1.parsedDouble ?? .nan, angleDegrees: angle1.parsedDouble ?? .nan),
                Phasor(id: 1, label: "2", magnitude: mag2.parsedDouble ?? .nan, angleDegrees: angle2.parsedDouble ?? .nan),
            ]
            if useThird {
                phasors.append(Phasor(id: 2, label: "3", magnitude: mag3.parsedDouble ?? .nan, angleDegrees: angle3.parsedDouble ?? .nan))
            }
            return try PhasorSum.resultant(of: phasors)
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        mag1 = ""; angle1 = ""
        mag2 = ""; angle2 = ""
        mag3 = ""; angle3 = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.phasors.count) phasors  →  \(Format.number(r.resultantMagnitude, digits: 3)) ∠ \(Format.number(r.resultantAngleDegrees, digits: 2))°"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.resultantMagnitude, digits: 3)) ∠ \(Format.number(r.resultantAngleDegrees, digits: 1))°"
    }

    private func save(_ r: PhasorSumResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .phasorDiagram,
            inputs: ["count": "\(r.phasors.count)"],
            outputs: ["magnitude": Format.number(r.resultantMagnitude, digits: 3), "angle": Format.degrees(r.resultantAngleDegrees)]
        ))
    }
}

// MARK: - Battery bank sizing

struct BatteryBankView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.batteryBank, "cellVoltage", default: "3.2") private var cellVoltage
    @StoredInput(.batteryBank, "cellAh", default: "100") private var cellAh
    @StoredInput(.batteryBank, "series", default: "4") private var series
    @StoredInput(.batteryBank, "parallel", default: "1") private var parallel
    @StoredInput(.batteryBank, "dod", default: "80") private var dod
    @StoredInput(.batteryBank, "loadWatts", default: "100") private var loadWatts
    @StoredInput(.batteryBank, "efficiency", default: "95") private var efficiency
    @StoredInput(.batteryBank, "jobName", default: "Battery bank") private var jobName
    @State private var session = ExplicitCalculationState<BatteryBankResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(cellVoltage)|\(cellAh)|\(series)|\(parallel)|\(dod)|\(loadWatts)|\(efficiency)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .batteryBank,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .batteryBank,
                symbolic: "V_bank = S · V_cell     Ah_bank = P · Ah_cell     t = Wh_usable · η / P_load",
                substituted: substituted,
                meaning: "Series strings add voltage without changing amp-hours; parallel strings add amp-hours without changing voltage. Depth of discharge and inverter efficiency both shrink what you actually get to use — a 100 % DoD number is a lab spec, not a runtime plan."
            )
            TryExampleButton(title: "4× 3.2 V / 100 Ah LiFePO4, 100 W load") {
                cellVoltage = "3.2"; cellAh = "100"
                series = "4"; parallel = "1"
                dod = "80"; loadWatts = "100"; efficiency = "95"
                session.prepareForNewInputs()
            }

            NumberField(title: "Cell voltage", unit: "V", text: $cellVoltage, fieldID: "cellVoltage", onSubmit: calculate)
            NumberField(title: "Cell capacity", unit: "Ah", text: $cellAh, fieldID: "cellAh", onSubmit: calculate)
            NumberField(title: "Series count", unit: "cells", text: $series, fieldID: "series", onSubmit: calculate)
            NumberField(title: "Parallel count", unit: "strings", text: $parallel, fieldID: "parallel", onSubmit: calculate)
            NumberField(title: "Usable depth of discharge", unit: "%", text: $dod, fieldID: "dod", onSubmit: calculate)
            NumberField(title: "Load", unit: "W", text: $loadWatts, fieldID: "loadWatts", onSubmit: calculate)
            NumberField(title: "System efficiency", unit: "%", text: $efficiency, optional: true, fieldID: "efficiency", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    cellVoltage = "3.2"; cellAh = "100"
                    series = "4"; parallel = "1"
                    dod = "80"; loadWatts = "100"; efficiency = "95"
                    session.prepareForNewInputs()
                },
                exampleTitle: "4S1P LiFePO4, 100 W"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                BatteryBankChart(usableWattHours: r.usableWattHours, totalWattHours: r.bankWattHours, runtimeHours: r.runtimeHours)
                    .opacity(session.isStale ? 0.72 : 1)
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Bank voltage", value: Format.volts(r.bankVoltage), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Bank capacity", value: "\(Format.number(r.bankAmpHours, digits: 1)) Ah")
                    ResultRow(label: "Total energy", value: "\(Format.number(r.bankWattHours, digits: 0)) Wh")
                    ResultRow(label: "Usable energy", value: "\(Format.number(r.usableWattHours, digits: 0)) Wh")
                    ResultRow(label: "Runtime at load", value: "\(Format.number(r.runtimeHours, digits: 2)) h", emphasis: true)
                    ResultRow(label: "Cell count", value: "\(r.cellCount)")
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
            try BatteryBank.size(
                cellVoltage: cellVoltage.parsedDouble ?? .nan,
                cellAmpHours: cellAh.parsedDouble ?? .nan,
                seriesCount: series.parsedDouble ?? .nan,
                parallelCount: parallel.parsedDouble ?? .nan,
                usableDepthOfDischargePercent: dod.parsedDouble ?? .nan,
                loadWatts: loadWatts.parsedDouble ?? .nan,
                systemEfficiencyPercent: efficiency.parsedDouble ?? 100
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        cellVoltage = ""; cellAh = ""
        series = ""; parallel = ""
        dod = ""; loadWatts = ""; efficiency = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.volts(r.bankVoltage))  ·  \(Format.number(r.bankAmpHours, digits: 1)) Ah  →  \(Format.number(r.runtimeHours, digits: 2)) h at \(loadWatts) W"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.runtimeHours, digits: 2)) h  ·  \(Format.volts(r.bankVoltage))  ·  \(Format.number(r.bankAmpHours, digits: 1)) Ah"
    }

    private func save(_ r: BatteryBankResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .batteryBank,
            inputs: ["cell": "\(cellVoltage) V / \(cellAh) Ah", "config": "\(series)S\(parallel)P", "load": "\(loadWatts) W"],
            outputs: ["bank": Format.volts(r.bankVoltage), "runtime": "\(Format.number(r.runtimeHours, digits: 2)) h"]
        ))
    }
}

// MARK: - Reference library

struct ReferenceLibraryView: View {
    @State private var query = ""

    private var topics: [ReferenceTopic] {
        ReferenceLibrary.matching(query)
    }

    var body: some View {
        ToolScaffold(toolID: .referenceLibrary, disclaimer: .none) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SEARCH")
                    .font(Theme.TypeRole.fieldLabel)
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.muted)
                    TextField("4X, THHN, torque, hazardous…", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Theme.foreground)
                        .accessibilityLabel("Search the reference library")
                }
                .padding(.horizontal, 14)
                .frame(minHeight: Theme.touchTarget)
                .background(Theme.inputFill, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                )
            }

            if topics.isEmpty {
                ToolEmptyState(
                    title: "No match",
                    detail: "Nothing in the reference library matches “\(query)”. Try a code (4X, IP67), a material (THHN), or a topic (hazardous, torque).",
                    systemImage: "magnifyingglass"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(topics) { topic in
                        NavigationLink {
                            ReferenceTopicDetailView(topic: topic)
                        } label: {
                            ReferenceTopicRow(topic: topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ReferenceTopicRow: View {
    let topic: ReferenceTopic

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Text(topic.purpose)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("\(topic.entries.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.muted)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .frame(minHeight: Theme.touchTarget)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(topic.title), \(topic.entries.count) entries")
        .accessibilityHint(topic.purpose)
    }
}

struct ReferenceTopicDetailView: View {
    let topic: ReferenceTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(topic.purpose)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                VStack(spacing: 8) {
                    ForEach(topic.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.code)
                                    .font(.subheadline.weight(.bold).monospaced())
                                    .foregroundStyle(Theme.accent)
                                Spacer(minLength: 8)
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.foreground)
                                    .multilineTextAlignment(.trailing)
                            }
                            Text(entry.detail)
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.code): \(entry.title)")
                        .accessibilityHint(entry.detail)
                    }
                }
                Text("Source: \(topic.source)")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            .padding(Theme.Space.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Magnetic circuit

struct MagneticCircuitView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.magneticCircuit, "mmf", default: "500") private var mmf
    @StoredInput(.magneticCircuit, "length", default: "0.2") private var length
    @StoredInput(.magneticCircuit, "area", default: "1") private var areaCm2
    @StoredInput(.magneticCircuit, "muR", default: "1000") private var muR
    @StoredInput(.magneticCircuit, "jobName", default: "Magnetic circuit") private var jobName
    @State private var session = ExplicitCalculationState<MagneticCircuitResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Entered in cm² since that is how core cross-sections are usually spec'd.
    private var areaSquareMetres: Double { (areaCm2.parsedDouble ?? .nan) * 1e-4 }

    private var inputFingerprint: String { "\(mmf)|\(length)|\(areaCm2)|\(muR)" }

    var body: some View {
        ToolScaffold(
            toolID: .magneticCircuit,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .magneticCircuit,
                symbolic: "R = l / (µ₀ µᵣ A)     Φ = mmf / R     B = Φ / A",
                substituted: substituted,
                meaning: "This is Ohm's law for a magnetic path: mmf plays the role of voltage, flux plays current, reluctance plays resistance. A higher µᵣ core (more iron, less air gap) means less reluctance and more flux for the same mmf."
            )
            TryExampleButton(title: "500 At, 20 cm path, 1 cm², µᵣ 1000") {
                mmf = "500"; length = "0.2"; areaCm2 = "1"; muR = "1000"
                session.prepareForNewInputs()
            }

            NumberField(title: "Magnetomotive force", unit: "At", text: $mmf, fieldID: "mmf", onSubmit: calculate)
            NumberField(title: "Path length", unit: "m", text: $length, fieldID: "length", onSubmit: calculate)
            NumberField(title: "Cross-sectional area", unit: "cm²", text: $areaCm2, fieldID: "area", onSubmit: calculate)
            NumberField(title: "Relative permeability µᵣ", unit: "", text: $muR, fieldID: "muR", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    mmf = "500"; length = "0.2"; areaCm2 = "1"; muR = "1000"
                    session.prepareForNewInputs()
                },
                exampleTitle: "Small relay-sized core"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Reluctance", value: "\(Format.number(r.reluctance, digits: 0)) At/Wb", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Flux", value: "\(Format.number(r.flux * 1000, digits: 4)) mWb")
                    ResultRow(label: "Flux density B", value: "\(Format.number(r.fluxDensity, digits: 3)) T", emphasis: true)
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
            try MagneticCircuit.solve(
                magnetomotiveForce: mmf.parsedDouble ?? .nan,
                pathLength: length.parsedDouble ?? .nan,
                crossSectionalArea: areaSquareMetres,
                relativePermeability: muR.parsedDouble ?? .nan
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        mmf = ""; length = ""; areaCm2 = ""; muR = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "R \(Format.number(r.reluctance, digits: 0)) At/Wb  →  B \(Format.number(r.fluxDensity, digits: 3)) T"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "B \(Format.number(r.fluxDensity, digits: 3)) T  ·  Φ \(Format.number(r.flux * 1000, digits: 4)) mWb"
    }

    private func save(_ r: MagneticCircuitResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .magneticCircuit,
            inputs: ["mmf": "\(mmf) At", "l": "\(length) m", "A": "\(areaCm2) cm²", "muR": muR],
            outputs: ["B": "\(Format.number(r.fluxDensity, digits: 3)) T", "flux": "\(Format.number(r.flux * 1000, digits: 4)) mWb"]
        ))
    }
}

// MARK: - Fiber link / numerical aperture

struct FiberLinkView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.fiberLink, "n1", default: "1.48") private var coreIndex
    @StoredInput(.fiberLink, "n2", default: "1.46") private var claddingIndex
    @StoredInput(.fiberLink, "radius", default: "4.5") private var coreRadius
    @StoredInput(.fiberLink, "wavelength", default: "1310") private var wavelength
    @StoredToggle(.fiberLink, "checkMode", default: true) private var checkMode
    @StoredInput(.fiberLink, "jobName", default: "Fiber link") private var jobName
    @State private var session = ExplicitCalculationState<FiberLinkResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(coreIndex)|\(claddingIndex)|\(coreRadius)|\(wavelength)|\(checkMode)" }

    var body: some View {
        ToolScaffold(
            toolID: .fiberLink,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .fiberLink,
                symbolic: "NA = √(n₁² − n₂²)     θ = arcsin(NA)     V = 2π a NA / λ",
                substituted: substituted,
                meaning: "NA sets the acceptance cone — how much of a light source's spread the fiber can actually capture. The V-number below 2.405 is the textbook single-mode cutoff for step-index fiber."
            )
            TryExampleButton(title: "62.5/125 µm multimode at 1310 nm") {
                coreIndex = "1.48"; claddingIndex = "1.46"
                coreRadius = "4.5"; wavelength = "1310"
                checkMode = true
                session.prepareForNewInputs()
            }

            NumberField(title: "Core index n₁", unit: "", text: $coreIndex, fieldID: "n1", onSubmit: calculate)
            NumberField(title: "Cladding index n₂", unit: "", text: $claddingIndex, fieldID: "n2", onSubmit: calculate)

            Toggle("Check single-mode cutoff", isOn: $checkMode)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            if checkMode {
                NumberField(title: "Core radius", unit: "µm", text: $coreRadius, fieldID: "radius", onSubmit: calculate)
                NumberField(title: "Wavelength", unit: "nm", text: $wavelength, fieldID: "wavelength", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    coreIndex = "1.48"; claddingIndex = "1.46"
                    coreRadius = "4.5"; wavelength = "1310"
                    checkMode = true
                    session.prepareForNewInputs()
                },
                exampleTitle: "Common multimode fiber"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Numerical aperture", value: Format.number(r.numericalAperture, digits: 4), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Acceptance angle", value: Format.degrees(r.acceptanceAngleDegrees))
                    if let v = r.vNumber {
                        ResultRow(label: "V-number", value: Format.number(v, digits: 3))
                    }
                    if let singleMode = r.isSingleMode {
                        ResultRow(
                            label: "Mode",
                            value: singleMode ? "single-mode" : "multimode",
                            emphasis: true,
                            tone: singleMode ? Theme.good : Theme.warn
                        )
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
            try FiberLink.solve(
                coreIndex: coreIndex.parsedDouble ?? .nan,
                claddingIndex: claddingIndex.parsedDouble ?? .nan,
                coreRadiusMicrons: checkMode ? (coreRadius.parsedDouble ?? .nan) : nil,
                wavelengthNanometers: checkMode ? (wavelength.parsedDouble ?? .nan) : nil
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        coreIndex = ""; claddingIndex = ""; coreRadius = ""; wavelength = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        var line = "NA \(Format.number(r.numericalAperture, digits: 4))  →  θ \(Format.degrees(r.acceptanceAngleDegrees))"
        if let v = r.vNumber {
            line += "  →  V \(Format.number(v, digits: 3))"
        }
        return line
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "NA \(Format.number(r.numericalAperture, digits: 4))  ·  \(Format.degrees(r.acceptanceAngleDegrees))"
    }

    private func save(_ r: FiberLinkResult) {
        var outputs = ["NA": Format.number(r.numericalAperture, digits: 4), "angle": Format.degrees(r.acceptanceAngleDegrees)]
        if let v = r.vNumber { outputs["V"] = Format.number(v, digits: 3) }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .fiberLink,
            inputs: ["n1": coreIndex, "n2": claddingIndex],
            outputs: outputs
        ))
    }
}

// MARK: - Gaussian beam

struct GaussianBeamView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.gaussianBeam, "waist", default: "0.5") private var waist
    @StoredInput(.gaussianBeam, "wavelength", default: "633") private var wavelength
    @StoredInput(.gaussianBeam, "distance", default: "") private var distance
    @StoredInput(.gaussianBeam, "jobName", default: "Gaussian beam") private var jobName
    @State private var session = ExplicitCalculationState<GaussianBeamResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(waist)|\(wavelength)|\(distance)" }

    var body: some View {
        ToolScaffold(
            toolID: .gaussianBeam,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .gaussianBeam,
                symbolic: "z_R = π w₀² / λ     θ = λ / (π w₀)     w(z) = w₀√(1 + (z/z_R)²)",
                substituted: substituted,
                meaning: "A real laser beam never stays parallel — it spreads at a rate set entirely by the wavelength and how tightly it's focused at the waist. A tighter waist diverges faster; that trade-off is fixed by the physics, not the laser's power."
            )
            TryExampleButton(title: "0.5 mm waist, 633 nm HeNe") {
                waist = "0.5"; wavelength = "633"; distance = ""
                session.prepareForNewInputs()
            }

            NumberField(title: "Waist radius w₀", unit: "mm", text: $waist, fieldID: "waist", onSubmit: calculate)
            NumberField(title: "Wavelength", unit: "nm", text: $wavelength, fieldID: "wavelength", onSubmit: calculate)
            NumberField(title: "Distance from waist", unit: "mm", text: $distance, optional: true, fieldID: "distance", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    waist = "0.5"; wavelength = "633"; distance = ""
                    session.prepareForNewInputs()
                },
                exampleTitle: "HeNe bench laser"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Rayleigh range", value: "\(Format.number(r.rayleighRange, digits: 2)) mm", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Divergence half-angle", value: "\(Format.number(r.divergenceHalfAngleMilliradians, digits: 3)) mrad")
                    if let radius = r.radiusAtDistance {
                        ResultRow(label: "Radius at distance", value: "\(Format.number(radius, digits: 4)) mm", emphasis: true)
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
            try GaussianBeam.solve(
                waistRadius: waist.parsedDouble ?? .nan,
                wavelengthNanometers: wavelength.parsedDouble ?? .nan,
                propagationDistance: distance.parsedDouble
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        waist = ""; wavelength = ""; distance = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        var line = "z_R \(Format.number(r.rayleighRange, digits: 2)) mm  →  θ \(Format.number(r.divergenceHalfAngleMilliradians, digits: 3)) mrad"
        if let radius = r.radiusAtDistance {
            line += "  →  w(z) \(Format.number(radius, digits: 4)) mm"
        }
        return line
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "z_R \(Format.number(r.rayleighRange, digits: 2)) mm  ·  θ \(Format.number(r.divergenceHalfAngleMilliradians, digits: 3)) mrad"
    }

    private func save(_ r: GaussianBeamResult) {
        var outputs = ["zR": "\(Format.number(r.rayleighRange, digits: 2)) mm", "theta": "\(Format.number(r.divergenceHalfAngleMilliradians, digits: 3)) mrad"]
        if let radius = r.radiusAtDistance { outputs["w(z)"] = "\(Format.number(radius, digits: 4)) mm" }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .gaussianBeam,
            inputs: ["w0": "\(waist) mm", "lambda": "\(wavelength) nm"],
            outputs: outputs
        ))
    }
}

// MARK: - Transient circuits

struct TransientCircuitView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case rc = "RC"
        case rl = "RL"
        var id: String { rawValue }
    }

    enum Direction: String, CaseIterable, Identifiable {
        case charging = "Charging"
        case discharging = "Discharging"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.transientCircuit, "kind", default: TransientCircuitView.Kind.rc) private var kind
    @StoredChoice(.transientCircuit, "direction", default: TransientCircuitView.Direction.charging) private var direction
    @StoredInput(.transientCircuit, "amplitude", default: "12") private var amplitude
    @StoredInput(.transientCircuit, "resistance", default: "1000") private var resistance
    @StoredInput(.transientCircuit, "capacitance", default: "100") private var capacitance
    @StoredInput(.transientCircuit, "inductance", default: "0.5") private var inductance
    @StoredInput(.transientCircuit, "time", default: "0.05") private var time
    @StoredInput(.transientCircuit, "jobName", default: "Transient") private var jobName
    @State private var session = ExplicitCalculationState<TransientResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var farads: Double { (capacitance.parsedDouble ?? .nan) * 1e-6 }
    private var unit: String { kind == .rc ? "V" : "A" }

    private var inputFingerprint: String {
        "\(kind)|\(direction)|\(amplitude)|\(resistance)|\(capacitance)|\(inductance)|\(time)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .transientCircuit,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .transientCircuit,
                symbolic: direction == .charging
                    ? "v(t) = A(1 − e^(−t/τ))"
                    : "v(t) = A · e^(−t/τ)",
                substituted: substituted,
                meaning: "One time constant τ covers about 63 % of the change; five time constants is close enough to call it settled. RC and RL share this exact shape — only what τ is made of changes."
            )
            TryExampleButton(title: "12 V, 1 kΩ, 100 µF, charging at 50 ms") {
                kind = .rc; direction = .charging
                amplitude = "12"; resistance = "1000"; capacitance = "100"; time = "0.05"
                session.prepareForNewInputs()
            }

            MenuField(title: "Circuit", selection: $kind, options: Kind.allCases) { $0.rawValue }
            MenuField(title: "Direction", selection: $direction, options: Direction.allCases) { $0.rawValue }
            NumberField(
                title: direction == .charging ? "Source amplitude" : "Starting value",
                unit: unit,
                text: $amplitude,
                fieldID: "amplitude",
                onSubmit: calculate
            )
            NumberField(title: "Resistance", unit: "Ω", text: $resistance, fieldID: "resistance", onSubmit: calculate)
            if kind == .rc {
                NumberField(title: "Capacitance", unit: "µF", text: $capacitance, fieldID: "capacitance", onSubmit: calculate)
            } else {
                NumberField(title: "Inductance", unit: "H", text: $inductance, fieldID: "inductance", onSubmit: calculate)
            }
            NumberField(title: "Time", unit: "s", text: $time, fieldID: "time", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    kind = .rc; direction = .charging
                    amplitude = "12"; resistance = "1000"; capacitance = "100"; time = "0.05"
                    session.prepareForNewInputs()
                },
                exampleTitle: "RC charging"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                TransientResponseChart(curve: r.curve, currentTime: time.parsedDouble ?? 0, currentValue: r.valueAtTime, unit: unit)
                    .opacity(session.isStale ? 0.72 : 1)
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Time constant τ", value: Format.time(r.timeConstant), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Value at t", value: "\(Format.number(r.valueAtTime, digits: 4)) \(unit)", emphasis: true)
                    ResultRow(label: "Percent complete", value: Format.percent(r.percentComplete))
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
            let tau: Double
            if kind == .rc {
                tau = try TransientCircuit.rcTimeConstant(resistance: resistance.parsedDouble ?? .nan, capacitance: farads)
            } else {
                tau = try TransientCircuit.rlTimeConstant(inductance: inductance.parsedDouble ?? .nan, resistance: resistance.parsedDouble ?? .nan)
            }
            return try TransientCircuit.step(
                amplitude: amplitude.parsedDouble ?? .nan,
                timeConstant: tau,
                time: time.parsedDouble ?? .nan,
                charging: direction == .charging
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        amplitude = ""; resistance = ""; capacitance = ""; inductance = ""; time = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "τ \(Format.time(r.timeConstant))  →  \(Format.number(r.valueAtTime, digits: 4)) \(unit) (\(Format.percent(r.percentComplete)))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.valueAtTime, digits: 4)) \(unit)  ·  \(Format.percent(r.percentComplete))"
    }

    private func save(_ r: TransientResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .transientCircuit,
            inputs: ["circuit": kind.rawValue, "dir": direction.rawValue, "A": amplitude, "t": "\(time) s"],
            outputs: ["tau": Format.time(r.timeConstant), "value": "\(Format.number(r.valueAtTime, digits: 4)) \(unit)"]
        ))
    }
}

// MARK: - E-bus / rack current budget

struct RackCurrentView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.rackCurrent, "capacity", default: "4") private var capacity
    @StoredInput(.rackCurrent, "device1", default: "0.5") private var device1
    @StoredInput(.rackCurrent, "device2", default: "1.2") private var device2
    @StoredInput(.rackCurrent, "device3", default: "0.3") private var device3
    @StoredInput(.rackCurrent, "device4", default: "") private var device4
    @StoredInput(.rackCurrent, "device5", default: "") private var device5
    @StoredInput(.rackCurrent, "device6", default: "") private var device6
    @StoredInput(.rackCurrent, "jobName", default: "Rack current") private var jobName
    @State private var session = ExplicitCalculationState<RackCurrentResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var deviceFields: [Binding<String>] {
        [$device1, $device2, $device3, $device4, $device5, $device6]
    }

    private var inputFingerprint: String {
        "\(capacity)|\(device1)|\(device2)|\(device3)|\(device4)|\(device5)|\(device6)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .rackCurrent,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .rackCurrent,
                symbolic: "total = Σ I_device     headroom = capacity − total",
                substituted: substituted,
                meaning: "The same budget arithmetic whether it's a PLC 5 V logic bus, a 24 VDC panel rail, or a rack backplane — add up every device's continuous draw and see what's left before the bus trips or browns out."
            )
            TryExampleButton(title: "3 devices on a 4 A rail") {
                capacity = "4"; device1 = "0.5"; device2 = "1.2"; device3 = "0.3"
                device4 = ""; device5 = ""; device6 = ""
                session.prepareForNewInputs()
            }

            NumberField(title: "Bus capacity", unit: "A", text: $capacity, fieldID: "capacity", onSubmit: calculate)
            ForEach(Array(deviceFields.enumerated()), id: \.offset) { index, field in
                NumberField(
                    title: "Device \(index + 1)",
                    unit: "A",
                    text: field,
                    optional: true,
                    fieldID: "device\(index + 1)",
                    onSubmit: calculate
                )
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    capacity = "4"; device1 = "0.5"; device2 = "1.2"; device3 = "0.3"
                    device4 = ""; device5 = ""; device6 = ""
                    session.prepareForNewInputs()
                },
                exampleTitle: "3-device rail"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                if r.headroom < 0 {
                    ToolEmptyState(
                        title: "Over budget",
                        detail: "These devices draw more than the bus is rated for. Something will brown out or the protection will trip — move a load to another bus or upsize the supply.",
                        systemImage: "exclamationmark.triangle"
                    )
                }
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Total current", value: Format.amps(r.totalCurrent), emphasis: true, tone: Theme.good)
                    ResultRow(
                        label: "Headroom",
                        value: Format.amps(r.headroom),
                        emphasis: true,
                        tone: r.headroom < 0 ? Theme.bad : Theme.good
                    )
                    ResultRow(
                        label: "Utilization",
                        value: Format.percent(r.utilizationPercent),
                        tone: r.utilizationPercent > 100 ? Theme.bad : (r.utilizationPercent > 80 ? Theme.warn : Theme.foreground)
                    )
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
            let currents = deviceFields.compactMap { $0.wrappedValue.parsedDouble }
            return try RackCurrentBudget.solve(deviceCurrents: currents, busCapacity: capacity.parsedDouble ?? .nan)
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        capacity = ""
        for field in deviceFields { field.wrappedValue = "" }
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.amps(r.totalCurrent)) of \(capacity) A  →  \(Format.percent(r.utilizationPercent))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.amps(r.totalCurrent))  ·  \(Format.amps(r.headroom)) headroom"
    }

    private func save(_ r: RackCurrentResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .rackCurrent,
            inputs: ["capacity": "\(capacity) A"],
            outputs: ["total": Format.amps(r.totalCurrent), "headroom": Format.amps(r.headroom)]
        ))
    }
}

// MARK: - Semiconductor I-V (diode)

struct DiodeIVView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.diodeIV, "saturation", default: "2.5") private var saturationNanoamps
    @StoredInput(.diodeIV, "ideality", default: "1.5") private var ideality
    @StoredInput(.diodeIV, "temperature", default: "300") private var temperature
    @StoredInput(.diodeIV, "voltage", default: "0.6") private var voltage
    @StoredInput(.diodeIV, "jobName", default: "Diode I-V") private var jobName
    @State private var session = ExplicitCalculationState<DiodeIVResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Entered in nanoamps, since saturation current is always a tiny number.
    private var saturationAmps: Double { (saturationNanoamps.parsedDouble ?? .nan) * 1e-9 }

    private var inputFingerprint: String { "\(saturationNanoamps)|\(ideality)|\(temperature)|\(voltage)" }

    var body: some View {
        ToolScaffold(
            toolID: .diodeIV,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .diodeIV,
                symbolic: "I = I_S (e^(V / nV_T) − 1)     V_T = kT / q",
                substituted: substituted,
                meaning: "The exponential is why a diode looks like an open circuit, then suddenly conducts hard over a few tenths of a volt — current changes by orders of magnitude while the voltage barely moves. That flat forward drop is the whole reason diodes make good rough voltage references."
            )
            TryExampleButton(title: "Small-signal diode, n = 1.5, 0.6 V") {
                saturationNanoamps = "2.5"; ideality = "1.5"; temperature = "300"; voltage = "0.6"
                session.prepareForNewInputs()
            }

            NumberField(title: "Saturation current I_S", unit: "nA", text: $saturationNanoamps, fieldID: "saturation", onSubmit: calculate)
            NumberField(title: "Ideality factor n", unit: "", text: $ideality, fieldID: "ideality", onSubmit: calculate)
            NumberField(title: "Temperature", unit: "K", text: $temperature, fieldID: "temperature", onSubmit: calculate)
            NumberField(title: "Forward voltage", unit: "V", text: $voltage, fieldID: "voltage", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    saturationNanoamps = "2.5"; ideality = "1.5"; temperature = "300"; voltage = "0.6"
                    session.prepareForNewInputs()
                },
                exampleTitle: "Typical silicon small-signal diode"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                DiodeIVChart(curve: r.curve, operatingVoltage: voltage.parsedDouble ?? 0, operatingCurrent: r.current)
                    .opacity(session.isStale ? 0.72 : 1)
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Forward current", value: "\(Format.number(r.current * 1000, digits: 4)) mA", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Thermal voltage V_T", value: "\(Format.number(r.thermalVoltage * 1000, digits: 3)) mV")
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
            try DiodeIV.solve(
                saturationCurrent: saturationAmps,
                idealityFactor: ideality.parsedDouble ?? .nan,
                temperatureKelvin: temperature.parsedDouble ?? .nan,
                forwardVoltage: voltage.parsedDouble ?? .nan
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        saturationNanoamps = ""; ideality = ""; temperature = ""; voltage = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "I \(Format.number(r.current * 1000, digits: 4)) mA at \(voltage) V"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.current * 1000, digits: 4)) mA at \(voltage) V"
    }

    private func save(_ r: DiodeIVResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .diodeIV,
            inputs: ["Is": "\(saturationNanoamps) nA", "n": ideality, "T": "\(temperature) K", "V": voltage],
            outputs: ["I": "\(Format.number(r.current * 1000, digits: 4)) mA"]
        ))
    }
}

// MARK: - Intrinsic safety loop verifier

struct ISLoopVerifierView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.isLoopVerifier, "voc", default: "24") private var voc
    @StoredInput(.isLoopVerifier, "isc", default: "100") private var iscMilliamps
    @StoredInput(.isLoopVerifier, "ca", default: "0.5") private var caMicrofarads
    @StoredInput(.isLoopVerifier, "la", default: "5") private var laMillihenries
    @StoredInput(.isLoopVerifier, "vmax", default: "30") private var vmax
    @StoredInput(.isLoopVerifier, "imax", default: "150") private var imaxMilliamps
    @StoredInput(.isLoopVerifier, "ci", default: "20") private var ciNanofarads
    @StoredInput(.isLoopVerifier, "li", default: "1") private var liMillihenries
    @StoredInput(.isLoopVerifier, "cableC", default: "50") private var cableCNanofaradsPerCore
    @StoredInput(.isLoopVerifier, "cableL", default: "1") private var cableLMillihenries
    @StoredInput(.isLoopVerifier, "jobName", default: "IS loop") private var jobName
    @State private var session = ExplicitCalculationState<ISLoopResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var iscAmps: Double { (iscMilliamps.parsedDouble ?? .nan) / 1000 }
    private var caFarads: Double { (caMicrofarads.parsedDouble ?? .nan) * 1e-6 }
    private var laHenries: Double { (laMillihenries.parsedDouble ?? .nan) / 1000 }
    private var imaxAmps: Double { (imaxMilliamps.parsedDouble ?? .nan) / 1000 }
    private var ciFarads: Double { (ciNanofarads.parsedDouble ?? .nan) * 1e-9 }
    private var liHenries: Double { (liMillihenries.parsedDouble ?? .nan) / 1000 }
    private var cableCFarads: Double { (cableCNanofaradsPerCore.parsedDouble ?? .nan) * 1e-9 }
    private var cableLHenries: Double { (cableLMillihenries.parsedDouble ?? .nan) / 1000 }

    private var inputFingerprint: String {
        "\(voc)|\(iscMilliamps)|\(caMicrofarads)|\(laMillihenries)|\(vmax)|\(imaxMilliamps)|\(ciNanofarads)|\(liMillihenries)|\(cableCNanofaradsPerCore)|\(cableLMillihenries)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .isLoopVerifier,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("This checks the four Entity Concept inequalities only — it is not a substitute for the system's control drawing, the equipment's certification documentation, or sign-off by a qualified person."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .isLoopVerifier,
                symbolic: "Voc ≤ Vmax     Isc ≤ Imax     Ca ≥ Ci + Ccable     La ≥ Li + Lcable",
                substituted: substituted,
                meaning: "The barrier can never be allowed to deliver more energy than the field device and wiring can safely absorb in a fault. All four checks must pass — a loop that's fine on voltage and current but fails on cable capacitance is still not safe to install."
            )
            TryExampleButton(title: "Common 24 V zener barrier into a compliant transmitter") {
                voc = "24"; iscMilliamps = "100"; caMicrofarads = "0.5"; laMillihenries = "5"
                vmax = "30"; imaxMilliamps = "150"; ciNanofarads = "20"; liMillihenries = "1"
                cableCNanofaradsPerCore = "50"; cableLMillihenries = "1"
                session.prepareForNewInputs()
            }

            Text("BARRIER / ASSOCIATED APPARATUS")
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            NumberField(title: "Voc", unit: "V", text: $voc, fieldID: "voc", onSubmit: calculate)
            NumberField(title: "Isc", unit: "mA", text: $iscMilliamps, fieldID: "isc", onSubmit: calculate)
            NumberField(title: "Ca", unit: "µF", text: $caMicrofarads, fieldID: "ca", onSubmit: calculate)
            NumberField(title: "La", unit: "mH", text: $laMillihenries, fieldID: "la", onSubmit: calculate)

            Text("FIELD DEVICE")
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            NumberField(title: "Vmax", unit: "V", text: $vmax, fieldID: "vmax", onSubmit: calculate)
            NumberField(title: "Imax", unit: "mA", text: $imaxMilliamps, fieldID: "imax", onSubmit: calculate)
            NumberField(title: "Ci", unit: "nF", text: $ciNanofarads, fieldID: "ci", onSubmit: calculate)
            NumberField(title: "Li", unit: "mH", text: $liMillihenries, fieldID: "li", onSubmit: calculate)

            Text("CABLE")
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            NumberField(title: "Cable capacitance", unit: "nF", text: $cableCNanofaradsPerCore, fieldID: "cableC", onSubmit: calculate)
            NumberField(title: "Cable inductance", unit: "mH", text: $cableLMillihenries, fieldID: "cableL", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    voc = "24"; iscMilliamps = "100"; caMicrofarads = "0.5"; laMillihenries = "5"
                    vmax = "30"; imaxMilliamps = "150"; ciNanofarads = "20"; liMillihenries = "1"
                    cableCNanofaradsPerCore = "50"; cableLMillihenries = "1"
                    session.prepareForNewInputs()
                },
                exampleTitle: "Compliant example loop"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Voltage", value: r.voltageOK ? "OK" : "FAILS", emphasis: true, tone: r.voltageOK ? Theme.good : Theme.bad)
                    ResultRow(label: "Current", value: r.currentOK ? "OK" : "FAILS", emphasis: true, tone: r.currentOK ? Theme.good : Theme.bad)
                    ResultRow(label: "Capacitance", value: r.capacitanceOK ? "OK" : "FAILS", emphasis: true, tone: r.capacitanceOK ? Theme.good : Theme.bad)
                    ResultRow(label: "Inductance", value: r.inductanceOK ? "OK" : "FAILS", emphasis: true, tone: r.inductanceOK ? Theme.good : Theme.bad)
                    ResultRow(label: "Total Ci + Ccable", value: "\(Format.number(r.totalCapacitance * 1e9, digits: 1)) nF")
                    ResultRow(label: "Total Li + Lcable", value: "\(Format.number(r.totalInductance * 1000, digits: 3)) mH")
                }
                .opacity(session.isStale ? 0.72 : 1)
                if !r.isSafe {
                    ToolEmptyState(
                        title: "This combination does not satisfy the Entity Concept",
                        detail: "At least one of Voc/Isc/Ca/La does not clear the field device and cable parameters. Re-check the barrier selection or the cable run — do not install this pairing.",
                        systemImage: "xmark.shield"
                    )
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
            try ISLoopVerifier.verify(
                barrierVoc: voc.parsedDouble ?? .nan,
                barrierIsc: iscAmps,
                barrierCa: caFarads,
                barrierLa: laHenries,
                deviceVmax: vmax.parsedDouble ?? .nan,
                deviceImax: imaxAmps,
                deviceCi: ciFarads,
                deviceLi: liHenries,
                cableCapacitance: cableCFarads,
                cableInductance: cableLHenries
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        voc = ""; iscMilliamps = ""; caMicrofarads = ""; laMillihenries = ""
        vmax = ""; imaxMilliamps = ""; ciNanofarads = ""; liMillihenries = ""
        cableCNanofaradsPerCore = ""; cableLMillihenries = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return r.isSafe ? "All four checks pass" : "At least one check fails — do not install"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return r.isSafe ? "Entity Concept: OK" : "Entity Concept: FAILS"
    }

    private func save(_ r: ISLoopResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .isLoopVerifier,
            inputs: ["Voc": "\(voc) V", "Isc": "\(iscMilliamps) mA", "Vmax": "\(vmax) V", "Imax": "\(imaxMilliamps) mA"],
            outputs: ["result": r.isSafe ? "OK" : "FAILS"]
        ))
    }
}
