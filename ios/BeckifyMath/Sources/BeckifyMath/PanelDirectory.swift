import Foundation

/// One row read off a panel directory sticker or schedule photo.
public struct PanelCircuit: Equatable, Sendable {
    public var circuit: String
    public var name: String
    public var trip: String
    public var poles: String

    public init(circuit: String, name: String, trip: String = "", poles: String = "") {
        self.circuit = circuit
        self.name = name
        self.trip = trip
        self.poles = poles
    }
}

/// Reads circuit rows out of recognized text from a panel photo.
///
/// Text recognition collapses runs of spaces, so a photographed schedule
/// arrives as one space-separated line rather than aligned columns. This walks
/// the tokens instead of relying on column gaps, which also picks up directory
/// stickers that carry only a circuit number and a name — no trip, no poles.
public enum PanelDirectory {
    /// Panels top out well below this; a larger leading number is a rating or a
    /// stray figure ("400A MCB"), not a circuit position.
    public static let maxCircuitNumber = 200

    public static func parse(_ text: String) -> [PanelCircuit] {
        var rows: [PanelCircuit] = []
        var seen = Set<String>()

        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = compact(String(rawLine))
            if line.isEmpty || isIgnored(line) { continue }

            for segment in segments(in: line) {
                guard let row = circuit(from: segment) else { continue }
                let key = "\(row.circuit)|\(row.name)|\(row.trip)|\(row.poles)".uppercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                rows.append(row)
            }
        }

        return rows
    }

    // MARK: - Line handling

    static func compact(_ line: String) -> String {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "|" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    static func isIgnored(_ line: String) -> Bool {
        let upper = line.uppercased()
        let headers: Set<String> = [
            "PANEL SCHEDULE", "BRANCH CIRCUIT", "BRANCH CIRCUITS",
            "CIRCUIT DIRECTORY", "LOAD SUMMARY", "NOTE", "NOTES", "ODD EVEN",
        ]
        if headers.contains(upper) { return true }

        let firstToken = String(upper.split(separator: " ").first ?? "")
        if upper.hasPrefix("PANEL"), !looksLikeCircuit(firstToken) { return true }
        if (upper.contains("CKT") || upper.contains("CIRCUIT")),
           upper.contains("LOAD") || upper.contains("DESCRIPTION") { return true }
        if upper.contains("TRIP") || upper.contains("AMP"), upper.contains("POLE") { return true }

        // "Voltage: 480Y/277V" and friends are panel metadata, not circuits.
        if let colon = upper.firstIndex(of: ":") {
            let key = upper[upper.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            if !looksLikeCircuit(key) { return true }
        }
        return false
    }

    // MARK: - Token classification

    /// A circuit position as printed: digits, optionally one trailing letter,
    /// optionally ganged ("1", "1A", "1-3", "2/4").
    static func looksLikeCircuit(_ token: String) -> Bool {
        let upper = token.uppercased()
        guard !upper.isEmpty else { return false }
        let parts = upper.split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "," })
        guard !parts.isEmpty else { return false }

        for part in parts {
            var digits = 0
            var letters = 0
            for (offset, character) in part.enumerated() {
                if character.isNumber {
                    if letters > 0 { return false }
                    digits += 1
                } else if character.isLetter {
                    if offset != part.count - 1 { return false }
                    letters += 1
                } else {
                    return false
                }
            }
            if digits == 0 || letters > 1 { return false }
        }
        return true
    }

    /// Deliberately stricter than `looksLikeCircuit`: "20A" is a trip and "1P"
    /// is a pole count, and treating either as a new circuit would chop a row
    /// in half.
    static func isBareCircuitToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        for character in token where !(character.isNumber || character == "-" || character == "/" || character == ",") {
            return false
        }
        let parts = token.split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "," })
        guard !parts.isEmpty else { return false }
        for part in parts where part.isEmpty || part.count > 3 { return false }
        return true
    }

    static func looksLikeTrip(_ token: String) -> Bool {
        var numeric = token.uppercased()
        for suffix in ["AMPS", "AMP", "A"] where numeric.hasSuffix(suffix) {
            numeric = String(numeric.dropLast(suffix.count))
            break
        }
        guard !numeric.isEmpty else { return false }

        var sawDot = false
        var sawDigit = false
        for character in numeric {
            if character == "." {
                if sawDot { return false }
                sawDot = true
            } else if character.isNumber {
                sawDigit = true
            } else {
                return false
            }
        }
        return sawDigit
    }

    static func looksLikePoles(_ token: String) -> Bool {
        ["1", "2", "3", "1P", "2P", "3P"].contains(token.uppercased())
    }

    static func firstCircuitNumber(_ token: String) -> Int {
        var digits = ""
        for character in token {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits) ?? Int.max
    }

    static func normalizeTrip(_ token: String) -> String {
        var numeric = ""
        for character in token {
            if character.isNumber || character == "." {
                numeric.append(character)
            } else {
                break
            }
        }
        return numeric.isEmpty ? "" : numeric + "A"
    }

    // MARK: - Segmenting

    static func startsNewCircuit(_ token: String, next: String?, previous: Int?) -> Bool {
        guard isBareCircuitToken(token), let next else { return false }
        if looksLikeTrip(next) || looksLikePoles(next) { return false }

        let value = firstCircuitNumber(token)
        guard value >= 1, value <= maxCircuitNumber else { return false }
        guard let previous else { return true }
        return value > previous
    }

    /// Break one line into per-circuit token runs. Two-up directories put the
    /// odd and even columns on the same line ("1 LIGHTING 2 RECEPTACLES").
    static func segments(in line: String) -> [[String]] {
        let tokens = line.split(separator: " ").map(String.init)
        guard let first = tokens.first, looksLikeCircuit(first) else { return [] }

        var result: [[String]] = []
        var current = [first]
        var previous: Int? = firstCircuitNumber(first)

        for index in 1..<max(tokens.count, 1) {
            let token = tokens[index]
            let next = index + 1 < tokens.count ? tokens[index + 1] : nil
            // Require a name token on the open segment before starting another,
            // so "1 2 3" style noise stays one run instead of exploding.
            if current.count >= 2, startsNewCircuit(token, next: next, previous: previous) {
                result.append(current)
                current = [token]
                previous = firstCircuitNumber(token)
            } else {
                current.append(token)
            }
        }

        result.append(current)
        return result
    }

    /// Circuit, name, then optional trip and poles. Directory stickers stop
    /// after the name, so neither trailing field may be required.
    static func circuit(from tokens: [String]) -> PanelCircuit? {
        guard let first = tokens.first, looksLikeCircuit(first) else { return nil }
        guard firstCircuitNumber(first) <= maxCircuitNumber else { return nil }

        var trailing = Array(tokens.dropFirst())
        var trip = ""
        var poles = ""

        // Keep at least one token for the name; a lone "LIGHTING" must not be
        // eaten as a trip or a pole count.
        if trailing.count > 1, let last = trailing.last, looksLikePoles(last) {
            poles = last.uppercased().replacingOccurrences(of: "P", with: "")
            trailing.removeLast()
        }
        if let last = trailing.last, looksLikeTrip(last), trailing.count > 1 || !poles.isEmpty {
            trip = normalizeTrip(last)
            trailing.removeLast()
        }

        let name = trailing.joined(separator: " ").trimmingCharacters(in: .whitespaces)

        // A real row names something. Without a name, only a complete trip and
        // pole pair is enough to keep it — otherwise it is recognition noise.
        let named = name.contains { $0.isLetter }
            && name.filter { $0.isLetter }.count >= 2
        if !named, trip.isEmpty || poles.isEmpty { return nil }

        return PanelCircuit(
            circuit: first.uppercased(),
            name: name,
            trip: trip,
            poles: poles
        )
    }
}
