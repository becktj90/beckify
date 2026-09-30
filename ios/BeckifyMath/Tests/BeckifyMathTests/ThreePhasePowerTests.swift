import XCTest
@testable import BeckifyMath

final class ThreePhasePowerTests: XCTestCase {
    private let sqrt3 = 3.0.squareRoot()

    func testWyeDefaultsMatchLinePhaseAndPowerIdentities() throws {
        let z = ComplexOhms(resistance: 8, reactance: 6)
        let r = try ThreePhasePower.solve(topology: .wyeWye, lineToLineVolts: 480, load: z)
        let vPhase = 480 / sqrt3
        let current = vPhase / 10
        XCTAssertEqual(r.sourcePhaseVolts, vPhase, accuracy: 1e-9)
        XCTAssertEqual(r.loadPhaseVolts, vPhase, accuracy: 1e-9)
        XCTAssertEqual(r.sourceLineVolts, 480, accuracy: 1e-9)
        XCTAssertEqual(r.loadLineVolts, 480, accuracy: 1e-9)
        XCTAssertEqual(r.lineCurrent, current, accuracy: 1e-9)
        XCTAssertEqual(r.loadPhaseCurrent, r.lineCurrent, accuracy: 1e-12)
        XCTAssertEqual(r.sourcePhaseCurrent, r.lineCurrent, accuracy: 1e-12)
        XCTAssertEqual(r.voltAmps, 480 * 480 / 10, accuracy: 1e-6)
        XCTAssertEqual(r.watts, r.voltAmps * 0.8, accuracy: 1e-6)
        XCTAssertEqual(r.vars, r.voltAmps * 0.6, accuracy: 1e-6)
        XCTAssertEqual(r.powerFactor, 0.8, accuracy: 1e-12)
        XCTAssertEqual(r.phaseAngleDegrees, atan2(6, 8) * 180 / .pi, accuracy: 1e-9)
        XCTAssertTrue(r.lagging)
        XCTAssertEqual(r.neutralAmps, 0, accuracy: 1e-12)
        XCTAssertEqual(r.lineLossWatts, 0, accuracy: 1e-12)
        XCTAssertEqual(r.sourceWatts, r.watts, accuracy: 1e-6)
        XCTAssertEqual(r.topology.sourceVoltageRatio, sqrt3, accuracy: 1e-12)
        XCTAssertEqual(r.topology.loadCurrentRatio, 1, accuracy: 1e-12)
        XCTAssertEqual(r.topology.loadVoltageLeadDegrees, 30, accuracy: 1e-12)
    }

    func testDeltaLoadMatchesEquivalentWye() throws {
        let wye = try ThreePhasePower.solve(
            topology: .wyeWye,
            lineToLineVolts: 480,
            load: ComplexOhms(resistance: 8, reactance: 6)
        )
        let deltaLoad = ComplexOhms(resistance: 24, reactance: 18)
        for topology in [ThreePhaseTopology.wyeDelta, .deltaDelta] {
            let r = try ThreePhasePower.solve(topology: topology, lineToLineVolts: 480, load: deltaLoad)
            XCTAssertEqual(r.lineCurrent, wye.lineCurrent, accuracy: 1e-8, topology.rawValue)
            XCTAssertEqual(r.watts, wye.watts, accuracy: 1e-6, topology.rawValue)
            XCTAssertEqual(r.vars, wye.vars, accuracy: 1e-6, topology.rawValue)
            XCTAssertEqual(r.voltAmps, wye.voltAmps, accuracy: 1e-6, topology.rawValue)
            XCTAssertEqual(r.loadPhaseCurrent * sqrt3, r.lineCurrent, accuracy: 1e-8, topology.rawValue)
            XCTAssertEqual(r.loadPhaseVolts, r.loadLineVolts, accuracy: 1e-8, topology.rawValue)
            XCTAssertEqual(r.equivalentWye.resistance, 8, accuracy: 1e-12, topology.rawValue)
            XCTAssertEqual(r.equivalentWye.reactance, 6, accuracy: 1e-12, topology.rawValue)
            XCTAssertEqual(topology.loadVoltageRatio, 1, accuracy: 1e-12)
            XCTAssertEqual(topology.loadCurrentRatio, sqrt3, accuracy: 1e-12)
            XCTAssertEqual(topology.loadCurrentLagDegrees, 30, accuracy: 1e-12)
        }
        let closed = try ThreePhasePower.solve(
            topology: .deltaDelta,
            lineToLineVolts: 480,
            load: deltaLoad
        )
        XCTAssertFalse(closed.topology.neutralPresent)
    }

    func testDeltaWyeUsesSourceWindingVoltage() throws {
        let r = try ThreePhasePower.solve(
            topology: .deltaWye,
            lineToLineVolts: 480,
            load: ComplexOhms(resistance: 8, reactance: 6)
        )
        XCTAssertEqual(r.sourcePhaseVolts, 480, accuracy: 1e-9)
        XCTAssertEqual(r.sourcePhaseCurrent * sqrt3, r.lineCurrent, accuracy: 1e-8)
        XCTAssertEqual(r.loadPhaseVolts, 480 / sqrt3, accuracy: 1e-8)
        XCTAssertEqual(r.loadPhaseCurrent, r.lineCurrent, accuracy: 1e-9)
        XCTAssertEqual(r.topology.sourceVoltageLeadDegrees, 0, accuracy: 1e-12)
        XCTAssertTrue(r.topology.neutralPresent)
        XCTAssertEqual(r.neutralAmps, 0, accuracy: 1e-12)
    }

    func testLineDropSplitsSourceAndLoadPower() throws {
        let r = try ThreePhasePower.solve(
            topology: .wyeWye,
            lineToLineVolts: 480,
            load: ComplexOhms(resistance: 8, reactance: 6),
            line: ComplexOhms(resistance: 1, reactance: 0)
        )
        let z = (81.0 + 36.0).squareRoot()
        let current = (480 / sqrt3) / z
        XCTAssertEqual(r.lineCurrent, current, accuracy: 1e-8)
        XCTAssertEqual(r.lineLossWatts, 3 * current * current * 1, accuracy: 1e-6)
        XCTAssertEqual(r.sourceWatts, r.watts + r.lineLossWatts, accuracy: 1e-4)
        XCTAssertLessThan(r.loadLineVolts, 480)
        let theta = atan2(6.0, 8.0)
        XCTAssertEqual(r.watts, sqrt3 * r.loadLineVolts * r.lineCurrent * cos(theta), accuracy: 1e-6)
        XCTAssertEqual(r.voltAmps, sqrt3 * r.loadLineVolts * r.lineCurrent, accuracy: 1e-6)
    }

    func testLeadingLoadFlipsReactiveSign() throws {
        let r = try ThreePhasePower.solve(
            topology: .wyeWye,
            lineToLineVolts: 480,
            load: ComplexOhms(resistance: 8, reactance: -6)
        )
        XCTAssertFalse(r.lagging)
        XCTAssertLessThan(r.vars, 0)
        XCTAssertEqual(r.watts, 480 * 480 / 10 * 0.8, accuracy: 1e-4)
        XCTAssertEqual(abs(r.vars), r.watts * 0.6 / 0.8, accuracy: 1e-4)
    }

    func testRejectsShortAndNegativeResistance() {
        XCTAssertThrowsError(
            try ThreePhasePower.solve(topology: .wyeWye, lineToLineVolts: 480, load: ComplexOhms(resistance: 0, reactance: 0))
        )
        XCTAssertThrowsError(
            try ThreePhasePower.solve(topology: .deltaDelta, lineToLineVolts: 0, load: ComplexOhms(resistance: 8, reactance: 6))
        )
        XCTAssertThrowsError(
            try ThreePhasePower.solve(
                topology: .wyeWye,
                lineToLineVolts: 480,
                load: ComplexOhms(resistance: 8, reactance: 6),
                line: ComplexOhms(resistance: -1, reactance: 0)
            )
        )
    }

    func testReferralScalesComplexLoadByTurnsSquared() throws {
        let load = ComplexOhms(resistance: 8, reactance: 6)
        let straight = try ImpedanceReflection.refer(
            load: load,
            primaryVolts: 480,
            secondaryVolts: 208,
            basis: .lineVoltages
        )
        let a = 480.0 / 208.0
        XCTAssertEqual(straight.turnsRatio, a, accuracy: 1e-12)
        XCTAssertEqual(straight.referred.resistance, 8 * a * a, accuracy: 1e-8)
        XCTAssertEqual(straight.referred.reactance, 6 * a * a, accuracy: 1e-8)
        XCTAssertEqual(straight.referred.angleDegrees, load.angleDegrees, accuracy: 1e-9)
        XCTAssertEqual(straight.formula, "Z' = Z × (Np/Ns)²")

        let deltaWye = try ImpedanceReflection.refer(
            load: load,
            primaryVolts: 480,
            secondaryVolts: 208,
            basis: .deltaPrimaryWyeSecondary
        )
        let aw = sqrt3 * a
        XCTAssertEqual(deltaWye.turnsRatio, aw, accuracy: 1e-12)
        XCTAssertEqual(deltaWye.referred.resistance, 8 * aw * aw, accuracy: 1e-6)

        let wyeDelta = try ImpedanceReflection.refer(
            load: load,
            primaryVolts: 480,
            secondaryVolts: 208,
            basis: .wyePrimaryDeltaSecondary
        )
        let ad = a / sqrt3
        XCTAssertEqual(wyeDelta.turnsRatio, ad, accuracy: 1e-12)
        XCTAssertEqual(wyeDelta.referred.reactance, 6 * ad * ad, accuracy: 1e-6)
    }

    func testStepUpCutsCurrentAndLineLoss() throws {
        let loss = try ImpedanceReflection.compareLineLoss(
            system: .threePhase,
            load: ComplexOhms(resistance: 8, reactance: 6),
            secondaryVolts: 208,
            primaryVolts: 480,
            conductorOhms: 0.25
        )
        let vPhase = 208 / sqrt3
        let current = vPhase / 10
        let watts = 3 * current * current * 8
        XCTAssertEqual(loss.loadWatts, watts, accuracy: 1e-6)
        XCTAssertEqual(loss.currentLow, current, accuracy: 1e-8)
        XCTAssertEqual(loss.currentHigh, watts / (sqrt3 * 480 * 0.8), accuracy: 1e-6)
        XCTAssertLessThan(loss.currentHigh, loss.currentLow)
        XCTAssertEqual(loss.lossLowWatts, 3 * loss.currentLow * loss.currentLow * 0.25, accuracy: 1e-6)
        XCTAssertEqual(
            loss.lossHighWatts / loss.lossLowWatts,
            (208.0 / 480.0) * (208.0 / 480.0),
            accuracy: 1e-9
        )
        XCTAssertEqual(loss.assumptions.count, 4)
        XCTAssertTrue(loss.assumptions.joined(separator: " ").contains("ideal"))
        XCTAssertTrue(loss.assumptions.joined(separator: " ").contains("wye"))
    }

    func testSinglePhaseLossUsesBothConductors() throws {
        let loss = try ImpedanceReflection.compareLineLoss(
            system: .singlePhase,
            load: ComplexOhms(resistance: 8, reactance: 6),
            secondaryVolts: 240,
            primaryVolts: 480,
            conductorOhms: 0.5
        )
        let current = 240.0 / 10
        XCTAssertEqual(loss.currentLow, current, accuracy: 1e-9)
        XCTAssertEqual(loss.lossLowWatts, 2 * current * current * 0.5, accuracy: 1e-6)
        XCTAssertEqual(loss.lossHighWatts / loss.lossLowWatts, 0.25, accuracy: 1e-9)
        XCTAssertTrue(loss.assumptions.contains { $0.contains("2 I²R") })
    }

    func testPureReactiveLoadSkipsLineLossComparison() {
        XCTAssertThrowsError(
            try ImpedanceReflection.compareLineLoss(
                system: .threePhase,
                load: ComplexOhms(resistance: 0, reactance: 6),
                secondaryVolts: 480,
                primaryVolts: 480,
                conductorOhms: 0.2
            )
        )
    }
}
