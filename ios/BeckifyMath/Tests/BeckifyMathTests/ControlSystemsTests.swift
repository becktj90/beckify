import XCTest
@testable import BeckifyMath

final class ControlSystemsTests: XCTestCase {

    func testFirstOrderPlantAndDCGain() {
        let tf = ControlSystems.firstOrderPlant(km: 1, tau: 2)
        XCTAssertEqual(tf.numerator, [1])
        XCTAssertEqual(tf.denominator, [2, 1])
        XCTAssertEqual(ControlSystems.dcGain(tf), 1, accuracy: 1e-12)
        XCTAssertTrue(ControlSystems.isStable(tf))
        XCTAssertEqual(tf.order, 1)
    }

    func testSecondOrderPlantMatchesLibrary() throws {
        let tf = ControlSystems.secondOrderPlant(wn: 2, zeta: 0.3)
        XCTAssertEqual(tf.numerator[0], 4, accuracy: 1e-12)
        XCTAssertEqual(tf.denominator[0], 1, accuracy: 1e-12)
        XCTAssertEqual(tf.denominator[1], 1.2, accuracy: 1e-12)
        XCTAssertEqual(tf.denominator[2], 4, accuracy: 1e-12)

        let plant = try ControlSystems.resolvePlant(id: .secondOrder)
        XCTAssertEqual(plant.dcGain, 1, accuracy: 1e-9)
        XCTAssertTrue(plant.openLoopStable)
        XCTAssertEqual(plant.order, 2)
        XCTAssertEqual(plant.poles.count, 2)
    }

    func testDCMotorDCGainAndStateSpace() throws {
        let plant = try ControlSystems.resolvePlant(id: .dcMotorSpeed)
        XCTAssertEqual(plant.dcGain, 0.6 / 0.52, accuracy: 1e-9)
        let ss = ControlSystems.transferFunctionToStateSpace(plant.transferFunction)
        XCTAssertEqual(ss.a.count, 2)
        XCTAssertEqual(ss.b.last?[0] ?? 0, 1, accuracy: 1e-12)
        // Leading-coefficient normalization: G = 0.6/(0.002s²+0.08s+0.52) settles at 1.1538, not 0.0023.
        let step = try ControlSystems.simulateStep(plant.transferFunction, duration: 2, dt: 0.01)
        XCTAssertEqual(step.last?.y ?? 0, plant.dcGain, accuracy: 0.05)
    }

    func testIntegratorDCGainIsInfiniteAndUnstableOpenLoopPolesAtOrigin() throws {
        let plant = try ControlSystems.resolvePlant(id: .integrator)
        XCTAssertTrue(plant.dcGain.isInfinite)
        XCTAssertFalse(plant.openLoopStable)
        XCTAssertEqual(plant.poles.count, 1)
        XCTAssertEqual(plant.poles[0].re, 0, accuracy: 1e-6)
    }

    func testUnstableFirstOrderIsFlagged() throws {
        let plant = try ControlSystems.resolvePlant(id: .unstableFirstOrder)
        XCTAssertFalse(plant.openLoopStable)
        XCTAssertGreaterThan(plant.poles[0].re, 0)
    }

    func testCustomPolynomialParseAndRejectImproper() throws {
        XCTAssertEqual(ControlSystems.parsePolynomial("4, 1.2,  0"), [4, 1.2, 0])
        XCTAssertEqual(ControlSystems.parsePolynomial("1  2 3"), [1, 2, 3])

        let tf = try ControlSystems.validateCustom(numeratorText: "1", denominatorText: "2, 1")
        XCTAssertEqual(tf.numerator, [1])
        XCTAssertEqual(tf.denominator, [2, 1])

        XCTAssertThrowsError(try ControlSystems.validateCustom(numeratorText: "1, 2, 3", denominatorText: "1, 1")) { error in
            guard let calc = error as? CalcError else { return XCTFail("expected CalcError") }
            XCTAssertTrue(calc.message.contains("Improper"))
        }
        XCTAssertThrowsError(try ControlSystems.validateCustom(numeratorText: "", denominatorText: "1, 1"))
        XCTAssertThrowsError(try ControlSystems.validateCustom(numeratorText: "1", denominatorText: "0, 0"))
    }

    func testClosedLoopFirstOrderPControl() throws {
        let plant = ControlSystems.firstOrderPlant(km: 1, tau: 1)
        let result = try ControlSystems.stepTune(
            plant: plant,
            mode: .p,
            gains: ControlPidGains(kp: 1, ki: 0, kd: 0),
            duration: 8
        )
        XCTAssertTrue(result.stable)
        XCTAssertEqual(result.metrics?.finalValue ?? 0, 0.5, accuracy: 0.03)
        XCTAssertEqual(result.metrics?.steadyStateError ?? 1, 0.5, accuracy: 0.03)
        XCTAssertFalse(result.closedLoop.isEmpty)
        XCTAssertFalse(result.openLoop.isEmpty)
    }

    func testPIDrivesFirstOrderOffsetTowardZero() throws {
        let plant = ControlSystems.firstOrderPlant(km: 1, tau: 2)
        let pOnly = try ControlSystems.stepTune(
            plant: plant,
            mode: .p,
            gains: ControlPidGains(kp: 2, ki: 0, kd: 0),
            duration: 20
        )
        let pi = try ControlSystems.stepTune(
            plant: plant,
            mode: .pi,
            gains: ControlPidGains(kp: 2, ki: 1, kd: 0),
            duration: 20
        )
        XCTAssertTrue(pOnly.stable)
        XCTAssertTrue(pi.stable)
        let pErr = pOnly.metrics?.steadyStateError ?? 1
        let piErr = pi.metrics?.steadyStateError ?? 1
        XCTAssertGreaterThan(pErr, 0.2)
        XCTAssertLessThan(piErr, 0.08)
    }

    func testUnstablePlantOpenLoopDiverges() throws {
        let plant = try ControlSystems.resolvePlant(id: .unstableFirstOrder)
        let open = try ControlSystems.stepTune(
            plant: plant.transferFunction,
            mode: .open,
            gains: ControlPidGains(kp: 0),
            duration: 8
        )
        XCTAssertFalse(open.stable)
        XCTAssertTrue(open.diverged || (open.closedLoop.last?.y ?? 0) > 10)
    }

    func testBodeFirstOrderAtUnityFrequency() {
        let tf = ControlTransferFunction(numerator: [1], denominator: [1, 1])
        let response = ControlSystems.evaluateTransferFunction(tf, omega: 1)
        XCTAssertEqual(response.magnitude, 1 / sqrt(2), accuracy: 1e-9)
        XCTAssertEqual(20 * log10(response.magnitude), -3.0103, accuracy: 0.01)
        XCTAssertEqual(response.phaseDeg, -45, accuracy: 0.05)
    }

    func testBodeMarginsAndBandwidthForProportionalLoop() throws {
        let plant = ControlTransferFunction(numerator: [4], denominator: [1, 1.2, 4])
        let bode = try ControlSystems.bodeAnalysis(plant: plant, loopGain: 1)
        XCTAssertFalse(bode.magnitude.isEmpty)
        XCTAssertFalse(bode.phase.isEmpty)
        XCTAssertEqual(bode.magnitude.count, bode.phase.count)
        XCTAssertNotNil(bode.margins.phaseMarginDeg)
        if let pm = bode.margins.phaseMarginDeg {
            XCTAssertGreaterThan(pm, 20)
            XCTAssertLessThan(pm, 120)
        }
        if let wb = bode.bandwidth {
            XCTAssertGreaterThan(wb, 0)
        }
        XCTAssertTrue(bode.closedLoopStable)
    }

    func testLeadPhaseBumpAndAnalogParts() throws {
        let designed = try ControlSystems.designLeadPhaseBump(phaseDeg: 50, omega: 4)
        let expectedAlpha = (1 - sin(50 * Double.pi / 180)) / (1 + sin(50 * Double.pi / 180))
        XCTAssertEqual(designed.alpha, expectedAlpha, accuracy: 1e-9)
        XCTAssertEqual(designed.timeConstant, 1 / (4 * sqrt(expectedAlpha)), accuracy: 1e-9)
        XCTAssertEqual(designed.tf.numerator[0], designed.timeConstant, accuracy: 1e-9)
        XCTAssertEqual(designed.tf.denominator[0], designed.alpha * designed.timeConstant, accuracy: 1e-9)

        let parts = ControlSystems.leadNetworkParts(alpha: designed.alpha, timeConstant: designed.timeConstant)
        XCTAssertEqual(parts.c1, 1e-7, accuracy: 1e-18)
        XCTAssertEqual(parts.r1, designed.timeConstant / 1e-7, accuracy: 1e-6)
        XCTAssertEqual(parts.r2, (designed.alpha * designed.timeConstant) / 1e-7, accuracy: 1e-6)
        XCTAssertEqual(parts.dcGain, -parts.r2 / parts.r1, accuracy: 1e-12)

        XCTAssertThrowsError(try ControlSystems.designLeadPhaseBump(phaseDeg: 90, omega: 4))
        XCTAssertThrowsError(try ControlSystems.designLeadPhaseBump(phaseDeg: 50, omega: 0))
    }

    func testLeadOnSecondOrderImprovesClosedLoop() throws {
        let plant = try ControlSystems.resolvePlant(id: .secondOrder)
        let lead = try ControlSystems.leadDesign(
            plant: plant.transferFunction,
            phaseDeg: 50,
            omega: 4,
            duration: 8
        )
        XCTAssertTrue(lead.display.contains("s"))
        XCTAssertFalse(lead.plantStep.isEmpty)
        XCTAssertFalse(lead.leadStep.isEmpty)
        XCTAssertGreaterThan(lead.alpha, 0)
        XCTAssertLessThan(lead.alpha, 1)
    }

    func testFormatTransferFunctionAndComplex() {
        let tf = ControlTransferFunction(numerator: [4], denominator: [1, 1.2, 4])
        let text = ControlSystems.formatTransferFunction(tf)
        XCTAssertTrue(text.contains("4"))
        XCTAssertTrue(text.contains("s"))

        let pole = ControlComplex(re: -0.6, im: 1.9)
        XCTAssertEqual(ControlSystems.formatComplex(pole), "-0.600 + 1.900j")
    }

    func testLibraryHasCuratedSubsetOnly() {
        let ids = Set(ControlSystems.libraryPlants.map(\.id))
        XCTAssertEqual(ids.count, 7)
        XCTAssertTrue(ids.contains(.firstOrder))
        XCTAssertTrue(ids.contains(.secondOrder))
        XCTAssertTrue(ids.contains(.dcMotorSpeed))
        XCTAssertFalse(ids.contains(.custom))
        XCTAssertNil(ControlSystems.libraryPlants.first { $0.id == .custom })
    }

    func testSeriesAndClosedLoopIdentities() {
        let g = ControlTransferFunction(numerator: [1], denominator: [1, 1])
        let k = ControlTransferFunction(numerator: [2], denominator: [1])
        let loop = ControlSystems.seriesTransferFunction(k, g)
        XCTAssertEqual(loop.numerator, [2])
        XCTAssertEqual(loop.denominator, [1, 1])
        let closed = ControlSystems.closedLoopTransferFunction(loop)
        XCTAssertEqual(closed.numerator, [2])
        XCTAssertEqual(closed.denominator[0], 1, accuracy: 1e-12)
        XCTAssertEqual(closed.denominator[1], 3, accuracy: 1e-12)
        XCTAssertEqual(ControlSystems.dcGain(closed), 2.0 / 3.0, accuracy: 1e-12)
    }
}
