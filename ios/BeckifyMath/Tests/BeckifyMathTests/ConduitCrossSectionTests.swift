import XCTest
@testable import BeckifyMath

final class ConduitCrossSectionTests: XCTestCase {
    func testLargeEMTUsesCurrentChapter9Areas() throws {
        XCTAssertEqual(NECTables.racewayInternalArea(kind: .emt, trade: "2-1/2"), 5.858)
        XCTAssertEqual(NECTables.racewayInternalArea(kind: .emt, trade: "3"), 8.846)
        XCTAssertEqual(NECTables.racewayInternalArea(kind: .emt, trade: "3-1/2"), 11.545)
        XCTAssertEqual(NECTables.racewayInternalArea(kind: .emt, trade: "4"), 14.753)

        // 5 × 250 kcmil THHN = 1.985 in². The older 2½ in EMT 40% column (1.915) would fail.
        // The current Table 4 bore at 40% is 2.343 in².
        let groups = [ConduitFillGroup(quantity: 5, size: "250", insulation: .thhn)]
        let result = try ConduitFill.calculate(groups: groups, raceway: .emt, tradeSize: "2-1/2")
        XCTAssertEqual(result.conduitArea, 5.858, accuracy: 1e-9)
        XCTAssertTrue(result.passes)
        XCTAssertEqual(result.maxFillArea, 5.858 * 0.40, accuracy: 1e-9)
    }

    func testPublishedIDsMatchTable4AreasAndWallsArePositive() {
        for kind in RacewayKind.allCases {
            for trade in NECTables.tradeSizes(for: kind) {
                let bore = try! XCTUnwrap(ConduitCrossSection.bore(kind: kind, trade: trade), "\(kind) \(trade)")
                let area = Double.pi * pow(bore.internalDiameterInches / 2, 2)
                XCTAssertEqual(area, bore.internalAreaSquareInches, accuracy: 0.002, "\(kind.displayName) \(trade)")
                if let outside = bore.outsideDiameterInches {
                    XCTAssertGreaterThan(outside, bore.internalDiameterInches)
                    XCTAssertGreaterThan(bore.wallThicknessInches ?? 0, 0)
                }
            }
        }
        XCTAssertNotNil(ConduitCrossSection.bore(kind: .emt, trade: "1/2")?.outsideDiameterInches)
        XCTAssertNil(ConduitCrossSection.bore(kind: .fmc, trade: "1/2")?.outsideDiameterInches)
        XCTAssertNil(ConduitCrossSection.bore(kind: .lfmc, trade: "3/4")?.outsideDiameterInches)
        XCTAssertNil(ConduitCrossSection.bore(kind: .ent, trade: "1")?.outsideDiameterInches)
        let halfEMT = try! XCTUnwrap(ConduitCrossSection.bore(kind: .emt, trade: "1/2"))
        XCTAssertEqual(halfEMT.wallThicknessInches ?? 0, (0.706 - 0.622) / 2, accuracy: 1e-9)
        let pvc80 = try! XCTUnwrap(ConduitCrossSection.bore(kind: .pvc80, trade: "1/2"))
        let pvc40 = try! XCTUnwrap(ConduitCrossSection.bore(kind: .pvc40, trade: "1/2"))
        XCTAssertEqual(pvc80.outsideDiameterInches, pvc40.outsideDiameterInches)
        XCTAssertLessThan(pvc80.internalDiameterInches, pvc40.internalDiameterInches)
    }

    func testAnnexCStyleCountsMatchKnownTHHNCells() {
        let twelve = try! XCTUnwrap(NECTables.conductorArea(size: "12", insulation: .thhn))
        let half = try! XCTUnwrap(NECTables.racewayInternalArea(kind: .emt, trade: "1/2"))
        let threeQuarter = try! XCTUnwrap(NECTables.racewayInternalArea(kind: .emt, trade: "3/4"))
        XCTAssertEqual(ConduitCrossSection.maximumIdenticalCount(conductorArea: twelve, racewayArea: half, nipple: false), 9)
        XCTAssertEqual(ConduitCrossSection.maximumIdenticalCount(conductorArea: twelve, racewayArea: threeQuarter, nipple: false), 16)
        let fourteen = try! XCTUnwrap(NECTables.conductorArea(size: "14", insulation: .thhn))
        XCTAssertEqual(ConduitCrossSection.maximumIdenticalCount(conductorArea: fourteen, racewayArea: half, nipple: false), 12)

        // Two conductors are limited to 31%, so a 40% floor must not report 2.
        let huge = half * 0.20
        XCTAssertEqual(ConduitCrossSection.maximumIdenticalCount(conductorArea: huge, racewayArea: half, nipple: false), 1)
    }

    func testThreeEqualConductorsFlagTheJamBand() throws {
        let groups = [ConduitFillGroup(quantity: 3, size: "1", insulation: .thhn)]
        let result = try ConduitFill.calculate(groups: groups, raceway: .emt, tradeSize: "1-1/4")
        let layout = try XCTUnwrap(ConduitCrossSection.make(
            result: result,
            egcGroupIndex: nil,
            context: .threePhase,
            colors: .off
        ))
        let ratio = try XCTUnwrap(layout.jamRatio)
        XCTAssertGreaterThan(ratio, 2.8)
        XCTAssertLessThan(ratio, 3.2)
        XCTAssertTrue(layout.jamNote?.contains("2.8") == true)
        XCTAssertTrue(layout.jamNote?.contains("Table 1") == true)
    }

    func testSettledPackKeepsOrdinaryFillInsideTheBore() throws {
        let result = try ConduitFill.calculate(quantity: 4, size: "12", tradeSize: "3/4")
        let layout = try XCTUnwrap(ConduitCrossSection.make(
            result: result,
            egcGroupIndex: nil,
            context: .none,
            colors: .off
        ))
        XCTAssertEqual(layout.conductors.count, 4)
        XCTAssertFalse(layout.packingOverlaps)
        XCTAssertEqual(layout.annexCMaximum, 16)
        XCTAssertEqual(layout.bore.internalDiameterInches, 0.824, accuracy: 1e-9)
        XCTAssertEqual(layout.bore.outsideDiameterInches ?? 0, 0.922, accuracy: 1e-9)
        assertPacked(layout)

        let again = try XCTUnwrap(ConduitCrossSection.make(
            result: result,
            egcGroupIndex: nil,
            context: .none,
            colors: .off
        ))
        XCTAssertEqual(layout.conductors.map(\.centerXInches), again.conductors.map(\.centerXInches))
        XCTAssertEqual(layout.conductors.map(\.centerYInches), again.conductors.map(\.centerYInches))
    }

    func testSingleConductorIsCenteredAndOversizedWireOverlaps() throws {
        let one = try ConduitFill.calculate(quantity: 1, size: "12", tradeSize: "3/4")
        let centered = try XCTUnwrap(ConduitCrossSection.make(
            result: one,
            egcGroupIndex: nil,
            context: .singlePhase,
            colors: .off
        ))
        XCTAssertEqual(centered.conductors.count, 1)
        XCTAssertEqual(centered.conductors[0].centerXInches, 0, accuracy: 1e-9)
        XCTAssertEqual(centered.conductors[0].centerYInches, 0, accuracy: 1e-9)
        XCTAssertFalse(centered.packingOverlaps)
        let metal = try XCTUnwrap(centered.conductors[0].metalDiameterInches)
        XCTAssertEqual(metal, sqrt(6530) / 1000, accuracy: 1e-9)
        XCTAssertLessThan(metal, centered.conductors[0].overallDiameterInches)

        let tight = try ConduitFill.calculate(
            groups: [ConduitFillGroup(quantity: 1, size: "4/0", insulation: .xhhw)],
            raceway: .rmc,
            tradeSize: "1/2"
        )
        let overlap = try XCTUnwrap(ConduitCrossSection.make(
            result: tight,
            egcGroupIndex: nil,
            context: .none,
            colors: .off
        ))
        XCTAssertTrue(overlap.packingOverlaps)
        XCTAssertTrue(overlap.packingNote.contains("Overlap"))
    }

    func testMixedFillPacksAndLabelsTheEGC() throws {
        let groups = [
            ConduitFillGroup(quantity: 3, size: "3/0", insulation: .thhn),
            ConduitFillGroup(quantity: 1, size: "3/0", insulation: .thhn),
            ConduitFillGroup(quantity: 1, size: "6", insulation: .thhn),
        ]
        let result = try ConduitFill.calculate(groups: groups, raceway: .emt, tradeSize: "2")
        let layout = try XCTUnwrap(ConduitCrossSection.make(
            result: result,
            egcGroupIndex: 2,
            context: .threePhase,
            colors: .low120
        ))
        XCTAssertEqual(layout.conductors.count, 5)
        XCTAssertFalse(layout.packingOverlaps)
        XCTAssertNil(layout.annexCMaximum)
        assertPacked(layout)

        let egc = layout.conductors.filter { $0.role == .egc }
        XCTAssertEqual(egc.count, 1)
        XCTAssertEqual(egc.first?.size, "6")
        XCTAssertEqual(egc.first?.colorName, "Green")

        let phases = layout.conductors.filter { $0.role != .egc }.map(\.role)
        XCTAssertEqual(phases, [.phaseA, .phaseB, .phaseC, .neutral])
        XCTAssertEqual(
            layout.conductors.filter { $0.role != .egc }.map(\.colorName),
            ["Black", "Red", "Blue", "White"]
        )
        let blob = ReferenceLibrary.conductorColors.entries
            .map { "\($0.title) \($0.detail)" }
            .joined(separator: " ")
        for name in ["Black", "Red", "Blue", "White", "Green", "Brown", "Orange", "Yellow"] {
            XCTAssertTrue(blob.localizedCaseInsensitiveContains(name), name)
        }
        XCTAssertTrue(layout.legend.contains { $0.role == .egc && $0.count == 1 })
        XCTAssertTrue(layout.legendDisclaimer.localizedCaseInsensitiveContains("legend"))
        XCTAssertTrue(layout.guidance.contains { $0.body.localizedCaseInsensitiveContains("NEMA") })
        XCTAssertGreaterThan(layout.freeAreaPercent, 0)
    }

    func testHighVoltageTintAndASNZSFactorStayBesideNEC() throws {
        let result = try ConduitFill.calculate(quantity: 3, size: "12", tradeSize: "1/2")
        let layout = try XCTUnwrap(ConduitCrossSection.make(
            result: result,
            egcGroupIndex: nil,
            context: .threePhase,
            colors: .high277
        ))
        XCTAssertEqual(layout.conductors.map(\.colorName), ["Brown", "Orange", "Yellow"])
        XCTAssertEqual(layout.asnzsSpaceFactorPercent, 40)
        XCTAssertFalse(layout.exceedsASNZSGuidance)
        XCTAssertEqual(ConduitCrossSection.asnzsSpaceFactorPercent(cableCount: 1), 50)
        XCTAssertEqual(ConduitCrossSection.asnzsSpaceFactorPercent(cableCount: 2), 33)
        XCTAssertTrue(layout.accessibilitySummary.contains("Illustrative"))
        XCTAssertTrue(layout.packingNote.localizedCaseInsensitiveContains("illustrative") || layout.packingNote.localizedCaseInsensitiveContains("Illustrative"))
    }

    func testNippleNoteAndUnmarkedWhenTintHasNoCircuit() throws {
        let result = try ConduitFill.calculate(
            groups: [ConduitFillGroup(quantity: 2, size: "12", insulation: .thhn)],
            raceway: .emt,
            tradeSize: "1/2",
            nipple: true
        )
        let layout = try XCTUnwrap(ConduitCrossSection.make(
            result: result,
            egcGroupIndex: nil,
            context: .none,
            colors: .low120
        ))
        XCTAssertEqual(layout.asnzsSpaceFactorPercent, 33)
        XCTAssertTrue(layout.conductors.allSatisfy { $0.role == .unmarked && $0.colorName == nil })
        XCTAssertTrue(layout.guidance.contains { $0.id == "nipple" })
        XCTAssertTrue(layout.legendDisclaimer.contains("1Ø"))
    }

    private func assertPacked(_ layout: ConduitCrossSectionLayout) {
        let boreR = layout.bore.internalDiameterInches / 2
        for conductor in layout.conductors {
            let radius = conductor.overallDiameterInches / 2
            let fromCenter = hypot(conductor.centerXInches, conductor.centerYInches)
            XCTAssertLessThanOrEqual(fromCenter + radius, boreR + 0.002, conductor.sizeLabel)
        }
        for i in layout.conductors.indices {
            for j in layout.conductors.indices where j > i {
                let a = layout.conductors[i]
                let b = layout.conductors[j]
                let distance = hypot(a.centerXInches - b.centerXInches, a.centerYInches - b.centerYInches)
                let touch = a.overallDiameterInches / 2 + b.overallDiameterInches / 2
                XCTAssertGreaterThanOrEqual(distance + 0.002, touch)
            }
        }
    }
}
