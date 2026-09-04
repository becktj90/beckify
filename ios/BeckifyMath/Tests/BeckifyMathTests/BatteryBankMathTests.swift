import XCTest
@testable import BeckifyMath

final class BatteryBankTests: XCTestCase {
    /// Four 3.2 V / 100 Ah LiFePO4 cells in series: a common 12 V / 100 Ah bank.
    func testSingleSeriesStringVoltageAndCapacity() throws {
        let result = try BatteryBank.size(
            cellVoltage: 3.2,
            cellAmpHours: 100,
            seriesCount: 4,
            parallelCount: 1,
            usableDepthOfDischargePercent: 100,
            loadWatts: 100
        )

        XCTAssertEqual(result.bankVoltage, 12.8, accuracy: 1e-9)
        XCTAssertEqual(result.bankAmpHours, 100, accuracy: 1e-9)
        XCTAssertEqual(result.bankWattHours, 1280, accuracy: 1e-9)
        XCTAssertEqual(result.cellCount, 4)
    }

    /// Two of those 4S strings in parallel doubles amp-hours, not voltage.
    func testParallelStringsAddAmpHoursNotVoltage() throws {
        let result = try BatteryBank.size(
            cellVoltage: 3.2,
            cellAmpHours: 100,
            seriesCount: 4,
            parallelCount: 2,
            usableDepthOfDischargePercent: 100,
            loadWatts: 100
        )

        XCTAssertEqual(result.bankVoltage, 12.8, accuracy: 1e-9)
        XCTAssertEqual(result.bankAmpHours, 200, accuracy: 1e-9)
        XCTAssertEqual(result.cellCount, 8)
    }

    /// A 1280 Wh bank at 100 % DoD, 100 % efficiency, into a 100 W load: 12.8 h.
    func testRuntimeAtFullDepthAndEfficiency() throws {
        let result = try BatteryBank.size(
            cellVoltage: 3.2,
            cellAmpHours: 100,
            seriesCount: 4,
            parallelCount: 1,
            usableDepthOfDischargePercent: 100,
            loadWatts: 100
        )
        XCTAssertEqual(result.runtimeHours, 12.8, accuracy: 1e-9)
    }

    /// 80 % usable DoD and 90 % inverter efficiency both shrink runtime proportionally.
    func testDepthOfDischargeAndEfficiencyScaleRuntime() throws {
        let full = try BatteryBank.size(
            cellVoltage: 12, cellAmpHours: 100, seriesCount: 1, parallelCount: 1,
            usableDepthOfDischargePercent: 100, loadWatts: 120, systemEfficiencyPercent: 100
        )
        let derated = try BatteryBank.size(
            cellVoltage: 12, cellAmpHours: 100, seriesCount: 1, parallelCount: 1,
            usableDepthOfDischargePercent: 80, loadWatts: 120, systemEfficiencyPercent: 90
        )

        XCTAssertEqual(derated.runtimeHours, full.runtimeHours * 0.8 * 0.9, accuracy: 1e-9)
    }

    func testNonWholeCellCountsThrow() {
        XCTAssertThrowsError(try BatteryBank.size(
            cellVoltage: 12, cellAmpHours: 100, seriesCount: 1.5, parallelCount: 1,
            usableDepthOfDischargePercent: 100, loadWatts: 100
        ))
    }

    func testOutOfRangePercentagesThrow() {
        XCTAssertThrowsError(try BatteryBank.size(
            cellVoltage: 12, cellAmpHours: 100, seriesCount: 1, parallelCount: 1,
            usableDepthOfDischargePercent: 0, loadWatts: 100
        ))
        XCTAssertThrowsError(try BatteryBank.size(
            cellVoltage: 12, cellAmpHours: 100, seriesCount: 1, parallelCount: 1,
            usableDepthOfDischargePercent: 101, loadWatts: 100
        ))
        XCTAssertThrowsError(try BatteryBank.size(
            cellVoltage: 12, cellAmpHours: 100, seriesCount: 1, parallelCount: 1,
            usableDepthOfDischargePercent: 100, loadWatts: 100, systemEfficiencyPercent: 0
        ))
    }

    func testZeroOrNegativeInputsThrow() {
        XCTAssertThrowsError(try BatteryBank.size(
            cellVoltage: 0, cellAmpHours: 100, seriesCount: 1, parallelCount: 1,
            usableDepthOfDischargePercent: 100, loadWatts: 100
        ))
        XCTAssertThrowsError(try BatteryBank.size(
            cellVoltage: 12, cellAmpHours: 100, seriesCount: 1, parallelCount: 1,
            usableDepthOfDischargePercent: 100, loadWatts: 0
        ))
    }
}
