import Foundation

public struct MotorFLARow: Equatable, Sendable {
    public var horsepower: String
    public var amps: [String: Double?]

    public init(horsepower: String, amps: [String: Double?]) {
        self.horsepower = horsepower
        self.amps = amps
    }

    public func amps(at voltage: String) -> Double? {
        amps[voltage] ?? nil
    }
}

/// NEC Tables 430.248 (1Ø) and 430.250 (3Ø squirrel-cage). Use table FLA for
/// conductor and OCPD sizing per 430.6(A)(1), not nameplate current.
public enum MotorFLA {
    public static let singlePhaseVoltages = ["115", "200", "208", "230"]
    public static let threePhaseVoltages = ["115", "200", "208", "230", "460", "575"]

    /// NEC Table 430.248 — single-phase AC motors.
    public static let table430_248: [MotorFLARow] = [
        MotorFLARow(horsepower: "1/6", amps: ["115": 4.4, "200": 2.5, "208": 2.4, "230": 2.2]),
        MotorFLARow(horsepower: "1/4", amps: ["115": 5.8, "200": 3.3, "208": 3.2, "230": 2.9]),
        MotorFLARow(horsepower: "1/3", amps: ["115": 7.2, "200": 4.1, "208": 4.0, "230": 3.6]),
        MotorFLARow(horsepower: "1/2", amps: ["115": 9.8, "200": 5.6, "208": 5.4, "230": 4.9]),
        MotorFLARow(horsepower: "3/4", amps: ["115": 13.8, "200": 7.9, "208": 7.6, "230": 6.9]),
        MotorFLARow(horsepower: "1", amps: ["115": 16, "200": 9.2, "208": 8.8, "230": 8.0]),
        MotorFLARow(horsepower: "1-1/2", amps: ["115": 20, "200": 11.5, "208": 11, "230": 10]),
        MotorFLARow(horsepower: "2", amps: ["115": 24, "200": 13.8, "208": 13.2, "230": 12]),
        MotorFLARow(horsepower: "3", amps: ["115": 34, "200": 19.6, "208": 18.7, "230": 17]),
        MotorFLARow(horsepower: "5", amps: ["115": 56, "200": 32.2, "208": 30.8, "230": 28]),
        MotorFLARow(horsepower: "7-1/2", amps: ["115": 80, "200": 46, "208": 44, "230": 40]),
        MotorFLARow(horsepower: "10", amps: ["115": 100, "200": 57.5, "208": 55, "230": 50]),
    ]

    /// NEC Table 430.250 — three-phase squirrel-cage and wound-rotor.
    public static let table430_250: [MotorFLARow] = [
        MotorFLARow(horsepower: "1/2", amps: ["115": 4.4, "200": 2.5, "208": 2.4, "230": 2.2, "460": 1.1, "575": 0.9]),
        MotorFLARow(horsepower: "3/4", amps: ["115": 6.4, "200": 3.7, "208": 3.5, "230": 3.2, "460": 1.6, "575": 1.3]),
        MotorFLARow(horsepower: "1", amps: ["115": 8.4, "200": 4.8, "208": 4.6, "230": 4.2, "460": 2.1, "575": 1.7]),
        MotorFLARow(horsepower: "1-1/2", amps: ["115": 12, "200": 6.9, "208": 6.6, "230": 6.0, "460": 3.0, "575": 2.4]),
        MotorFLARow(horsepower: "2", amps: ["115": 13.6, "200": 7.8, "208": 7.5, "230": 6.8, "460": 3.4, "575": 2.7]),
        MotorFLARow(horsepower: "3", amps: ["115": nil, "200": 11, "208": 10.6, "230": 9.6, "460": 4.8, "575": 3.9]),
        MotorFLARow(horsepower: "5", amps: ["115": nil, "200": 17.5, "208": 16.7, "230": 15.2, "460": 7.6, "575": 6.1]),
        MotorFLARow(horsepower: "7-1/2", amps: ["115": nil, "200": 25.3, "208": 24.2, "230": 22, "460": 11, "575": 9.0]),
        MotorFLARow(horsepower: "10", amps: ["115": nil, "200": 32.2, "208": 30.8, "230": 28, "460": 14, "575": 11]),
        MotorFLARow(horsepower: "15", amps: ["115": nil, "200": 48.3, "208": 46.2, "230": 42, "460": 21, "575": 17]),
        MotorFLARow(horsepower: "20", amps: ["115": nil, "200": 62.1, "208": 59.4, "230": 54, "460": 27, "575": 22]),
        MotorFLARow(horsepower: "25", amps: ["115": nil, "200": 78.2, "208": 74.8, "230": 68, "460": 34, "575": 27]),
        MotorFLARow(horsepower: "30", amps: ["115": nil, "200": 92, "208": 88, "230": 80, "460": 40, "575": 32]),
        MotorFLARow(horsepower: "40", amps: ["115": nil, "200": 120, "208": 114, "230": 104, "460": 52, "575": 41]),
        MotorFLARow(horsepower: "50", amps: ["115": nil, "200": 150, "208": 143, "230": 130, "460": 65, "575": 52]),
        MotorFLARow(horsepower: "60", amps: ["115": nil, "200": 177, "208": 169, "230": 154, "460": 77, "575": 62]),
        MotorFLARow(horsepower: "75", amps: ["115": nil, "200": 221, "208": 211, "230": 192, "460": 96, "575": 77]),
        MotorFLARow(horsepower: "100", amps: ["115": nil, "200": 285, "208": 273, "230": 248, "460": 124, "575": 99]),
        MotorFLARow(horsepower: "125", amps: ["115": nil, "200": 359, "208": 343, "230": 312, "460": 156, "575": 125]),
        MotorFLARow(horsepower: "150", amps: ["115": nil, "200": 414, "208": 396, "230": 360, "460": 180, "575": 144]),
        MotorFLARow(horsepower: "200", amps: ["115": nil, "200": 552, "208": 528, "230": 480, "460": 240, "575": 192]),
    ]

    /// Map a system voltage to the NEC table column. 480 V systems use the 460 V column.
    public static func tableVoltage(forSystemVolts volts: Double, threePhase: Bool) -> String? {
        let columns = threePhase ? threePhaseVoltages : singlePhaseVoltages
        let numeric = columns.compactMap { col -> (String, Double)? in
            Double(col).map { (col, $0) }
        }
        // Prefer the listed voltage that is ≤ actual, closest (480 → 460).
        let atOrBelow = numeric.filter { $0.1 <= volts }.max { $0.1 < $1.1 }
        if let match = atOrBelow { return match.0 }
        return numeric.min { abs($0.1 - volts) < abs($1.1 - volts) }?.0
    }

    public static func lookup(horsepower: String, voltageColumn: String, threePhase: Bool) -> Double? {
        let table = threePhase ? table430_250 : table430_248
        return table.first(where: { $0.horsepower == horsepower })?.amps(at: voltageColumn)
    }

    /// Conductor minimum = 125 % of table FLA (NEC 430.22).
    public static func conductorAmps(fla: Double) -> Double { fla * 1.25 }

    /// Parse a table or nameplate HP token (`7-1/2`, `1/2`, `10`, `7.5`).
    public static func horsepowerValue(_ token: String) -> Double? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard !trimmed.isEmpty else { return nil }

        if let direct = Double(trimmed), direct > 0, direct.isFinite {
            return direct
        }

        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        if let mixed = compact.range(of: "-") {
            let whole = Double(compact[..<mixed.lowerBound])
            let frac = fractionValue(String(compact[mixed.upperBound...]))
            if let whole, let frac { return whole + frac }
        }
        return fractionValue(compact)
    }

    /// Closest listed HP row for seeding Motor FLA from a reviewed nameplate.
    public static func nearestListedHorsepower(value: Double, threePhase: Bool) -> String? {
        guard value > 0, value.isFinite else { return nil }
        let table = threePhase ? table430_250 : table430_248
        return table.min { lhs, rhs in
            let a = horsepowerValue(lhs.horsepower) ?? .infinity
            let b = horsepowerValue(rhs.horsepower) ?? .infinity
            return abs(a - value) < abs(b - value)
        }?.horsepower
    }

    private static func fractionValue(_ token: String) -> Double? {
        let parts = token.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let num = Double(parts[0]),
              let den = Double(parts[1]),
              den != 0
        else { return nil }
        let value = num / den
        return value > 0 && value.isFinite ? value : nil
    }
}
