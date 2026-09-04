import Foundation

public enum NumberBase: String, CaseIterable, Sendable, Identifiable {
    case binary
    case octal
    case decimal
    case hexadecimal

    public var id: String { rawValue }

    /// The radix passed to `UInt64(_:radix:)` — kept separate from `rawValue`
    /// so this type stays String-backed for on-device settings storage.
    public var radix: Int {
        switch self {
        case .binary: return 2
        case .octal: return 8
        case .decimal: return 10
        case .hexadecimal: return 16
        }
    }

    public var displayName: String {
        switch self {
        case .binary: return "Binary"
        case .octal: return "Octal"
        case .decimal: return "Decimal"
        case .hexadecimal: return "Hex"
        }
    }

    public var prefix: String {
        switch self {
        case .binary: return "0b"
        case .octal: return "0o"
        case .decimal: return ""
        case .hexadecimal: return "0x"
        }
    }

    /// What VoiceOver should say is valid to type — the accepted digit range
    /// differs per base, and hex in particular accepts letters, not just digits.
    public var validCharactersDescription: String {
        switch self {
        case .binary: return "Digits 0 and 1"
        case .octal: return "Digits 0 through 7"
        case .decimal: return "Digits 0 through 9"
        case .hexadecimal: return "Digits 0 through 9 and letters A through F"
        }
    }
}

public struct NumberBaseResult: Equatable, Sendable {
    public var value: UInt64
    public var binary: String
    public var octal: String
    public var decimal: String
    public var hexadecimal: String
    /// Same bit pattern, read as two's-complement signed at common register widths.
    public var signed8: Int
    public var signed16: Int
    public var signed32: Int

    public init(value: UInt64, binary: String, octal: String, decimal: String, hexadecimal: String, signed8: Int, signed16: Int, signed32: Int) {
        self.value = value
        self.binary = binary
        self.octal = octal
        self.decimal = decimal
        self.hexadecimal = hexadecimal
        self.signed8 = signed8
        self.signed16 = signed16
        self.signed32 = signed32
    }
}

/// Base conversion for the value you're actually staring at: a PLC register,
/// a Modbus word, a byte off a scope. Everything lives in `UInt64` and the
/// signed columns re-read that same bit pattern at a register width — they are
/// not a second, independent value.
public enum NumberBaseConvert {
    public static func parse(_ text: String, from base: NumberBase) throws -> NumberBaseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CalcError.missing("a value") }

        let stripped = strippingKnownPrefix(trimmed, for: base)
        guard let value = UInt64(stripped, radix: base.radix) else {
            throw CalcError.outOfRange("\"\(trimmed)\" is not a valid \(base.displayName.lowercased()) value.")
        }
        return result(for: value)
    }

    public static func result(for value: UInt64) -> NumberBaseResult {
        NumberBaseResult(
            value: value,
            binary: String(value, radix: 2),
            octal: String(value, radix: 8),
            decimal: String(value, radix: 10),
            hexadecimal: String(value, radix: 16).uppercased(),
            signed8: signedInterpretation(value, bitWidth: 8),
            signed16: signedInterpretation(value, bitWidth: 16),
            signed32: signedInterpretation(value, bitWidth: 32)
        )
    }

    /// Binary grouped in nibbles (`1010 1100`) — the way anyone actually reads it.
    public static func groupedBinary(_ binary: String) -> String {
        let padded = String(repeating: "0", count: (4 - binary.count % 4) % 4) + binary
        return stride(from: 0, to: padded.count, by: 4).map { start in
            let from = padded.index(padded.startIndex, offsetBy: start)
            let to = padded.index(from, offsetBy: 4)
            return String(padded[from..<to])
        }.joined(separator: " ")
    }

    private static func signedInterpretation(_ value: UInt64, bitWidth: Int) -> Int {
        let mask: UInt64 = bitWidth >= 64 ? .max : (1 << UInt64(bitWidth)) - 1
        let truncated = value & mask
        let signBit: UInt64 = 1 << UInt64(bitWidth - 1)
        if truncated & signBit != 0 {
            return Int(truncated) - Int(mask) - 1
        }
        return Int(truncated)
    }

    private static func strippingKnownPrefix(_ text: String, for base: NumberBase) -> String {
        let lowered = text.lowercased()
        switch base {
        case .binary where lowered.hasPrefix("0b"):
            return String(text.dropFirst(2))
        case .octal where lowered.hasPrefix("0o"):
            return String(text.dropFirst(2))
        case .hexadecimal where lowered.hasPrefix("0x"):
            return String(text.dropFirst(2))
        default:
            return text
        }
    }
}
