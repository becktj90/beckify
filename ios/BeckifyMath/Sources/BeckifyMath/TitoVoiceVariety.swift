import Foundation

/// Keeps Tito from leaning on "¡Oye, coño!" and gives him the occasional human sound.
///
/// - "Oye/Óyeme, coño" as an opener survives only about one line in five, and never on
///   two back-to-back lines. Otherwise it is swapped for a rotating Cuban / South Florida
///   jobsite opener. Profanity stays at his ceiling.
/// - About one line in three gets a smoker's cough as ElevenLabs v3 audio tags ([coughs],
///   [clears throat], now and then [coughs heavily] or [wheezes]) at a natural pause:
///   line start or between sentences, at most two per line. `CrewDialectRewrite.displayText` strips the tag
///   for the screen, copy, share and Apple speech; `/api/speak` gets it so the voice performs it.
///
/// Choices are a stable hash of the line, so SwiftUI re-reading the same line gets the
/// same answer. The last line is remembered only to enforce the back-to-back rule.
public enum TitoVoiceVariety {
    public static let openers: [String] = [
        "¡Mira, asere!",
        "Asere, ¿qué volá?",
        "¡Ñooo, compadre!",
        "Ven acá, mi hermano,",
        "¡Ey, monina!",
        "Acere, escúchame,",
        "¡Mira, cabrón!",
        "¡Coñooo, asere!",
        "Oíste, consorte,",
        "¡Pinga, compay!",
        "Dale, papo,",
        "Chico, mira,",
        "¡Mi socio!",
        "¡Oyiste, acere!",
        "Chico, esto está en candela,",
        "Asere, atiéndeme,",
        "¡Me cago en diez!",
        "Asere, no te me hagas el bobo,",
        "¡Qué clase de lío, mi hermano!",
        "Óyelo bien, mi ambia,",
    ]

    /// Tags eleven_v3 performs. Cough is weighted: he smoked for fifty years.
    public static let nonverbalTags: [String] = [
        "[coughs]", "[coughs]", "[coughs]", "[clears throat]", "[clears throat]", "[coughs heavily]", "[wheezes]",
    ]
    /// Most lines that get a cough get one; about one in four of those gets a second.
    public static let maxNonverbalPerLine = 2

    /// Roughly 1 in N lines keeps the classic opener / gets a nonverbal tag.
    public static let oyeKeepOneIn = 5
    public static let nonverbalOneIn = 3

    private static let oyePattern = #"^\s*¡?\s*(oye|óyeme|oyeme)\s*,?\s*coño\s*[!,.]*\s*"#

    /// Off only in tests that pin exact template text.
    nonisolated(unsafe) public static var isEnabled = true

    private static let lock = NSLock()
    nonisolated(unsafe) private static var lastInput: String?
    nonisolated(unsafe) private static var lastOutput: String?
    nonisolated(unsafe) private static var lastKeptOye = false

    /// Stateful entry point used by Crew Talk. Same input twice in a row returns the same output.
    public static func apply(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !trimmed.isEmpty else { return line }
        lock.lock(); defer { lock.unlock() }
        if trimmed == lastInput, let out = lastOutput { return out }
        let result = vary(trimmed, previousKeptOye: lastKeptOye)
        lastInput = trimmed
        lastOutput = result.line
        lastKeptOye = result.keptOye
        return result.line
    }

    /// Test hook.
    public static func resetHistory() {
        lock.lock(); defer { lock.unlock() }
        lastInput = nil; lastOutput = nil; lastKeptOye = false
    }

    public static func startsWithOyeCono(_ line: String) -> Bool {
        line.range(of: oyePattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Pure core: deterministic for a given line and previous-line state.
    public static func vary(_ line: String, previousKeptOye: Bool) -> (line: String, keptOye: Bool) {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = stableHash(text)
        var kept = false
        if let r = text.range(of: oyePattern, options: [.regularExpression, .caseInsensitive]) {
            if !previousKeptOye && h % UInt64(oyeKeepOneIn) == 0 {
                kept = true
            } else {
                let opener = openers[Int((h / 7) % UInt64(openers.count))]
                var rest = String(text[r.upperBound...])
                if let f = rest.first, opener.hasSuffix(",") { rest = f.lowercased() + rest.dropFirst() }
                text = opener + " " + rest
            }
        }
        let hasTag = text.range(of: #"\[[^\]]{1,24}\]"#, options: .regularExpression) != nil
        let t = stableHash(text + "#nv")
        if !hasTag && t % UInt64(nonverbalOneIn) == 0 {
            let first = nonverbalTags[Int((t / 11) % UInt64(nonverbalTags.count))]
            let pauses = sentenceBreaks(text)
            // First tag: line start, or the first sentence break when there is one and the hash says so.
            var inserts: [(String.Index, String)] = []
            if !pauses.isEmpty && (t / 3) % 2 == 0 {
                inserts.append((pauses[0], first))
            } else {
                inserts.append((text.startIndex, first))
            }
            if maxNonverbalPerLine > 1 && (t / 5) % 4 == 0, let last = pauses.last, last != inserts[0].0 {
                inserts.append((last, nonverbalTags[Int((t / 17) % UInt64(nonverbalTags.count))]))
            }
            var chars = Array(text)
            let offsets = inserts.map { (text.distance(from: text.startIndex, to: $0.0), $0.1) }
            for (offset, tag) in offsets.sorted(by: { $0.0 > $1.0 }) {
                chars.insert(contentsOf: Array(tag + " "), at: offset)
            }
            text = String(chars)
        }
        return (text, kept)
    }

    /// Indices just after ". ", "! " or "? " — natural pauses between sentences.
    static func sentenceBreaks(_ text: String) -> [String.Index] {
        var out: [String.Index] = []
        var i = text.startIndex
        while i < text.endIndex {
            let next = text.index(after: i)
            if ".!?".contains(text[i]), next < text.endIndex, text[next] == " " {
                let after = text.index(after: next)
                if after < text.endIndex { out.append(after) }
            }
            i = next
        }
        return out
    }

    /// FNV-1a; Swift's Hasher is seeded per launch.
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }

    /// Humberto's rare touch: about one line in ten ends with a quiet chuckle or throat clear, after the ask.
    public static let humbertoNonverbalOneIn = 10
    public static let humbertoTags: [String] = ["[chuckles]", "[clears throat]"]

    public static func humberto(_ line: String) -> String {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !text.isEmpty,
              text.range(of: #"\[[^\]]{1,24}\]"#, options: .regularExpression) == nil else { return line }
        let h = stableHash(text + "#humberto")
        guard h % UInt64(humbertoNonverbalOneIn) == 0 else { return text }
        return text + " " + humbertoTags[Int((h / 13) % UInt64(humbertoTags.count))]
    }

    /// Dre's energy on a deep bass voice: about one line in three gets spoken-only tags,
    /// at the start or between sentences, at most two per line. [sighs] is rare.
    public static let dreOneIn = 3
    public static let dreTags: [String] = [
        "[laughs]", "[laughs]", "[excited]", "[excited]", "[shouting]", "[shouting]", "[chuckles]", "[chuckles]", "[sighs]",
    ]

    public static func dre(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !text.isEmpty,
              text.range(of: #"\[[^\]]{1,24}\]"#, options: .regularExpression) == nil else { return line }
        let h = stableHash(text + "#dre")
        guard h % UInt64(dreOneIn) == 0 else { return text }
        var inserts: [(Int, String)] = [(0, dreTags[Int((h / 7) % UInt64(dreTags.count))])]
        let pauses = sentenceBreaks(text)
        if (h / 5) % 3 == 0, let last = pauses.last {
            inserts.append((text.distance(from: text.startIndex, to: last), dreTags[Int((h / 13) % UInt64(dreTags.count))]))
        }
        var chars = Array(text)
        for (offset, tag) in inserts.sorted(by: { $0.0 > $1.0 }) {
            chars.insert(contentsOf: Array(tag + " "), at: offset)
        }
        text = String(chars)
        return text
    }

    /// Crew Talk hook for every helper: Tito variety, Humberto's rare chuckle, everyone else unchanged.
    public static func voiced(crew: CrewTalkMember, _ line: String) -> String {
        switch crew {
        case .titoSolano: return apply(line)
        case .humbertoArismendi, .humbertoArismendiEnglish: return humberto(line)
        case .dreLacey: return dre(line)
        default: return line
        }
    }
}
