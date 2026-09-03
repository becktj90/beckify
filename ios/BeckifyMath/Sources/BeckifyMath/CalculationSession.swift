import Foundation

/// How a toolbox tool should compute: immediately on valid input, or only when
/// the engineer presses Calculate.
public enum CalculationMode: String, Codable, CaseIterable, Sendable, Hashable {
    /// Deterministic converters that update as soon as the current input parses.
    case live
    /// Multi-input engineering work that must not silently rewrite a committed answer.
    case explicit
}

/// Pure session state for explicit calculators. Views own an instance and feed
/// it an input fingerprint; they never invent a result without `calculate`.
public struct ExplicitCalculationSession<Value: Equatable & Sendable>: Equatable, Sendable {
    public enum Display: Equatable, Sendable {
        case idle
        case failed(String)
        case current(Value)
        case stale(Value)
    }

    public private(set) var committed: Value?
    public private(set) var committedFingerprint: String?
    public private(set) var lastError: String?

    public init() {}

    public init(committed: Value?, committedFingerprint: String?, lastError: String? = nil) {
        self.committed = committed
        self.committedFingerprint = committedFingerprint
        self.lastError = lastError
    }

    /// What the UI should show for the inputs currently on screen.
    public func display(for fingerprint: String) -> Display {
        guard let committed else {
            if let lastError { return .failed(lastError) }
            return .idle
        }
        if fingerprint == committedFingerprint {
            return .current(committed)
        }
        return .stale(committed)
    }

    /// Error copy for the Calculate dock. Cleared when the on-screen inputs
    /// again match the last successful fingerprint so a restored answer is not
    /// paired with a leftover failure message.
    public func visibleError(for fingerprint: String) -> String? {
        guard let lastError else { return nil }
        if fingerprint == committedFingerprint { return nil }
        return lastError
    }

    public var hasCommittedResult: Bool { committed != nil }

    public mutating func calculate(fingerprint: String, _ body: () throws -> Value) {
        do {
            let value = try body()
            committed = value
            committedFingerprint = fingerprint
            lastError = nil
        } catch let error as CalcError {
            lastError = error.message
            // Keep any previous committed value; display becomes `.stale` until
            // the fingerprint matches again after a successful calculate.
        } catch {
            lastError = "Could not calculate with the current inputs."
        }
    }

    public mutating func reset() {
        committed = nil
        committedFingerprint = nil
        lastError = nil
    }
}

/// Shared classification for every primary toolbox tool. Sensors stay live
/// because they stream device data rather than solving a worksheet.
public enum ToolCalculationPolicy {
    public static func mode(for toolID: String) -> CalculationMode {
        switch toolID {
        case "unitConverter", "resistorColor", "circularMils", "modbusAddress",
             "wifiStatus", "bluetoothScan", "noiseMeter", "bubbleLevel",
             "magnetometer", "barometer", "motionSnapshot", "fieldPosition",
             "deviceHealth", "panelDirectory":
            return .live
        default:
            return .explicit
        }
    }
}
