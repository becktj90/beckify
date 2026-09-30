import XCTest
@testable import BeckifyMath

final class ControlStrategyGuideTests: XCTestCase {

    func testMatrixCoversEveryStrategyAndAxis() {
        XCTAssertEqual(ControlStrategyGuide.profiles.count, ControlStrategyID.allCases.count)
        for profile in ControlStrategyGuide.profiles {
            for axis in ControlMatrixAxis.allCases {
                let cell = axis.cell(profile)
                XCTAssertFalse(cell.trimmingCharacters(in: .whitespaces).isEmpty, "\(profile.id) \(axis)")
            }
            XCTAssertFalse(profile.summary.isEmpty)
            XCTAssertFalse(profile.limit.isEmpty)
        }
        XCTAssertTrue(ControlStrategyGuide.profile(.drl).explanatoryOnly)
        XCTAssertTrue(ControlStrategyGuide.profile(.nnAdaptive).explanatoryOnly)
        XCTAssertFalse(ControlStrategyGuide.profile(.pid).explanatoryOnly)
        XCTAssertFalse(ControlStrategyGuide.profile(.adrc).explanatoryOnly)
    }

    func testRegimeFilterDimsPoorFitsWithoutDroppingTheMatrix() {
        let fast = ControlStrategyGuide.matching(linearity: .any, channels: .any, loop: .fast)
        XCTAssertTrue(fast.contains(.pid))
        XCTAssertTrue(fast.contains(.bangBang))
        XCTAssertTrue(fast.contains(.slidingMode))
        XCTAssertTrue(fast.contains(.adrc))
        XCTAssertFalse(fast.contains(.mpc))
        XCTAssertFalse(fast.contains(.drl))

        let process = ControlStrategyGuide.matching(linearity: .any, channels: .any, loop: .process)
        XCTAssertTrue(process.contains(.pid))
        XCTAssertTrue(process.contains(.mpc))
        XCTAssertFalse(process.contains(.drl))

        let mimo = ControlStrategyGuide.matching(linearity: .any, channels: .mimo, loop: .any)
        XCTAssertTrue(mimo.contains(.mpc))
        XCTAssertFalse(mimo.contains(.bangBang))

        let sisoLinear = ControlStrategyGuide.matching(linearity: .linear, channels: .siso, loop: .any)
        XCTAssertTrue(sisoLinear.contains(.pid))
        XCTAssertFalse(sisoLinear.contains(.drl))
        XCTAssertFalse(sisoLinear.contains(.nnAdaptive))

        let any = ControlStrategyGuide.matching(linearity: .any, channels: .any, loop: .any)
        XCTAssertEqual(any.count, ControlStrategyID.allCases.count)
    }

    func testApplicationsCoverTheFiveIndustries() {
        let industries = Set(ControlStrategyGuide.applications.map(\.industry))
        XCTAssertEqual(industries, Set(ControlStrategyGuide.industryOrder))
        for note in ControlStrategyGuide.applications {
            XCTAssertFalse(note.why.isEmpty)
            XCTAssertTrue(ControlStrategyID.allCases.contains(note.strategy))
        }
        XCTAssertEqual(
            ControlStrategyGuide.applications.first { $0.id == "flight-drl" }?.strategy,
            .drl
        )
        XCTAssertEqual(
            ControlStrategyGuide.applications.first { $0.id == "bms-pinn" }?.strategy,
            .nnAdaptive
        )
    }

    func testFieldDefaultIsPIDAndOpensTheLab() {
        let pick = ControlStrategyGuide.recommend(.fieldDefault)
        XCTAssertEqual(pick.primary, .pid)
        XCTAssertNil(pick.variant)
        XCTAssertTrue(pick.opensControlSystemsLab)
        XCTAssertFalse(pick.shipsTrainedPolicy)
        XCTAssertFalse(pick.reasons.isEmpty)
        XCTAssertFalse(pick.caution.isEmpty)
    }

    func testOnOffRoomStatIsBangBang() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .process, channels: .siso, plant: .linear, model: .none,
            disturbance: .mild, actuator: .onOff, priority: .maintain
        ))
        XCTAssertEqual(pick.primary, .bangBang)
        XCTAssertFalse(pick.opensControlSystemsLab)
        XCTAssertEqual(pick.alternate, .pid)
    }

    func testChillerPlantIsMPC() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .process, channels: .mimo, plant: .linear, model: .stateSpace,
            disturbance: .mild, actuator: .modulating, priority: .constraints
        ))
        XCTAssertEqual(pick.primary, .mpc)
        XCTAssertFalse(pick.opensControlSystemsLab)
        XCTAssertFalse(pick.shipsTrainedPolicy)
    }

    func testDriveCurrentStaysPID() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .fast, channels: .siso, plant: .linear, model: .rough,
            disturbance: .mild, actuator: .modulating, priority: .tracking
        ))
        XCTAssertEqual(pick.primary, .pid)
        XCTAssertTrue(pick.opensControlSystemsLab)
        XCTAssertNil(pick.variant)
    }

    func testFastMIMODoesNotPromiseOnlineMPC() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .fast, channels: .mimo, plant: .linear, model: .stateSpace,
            disturbance: .mild, actuator: .modulating, priority: .constraints
        ))
        XCTAssertEqual(pick.primary, .pid)
        XCTAssertEqual(pick.variant, "One PID per channel")
        XCTAssertEqual(pick.alternate, .mpc)
        XCTAssertTrue(pick.opensControlSystemsLab)
    }

    func testUncertainServoIsSlidingModeWithChatterCaution() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .fast, channels: .siso, plant: .nonlinear, model: .rough,
            disturbance: .strong, actuator: .modulating, priority: .tracking
        ))
        XCTAssertEqual(pick.primary, .slidingMode)
        XCTAssertTrue(pick.caution.localizedCaseInsensitiveContains("chatter"))
        XCTAssertFalse(pick.opensControlSystemsLab)
    }

    func testStrongUpsetWithoutAStateModelIsADRC() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .process, channels: .siso, plant: .linear, model: .none,
            disturbance: .strong, actuator: .modulating, priority: .maintain
        ))
        XCTAssertEqual(pick.primary, .adrc)
        XCTAssertEqual(pick.alternate, .pid)
        XCTAssertFalse(pick.shipsTrainedPolicy)
    }

    func testOperatingPointShiftIsGainScheduledPID() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .mid, channels: .siso, plant: .nonlinear, model: .rough,
            disturbance: .mild, actuator: .modulating, priority: .maintain
        ))
        XCTAssertEqual(pick.primary, .pid)
        XCTAssertEqual(pick.variant, "Gain-scheduled PID")
        XCTAssertTrue(pick.opensControlSystemsLab)
    }

    func testNoModelNonlinearProcessIsFuzzy() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .process, channels: .siso, plant: .nonlinear, model: .none,
            disturbance: .mild, actuator: .modulating, priority: .maintain
        ))
        XCTAssertEqual(pick.primary, .fuzzy)
        XCTAssertFalse(pick.shipsTrainedPolicy)
    }

    func testLearnedMIMOIsExplanatoryMLMPC() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .process, channels: .mimo, plant: .nonlinear, model: .learned,
            disturbance: .strong, actuator: .modulating, priority: .constraints
        ))
        XCTAssertEqual(pick.primary, .nnAdaptive)
        XCTAssertEqual(pick.variant, "ML-MPC")
        XCTAssertFalse(pick.shipsTrainedPolicy)
        XCTAssertFalse(pick.opensControlSystemsLab)
        XCTAssertTrue(pick.caution.localizedCaseInsensitiveContains("does not train"))
    }

    func testLearnedTrackingIsExplanatoryRL() {
        let pick = ControlStrategyGuide.recommend(constraints(
            loop: .mid, channels: .siso, plant: .nonlinear, model: .learned,
            disturbance: .strong, actuator: .modulating, priority: .tracking
        ))
        XCTAssertEqual(pick.primary, .drl)
        XCTAssertFalse(pick.shipsTrainedPolicy)
        XCTAssertTrue(pick.caution.localizedCaseInsensitiveContains("does not train"))
    }

    func testNoConstraintComboShipsAPolicy() {
        for loop in ControlLoopPace.allCases {
            for channels in ControlChannelClass.allCases {
                for plant in ControlPlantCharacter.allCases {
                    for model in ControlModelAvailability.allCases {
                        for disturbance in ControlDisturbanceDemand.allCases {
                            for actuator in ControlActuatorKind.allCases {
                                for priority in ControlFieldPriority.allCases {
                                    let pick = ControlStrategyGuide.recommend(constraints(
                                        loop: loop, channels: channels, plant: plant, model: model,
                                        disturbance: disturbance, actuator: actuator, priority: priority
                                    ))
                                    XCTAssertFalse(pick.shipsTrainedPolicy)
                                    XCTAssertTrue(ControlStrategyID.allCases.contains(pick.primary))
                                    XCTAssertTrue(ControlStrategyID.allCases.contains(pick.alternate))
                                    XCTAssertFalse(pick.reasons.isEmpty)
                                    XCTAssertFalse(pick.caution.isEmpty)
                                    if pick.primary != .pid {
                                        XCTAssertFalse(pick.opensControlSystemsLab)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func testStepSketchShowsBangBangChatterAgainstPIDAndADRC() {
        let sketch = ControlStrategyGuide.stepSketch()
        XCTAssertGreaterThan(sketch.bangBang.switchCount, sketch.pid.switchCount + 4)
        XCTAssertGreaterThan(sketch.bangBang.switchCount, sketch.adrc.switchCount + 4)
        XCTAssertGreaterThan(sketch.bangBang.lateSpread, sketch.pid.lateSpread)
        XCTAssertLessThan(sketch.pid.lateAbsoluteError, 0.08)
        XCTAssertLessThan(sketch.adrc.lateAbsoluteError, 0.08)
        XCTAssertLessThan(sketch.bangBang.lateAbsoluteError, 0.08)
        for trace in [sketch.bangBang, sketch.pid, sketch.adrc] {
            XCTAssertFalse(trace.output.isEmpty)
            XCTAssertTrue(trace.output.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            XCTAssertTrue(trace.actuator.allSatisfy { $0.y >= -0.001 && $0.y <= 1.001 })
        }
        XCTAssertEqual(sketch.disturbanceTime, 7, accuracy: 0.001)
    }

    func testHysteresisRemembersDirection() {
        let loop = ControlStrategyGuide.hysteresisLoop(band: 0.15)
        XCTAssertEqual(loop.risingTrip, 0.15, accuracy: 1e-9)
        XCTAssertEqual(loop.fallingTrip, -0.15, accuracy: 1e-9)
        let half = loop.samples.count / 2
        let ascending = loop.samples[..<half].min { abs($0.x) < abs($1.x) }
        let descending = loop.samples[half...].min { abs($0.x) < abs($1.x) }
        XCTAssertEqual(ascending?.y ?? 0, -1, accuracy: 0.001)
        XCTAssertEqual(descending?.y ?? 0, 1, accuracy: 0.001)
        XCTAssertGreaterThan(loop.risingTrip, loop.fallingTrip)
    }

    func testSlidingBoundaryLayerCutsChatter() {
        let tight = ControlStrategyGuide.slidingSketch(boundary: 0.015)
        let wide = ControlStrategyGuide.slidingSketch(boundary: 0.5)
        XCTAssertGreaterThan(tight.chatterIndex, wide.chatterIndex * 3)
        XCTAssertEqual(tight.surface.count, 2)
        XCTAssertFalse(tight.phase.isEmpty)
        XCTAssertTrue(tight.phase.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        XCTAssertTrue(wide.chatterIndex.isFinite)
    }

    func testComputeSketchIsHonestAboutLearnedMethods() {
        func point(_ id: ControlStrategyID) -> ControlComputePoint {
            ControlStrategyGuide.computeSketch.first { $0.id == id }!
        }
        let bang = point(.bangBang)
        let pid = point(.pid)
        let adrc = point(.adrc)
        let mpc = point(.mpc)
        let drl = point(.drl)
        XCTAssertLessThan(bang.compute, pid.compute)
        XCTAssertLessThan(pid.compute, adrc.compute)
        XCTAssertLessThan(adrc.compute, mpc.compute)
        XCTAssertLessThan(mpc.compute, drl.compute)
        XCTAssertLessThan(drl.tracking, mpc.tracking)
        XCTAssertLessThan(drl.tracking, pid.tracking)
        XCTAssertGreaterThan(mpc.tracking, pid.tracking)
        for item in ControlStrategyGuide.computeSketch {
            XCTAssertGreaterThanOrEqual(item.compute, 0)
            XCTAssertLessThanOrEqual(item.compute, 1)
            XCTAssertGreaterThanOrEqual(item.tracking, 0)
            XCTAssertLessThanOrEqual(item.tracking, 1)
        }
        XCTAssertEqual(ControlStrategyGuide.computeSketch.count, ControlStrategyID.allCases.count)
    }

    private func constraints(
        loop: ControlLoopPace,
        channels: ControlChannelClass,
        plant: ControlPlantCharacter,
        model: ControlModelAvailability,
        disturbance: ControlDisturbanceDemand,
        actuator: ControlActuatorKind,
        priority: ControlFieldPriority
    ) -> ControlStrategyConstraints {
        ControlStrategyConstraints(
            loop: loop,
            channels: channels,
            plant: plant,
            model: model,
            disturbance: disturbance,
            actuator: actuator,
            priority: priority
        )
    }
}
