import Foundation

public struct BatteryBankResult: Equatable, Sendable {
    public var bankVoltage: Double
    public var bankAmpHours: Double
    public var bankWattHours: Double
    /// Watt-hours actually available at the chosen depth of discharge.
    public var usableWattHours: Double
    /// Hours the bank runs the stated load, after DoD and system efficiency.
    public var runtimeHours: Double
    public var cellCount: Int

    public init(
        bankVoltage: Double,
        bankAmpHours: Double,
        bankWattHours: Double,
        usableWattHours: Double,
        runtimeHours: Double,
        cellCount: Int
    ) {
        self.bankVoltage = bankVoltage
        self.bankAmpHours = bankAmpHours
        self.bankWattHours = bankWattHours
        self.usableWattHours = usableWattHours
        self.runtimeHours = runtimeHours
        self.cellCount = cellCount
    }
}

/// Series-string / parallel-string sizing for a bank built from identical
/// cells — the arithmetic behind "how long will N cells in S×P run this load."
public enum BatteryBank {
    public static func size(
        cellVoltage: Double,
        cellAmpHours: Double,
        seriesCount: Double,
        parallelCount: Double,
        usableDepthOfDischargePercent: Double,
        loadWatts: Double,
        systemEfficiencyPercent: Double = 100
    ) throws -> BatteryBankResult {
        let cellV = try Positive.require(cellVoltage, name: "Cell voltage")
        let cellAh = try Positive.require(cellAmpHours, name: "Cell amp-hours")
        let series = try WholeCount.parse(seriesCount, name: "Series count")
        let parallel = try WholeCount.parse(parallelCount, name: "Parallel count")

        guard usableDepthOfDischargePercent.isFinite, usableDepthOfDischargePercent > 0, usableDepthOfDischargePercent <= 100 else {
            throw CalcError.outOfRange("Usable depth of discharge is between 0 and 100 %.")
        }
        guard systemEfficiencyPercent.isFinite, systemEfficiencyPercent > 0, systemEfficiencyPercent <= 100 else {
            throw CalcError.outOfRange("System efficiency is between 0 and 100 %.")
        }
        let load = try Positive.require(loadWatts, name: "Load")

        let bankVoltage = cellV * Double(series)
        let bankAmpHours = cellAh * Double(parallel)
        let bankWattHours = bankVoltage * bankAmpHours
        let usableWattHours = bankWattHours * (usableDepthOfDischargePercent / 100)
        let runtimeHours = usableWattHours * (systemEfficiencyPercent / 100) / load

        return BatteryBankResult(
            bankVoltage: bankVoltage,
            bankAmpHours: bankAmpHours,
            bankWattHours: bankWattHours,
            usableWattHours: usableWattHours,
            runtimeHours: runtimeHours,
            cellCount: series * parallel
        )
    }
}
