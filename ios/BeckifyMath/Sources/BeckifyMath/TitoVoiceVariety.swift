import Foundation

/// Keeps Tito from leaning on "¡Oye, coño!" and gives him the occasional human sound.
///
/// - "Oye/Óyeme, coño" as an opener survives only about one line in five, and never on
///   two back-to-back lines. Otherwise it is swapped for a rotating Cuban / South Florida
///   jobsite opener. Profanity stays at his ceiling.
/// - About one line in five gets an ElevenLabs v3 audio tag up front ([coughs],
///   [clears throat], [chuckles], [sighs]). `CrewDialectRewrite.displayText` strips the tag
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
        "¡Coñooo, caballero!",
        "Oíste, consorte,",
        "¡Pinga, compay!",
        "Dale, papo,",
        "Chico, mira,",
        "¡Mi socio!",
        "Caballero, atiéndeme,",
        "¡Me cago en diez!",
        "Asere, no te me hagas el bobo,",
        "¡Qué clase de lío, caballero!",
        "Óyelo bien, mi ambia,",
    ]

    /// Tags eleven_v3 performs. Cough is weighted: he smoked for fifty years.
    public static let nonverbalTags: [String] = [
        "[coughs]", "[coughs]", "[clears throat]", "[chuckles]", "[sighs]",
    ]

    /// Roughly 1 in N lines keeps the classic opener / gets a nonverbal tag.
    public static let oyeKeepOneIn = 5
    public static let nonverbalOneIn = 5

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
            text = nonverbalTags[Int((t / 11) % UInt64(nonverbalTags.count))] + " " + text
        }
        return (text, kept)
    }

    /// FNV-1a; Swift's Hasher is seeded per launch.
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }
}
