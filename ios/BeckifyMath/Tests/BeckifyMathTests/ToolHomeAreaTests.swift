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
            "voltageDrop", "wireAmpacity", "conductorCost", "conductorLength", "conduitFill", "equipmentGround", "transformer",
            "motorFLA", "power", "threePhasePower", "powerWizard", "receptacleSelector",
            "circularMils", "loadFactors", "shortCircuit",
            "motorSpeed", "isLoopVerifier", "signalScaling", "modbusAddress",
            "plcTimer", "rackCurrent", "powerFactor", "batteryBank",
            "tapChanger", "harmonicsTHD", "upsSizing", "motorNameplate",
            "motorNameplateOCR", "necCircuit",
            "controlSystems", "controlStrategies", "phasorDiagram", "phasorImpedance",
        ]
        for id in field {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
        }
    }

    func testHeuristicToolkitBasicsAndBench() {
        let toolkit = [
            "ohmsLaw", "voltageDivider", "seriesParallel", "resistorColor",
            "ledRC", "frequencyWave", "unitConverter", "timer555",
            "reactance", "electronicsLab", "numberBase",
            "fiberLink", "gaussianBeam", "transientCircuit", "diodeIV", "rfLink",
            "heaterDesign",
            "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
            "statistics",
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

    func testAnalogToolsAreToolkitElectronics() {
        for id in ["analogWorkbench", "noiseSNR", "linearRegulator", "instrumentationAmp", "adcDac"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .electronics, id)
        }
    }

    func testControlSystemsIsFieldControls() {
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "controlSystems"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "controlSystems"), .controls)
    }

    func testFacilityPowerStaysFieldPower() {
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "solarDesign"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "solarDesign"), .power)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "motorNameplate"), .motors)
        let power = [
            "power", "threePhasePower", "powerWizard", "transformer", "powerFactor", "batteryBank",
            "solarDesign", "tapChanger", "harmonicsTHD", "upsSizing",
        ]
        for id in power {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .power, id)
        }
    }

    func testEbikeAndNickelStripAreToolkitBuild() {
        for id in ["eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip", "heaterDesign"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .build, id)
        }
    }

    func testCoilAndFieldDesignLivesWithMagnetics() {
        for id in ["magneticsLab", "emFields", "magneticCircuit", "solenoidDesign", "empEmc"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .magnetics, id)
        }
    }

    func testCrewTalkAndPaperworkAreFieldCrew() {
        for id in ["spanishTranslator", "panelDirectory", "loadWorksheet", "cableSchedule", "referenceLibrary"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .crew, id)
        }
        XCTAssertEqual(ToolShelfKind.crew.homeArea, .field)
    }

    func testNECCircuitStaysFieldJobsite() {
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "necCircuit"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "necCircuit"), .jobsite)
    }

    func testPrimaryJobsiteShelfMembership() {
        let jobsite = [
            "voltageDrop", "wireAmpacity", "conduitFill", "equipmentGround",
            "receptacleSelector", "shortCircuit", "loadFactors", "necCircuit",
        ]
        for id in jobsite {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .jobsite, id)
        }
    }

    func testWireAndMotorShelves() {
        for id in ["cableLadder", "flexibleCable", "conductorCost", "conductorLength", "circularMils"] {
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .wiring, id)
        }
        for id in ["motorFLA", "motorNameplate", "motorNameplateOCR", "motorSpeed"] {
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .motors, id)
        }
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "isLoopVerifier"), .controls)
    }

    func testToolkitShelves() {
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "electronicsLab"), .electronics)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "reactance"), .electronics)
        for id in ["rfLink", "fiberLink", "gaussianBeam"] {
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .rfOptics, id)
        }
        for id in ["statistics", "numberBase"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .toolkit, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .math, id)
        }
    }

    func testEveryShelfHasToolsAndNoToolIsListedTwice() {
        var seen = Set<String>()
        for shelf in ToolShelfKind.allCases {
            let ids = ToolHomeAreaPolicy.toolIDs(on: shelf)
            XCTAssertFalse(ids.isEmpty, "\(shelf) is empty")
            for id in ids { XCTAssertTrue(seen.insert(id).inserted, "\(id) is on two shelves") }
        }
        // Every known tool sits on a shelf the policy lists, not on the fallback by accident.
        for id in ToolCalculationPolicy.knownToolIDs {
            XCTAssertTrue(seen.contains(id), "\(id) has no shelf")
        }
    }

    func testShelfSizesStayReadable() {
        for shelf in ToolShelfKind.allCases {
            XCTAssertLessThanOrEqual(ToolHomeAreaPolicy.toolIDs(on: shelf).count, 14, "\(shelf) is too crowded")
        }
    }

    func testFieldControlsStayLoopHelpers() {
        for id in ["signalScaling", "modbusAddress", "plcTimer", "rackCurrent", "isLoopVerifier", "controlSystems", "controlStrategies", "phasorDiagram", "phasorImpedance", "ul508aPanelLab"] {
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
        }
    }

    func testDefaultPinnedSeedsAreJobsiteSet() {
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
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "conductorLength"), .wiring)
    }

    func testConductorLengthRestoreMapsMeasurementQualityAndSnapshotFields() {
        let mapped = ToolHomeAreaPolicy.storedFields(
            toolID: "conductorLength",
            inputs: [
                "tempUnit": "celsius",
                "refTemp": "75",
                "alpha": "0.00393",
                "rho": "10.371",
                "technique": "fourWireKelvin",
                "leadR": "0.002",
                "jumperR": "0.01",
                "qty": "3",
            ]
        )
        XCTAssertEqual(mapped["tempUnit"], "celsius")
        XCTAssertEqual(mapped["refTemp"], "75")
        XCTAssertEqual(mapped["alpha"], "0.00393")
        XCTAssertEqual(mapped["rho"], "10.371")
        XCTAssertEqual(mapped["technique"], "fourWireKelvin")
        XCTAssertEqual(mapped["leadR"], "0.002")
        XCTAssertEqual(mapped["jumperR"], "0.01")
        XCTAssertEqual(mapped["qty"], "3")
    }
}
