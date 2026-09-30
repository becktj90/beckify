import Foundation

/// Spatial schedule grid plus the OCR rewrites that should happen before
/// `PanelScheduleParser`. Pure logic — no Vision — so a typed fixture and a
/// photo observation take the same path.
///
/// Odd circuits stay on the left and even circuits on the right when a row
/// has two columns and the printed number is missing. Trade codes such as
/// `BKR-3A` are left alone; dictionary distance does not rewrite them.
public enum FuzzyPanelGrid {
    public struct Assignment: Equatable, Sendable {
        public var lines: [PanelOCRLine]
        public var inferredSlots: Int
    }

    public struct Cleanup: Equatable, Sendable {
        public var text: String
        public var changed: Bool
    }

    /// Levenshtein distance. Used for near-miss directory words, not for codes.
    public static func levenshtein(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        let aChars = Array(a)
        let bChars = Array(b)
        for i in 1...aChars.count {
            current[0] = i
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    /// Rewrite glare-era OCR before the schedule parser sees the line.
    public static func cleanup(_ raw: String) -> Cleanup {
        var text = raw
        text = text.replacingOccurrences(of: "A|C", with: "A/C", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "I|P", with: "1P", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "L|P", with: "1P", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "1|P", with: "1P", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "2|P", with: "2P", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "3|P", with: "3P", options: .caseInsensitive)
        if let range = text.range(of: #"(\d{2,3})\s*Y\s*\|\s*(\d{2,3})"#, options: .regularExpression) {
            let matched = String(text[range])
            let digits = matched.split(whereSeparator: { !$0.isNumber }).map(String.init)
            if digits.count >= 2 {
                text.replaceSubrange(range, with: "\(digits[0])Y/\(digits[1])")
            }
        }

        let tokens = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        var rewritten: [String] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if let digits = confusedDigits(token),
               let value = Int(digits), value >= 10,
               index + 1 < tokens.count,
               isAmpWord(tokens[index + 1]) {
                rewritten.append(digits + "A")
                index += 2
                continue
            }
            if let trip = rewriteTripToken(token) {
                rewritten.append(trip)
                index += 1
                continue
            }
            if let digits = confusedDigits(token), digits != token.uppercased() {
                rewritten.append(digits)
                index += 1
                continue
            }
            if let poles = rewritePoleToken(token) {
                rewritten.append(poles)
                index += 1
                continue
            }
            if let named = rewriteVocabToken(token) {
                rewritten.append(named)
                index += 1
                continue
            }
            rewritten.append(token)
            index += 1
        }

        let joined = rewritten.joined(separator: " ")
        let before = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        let changed = joined.uppercased() != before.uppercased()
        return Cleanup(text: joined, changed: changed)
    }

    /// Cluster by Y, then fill missing odd/even circuit numbers when the
    /// page actually has two columns. Lines without boxes keep input order.
    public static func assign(_ lines: [PanelOCRLine]) -> Assignment {
        let rows = cluster(lines)
        let boxes = lines.compactMap(\.box)
        let split = columnSplit(for: boxes)

        var nextOdd = 1
        var nextEven = 2
        var output: [PanelOCRLine] = []

        for row in rows {
            let cells: [(side: Side, line: PanelOCRLine)]
            if let split {
                let left = row.filter { ($0.box?.midX ?? 0) < split }
                let right = row.filter { ($0.box?.midX ?? 0) >= split }
                cells = [
                    (.left, join(left)),
                    (.right, join(right)),
                ].filter { !$0.line.text.trimmingCharacters(in: .whitespaces).isEmpty }
                if cells.isEmpty, let only = row.first {
                    cellsPlaceholder(&output, line: only, split: nil, nextOdd: &nextOdd, nextEven: &nextEven)
                    continue
                }
            } else if let only = join(row).text.isEmpty ? nil : join(row) {
                cells = [(.single, only)]
            } else {
                cells = []
            }

            for cell in cells {
                output.append(place(
                    cell.line,
                    side: cell.side,
                    split: split,
                    nextOdd: &nextOdd,
                    nextEven: &nextEven
                ))
            }
        }

        let inferred = output.filter(\.inferredCircuit).count
        return Assignment(lines: output, inferredSlots: inferred)
    }

    public static func prepare(_ lines: [PanelOCRLine]) -> Assignment {
        let cleaned = lines.map { line -> PanelOCRLine in
            let cleanup = cleanup(line.text)
            var copy = line
            copy.text = cleanup.text
            if cleanup.changed { copy.guessed = true }
            return copy
        }
        return assign(cleaned)
    }

    // MARK: - Tokens

    /// Digit-confused token (`ZO` → `20`). Requires a real digit or a `Z`,
    /// so ordinary words are not rewritten.
    static func confusedDigits(_ token: String) -> String? {
        let upper = token.uppercased()
        guard !upper.isEmpty, upper.count <= 4 else { return nil }
        let allowed = Set("0123456789OILZ")
        guard upper.allSatisfy({ allowed.contains($0) }) else { return nil }
        let hasDigit = upper.contains(where: \.isNumber)
        let hasZ = upper.contains("Z")
        guard hasDigit || hasZ else { return nil }
        let mapped = String(upper.map { character -> Character in
            switch character {
            case "O": return "0"
            case "I", "L": return "1"
            case "Z": return "2"
            default: return character
            }
        })
        guard mapped.allSatisfy(\.isNumber) else { return nil }
        return mapped
    }

    /// True for `BKR-3A`, `AHU-1`, and similar tokens that must survive cleanup.
    public static func isProtectedTradeCode(_ token: String) -> Bool {
        let upper = token.uppercased()
        guard upper.contains(where: \.isNumber) else { return false }
        guard let regex = try? NSRegularExpression(pattern: #"^[A-Z]{1,6}-?\d+[A-Z0-9]{0,4}$"#) else {
            return false
        }
        let range = NSRange(upper.startIndex..<upper.endIndex, in: upper)
        return regex.firstMatch(in: upper, options: [], range: range) != nil
    }

    // MARK: - Internals

    private enum Side {
        case left
        case right
        case single
    }

    private static let vocabOrder = [
        "LIGHTING", "RECEPTACLES", "RECEPTACLE", "BREAKER", "DISCONNECT",
        "TRANSFORMER", "SPARE", "SPACE", "MAIN", "NEMA", "PANEL", "VOLTAGE",
        "PHASE", "HVAC", "KITCHEN", "OFFICE", "GARAGE",
    ]

    private static func isAmpWord(_ token: String) -> Bool {
        let upper = token.uppercased()
        return upper == "A" || upper == "AMP" || upper == "AMPS"
    }

    private static func rewriteTripToken(_ token: String) -> String? {
        let upper = token.uppercased()
        guard upper.hasSuffix("A"), upper.count >= 2, upper.count <= 6 else { return nil }
        let head = String(upper.dropLast())
        guard let digits = confusedDigits(head), let value = Int(digits), value >= 10 else { return nil }
        let rewritten = digits + "A"
        return rewritten == upper ? nil : rewritten
    }

    private static func rewritePoleToken(_ token: String) -> String? {
        let upper = token.uppercased()
        let mapped = upper
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
        guard ["1P", "2P", "3P"].contains(mapped), mapped != upper else { return nil }
        return mapped
    }

    private static func rewriteVocabToken(_ token: String) -> String? {
        let upper = token.uppercased()
        guard upper.count >= 4 else { return nil }
        if upper.contains(where: \.isNumber) || isProtectedTradeCode(upper) { return nil }
        if vocabOrder.contains(upper) { return nil }
        let maxDistance = upper.count <= 6 ? 1 : 2
        var best: (name: String, distance: Int)?
        for name in vocabOrder {
            let distance = levenshtein(upper, name)
            guard distance > 0, distance <= maxDistance else { continue }
            if best == nil || distance < best!.distance {
                best = (name, distance)
            }
        }
        return best?.name
    }

    private static func cluster(_ lines: [PanelOCRLine]) -> [[PanelOCRLine]] {
        let boxed = lines.enumerated().filter { $0.element.box != nil }
        let plain = lines.filter { $0.box == nil }
        guard !boxed.isEmpty else {
            return plain.map { [$0] }
        }

        let sorted = boxed.sorted { ($0.element.box?.midY ?? 0) > ($1.element.box?.midY ?? 0) }
        var rows: [[PanelOCRLine]] = []
        var current: [PanelOCRLine] = []
        var anchorY = 0.0

        for item in sorted {
            let line = item.element
            let y = line.box?.midY ?? 0
            let height = line.box?.height ?? 0.03
            let tolerance = max(0.012, height * 0.7)
            if current.isEmpty || abs(y - anchorY) <= tolerance {
                if current.isEmpty { anchorY = y }
                current.append(line)
            } else {
                rows.append(current.sorted { ($0.box?.midX ?? 0) < ($1.box?.midX ?? 0) })
                current = [line]
                anchorY = y
            }
        }
        if !current.isEmpty {
            rows.append(current.sorted { ($0.box?.midX ?? 0) < ($1.box?.midX ?? 0) })
        }
        rows.append(contentsOf: plain.map { [$0] })
        return rows
    }

    /// Largest horizontal gap that actually separates two columns.
    static func columnSplit(for boxes: [PanelOCRBox]) -> Double? {
        let xs = boxes.map(\.midX).sorted()
        guard xs.count >= 2 else { return nil }
        var bestGap = 0.0
        var split = 0.5
        for index in 1..<xs.count {
            let gap = xs[index] - xs[index - 1]
            if gap > bestGap {
                bestGap = gap
                split = (xs[index] + xs[index - 1]) / 2
            }
        }
        guard bestGap >= 0.12 else { return nil }
        let left = xs.filter { $0 < split }.count
        guard left >= 1, xs.count - left >= 1 else { return nil }
        return split
    }

    private static func join(_ lines: [PanelOCRLine]) -> PanelOCRLine {
        let kept = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = kept.first else { return PanelOCRLine(text: "") }
        if kept.count == 1 { return first }
        let confidences = kept.compactMap(\.confidence)
        return PanelOCRLine(
            text: kept.map(\.text).joined(separator: " "),
            confidence: confidences.min(),
            box: unionBox(kept.compactMap(\.box)),
            alternates: [],
            guessed: kept.contains(where: \.guessed),
            inferredCircuit: kept.contains(where: \.inferredCircuit)
        )
    }

    private static func unionBox(_ boxes: [PanelOCRBox]) -> PanelOCRBox? {
        guard let first = boxes.first else { return nil }
        var minX = first.x
        var minY = first.y
        var maxX = first.x + first.width
        var maxY = first.y + first.height
        for box in boxes.dropFirst() {
            minX = min(minX, box.x)
            minY = min(minY, box.y)
            maxX = max(maxX, box.x + box.width)
            maxY = max(maxY, box.y + box.height)
        }
        return PanelOCRBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func cellsPlaceholder(
        _ output: inout [PanelOCRLine],
        line: PanelOCRLine,
        split: Double?,
        nextOdd: inout Int,
        nextEven: inout Int
    ) {
        output.append(place(line, side: .single, split: split, nextOdd: &nextOdd, nextEven: &nextEven))
    }

    private static func place(
        _ line: PanelOCRLine,
        side: Side,
        split: Double?,
        nextOdd: inout Int,
        nextEven: inout Int
    ) -> PanelOCRLine {
        let text = stripSmudgePrefix(line.text)
        if PanelDirectory.isIgnored(text) {
            var copy = line
            copy.text = text
            return copy
        }
        if let number = leadingCircuitNumber(in: text) {
            notePrinted(number, nextOdd: &nextOdd, nextEven: &nextEven)
            var copy = line
            copy.text = text
            return copy
        }
        guard split != nil, side == .left || side == .right, looksLikeUnnumberedLoad(text) else {
            var copy = line
            copy.text = text
            return copy
        }
        let number = side == .left ? nextOdd : nextEven
        if side == .left {
            nextOdd += 2
        } else {
            nextEven += 2
        }
        var copy = line
        copy.text = "\(number) \(text)"
        copy.guessed = true
        copy.inferredCircuit = true
        return copy
    }

    private static func notePrinted(_ number: Int, nextOdd: inout Int, nextEven: inout Int) {
        if number % 2 == 0 {
            nextEven = max(nextEven, number + 2)
        } else {
            nextOdd = max(nextOdd, number + 2)
        }
    }

    /// Drop a single smashed glyph in front of an otherwise readable load.
    private static func stripSmudgePrefix(_ text: String) -> String {
        let tokens = text.split(separator: " ").map(String.init)
        guard let first = tokens.first, tokens.count >= 2 else { return text }
        let smudge: Set<Character> = ["?", "•", "*", "I", "L", "O", "l"]
        guard first.count == 1, let character = first.first, smudge.contains(character) else { return text }
        return tokens.dropFirst().joined(separator: " ")
    }

    private static func leadingCircuitNumber(in text: String) -> Int? {
        guard let token = text.split(separator: " ").first.map(String.init) else { return nil }
        let upper = token.uppercased()
        let bare = upper.allSatisfy(\.isNumber)
            || (upper.dropLast().allSatisfy(\.isNumber) && upper.last?.isLetter == true && !upper.hasSuffix("A"))
        guard bare, let value = Int(upper.prefix(while: \.isNumber)), value >= 1, value <= PanelDirectory.maxCircuitNumber else {
            return nil
        }
        return value
    }

    private static func looksLikeUnnumberedLoad(_ text: String) -> Bool {
        if PanelDirectory.isIgnored(text) { return false }
        let tokens = text.split(separator: " ").map { $0.uppercased() }
        guard !tokens.isEmpty else { return false }
        if leadingCircuitNumber(in: text) != nil { return false }
        let loadWords = [
            "LIGHT", "LTG", "REC", "RECEPT", "SPARE", "SPACE", "AHU", "RTU",
            "HVAC", "MTR", "BKR", "BREAKER", "DISCONNECT", "TRANSFORMER", "PUMP", "FAN",
        ]
        let hasLoad = tokens.contains { token in loadWords.contains { token.contains($0) } }
        let hasTrip = tokens.contains { token in
            PanelDirectory.looksLikeTrip(token) || rewriteTripToken(token) != nil
        }
        let hasPole = tokens.contains { token in
            PanelDirectory.looksLikePoles(token) || rewritePoleToken(token) != nil
        }
        return hasLoad || hasTrip || hasPole
    }
}
