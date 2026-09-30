import Foundation

// MARK: - Strategy guide
//
// Field-tech comparison of common control strategies. Qualitative on purpose:
// the matrix, the decision, and the sketches are a design aid. They are not a
// commissioned tune and they do not guarantee stability on a real plant.
// DRL / PINN / ML-MPC entries explain when those methods come up. This module
// does not train or store a policy.

public enum ControlStrategyID: String, CaseIterable, Sendable, Hashable, Codable, Identifiable {
    case bangBang
    case pid
    case mpc
    case fuzzy
    case slidingMode
    case drl
    case adrc
    case nnAdaptive

    public var id: String { rawValue }
}

public enum ControlFit: String, Sendable, Hashable {
    /// Used this way on real jobs.
    case typical
    /// Possible, usually with a specialist or a compromise.
    case possible
    /// A poor match for that constraint.
    case poor
}

public enum ControlMatrixAxis: String, CaseIterable, Sendable, Hashable, Identifiable {
    case model
    case tuning
    case settling
    case overshoot
    case steadyState
    case chattering
    case disturbance
    case compute
    case maintainability

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .model: return "Model"
        case .tuning: return "Tuning"
        case .settling: return "Settling"
        case .overshoot: return "Overshoot"
        case .steadyState: return "ess"
        case .chattering: return "Chatter"
        case .disturbance: return "Disturbance"
        case .compute: return "Compute"
        case .maintainability: return "Field care"
        }
    }

    public func cell(_ profile: ControlStrategyProfile) -> String {
        switch self {
        case .model: return profile.model
        case .tuning: return profile.tuning
        case .settling: return profile.settling
        case .overshoot: return profile.overshoot
        case .steadyState: return profile.steadyState
        case .chattering: return profile.chattering
        case .disturbance: return profile.disturbance
        case .compute: return profile.compute
        case .maintainability: return profile.maintainability
        }
    }
}

public struct ControlStrategyProfile: Equatable, Sendable, Identifiable {
    public var id: ControlStrategyID
    public var title: String
    public var shortName: String
    public var model: String
    public var tuning: String
    public var settling: String
    public var overshoot: String
    public var steadyState: String
    public var chattering: String
    public var disturbance: String
    public var compute: String
    public var maintainability: String
    public var summary: String
    public var limit: String
    /// Learned methods stay explanatory. No weights ship with the app.
    public var explanatoryOnly: Bool
    public var linear: ControlFit
    public var nonlinear: ControlFit
    public var siso: ControlFit
    public var mimo: ControlFit
    public var fastLoop: ControlFit
    public var processLoop: ControlFit

    public init(
        id: ControlStrategyID,
        title: String,
        shortName: String,
        model: String,
        tuning: String,
        settling: String,
        overshoot: String,
        steadyState: String,
        chattering: String,
        disturbance: String,
        compute: String,
        maintainability: String,
        summary: String,
        limit: String,
        explanatoryOnly: Bool,
        linear: ControlFit,
        nonlinear: ControlFit,
        siso: ControlFit,
        mimo: ControlFit,
        fastLoop: ControlFit,
        processLoop: ControlFit
    ) {
        self.id = id
        self.title = title
        self.shortName = shortName
        self.model = model
        self.tuning = tuning
        self.settling = settling
        self.overshoot = overshoot
        self.steadyState = steadyState
        self.chattering = chattering
        self.disturbance = disturbance
        self.compute = compute
        self.maintainability = maintainability
        self.summary = summary
        self.limit = limit
        self.explanatoryOnly = explanatoryOnly
        self.linear = linear
        self.nonlinear = nonlinear
        self.siso = siso
        self.mimo = mimo
        self.fastLoop = fastLoop
        self.processLoop = processLoop
    }
}

public enum ControlLinearityPick: String, CaseIterable, Sendable, Hashable {
    case any
    case linear
    case nonlinear

    public var displayName: String {
        switch self {
        case .any: return "Any"
        case .linear: return "Linear"
        case .nonlinear: return "Nonlinear"
        }
    }
}

public enum ControlChannelPick: String, CaseIterable, Sendable, Hashable {
    case any
    case siso
    case mimo

    public var displayName: String {
        switch self {
        case .any: return "Any"
        case .siso: return "SISO"
        case .mimo: return "MIMO"
        }
    }
}

public enum ControlLoopPick: String, CaseIterable, Sendable, Hashable {
    case any
    case fast
    case process

    public var displayName: String {
        switch self {
        case .any: return "Any"
        case .fast: return "< 1 ms"
        case .process: return "> 1 s"
        }
    }
}

public enum ControlLoopPace: String, CaseIterable, Sendable, Hashable {
    case fast
    case mid
    case process

    public var displayName: String {
        switch self {
        case .fast: return "< 1 ms loop"
        case .mid: return "Milliseconds to ~1 s"
        case .process: return "> 1 s process loop"
        }
    }
}

public enum ControlChannelClass: String, CaseIterable, Sendable, Hashable {
    case siso
    case mimo

    public var displayName: String {
        switch self {
        case .siso: return "SISO — one loop"
        case .mimo: return "MIMO — coupled loops"
        }
    }
}

public enum ControlPlantCharacter: String, CaseIterable, Sendable, Hashable {
    case linear
    case nonlinear

    public var displayName: String {
        switch self {
        case .linear: return "Linear, or close"
        case .nonlinear: return "Nonlinear / operating point moves"
        }
    }
}

public enum ControlModelAvailability: String, CaseIterable, Sendable, Hashable {
    case none
    case rough
    case stateSpace
    case learned

    public var displayName: String {
        switch self {
        case .none: return "No model"
        case .rough: return "Rough — gain, lag, or FOPDT"
        case .stateSpace: return "State-space or step model you can write"
        case .learned: return "Learned model or simulator"
        }
    }
}

public enum ControlDisturbanceDemand: String, CaseIterable, Sendable, Hashable {
    case mild
    case strong

    public var displayName: String {
        switch self {
        case .mild: return "Mild upset"
        case .strong: return "Strong or changing upset"
        }
    }
}

public enum ControlActuatorKind: String, CaseIterable, Sendable, Hashable {
    case onOff
    case modulating

    public var displayName: String {
        switch self {
        case .onOff: return "On / off"
        case .modulating: return "Modulating (valve, VFD, PWM)"
        }
    }
}

public enum ControlFieldPriority: String, CaseIterable, Sendable, Hashable {
    case maintain
    case tracking
    case constraints

    public var displayName: String {
        switch self {
        case .maintain: return "A tech has to retune it"
        case .tracking: return "Tracking matters most"
        case .constraints: return "Limits and coordination"
        }
    }
}

public struct ControlStrategyConstraints: Equatable, Sendable {
    public var loop: ControlLoopPace
    public var channels: ControlChannelClass
    public var plant: ControlPlantCharacter
    public var model: ControlModelAvailability
    public var disturbance: ControlDisturbanceDemand
    public var actuator: ControlActuatorKind
    public var priority: ControlFieldPriority

    public init(
        loop: ControlLoopPace,
        channels: ControlChannelClass,
        plant: ControlPlantCharacter,
        model: ControlModelAvailability,
        disturbance: ControlDisturbanceDemand,
        actuator: ControlActuatorKind,
        priority: ControlFieldPriority
    ) {
        self.loop = loop
        self.channels = channels
        self.plant = plant
        self.model = model
        self.disturbance = disturbance
        self.actuator = actuator
        self.priority = priority
    }

    /// Opens on the ordinary field case: one slow modulating loop and a rough model.
    public static let fieldDefault = ControlStrategyConstraints(
        loop: .process,
        channels: .siso,
        plant: .linear,
        model: .rough,
        disturbance: .mild,
        actuator: .modulating,
        priority: .maintain
    )
}

public struct ControlStrategyRecommendation: Equatable, Sendable {
    public var primary: ControlStrategyID
    /// Extra label when the family has a specific shape (gain-scheduled PID, ML-MPC).
    public var variant: String?
    public var reasons: [String]
    public var alternate: ControlStrategyID
    public var alternateReason: String
    /// True when the next useful screen is the existing PID / Bode lab.
    public var opensControlSystemsLab: Bool
    /// Always false. This module never ships a trained policy.
    public var shipsTrainedPolicy: Bool
    public var caution: String

    public init(
        primary: ControlStrategyID,
        variant: String?,
        reasons: [String],
        alternate: ControlStrategyID,
        alternateReason: String,
        opensControlSystemsLab: Bool,
        shipsTrainedPolicy: Bool,
        caution: String
    ) {
        self.primary = primary
        self.variant = variant
        self.reasons = reasons
        self.alternate = alternate
        self.alternateReason = alternateReason
        self.opensControlSystemsLab = opensControlSystemsLab
        self.shipsTrainedPolicy = shipsTrainedPolicy
        self.caution = caution
    }

    public var headline: String {
        if let variant, !variant.isEmpty { return variant }
        return ControlStrategyGuide.profile(primary).title
    }
}

public struct ControlApplicationNote: Equatable, Sendable, Identifiable {
    public var id: String
    public var industry: String
    public var example: String
    public var loop: String
    public var channels: String
    public var strategy: ControlStrategyID
    public var why: String

    public init(
        id: String,
        industry: String,
        example: String,
        loop: String,
        channels: String,
        strategy: ControlStrategyID,
        why: String
    ) {
        self.id = id
        self.industry = industry
        self.example = example
        self.loop = loop
        self.channels = channels
        self.strategy = strategy
        self.why = why
    }
}

public struct ControlComputePoint: Equatable, Sendable, Identifiable {
    public var id: ControlStrategyID
    public var compute: Double
    public var tracking: Double

    public init(id: ControlStrategyID, compute: Double, tracking: Double) {
        self.id = id
        self.compute = compute
        self.tracking = tracking
    }
}

public struct ControlStrategyTrace: Equatable, Sendable {
    public var id: ControlStrategyID
    public var output: [PlotPoint]
    public var actuator: [PlotPoint]
    public var switchCount: Int
    public var lateAbsoluteError: Double
    public var lateSpread: Double

    public init(
        id: ControlStrategyID,
        output: [PlotPoint],
        actuator: [PlotPoint],
        switchCount: Int,
        lateAbsoluteError: Double,
        lateSpread: Double
    ) {
        self.id = id
        self.output = output
        self.actuator = actuator
        self.switchCount = switchCount
        self.lateAbsoluteError = lateAbsoluteError
        self.lateSpread = lateSpread
    }
}

public struct ControlStrategyStepSketch: Equatable, Sendable {
    public var reference: Double
    public var disturbance: Double
    public var disturbanceTime: Double
    public var band: Double
    public var bangBang: ControlStrategyTrace
    public var pid: ControlStrategyTrace
    public var adrc: ControlStrategyTrace
    public var note: String

    public init(
        reference: Double,
        disturbance: Double,
        disturbanceTime: Double,
        band: Double,
        bangBang: ControlStrategyTrace,
        pid: ControlStrategyTrace,
        adrc: ControlStrategyTrace,
        note: String
    ) {
        self.reference = reference
        self.disturbance = disturbance
        self.disturbanceTime = disturbanceTime
        self.band = band
        self.bangBang = bangBang
        self.pid = pid
        self.adrc = adrc
        self.note = note
    }
}

public struct ControlHysteresisLoop: Equatable, Sendable {
    public var band: Double
    public var samples: [PlotPoint]
    public var risingTrip: Double
    public var fallingTrip: Double

    public init(band: Double, samples: [PlotPoint], risingTrip: Double, fallingTrip: Double) {
        self.band = band
        self.samples = samples
        self.risingTrip = risingTrip
        self.fallingTrip = fallingTrip
    }
}

public struct ControlSlidingSketch: Equatable, Sendable {
    public var boundary: Double
    public var lambda: Double
    public var phase: [PlotPoint]
    public var actuator: [PlotPoint]
    public var surface: [PlotPoint]
    public var upperBand: [PlotPoint]
    public var lowerBand: [PlotPoint]
    /// Mean |Δu| after the reach phase. Larger means more chatter.
    public var chatterIndex: Double

    public init(
        boundary: Double,
        lambda: Double,
        phase: [PlotPoint],
        actuator: [PlotPoint],
        surface: [PlotPoint],
        upperBand: [PlotPoint],
        lowerBand: [PlotPoint],
        chatterIndex: Double
    ) {
        self.boundary = boundary
        self.lambda = lambda
        self.phase = phase
        self.actuator = actuator
        self.surface = surface
        self.upperBand = upperBand
        self.lowerBand = lowerBand
        self.chatterIndex = chatterIndex
    }
}

public enum ControlStrategyGuide {
    public static let noTrainedPolicy = "This app does not train, download, or run a learned policy. The note is when-to-use only."

    public static let computeSketchNote = "Relative on-device cost versus how clean the textbook lag looks. Not a FLOP count, not your PLC, and not a score that says one method wins."

    public static let industryOrder = ["HVAC", "Motor drives", "Robotics", "Flight / launch", "BMS"]

    public static var profiles: [ControlStrategyProfile] {
        ControlStrategyID.allCases.map(profile)
    }

    public static func profile(_ id: ControlStrategyID) -> ControlStrategyProfile {
        switch id {
        case .bangBang:
            return ControlStrategyProfile(
                id: id,
                title: "Bang-bang / hysteresis",
                shortName: "Bang",
                model: "None",
                tuning: "Band width",
                settling: "Limit cycle",
                overshoot: "To the rail",
                steadyState: "Inside band",
                chattering: "By design",
                disturbance: "Weak",
                compute: "A compare",
                maintainability: "Easy",
                summary: "On/off with a deadband. Furnace, heater stage, bleed resistor, cheap thermostat. The process variable hunts inside the band.",
                limit: "Widening the band cuts relay wear and slows the chatter. The error grows with the band. Not a modulating valve.",
                explanatoryOnly: false,
                linear: .typical,
                nonlinear: .possible,
                siso: .typical,
                mimo: .poor,
                fastLoop: .typical,
                processLoop: .typical
            )
        case .pid:
            return ControlStrategyProfile(
                id: id,
                title: "PID / gain-scheduled PID",
                shortName: "PID",
                model: "Gain or FOPDT",
                tuning: "Kp Ki Kd",
                settling: "Tunable",
                overshoot: "Tunable",
                steadyState: "~0 with I",
                chattering: "No",
                disturbance: "Fair (I)",
                compute: "A few flops",
                maintainability: "Easy",
                summary: "The loop most panels already have. One channel, a modulating output, gains a technician can write down. Schedule the gains when the operating point moves.",
                limit: "The Control Systems lab sketches one plant and one tune. It is not an autotune and it does not prove your hardware is stable.",
                explanatoryOnly: false,
                linear: .typical,
                nonlinear: .possible,
                siso: .typical,
                mimo: .possible,
                fastLoop: .typical,
                processLoop: .typical
            )
        case .mpc:
            return ControlStrategyProfile(
                id: id,
                title: "MPC",
                shortName: "MPC",
                model: "Prediction model",
                tuning: "Horizon, weights",
                settling: "Looks ahead",
                overshoot: "Penalize it",
                steadyState: "Model-dependent",
                chattering: "No",
                disturbance: "Good if modeled",
                compute: "QP each scan",
                maintainability: "Specialist",
                summary: "A short forecast plus limits. Chiller plants, coordinated valves, launch constraints, a pack with several limits. Someone has to own the model after startup.",
                limit: "A stale model is worse than a boring PID. Sub-millisecond scans rarely have time for a horizon solve. Explicit MPC is a specialist job.",
                explanatoryOnly: false,
                linear: .typical,
                nonlinear: .possible,
                siso: .possible,
                mimo: .typical,
                fastLoop: .poor,
                processLoop: .typical
            )
        case .fuzzy:
            return ControlStrategyProfile(
                id: id,
                title: "Fuzzy / ANFIS",
                shortName: "Fuzzy",
                model: "Rule table",
                tuning: "Memberships",
                settling: "Rule-dependent",
                overshoot: "Usually soft",
                steadyState: "Often a band",
                chattering: "Low",
                disturbance: "Fair",
                compute: "Rule eval",
                maintainability: "Linguistic",
                summary: "Useful when the operator can say “if temperature is high and rising, close a little” and nobody has a transfer function. ANFIS fits those rules from data.",
                limit: "This app does not fit an ANFIS. A bad rule hides inside ordinary language. Step it with limits in place.",
                explanatoryOnly: false,
                linear: .possible,
                nonlinear: .typical,
                siso: .typical,
                mimo: .possible,
                fastLoop: .poor,
                processLoop: .typical
            )
        case .slidingMode:
            return ControlStrategyProfile(
                id: id,
                title: "Sliding mode",
                shortName: "SMC",
                model: "Surface + bound",
                tuning: "λ, effort, φ",
                settling: "Reach, then slide",
                overshoot: "Can be sharp",
                steadyState: "Near 0 on surface",
                chattering: "High if sign(s)",
                disturbance: "Strong if matched",
                compute: "Modest",
                maintainability: "Watch chatter",
                summary: "Drive the error onto a line and stay there. Matched uncertainty (a load that looks like the input) is the reason people reach for it on servos.",
                limit: "sign(s) chatters. A boundary layer, sat(s/φ), trades chatter for a small band of error. It can heat a drive. This sketch is not a current-loop tune.",
                explanatoryOnly: false,
                linear: .possible,
                nonlinear: .typical,
                siso: .typical,
                mimo: .possible,
                fastLoop: .typical,
                processLoop: .possible
            )
        case .drl:
            return ControlStrategyProfile(
                id: id,
                title: "DRL / physics-informed RL",
                shortName: "DRL",
                model: "Simulator",
                tuning: "Reward, net",
                settling: "Not guaranteed",
                overshoot: "Not guaranteed",
                steadyState: "Not guaranteed",
                chattering: "Possible",
                disturbance: "Only if trained",
                compute: "Train off-device",
                maintainability: "Poor",
                summary: "A policy learned by trial in a simulator. Physics-informed RL adds a residual so it is not pure trial-and-error. Still a research bench, not a panel default.",
                limit: noTrainedPolicy + " Not a flight release, a drive tune, or a BMS cert.",
                explanatoryOnly: true,
                linear: .poor,
                nonlinear: .possible,
                siso: .possible,
                mimo: .possible,
                fastLoop: .poor,
                processLoop: .poor
            )
        case .adrc:
            return ControlStrategyProfile(
                id: id,
                title: "ADRC",
                shortName: "ADRC",
                model: "b0 guess",
                tuning: "Two bandwidths",
                settling: "Observer-limited",
                overshoot: "Usually modest",
                steadyState: "~0 via ESO",
                chattering: "Low",
                disturbance: "Strong",
                compute: "A few states",
                maintainability: "Fair",
                summary: "Treat everything you did not model — load, friction, a wrong gain — as one disturbance and cancel it. You need b0 in the right ballpark, not a full state-space model.",
                limit: "Observer bandwidth too high follows noise. The plot is a first-order teaching sketch, not your PLC’s commissioned loop.",
                explanatoryOnly: false,
                linear: .typical,
                nonlinear: .typical,
                siso: .typical,
                mimo: .possible,
                fastLoop: .typical,
                processLoop: .typical
            )
        case .nnAdaptive:
            return ControlStrategyProfile(
                id: id,
                title: "NN adaptive / PINN / ML-MPC",
                shortName: "NN",
                model: "Learned",
                tuning: "Loss, constraints",
                settling: "Not guaranteed",
                overshoot: "Not guaranteed",
                steadyState: "Not guaranteed",
                chattering: "Low if smooth",
                disturbance: "If it was in the data",
                compute: "Inference or a QP",
                maintainability: "Poor",
                summary: "NN adaptive updates weights online. A PINN keeps a physics residual so the fit cannot ignore the plant. ML-MPC puts a learned model inside an optimizer.",
                limit: noTrainedPolicy + " Keep a classical loop a technician can put in manual.",
                explanatoryOnly: true,
                linear: .poor,
                nonlinear: .typical,
                siso: .possible,
                mimo: .typical,
                fastLoop: .poor,
                processLoop: .possible
            )
        }
    }

    public static func matches(
        _ id: ControlStrategyID,
        linearity: ControlLinearityPick,
        channels: ControlChannelPick,
        loop: ControlLoopPick
    ) -> Bool {
        let profile = profile(id)
        if linearity == .linear, profile.linear == .poor { return false }
        if linearity == .nonlinear, profile.nonlinear == .poor { return false }
        if channels == .siso, profile.siso == .poor { return false }
        if channels == .mimo, profile.mimo == .poor { return false }
        if loop == .fast, profile.fastLoop == .poor { return false }
        if loop == .process, profile.processLoop == .poor { return false }
        return true
    }

    public static func matching(
        linearity: ControlLinearityPick,
        channels: ControlChannelPick,
        loop: ControlLoopPick
    ) -> [ControlStrategyID] {
        ControlStrategyID.allCases.filter {
            matches($0, linearity: linearity, channels: channels, loop: loop)
        }
    }

    public static func recommend(_ constraints: ControlStrategyConstraints) -> ControlStrategyRecommendation {
        let c = constraints

        if c.actuator == .onOff, c.channels == .siso {
            return make(
                primary: .bangBang,
                variant: nil,
                reasons: [
                    "The actuator is on/off and the loop is one channel. A hysteresis band is the controller.",
                    "Expect a limit cycle inside the band. Widen the band to cut chatter; the error grows with it.",
                ],
                alternate: .pid,
                alternateReason: "If you can modulate (valve, VFD, PWM), use PID in the Control Systems lab instead of the relay.",
                lab: false,
                caution: "Teaching sketch of a relay. Not a proof the band is safe on your equipment."
            )
        }

        if c.actuator == .onOff, c.channels == .mimo {
            if c.model == .stateSpace, c.loop != .fast {
                return make(
                    primary: .mpc,
                    variant: "Hybrid MPC",
                    reasons: [
                        "Several on/off devices plus a model you can write. Coordination is the problem, not a single deadband.",
                    ],
                    alternate: .bangBang,
                    alternateReason: "One relay per loop is what you can ship tonight. They will not share a limit.",
                    lab: false,
                    caution: "Hybrid MPC is a specialist design. This screen does not build the horizon."
                )
            }
            return make(
                primary: .bangBang,
                variant: "One relay per loop",
                reasons: [
                    "On/off outputs do not need a neural policy. Each loop gets its own band.",
                    "They will fight if the loops are coupled. That is a model problem, not a tighter band.",
                ],
                alternate: .mpc,
                alternateReason: "Move to MPC only with a model someone will keep and a scan slower than 1 ms.",
                lab: false,
                caution: "Not a plant-wide optimizer. Learned methods stay off this path."
            )
        }

        if c.model == .learned {
            if c.channels == .mimo, c.priority != .maintain {
                return make(
                    primary: .nnAdaptive,
                    variant: "ML-MPC",
                    reasons: [
                        "Coupled loops and a model you do not have in equations. A learned model inside an optimizer is the shape people mean.",
                        "Constraints still have to be written by someone who owns the plant.",
                    ],
                    alternate: .mpc,
                    alternateReason: "If you can write a state-space or step-response model, classical MPC is easier to defend on a job.",
                    lab: false,
                    caution: noTrainedPolicy
                )
            }
            if c.priority == .tracking, c.plant == .nonlinear {
                return make(
                    primary: .drl,
                    variant: "Physics-informed RL",
                    reasons: [
                        "You asked for tracking on a nonlinear plant and said the model is learned.",
                        "A physics residual keeps the policy from being pure trial-and-error. It still needs a simulator and a review.",
                    ],
                    alternate: .slidingMode,
                    alternateReason: "Sliding mode or ADRC is the on-device option when you need robustness without a training loop.",
                    lab: false,
                    caution: noTrainedPolicy + " Not a flight, drive, or BMS release."
                )
            }
            return make(
                primary: .nnAdaptive,
                variant: "NN adaptive / PINN",
                reasons: [
                    "A learned model was the constraint you set. A PINN keeps a physics residual; NN adaptive updates weights online.",
                    "Both need a supervisor and a fallback loop a technician can put in manual.",
                ],
                alternate: .adrc,
                alternateReason: "ADRC rejects a disturbance with two bandwidths and a b0 guess — no training set.",
                lab: false,
                caution: noTrainedPolicy
            )
        }

        if c.channels == .mimo, c.loop == .fast {
            return make(
                primary: .pid,
                variant: "One PID per channel",
                reasons: [
                    "A horizon solve usually misses a sub-millisecond scan.",
                    "Decouple what you can and run a PI or PID per loop.",
                ],
                alternate: .mpc,
                alternateReason: "Only if the horizon is precomputed and someone owns that code.",
                lab: true,
                caution: "The Control Systems lab is one loop. It does not tune the decoupling."
            )
        }

        if c.channels == .mimo, c.model == .stateSpace, c.loop != .fast, c.priority != .maintain {
            return make(
                primary: .mpc,
                variant: nil,
                reasons: [
                    "Several coupled channels, a model you can write, and a scan slow enough for a short horizon.",
                    "Use it when limits matter: power, stroke, temperature, or actuator authority.",
                ],
                alternate: .pid,
                alternateReason: "Decentralized PID is the maintainable fallback if the model owner leaves the site.",
                lab: false,
                caution: "Needs the model kept current. A stale model is worse than a boring PID."
            )
        }

        if c.channels == .mimo, c.model == .rough, c.loop != .fast, c.priority == .constraints {
            return make(
                primary: .mpc,
                variant: nil,
                reasons: [
                    "You need coordination and limits. A rough model can start the conversation. It is not a commission.",
                ],
                alternate: .pid,
                alternateReason: "Until the model exists, one PID per channel is what a tech can retune tonight.",
                lab: false,
                caution: "Do not commission MPC from a guess. The suggestion is a direction, not gains."
            )
        }

        if c.plant == .nonlinear, c.disturbance == .strong, c.actuator == .modulating, c.channels == .siso {
            if c.loop == .fast, c.priority != .maintain {
                return make(
                    primary: .slidingMode,
                    variant: nil,
                    reasons: [
                        "Fast loop, nonlinear plant, strong disturbance, and tracking ahead of a simple retune.",
                        "Use a boundary layer (sat instead of sign) if the command chatters.",
                    ],
                    alternate: .adrc,
                    alternateReason: "ADRC if the uncertainty looks like an input disturbance and you want fewer sliding-surface knobs.",
                    lab: false,
                    caution: "Chattering can heat a drive or wear a valve. This sketch is not a current-loop tune."
                )
            }
            if c.model == .none, c.priority == .maintain, c.loop != .fast {
                return make(
                    primary: .fuzzy,
                    variant: "Fuzzy / ANFIS",
                    reasons: [
                        "No usable model, a nonlinear process, a real upset, and a technician who can talk in rules.",
                        "ANFIS only if you already have data and someone to check the fit. This app does not fit it.",
                    ],
                    alternate: .adrc,
                    alternateReason: "ADRC if the pain is the load upset more than a strange gain curve.",
                    lab: false,
                    caution: "A rule table can hide a bad rule. Step it on the real plant with limits in place."
                )
            }
            return make(
                primary: .adrc,
                variant: nil,
                reasons: [
                    "Strong disturbance on a nonlinear single loop. ADRC estimates the lump and cancels it.",
                    "You need a b0 in the right ballpark and two bandwidths — not a full state-space model.",
                ],
                alternate: .pid,
                alternateReason: "Gain-scheduled PID if the nonlinearity is mostly a gain that changes with operating point.",
                lab: false,
                caution: "Observer bandwidth too high follows noise. This is not an autotune."
            )
        }

        if c.disturbance == .strong, c.channels == .siso, c.actuator == .modulating, c.model != .stateSpace {
            return make(
                primary: .adrc,
                variant: nil,
                reasons: [
                    "The upset is the problem, and you do not have a state-space model worth an MPC.",
                    "Integral PID also fights offset. ADRC is the pick when the disturbance is large or changing.",
                ],
                alternate: .pid,
                alternateReason: "Open the Control Systems lab if a PI with anti-windup is what the panel already knows.",
                lab: false,
                caution: "Sketch only. Measure the real upset before you raise observer bandwidth."
            )
        }

        if c.plant == .nonlinear, c.priority == .maintain, c.actuator == .modulating, c.model != .none, c.channels == .siso {
            return make(
                primary: .pid,
                variant: "Gain-scheduled PID",
                reasons: [
                    "The curve changes with operating point, and a technician has to own the tune.",
                    "Schedule Kp (and maybe Ki) across the range instead of one gain everywhere.",
                ],
                alternate: .fuzzy,
                alternateReason: "Fuzzy if the schedule becomes a pile of regions nobody can explain.",
                lab: true,
                caution: "The lab shows one operating point. Schedule the gains outside that sketch."
            )
        }

        if c.plant == .nonlinear, c.model == .none, c.loop != .fast, c.actuator == .modulating, c.channels == .siso {
            return make(
                primary: .fuzzy,
                variant: nil,
                reasons: [
                    "No model, slow enough for rules, nonlinear, one loop.",
                ],
                alternate: .pid,
                alternateReason: "Try PID first if the loop is only mildly nonlinear. The lab is the place to see overshoot.",
                lab: false,
                caution: "Rules are still a design. They do not certify the plant."
            )
        }

        if c.channels == .mimo, c.priority == .maintain {
            return make(
                primary: .pid,
                variant: "One PID per channel",
                reasons: [
                    "You asked for something a tech can retune. Coordinated MPC is harder to hand over.",
                ],
                alternate: .mpc,
                alternateReason: "Move to MPC when the loops fight and someone will keep the model.",
                lab: true,
                caution: "Decoupling is not in the PID lab."
            )
        }

        return make(
            primary: .pid,
            variant: nil,
            reasons: [
                "One modulating loop, a model you can sketch as a lag or a gain, and a tune a technician can revisit.",
                "Start in the Control Systems lab: step response, Ziegler–Nichols as a seed, then Bode margins.",
            ],
            alternate: .adrc,
            alternateReason: "If a load step still walks the process variable after the PID is honest, ADRC is the next single-loop tool.",
            lab: true,
            caution: "Not a guarantee the loop is stable on your hardware. The lab uses a textbook plant."
        )
    }

    public static let applications: [ControlApplicationNote] = [
        ControlApplicationNote(
            id: "hvac-stat",
            industry: "HVAC",
            example: "Room heat or a staged compressor",
            loop: "> 1 s",
            channels: "SISO",
            strategy: .bangBang,
            why: "On/off with a deadband. The room temperature limit-cycles inside the band. That is the controller, not a fault."
        ),
        ControlApplicationNote(
            id: "hvac-dat",
            industry: "HVAC",
            example: "Discharge-air or VAV reheat valve",
            loop: "> 1 s",
            channels: "SISO",
            strategy: .pid,
            why: "A modulating valve. One loop. Sketch the step in the Control Systems lab, then write the gains on the panel."
        ),
        ControlApplicationNote(
            id: "hvac-chiller",
            industry: "HVAC",
            example: "Chiller plant, kW versus comfort",
            loop: "> 1 s",
            channels: "MIMO",
            strategy: .mpc,
            why: "Several machines, a power limit, and a comfort band. Needs a model someone can maintain after the startup crew leaves."
        ),
        ControlApplicationNote(
            id: "drive-current",
            industry: "Motor drives",
            example: "Current or torque loop in a VFD or servo amp",
            loop: "< 1 ms",
            channels: "SISO",
            strategy: .pid,
            why: "PI around the current. There is no time for an online optimizer. The outer speed loop is another PI."
        ),
        ControlApplicationNote(
            id: "drive-smc",
            industry: "Motor drives",
            example: "Servo with a badly known mechanical load",
            loop: "< 1 ms",
            channels: "SISO",
            strategy: .slidingMode,
            why: "Some drive papers use a sliding surface when the load torque jumps. Watch the current command for chatter. Not the default VFD."
        ),
        ControlApplicationNote(
            id: "robot-joint",
            industry: "Robotics",
            example: "Joint position on a known trajectory",
            loop: "1–10 ms",
            channels: "SISO",
            strategy: .pid,
            why: "PID plus feedforward on one joint. Gain-schedule if the inertia changes a lot with pose."
        ),
        ControlApplicationNote(
            id: "robot-contact",
            industry: "Robotics",
            example: "Contact, deburring, or a moving fixture",
            loop: "1–10 ms",
            channels: "SISO",
            strategy: .slidingMode,
            why: "The environment is the disturbance. A boundary layer keeps the tool from buzzing on the surface."
        ),
        ControlApplicationNote(
            id: "robot-arm",
            industry: "Robotics",
            example: "Whole arm with joint and payload limits",
            loop: "10–100 ms",
            channels: "MIMO",
            strategy: .mpc,
            why: "Shared torque and stroke limits. The horizon has to finish inside the cycle, or you do not have MPC."
        ),
        ControlApplicationNote(
            id: "flight-pid",
            industry: "Flight / launch",
            example: "Attitude on a legacy autopilot",
            loop: "Milliseconds",
            channels: "SISO",
            strategy: .pid,
            why: "Gain-scheduled PID against airspeed or dynamic pressure. One loop at a time, schedules written down."
        ),
        ControlApplicationNote(
            id: "flight-mpc",
            industry: "Flight / launch",
            example: "Powered flight with angle and actuator limits",
            loop: "Outer loop, slower than the inner rate",
            channels: "MIMO",
            strategy: .mpc,
            why: "Propellant, angle of attack, and actuator authority in one horizon. A specialist model, not a phone tune."
        ),
        ControlApplicationNote(
            id: "flight-drl",
            industry: "Flight / launch",
            example: "Learned guidance on a research bench",
            loop: "Offline training",
            channels: "MIMO",
            strategy: .drl,
            why: "Physics-informed RL shows up in papers. This device does not train it and does not certify it for a vehicle."
        ),
        ControlApplicationNote(
            id: "bms-balance",
            industry: "BMS",
            example: "Passive cell balance",
            loop: "Seconds",
            channels: "SISO per cell",
            strategy: .bangBang,
            why: "Bleed resistor on above a delta-V band, off below it. Hysteresis so the FET does not buzz."
        ),
        ControlApplicationNote(
            id: "bms-charge",
            industry: "BMS",
            example: "Charge current into CC/CV",
            loop: "10 ms – 1 s",
            channels: "SISO",
            strategy: .pid,
            why: "A current loop plus a voltage limit. Still PID. Not a learned state-of-health model."
        ),
        ControlApplicationNote(
            id: "bms-pack",
            industry: "BMS",
            example: "Pack power with cell and thermal limits",
            loop: "> 1 s",
            channels: "MIMO",
            strategy: .mpc,
            why: "Several limits at once. Only if the pack model is owned. Otherwise the current loop stays PID."
        ),
        ControlApplicationNote(
            id: "bms-pinn",
            industry: "BMS",
            example: "PINN or NN state-of-health in a lab",
            loop: "Offline fit",
            channels: "MIMO",
            strategy: .nnAdaptive,
            why: "A physics residual can identify a cell. It is not a BMS certification and this app does not download a model."
        ),
    ]

    /// Relative sketch for the compute-versus-tracking plot. Tracking is how
    /// settled the textbook lag looks, not a measured score on hardware.
    public static let computeSketch: [ControlComputePoint] = [
        ControlComputePoint(id: .bangBang, compute: 0.08, tracking: 0.34),
        ControlComputePoint(id: .pid, compute: 0.22, tracking: 0.74),
        ControlComputePoint(id: .slidingMode, compute: 0.36, tracking: 0.66),
        ControlComputePoint(id: .fuzzy, compute: 0.42, tracking: 0.58),
        ControlComputePoint(id: .adrc, compute: 0.50, tracking: 0.80),
        ControlComputePoint(id: .mpc, compute: 0.76, tracking: 0.86),
        ControlComputePoint(id: .nnAdaptive, compute: 0.84, tracking: 0.70),
        ControlComputePoint(id: .drl, compute: 0.95, tracking: 0.60),
    ]

    /// Same first-order lag for bang-bang, PID, and a first-order ADRC.
    /// Teaching seconds — not your scan time. A load step hits at `disturbanceTime`.
    public static func stepSketch(disturbance: Double = 0.25) -> ControlStrategyStepSketch {
        let disturbance = min(0.5, max(0, disturbance))
        let band = 0.045
        let bang = simulate(.bangBang(band: band), disturbance: disturbance)
        let pid = simulate(.pid(kp: 1.7, ki: 0.95, kd: 0.28), disturbance: disturbance)
        let adrc = simulate(.adrc(b0: 0.72, omegaC: 1.35, omegaO: 2.6), disturbance: disturbance)
        let note = "Textbook lag, 0–1 actuator, setpoint \(TeachingPlant.reference). Load step at \(Int(TeachingPlant.disturbanceTime)) s. Not your hardware."
        return ControlStrategyStepSketch(
            reference: TeachingPlant.reference,
            disturbance: disturbance,
            disturbanceTime: TeachingPlant.disturbanceTime,
            band: band,
            bangBang: bang,
            pid: pid,
            adrc: adrc,
            note: note
        )
    }

    /// Relay memory: the output at the same input depends on which way you came.
    public static func hysteresisLoop(band: Double) -> ControlHysteresisLoop {
        let band = min(0.4, max(0.02, band))
        var samples: [PlotPoint] = []
        var output = -1.0
        let count = 81
        for index in 0..<count {
            let x = -1 + 2 * Double(index) / Double(count - 1)
            if x > band { output = 1 }
            samples.append(PlotPoint(x: x, y: output))
        }
        for index in stride(from: count - 1, through: 0, by: -1) {
            let x = -1 + 2 * Double(index) / Double(count - 1)
            if x < -band { output = -1 }
            samples.append(PlotPoint(x: x, y: output))
        }
        return ControlHysteresisLoop(band: band, samples: samples, risingTrip: band, fallingTrip: -band)
    }

    /// Second-order sketch: ẍ = u − damping·ẋ, surface s = ė + λe.
    /// The command is a sampled sat(s/φ). A thin layer chatters; a wide layer does not.
    public static func slidingSketch(boundary: Double) -> ControlSlidingSketch {
        let phi = min(0.8, max(0.012, boundary))
        let lambda = 3.0
        let effort = 12.0
        let dt = 0.0005
        let steps = 5_000
        let hold = 20
        var position = 0.0
        var velocity = 0.0
        let target = 1.0
        var phase: [PlotPoint] = []
        var actuator: [PlotPoint] = []
        var command = 0.0
        var previous = 0.0
        var chatter = 0.0
        var chatterCount = 0
        for index in 0..<steps {
            let time = Double(index) * dt
            let error = target - position
            let errorRate = -velocity
            let surface = errorRate + lambda * error
            if index % hold == 0 {
                let saturated = max(-1, min(1, surface / phi))
                command = effort * saturated
            }
            velocity += (command - 0.05 * velocity) * dt
            position += velocity * dt
            if index % 10 == 0 {
                phase.append(PlotPoint(x: error, y: errorRate))
                actuator.append(PlotPoint(x: time, y: command))
            }
            if time > 1.0 {
                chatter += abs(command - previous)
                chatterCount += 1
            }
            previous = command
        }
        let indexValue = chatterCount > 0 ? chatter / Double(chatterCount) : 0
        func line(offset: Double) -> [PlotPoint] {
            let left = -0.15
            let right = 1.15
            return [
                PlotPoint(x: left, y: -lambda * left + offset),
                PlotPoint(x: right, y: -lambda * right + offset),
            ]
        }
        return ControlSlidingSketch(
            boundary: phi,
            lambda: lambda,
            phase: phase,
            actuator: actuator,
            surface: line(offset: 0),
            upperBand: line(offset: phi),
            lowerBand: line(offset: -phi),
            chatterIndex: indexValue
        )
    }

    // MARK: - Recommendation helper

    private static func make(
        primary: ControlStrategyID,
        variant: String?,
        reasons: [String],
        alternate: ControlStrategyID,
        alternateReason: String,
        lab: Bool,
        caution: String
    ) -> ControlStrategyRecommendation {
        ControlStrategyRecommendation(
            primary: primary,
            variant: variant,
            reasons: reasons,
            alternate: alternate,
            alternateReason: alternateReason,
            opensControlSystemsLab: lab && primary == .pid,
            shipsTrainedPolicy: false,
            caution: caution
        )
    }

    // MARK: - Teaching plant

    private enum TeachingPlant {
        static let tau = 1.6
        static let reference = 0.62
        static let disturbanceTime = 7.0
        static let duration = 14.0
        static let dt = 0.01
    }

    private enum TeachingLaw {
        case bangBang(band: Double)
        case pid(kp: Double, ki: Double, kd: Double)
        case adrc(b0: Double, omegaC: Double, omegaO: Double)
    }

    private static func simulate(_ law: TeachingLaw, disturbance: Double) -> ControlStrategyTrace {
        let steps = Int(TeachingPlant.duration / TeachingPlant.dt)
        var y = 0.0
        var u = 0.0
        var integral = 0.0
        var previousError = TeachingPlant.reference
        var z1 = 0.0
        var z2 = 0.0
        var output: [PlotPoint] = []
        var actuator: [PlotPoint] = []
        var ySamples: [Double] = []
        var uSamples: [Double] = []
        output.reserveCapacity(steps / 2)
        actuator.reserveCapacity(steps / 2)

        for index in 0..<steps {
            let time = Double(index) * TeachingPlant.dt
            let load = time >= TeachingPlant.disturbanceTime ? disturbance : 0
            let error = TeachingPlant.reference - y

            switch law {
            case .bangBang(let band):
                if y < TeachingPlant.reference - band {
                    u = 1
                } else if y > TeachingPlant.reference + band {
                    u = 0
                }
            case .pid(let kp, let ki, let kd):
                let derivative = (error - previousError) / TeachingPlant.dt
                previousError = error
                let raw = kp * error + ki * integral + kd * derivative
                let saturatedHigh = raw > 1 && error > 0
                let saturatedLow = raw < 0 && error < 0
                if !saturatedHigh && !saturatedLow {
                    integral += error * TeachingPlant.dt
                    integral = min(4, max(-4, integral))
                }
                u = min(1, max(0, raw))
            case .adrc(let b0, let omegaC, let omegaO):
                let beta1 = 2 * omegaO
                let beta2 = omegaO * omegaO
                let observerError = z1 - y
                let z1Dot = z2 + b0 * u - beta1 * observerError
                let z2Dot = -beta2 * observerError
                z1 += z1Dot * TeachingPlant.dt
                z2 += z2Dot * TeachingPlant.dt
                let u0 = omegaC * (TeachingPlant.reference - z1)
                let raw = (u0 - z2) / b0
                u = min(1, max(0, raw))
            }

            let dy = (-y + u + load) / TeachingPlant.tau
            y += dy * TeachingPlant.dt
            ySamples.append(y)
            uSamples.append(u)
            if index % 2 == 0 {
                output.append(PlotPoint(x: time, y: y))
                actuator.append(PlotPoint(x: time, y: u))
            }
        }

        let id: ControlStrategyID
        switch law {
        case .bangBang: id = .bangBang
        case .pid: id = .pid
        case .adrc: id = .adrc
        }
        let late = lateWindow(ySamples, reference: TeachingPlant.reference)
        return ControlStrategyTrace(
            id: id,
            output: output,
            actuator: actuator,
            switchCount: switchCount(uSamples, threshold: 0.35),
            lateAbsoluteError: late.meanAbs,
            lateSpread: late.spread
        )
    }

    private static func switchCount(_ samples: [Double], threshold: Double) -> Int {
        guard let first = samples.first else { return 0 }
        var count = 0
        var last = first
        for value in samples.dropFirst() {
            if abs(value - last) >= threshold {
                count += 1
                last = value
            }
        }
        return count
    }

    private static func lateWindow(_ samples: [Double], reference: Double) -> (meanAbs: Double, spread: Double) {
        guard samples.count >= 5 else { return (0, 0) }
        let start = samples.count * 4 / 5
        let window = Array(samples[start...])
        let count = Double(window.count)
        let meanAbs = window.reduce(0) { $0 + abs($1 - reference) } / count
        let mean = window.reduce(0, +) / count
        let variance = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / count
        return (meanAbs, variance.squareRoot())
    }
}
