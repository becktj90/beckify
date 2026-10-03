import Foundation

/// Turns a user's line into one crew member's dialect.
/// Wording may change a lot. The ask survives. Slurs and insults are never echoed.
/// Never glue a stock opener onto the raw sentence ("Would you please hi I need…").
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

    // MARK: - Pearl

    static func pearl(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let key = fold(trimmed)
        if let known = pearlKnown[key] { return known }
        let cleaned = scrub(trimmed)
        guard !cleaned.isEmpty else {
            return "Would you please tell me what you need, when you have a moment?"
        }
        let ask = extractAsk(cleaned)
        guard !ask.isEmpty else {
            return "Would you please tell me what you need, when you have a moment?"
        }
        let lower = ask.lowercased()
        if lower.hasPrefix("please ") || lower.hasPrefix("would you") || lower.hasPrefix("could you") {
            return sentence(capitalize(ask))
        }
        let frames: [(String) -> String] = [
            { ask in "Would you please \(ask)?" },
            { ask in "Could you \(ask) for me?" },
            { ask in "Would you mind \(gerundish(ask))?" },
            { ask in "Please \(ask) when you have a moment." },
            { ask in "Could we \(ask)?" },
        ]
        return frames[rotate(key, frames.count)](ask)
    }

    private static let pearlKnown: [String: String] = [
        "kill the power": "Would you please cut the power?",
        "thats live dont touch it": "That line is live — please don't touch it.",
        "hand me that conduit": "Could you hand me that conduit?",
        "move the ladder": "Would you move the ladder for me?",
        "watch your head": "Please watch your head.",
        "we need more wire": "Could we get a little more wire?",
        "who left this mess": "Could you help me see who left this mess?",
        "hi i need you to clean up all these racks": "Would you please clean up all these racks?",
        "i need you to clean up all these racks": "Would you please clean up all these racks?",
        "clean up all these racks": "Would you please clean up all these racks?",
    ]

    // MARK: - Sloane

    /// Meeting-speak only. Two lines. A rude line still leaves as a meeting, never as the original words.
    static func sloane(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let key = fold(trimmed)
        if let known = sloaneKnown[key] { return known }
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
        return templates[rotate(key, templates.count)](topic)
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
        let scrubbed = scrub(raw).lowercased()
        if scrubbed.contains("feeder") {
            return scrubbed.contains("lunch") ? "landing the feeder before lunch" : "the feeder"
        }
        if scrubbed.contains("power") { return "cutting the power" }
        if scrubbed.contains("conduit") { return "that conduit handoff" }
        if scrubbed.contains("ladder") { return "relocating the ladder" }
        if scrubbed.contains("head") { return "head clearance" }
        if scrubbed.contains("wire") { return "wire supply" }
        if scrubbed.contains("mess") { return "the open housekeeping item" }
        if scrubbed.contains("hold") { return "holding that for a moment" }
        if scrubbed.contains("breaker") { return "that breaker" }
        if scrubbed.contains("rack") { return "clearing those racks" }
        let stop: Set<String> = [
            "the", "a", "an", "and", "or", "to", "for", "of", "me", "my", "that", "this",
            "please", "you", "your", "just", "now", "get", "it", "with", "from", "into",
            "hi", "hey", "hello", "need", "want",
        ]
        let words = extractAsk(scrubbed).split(separator: " ").map(String.init).filter { word in
            word.count > 2 && !stop.contains(word)
        }
        if words.isEmpty { return "the open item" }
        return words.prefix(6).joined(separator: " ")
    }

    // MARK: - Junie

    static func junie(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let key = fold(trimmed)
        if let known = junieKnown[key] { return known }
        let ask = extractAsk(scrub(trimmed))
        let color = junieColors[rotate(key, junieColors.count)]
        let frames: [(String, String) -> String] = [
            { ask, color in "Well, I'm fixin' to \(ask). \(color)." },
            { ask, color in "Listen here — \(ask), over yonder. \(color)." },
            { ask, color in "Bless your heart, \(ask). \(color)." },
            { ask, color in "Heavens to Betsy, \(ask) till the cows come home if we have to. \(color)." },
            { ask, color in "I'm fixin' to \(ask), and don't get your knickers in a knot. \(color)." },
            { ask, color in "Well I'll be Sam Browned — \(ask). \(color)." },
        ]
        return frames[rotate(key + "|j", frames.count)](ask.isEmpty ? "take care of that" : ask, color)
    }

    private static let junieColors = [
        "Don't get your knickers in a knot",
        "Don't take any wooden nickels",
        "Slick as a ribbon on an ice cube",
        "Fitter than a fiddle",
        "Well I'll be Sam Browned",
        "Heavens to Betsy",
        "Bless your heart",
        "Madder than a wet hen if we leave it",
    ]

    private static let junieKnown: [String: String] = [
        "kill the power": "I'm fixin' to cut that power. Don't get your knickers in a knot — bless your heart, it'll be off.",
        "hand me that conduit": "Hand me that conduit over yonder. It'll fit the job better than a sock on a rooster.",
        "move the ladder": "I'm fixin' to move that ladder a fur piece. Don't take any wooden nickels while I do.",
        "watch your head": "Watch your head, now. I'm nervous as a long-tailed cat in a room full of rocking chairs about that clearance.",
        "we need more wire": "We're shy on wire, and I'm fixin' to fetch more from over yonder.",
        "who left this mess": "Well I'll be Sam Browned, somebody left this mess and ain't got the sense of a sack of wet hammers. Bless your heart, let's set it right.",
        "stop talking and get that feeder in before lunch": "I'm fixin' to get that feeder in before lunch. Don't get your knickers in a knot — we'll be done before the cows even look up.",
    ]

    // MARK: - Bodie

    static func bodie(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let key = fold(trimmed)
        if let known = bodieKnown[key] { return known }
        let ask = extractAsk(scrub(trimmed))
        let frames: [(String) -> String] = [
            { ask in "Hey, let's \(ask). Easy does it out here — we're good." },
            { ask in "No rush. \(capitalize(ask)), then we can leave it and enjoy the rest of the day." },
            { ask in "Alright, \(ask). Keep it light, keep it easy, and we're done." },
            { ask in "Hey, \(ask) when the moment's right. The work can breathe a second." },
            { ask in "Let's \(ask) and call it good. Nothing out here needs a panic." },
        ]
        return frames[rotate(key, frames.count)](ask.isEmpty ? "take care of that" : ask)
    }

    private static let bodieKnown: [String: String] = [
        "kill the power": "Hey, let's cut the power and call it good. Easy does it — we're set once it's off.",
        "hand me that conduit": "Hey, pass that conduit over when you can. No rush, we're good.",
        "move the ladder": "Let's slide that ladder over, nice and easy. We'll be set.",
        "watch your head": "Hey, mind your head up there. Easy does it.",
        "we need more wire": "We're light on wire. Let's grab a little more and keep it easy.",
        "who left this mess": "Hey, this spot got away from us. Let's tidy it and call it good.",
        "hola": "Hey, good to see you out here. We're good.",
    ]

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
        let ask = titoAsk(scrubbed)
        let frames: [(String) -> String] = [
            { ask in "Óyeme, coño, \(ask). Hazlo firme y rápido, carajo, ¿sí?" },
            { ask in "Mira, \(ask), mierda. Sin distracción, pinga, que el trabajo no espera." },
            { ask in "A ver, cabrón, \(ask). Con calma y con fuerza, joder, mi hermano." },
            { ask in "Escúchame, \(ask), coño. Ya, carajo, que estamos en la obra." },
        ]
        return frames[rotate(key, frames.count)](ask)
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

    private static func titoAsk(_ scrubbed: String) -> String {
        let lower = scrubbed.lowercased()
        if lower.contains("power") || lower.contains("corriente") { return "corta esa corriente" }
        if lower.contains("conduit") { return "pásame ese conduit" }
        if lower.contains("ladder") || lower.contains("escalera") { return "mueve esa escalera" }
        if lower.contains("head") || lower.contains("cabeza") { return "cuida la cabeza" }
        if lower.contains("wire") || lower.contains("cable") { return "trae más cable" }
        if lower.contains("mess") || lower.contains("desorden") { return "recoge este desorden" }
        if lower.contains("feeder") || lower.contains("aliment") { return "mete ese alimentador" }
        if lower.contains("breaker") { return "deja ese breaker" }
        if lower.contains("hold") { return "sostén eso un momento" }
        if lower.contains("rack") { return "limpia esos racks" }
        let stop: Set<String> = ["the", "a", "an", "and", "to", "for", "me", "that", "this", "you", "please", "hi", "hey", "hello", "need", "want"]
        let words = extractAsk(lower).split(separator: " ").map(String.init).filter { !stop.contains($0) && $0.count > 1 }
        if words.isEmpty { return "haz lo que te pedí" }
        return "haz esto: " + words.prefix(5).joined(separator: " ")
    }

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
    /// Prevents stock openers from gluing onto the raw sentence.
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

    private static func plainAsk(_ raw: String) -> String {
        let ask = extractAsk(raw)
        return ask.isEmpty ? "take care of that" : ask
    }

    private static func gerundish(_ ask: String) -> String {
        let lower = ask.lowercased()
        if lower.hasPrefix("clean up ") {
            return "cleaning up " + String(ask.dropFirst("clean up ".count))
        }
        if lower.hasPrefix("cut ") {
            return "cutting " + String(ask.dropFirst("cut ".count))
        }
        if lower.hasPrefix("move ") {
            return "moving " + String(ask.dropFirst("move ".count))
        }
        if lower.hasPrefix("hand me ") {
            return "handing me " + String(ask.dropFirst("hand me ".count))
        }
        if lower.hasPrefix("hold ") {
            return "holding " + String(ask.dropFirst("hold ".count))
        }
        return ask
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

    private static func sentence(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if let last = trimmed.last, ".!?".contains(last) { return trimmed }
        return trimmed + "."
    }

    private static func capitalize(_ raw: String) -> String {
        guard let first = raw.first else { return raw }
        return String(first).uppercased() + raw.dropFirst()
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
