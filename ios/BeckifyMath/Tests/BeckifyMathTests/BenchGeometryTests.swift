import XCTest
@testable import BeckifyMath

final class BenchGeometryTests: XCTestCase {
    // MARK: Heater materials and coil

    func testHeaterMaterialsFillResistivity() {
        XCTAssertEqual(HeaterMaterials.material(id: "nichrome80")?.resistivity, 1.09)
        XCTAssertEqual(HeaterMaterials.material(id: "kanthalA1")?.resistivity, 1.45)
        XCTAssertEqual(HeaterMaterials.material(id: "constantan")?.resistivity, 0.49)
        XCTAssertEqual(Set(HeaterMaterials.all.map(\.id)).count, HeaterMaterials.all.count)
        XCTAssertEqual(HeaterMaterials.material(matching: 1.45).id, "kanthalA1")
        XCTAssertEqual(HeaterMaterials.material(matching: 1.23).id, HeaterMaterials.customID)
        XCTAssertEqual(HeaterMaterials.material(matching: nil).id, HeaterMaterials.customID)
        for material in HeaterMaterials.all {
            XCTAssertGreaterThan(material.resistivity, 0, material.id)
        }
    }

    func testHeaterCoilGeometry() throws {
        // 2 m of 1.024 mm wire on an 8 mm mean diameter with a 1 mm gap.
        let coil = try HeaterCoil.design(wireLengthMeters: 2, wireDiameterMM: 1.024, meanDiameterMM: 8, gapMM: 1)
        XCTAssertEqual(coil.pitchMM, 2.024, accuracy: 1e-9)
        XCTAssertEqual(coil.innerDiameterMM, 6.976, accuracy: 1e-9)
        XCTAssertEqual(coil.outerDiameterMM, 9.024, accuracy: 1e-9)
        XCTAssertEqual(coil.wirePerTurnMM, 25.2141, accuracy: 1e-3)
        XCTAssertEqual(coil.turns, 79.32, accuracy: 0.01)
        XCTAssertEqual(coil.coilLengthMM, 159.55, accuracy: 0.05)
        XCTAssertEqual(coil.wireLengthMM, 2000, accuracy: 1e-9)
        // Turns times wire per turn gives the wire back.
        XCTAssertEqual(coil.turns * coil.wirePerTurnMM, coil.wireLengthMM, accuracy: 1e-6)
    }

    func testCloseWoundCoilIsShortest() throws {
        let tight = try HeaterCoil.design(wireLengthMeters: 1, wireDiameterMM: 1, meanDiameterMM: 10, gapMM: 0)
        let open = try HeaterCoil.design(wireLengthMeters: 1, wireDiameterMM: 1, meanDiameterMM: 10, gapMM: 3)
        XCTAssertEqual(tight.pitchRatio, 1, accuracy: 1e-9)
        XCTAssertLessThan(tight.coilLengthMM, open.coilLengthMM)
        XCTAssertGreaterThan(tight.turns, open.turns)
    }

    func testHeaterCoilRejectsImpossibleShapes() {
        XCTAssertThrowsError(try HeaterCoil.design(wireLengthMeters: 1, wireDiameterMM: 2, meanDiameterMM: 2, gapMM: 1))
        XCTAssertThrowsError(try HeaterCoil.design(wireLengthMeters: 1, wireDiameterMM: 1, meanDiameterMM: 8, gapMM: -1))
        XCTAssertThrowsError(try HeaterCoil.design(wireLengthMeters: 0, wireDiameterMM: 1, meanDiameterMM: 8, gapMM: 1))
        XCTAssertThrowsError(try HeaterCoil.design(wireLengthMeters: 0.01, wireDiameterMM: 1, meanDiameterMM: 20, gapMM: 1))
    }

    // MARK: Sprocket

    func testSprocketPitchAndOutsideDiameter() {
        XCTAssertEqual(SprocketGeometry.pitchDiameterMM(teeth: 14, pitchMM: 12.7), 57.073, accuracy: 0.01)
        XCTAssertEqual(SprocketGeometry.pitchDiameterMM(teeth: 56, pitchMM: 12.7), 226.50, accuracy: 0.01)
        XCTAssertEqual(SprocketGeometry.outsideDiameterMM(teeth: 14, pitchMM: 12.7), 63.262, accuracy: 0.01)
        XCTAssertGreaterThan(SprocketGeometry.outsideDiameterMM(teeth: 20, pitchMM: 12.7),
                             SprocketGeometry.pitchDiameterMM(teeth: 20, pitchMM: 12.7))
    }

    func testSprocketSetupChainLength() throws {
        let chain = SprocketChains.chain(id: "420")
        let setup = try XCTUnwrap(SprocketGeometry.setup(driveTeeth: 14, drivenTeeth: 56, chain: chain))
        XCTAssertEqual(setup.ratio, 4, accuracy: 1e-9)
        XCTAssertEqual(setup.chainLinks, 98)
        XCTAssertEqual(setup.chainLinks % 2, 0)
        XCTAssertEqual(setup.centerDistanceMM, 390.83, accuracy: 0.05)
        XCTAssertEqual(setup.chainLengthMM, 98 * 12.7, accuracy: 1e-9)
        XCTAssertEqual(setup.smallWrapDegrees, 154.96, accuracy: 0.05)
    }

    func testSprocketCustomCenterDistanceAndLimits() throws {
        let chain = SprocketChains.chain(id: "410")
        let near = try XCTUnwrap(SprocketGeometry.setup(driveTeeth: 14, drivenTeeth: 56, chain: chain, centerDistanceMM: 300))
        let far = try XCTUnwrap(SprocketGeometry.setup(driveTeeth: 14, drivenTeeth: 56, chain: chain, centerDistanceMM: 500))
        XCTAssertLessThan(near.chainLinks, far.chainLinks)
        // Too close for the two sprockets is pushed out.
        let tiny = try XCTUnwrap(SprocketGeometry.setup(driveTeeth: 14, drivenTeeth: 56, chain: chain, centerDistanceMM: 1))
        XCTAssertGreaterThan(tiny.centerDistanceMM, (tiny.drivePitchDiameterMM + tiny.drivenPitchDiameterMM) / 2)
        XCTAssertNil(SprocketGeometry.setup(driveTeeth: 3, drivenTeeth: 56, chain: chain))
        XCTAssertNil(SprocketGeometry.setup(driveTeeth: 14, drivenTeeth: 500, chain: chain))
        XCTAssertNil(SprocketGeometry.setup(driveTeeth: .nan, drivenTeeth: 56, chain: chain))
        XCTAssertEqual(SprocketChains.chain(id: "unknown").pitchMM, 12.7)
    }

    func testEqualSprocketsWrapHalfTurn() throws {
        let setup = try XCTUnwrap(SprocketGeometry.setup(driveTeeth: 20, drivenTeeth: 20, chain: SprocketChains.chain(id: "35")))
        XCTAssertEqual(setup.smallWrapDegrees, 180, accuracy: 1e-6)
        XCTAssertEqual(setup.ratio, 1, accuracy: 1e-9)
    }

    // MARK: Pack

    func testGridPackDimensions() throws {
        let pack = try XCTUnwrap(PackGeometry.model(series: 14, parallel: 10, cellDiameterMM: 18.5, cellLengthMM: 65.2, honeycomb: false))
        XCTAssertEqual(pack.cells.count, 140)
        XCTAssertEqual(pack.lengthMM, 259, accuracy: 1e-9)
        XCTAssertEqual(pack.widthMM, 185, accuracy: 1e-9)
        XCTAssertEqual(pack.heightMM, 65.5, accuracy: 1e-9)
        XCTAssertEqual(Set(pack.cells.map { "\($0.column),\($0.row)" }).count, 140)
    }

    func testHoneycombPackIsShorterAndStaggered() throws {
        let grid = try XCTUnwrap(PackGeometry.model(series: 14, parallel: 10, cellDiameterMM: 18.5, cellLengthMM: 65.2, honeycomb: false))
        let honey = try XCTUnwrap(PackGeometry.model(series: 14, parallel: 10, cellDiameterMM: 18.5, cellLengthMM: 65.2, honeycomb: true))
        XCTAssertEqual(honey.lengthMM, 226.78, accuracy: 0.05)
        XCTAssertEqual(honey.widthMM, 194.25, accuracy: 1e-9)
        XCTAssertLessThan(honey.lengthMM, grid.lengthMM)
        let first = honey.cells.first { $0.column == 0 && $0.row == 0 }
        let second = honey.cells.first { $0.column == 1 && $0.row == 0 }
        XCTAssertEqual((second?.y ?? 0) - (first?.y ?? 0), 18.5 / 2, accuracy: 1e-9)
    }

    func testPackModelRefusesHugeOrInvalidPacks() {
        XCTAssertNil(PackGeometry.model(series: 40, parallel: 20, cellDiameterMM: 18.5, cellLengthMM: 65, honeycomb: false))
        XCTAssertNil(PackGeometry.model(series: 0, parallel: 4, cellDiameterMM: 18.5, cellLengthMM: 65, honeycomb: false))
        XCTAssertNil(PackGeometry.model(series: 4, parallel: 4, cellDiameterMM: 0, cellLengthMM: 65, honeycomb: false))
        let single = PackGeometry.model(series: 1, parallel: 1, cellDiameterMM: 18, cellLengthMM: 65, honeycomb: true)
        XCTAssertEqual(single?.widthMM ?? 0, 18, accuracy: 1e-9, "one cell has no stagger")
    }

    // MARK: Part pinouts

    func testEveryPartHasConsecutivePinsMatchingItsPackage() {
        for part in PartPinouts.all {
            let numbers = part.pins.map(\.number)
            XCTAssertEqual(numbers, Array(1...numbers.count), part.id)
            switch part.package {
            case .dip(let count): XCTAssertEqual(numbers.count, count, part.id)
            case .sot23_5: XCTAssertEqual(numbers.count, 5, part.id)
            case .to220, .sot223: XCTAssertEqual(numbers.count, 3, part.id)
            }
            XCTAssertFalse(part.summary.isEmpty, part.id)
        }
        XCTAssertEqual(Set(PartPinouts.all.map(\.id)).count, PartPinouts.all.count)
    }

    func testKnownOpAmpPinouts() throws {
        func name(_ id: String, _ pin: Int) throws -> String {
            try XCTUnwrap(PartPinouts.part(id: id)?.pins.first { $0.number == pin }?.name)
        }
        XCTAssertEqual(try name("lm741", 2), "IN−")
        XCTAssertEqual(try name("lm741", 3), "IN+")
        XCTAssertEqual(try name("lm741", 4), "V−")
        XCTAssertEqual(try name("lm741", 6), "OUT")
        XCTAssertEqual(try name("lm741", 7), "V+")
        XCTAssertEqual(try name("lm358", 8), "V+")
        XCTAssertEqual(try name("lm358", 4), "V−")
        XCTAssertEqual(try name("lm358", 1), "OUT A")
        XCTAssertEqual(try name("lm358", 7), "OUT B")
        XCTAssertEqual(try name("lm324", 4), "V+")
        XCTAssertEqual(try name("lm324", 11), "V−")
        XCTAssertEqual(try name("lm324", 14), "OUT D")
        XCTAssertEqual(try name("mcp6001", 5), "V+")
        XCTAssertEqual(try name("mcp6001", 2), "V−")
        XCTAssertEqual(try name("op07", 5), "NC")
    }

    func testKnownInAmpAndRegulatorPinouts() throws {
        for id in ["ina128", "ad620"] {
            let part = try XCTUnwrap(PartPinouts.part(id: id))
            XCTAssertEqual(part.pins.filter { $0.role == .gain }.map(\.number), [1, 8], id)
            XCTAssertEqual(part.pins.first { $0.role == .reference }?.number, 5, id)
            XCTAssertEqual(part.pins.first { $0.role == .output }?.number, 6, id)
        }
        let lm317 = try XCTUnwrap(PartPinouts.part(id: "lm317"))
        XCTAssertEqual(lm317.pins.map(\.name), ["ADJ", "OUT", "IN"])
        XCTAssertEqual(lm317.tabNote, "Tab is OUT")
        let l7805 = try XCTUnwrap(PartPinouts.part(id: "lm7805"))
        XCTAssertEqual(l7805.pins.map(\.name), ["IN", "GND", "OUT"])
        XCTAssertEqual(l7805.tabNote, "Tab is GND")
        let lm1117 = try XCTUnwrap(PartPinouts.part(id: "lm1117"))
        XCTAssertEqual(lm1117.pins.map(\.number), [1, 2, 3])
        XCTAssertEqual(lm1117.pins[2].name, "IN")
    }

    func testFamiliesAreAllRepresented() {
        for family in PartFamily.allCases {
            XCTAssertFalse(PartPinouts.parts(family: family).isEmpty, family.rawValue)
        }
    }
}
