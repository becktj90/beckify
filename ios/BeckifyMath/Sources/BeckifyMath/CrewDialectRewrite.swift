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
        case .juniePell: return junie(raw)
        case .pearl: return pearl(raw)
        case .sloaneMerritt: return sloane(raw)
        }
    }

    // MARK: - Intent

    private enum Intent {
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
        case free
    }

    private static func intent(for scrubbed: String) -> Intent {
        let key = fold(scrubbed)
        if key == "hola" || key == "hi" || key == "hey" || key == "hello" { return .greeting }
        let lower = scrubbed.lowercased()
        if lower.contains("good at") || lower.contains("so good") || lower.contains("great at")
            || (lower.contains("you are") && lower.contains("good"))
            || (lower.contains("you're") && lower.contains("good"))
            || (lower.contains("youre") && lower.contains("good")) {
            return .compliment
        }
        if lower.contains("power") || lower.contains("corriente") { return .cutPower }
        if lower.contains("conduit") { return .conduit }
        if lower.contains("ladder") || lower.contains("escalera") { return .ladder }
        if lower.contains("head") || lower.contains("cabeza") { return .head }
        if lower.contains("wire") || lower.contains("alambre") || lower.contains("cable") { return .wire }
        if lower.contains("mess") || lower.contains("desorden") { return .mess }
        if lower.contains("feeder") || lower.contains("aliment") { return .feeder }
        if lower.contains("breaker") { return .breaker }
        if lower.contains("rack") { return .racks }
        if lower.contains("hold") { return .hold }
        return .free
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
        switch intent(for: cleaned) {
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
        }
        return safe(line, raw: trimmed, fallback: "When you have a moment, tell me the part you need help with.")
    }

    // MARK: - Sloane

    /// Meeting-speak only. A rude line still leaves as a meeting, never as the original words.
    static func sloane(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let key = fold(trimmed)
        if let known = sloaneKnown[key] { return known }
        let cleaned = scrub(trimmed)
        let topic = sloaneTopic(cleaned.isEmpty ? trimmed : cleaned)
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
        switch intent(for: raw) {
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
        }
    }

    // MARK: - Junie

    static func junie(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let cleaned = scrub(trimmed)
        let line: String
        switch intent(for: cleaned.isEmpty ? trimmed : cleaned) {
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
        }
        return safe(line, raw: trimmed, fallback: "Bless your heart, say that once more in plain words and I'll tend to it.")
    }

    // MARK: - Bodie

    static func bodie(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let cleaned = scrub(trimmed)
        let line: String
        switch intent(for: cleaned.isEmpty ? trimmed : cleaned) {
        case .cutPower:
            line = "Hey, let's cut the power and call it good. Easy does it — we're set once it's off."
        case .conduit:
            line = "Hey, pass that conduit over when you can. No rush, we're good."
        case .ladder:
            line = "Let's slide that ladder over, nice and easy. We'll be set."
        case .head:
            line = "Hey, mind your head up there. Easy does it."
        case .wire:
            line = "We're light on wire. Let's grab a little more and keep it easy."
        case .mess:
            line = "Hey, this spot got away from us. Let's tidy it and call it good."
        case .feeder:
            line = "Hey, let's land that feeder before lunch and call it good. Easy does it."
        case .breaker:
            line = "Hey, leave that breaker be. No rush — we're good."
        case .racks:
            line = "Hey, let's get these racks cleaned up and call it good. Easy does it — we're good."
        case .hold:
            line = "No rush. Keep a hold on this for a breath, then we're good."
        case .compliment:
            line = "Hey, you're a natural at this. Easy does it — we're good."
        case .greeting:
            line = "Hey, good to see you out here. We're good."
        case .free:
            line = "Hey, let's take care of \(voicedWords(cleaned)) and call it good. Easy does it."
        }
        return safe(line, raw: trimmed, fallback: "Hey, let's take care of that and call it good. Easy does it.")
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
        if looksSpanish(scrubbed) {
            let reshaped = reshapeSpanish(scrubbed)
            return "Óyeme, coño, \(reshaped). Ahora mismo, carajo, con cuidado, ¿me oyes, pinga?"
        }
        let line: String
        switch intent(for: scrubbed) {
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
        case .free:
            line = "Óyeme, coño, encárgate de \(voicedWords(scrubbed)), carajo. Ahora, mierda."
        }
        return safe(line, raw: trimmed, fallback: "Óyeme, coño, dime qué carajo necesitas en la obra, mierda.")
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

    private static func looksSpanish(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.range(of: "[áéíóúñ¿¡]", options: .regularExpression) != nil { return true }
        let markers = [" el ", " la ", " que ", " corta", " pásame", " pasame", " corriente", " mira", " oye"]
        let padded = " " + lower + " "
        return markers.contains { padded.contains($0) }
    }

    private static func reshapeSpanish(_ text: String) -> String {
        var line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = line.last, ".!?".contains(last) { line.removeLast() }
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { return "hazlo ya" }
        let lower = line.lowercased()
        if lower.hasPrefix("corta ") {
            let rest = String(line.dropFirst("corta ".count))
            return "\(rest) córtala ya"
        }
        if lower.hasPrefix("pásame ") || lower.hasPrefix("pasame ") {
            return "eso que te pedí, pásamelo ya"
        }
        return line
    }

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

    private static func scrub(_ raw: String) -> String {
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
