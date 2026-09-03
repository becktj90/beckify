import XCTest
@testable import BeckifyMath

final class SignalScalingTests: XCTestCase {
    func testLinearFourToTwentyMilliamps() throws {
        // Mid-scale 12 mA on a 0-150 PSI transmitter is 75 PSI.
        let result = try SignalScaling.toEngineering(
            raw: 12,
            rawMin: 4,
            rawMax: 20,
            engineeringMin: 0,
            engineeringMax: 150
        )

        XCTAssertEqual(result.engineeringValue, 75, accuracy: 0.0001)
        XCTAssertEqual(result.percentOfSpan, 50, accuracy: 0.0001)
        XCTAssertFalse(result.isLiveZeroFault)
    }

    func testSquareRootFlowCurve() throws {
        // DP flow: half of span in signal is √0.5 = 70.7% of flow.
        let result = try SignalScaling.toEngineering(
            raw: 12,
            rawMin: 4,
            rawMax: 20,
            engineeringMin: 0,
            engineeringMax: 100,
            curve: .squareRoot
        )

        XCTAssertEqual(result.engineeringValue, 70.711, accuracy: 0.001)
    }

    func testReverseScalingRoundTrips() throws {
        let forward = try SignalScaling.toEngineering(
            raw: 8,
            rawMin: 4,
            rawMax: 20,
            engineeringMin: -50,
            engineeringMax: 250
        )
        let back = try SignalScaling.toRaw(
            engineering: forward.engineeringValue,
            rawMin: 4,
            rawMax: 20,
            engineeringMin: -50,
            engineeringMax: 250
        )

        XCTAssertEqual(back.rawValue, 8, accuracy: 0.0001)
    }

    func testSquareRootReverseRoundTrips() throws {
        let forward = try SignalScaling.toEngineering(
            raw: 16, rawMin: 4, rawMax: 20,
            engineeringMin: 0, engineeringMax: 100, curve: .squareRoot
        )
        let back = try SignalScaling.toRaw(
            engineering: forward.engineeringValue, rawMin: 4, rawMax: 20,
            engineeringMin: 0, engineeringMax: 100, curve: .squareRoot
        )

        XCTAssertEqual(back.rawValue, 16, accuracy: 0.0001)
    }

    /// Below live zero is a broken loop, not a negative process value.
    func testLiveZeroFaultIsFlagged() throws {
        let result = try SignalScaling.toEngineering(
            raw: 2,
            rawMin: 4,
            rawMax: 20,
            engineeringMin: 0,
            engineeringMax: 150,
            detectLiveZeroFault: true
        )
        XCTAssertTrue(result.isLiveZeroFault)
    }

    func testPositiveRawRangeIsNotImplicitlyLiveZero() throws {
        let result = try SignalScaling.toEngineering(
            raw: 99,
            rawMin: 100,
            rawMax: 138.51,
            engineeringMin: 0,
            engineeringMax: 100
        )

        XCTAssertFalse(result.isLiveZeroFault)
    }

    func testZeroRawSpanThrows() {
        XCTAssertThrowsError(try SignalScaling.toEngineering(
            raw: 12, rawMin: 4, rawMax: 4, engineeringMin: 0, engineeringMax: 150
        ))
        XCTAssertThrowsError(try SignalScaling.toRaw(
            engineering: 75, rawMin: 4, rawMax: 4, engineeringMin: 0, engineeringMax: 150
        ))
    }

    func testReverseScalingRejectsNonFiniteEngineeringRange() {
        XCTAssertThrowsError(try SignalScaling.toRaw(
            engineering: 75, rawMin: 4, rawMax: 20, engineeringMin: .nan, engineeringMax: 150
        ))
        XCTAssertThrowsError(try SignalScaling.toRaw(
            engineering: 75, rawMin: 4, rawMax: 20, engineeringMin: 0, engineeringMax: .infinity
        ))
    }

    func testSquareRootScalingRejectsValuesBelowConfiguredRange() {
        XCTAssertThrowsError(try SignalScaling.toEngineering(
            raw: 3, rawMin: 4, rawMax: 20,
            engineeringMin: 0, engineeringMax: 100, curve: .squareRoot
        ))
        XCTAssertThrowsError(try SignalScaling.toRaw(
            engineering: -1, rawMin: 4, rawMax: 20,
            engineeringMin: 0, engineeringMax: 100, curve: .squareRoot
        ))
    }
}

final class ModbusAddressTests: XCTestCase {
    func testHoldingRegisterOffsetZero() throws {
        let result = try ModbusAddress.fromPDUOffset(0, table: .holdingRegister)

        XCTAssertEqual(result.pduOffset, 0)
        XCTAssertEqual(result.entityNumber, 1)
        XCTAssertEqual(result.fiveDigit, "40001")
        XCTAssertEqual(result.sixDigit, "400001")
        XCTAssertEqual(result.readFunctionCode, 3)
    }

    func testFiveDigitDisplayAddressResolvesToOffset() throws {
        let result = try ModbusAddress.fromDisplayAddress("40064", table: .holdingRegister)
        XCTAssertEqual(result.entityNumber, 64)
        XCTAssertEqual(result.pduOffset, 63)
    }

    func testSixDigitDisplayAddressResolvesToOffset() throws {
        let result = try ModbusAddress.fromDisplayAddress("400064", table: .holdingRegister)
        XCTAssertEqual(result.entityNumber, 64)
        XCTAssertEqual(result.pduOffset, 63)
    }

    func testDisplayAddressRequiresMatchingPrefixAndExactLength() {
        XCTAssertThrowsError(try ModbusAddress.fromDisplayAddress("30001", table: .holdingRegister))
        XCTAssertThrowsError(try ModbusAddress.fromDisplayAddress("4000001", table: .holdingRegister))
        XCTAssertThrowsError(try ModbusAddress.fromDisplayAddress("1", table: .holdingRegister))
    }

    func testExplicitFiveDigitEntityNumberIsNotTruncated() throws {
        let result = try ModbusAddress.fromEntityNumber(65_536, table: .holdingRegister)

        XCTAssertEqual(result.pduOffset, 65_535)
        XCTAssertEqual(result.entityNumber, 65_536)
        XCTAssertNil(result.fiveDigit)
        XCTAssertEqual(result.sixDigit, "465536")
    }

    func testFiveDigitNotationIsUnavailableWhenEntityDoesNotFit() throws {
        let result = try ModbusAddress.fromPDUOffset(9_999, table: .holdingRegister)

        XCTAssertNil(result.fiveDigit)
        XCTAssertEqual(result.sixDigit, "410000")
    }

    func testCoilAndDiscreteInputFunctionCodes() throws {
        XCTAssertEqual(try ModbusAddress.fromPDUOffset(0, table: .coil).readFunctionCode, 1)
        XCTAssertEqual(try ModbusAddress.fromPDUOffset(0, table: .discreteInput).readFunctionCode, 2)
        XCTAssertEqual(try ModbusAddress.fromPDUOffset(0, table: .inputRegister).readFunctionCode, 4)
    }

    func testOutOfRangeAndNonNumericThrow() {
        XCTAssertThrowsError(try ModbusAddress.fromPDUOffset(-1, table: .coil))
        XCTAssertThrowsError(try ModbusAddress.fromPDUOffset(70000, table: .coil))
        XCTAssertThrowsError(try ModbusAddress.fromDisplayAddress("4x001", table: .holdingRegister))
        XCTAssertThrowsError(try ModbusAddress.fromDisplayAddress("", table: .holdingRegister))
    }
}

final class PLCTimerTests: XCTestCase {
    func testPresetAtTenMillisecondBase() throws {
        let result = try PLCTimer.preset(seconds: 5, timebaseSeconds: 0.01)

        XCTAssertEqual(result.preset, 500)
        XCTAssertEqual(result.actualSeconds, 5, accuracy: 1e-9)
        XCTAssertEqual(result.errorSeconds, 0, accuracy: 1e-9)
    }

    /// A coarse timebase quantises the achievable time; the error is the point.
    func testCoarseTimebaseReportsQuantisationError() throws {
        let result = try PLCTimer.preset(seconds: 2.4, timebaseSeconds: 1)

        XCTAssertEqual(result.preset, 2)
        XCTAssertEqual(result.actualSeconds, 2, accuracy: 1e-9)
        XCTAssertEqual(result.errorSeconds, -0.4, accuracy: 1e-9)
    }

    /// An exact half rounds up, so the timer never lands short of the time that
    /// was asked for — the safer direction for a timeout.
    func testExactHalfRoundsUp() throws {
        let result = try PLCTimer.preset(seconds: 2.5, timebaseSeconds: 1)

        XCTAssertEqual(result.preset, 3)
        XCTAssertEqual(result.actualSeconds, 3, accuracy: 1e-9)
        XCTAssertEqual(result.errorSeconds, 0.5, accuracy: 1e-9)
    }

    func testReverseGivesTimeoutForPreset() throws {
        let result = try PLCTimer.seconds(preset: 750, timebaseSeconds: 0.1)
        XCTAssertEqual(result.actualSeconds, 75, accuracy: 1e-9)
    }

    func testInvalidInputsThrow() {
        XCTAssertThrowsError(try PLCTimer.preset(seconds: 0, timebaseSeconds: 0.01))
        XCTAssertThrowsError(try PLCTimer.preset(seconds: 5, timebaseSeconds: 0))
        XCTAssertThrowsError(try PLCTimer.seconds(preset: -1, timebaseSeconds: 0.1))
    }

    func testIntegerBoundaryAndDurationOverflowThrow() {
        XCTAssertThrowsError(try PLCTimer.preset(seconds: Double(Int.max), timebaseSeconds: 1))
        XCTAssertThrowsError(try PLCTimer.seconds(
            preset: Int.max,
            timebaseSeconds: Double.greatestFiniteMagnitude
        ))
    }
}
