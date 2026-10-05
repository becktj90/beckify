import Foundation

/// Turns a user's line into one crew member's dialect.
/// Wording may change a lot. The ask survives. Slurs and insults are never echoed.
/// Never glue a stock opener onto the raw sentence ("I'm fixin' to you are so good…",
/// "Would you please hi I need…").
enum CrewDialectRewrite {
    static func rewrite(crew: CrewTalkMember, raw: String) -> String {
        switch crew {
        case .bodieHale: return bodie(raw)
        case .titoSolano: return tito(raw)
        case .lupitaReyes: return lupita(raw)
        case .juniePell: return junie(raw)
        case .pearl: return pearl(raw)
        case .sloaneMerritt: return sloane(raw)
        }
    }

    // MARK: - Intent
    //
    // Keyword hits go through CrewRewriteGuard (word boundaries on folded text).
    // Nil means do not template: negation, question, opposing polarity,
    // more than one intent, or more than 12 words.

    private static func guarded(_ line: String, raw: String, fallback: String) -> String {
        guard CrewRewriteGuard.isConsistent(translation: raw, persona: line) else { return fallback }
        return safe(line, raw: raw, fallback: fallback)
    }

    /// Content words with the original sentence broken apart so a template cannot
    /// paste the raw line back on the end of a stock opener.
    private static func voicedWords(_ raw: String) -> String {
        let stop: Set<String> = [
            "the", "a", "an", "and", "or", "to", "for", "of", "me", "my", "that", "this",
            "please", "you", "your", "just", "now", "get", "it", "with", "from", "into",
            "hi", "hey", "hello", "need", "want", "are", "was", "were", "been", "have",
            "has", "had", "so", "very", "really", "all", "these", "those", "them",
        ]
        let words = extractAsk(raw).split(separator: " ").map(String.init).filter { word in
            word.count > 2 && !stop.contains(word)
        }
        if words.isEmpty { return "that open item" }
        if words.count == 1 { return words[0] }
        let head = words.dropLast().joined(separator: ", ")
        return "\(head), then \(words.last!)"
    }

    private static func safe(_ line: String, raw: String, fallback: String) -> String {
        let foldedRaw = fold(raw)
        guard foldedRaw.count >= 8 else { return line }
        if fold(line).contains(foldedRaw) { return fallback }
        return line
    }

    // MARK: - Pearl

    static func pearl(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let cleaned = scrub(trimmed)
        guard !cleaned.isEmpty else {
            return "When you have a moment, tell me what you need."
        }
        let line: String
        let fallback = "When you have a moment, tell me the part you need help with."
        switch CrewRewriteGuard.intent(trimmed) {
        case .cutPower:
            line = "Please cut the power, and let's stay clear of it."
        case .conduit:
            line = "When you have a moment, that conduit needs to come this way."
        case .ladder:
            line = "The ladder needs to move over, if you have a moment."
        case .head:
            line = "Please mind the clearance above your head."
        case .wire:
            line = "A little more wire would help, whenever you have a moment."
        case .mess:
            line = "Someone left a mess, and I'd like to know who, when you have a moment."
        case .feeder:
            line = "Please land that feeder before lunch, if you would."
        case .breaker:
            line = "Please leave that breaker alone until we're ready."
        case .racks:
            line = "Those racks could use a proper clean, whenever you have a moment."
        case .hold:
            line = "Please hold this steady for a moment."
        case .compliment:
            line = "You've got such a gift for this, and I wanted you to hear it."
        case .greeting:
            line = "Hello there. Tell me what you need, when you have a moment."
        case .free:
            line = "When you have a moment, the thing to handle is \(voicedWords(cleaned))."
        case nil:
            line = fallback
        }
        return guarded(line, raw: trimmed, fallback: fallback)
    }

    // MARK: - Sloane

    /// Meeting-speak only. A rude line still leaves as a meeting, never as the original words.
    static func sloane(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let key = fold(trimmed)
        if let known = sloaneKnown[key] { return known }
        // Pass the raw line. scrub() splits "Don't" into "Don t" and would hide the negation.
        let topic = sloaneTopic(trimmed)
        let templates: [(String) -> String] = [
            { topic in
                "Team, I want to circle back on \(topic). I'll keep you in the loop and take the rest offline."
            },
            { topic in
                "Quick ping on \(topic). If we pivot there we move the needle without boiling the ocean."
            },
            { topic in
                "Putting \(topic) on my radar. Low-hanging fruit if we touch base and free up the bandwidth."
            },
            { topic in
                "Let's align on \(topic). I'll ping leadership so they hear it was you."
            },
            { topic in
                "Small paradigm shift: \(topic). I'll circle back once we touch base."
            },
            { topic in
                "I want \(topic) to move the needle. Let's take the low-hanging fruit and park the rest offline."
            },
            { topic in
                "Hard stop on the noise around \(topic). I'll piggyback with the folks who have bandwidth."
            },
            { topic in
                "Let's align the flywheel on \(topic). I'll keep it on my radar and bifurcate the rest."
            },
        ]
        let line = templates[rotate(key, templates.count)](topic)
        return safe(line, raw: trimmed, fallback: "Team, I want to circle back on the open item. I'll take the rest offline.")
    }

    private static let sloaneKnown: [String: String] = [
        "stop talking and get that feeder in before lunch": "Team, I want to circle back on landing the feeder before lunch. I'll piggyback with leadership so they hear it was you.",
        "kill the power": "Team, I want to circle back on cutting the power. I'll take the rest offline.",
        "hand me that conduit": "Team, let's touch base on that conduit handoff. I'll ping you and keep leadership in the loop.",
        "move the ladder": "Team, I want the ladder relocation on my radar. Let's pivot that before the hard stop.",
        "watch your head": "Team, head clearance is the North Star for this minute. Let's stay in the loop.",
        "we need more wire": "Team, wire supply is on my radar. I'll take the rest offline.",
        "who left this mess": "Team, let's bifurcate the housekeeping item from the rest of the agenda. I'll ping the owner.",
    ]

    private static func sloaneTopic(_ raw: String) -> String {
        switch CrewRewriteGuard.intent(raw) {
        case .cutPower: return "cutting the power"
        case .conduit: return "that conduit handoff"
        case .ladder: return "relocating the ladder"
        case .head: return "head clearance"
        case .wire: return "wire supply"
        case .mess: return "the open housekeeping item"
        case .feeder:
            return raw.lowercased().contains("lunch") ? "landing the feeder before lunch" : "the feeder"
        case .breaker: return "that breaker"
        case .racks: return "clearing those racks"
        case .hold: return "holding that for a moment"
        case .compliment: return "how strong this work is"
        case .greeting: return "the open item"
        case .free:
            return voicedWords(raw)
        case nil:
            // Rejected asks keep a neutral topic so a stock line cannot flip polarity.
            return "the open item"
        }
    }

    // MARK: - Junie

    static func junie(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let cleaned = scrub(trimmed)
        let line: String
        let fallback = "Bless your heart, say that once more in plain words and I'll tend to it."
        switch CrewRewriteGuard.intent(trimmed) {
        case .cutPower:
            line = "That power needs to come off, bless your heart. Don't get your knickers in a knot."
        case .conduit:
            line = "That conduit belongs over yonder in a working hand. It'll fit better than a sock on a rooster."
        case .ladder:
            line = "That ladder needs to slide a fur piece. Don't take any wooden nickels while it moves."
        case .head:
            line = "Mind the clearance above you. I'm nervous as a long-tailed cat in a room full of rocking chairs."
        case .wire:
            line = "We're shy on wire, and more has to come from over yonder. Bless your heart."
        case .mess:
            line = "Well I'll be Sam Browned — this mess needs setting right. Bless your heart, let's own it."
        case .feeder:
            line = "That feeder has to land before lunch. Don't get your knickers in a knot — we'll beat the cows home."
        case .breaker:
            line = "Leave that breaker be, over yonder. Heavens to Betsy, it stays off."
        case .racks:
            line = "Those racks need a real clean, bless your heart. We'll set them right over yonder."
        case .hold:
            line = "Keep a gentle hold on this for a moment, and don't get your knickers in a knot."
        case .compliment:
            line = "Bless your heart, you've got a real gift for this. Slick as a ribbon on an ice cube."
        case .greeting:
            line = "Hey there, bless your heart. Good to see you over yonder."
        case .free:
            line = "Listen here — \(voicedWords(cleaned)), over yonder. Bless your heart."
        case nil:
            line = fallback
        }
        return guarded(line, raw: trimmed, fallback: fallback)
    }

    // MARK: - Bodie

    /// Shown, copied, shared, docked, and spoken by Apple. Laugh tags stay in the
    /// string `/api/speak` receives so ElevenLabs can perform them.
    static func displayText(_ raw: String) -> String {
        let stripped = raw.replacingOccurrences(
            of: #"\[[^\]]{1,24}\]"#,
            with: "",
            options: .regularExpression
        )
        let collapsed = stripped.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Mellow California helper. Drawn-out vowels, filler, warm. Laugh tags sit
    /// after the ask, never before a safety instruction, and at most twice.
    static func bodie(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let cleaned = scrub(trimmed)
        let line: String
        let fallback = "Okaaay, so let's just ease into that open item, maaan. [chuckles] Easy does it."
        switch CrewRewriteGuard.intent(trimmed) {
        case .cutPower:
            line = "Duuude, kill that power first, okay. For real. [chuckles] Then we're golden, man."
        case .conduit:
            line = "Duuude, pass that conduit over when you can, maaan. Easy does it."
        case .ladder:
            line = "Okaaay, slide that ladder over, nice and easy, man. Then we're golden."
        case .head:
            line = "Duuude, mind your head up there, okay. For real. [exhales] Easy does it, man."
        case .wire:
            line = "Duuude, grab more wire, maaan. Easy does it, for real."
        case .mess:
            line = "Whoa, this mess got away from us, man. [giggles] Let's tidy it and we're golden."
        case .feeder:
            line = "Duuude, get that feeder set before the lunch bell, okay. For real. Then we're golden, man."
        case .breaker:
            line = "Duuude, that breaker stays put, okay. For real. [chuckles] Then we're golden, man."
        case .racks:
            line = "Okaaay, let's get these racks cleaned up, maaan. Easy does it."
        case .hold:
            line = "Maaan, keep a hold on this for a breath. [wheezing] Then we're golden."
        case .compliment:
            line = "Whoa, look at you, man — you're, like, a natural. [laughs] Heh-heh. Totally."
        case .greeting:
            line = "Heyyy, good to see you out here, man. Totally."
        case .free:
            line = "Okay okay, so let's handle \(voicedWords(cleaned)), maaan. [giggles] Easy does it."
        case nil:
            line = fallback
        }
        return guarded(line, raw: trimmed, fallback: fallback)
    }

    // MARK: - Lupita

    /// Mexican Spanish, Jalisco and Mexico City. Diminutives and light asides.
    /// No heavy profanity, no caricature spelling, no real person.
    static func lupita(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // Like Tito: only a recognized ask gets a template. Everything else is empty so
        // callers speak the real translation. A canned fallback here made her answer
        // every question, negation, and long sentence with the same line.
        let line: String
        switch CrewRewriteGuard.intent(trimmed) {
        case .cutPower:
            line = "Chin, corta la corriente primero. No manches, luego quedamos tranquilos."
        case .conduit:
            line = "Pásame ese conduit, ahorita, un ladito más cerca."
        case .ladder:
            line = "Mueve esa escalera un poquito, despacito, y déjala firme."
        case .head:
            line = "Cuidado con la cabeza, chin. Despacito ahí arriba."
        case .wire:
            line = "Nos falta un poquito de cable. Tráeme más alambre, ahorita."
        case .mess:
            line = "Chin, este desorden se nos fue. Lo acomodamos juntitos y quedamos en paz."
        case .feeder:
            line = "Hay que aterrizar ese alimentador antes del almuerzo, despacito."
        case .breaker:
            line = "Deja ese breaker quieto, chin. Ahorita no lo toques."
        case .racks:
            line = "Esos racks piden una limpiadita, órale. Los dejamos bonitos."
        case .hold:
            line = "Sostén esto un momentito, despacito. Ahí mero."
        case .compliment:
            line = "Mira nada más, lo haces muy bonito. Eres un naturalito, chin."
        case .greeting:
            line = "Hola, qué gusto verte. Aquí andamos, despacito."
        case .free, nil:
            return ""
        }
        return guarded(line, raw: trimmed, fallback: "")
    }

    // MARK: - Tito

    /// Cuban jobsite rewrite. The ask stays. Slurs are still scrubbed and never echoed.
    /// Workplace cussing is the ceiling this character is allowed to hit.
    static func tito(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let key = fold(trimmed)
        if let known = titoKnown[key] { return known }
        let scrubbed = scrub(trimmed)
        if scrubbed.isEmpty {
            return "Óyeme, coño, dime qué carajo necesitas en la obra, mierda."
        }
        // A2: no .free template. Unmatched or rejected text is empty so callers use the translation.
        let line: String
        switch CrewRewriteGuard.intent(trimmed) {
        case .cutPower:
            line = "¡Coño, corta esa pinga de corriente ahora mismo, carajo!"
        case .conduit:
            line = "Pásame ese conduit, cabrón, que lo necesito en la mano ahora, coño."
        case .ladder:
            line = "Mueve esa escalera, mi hermano, coño, y déjala firme, carajo."
        case .head:
            line = "Ojo con la cabeza, coño. No te me golpees ahí arriba, mierda."
        case .wire:
            line = "Falta cable, mierda. Tráeme más alambre ya, coño, carajo."
        case .mess:
            line = "¿Quién dejó este desorden de mierda? Recógelo ahora, cabrón, coño."
        case .feeder:
            line = "¡Coño, deja la habladera y mete ese alimentador antes del almuerzo, carajo!"
        case .breaker:
            line = "Óyeme, coño, deja ese breaker quieto, carajo. Ahora, mierda."
        case .racks:
            line = "Óyeme, coño, limpia esos racks ya, carajo. Sin excusa, mierda."
        case .hold:
            line = "Óyeme, coño, sostén eso un momento, carajo. Firme, mierda."
        case .compliment:
            line = "Óyeme, coño, esto lo haces de pinga, carajo. Sigue así, mierda."
        case .greeting:
            line = "¿Qué bolá, coño? Aquí estoy, carajo."
        case .free, nil:
            return ""
        }
        return guarded(line, raw: trimmed, fallback: "")
    }

    private static let titoKnown: [String: String] = [
        "kill the power": "¡Coño, corta esa pinga de corriente ahora mismo, carajo!",
        "corta la corriente": "Óyeme, la corriente córtala ya, coño, con cuidado, mierda.",
        "hand me that conduit": "Pásame ese conduit, cabrón, que lo necesito en la mano ahora, coño.",
        "move the ladder": "Mueve esa escalera, mi hermano, coño, y déjala firme, carajo.",
        "watch your head": "Ojo con la cabeza, coño. No te me golpees ahí arriba, mierda.",
        "we need more wire": "Falta cable, mierda. Tráeme más alambre ya, coño, carajo.",
        "who left this mess": "¿Quién dejó este desorden de mierda? Recógelo ahora, cabrón, coño.",
        "hola": "¿Qué bolá, coño? Aquí estoy, carajo.",
        "stop talking and get that feeder in before lunch": "¡Coño, deja la habladera y mete ese alimentador antes del almuerzo, carajo!",
    ]

    // MARK: - Shared

    /// Pull the real ask out of greetings and "I need you to…" wrappers.
    static func extractAsk(_ raw: String) -> String {
        var text = scrub(raw)
        if text.isEmpty { return "" }
        text = text.replacingOccurrences(of: "kill the ", with: "cut the ", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "kill ", with: "cut ", options: .caseInsensitive)
        var lower = text.lowercased()
        let prefixes = [
            "hi i need you to ", "hey i need you to ", "hello i need you to ",
            "hi i want you to ", "hey i want you to ",
            "hi i need you ", "hey i need you ",
            "i need you to ", "i want you to ", "i need you ", "i want you ",
            "i need to ", "i want to ",
            "can you please ", "could you please ", "would you please ",
            "can you ", "could you ", "would you ", "will you ",
            "please ", "hi ", "hey ", "hello ",
            "and ",
        ]
        var changed = true
        while changed {
            changed = false
            lower = text.lowercased()
            for prefix in prefixes {
                if lower.hasPrefix(prefix) {
                    text = String(text.dropFirst(prefix.count))
                    changed = true
                    break
                }
            }
        }
        lower = text.lowercased()
        if lower.hasPrefix("stop talking and ") {
            text = String(text.dropFirst("stop talking and ".count))
        }
        while let last = text.last, ".!?".contains(last) { text.removeLast() }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first else { return "" }
        return String(first).lowercased() + text.dropFirst()
    }

    fileprivate static func scrub(_ raw: String) -> String {
        var text = raw
        let phrases = [
            "shut your mouth", "shut up", "fuck you", "screw you", "piss off", "go to hell",
        ]
        for phrase in phrases {
            text = text.replacingOccurrences(of: phrase, with: " ", options: .caseInsensitive)
        }
        let parts = text.split { character in
            character.isWhitespace || character.isPunctuation
        }
        let kept = parts.map(String.init).filter { token in
            !blockedTokens.contains(token.lowercased())
        }
        return kept.joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Insults and slurs. Dropped so a rewrite cannot echo them.
    private static let blockedTokens: Set<String> = [
        "fuck", "fucking", "fuckin", "fucker", "fucked", "shit", "shitty", "bullshit",
        "bitch", "bastard", "asshole", "ass", "damn", "damned", "dammit", "crap",
        "idiot", "idiots", "stupid", "dumb", "moron", "retard", "retarded",
        "dick", "cock", "piss", "pissed", "whore", "slut", "hell",
        "nigger", "nigga", "spic", "chink", "kike", "fag", "faggot", "tranny", "wetback",
        "maricon", "maricón", "mayate", "sudaca",
    ]

    static func fold(_ raw: String) -> String {
        var text = raw.lowercased()
        let drop = CharacterSet.punctuationCharacters.union(.symbols)
        text = text.unicodeScalars.filter { !drop.contains($0) }.map(String.init).joined()
        return text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func rotate(_ key: String, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Int(hash % UInt64(count))
    }
}

/// Decides whether a crew template may stand in for a line.
/// `intent` matches whole words on folded text. Substring hits (`overhead`, `track`, `Household`) do not count.
public enum CrewRewriteGuard {
    enum Intent: Equatable {
        case cutPower
        case conduit
        case ladder
        case head
        case wire
        case mess
        case feeder
        case breaker
        case racks
        case hold
        case compliment
        case greeting
        /// No keyword. English crew may add a short opener. Tito returns empty (A2).
        case free
    }

    /// Word-boundary intent on folded text. Nil when a template would be unsafe.
    static func intent(_ text: String) -> Intent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if isQuestion(trimmed) { return nil }
        let scrubbed = CrewDialectRewrite.scrub(trimmed)
        if scrubbed.isEmpty { return .free }
        let folded = CrewDialectRewrite.fold(scrubbed)
        let words = folded.split(whereSeparator: { $0.isWhitespace })
        if words.count > 12 { return nil }
        // Fold the original so "Don't" stays one token. scrub() would split it on the apostrophe.
        if hasCommandNegation(trimmed) { return nil }
        if hasOpposingPowerPolarity(folded) { return nil }

        var found: [Intent] = []
        if isDeenergizePower(folded) { found.append(.cutPower) }
        let patterns: [(Intent, String)] = [
            (.conduit, #"\bconduits?\b"#),
            (.ladder, #"\b(ladders?|escaleras?)\b"#),
            (.head, #"\b(head|cabeza)\b"#),
            (.wire, #"\b(wires?|alambres?|cables?)\b"#),
            (.mess, #"\b(mess|messes|desorden)\b"#),
            (.feeder, #"\b(feeders?|aliment\w*)\b"#),
            (.breaker, #"\bbreakers?\b"#),
            (.racks, #"\bracks?\b"#),
            (.hold, #"\bhold\b"#),
        ]
        for (intent, pattern) in patterns where matches(pattern, in: folded) {
            found.append(intent)
        }
        if matches(#"\b(good at|so good|great at)\b|\byou are\b.*\bgood\b|\byoure\b.*\bgood\b"#, in: folded) {
            found.append(.compliment)
        }
        if found.count > 1 { return nil }
        if let only = found.first { return only }
        if folded == "hola" || folded == "hi" || folded == "hey" || folded == "hello" {
            return .greeting
        }
        return .free
    }

    /// Persona wording must not flip polarity, negation, or question-ness against the translation.
    public static func isConsistent(translation: String, persona: String) -> Bool {
        if hasCommandNegation(translation) != hasCommandNegation(persona) { return false }
        if isQuestion(translation) != isQuestion(persona) { return false }
        switch (powerPolarity(translation), powerPolarity(persona)) {
        case (.deenergize, .energize), (.energize, .deenergize):
            return false
        default:
            return true
        }
    }

    private enum PowerPolarity {
        case deenergize
        case energize
    }

    private static let powerWord = #"\b(power|corriente)\b"#
    private static let deenergizeWord = #"\b(kill|kills|killed|killing|cut|cuts|cutting|corta|corte|cortes|corten|cortar|apaga|apagar|desconecta|desconectar|disconnect|disconnects|off|mata|matar)\b"#
    private static let energizeWord = #"\b(on|prende|prender|enciende|encender|energize|energizes|restore|restores)\b"#

    private static let negationTokens: Set<String> = [
        "dont", "never", "not", "no", "cant", "cannot", "nunca", "jamas", "jamás",
    ]

    private static let questionStarters: Set<String> = [
        "is", "are", "was", "were", "am", "do", "does", "did",
        "can", "could", "would", "will", "shall", "should",
        "what", "who", "whom", "whose", "where", "why", "how", "which",
        "donde", "que", "qué", "como", "cómo", "cual", "cuál", "quien", "quién",
    ]

    /// `cutPower` only when the power words are a deenergize, not a restore.
    private static func isDeenergizePower(_ folded: String) -> Bool {
        guard matches(powerWord, in: folded) else { return false }
        return matches(deenergizeWord, in: folded) && !matches(energizeWord, in: folded)
    }

    /// Energize (or mixed energize + deenergize) on a power line. Not a cut template.
    private static func hasOpposingPowerPolarity(_ folded: String) -> Bool {
        guard matches(powerWord, in: folded) else { return false }
        return matches(energizeWord, in: folded)
    }

    private static func powerPolarity(_ text: String) -> PowerPolarity? {
        let folded = CrewDialectRewrite.fold(text)
        guard matches(powerWord, in: folded) else { return nil }
        let de = matches(deenergizeWord, in: folded)
        let en = matches(energizeWord, in: folded)
        if de && !en { return .deenergize }
        if en && !de { return .energize }
        return nil
    }

    /// Command negation near the start of the first sentence. Later flavor ("Don't get your knickers…") does not count.
    private static func hasCommandNegation(_ text: String) -> Bool {
        let folded = CrewDialectRewrite.fold(firstClause(text))
        let tokens = folded.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if tokens.count >= 2 && tokens[0] == "do" && tokens[1] == "not" { return true }
        let window = Array(tokens.prefix(6))
        if window.contains(where: { negationTokens.contains($0) }) { return true }
        // scrub() splits the apostrophe in "Don't" / "can't" before fold can join them.
        for index in window.indices.dropLast() where window[index + 1] == "t" {
            if window[index] == "don" || window[index] == "can" || window[index] == "won" {
                return true
            }
        }
        return false
    }

    private static func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("?") || trimmed.contains("¿") { return true }
        let folded = CrewDialectRewrite.fold(firstClause(trimmed))
        guard let first = folded.split(whereSeparator: { $0.isWhitespace }).first else { return false }
        return questionStarters.contains(String(first))
    }

    private static func firstClause(_ text: String) -> String {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = rest.first, "¡¿".contains(first) {
            rest.removeFirst()
        }
        rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = rest.firstIndex(where: { ".!?".contains($0) }) ?? rest.endIndex
        return String(rest[..<end])
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
