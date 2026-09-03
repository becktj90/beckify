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
