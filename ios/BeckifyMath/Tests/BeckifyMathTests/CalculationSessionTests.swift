import XCTest
@testable import BeckifyMath

final class ExplicitCalculationSessionTests: XCTestCase {
    private struct Sample: Equatable, Sendable {
        var value: Double
    }

    func testStartsIdle() {
        let session = ExplicitCalculationSession<Sample>()
        XCTAssertEqual(session.display(for: "a"), .idle)
        XCTAssertFalse(session.hasCommittedResult)
    }

    func testSuccessfulCalculateBecomesCurrent() {
        var session = ExplicitCalculationSession<Sample>()
        session.calculate(fingerprint: "12|2|") {
            Sample(value: 6)
        }

        XCTAssertEqual(session.display(for: "12|2|"), .current(Sample(value: 6)))
        XCTAssertNil({
            if case .failed = session.display(for: "12|2|") { return "failed" }
            return nil
        }())
    }

    func testInputChangeMarksResultStaleWithoutSilentUpdate() {
        var session = ExplicitCalculationSession<Sample>()
        session.calculate(fingerprint: "12|2|") { Sample(value: 6) }
        session.calculate(fingerprint: "24|2|") { Sample(value: 12) }

        // After a second successful calculate the new answer is current.
        XCTAssertEqual(session.display(for: "24|2|"), .current(Sample(value: 12)))

        // Editing inputs without calculating keeps the last answer, marked stale.
        var edited = ExplicitCalculationSession<Sample>()
        edited.calculate(fingerprint: "12|2|") { Sample(value: 6) }
        XCTAssertEqual(edited.display(for: "12|3|"), .stale(Sample(value: 6)))
        XCTAssertEqual(edited.committed?.value, 6)
    }

    func testValidationFailurePreservesPriorResultAndRecordsError() {
        var session = ExplicitCalculationSession<Sample>()
        session.calculate(fingerprint: "12|2|") { Sample(value: 6) }
        session.calculate(fingerprint: "bad") {
            throw CalcError.missing("current")
        }

        XCTAssertEqual(session.display(for: "bad"), .stale(Sample(value: 6)))
        XCTAssertEqual(session.lastError, CalcError.missing("current").message)
    }

    func testFirstFailureWithoutPriorResultIsFailed() {
        var session = ExplicitCalculationSession<Sample>()
        session.calculate(fingerprint: "bad") {
            throw CalcError.outOfRange("Need a positive load.")
        }

        XCTAssertEqual(session.display(for: "bad"), .failed("Need a positive load."))
    }

    func testResetClearsCommittedAnswer() {
        var session = ExplicitCalculationSession<Sample>()
        session.calculate(fingerprint: "12|2|") { Sample(value: 6) }
        session.reset()

        XCTAssertEqual(session.display(for: "12|2|"), .idle)
        XCTAssertFalse(session.hasCommittedResult)
        XCTAssertNil(session.lastError)
    }

    func testRecalculationWithSameFingerprintRefreshesCurrent() {
        var session = ExplicitCalculationSession<Sample>()
        session.calculate(fingerprint: "a") { Sample(value: 1) }
        session.calculate(fingerprint: "a") { Sample(value: 2) }
        XCTAssertEqual(session.display(for: "a"), .current(Sample(value: 2)))
    }
}

final class ToolCalculationPolicyTests: XCTestCase {
    func testLiveConverters() {
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "unitConverter"), .live)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "resistorColor"), .live)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "circularMils"), .live)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "modbusAddress"), .live)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "panelDirectory"), .live)
    }

    func testExplicitEngineeringWorksheets() {
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "ohmsLaw"), .explicit)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "power"), .explicit)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "voltageDrop"), .explicit)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "reactance"), .explicit)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "powerFactor"), .explicit)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "shortCircuit"), .explicit)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "signalScaling"), .explicit)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "plcTimer"), .explicit)
    }

    func testSensorsStayLive() {
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "noiseMeter"), .live)
        XCTAssertEqual(ToolCalculationPolicy.mode(for: "bubbleLevel"), .live)
    }
}
