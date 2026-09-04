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
