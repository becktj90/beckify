import SwiftUI
import BeckifyMath

// MARK: - Reactance and resonance

struct ReactanceView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case series = "Series Z"
        case resonance = "Resonance"
        var id: String { rawValue }
    }

    private enum Output: Equatable, Sendable {
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
    @State private var session = ExplicitCalculationSession<Output>()
    @State private var successTick = 0

    private var farads: Double { (capacitance.parsedDouble ?? .nan) * 1e-6 }
    private var fingerprint: String {
        "\(mode.rawValue)|\(frequency)|\(resistance)|\(inductance)|\(capacitance)"
    }
    private var display: ExplicitCalculationSession<Output>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .reactance,
            stickyAnswer: sticky,
            copyText: sticky,
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
                toolID: .reactance,
                symbolic: mode == .series
                    ? "X_L = 2πfL    X_C = 1/(2πfC)    Z = √(R² + (X_L − X_C)²)"
                    : "f₀ = 1/(2π√(LC))    Q = (1/R)√(L/C)    BW = f₀/Q",
                substituted: substituted,
                meaning: mode == .series
                    ? "Net reactance is inductive when X_L wins, and the angle is positive — current lags."
                    : "At resonance X_L and X_C cancel and the circuit looks resistive. Q is the sharpness of that peak."
            )
            TryExampleButton(title: "60 Hz, 10 Ω, 100 mH, 100 µF") {
                frequency = "60"
                resistance = "10"
                inductance = "0.1"
                capacitance = "100"
            }
            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }
            if mode == .series {
                NumberField(title: "Frequency", unit: "Hz", text: $frequency)
            }
            NumberField(title: "Resistance", unit: "Ω", text: $resistance, optional: mode == .resonance)
            NumberField(title: "Inductance", unit: "H", text: $inductance)
            NumberField(title: "Capacitance", unit: "µF", text: $capacitance)

            switch display {
            case .current(let output), .stale(let output):
                ResultCard(copyText: sticky) { rows(for: output) }
                diagrams(for: output)
                SaveJobBar(jobName: $jobName, canSave: true) { save(output) }
            case .idle:
                ToolEmptyState(
                    title: "Set R, L, and C",
                    detail: "Choose series impedance or resonance, then Calculate.",
                    systemImage: "waveform.path"
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
            if mode == .series {
                return .series(try Reactance.series(
                    frequency: frequency.parsedDouble ?? .nan,
                    resistance: resistance.parsedDouble ?? 0,
                    inductance: inductance.parsedDouble ?? .nan,
                    capacitance: farads
                ))
            }
            return .resonance(try Reactance.resonance(
                inductance: inductance.parsedDouble ?? .nan,
                capacitance: farads,
                resistance: resistance.parsedDouble ?? .nan
            ))
        }
        if case .current = session.display(for: fingerprint) { successTick += 1 }
    }

    private func reset() {
        session.reset()
        frequency = "60"
        resistance = "10"
        inductance = "0.1"
        capacitance = "100"
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

    @ViewBuilder
    private func diagrams(for output: Output) -> some View {
        switch output {
        case .series(let r):
            PhasorDiagramView(
                resistance: max(resistance.parsedDouble ?? 0, 0),
                netReactance: r.netReactance.isFinite ? r.netReactance : 0
            )
        case .resonance(let r):
            if r.frequency.isFinite {
                ResonanceCurveView(frequency: r.frequency, bandwidth: r.bandwidth)
            }
        }
    }

    private var substituted: String? {
        guard case .current(let output) = display else { return nil }
        switch output {
        case .series(let r):
            return "X_L = \(Format.number(r.inductiveReactance, digits: 3)) Ω    Z = \(Format.number(r.impedance, digits: 3)) Ω ∠ \(Format.number(r.phaseAngleDegrees, digits: 2))°"
        case .resonance(let r):
            return "f₀ = \(Format.frequency(r.frequency))    Q = \(Format.number(r.qualityFactor, digits: 3))"
        }
    }

    private var sticky: String? {
        switch display {
        case .current(let output), .stale(let output):
            switch output {
            case .series(let r):
                return r.impedance.isFinite ? "Z \(Format.number(r.impedance, digits: 3)) Ω ∠ \(Format.number(r.phaseAngleDegrees, digits: 1))°" : "Open circuit"
            case .resonance(let r):
                return "f₀ \(Format.frequency(r.frequency))"
            }
        default:
            return nil
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
    @State private var session = ExplicitCalculationSession<PowerFactorResult>()
    @State private var successTick = 0

    private var fingerprint: String {
        "\(system.rawValue)|\(kw)|\(existing)|\(target)|\(voltage)|\(frequency)"
    }
    private var display: ExplicitCalculationSession<PowerFactorResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .powerFactor,
            stickyAnswer: sticky,
            copyText: sticky,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.lastError,
                    successTick: successTick,
                    onCalculate: calculate,
                    onReset: {
                        session.reset()
                        kw = "100"; existing = "75"; target = "95"; voltage = "480"; frequency = "60"
                    }
                )
            }
        ) {
            ShowWorkCard(
                toolID: .powerFactor,
                symbolic: "kVAR = kW·(tan θ₁ − tan θ₂)    C = Q / (2πf·V²)",
                substituted: substituted,
                meaning: "Capacitors supply the reactive power the load was drawing from the source, so current and losses drop while real power stays the same."
            )
            TryExampleButton(title: "100 kW, 0.75 → 0.95 PF at 480 V") {
                kw = "100"; existing = "75"; target = "95"; voltage = "480"
            }
            MenuField(title: "System", selection: $system, options: [ElectricalSystem.singlePhase, ElectricalSystem.threePhase]) { $0.displayName }
            NumberField(title: "Real power", unit: "kW", text: $kw)
            NumberField(title: "Existing PF", unit: "%", text: $existing)
            NumberField(title: "Target PF", unit: "%", text: $target)
            NumberField(title: "Voltage", unit: "V", text: $voltage)
            NumberField(title: "Frequency", unit: "Hz", text: $frequency)

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Correction", value: "\(Format.number(r.correctionKVAR, digits: 2)) kVAR", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Existing reactive", value: "\(Format.number(r.existingKVAR, digits: 2)) kVAR")
                    ResultRow(label: "After correction", value: "\(Format.number(r.targetKVAR, digits: 2)) kVAR")
                    ResultRow(label: "New apparent", value: "\(Format.number(r.newKVA, digits: 2)) kVA")
                    ResultRow(label: "Bank capacitance", value: r.capacitance.isFinite ? "\(Format.number(r.capacitance * 1e6, digits: 2)) µF" : "—")
                }
                PowerTriangleView(
                    realKW: kw.parsedDouble ?? 0,
                    reactiveKVAR: r.existingKVAR,
                    title: "Before",
                    summary: "Power triangle before correction. Real \(kw) kW, reactive \(Format.number(r.existingKVAR, digits: 2)) kVAR."
                )
                PowerTriangleView(
                    realKW: kw.parsedDouble ?? 0,
                    reactiveKVAR: r.targetKVAR,
                    title: "After",
                    summary: "Power triangle after correction. Real \(kw) kW, reactive \(Format.number(r.targetKVAR, digits: 2)) kVAR."
                )
                SaveJobBar(jobName: $jobName, canSave: true) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .powerFactor,
                        inputs: ["kW": kw, "PF1 %": existing, "PF2 %": target, "V": voltage, "system": system.displayName],
                        outputs: ["kVAR": Format.number(r.correctionKVAR, digits: 2), "kVA": Format.number(r.newKVA, digits: 2)]
                    ))
                }
            case .idle:
                ToolEmptyState(title: "Enter load and PF targets", detail: "Press Calculate to size the capacitor bank.", systemImage: "arrow.triangle.2.circlepath")
            case .failed:
                EmptyView()
            }
        }
    }

    private var isStale: Bool { if case .stale = display { return true }; return false }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            try PowerFactorCorrection.solve(
                realPowerKW: kw.parsedDouble ?? .nan,
                existingPowerFactor: (existing.parsedDouble ?? .nan) / 100,
                targetPowerFactor: (target.parsedDouble ?? .nan) / 100,
                voltage: voltage.parsedDouble ?? .nan,
                frequency: frequency.parsedDouble ?? 60,
                system: system
            )
        }
        if case .current = session.display(for: fingerprint) { successTick += 1 }
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "kVAR = \(Format.number(kw.parsedDouble ?? .nan, digits: 1)) × (tan θ₁ − tan θ₂) = \(Format.number(r.correctionKVAR, digits: 2)) kVAR"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "\(Format.number(r.correctionKVAR, digits: 2)) kVAR  ·  \(Format.number(r.newKVA, digits: 1)) kVA"
        default: return nil
        }
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
    @State private var session = ExplicitCalculationSession<ShortCircuitResult>()
    @State private var successTick = 0

    private var fingerprint: String { "\(system.rawValue)|\(kva)|\(volts)|\(impedance)" }
    private var display: ExplicitCalculationSession<ShortCircuitResult>.Display { session.display(for: fingerprint) }
    private var isStale: Bool { if case .stale = display { return true }; return false }

    var body: some View {
        ToolScaffold(
            toolID: .shortCircuit,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Infinite-bus estimate at the secondary terminals. A real study models source and conductor impedance, which lowers this number."),
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.lastError,
                    successTick: successTick,
                    onCalculate: {
                        session.calculate(fingerprint: fingerprint) {
                            try ShortCircuit.transformerSecondary(
                                kVA: kva.parsedDouble ?? .nan,
                                secondaryVolts: volts.parsedDouble ?? .nan,
                                impedancePercent: impedance.parsedDouble ?? .nan,
                                system: system
                            )
                        }
                        if case .current = session.display(for: fingerprint) { successTick += 1 }
                    },
                    onReset: {
                        session.reset()
                        kva = "500"; volts = "480"; impedance = "5"
                    }
                )
            }
        ) {
            ShowWorkCard(
                toolID: .shortCircuit,
                symbolic: system == .threePhase
                    ? "I_FLA = kVA·1000 / (√3·V)    I_SC = I_FLA × 100/%Z"
                    : "I_FLA = kVA·1000 / V    I_SC = I_FLA × 100/%Z",
                substituted: substituted,
                meaning: "Assumes an infinite source behind the transformer, so this is the worst case. Equipment interrupting ratings must exceed it."
            )
            TryExampleButton(title: "500 kVA, 480 V, 5% Z") {
                kva = "500"; volts = "480"; impedance = "5"
            }
            MenuField(title: "System", selection: $system, options: [ElectricalSystem.singlePhase, ElectricalSystem.threePhase]) { $0.displayName }
            NumberField(title: "Transformer", unit: "kVA", text: $kva)
            NumberField(title: "Secondary", unit: "V", text: $volts)
            NumberField(title: "Impedance", unit: "%", text: $impedance)

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Available fault", value: "\(Format.number(r.availableFaultAmps, digits: 0)) A", emphasis: true, tone: Theme.fault)
                    ResultRow(label: "In kA", value: "\(Format.number(r.availableFaultAmps / 1000, digits: 2)) kA", emphasis: true)
                    ResultRow(label: "Secondary FLA", value: Format.amps(r.fullLoadAmps))
                    ResultRow(label: "Multiplier", value: "×\(Format.number(r.multiplier, digits: 2))")
                }
                SaveJobBar(jobName: $jobName, canSave: true) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .shortCircuit,
                        inputs: ["kVA": kva, "V": volts, "%Z": impedance, "system": system.displayName],
                        outputs: ["ISC": "\(Format.number(r.availableFaultAmps, digits: 0)) A", "FLA": Format.amps(r.fullLoadAmps)]
                    ))
                }
            case .idle:
                ToolEmptyState(title: "Enter transformer data", detail: "Calculate for the infinite-bus secondary fault current.", systemImage: "bolt.trianglebadge.exclamationmark")
            case .failed:
                EmptyView()
            }
        }
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "I_FLA = \(Format.amps(r.fullLoadAmps))    I_SC = \(Format.amps(r.fullLoadAmps)) × \(Format.number(r.multiplier, digits: 2)) = \(Format.number(r.availableFaultAmps, digits: 0)) A"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "\(Format.number(r.availableFaultAmps / 1000, digits: 2)) kA available"
        default: return nil
        }
    }
}

// MARK: - Circular mils (live)

struct CircularMilsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case fromDiameter = "Diameter → CM"
        case fromCircularMils = "CM → diameter"
        var id: String { rawValue }
    }

    @StoredChoice(.circularMils, "mode", default: Mode.fromDiameter) private var mode
    @StoredInput(.circularMils, "diameter", default: "250") private var diameter
    @StoredInput(.circularMils, "cm", default: "62500") private var cm

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

            switch result {
            case .success(let value):
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Circular mils", value: "\(Format.number(value.circularMils, digits: 1)) CM", emphasis: true, tone: Theme.good)
                    ResultRow(label: "kcmil", value: Format.number(value.circularMils / 1000, digits: 2))
                    ResultRow(label: "Diameter", value: "\(Format.number(value.diameterMils, digits: 3)) mils")
                    ResultRow(label: "Diameter", value: "\(Format.number(value.diameterMils / 1000, digits: 5)) in")
                    ResultRow(label: "Area", value: "\(Format.number(value.squareInches, digits: 6)) in²")
                }
            case .failure(let error):
                ErrorText(message: error.message)
            }
        }
    }

    private struct Output: Equatable {
        var circularMils: Double
        var diameterMils: Double
        var squareInches: Double
    }

    private var result: Result<Output, CalcError> {
        CalcCatch.run {
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

    private var substituted: String? {
        guard case .success(let value) = result else { return nil }
        return "\(Format.number(value.diameterMils, digits: 3)) mils² = \(Format.number(value.circularMils, digits: 1)) CM"
    }

    private var sticky: String? {
        guard case .success(let value) = result else { return nil }
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
    @State private var session = ExplicitCalculationSession<LoadFactorResult>()
    @State private var successTick = 0

    private var fingerprint: String { "\(connected)|\(demand)|\(average)|\(individual)|\(capacity)" }
    private var display: ExplicitCalculationSession<LoadFactorResult>.Display { session.display(for: fingerprint) }
    private var isStale: Bool { if case .stale = display { return true }; return false }

    var body: some View {
        ToolScaffold(
            toolID: .loadFactors,
            stickyAnswer: sticky,
            copyText: sticky,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.lastError,
                    successTick: successTick,
                    onCalculate: {
                        session.calculate(fingerprint: fingerprint) {
                            try LoadFactors.solve(
                                connectedLoad: connected.parsedDouble ?? .nan,
                                maximumDemand: demand.parsedDouble ?? .nan,
                                averageLoad: average.parsedDouble ?? 0,
                                sumOfIndividualDemands: individual.parsedDouble ?? 0,
                                systemCapacity: capacity.parsedDouble ?? 0
                            )
                        }
                        if case .current = session.display(for: fingerprint) { successTick += 1 }
                    },
                    onReset: {
                        session.reset()
                        connected = "400"; demand = "250"; average = "150"; individual = "320"; capacity = "500"
                    }
                )
            }
        ) {
            ShowWorkCard(
                toolID: .loadFactors,
                symbolic: "DF = max demand / connected    LF = average / max demand    Diversity = Σ individual / max demand",
                substituted: substituted,
                meaning: "Demand factor says how much of the connected load actually shows up at once. Load factor says how steady it is. Leave a field blank and its ratio is skipped."
            )
            TryExampleButton(title: "400 connected, 250 peak, 150 average") {
                connected = "400"; demand = "250"; average = "150"; individual = "320"; capacity = "500"
            }
            NumberField(title: "Connected load", unit: "kW", text: $connected)
            NumberField(title: "Maximum demand", unit: "kW", text: $demand)
            NumberField(title: "Average load", unit: "kW", text: $average, optional: true)
            NumberField(title: "Σ individual demands", unit: "kW", text: $individual, optional: true)
            NumberField(title: "System capacity", unit: "kW", text: $capacity, optional: true)

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Demand factor", value: Format.number(r.demandFactor, digits: 3), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Load factor", value: r.loadFactor.isFinite ? Format.number(r.loadFactor, digits: 3) : "—")
                    ResultRow(label: "Diversity factor", value: r.diversityFactor.isFinite ? Format.number(r.diversityFactor, digits: 3) : "—")
                    ResultRow(label: "Capacity used", value: r.capacityUtilization.isFinite ? Format.percent(r.capacityUtilization * 100) : "—")
                }
                LoadFactorProfileView(
                    connected: connected.parsedDouble ?? 0,
                    demand: demand.parsedDouble ?? 0,
                    average: average.parsedDouble ?? 0,
                    capacity: capacity.parsedDouble ?? 0
                )
                SaveJobBar(jobName: $jobName, canSave: true) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .loadFactors,
                        inputs: ["connected": connected, "demand": demand, "average": average],
                        outputs: ["DF": Format.number(r.demandFactor, digits: 3)]
                    ))
                }
            case .idle:
                ToolEmptyState(title: "Enter metered loads", detail: "Calculate demand, load, and diversity factors.", systemImage: "chart.bar.xaxis")
            case .failed:
                EmptyView()
            }
        }
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "DF = \(demand) / \(connected) = \(Format.number(r.demandFactor, digits: 3))"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "DF \(Format.number(r.demandFactor, digits: 3))"
        default: return nil
        }
    }
}
