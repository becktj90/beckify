import SwiftUI

enum ToolID: String, Codable, CaseIterable, Identifiable {
    case ohmsLaw
    case power
    case powerWizard
    case voltageDrop
    case conduitFill
    case transformer
    case timer555
    case motorFLA
    case wireAmpacity

    var id: String { rawValue }
}

struct ToolDefinition: Identifiable {
    var id: ToolID
    var title: String
    var subtitle: String
    var symbol: String
    var synonyms: [String]

    var searchBlob: String {
        ([title, subtitle] + synonyms).joined(separator: " ").lowercased()
    }
}

enum ToolboxCatalog {
    static let tools: [ToolDefinition] = [
        ToolDefinition(
            id: .ohmsLaw,
            title: "Ohm's Law",
            subtitle: "Solve any two of V, I, R. Power follows.",
            symbol: "waveform.path.ecg",
            synonyms: ["ohm", "ohms", "voltage", "current", "resistance", "v=ir", "vir"]
        ),
        ToolDefinition(
            id: .power,
            title: "DC / AC Power",
            subtitle: "P = VI, 1Ø and 3Ø kVA / kW / kVAR.",
            symbol: "bolt.fill",
            synonyms: ["dc power", "ac power", "watts", "kvar", "apparent", "true power", "reactive"]
        ),
        ToolDefinition(
            id: .powerWizard,
            title: "Power Wizard",
            subtitle: "DC, 1Ø, and 3Ø — amps, kW, kVA, or HP.",
            symbol: "wand.and.stars",
            synonyms: ["power wizard", "kva", "kw", "horsepower", "three phase", "3 phase", "single phase", "fla estimate"]
        ),
        ToolDefinition(
            id: .voltageDrop,
            title: "Voltage Drop",
            subtitle: "K-factor VD with 3% / 5% notes and ampacity check.",
            symbol: "arrow.down.right.and.arrow.up.left",
            synonyms: ["voltage drop", "vd", "feeder", "branch", "ampacity", "awg", "circular mils", "k-factor"]
        ),
        ToolDefinition(
            id: .conduitFill,
            title: "Conduit Fill",
            subtitle: "THHN in EMT per Chapter 9 Table 1.",
            symbol: "circle.hexagongrid.fill",
            synonyms: ["conduit", "fill", "emt", "thhn", "raceway", "chapter 9", "40 percent", "annex c"]
        ),
        ToolDefinition(
            id: .transformer,
            title: "Transformer Sizing",
            subtitle: "Standard kVA and 450.3(B) protection, Note 1.",
            symbol: "rectangle.split.2x1.fill",
            synonyms: ["transformer", "xfmr", "kva", "450.3", "ocpd", "primary", "secondary", "note 1"]
        ),
        ToolDefinition(
            id: .timer555,
            title: "555 Timer",
            subtitle: "Astable and monostable from ln(2) / ln(3).",
            symbol: "timer",
            synonyms: ["555", "astable", "monostable", "ne555", "oscillator", "one shot", "duty cycle"]
        ),
        ToolDefinition(
            id: .motorFLA,
            title: "Motor FLA Tables",
            subtitle: "NEC 430.248 and 430.250 table currents.",
            symbol: "fanblades.fill",
            synonyms: ["motor", "fla", "flc", "430.248", "430.250", "horsepower", "squirrel cage"]
        ),
        ToolDefinition(
            id: .wireAmpacity,
            title: "Wire Size & Ampacity",
            subtitle: "NEC Table 310.16, 75 °C column.",
            symbol: "cable.connector.horizontal",
            synonyms: ["wire size", "ampacity", "awg", "310.16", "75c", "kcmil", "copper", "aluminum", "conductor"]
        ),
    ]

    static func matching(_ query: String) -> [ToolDefinition] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return tools }
        return tools.filter { $0.searchBlob.contains(q) }
    }

    static func tool(_ id: ToolID) -> ToolDefinition {
        tools.first { $0.id == id } ?? tools[0]
    }
}
