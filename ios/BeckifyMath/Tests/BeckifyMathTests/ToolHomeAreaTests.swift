import XCTest
@testable import BeckifyMath

final class ToolHomeAreaTests: XCTestCase {

    func testEveryKnownToolHasExactlyOneArea() {
        let field = Set(ToolHomeAreaPolicy.fieldToolIDs)
        let toolkit = Set(ToolHomeAreaPolicy.toolkitToolIDs)
        XCTAssertTrue(field.isDisjoint(with: toolkit))
        XCTAssertEqual(field.union(toolkit), Set(ToolCalculationPolicy.knownToolIDs))
        XCTAssertFalse(field.isEmpty)
        XCTAssertFalse(toolkit.isEmpty)
    }

    func testHeuristicFieldJobsiteTools() {
        let field = [
            "voltageDrop", "wireAmpacity", "conduitFill", "transformer",
            "motorFLA", "power", "powerWizard", "receptacleSelector",
            "panelDirectory", "circularMils", "loadFactors", "shortCircuit",
            "motorSpeed", "isLoopVerifier", "signalScaling", "modbusAddress",
            "plcTimer", "rackCurrent", "powerFactor", "batteryBank",
            "tapChanger", "harmonicsTHD", "upsSizing", "motorNameplate",
            "heaterDesign", "empEmc", "necCircuit", "loadWorksheet",
            "cableSchedule", "solenoidDesign",
            "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
        ]
        for id in field {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
        }
    }

    func testHeuristicToolkitBasicsAndBench() {
        let toolkit = [
            "ohmsLaw", "voltageDivider", "seriesParallel", "resistorColor",
            "ledRC", "frequencyWave", "unitConverter", "timer555",
            "reactance", "phasorDiagram", "numberBase", "magneticCircuit",
            "fiberLink", "gaussianBeam", "transientCircuit", "diodeIV", "rfLink",
            "referenceLibrary",
        ]
        for id in toolkit {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
        }
    }

    func testSensorsAreFieldInstruments() {
        for id in ToolCalculationPolicy.sensorToolIDs {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .instruments, id)
        }
    }

    func testFutureAoEAnalogLandsInToolkitBench() {
        for id in ["analogWorkbench", "noiseSNR", "linearRegulator", "instrumentationAmp", "adcDac"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .bench, id)
        }
    }

    func testFutureJobsiteToolsDefaultField() {
        for id in ["solarDesign", "loadWorksheet", "cableSchedule", "motorNameplate"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
        }
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "solarDesign"), .power)
        for id in ["eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .power, id)
        }
    }

    func testShelfAreaMatchesHomeArea() {
        for id in ToolCalculationPolicy.knownToolIDs {
            let shelf = ToolHomeAreaPolicy.shelf(forToolID: id)
            XCTAssertEqual(shelf.homeArea, ToolHomeAreaPolicy.area(forToolID: id), id)
        }
    }

    func testSavedJobRestoreMapsOhmAliasesAndSkipsEmpty() {
        let mapped = ToolHomeAreaPolicy.storedFields(
            toolID: "ohmsLaw",
            inputs: ["V": "24", "I": "2", "R": "", "notes": "  "]
        )
        XCTAssertEqual(mapped["voltage"], "24")
        XCTAssertEqual(mapped["current"], "2")
        XCTAssertNil(mapped["resistance"])
        XCTAssertNil(mapped["R"])
    }

    func testSavedJobRestoreCoercesSystemAndMaterial() {
        let mapped = ToolHomeAreaPolicy.storedFields(
            toolID: "voltageDrop",
            inputs: ["sys": "3Ø AC", "V": "480", "material": "Copper"]
        )
        XCTAssertEqual(mapped["system"], ElectricalSystem.threePhase.rawValue)
        XCTAssertEqual(mapped["voltage"], "480")
        XCTAssertEqual(mapped["material"], ConductorMaterial.copper.rawValue)
    }

    func testSavedJobRestoreUnknownKeysPassThrough() {
        let mapped = ToolHomeAreaPolicy.storedFields(
            toolID: "panelDirectory",
            inputs: ["rows": "42"]
        )
        XCTAssertEqual(mapped["rows"], "42")
    }
}
