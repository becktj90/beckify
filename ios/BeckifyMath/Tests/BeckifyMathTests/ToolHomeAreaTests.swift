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
            "voltageDrop", "wireAmpacity", "conductorCost", "conductorLength", "conduitFill", "transformer",
            "motorFLA", "power", "powerWizard", "receptacleSelector",
            "circularMils", "loadFactors", "shortCircuit",
            "motorSpeed", "isLoopVerifier", "signalScaling", "modbusAddress",
            "plcTimer", "rackCurrent", "powerFactor", "batteryBank",
            "tapChanger", "harmonicsTHD", "upsSizing", "motorNameplate",
            "motorNameplateOCR", "necCircuit",
            "controlSystems",
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
            "heaterDesign", "solenoidDesign", "empEmc",
            "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
            "panelDirectory", "loadWorksheet", "cableSchedule",
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

    func testControlSystemsIsFieldControls() {
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "controlSystems"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "controlSystems"), .controls)
    }

    func testFacilityPowerStaysFieldPower() {
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "solarDesign"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "solarDesign"), .power)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "motorNameplate"), .jobsite)
        let power = [
            "power", "powerWizard", "transformer", "powerFactor", "batteryBank",
            "solarDesign", "tapChanger", "harmonicsTHD", "upsSizing",
        ]
        for id in power {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .power, id)
        }
    }

    func testEbikeAndNickelStripAreToolkitBench() {
        for id in ["eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .bench, id)
        }
    }

    func testSpecialtyDesignIsToolkitBench() {
        for id in ["heaterDesign", "solenoidDesign", "empEmc", "magneticCircuit", "linearRegulator"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .bench, id)
        }
    }

    func testPaperworkFormsAreToolkitReference() {
        for id in ["panelDirectory", "loadWorksheet", "cableSchedule"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .reference, id)
        }
    }

    func testNECCircuitStaysFieldJobsite() {
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "necCircuit"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "necCircuit"), .jobsite)
    }

    func testPrimaryJobsiteShelfMembership() {
        let jobsite = [
            "voltageDrop", "wireAmpacity", "conductorCost", "conductorLength",
            "conduitFill", "motorFLA", "motorSpeed", "motorNameplate", "motorNameplateOCR",
            "receptacleSelector", "shortCircuit", "circularMils", "loadFactors",
            "necCircuit", "isLoopVerifier",
        ]
        for id in jobsite {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .jobsite, id)
        }
    }

    func testFieldControlsStayLoopHelpers() {
        for id in ["signalScaling", "modbusAddress", "plcTimer", "rackCurrent", "controlSystems"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .controls, id)
        }
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "timer555"), .toolkit)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "timer555"), .basics)
    }

    func testFieldPowerExcludesSpecialtyAndEbike() {
        for id in [
            "heaterDesign", "solenoidDesign", "empEmc", "magneticCircuit", "linearRegulator",
            "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
        ] {
            XCTAssertNotEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .power, id)
            XCTAssertNotEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
        }
    }

    func testFieldQuickStripIsJobsitePinnedSet() {
        XCTAssertEqual(
            ToolHomeAreaPolicy.fieldQuickIDs,
            ["voltageDrop", "wireAmpacity", "motorFLA", "receptacleSelector", "wifiStatus", "conduitFill"]
        )
        for id in ToolHomeAreaPolicy.fieldQuickIDs {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
        }
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "wifiStatus"), .instruments)
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

    func testWiFiStatusRestoreMapsSurveyAndRTTFields() {
        let mapped = ToolHomeAreaPolicy.storedFields(
            toolID: "wifiStatus",
            inputs: [
                "mode": "Tap floor",
                "rttTarget": "1.1.1.1",
                "rttHost": "192.168.1.1:80",
            ]
        )
        XCTAssertEqual(mapped["surveyMode"], "Tap floor")
        XCTAssertEqual(mapped["rttTarget"], "1.1.1.1")
        XCTAssertEqual(mapped["rttHost"], "192.168.1.1:80")
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "wifiStatus"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "wifiStatus"), .instruments)
    }

    func testCellularStatusIsFieldInstrumentAndRestoresRTTFields() {
        let mapped = ToolHomeAreaPolicy.storedFields(
            toolID: "cellularStatus",
            inputs: [
                "rttTarget": "1.1.1.1",
                "rttHost": "beckify.com:443",
            ]
        )
        XCTAssertEqual(mapped["rttTarget"], "1.1.1.1")
        XCTAssertEqual(mapped["rttHost"], "beckify.com:443")
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "cellularStatus"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "cellularStatus"), .instruments)
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "cellularStatus"), .sensor)
        XCTAssertTrue(ToolCalculationPolicy.knownToolIDs.contains("cellularStatus"))
    }

    func testConductorLengthRestoreMapsAliasesAndPreset() {
        let mapped = ToolHomeAreaPolicy.storedFields(
            toolID: "conductorLength",
            inputs: [
                "R": "250",
                "unit": "mohm",
                "mat": "Aluminum",
                "method": "loop2",
                "T": "68",
            ]
        )
        XCTAssertEqual(mapped["resistance"], "250")
        XCTAssertEqual(mapped["rUnit"], "mohm")
        XCTAssertEqual(mapped["preset"], ConductorLengthMaterial.aluminum.rawValue)
        XCTAssertEqual(mapped["method"], "loop2")
        XCTAssertEqual(mapped["temp"], "68")
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "conductorLength"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "conductorLength"), .jobsite)
    }
}
