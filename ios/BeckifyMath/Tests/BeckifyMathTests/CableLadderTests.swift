import XCTest
@testable import BeckifyMath

final class CableLadderTests: XCTestCase {

    func testPublishedMulticonductorNodes() {
        let twelveLadder = CableLadderTables.multiconductorAllowable(widthInches: 12, solidBottom: false)
        XCTAssertEqual(twelveLadder.area, 14, accuracy: 1e-12)
        XCTAssertFalse(twelveLadder.extrapolated)

        let twelveSolid = CableLadderTables.multiconductorAllowable(widthInches: 12, solidBottom: true)
        XCTAssertEqual(twelveSolid.area, 11, accuracy: 1e-12)

        XCTAssertEqual(CableLadderTables.multiconductorAllowable(widthInches: 6, solidBottom: false).area, 7, accuracy: 1e-12)
        XCTAssertEqual(CableLadderTables.multiconductorAllowable(widthInches: 6, solidBottom: true).area, 5.5, accuracy: 1e-12)
        XCTAssertEqual(CableLadderTables.multiconductorAllowable(widthInches: 9, solidBottom: false).area, 10.5, accuracy: 1e-12)
        XCTAssertEqual(CableLadderTables.multiconductorAllowable(widthInches: 9, solidBottom: true).area, 8, accuracy: 1e-12)
        XCTAssertEqual(CableLadderTables.multiconductorAllowable(widthInches: 36, solidBottom: false).area, 42, accuracy: 1e-12)
        XCTAssertEqual(CableLadderTables.multiconductorAllowable(widthInches: 36, solidBottom: true).area, 33, accuracy: 1e-12)
    }

    func testInterpolationAndExtrapolation() {
        let fifteen = CableLadderTables.multiconductorAllowable(widthInches: 15, solidBottom: false)
        XCTAssertEqual(fifteen.area, 17.5, accuracy: 1e-9)
        XCTAssertFalse(fifteen.extrapolated)

        let narrow = CableLadderTables.multiconductorAllowable(widthInches: 5, solidBottom: false)
        XCTAssertTrue(narrow.extrapolated)
        XCTAssertLessThan(narrow.area, 7)

        let nine = CableLadderTables.singleConductorColumn1(widthInches: 9)
        XCTAssertEqual(nine.area, 9.75, accuracy: 1e-9)
        XCTAssertFalse(nine.extrapolated)
        XCTAssertEqual(CableLadderTables.singleConductorColumn1(widthInches: 12).area, 13, accuracy: 1e-12)
    }

    func testChannelColumns() {
        let one = CableLadderTables.channelAllowable(widthInches: 4, cableCount: 1)
        XCTAssertEqual(one.area, 4.5, accuracy: 1e-12)
        let many = CableLadderTables.channelAllowable(widthInches: 4, cableCount: 2)
        XCTAssertEqual(many.area, 2.5, accuracy: 1e-12)
        XCTAssertEqual(CableLadderTables.channelAllowable(widthInches: 6, cableCount: 3).area, 3.8, accuracy: 1e-12)
        XCTAssertTrue(CableLadderTables.channelAllowable(widthInches: 2, cableCount: 1).extrapolated)
    }

    func testControlSignalDepthCap() {
        XCTAssertEqual(
            CableLadderTables.controlSignalAllowable(widthInches: 12, depthInches: 4, solidBottom: false),
            24,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            CableLadderTables.controlSignalAllowable(widthInches: 12, depthInches: 8, solidBottom: false),
            36,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            CableLadderTables.controlSignalAllowable(widthInches: 12, depthInches: 4, solidBottom: true),
            19.2,
            accuracy: 1e-12
        )
    }

    func testFillStatusThresholds() {
        XCTAssertEqual(CableLadderTables.fillStatus(percentOfLimit: 80), .pass)
        XCTAssertEqual(CableLadderTables.fillStatus(percentOfLimit: 80.001), .warn)
        XCTAssertEqual(CableLadderTables.fillStatus(percentOfLimit: 100), .warn)
        XCTAssertEqual(CableLadderTables.fillStatus(percentOfLimit: 100.001), .fail)
    }

    func testSupportStations() throws {
        let even = try CableLadderTables.supportStations(runLengthFeet: 80, spanFeet: 8)
        XCTAssertEqual(even.first, 0)
        XCTAssertEqual(even.last, 80)
        XCTAssertEqual(even.count, 11)
        for pair in zip(even, even.dropFirst()) {
            XCTAssertEqual(pair.1 - pair.0, 8, accuracy: 1e-9)
        }

        let remainder = try CableLadderTables.supportStations(runLengthFeet: 30, spanFeet: 8)
        XCTAssertEqual(remainder, [0, 8, 16, 24, 30])

        let oneSpan = try CableLadderTables.supportStations(runLengthFeet: 10, spanFeet: 12)
        XCTAssertEqual(oneSpan, [0, 10])

        XCTAssertThrowsError(try CableLadderTables.supportStations(runLengthFeet: 80, spanFeet: 0))
    }

    func testNineFiveHundredKcmilPassesAndUsesColumn1() throws {
        let result = try CableLadder.calculate(feeder(perPhase: 3))
        let area = try XCTUnwrap(NECTables.conductorArea(size: "500", insulation: .thhn))
        XCTAssertEqual(result.cableArea, 9 * area, accuracy: 1e-9)
        XCTAssertEqual(result.allowableArea ?? 0, 13, accuracy: 1e-9)
        XCTAssertEqual(result.codePercent, (9 * area) / 13 * 100, accuracy: 1e-6)
        XCTAssertEqual(result.status, .pass)
        XCTAssertTrue(result.reasons.contains { $0.contains("Within the cited fill limit") })
        XCTAssertEqual(result.supportStationsFeet.count, 11)
        XCTAssertFalse(result.extrapolated)
        XCTAssertTrue(result.basis.contains("392.22(B)"))
    }

    func testOverfillFailsAndWarnBand() throws {
        let fail = try CableLadder.calculate(feeder(perPhase: 7))
        XCTAssertEqual(fail.status, .fail)
        XCTAssertGreaterThan(fail.codePercent, 100)

        let warn = try CableLadder.calculate(singleSize("500", count: 15, role: .phaseA))
        XCTAssertEqual(warn.status, .warn)
        XCTAssertGreaterThan(warn.codePercent, 80)
        XCTAssertLessThanOrEqual(warn.codePercent, 100)

        let pass = try CableLadder.calculate(singleSize("500", count: 14, role: .phaseA))
        XCTAssertEqual(pass.status, .pass)
        XCTAssertLessThanOrEqual(pass.codePercent, 80)
    }

    func testSolidCoverUsesSolidBottomColumn() throws {
        var open = feeder(perPhase: 3)
        open.cover = .none
        var covered = open
        covered.cover = .solid
        let openResult = try CableLadder.calculate(open)
        let coveredResult = try CableLadder.calculate(covered)
        XCTAssertEqual(openResult.allowableArea ?? 0, 13, accuracy: 1e-9)
        XCTAssertEqual(coveredResult.allowableArea ?? 0, 11, accuracy: 1e-9)
        XCTAssertTrue(coveredResult.basis.contains("solid cover"))
        XCTAssertGreaterThan(coveredResult.codePercent, openResult.codePercent)
    }

    func testOneOughtBookWeightAndLoadClass() throws {
        let result = try CableLadder.calculate(singleSize("1/0", count: 1, role: .phaseA))
        XCTAssertEqual(result.load.cableLbPerFt, 319.5 / 1000, accuracy: 1e-9)
        XCTAssertEqual(result.load.matchedClass, "8A")
        XCTAssertTrue(result.load.weightComplete)
        XCTAssertFalse(result.load.exceedsClassC)

        let heavy = CableLadder.loadCheck(lbPerFt: 60, spanFeet: 12, weightComplete: true, material: .steel)
        XCTAssertEqual(heavy.matchedClass, "12B")
        let full = CableLadder.loadCheck(lbPerFt: 90, spanFeet: 16, weightComplete: true, material: .steel)
        XCTAssertEqual(full.matchedClass, "16C")
        let over = CableLadder.loadCheck(lbPerFt: 120, spanFeet: 8, weightComplete: true, material: .aluminum)
        XCTAssertNil(over.matchedClass)
        XCTAssertTrue(over.exceedsClassC)
        XCTAssertTrue(over.note.contains("aluminum"))
        XCTAssertTrue(over.note.contains("does not change the letter"))

        let customSpan = CableLadder.loadCheck(lbPerFt: 40, spanFeet: 10, weightComplete: true, material: .steel)
        XCTAssertNil(customSpan.matchedClass)
        XCTAssertEqual(customSpan.workingLetter, "A")
        XCTAssertFalse(customSpan.spanIsPublishedNEMA)

        let sameSteel = CableLadder.loadCheck(lbPerFt: 13, spanFeet: 8, weightComplete: true, material: .steel)
        let sameAluminum = CableLadder.loadCheck(lbPerFt: 13, spanFeet: 8, weightComplete: true, material: .aluminum)
        XCTAssertEqual(sameSteel.matchedClass, sameAluminum.matchedClass)
    }

    func testSmallSingleConductorIsNotTrayWire() throws {
        let result = try CableLadder.calculate(singleSize("12", count: 4, role: .phaseA))
        XCTAssertEqual(result.status, .warn)
        XCTAssertTrue(result.reasons.contains { $0.contains("1/0") })
        let cable = try XCTUnwrap(result.specChips.first { $0.id == "cable" })
        XCTAssertEqual(cable.value, "Not tray wire")
        XCTAssertTrue(cable.raisesWarning)
        XCTAssertTrue(cable.detail.contains("THHN"))
    }

    func testLargeSingleConductorAsksForTrayMarking() throws {
        let result = try CableLadder.calculate(feeder(perPhase: 1))
        let cable = try XCTUnwrap(result.specChips.first { $0.id == "cable" })
        XCTAssertEqual(cable.value, "1/0+ and tray-marked")
        XCTAssertFalse(cable.raisesWarning)
        XCTAssertTrue(cable.detail.contains("TC"))
    }

    func testRungSpacingOverNineInchesWarns() throws {
        var input = feeder(perPhase: 1)
        input.rungSpacingInches = 12
        let result = try CableLadder.calculate(input)
        XCTAssertEqual(result.status, .warn)
        XCTAssertTrue(result.reasons.contains { $0.contains("9 in") })
    }

    func testEnvironmentChipsStayHonest() throws {
        let indoor = try CableLadder.calculate(feeder(perPhase: 1, environment: .indoorDry))
        let nema = try XCTUnwrap(indoor.specChips.first { $0.id == "nema" })
        XCTAssertEqual(nema.value, "1")
        XCTAssertTrue(nema.detail.contains("not a NEMA 250 enclosure"))
        XCTAssertTrue(nema.detail.contains("VE 1"))
        let conduit = try XCTUnwrap(indoor.specChips.first { $0.id == "conduit" })
        XCTAssertEqual(conduit.value, "EMT")
        XCTAssertTrue(conduit.detail.contains("set-screw"))
        let ip = try XCTUnwrap(indoor.specChips.first { $0.id == "ip" })
        XCTAssertEqual(ip.value, "—")

        let rain = try CableLadder.calculate(feeder(perPhase: 1, environment: .outdoorRain))
        XCTAssertEqual(rain.specChips.first { $0.id == "nema" }?.value, "3R")
        XCTAssertEqual(rain.specChips.first { $0.id == "conduit" }?.value, "RMC")
        XCTAssertEqual(rain.specChips.first { $0.id == "ip" }?.value, "—")
        XCTAssertTrue(rain.specChips.first { $0.id == "cable" }?.detail.contains("THWN-2") == true)

        let wash = try CableLadder.calculate(feeder(perPhase: 1, environment: .washdown))
        let washIP = try XCTUnwrap(wash.specChips.first { $0.id == "ip" })
        XCTAssertEqual(washIP.value, "IPX6")
        XCTAssertTrue(washIP.detail.contains("roughly"))
        XCTAssertTrue(washIP.detail.contains("NEMA 4"))
        XCTAssertEqual(wash.specChips.first { $0.id == "nema" }?.value, "4")

        let corrosive = try CableLadder.calculate(feeder(perPhase: 1, environment: .corrosive))
        XCTAssertEqual(corrosive.specChips.first { $0.id == "nema" }?.value, "4X")
        XCTAssertEqual(corrosive.specChips.first { $0.id == "conduit" }?.value, "PVC Sch 80")

        let dust = try CableLadder.calculate(feeder(perPhase: 1, environment: .indoorDustDrip))
        XCTAssertEqual(dust.specChips.first { $0.id == "nema" }?.value, "12")
        XCTAssertTrue(dust.specChips.first { $0.id == "ip" }?.detail.contains("IP5X") == true)

        for environment in CableLadderEnvironment.allCases {
            let result = try CableLadder.calculate(feeder(perPhase: 1, environment: environment))
            let blob = result.specChips.map(\.detail).joined(separator: " ")
            XCTAssertFalse(blob.contains("IP65"), environment.rawValue)
            XCTAssertFalse(blob.contains("IP54"), environment.rawValue)
            XCTAssertFalse(blob.contains("IP67"), environment.rawValue)
        }
    }

    func testFlexibleDropAndExposedRunDoNotChangeFill() throws {
        var base = feeder(perPhase: 2)
        base.contents = .multiconductorMixed
        base.cables = [
            CableLadderCableInput(
                count: 4,
                sizing: .overallDiameter(inches: 1.2, weightLbPerKft: 800),
                role: .phaseA
            ),
        ]
        var exposed = base
        exposed.exposedRun = true
        var whip = base
        whip.flexibleDrop = true

        let plain = try CableLadder.calculate(base)
        let er = try CableLadder.calculate(exposed)
        let lfmc = try CableLadder.calculate(whip)
        XCTAssertEqual(plain.codePercent, er.codePercent, accuracy: 1e-9)
        XCTAssertEqual(plain.codePercent, lfmc.codePercent, accuracy: 1e-9)
        XCTAssertEqual(er.specChips.first { $0.id == "cable" }?.value, "TC-ER")
        XCTAssertTrue(er.specChips.first { $0.id == "cable" }?.detail.contains("336.10(7)") == true)
        XCTAssertEqual(lfmc.specChips.first { $0.id == "conduit" }?.value, "LFMC")
        XCTAssertEqual(lfmc.conduitDropLabel, "LFMC")
    }

    func testPhaseLegendMatchesReferenceLibraryNames() {
        let low = CableLadder.colorLegend(
            system: .low120,
            roles: [.phaseA, .phaseB, .phaseC, .neutral, .egc],
            tintEnabled: true
        )
        XCTAssertEqual(low.entries.map(\.colorName), ["Black", "Red", "Blue", "White", "Green"])
        XCTAssertEqual(low.entries.map(\.letter), ["A", "B", "C", "N", "G"])
        XCTAssertTrue(low.tintEnabled)
        XCTAssertTrue(low.disclaimer.contains("Convention aid only"))

        let high = CableLadder.colorLegend(
            system: .high277,
            roles: [.phaseA, .phaseB, .phaseC, .neutral, .egc, .control],
            tintEnabled: false
        )
        XCTAssertEqual(high.entries.map(\.colorName), ["Brown", "Orange", "Yellow", "Grey", "Green", "Not a phase color"])
        XCTAssertFalse(high.tintEnabled)

        let blob = ReferenceLibrary.conductorColors.entries
            .map { "\($0.title) \($0.detail)" }
            .joined(separator: " ")
            .lowercased()
        for name in ["black", "red", "blue", "white", "green", "brown", "orange", "yellow", "grey"] {
            XCTAssertTrue(blob.contains(name), name)
        }
    }

    func testCalculatedLegendFollowsTheRows() throws {
        let result = try CableLadder.calculate(feeder(perPhase: 1))
        XCTAssertEqual(result.legend.entries.map(\.colorName), ["Black", "Red", "Blue"])
        XCTAssertTrue(result.accessibilitySummary.contains("PASS"))
        XCTAssertTrue(result.accessibilitySummary.contains("Black"))
        var plain = feeder(perPhase: 1)
        plain.tintByRole = false
        let untinted = try CableLadder.calculate(plain)
        XCTAssertFalse(untinted.legend.tintEnabled)
        XCTAssertTrue(untinted.accessibilitySummary.contains("tint is off"))
    }

    func testPackingStaysInsideWithoutOverlap() throws {
        let result = try CableLadder.calculate(feeder(perPhase: 3))
        XCTAssertEqual(result.circles.count, 9)
        for circle in result.circles {
            XCTAssertTrue(circle.fits)
            XCTAssertGreaterThanOrEqual(circle.centerXInches - circle.diameterInches / 2, -1e-6)
            XCTAssertLessThanOrEqual(circle.centerXInches + circle.diameterInches / 2, 12 + 1e-6)
            XCTAssertGreaterThanOrEqual(circle.centerYInches - circle.diameterInches / 2, -1e-6)
            XCTAssertLessThanOrEqual(circle.centerYInches + circle.diameterInches / 2, 4 + 1e-6)
        }
        for left in result.circles {
            for right in result.circles where right.id > left.id {
                let dx = left.centerXInches - right.centerXInches
                let dy = left.centerYInches - right.centerYInches
                let distance = (dx * dx + dy * dy).squareRoot()
                let minDistance = (left.diameterInches + right.diameterInches) / 2
                XCTAssertGreaterThanOrEqual(distance + 1e-6, minDistance)
            }
        }
    }

    func testNarrowWidthIsExtrapolationWarn() throws {
        var input = feeder(perPhase: 1)
        input.widthInches = 5
        let result = try CableLadder.calculate(input)
        XCTAssertTrue(result.extrapolated)
        XCTAssertEqual(result.status, .warn)
        XCTAssertTrue(result.reasons.contains { $0.contains("outside the published table") })
    }

    func testTable5OnMulticonductorWarns() throws {
        var input = feeder(perPhase: 1)
        input.contents = .multiconductorMixed
        let result = try CableLadder.calculate(input)
        XCTAssertEqual(result.status, .warn)
        XCTAssertTrue(result.reasons.contains { $0.contains("jacketed") })
    }

    func testDiameterMatchesArea() throws {
        let area = try XCTUnwrap(NECTables.conductorArea(size: "500", insulation: .thhn))
        let diameter = CableLadderTables.diameterInches(areaSquareInches: area)
        XCTAssertEqual(.pi * (diameter / 2) * (diameter / 2), area, accuracy: 1e-12)
    }

    func testOneThousandKcmilUsesSingleLayer() throws {
        let eight = try CableLadder.calculate(singleSize("1000", count: 8, role: .phaseA))
        XCTAssertNil(eight.allowableArea)
        XCTAssertTrue(eight.basis.contains("392.22(B)(1)(a)"))
        XCTAssertTrue(eight.circles.allSatisfy { abs($0.centerYInches - eight.circles[0].centerYInches) < 1e-9 })

        let ten = try CableLadder.calculate(singleSize("1000", count: 10, role: .phaseA))
        XCTAssertEqual(ten.status, .fail)
        XCTAssertTrue(ten.circles.contains { !$0.fits })
    }

    private func feeder(perPhase: Int, environment: CableLadderEnvironment = .indoorDry) -> CableLadderInput {
        CableLadderInput(
            environment: environment,
            cables: [
                CableLadderCableInput(count: perPhase, sizing: .table5(size: "500", insulation: .thhn, material: .copper), role: .phaseA),
                CableLadderCableInput(count: perPhase, sizing: .table5(size: "500", insulation: .thhn, material: .copper), role: .phaseB),
                CableLadderCableInput(count: perPhase, sizing: .table5(size: "500", insulation: .thhn, material: .copper), role: .phaseC),
            ]
        )
    }

    private func singleSize(_ size: String, count: Int, role: CableLadderCableRole) -> CableLadderInput {
        CableLadderInput(
            cables: [
                CableLadderCableInput(
                    count: count,
                    sizing: .table5(size: size, insulation: .thhn, material: .copper),
                    role: role
                ),
            ]
        )
    }
}
