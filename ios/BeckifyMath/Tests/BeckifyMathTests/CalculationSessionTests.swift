import XCTest
@testable import BeckifyMath

final class CalculationSessionTests: XCTestCase {

    // MARK: - Mode classification

    func testLiveToolsAreClassifiedLive() {
        for id in ["unitConverter", "resistorColor", "circularMils", "modbusAddress", "numberBase"] {
            XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: id), .live, id)
        }
    }

    func testEngineeringToolsAreExplicit() {
        let explicit = [
            "ohmsLaw", "power", "voltageDrop", "conduitFill", "transformer",
            "reactance", "powerFactor", "shortCircuit", "loadFactors",
            "signalScaling", "plcTimer", "timer555", "motorFLA", "wireAmpacity",
            "voltageDivider", "seriesParallel", "frequencyWave", "ledRC",
            "receptacleSelector", "panelDirectory", "powerWizard",
            "motorSpeed", "rfLink", "phasorDiagram", "batteryBank", "solarDesign",
            "analogWorkbench", "noiseSNR", "linearRegulator", "instrumentationAmp", "adcDac",
            "motorNameplateOCR",
            "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
        ]
        for id in explicit {
            XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: id), .explicit, id)
        }
    }

    func testSensorsAreSensorMode() {
        for id in ToolCalculationPolicy.sensorToolIDs {
            XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: id), .sensor, id)
        }
        XCTAssertFalse(ToolCalculationPolicy.sensorToolIDs.isEmpty)
    }

    func testEveryKnownToolHasExactlyOneMode() {
        for id in ToolCalculationPolicy.knownToolIDs {
            let mode = ToolCalculationPolicy.mode(forToolID: id)
            XCTAssertTrue(
                CalculationMode.allCases.contains(mode),
                "Unexpected mode for \(id)"
            )
        }
        let partitioned =
            ToolCalculationPolicy.liveToolIDs.count
            + ToolCalculationPolicy.explicitToolIDs.count
            + ToolCalculationPolicy.sensorToolIDs.count
        XCTAssertEqual(partitioned, ToolCalculationPolicy.knownToolIDs.count)
    }

    // MARK: - Explicit state machine

    func testExplicitStartsIdle() {
        let state = ExplicitCalculationState<Double>()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.isStale)
        XCTAssertNil(state.displayedResult)
        XCTAssertNil(state.staleBanner)
    }

    func testExplicitSuccessThenStaleOnEdit() {
        var state = ExplicitCalculationState<Double>()
        state.calculate { 12.0 }
        XCTAssertEqual(state.displayedResult, 12.0)
        XCTAssertFalse(state.isStale)

        state.markInputsChanged()
        XCTAssertEqual(state.displayedResult, 12.0)
        XCTAssertTrue(state.isStale)
        XCTAssertEqual(state.staleBanner, "Inputs changed — Calculate again.")
    }

    func testExplicitDoesNotSilentlyUpdateWhileEditing() {
        var state = ExplicitCalculationState<Double>()
        state.calculate { 10.0 }
        state.markInputsChanged()
        // Editing must not replace the displayed value until Calculate.
        XCTAssertEqual(state.displayedResult, 10.0)
        XCTAssertTrue(state.isStale)
    }

    func testExplicitRecalculationClearsStale() {
        var state = ExplicitCalculationState<Double>()
        state.calculate { 10.0 }
        state.markInputsChanged()
        state.calculate { 22.0 }
        XCTAssertEqual(state.displayedResult, 22.0)
        XCTAssertFalse(state.isStale)
        XCTAssertNil(state.staleBanner)
        XCTAssertNil(state.lastValidationError)
    }

    func testExplicitValidationFailureWithoutPriorSuccess() {
        var state = ExplicitCalculationState<Double>()
        state.calculate(focusOnFailure: "voltage") {
            throw CalcError.missing("voltage")
        }
        XCTAssertEqual(state.phase, .failed(.missing("voltage")))
        XCTAssertEqual(state.focusField, "voltage")
        XCTAssertEqual(state.lastValidationError, .missing("voltage"))
        XCTAssertNil(state.displayedResult)
    }

    func testExplicitValidationFailureKeepsPriorSuccessStale() {
        var state = ExplicitCalculationState<Double>()
        state.calculate { 48.0 }
        state.markInputsChanged()
        state.calculate(focusOnFailure: "current") {
            throw CalcError.nonPositive("current")
        }
        XCTAssertEqual(state.displayedResult, 48.0)
        XCTAssertTrue(state.isStale)
        XCTAssertEqual(state.lastValidationError, .nonPositive("current"))
        XCTAssertEqual(state.focusField, "current")
    }

    func testExplicitResetClearsEverything() {
        var state = ExplicitCalculationState<Double>()
        state.calculate { 5.0 }
        state.markInputsChanged()
        state.reset()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.isStale)
        XCTAssertNil(state.lastValidationError)
        XCTAssertNil(state.focusField)
    }

    func testMarkInputsChangedClearsFailureToIdle() {
        var state = ExplicitCalculationState<Double>()
        state.calculate { throw CalcError.missing("R") }
        XCTAssertNotNil(state.error)
        XCTAssertNotNil(state.lastValidationError)
        state.markInputsChanged()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.lastValidationError)
        XCTAssertNil(state.error)
    }

    func testMarkInputsChangedClearsValidationErrorBesideStaleSuccess() {
        var state = ExplicitCalculationState<Double>()
        state.calculate { 10 }
        state.markInputsChanged()
        state.calculate { throw CalcError.missing("I") }
        XCTAssertEqual(state.displayedResult, 10)
        XCTAssertNotNil(state.lastValidationError)
        state.markInputsChanged()
        XCTAssertNil(state.lastValidationError)
        XCTAssertTrue(state.isStale)
    }

    // MARK: - Live state

    func testLiveValidInputPublishesResult() {
        var state = LiveCalculationState<Double>()
        state.update { 4700 }
        XCTAssertEqual(state.result, 4700)
        XCTAssertNil(state.error)
    }

    func testLiveInvalidClearsResult() {
        var state = LiveCalculationState<Double>()
        state.update { 10 }
        state.update { throw CalcError.missing("value") }
        XCTAssertNil(state.result)
        XCTAssertEqual(state.error, .missing("value"))
    }

    func testLiveClear() {
        var state = LiveCalculationState<Double>()
        state.update { 1 }
        state.clear()
        XCTAssertNil(state.result)
        XCTAssertNil(state.error)
    }

    // MARK: - Visual model honesty

    func testVisualModelRejectsNonFiniteSource() {
        let model = ValidatedVisualModel(
            requireFinite: [1.0, .nan],
            payload: "phasor",
            accessibilitySummary: "bad"
        )
        XCTAssertNil(model)
    }

    func testVisualModelAcceptsFiniteValidatedNumbers() {
        let model = ValidatedVisualModel(
            requireFinite: [120.0, 3.5],
            payload: "drop-3.5-receiving-116.5",
            accessibilitySummary: "Drop 3.5 V, receiving 116.5 V"
        )
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.accessibilitySummary.contains("3.5"), true)
    }
}
