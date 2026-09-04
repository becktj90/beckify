import Foundation

// MARK: - Types
//
// Educational servo / process-control math ported from the website
// `controlEngine.ts`. Approximations (RK4 step, Durand–Kerner roots, log Bode
// sweep) — not for safety-critical commissioning.

private let controlEpsilon = 1e-9

public struct ControlComplex: Equatable, Sendable, Hashable {
    public var re: Double
    public var im: Double

    public init(re: Double, im: Double = 0) {
        self.re = re
        self.im = im
    }

    public var magnitude: Double { hypot(re, im) }
    public var phaseDeg: Double { atan2(im, re) * 180 / .pi }
}

public struct ControlTransferFunction: Equatable, Sendable {
    public var numerator: [Double]
    public var denominator: [Double]

    public init(numerator: [Double], denominator: [Double]) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public var order: Int { max(0, denominator.count - 1) }
}

public struct ControlBodePoint: Equatable, Sendable {
    public var omega: Double
    public var magnitudeDb: Double
    public var phaseDeg: Double

    public init(omega: Double, magnitudeDb: Double, phaseDeg: Double) {
        self.omega = omega
        self.magnitudeDb = magnitudeDb
        self.phaseDeg = phaseDeg
    }
}

public struct ControlMargins: Equatable, Sendable {
    public var gainMarginDb: Double?
    public var phaseMarginDeg: Double?
    public var gainCrossover: Double?
    public var phaseCrossover: Double?

    public init(
        gainMarginDb: Double? = nil,
        phaseMarginDeg: Double? = nil,
        gainCrossover: Double? = nil,
        phaseCrossover: Double? = nil
    ) {
        self.gainMarginDb = gainMarginDb
        self.phaseMarginDeg = phaseMarginDeg
        self.gainCrossover = gainCrossover
        self.phaseCrossover = phaseCrossover
    }
}

public struct ControlStepSample: Equatable, Sendable {
    public var t: Double
    public var y: Double

    public init(t: Double, y: Double) {
        self.t = t
        self.y = y
    }
}

public struct ControlPerformance: Equatable, Sendable {
    public var riseTime: Double?
    public var peakTime: Double?
    public var overshoot: Double
    public var settlingTime: Double?
    public var steadyStateError: Double
    public var finalValue: Double

    public init(
        riseTime: Double?,
        peakTime: Double?,
        overshoot: Double,
        settlingTime: Double?,
        steadyStateError: Double,
        finalValue: Double
    ) {
        self.riseTime = riseTime
        self.peakTime = peakTime
        self.overshoot = overshoot
        self.settlingTime = settlingTime
        self.steadyStateError = steadyStateError
        self.finalValue = finalValue
    }
}

public struct ControlPidGains: Equatable, Sendable {
    public var kp: Double
    public var ki: Double
    public var kd: Double

    public init(kp: Double, ki: Double = 0, kd: Double = 0) {
        self.kp = kp
        self.ki = ki
        self.kd = kd
    }
}

public enum ControlControllerMode: String, CaseIterable, Sendable, Hashable {
    case open
    case p
    case pi
    case pid

    public var displayName: String {
        switch self {
        case .open: return "Open loop"
        case .p: return "P"
        case .pi: return "PI"
        case .pid: return "PID"
        }
    }
}

public enum ControlPlantID: String, CaseIterable, Sendable, Hashable, Codable {
    case firstOrder = "first-order"
    case secondOrder = "second-order"
    case integrator = "integrator"
    case dcMotorSpeed = "dc-motor-speed"
    case motorPosition = "motor-position"
    case thermal = "thermal"
    case unstableFirstOrder = "unstable-first-order"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .firstOrder: return "First-order lag"
        case .secondOrder: return "Second-order, lightly damped"
        case .integrator: return "Integrator"
        case .dcMotorSpeed: return "DC motor speed"
        case .motorPosition: return "Motor position"
        case .thermal: return "Thermal process"
        case .unstableFirstOrder: return "Unstable first-order"
        case .custom: return "Custom G(s)"
        }
    }
}

public struct ControlPlant: Equatable, Sendable, Identifiable {
    public var id: ControlPlantID
    public var name: String
    public var summary: String
    public var teaches: String
    public var display: String
    public var transferFunction: ControlTransferFunction
    public var suggested: ControlPidGains
    public var duration: Double

    public var idValue: ControlPlantID { id }
}

public struct ControlPlantSummary: Equatable, Sendable {
    public var plantID: ControlPlantID
    public var name: String
    public var display: String
    public var summary: String
    public var teaches: String
    public var order: Int
    public var dcGain: Double
    public var openLoopStable: Bool
    public var poles: [ControlComplex]
    public var zeros: [ControlComplex]
    public var transferFunction: ControlTransferFunction
    public var duration: Double
    public var suggested: ControlPidGains

    public init(
        plantID: ControlPlantID,
        name: String,
        display: String,
        summary: String,
        teaches: String,
        order: Int,
        dcGain: Double,
        openLoopStable: Bool,
        poles: [ControlComplex],
        zeros: [ControlComplex],
        transferFunction: ControlTransferFunction,
        duration: Double,
        suggested: ControlPidGains
    ) {
        self.plantID = plantID
        self.name = name
        self.display = display
        self.summary = summary
        self.teaches = teaches
        self.order = order
        self.dcGain = dcGain
        self.openLoopStable = openLoopStable
        self.poles = poles
        self.zeros = zeros
        self.transferFunction = transferFunction
        self.duration = duration
        self.suggested = suggested
    }
}

public struct ControlStepResult: Equatable, Sendable {
    public var mode: ControlControllerMode
    public var gains: ControlPidGains
    public var stable: Bool
    public var diverged: Bool
    public var metrics: ControlPerformance?
    public var closedLoop: [PlotPoint]
    public var openLoop: [PlotPoint]
    public var closedLoopTF: ControlTransferFunction
    public var formula: String

    public init(
        mode: ControlControllerMode,
        gains: ControlPidGains,
        stable: Bool,
        diverged: Bool,
        metrics: ControlPerformance?,
        closedLoop: [PlotPoint],
        openLoop: [PlotPoint],
        closedLoopTF: ControlTransferFunction,
        formula: String
    ) {
        self.mode = mode
        self.gains = gains
        self.stable = stable
        self.diverged = diverged
        self.metrics = metrics
        self.closedLoop = closedLoop
        self.openLoop = openLoop
        self.closedLoopTF = closedLoopTF
        self.formula = formula
    }
}

public struct ControlBodeResult: Equatable, Sendable {
    public var magnitude: [PlotPoint]
    public var phase: [PlotPoint]
    public var closedMagnitude: [PlotPoint]
    public var margins: ControlMargins
    public var bandwidth: Double?
    public var closedLoopStable: Bool
    public var relativeStability: String
    public var formula: String

    public init(
        magnitude: [PlotPoint],
        phase: [PlotPoint],
        closedMagnitude: [PlotPoint],
        margins: ControlMargins,
        bandwidth: Double?,
        closedLoopStable: Bool,
        relativeStability: String,
        formula: String
    ) {
        self.magnitude = magnitude
        self.phase = phase
        self.closedMagnitude = closedMagnitude
        self.margins = margins
        self.bandwidth = bandwidth
        self.closedLoopStable = closedLoopStable
        self.relativeStability = relativeStability
        self.formula = formula
    }
}

public struct ControlLeadParts: Equatable, Sendable {
    public var r1: Double
    public var c1: Double
    public var r2: Double
    public var c2: Double
    public var dcGain: Double

    public init(r1: Double, c1: Double, r2: Double, c2: Double, dcGain: Double) {
        self.r1 = r1
        self.c1 = c1
        self.r2 = r2
        self.c2 = c2
        self.dcGain = dcGain
    }
}

public struct ControlLeadResult: Equatable, Sendable {
    public var alpha: Double
    public var timeConstant: Double
    public var compensator: ControlTransferFunction
    public var display: String
    public var parts: ControlLeadParts
    public var plantStep: [PlotPoint]
    public var leadStep: [PlotPoint]
    public var plantMetrics: ControlPerformance
    public var leadMetrics: ControlPerformance
    public var formula: String

    public init(
        alpha: Double,
        timeConstant: Double,
        compensator: ControlTransferFunction,
        display: String,
        parts: ControlLeadParts,
        plantStep: [PlotPoint],
        leadStep: [PlotPoint],
        plantMetrics: ControlPerformance,
        leadMetrics: ControlPerformance,
        formula: String
    ) {
        self.alpha = alpha
        self.timeConstant = timeConstant
        self.compensator = compensator
        self.display = display
        self.parts = parts
        self.plantStep = plantStep
        self.leadStep = leadStep
        self.plantMetrics = plantMetrics
        self.leadMetrics = leadMetrics
        self.formula = formula
    }
}

// MARK: - Plant library

public enum ControlSystems {
    public static let defaultPlantID: ControlPlantID = .secondOrder

    public static let libraryPlants: [ControlPlant] = [
        ControlPlant(
            id: .firstOrder,
            name: "First-order lag",
            summary: "An RC filter, a tank level, a room warming up — one storage element, no oscillation.",
            teaches: "Proportional gain alone leaves a permanent offset. Add integral action and the error goes to zero.",
            display: "1 / (2s + 1)",
            transferFunction: ControlTransferFunction(numerator: [1], denominator: [2, 1]),
            suggested: ControlPidGains(kp: 2, ki: 1, kd: 0),
            duration: 15
        ),
        ControlPlant(
            id: .secondOrder,
            name: "Second-order, lightly damped",
            summary: "ζ = 0.3, ωₙ = 2 rad/s. The textbook ringing response.",
            teaches: "Derivative action damps the ringing. Push Kp up without Kd and the overshoot grows fast.",
            display: "4 / (s² + 1.2s + 4)",
            transferFunction: ControlTransferFunction(numerator: [4], denominator: [1, 1.2, 4]),
            suggested: ControlPidGains(kp: 1, ki: 0.5, kd: 0.4),
            duration: 20
        ),
        ControlPlant(
            id: .integrator,
            name: "Integrator",
            summary: "Velocity in, position out. The output never settles on its own.",
            teaches: "The plant already integrates, so proportional control alone tracks a step with no offset — adding Ki here mostly buys overshoot.",
            display: "1 / s",
            transferFunction: ControlTransferFunction(numerator: [1], denominator: [1, 0]),
            suggested: ControlPidGains(kp: 1, ki: 0, kd: 0),
            duration: 12
        ),
        ControlPlant(
            id: .dcMotorSpeed,
            name: "DC motor speed",
            summary: "Armature dynamics with inertia, damping, and back-EMF. Fast electrical pole, slow mechanical one.",
            teaches: "A stiff plant: the two poles are decades apart, so the loop reacts far faster than the mechanical settling suggests.",
            display: "0.6 / (0.002s² + 0.08s + 0.52)",
            transferFunction: ControlTransferFunction(numerator: [0.6], denominator: [0.002, 0.08, 0.52]),
            suggested: ControlPidGains(kp: 2, ki: 8, kd: 0),
            duration: 2
        ),
        ControlPlant(
            id: .motorPosition,
            name: "Motor position",
            summary: "The same motor driving a position axis — a lag in series with an integrator.",
            teaches: "Classic servo shape. Integral action is rarely needed and usually costs you phase margin.",
            display: "1 / (0.5s² + s)",
            transferFunction: ControlTransferFunction(numerator: [1], denominator: [0.5, 1, 0]),
            suggested: ControlPidGains(kp: 2, ki: 0, kd: 1),
            duration: 12
        ),
        ControlPlant(
            id: .thermal,
            name: "Thermal process",
            summary: "Two cascaded thermal masses, heavily overdamped — an oven or heat exchanger.",
            teaches: "Slow and forgiving. PI is almost always enough; derivative action mostly amplifies sensor noise here.",
            display: "1 / (20s² + 12s + 1)",
            transferFunction: ControlTransferFunction(numerator: [1], denominator: [20, 12, 1]),
            suggested: ControlPidGains(kp: 3, ki: 0.4, kd: 0),
            duration: 90
        ),
        ControlPlant(
            id: .unstableFirstOrder,
            name: "Unstable first-order",
            summary: "A pole in the right half plane — it runs away unless feedback holds it.",
            teaches: "Open loop diverges. Feedback is not an improvement here, it is the only thing making the system usable.",
            display: "1 / (s − 1)",
            transferFunction: ControlTransferFunction(numerator: [1], denominator: [1, -1]),
            suggested: ControlPidGains(kp: 4, ki: 2, kd: 0),
            duration: 12
        ),
    ]

    public static func plant(id: ControlPlantID) -> ControlPlant? {
        libraryPlants.first { $0.id == id }
    }

    /// Highest-power-first coefficients, comma or space separated.
    public static func parsePolynomial(_ input: String) -> [Double] {
        input
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    public static func validateCustom(
        numeratorText: String,
        denominatorText: String
    ) throws -> ControlTransferFunction {
        let numerator = parsePolynomial(numeratorText)
        let denominator = parsePolynomial(denominatorText)
        guard !numerator.isEmpty else {
            throw CalcError.missing("numerator coefficients (highest power first)")
        }
        guard !denominator.isEmpty else {
            throw CalcError.missing("denominator coefficients (highest power first)")
        }
        guard denominator.contains(where: { abs($0) >= 1e-14 }) else {
            throw CalcError.outOfRange("Denominator cannot be all zeros.")
        }
        guard numerator.count <= denominator.count else {
            throw CalcError.outOfRange("Improper TF (num degree > den degree). Add poles or reduce the numerator order.")
        }
        return ControlTransferFunction(numerator: numerator, denominator: denominator)
    }

    public static func resolvePlant(
        id: ControlPlantID,
        numeratorText: String = "",
        denominatorText: String = ""
    ) throws -> ControlPlantSummary {
        let library: ControlPlant
        let tf: ControlTransferFunction
        let name: String
        let display: String
        let summary: String
        let teaches: String
        let duration: Double
        let suggested: ControlPidGains

        if id == .custom {
            tf = try validateCustom(numeratorText: numeratorText, denominatorText: denominatorText)
            library = libraryPlants[1]
            name = "Custom transfer function"
            display = formatTransferFunction(tf)
            summary = "Your coefficients feed every analysis section in this lab."
            teaches = "Highest power first. Example: num 4 and den 1, 1.2, 4 is 4 / (s² + 1.2s + 4)."
            duration = suggestedDuration(for: tf)
            suggested = ControlPidGains(kp: 1, ki: 0.4, kd: 0.2)
        } else if let plant = plant(id: id) {
            library = plant
            tf = plant.transferFunction
            name = plant.name
            display = plant.display
            summary = plant.summary
            teaches = plant.teaches
            duration = plant.duration
            suggested = plant.suggested
        } else {
            throw CalcError.notListed("Unknown plant.")
        }

        let map = poleZeroMap(tf)
        return ControlPlantSummary(
            plantID: id == .custom ? .custom : library.id,
            name: name,
            display: display,
            summary: summary,
            teaches: teaches,
            order: tf.order,
            dcGain: dcGain(tf),
            openLoopStable: isStable(tf),
            poles: map.poles,
            zeros: map.zeros,
            transferFunction: tf,
            duration: duration,
            suggested: suggested
        )
    }

    public static func firstOrderPlant(km: Double, tau: Double) -> ControlTransferFunction {
        ControlTransferFunction(numerator: [km], denominator: [tau, 1])
    }

    public static func secondOrderPlant(wn: Double, zeta: Double, gain: Double = 1) -> ControlTransferFunction {
        let wn2 = wn * wn
        return ControlTransferFunction(numerator: [gain * wn2], denominator: [1, 2 * zeta * wn, wn2])
    }

    // MARK: Polynomials

    public static func normalizePolynomial(_ coefficients: [Double]) -> [Double] {
        var trimmed = coefficients
        while trimmed.count > 1, abs(trimmed[0]) < controlEpsilon {
            trimmed.removeFirst()
        }
        guard let lead = trimmed.first, abs(lead) >= controlEpsilon else { return [0] }
        return trimmed.map { $0 / lead }
    }

    public static func padPolynomial(_ coefficients: [Double], size: Int) -> [Double] {
        if coefficients.count >= size { return Array(coefficients) }
        return Array(repeating: 0, count: size - coefficients.count) + coefficients
    }

    public static func addPolynomials(_ a: [Double], _ b: [Double]) -> [Double] {
        let size = max(a.count, b.count)
        let left = padPolynomial(a, size: size)
        let right = padPolynomial(b, size: size)
        return zip(left, right).map { $0 + $1 }
    }

    public static func multiplyPolynomials(_ a: [Double], _ b: [Double]) -> [Double] {
        guard !a.isEmpty, !b.isEmpty else { return [0] }
        var out = Array(repeating: 0.0, count: a.count + b.count - 1)
        for i in 0..<a.count {
            for j in 0..<b.count {
                out[i + j] += a[i] * b[j]
            }
        }
        return out
    }

    // MARK: Complex / evaluation

    public static func evaluatePolynomial(_ coefficients: [Double], at s: ControlComplex) -> ControlComplex {
        coefficients.reduce(ControlComplex(re: 0, im: 0)) { acc, coeff in
            complexAdd(complexMul(acc, s), ControlComplex(re: coeff))
        }
    }

    public static func evaluateTransferFunction(_ tf: ControlTransferFunction, omega: Double) -> ControlComplex {
        let s = ControlComplex(re: 0, im: omega)
        return complexDiv(evaluatePolynomial(tf.numerator, at: s), evaluatePolynomial(tf.denominator, at: s))
    }

    public static func bodeResponse(
        _ tf: ControlTransferFunction,
        minOmega: Double = 0.1,
        maxOmega: Double = 100,
        points: Int = 140
    ) -> [ControlBodePoint] {
        let count = max(points, 2)
        let ratio = maxOmega / max(minOmega, controlEpsilon)
        return (0..<count).map { index in
            let fraction = Double(index) / Double(count - 1)
            let omega = minOmega * pow(ratio, fraction)
            let response = evaluateTransferFunction(tf, omega: omega)
            return ControlBodePoint(
                omega: omega,
                magnitudeDb: 20 * log10(max(response.magnitude, controlEpsilon)),
                phaseDeg: response.phaseDeg
            )
        }
    }

    public static func computeMargins(_ points: [ControlBodePoint]) -> ControlMargins {
        var margins = ControlMargins()
        guard points.count >= 2 else { return margins }
        for index in 1..<points.count {
            let prev = points[index - 1]
            let next = points[index]
            if (prev.magnitudeDb <= 0 && next.magnitudeDb >= 0) || (prev.magnitudeDb >= 0 && next.magnitudeDb <= 0) {
                let ratio = (0 - prev.magnitudeDb) / ((next.magnitudeDb - prev.magnitudeDb) == 0 ? 1 : (next.magnitudeDb - prev.magnitudeDb))
                let omega = prev.omega + (next.omega - prev.omega) * ratio
                let phase = prev.phaseDeg + (next.phaseDeg - prev.phaseDeg) * ratio
                margins.gainCrossover = omega
                margins.phaseMarginDeg = 180 + phase
            }
            if (prev.phaseDeg <= -180 && next.phaseDeg >= -180) || (prev.phaseDeg >= -180 && next.phaseDeg <= -180) {
                let ratio = (-180 - prev.phaseDeg) / ((next.phaseDeg - prev.phaseDeg) == 0 ? 1 : (next.phaseDeg - prev.phaseDeg))
                let omega = prev.omega + (next.omega - prev.omega) * ratio
                let magnitude = prev.magnitudeDb + (next.magnitudeDb - prev.magnitudeDb) * ratio
                margins.phaseCrossover = omega
                margins.gainMarginDb = -magnitude
            }
        }
        return margins
    }

    public static func closedLoopBandwidth(
        _ openLoop: ControlTransferFunction,
        minOmega: Double = 0.01,
        maxOmega: Double = 500,
        points: Int = 240
    ) -> Double? {
        let closed = closedLoopTransferFunction(openLoop)
        let dc = dcGain(closed)
        guard dc.isFinite, abs(dc) >= controlEpsilon else { return nil }
        let thresholdDb = 20 * log10(max(abs(dc), controlEpsilon)) - 3
        let bode = bodeResponse(closed, minOmega: minOmega, maxOmega: maxOmega, points: points)
        for index in 1..<bode.count {
            let prev = bode[index - 1]
            let next = bode[index]
            if prev.magnitudeDb >= thresholdDb && next.magnitudeDb <= thresholdDb {
                let ratio = (thresholdDb - prev.magnitudeDb) / ((next.magnitudeDb - prev.magnitudeDb) == 0 ? 1 : (next.magnitudeDb - prev.magnitudeDb))
                return prev.omega + (next.omega - prev.omega) * ratio
            }
        }
        return nil
    }

    public static func dcGain(_ tf: ControlTransferFunction) -> Double {
        let num = tf.numerator.last ?? 0
        let den = tf.denominator.last ?? 0
        if abs(den) < controlEpsilon { return .infinity }
        return num / den
    }

    public static func isStable(_ tf: ControlTransferFunction) -> Bool {
        polynomialRoots(tf.denominator).allSatisfy { $0.re < -controlEpsilon }
    }

    public static func poleZeroMap(_ tf: ControlTransferFunction) -> (poles: [ControlComplex], zeros: [ControlComplex]) {
        (polynomialRoots(tf.denominator), polynomialRoots(tf.numerator))
    }

    public static func polynomialRoots(_ coefficients: [Double]) -> [ControlComplex] {
        let normalized = normalizePolynomial(coefficients)
        let order = normalized.count - 1
        if order <= 0 { return [] }
        if order == 1 { return [ControlComplex(re: -normalized[1])] }
        var roots = (0..<order).map { index -> ControlComplex in
            let angle = (2 * Double.pi * Double(index)) / Double(order)
            return ControlComplex(re: cos(angle), im: sin(angle))
        }
        for _ in 0..<120 {
            var maxDelta = 0.0
            roots = roots.enumerated().map { index, root in
                let value = evaluatePolynomial(normalized, at: root)
                var divisor = ControlComplex(re: 1)
                for (currentIndex, current) in roots.enumerated() where currentIndex != index {
                    divisor = complexMul(divisor, complexSub(root, current))
                }
                let next = complexSub(root, complexDiv(value, divisor))
                maxDelta = max(maxDelta, hypot(next.re - root.re, next.im - root.im))
                return next
            }
            if maxDelta < 1e-8 { break }
        }
        return roots
    }

    public static func pidTransferFunction(_ gains: ControlPidGains) -> ControlTransferFunction {
        if abs(gains.ki) < controlEpsilon {
            if abs(gains.kd) < controlEpsilon {
                return ControlTransferFunction(numerator: [gains.kp], denominator: [1])
            }
            return ControlTransferFunction(numerator: [gains.kd, gains.kp], denominator: [1])
        }
        return ControlTransferFunction(numerator: [gains.kd, gains.kp, gains.ki], denominator: [1, 0])
    }

    public static func seriesTransferFunction(
        _ a: ControlTransferFunction,
        _ b: ControlTransferFunction
    ) -> ControlTransferFunction {
        ControlTransferFunction(
            numerator: multiplyPolynomials(a.numerator, b.numerator),
            denominator: multiplyPolynomials(a.denominator, b.denominator)
        )
    }

    public static func closedLoopTransferFunction(_ openLoop: ControlTransferFunction) -> ControlTransferFunction {
        ControlTransferFunction(
            numerator: openLoop.numerator,
            denominator: addPolynomials(openLoop.denominator, openLoop.numerator)
        )
    }

    public static func gainsForMode(_ mode: ControlControllerMode, _ gains: ControlPidGains) -> ControlPidGains {
        switch mode {
        case .open: return ControlPidGains(kp: 0, ki: 0, kd: 0)
        case .p: return ControlPidGains(kp: gains.kp, ki: 0, kd: 0)
        case .pi: return ControlPidGains(kp: gains.kp, ki: gains.ki, kd: 0)
        case .pid: return gains
        }
    }

    public static func leadCompensator(alpha: Double, timeConstant: Double, gain: Double = 1) -> ControlTransferFunction {
        ControlTransferFunction(
            numerator: [gain * timeConstant, gain],
            denominator: [alpha * timeConstant, 1]
        )
    }

    /// Phase-lead placement: α = (1−sin φ)/(1+sin φ), T = 1 / (ωm √α).
    public static func designLeadPhaseBump(phaseDeg: Double, omega: Double) throws -> (alpha: Double, timeConstant: Double, tf: ControlTransferFunction) {
        guard phaseDeg.isFinite else { throw CalcError.missing("a phase bump") }
        guard omega.isFinite, omega > 0 else { throw CalcError.nonPositive("ωm") }
        guard phaseDeg > 0, phaseDeg < 80 else {
            throw CalcError.outOfRange("Phase bump must be between 0° and 80°.")
        }
        let phi = phaseDeg * .pi / 180
        let s = sin(phi)
        let alpha = (1 - s) / (1 + s)
        let timeConstant = 1 / (omega * sqrt(alpha))
        return (alpha, timeConstant, leadCompensator(alpha: alpha, timeConstant: timeConstant))
    }

    public static func leadNetworkParts(alpha: Double, timeConstant: Double, c1: Double = 1e-7) -> ControlLeadParts {
        let c2 = c1
        let r1 = timeConstant / c1
        let r2 = (alpha * timeConstant) / c2
        return ControlLeadParts(r1: r1, c1: c1, r2: r2, c2: c2, dcGain: -r2 / r1)
    }

    public static func formatComplex(_ value: ControlComplex) -> String {
        let real = String(format: "%.3f", value.re)
        let imag = String(format: "%.3f", abs(value.im))
        let sign = value.im >= 0 ? "+" : "−"
        return "\(real) \(sign) \(imag)j"
    }

    public static func formatPolynomial(_ coefficients: [Double]) -> String {
        var terms: [String] = []
        let last = coefficients.count - 1
        for (index, value) in coefficients.enumerated() {
            if abs(value) < controlEpsilon { continue }
            let power = last - index
            let absv = abs(value)
            let coeff: String
            if power != 0, abs(absv - 1) < 1e-9 {
                coeff = value < 0 ? "−" : ""
            } else if absv == absv.rounded(), abs(absv - absv.rounded()) < 1e-9 {
                coeff = "\(value < 0 ? "−" : "")\(Int(absv.rounded()))"
            } else {
                var text = String(format: "%.4g", absv)
                if text.hasSuffix(".0") { text = String(text.dropLast(2)) }
                coeff = "\(value < 0 ? "−" : "")\(text)"
            }
            let mag = coeff.replacingOccurrences(of: "^[−-]", with: "", options: .regularExpression)
            let signed = value < 0 ? "− \(mag.isEmpty && power != 0 ? "1" : (mag.isEmpty ? "0" : mag))" : (mag.isEmpty && power != 0 ? "1" : (mag.isEmpty ? "0" : mag))
            if power == 0 {
                terms.append(signed)
            } else if power == 1 {
                terms.append(signed == "1" ? "s" : "\(signed) s")
            } else {
                terms.append(signed == "1" ? "s^\(power)" : "\(signed) s^\(power)")
            }
        }
        if terms.isEmpty { return "0" }
        return terms.enumerated().map { index, term in
            if index == 0 { return term }
            return term.hasPrefix("−") ? term : "+ \(term)"
        }.joined(separator: " ")
    }

    public static func formatTransferFunction(_ tf: ControlTransferFunction) -> String {
        "(\(formatPolynomial(tf.numerator))) / (\(formatPolynomial(tf.denominator)))"
    }

    public static func formatFinite(_ value: Double?, digits: Int = 2, suffix: String = "") -> String {
        guard let value, value.isFinite else { return "—" }
        return "\(String(format: "%.\(digits)f", value))\(suffix)"
    }

    // MARK: High-level lab analyses

    public static func stepTune(
        plant: ControlTransferFunction,
        mode: ControlControllerMode,
        gains: ControlPidGains,
        duration: Double
    ) throws -> ControlStepResult {
        guard duration.isFinite, duration > 0 else { throw CalcError.nonPositive("Duration") }
        try validateGains(gains, mode: mode)
        let samples = 320
        let dt = duration / Double(samples)
        let openSamples = try simulateStep(plant, duration: duration, dt: dt)
        let closedTF: ControlTransferFunction
        let closedSamples: [ControlStepSample]
        if mode == .open {
            closedTF = plant
            closedSamples = openSamples
        } else {
            let controller = pidTransferFunction(gainsForMode(mode, gains))
            closedTF = closedLoopTransferFunction(seriesTransferFunction(controller, plant))
            closedSamples = try simulateStep(closedTF, duration: duration, dt: dt)
        }
        let diverged = closedSamples.contains { !$0.y.isFinite || abs($0.y) > 1e6 }
        let stable = isStable(closedTF) && !diverged
        let metrics = stable ? computePerformance(closedSamples) : nil
        let formula: String
        switch mode {
        case .open:
            formula = "Open loop: Y(s) = G(s) · 1/s"
        case .p:
            formula = "T(s) = Kp G / (1 + Kp G)"
        case .pi:
            formula = "C(s) = Kp + Ki/s    T = CG / (1 + CG)"
        case .pid:
            formula = "C(s) = Kp + Ki/s + Kd s    T = CG / (1 + CG)"
        }
        return ControlStepResult(
            mode: mode,
            gains: gainsForMode(mode, gains),
            stable: stable,
            diverged: diverged,
            metrics: metrics,
            closedLoop: closedSamples.map { PlotPoint(x: $0.t, y: $0.y) },
            openLoop: openSamples.map { PlotPoint(x: $0.t, y: $0.y) },
            closedLoopTF: closedTF,
            formula: formula
        )
    }

    public static func bodeAnalysis(
        plant: ControlTransferFunction,
        loopGain: Double = 1
    ) throws -> ControlBodeResult {
        guard loopGain.isFinite, loopGain >= 0 else { throw CalcError.outOfRange("Loop gain K must be zero or positive.") }
        let openLoop = seriesTransferFunction(
            ControlTransferFunction(numerator: [loopGain], denominator: [1]),
            plant
        )
        let closed = closedLoopTransferFunction(openLoop)
        let bode = bodeResponse(plant, minOmega: 0.05, maxOmega: 200, points: 120)
        let closedBode = bodeResponse(closed, minOmega: 0.05, maxOmega: 200, points: 120)
        let margins = computeMargins(bodeResponse(openLoop, minOmega: 0.05, maxOmega: 200, points: 180))
        let omegaB = closedLoopBandwidth(openLoop)
        let relative: String
        if let pm = margins.phaseMarginDeg {
            if pm < 0 {
                relative = "Negative phase margin: the closed loop is expected to be unstable."
            } else if pm < 30 {
                relative = "Thin phase margin: expect ringing and a long settle."
            } else if pm < 60 {
                relative = "Moderate phase margin: a usable but still lively loop."
            } else {
                relative = "Comfortable phase margin: the closed loop should look well damped."
            }
        } else {
            relative = "No gain crossover on this sweep — the loop may never reach |KG|=1."
        }
        return ControlBodeResult(
            magnitude: bode.map { PlotPoint(x: $0.omega, y: $0.magnitudeDb) },
            phase: bode.map { PlotPoint(x: $0.omega, y: $0.phaseDeg) },
            closedMagnitude: closedBode.map { PlotPoint(x: $0.omega, y: $0.magnitudeDb) },
            margins: margins,
            bandwidth: omegaB,
            closedLoopStable: isStable(closed),
            relativeStability: relative,
            formula: "PM = 180° + ∠G(jωc)    GM = −|G(jωpc)|dB    ωb : |T| = |T(0)|/√2"
        )
    }

    public static func leadDesign(
        plant: ControlTransferFunction,
        phaseDeg: Double,
        omega: Double,
        duration: Double
    ) throws -> ControlLeadResult {
        let designed = try designLeadPhaseBump(phaseDeg: phaseDeg, omega: omega)
        let parts = leadNetworkParts(alpha: designed.alpha, timeConstant: designed.timeConstant)
        let compensated = seriesTransferFunction(designed.tf, plant)
        let closedPlant = closedLoopTransferFunction(plant)
        let closedLead = closedLoopTransferFunction(compensated)
        let dt = max(duration / 280.0, 0.005)
        let plantStep = try simulateStep(closedPlant, duration: duration, dt: dt)
        let leadStep = try simulateStep(closedLead, duration: duration, dt: dt)
        return ControlLeadResult(
            alpha: designed.alpha,
            timeConstant: designed.timeConstant,
            compensator: designed.tf,
            display: formatTransferFunction(designed.tf),
            parts: parts,
            plantStep: plantStep.map { PlotPoint(x: $0.t, y: $0.y) },
            leadStep: leadStep.map { PlotPoint(x: $0.t, y: $0.y) },
            plantMetrics: computePerformance(plantStep),
            leadMetrics: computePerformance(leadStep),
            formula: "α = (1 − sin φ) / (1 + sin φ)    T = 1 / (ωm √α)    Gc = (T s + 1) / (α T s + 1)"
        )
    }

    public static func simulateStep(
        _ tf: ControlTransferFunction,
        duration: Double,
        dt: Double
    ) throws -> [ControlStepSample] {
        guard duration.isFinite, duration > 0 else { throw CalcError.nonPositive("Duration") }
        guard dt.isFinite, dt > 0 else { throw CalcError.nonPositive("Time step") }
        let system = transferFunctionToStateSpace(tf)
        return simulateStateSpaceStep(system, duration: duration, dt: dt)
    }

    public static func computePerformance(_ samples: [ControlStepSample], target: Double = 1) -> ControlPerformance {
        let finalValue = samples.last?.y ?? 0
        let ten = target * 0.1
        let ninety = target * 0.9
        let riseStart = samples.first { $0.y >= ten }?.t
        let riseEnd = samples.first { $0.y >= ninety }?.t
        let peak = samples.max(by: { $0.y < $1.y }) ?? ControlStepSample(t: 0, y: 0)
        let overshoot = target == 0 ? 0 : max(0, ((peak.y - target) / max(abs(target), controlEpsilon)) * 100)
        var settlingTime: Double?
        let band = abs(target) * 0.02
        let settleBand = band > 0 ? band : 0.02
        for index in stride(from: samples.count - 1, through: 0, by: -1) {
            if abs(samples[index].y - target) > settleBand {
                settlingTime = index + 1 < samples.count ? samples[index + 1].t : nil
                break
            }
        }
        return ControlPerformance(
            riseTime: riseStart != nil && riseEnd != nil ? riseEnd! - riseStart! : nil,
            peakTime: peak.t,
            overshoot: overshoot,
            settlingTime: settlingTime,
            steadyStateError: abs(target - finalValue),
            finalValue: finalValue
        )
    }

    public static func transferFunctionToStateSpace(_ tf: ControlTransferFunction) -> ControlStateSpace {
        var rawDenominator = tf.denominator
        while rawDenominator.count > 1, abs(rawDenominator[0]) < controlEpsilon {
            rawDenominator.removeFirst()
        }
        let lead = abs(rawDenominator.first ?? 0) < controlEpsilon ? 1 : rawDenominator[0]
        let denominator = normalizePolynomial(tf.denominator)
        let numerator = padPolynomial(tf.numerator.map { $0 / lead }, size: denominator.count)
        let order = denominator.count - 1
        if order < 1 {
            let d = numerator.last ?? 0
            let den = denominator.last ?? 1
            return ControlStateSpace(a: [[0]], b: [[0]], c: [[0]], d: [[d / den]])
        }
        var a = Array(repeating: Array(repeating: 0.0, count: order), count: order)
        for row in 0..<(order - 1) {
            a[row][row + 1] = 1
        }
        let trailing = denominator.dropFirst().map { -$0 }
        a[order - 1] = Array(trailing.reversed())
        var b = Array(repeating: [0.0], count: order)
        b[order - 1][0] = 1
        let direct = numerator[0]
        let adjusted = numerator.dropFirst().enumerated().map { index, value in
            value - direct * denominator[index + 1]
        }
        let c = [Array(adjusted.reversed())]
        let d = [[direct]]
        return ControlStateSpace(a: a, b: b, c: c, d: d)
    }
}

public struct ControlStateSpace: Equatable, Sendable {
    public var a: [[Double]]
    public var b: [[Double]]
    public var c: [[Double]]
    public var d: [[Double]]

    public init(a: [[Double]], b: [[Double]], c: [[Double]], d: [[Double]]) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }
}

// MARK: - Internals

private func complexAdd(_ a: ControlComplex, _ b: ControlComplex) -> ControlComplex {
    ControlComplex(re: a.re + b.re, im: a.im + b.im)
}

private func complexSub(_ a: ControlComplex, _ b: ControlComplex) -> ControlComplex {
    ControlComplex(re: a.re - b.re, im: a.im - b.im)
}

private func complexMul(_ a: ControlComplex, _ b: ControlComplex) -> ControlComplex {
    ControlComplex(re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re)
}

private func complexDiv(_ a: ControlComplex, _ b: ControlComplex) -> ControlComplex {
    let denom = b.re * b.re + b.im * b.im
    if abs(denom) < controlEpsilon { return ControlComplex(re: .infinity, im: .infinity) }
    return ControlComplex(re: (a.re * b.re + a.im * b.im) / denom, im: (a.im * b.re - a.re * b.im) / denom)
}

private func zeros(_ rows: Int, _ cols: Int) -> [[Double]] {
    Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
}

private func addMatrices(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
    a.enumerated().map { rowIndex, row in
        row.enumerated().map { colIndex, value in
            value + (b[rowIndex][colIndex])
        }
    }
}

private func scaleMatrix(_ matrix: [[Double]], _ scalar: Double) -> [[Double]] {
    matrix.map { $0.map { $0 * scalar } }
}

private func multiplyMatrices(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
    let rows = a.count
    let cols = b.first?.count ?? 0
    let inner = b.count
    var out = zeros(rows, cols)
    for row in 0..<rows {
        for col in 0..<cols {
            var sum = 0.0
            for index in 0..<inner {
                sum += a[row][index] * b[index][col]
            }
            out[row][col] = sum
        }
    }
    return out
}

private func vectorFromMatrix(_ matrix: [[Double]]) -> [Double] {
    matrix.map { $0.first ?? 0 }
}

private func matrixFromVector(_ vector: [Double]) -> [[Double]] {
    vector.map { [$0] }
}

private func rk4Step(a: [[Double]], b: [[Double]], x: [Double], u: Double, dt: Double) -> [Double] {
    func dx(_ state: [Double]) -> [Double] {
        let derivative = addMatrices(multiplyMatrices(a, matrixFromVector(state)), scaleMatrix(b, u))
        return vectorFromMatrix(derivative)
    }
    let k1 = dx(x)
    var k2In = [Double]()
    var k3In = [Double]()
    var k4In = [Double]()
    k2In.reserveCapacity(x.count)
    k3In.reserveCapacity(x.count)
    k4In.reserveCapacity(x.count)
    for index in 0..<x.count {
        k2In.append(x[index] + k1[index] * dt * 0.5)
    }
    let k2 = dx(k2In)
    for index in 0..<x.count {
        k3In.append(x[index] + k2[index] * dt * 0.5)
    }
    let k3 = dx(k3In)
    for index in 0..<x.count {
        k4In.append(x[index] + k3[index] * dt)
    }
    let k4 = dx(k4In)
    var next = [Double]()
    next.reserveCapacity(x.count)
    for index in 0..<x.count {
        let weighted = k1[index] + 2 * k2[index] + 2 * k3[index] + k4[index]
        next.append(x[index] + (weighted * dt) / 6)
    }
    return next
}

private func simulateStateSpaceStep(
    _ system: ControlStateSpace,
    duration: Double,
    dt: Double,
    inputAmplitude: Double = 1
) -> [ControlStepSample] {
    var samples: [ControlStepSample] = []
    var x = Array(repeating: 0.0, count: system.a.count)
    var time = 0.0
    let end = duration + controlEpsilon
    while time <= end {
        let y = (multiplyMatrices(system.c, matrixFromVector(x)).first?.first ?? 0)
            + (system.d.first?.first ?? 0) * inputAmplitude
        samples.append(ControlStepSample(t: time, y: y))
        x = rk4Step(a: system.a, b: system.b, x: x, u: inputAmplitude, dt: dt)
        time += dt
    }
    return samples
}

private func suggestedDuration(for tf: ControlTransferFunction) -> Double {
    if tf.order <= 1 {
        let tau = abs(tf.denominator.first ?? 1)
        return max(8, tau * 6)
    }
    return 12
}

private func validateGains(_ gains: ControlPidGains, mode: ControlControllerMode) throws {
    guard gains.kp.isFinite else { throw CalcError.missing("Kp") }
    if mode == .pi || mode == .pid {
        guard gains.ki.isFinite else { throw CalcError.missing("Ki") }
    }
    if mode == .pid {
        guard gains.kd.isFinite else { throw CalcError.missing("Kd") }
    }
    guard gains.kp >= 0, gains.ki >= 0, gains.kd >= 0 else {
        throw CalcError.outOfRange("PID gains must be zero or positive.")
    }
}
