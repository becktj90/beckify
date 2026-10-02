import Foundation

/// Comedy-only English dialect stylizer — an exaggerated "Deep South" drawl
/// for the Translator's novelty output. This is same-language wordplay, not
/// a translation and not a voice/ethnicity impression: no accent synthesis,
/// no claim about how anyone actually talks. Purely a text transform plus
/// whatever TTS voice is already selected.
public enum DeepSouthDialect {
    public static let honestLimit =
        "Comedy word-swap on the English text only — not a translation, not a real accent, not a real place's dialect. For laughs."

    /// Case-preserving whole-word substitutions, longest phrases first so
    /// multi-word matches win before their single-word pieces do.
    private static let phraseSwaps: [(String, String)] = [
        ("you all", "y'all"),
        ("you guys", "y'all"),
        ("going to", "fixin' to"),
        ("about to", "fixin' to"),
        ("a lot of", "a whole mess of"),
        ("kind of", "kinda"),
        ("sort of", "kinda"),
        ("right now", "directly"),
        ("i am going to", "i'm fixin' to"),
    ]

    private static let wordSwaps: [String: String] = [
        "you": "y'all",
        "your": "yer",
        "yours": "yer'n",
        "is not": "ain't",
        "isn't": "ain't",
        "aren't": "ain't",
        "am not": "ain't",
        "doesn't": "don't",
        "cannot": "cain't",
        "can't": "cain't",
        "will": "gonna",
        "hello": "well howdy",
        "hi": "howdy",
        "hey": "hey there",
        "friend": "buddy",
        "yes": "yessiree",
        "no": "nuh-uh, no sir",
        "very": "mighty",
        "really": "plumb",
        "crazy": "nuttier than a fruitcake",
        "tired": "wore slap out",
        "hot": "hotter than a goat's rear end in a pepper patch",
        "fast": "quick as a cat on a hot tin roof",
        "angry": "madder than a wet hen",
        "drunk": "three sheets to the wind",
        "surprised": "like a possum caught in the headlights",
        "wrong": "all catawampus",
        "broken": "busted all to pieces",
        "good": "finer than frog hair",
        "great": "finer than frog hair split four ways",
        "small": "little bitty",
        "big": "big ol'",
        "food": "vittles",
        "breakfast": "brekfust",
        "think": "reckon",
        "guess": "reckon",
        "child": "young'un",
        "children": "young'uns",
        "people": "folks",
        "everyone": "all y'all",
        "stop": "quit it now",
        "please": "if you'd be so kind, sugar",
    ]

    /// One closing flavor phrase, chosen deterministically from `seed` so the
    /// same input always produces the same output (no flaky tests, no
    /// randomness the caller can't reproduce).
    private static let closers: [String] = [
        "if that don't beat all.",
        "bless your heart.",
        "well I'll be.",
        "I do declare.",
        "sure as the world.",
        "and that's the Lord's honest truth.",
    ]

    /// Rewrite `text` into an exaggerated, comedic Southern-drawl rendering.
    /// Deterministic for a given `seed` — same input and seed always give the
    /// same output. Empty or whitespace-only input returns unchanged.
    public static func stylize(_ text: String, seed: Int = 0) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        var working = trimmed
        for (phrase, replacement) in phraseSwaps {
            working = replacing(phrase, in: working, with: replacement)
        }
        for (word, replacement) in wordSwaps {
            working = replacing(word, in: working, with: replacement)
        }
        working = dropTrailingG(in: working)

        let closer = closers[((seed % closers.count) + closers.count) % closers.count]
        if let last = working.last, ".!?,".contains(last) {
            working.removeLast()
        }
        return working + ", " + closer
    }

    /// Case-insensitive, word-boundary-respecting replace that preserves the
    /// original match's capitalization style (all-caps, capitalized, or lowercase).
    private static func replacing(_ target: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "\\b\(NSRegularExpression.escapedPattern(for: target))\\b",
            options: [.caseInsensitive]
        ) else { return text }

        let nsText = text as NSString
        var result = ""
        var lastEnd = 0
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            result += nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            let matched = nsText.substring(with: match.range)
            result += matchCase(of: matched, applyTo: replacement)
            lastEnd = match.range.location + match.range.length
        }
        result += nsText.substring(from: lastEnd)
        return result
    }

    private static func matchCase(of original: String, applyTo replacement: String) -> String {
        if original == original.uppercased(), original != original.lowercased() {
            return replacement.uppercased()
        }
        if let first = original.first, first.isUppercase {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    /// Drops a trailing "g" from common "-ing" words (going -> goin') for
    /// words not already covered by an explicit swap above.
    private static func dropTrailingG(in text: String) -> String {
        // {2,} (not {3,}) so short stems like "do"/"go"/"be" still catch
        // "doing"/"going"/"being" — a 3-letter minimum would silently skip them.
        guard let regex = try? NSRegularExpression(pattern: "\\b([A-Za-z]{2,})ing\\b") else { return text }
        let nsText = text as NSString
        var result = ""
        var lastEnd = 0
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            result += nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            let whole = nsText.substring(with: match.range)
            result += String(whole.dropLast()) + "'"
            lastEnd = match.range.location + match.range.length
        }
        result += nsText.substring(from: lastEnd)
        return result
    }
}
