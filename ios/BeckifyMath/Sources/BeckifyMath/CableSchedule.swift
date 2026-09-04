import Foundation

public struct CableCatalogItem: Equatable, Sendable, Identifiable {
    public var id: String
    public var size: String
    public var conductorCount: Int
    public var insulation: String
    public var voltageRating: String
    public var use: String

    public init(
        id: String,
        size: String,
        conductorCount: Int,
        insulation: String,
        voltageRating: String,
        use: String
    ) {
        self.id = id
        self.size = size
        self.conductorCount = conductorCount
        self.insulation = insulation
        self.voltageRating = voltageRating
        self.use = use
    }
}

public struct CableScheduleLineInput: Equatable, Sendable {
    public var typeId: String
    public var quantity: Int
    public var from: String
    public var to: String
    public var system: String

    public init(typeId: String, quantity: Int = 1, from: String = "", to: String = "", system: String = "") {
        self.typeId = typeId
        self.quantity = quantity
        self.from = from
        self.to = to
        self.system = system
    }
}

public struct CableScheduleRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var cableID: String
    public var from: String
    public var to: String
    public var cableType: String
    public var conductorSize: String
    public var conductorCount: Int
    public var insulation: String
    public var voltageRating: String
    public var ampacityNote: String
    public var system: String
}

public struct CableScheduleResult: Equatable, Sendable {
    public var rows: [CableScheduleRow]
    public var csv: String
    public var formula: String
}

/// Generates sequential cable IDs and a CSV schedule from a type catalog + cart.
public enum CableSchedule {
    public static let seedCatalog: [CableCatalogItem] = [
        CableCatalogItem(id: "PWR-4C-12", size: "12", conductorCount: 4, insulation: "THHN/THWN-2", voltageRating: "600 V", use: "power"),
        CableCatalogItem(id: "PWR-3C-10", size: "10", conductorCount: 3, insulation: "THHN/THWN-2", voltageRating: "600 V", use: "power"),
        CableCatalogItem(id: "PWR-4C-8", size: "8", conductorCount: 4, insulation: "XHHW-2", voltageRating: "600 V", use: "power"),
        CableCatalogItem(id: "PWR-3C-4", size: "4", conductorCount: 3, insulation: "XHHW-2", voltageRating: "600 V", use: "power"),
        CableCatalogItem(id: "PWR-3C-2/0", size: "2/0", conductorCount: 3, insulation: "XHHW-2", voltageRating: "600 V", use: "power"),
        CableCatalogItem(id: "CTL-8C-14", size: "14", conductorCount: 8, insulation: "THHN/THWN-2", voltageRating: "600 V", use: "control"),
        CableCatalogItem(id: "CTL-12C-16", size: "16", conductorCount: 12, insulation: "PVC", voltageRating: "300 V", use: "control"),
        CableCatalogItem(id: "INS-1P-18", size: "18", conductorCount: 2, insulation: "XLPE", voltageRating: "300 V", use: "instrumentation"),
        CableCatalogItem(id: "INS-2P-18", size: "18", conductorCount: 4, insulation: "XLPE", voltageRating: "300 V", use: "instrumentation"),
        CableCatalogItem(id: "COM-CAT6", size: "23", conductorCount: 8, insulation: "PVC", voltageRating: "300 V", use: "communication"),
    ]

    public static func padNumber(_ n: Int, width: Int) -> String {
        let w = max(1, width)
        let s = String(max(0, n))
        if s.count >= w { return s }
        return String(repeating: "0", count: w - s.count) + s
    }

    public static func nextCableID(prefix: String, start: Int, index: Int, width: Int) -> String {
        let p = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let num = padNumber(start + index, width: width)
        return p.isEmpty ? num : "\(p)-\(num)"
    }

    public static func ampacityNote(size: String, material: ConductorMaterial = .copper) -> String {
        if let amps = NECTables.ampacity75C(size: size, material: material) {
            return "\(amps) A @ 75°C (Table 310.16)"
        }
        return "—"
    }

    public static func generate(
        catalog: [CableCatalogItem] = seedCatalog,
        lines: [CableScheduleLineInput],
        prefix: String = "C",
        startNumber: Int = 1,
        width: Int = 3,
        material: ConductorMaterial = .copper
    ) throws -> CableScheduleResult {
        guard !lines.isEmpty else {
            throw CalcError.missing("at least one cable cart line")
        }
        guard startNumber >= 0 else {
            throw CalcError.outOfRange("Start number must be ≥ 0.")
        }

        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id.uppercased(), $0) })
        var rows: [CableScheduleRow] = []
        var seq = 0

        for line in lines {
            let qty = max(1, line.quantity)
            guard let item = byID[line.typeId.uppercased()] else {
                throw CalcError.notListed("Unknown cable type “\(line.typeId)”.")
            }
            for _ in 0..<qty {
                let cableID = nextCableID(prefix: prefix, start: startNumber, index: seq, width: width)
                rows.append(CableScheduleRow(
                    id: "\(cableID)-\(seq)",
                    cableID: cableID,
                    from: line.from,
                    to: line.to,
                    cableType: item.id,
                    conductorSize: item.size,
                    conductorCount: item.conductorCount,
                    insulation: item.insulation,
                    voltageRating: item.voltageRating,
                    ampacityNote: ampacityNote(size: item.size, material: material),
                    system: line.system
                ))
                seq += 1
            }
        }

        var csv = "Cable ID,From,To,Cable Type,Conductor Size,Conductor Count,Insulation,Voltage Rating,Ampacity,System\n"
        for row in rows {
            csv += "\(escape(row.cableID)),\(escape(row.from)),\(escape(row.to)),\(escape(row.cableType)),\(escape(row.conductorSize)),\(row.conductorCount),\(escape(row.insulation)),\(escape(row.voltageRating)),\(escape(row.ampacityNote)),\(escape(row.system))\n"
        }

        return CableScheduleResult(
            rows: rows,
            csv: csv,
            formula: "Cable ID = prefix + zero-padded sequence; ampacity from Table 310.16 75°C when listed"
        )
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
