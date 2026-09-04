import Foundation

/// How a tool should refresh its numeric result.
///
/// - `live`: update as soon as the current input is parseable and valid.
/// - `explicit`: require a Calculate action; preserve the last success as stale
///   while the operator edits inputs.
/// - `sensor`: continuous or permission-gated instrument readings (not a form calc).
public enum CalculationMode: String, Codable, CaseIterable, Sendable, Hashable {
    case live
    case explicit
    case sensor
}

/// Pure-Swift interaction state for explicit (button-driven) calculators.
///
/// Views must not silently replace `lastSuccess` while inputs change — call
/// `markInputsChanged()` on every meaningful edit, and `calculate` only from
/// the Calculate action (or an equivalent Return key).
public struct ExplicitCalculationState<Result: Equatable & Sendable>: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case failed(CalcError)
        case success(Result)
    }

    public private(set) var phase: Phase = .idle
    /// True when `phase` still holds a previous success but inputs have changed.
    public private(set) var isStale: Bool = false
    /// Field id to focus after a validation failure (optional).
    public private(set) var focusField: String? = nil

    public init() {}

    public var hasDisplayableResult: Bool {
        if case .success = phase { return true }
        return false
    }

    public var displayedResult: Result? {
        if case .success(let value) = phase { return value }
        return nil
    }

    public var error: CalcError? {
        if case .failed(let error) = phase { return error }
        return nil
    }

    public var staleBanner: String? {
        guard isStale, case .success = phase else { return nil }
        return "Inputs changed — Calculate again."
    }

    /// Call whenever the operator edits an input that could change the answer.
    public mutating func markInputsChanged() {
        lastValidationError = nil
        focusField = nil
        guard case .success = phase else {
            // Clear a prior validation failure once the operator starts fixing fields.
            if case .failed = phase {
                phase = .idle
            }
            return
        }
        isStale = true
    }

    /// Last validation error from Calculate, even when a stale success remains.
    public private(set) var lastValidationError: CalcError? = nil

    /// Run validation + math. On failure, keep any prior success and mark it stale
    /// so the operator never loses the last good answer to a typo.
    public mutating func calculate(
        focusOnFailure field: String? = nil,
        _ work: () throws -> Result
    ) {
        do {
            let value = try work()
            phase = .success(value)
            isStale = false
            focusField = nil
            lastValidationError = nil
        } catch let error as CalcError {
            lastValidationError = error
            focusField = field
            if case .success = phase {
                isStale = true
            } else {
                phase = .failed(error)
                isStale = false
            }
        } catch {
            let wrapped = CalcError.outOfRange(error.localizedDescription)
            lastValidationError = wrapped
            focusField = field
            if case .success = phase {
                isStale = true
            } else {
                phase = .failed(wrapped)
                isStale = false
            }
        }
    }

    public mutating func reset() {
        phase = .idle
        isStale = false
        focusField = nil
        lastValidationError = nil
    }

    /// Clear result state after loading an example so Calculate stays intentional.
    public mutating func prepareForNewInputs() {
        reset()
    }
}

/// Live-tool helper: only exposes a result when the current input validates.
public struct LiveCalculationState<Result: Equatable & Sendable>: Equatable, Sendable {
    public private(set) var result: Result? = nil
    public private(set) var error: CalcError? = nil

    public init() {}

    public mutating func update(_ work: () throws -> Result) {
        do {
            result = try work()
            error = nil
        } catch let calc as CalcError {
            result = nil
            error = calc
        } catch let unexpected {
            result = nil
            error = .outOfRange(unexpected.localizedDescription)
        }
    }

    public mutating func clear() {
        result = nil
        error = nil
    }
}

/// Single source of truth: which tools are live vs explicit vs sensor.
/// Keys match `ToolID.rawValue` in the iOS app.
public enum ToolCalculationPolicy {
    public static func mode(forToolID id: String) -> CalculationMode {
        switch id {
        case
            "unitConverter",
            "resistorColor",
            "circularMils",
            "modbusAddress",
            "numberBase":
            return .live

        case
            "wifiStatus",
            "bluetoothScan",
            "noiseMeter",
            "bubbleLevel",
            "magnetometer",
            "barometer",
            "motionSnapshot",
            "fieldPosition",
            "deviceHealth":
            return .sensor

        default:
            return .explicit
        }
    }

    /// Every catalog tool id that should appear on the home grid (and hidden deep-link ids).
    public static let knownToolIDs: [String] = [
        "ohmsLaw", "power", "powerWizard", "voltageDrop", "conduitFill", "transformer",
        "timer555", "motorFLA", "wireAmpacity", "conductorCost", "voltageDivider", "seriesParallel",
        "resistorColor", "unitConverter", "frequencyWave", "ledRC", "wifiStatus",
        "bluetoothScan", "noiseMeter", "bubbleLevel", "magnetometer", "barometer",
        "motionSnapshot", "fieldPosition", "deviceHealth", "receptacleSelector",
        "reactance", "powerFactor", "shortCircuit", "circularMils", "loadFactors",
        "signalScaling", "modbusAddress", "plcTimer", "panelDirectory",
        "motorSpeed", "rfLink", "phasorDiagram", "numberBase", "batteryBank",
        "referenceLibrary", "magneticCircuit", "fiberLink", "gaussianBeam",
        "transientCircuit", "rackCurrent", "diodeIV", "isLoopVerifier",
        "tapChanger", "harmonicsTHD", "upsSizing", "motorNameplate", "motorNameplateOCR",
        "heaterDesign",
        "empEmc", "necCircuit", "loadWorksheet", "cableSchedule", "solenoidDesign",
        "solarDesign",
        "analogWorkbench", "noiseSNR", "linearRegulator", "instrumentationAmp", "adcDac",
        "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
    ]

    public static var liveToolIDs: [String] {
        knownToolIDs.filter { mode(forToolID: $0) == .live }
    }

    public static var explicitToolIDs: [String] {
        knownToolIDs.filter { mode(forToolID: $0) == .explicit }
    }

    public static var sensorToolIDs: [String] {
        knownToolIDs.filter { mode(forToolID: $0) == .sensor }
    }
}

/// Chart / diagram payload built only from finite validated numbers.
/// Keeps visualization models honest: no diagram without a usable numeric source.
public struct ValidatedVisualModel<Payload: Equatable & Sendable>: Equatable, Sendable {
    public let payload: Payload
    public let accessibilitySummary: String

    public init?(
        requireFinite values: [Double],
        payload: Payload,
        accessibilitySummary: String
    ) {
        guard !values.isEmpty, values.allSatisfy({ $0.isFinite }) else { return nil }
        self.payload = payload
        self.accessibilitySummary = accessibilitySummary
    }

    public init(payload: Payload, accessibilitySummary: String) {
        self.payload = payload
        self.accessibilitySummary = accessibilitySummary
    }
}
