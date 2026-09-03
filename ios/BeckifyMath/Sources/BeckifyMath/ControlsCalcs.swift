import Foundation

// MARK: - Process value / signal scaling

public struct SignalScalingResult: Equatable, Sendable {
    public var engineeringValue: Double
    public var rawValue: Double
    public var percentOfSpan: Double
    public var isLiveZeroFault: Bool
    public var formula: String

    public init(
        engineeringValue: Double,
        rawValue: Double,
        percentOfSpan: Double,
        isLiveZeroFault: Bool,
        formula: String
    ) {
        self.engineeringValue = engineeringValue
        self.rawValue = rawValue
        self.percentOfSpan = percentOfSpan
        self.isLiveZeroFault = isLiveZeroFault
        self.formula = formula
    }
}

public enum SignalCurve: String, Codable, CaseIterable, Sendable, Hashable {
    case linear
    case squareRoot

    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .squareRoot: return "√ (DP flow)"
        }
    }
}

public enum SignalScaling {
    /// Raw instrument signal to engineering units. Square-root is the
    /// differential-pressure flow case, where flow tracks √ΔP.
    public static func toEngineering(
        raw: Double,
        rawMin: Double,
        rawMax: Double,
        engineeringMin: Double,
        engineeringMax: Double,
        curve: SignalCurve = .linear,
        detectLiveZeroFault: Bool = false
    ) throws -> SignalScalingResult {
        guard raw.isFinite, rawMin.isFinite, rawMax.isFinite else { throw CalcError.missing("signal values") }
        guard engineeringMin.isFinite, engineeringMax.isFinite else { throw CalcError.missing("engineering range") }
        guard rawMax != rawMin else { throw CalcError.outOfRange("Raw span cannot be zero.") }

        var fraction = (raw - rawMin) / (rawMax - rawMin)
        // Live-zero semantics are opt-in because an arbitrary positive raw
        // range (for example, RTD resistance) is not necessarily a current loop.
        let liveZeroFault = detectLiveZeroFault && raw < rawMin - abs(rawMax - rawMin) * 0.01

        if curve == .squareRoot {
            guard fraction >= 0 else {
                throw CalcError.outOfRange("Square-root scaling requires a raw value at or above the raw minimum.")
            }
            fraction = fraction.squareRoot()
        }

        let value = engineeringMin + fraction * (engineeringMax - engineeringMin)
        return SignalScalingResult(
            engineeringValue: value,
            rawValue: raw,
            percentOfSpan: fraction * 100,
            isLiveZeroFault: liveZeroFault,
            formula: curve == .squareRoot
                ? "EU = EU_min + √((raw − raw_min)/(raw_max − raw_min)) · span"
                : "EU = EU_min + (raw − raw_min)/(raw_max − raw_min) · span"
        )
    }

    /// Engineering units back to a raw signal.
    public static func toRaw(
        engineering: Double,
        rawMin: Double,
        rawMax: Double,
        engineeringMin: Double,
        engineeringMax: Double,
        curve: SignalCurve = .linear
    ) throws -> SignalScalingResult {
        guard engineering.isFinite, rawMin.isFinite, rawMax.isFinite else { throw CalcError.missing("signal values") }
        guard engineeringMin.isFinite, engineeringMax.isFinite else { throw CalcError.missing("engineering range") }
        guard rawMax != rawMin else { throw CalcError.outOfRange("Raw span cannot be zero.") }
        guard engineeringMax != engineeringMin else { throw CalcError.outOfRange("Engineering span cannot be zero.") }

        var fraction = (engineering - engineeringMin) / (engineeringMax - engineeringMin)
        if curve == .squareRoot {
            guard fraction >= 0 else {
                throw CalcError.outOfRange("Square-root scaling requires an engineering value at or above the engineering minimum.")
            }
            fraction *= fraction
        }

        let raw = rawMin + fraction * (rawMax - rawMin)
        return SignalScalingResult(
            engineeringValue: engineering,
            rawValue: raw,
            percentOfSpan: fraction * 100,
            isLiveZeroFault: false,
            formula: curve == .squareRoot
                ? "raw = raw_min + ((EU − EU_min)/span)² · raw_span"
                : "raw = raw_min + (EU − EU_min)/span · raw_span"
        )
    }
}

// MARK: - Modbus addressing

public enum ModbusTable: String, Codable, CaseIterable, Sendable, Hashable {
    case coil
    case discreteInput
    case inputRegister
    case holdingRegister

    public var displayName: String {
        switch self {
        case .coil: return "Coil (0x)"
        case .discreteInput: return "Discrete input (1x)"
        case .inputRegister: return "Input register (3x)"
        case .holdingRegister: return "Holding register (4x)"
        }
    }

    /// Leading digit of the classic data-model prefix.
    public var prefix: Int {
        switch self {
        case .coil: return 0
        case .discreteInput: return 1
        case .inputRegister: return 3
        case .holdingRegister: return 4
        }
    }

    public var readFunctionCode: Int {
        switch self {
        case .coil: return 1
        case .discreteInput: return 2
        case .inputRegister: return 4
        case .holdingRegister: return 3
        }
    }
}

public struct ModbusAddressResult: Equatable, Sendable {
    public var table: ModbusTable
    public var pduOffset: Int
    public var entityNumber: Int
    public var fiveDigit: String?
    public var sixDigit: String
    public var readFunctionCode: Int

    public init(
        table: ModbusTable,
        pduOffset: Int,
        entityNumber: Int,
        fiveDigit: String?,
        sixDigit: String,
        readFunctionCode: Int
    ) {
        self.table = table
        self.pduOffset = pduOffset
        self.entityNumber = entityNumber
        self.fiveDigit = fiveDigit
        self.sixDigit = sixDigit
        self.readFunctionCode = readFunctionCode
    }
}

public enum ModbusAddress {
    public static let maxOffset = 65535

    /// The 0-based offset that goes on the wire is the one people get wrong;
    /// everything else is a display convention layered on top of it.
    public static func fromPDUOffset(_ offset: Int, table: ModbusTable) throws -> ModbusAddressResult {
        guard offset >= 0, offset <= maxOffset else {
            throw CalcError.outOfRange("Offset must be 0 to \(maxOffset).")
        }
        let entity = offset + 1
        return ModbusAddressResult(
            table: table,
            pduOffset: offset,
            entityNumber: entity,
            fiveDigit: entity <= 9_999 ? "\(table.prefix)\(String(format: "%04d", entity))" : nil,
            sixDigit: "\(table.prefix)\(String(format: "%05d", entity))",
            readFunctionCode: table.readFunctionCode
        )
    }

    /// Accepts an exact five- or six-digit display address whose prefix agrees
    /// with `table`. Use `fromEntityNumber(_:table:)` for an unprefixed entity.
    public static func fromDisplayAddress(_ text: String, table: ModbusTable) throws -> ModbusAddressResult {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isNumber }) else {
            throw CalcError.missing("a numeric address")
        }
        guard trimmed.count == 5 || trimmed.count == 6 else {
            throw CalcError.outOfRange("Display addresses must contain exactly 5 or 6 digits.")
        }
        guard let prefix = trimmed.first?.wholeNumberValue, prefix == table.prefix else {
            throw CalcError.outOfRange("Address prefix does not match the selected Modbus table.")
        }
        guard let entity = Int(trimmed.dropFirst()) else { throw CalcError.missing("a numeric address") }

        return try fromEntityNumber(entity, table: table)
    }

    /// Converts an explicit, unprefixed one-based entity number.
    public static func fromEntityNumber(_ entity: Int, table: ModbusTable) throws -> ModbusAddressResult {
        guard entity >= 1 else { throw CalcError.outOfRange("Entity numbers start at 1.") }
        return try fromPDUOffset(entity - 1, table: table)
    }
}

// MARK: - PLC timer presets

public struct TimerPresetResult: Equatable, Sendable {
    public var preset: Int
    public var actualSeconds: Double
    public var errorSeconds: Double
    public var timebaseSeconds: Double
    public var formula: String

    public init(
        preset: Int,
        actualSeconds: Double,
        errorSeconds: Double,
        timebaseSeconds: Double,
        formula: String
    ) {
        self.preset = preset
        self.actualSeconds = actualSeconds
        self.errorSeconds = errorSeconds
        self.timebaseSeconds = timebaseSeconds
        self.formula = formula
    }
}

public enum PLCTimer {
    /// Preset counts for a desired time at a given timebase. The preset is a
    /// whole number, so the achievable time is quantised — the error matters
    /// when the timebase is coarse.
    public static func preset(seconds: Double, timebaseSeconds: Double) throws -> TimerPresetResult {
        let target = try Positive.require(seconds, name: "Time")
        let base = try Positive.require(timebaseSeconds, name: "Timebase")

        let exact = target / base
        let rounded = exact.rounded()
        guard rounded.isFinite, rounded >= 0, let preset = Int(exactly: rounded) else {
            throw CalcError.outOfRange("Preset is out of range for this timebase.")
        }

        let actual = Double(preset) * base
        guard actual.isFinite else { throw CalcError.outOfRange("Timed duration is too large.") }
        return TimerPresetResult(
            preset: preset,
            actualSeconds: actual,
            errorSeconds: actual - target,
            timebaseSeconds: base,
            formula: "preset = round(time / timebase)    actual = preset × timebase"
        )
    }

    /// The reverse: what a preset actually times out at.
    public static func seconds(preset: Int, timebaseSeconds: Double) throws -> TimerPresetResult {
        guard preset >= 0 else { throw CalcError.nonPositive("Preset") }
        let base = try Positive.require(timebaseSeconds, name: "Timebase")
        let actual = Double(preset) * base
        guard actual.isFinite else { throw CalcError.outOfRange("Timed duration is too large.") }
        return TimerPresetResult(
            preset: preset,
            actualSeconds: actual,
            errorSeconds: 0,
            timebaseSeconds: base,
            formula: "time = preset × timebase"
        )
    }
}
