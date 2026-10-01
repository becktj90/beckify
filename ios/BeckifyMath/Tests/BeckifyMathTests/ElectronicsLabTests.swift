import XCTest
@testable import BeckifyMath

final class ElectronicsLabTests: XCTestCase {
    func testDividerMidpointAndCurrent() throws {
        let solved = try ElectronicsLab.solve(
            .voltageDivider,
            unknown: "vout",
            inputs: ["vin": "12", "r1": "10000", "r2": "10000"]
        )
        XCTAssertEqual(solved.quantity("vout") ?? -1, 6, accuracy: 1e-9)
        XCTAssertEqual(solved.node("out")?.value ?? -1, 6, accuracy: 1e-9)
        XCTAssertEqual(solved.branch("series")?.value ?? -1, 12.0 / 20_000, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(solved.notes.count, 4)
        XCTAssertFalse(solved.notes.isEmpty)
    }

    func testDividerSolvesMissingResistor() throws {
        let solved = try ElectronicsLab.solve(
            .voltageDivider,
            unknown: "r2",
            inputs: ["vin": "12", "vout": "6", "r1": "10000"]
        )
        XCTAssertEqual(solved.quantity("r2") ?? -1, 10_000, accuracy: 1e-6)
    }

    func testAstableFrequencyUsesLn2() throws {
        let r1 = 1_000.0
        let r2 = 1_000.0
        let c = 1e-6
        let expected = 1 / (Timer555.ln2 * (r1 + 2 * r2) * c)
        let solved = try ElectronicsLab.solve(
            .astable555,
            unknown: "frequency",
            inputs: ["vcc": "5", "r1": "1000", "r2": "1000", "c": "0.000001"]
        )
        XCTAssertEqual(solved.quantity("frequency") ?? -1, expected, accuracy: 1e-6)
        let fromTimer = try Timer555.astable(r1: r1, r2: r2, capacitance: c, diodeSteering: false)
        XCTAssertEqual(solved.quantity("frequency") ?? -1, fromTimer.frequency, accuracy: 1e-9)

        let back = try ElectronicsLab.solve(
            .astable555,
            unknown: "c",
            inputs: ["vcc": "5", "r1": "1000", "r2": "1000", "frequency": String(expected)]
        )
        XCTAssertEqual(back.quantity("c") ?? -1, c, accuracy: 1e-12)
    }

    func testComplexRectangularToPolarAndBack() throws {
        let polar = try ElectronicsLab.solve(
            .complexConvert,
            unknown: "polar",
            inputs: ["x": "3", "y": "4"]
        )
        XCTAssertEqual(polar.quantity("magnitude") ?? -1, 5, accuracy: 1e-12)
        XCTAssertEqual(polar.quantity("angleDeg") ?? -999, atan2(4, 3) * 180 / .pi, accuracy: 1e-9)

        let rect = try ElectronicsLab.solve(
            .complexConvert,
            unknown: "rect",
            inputs: ["magnitude": "5", "angleDeg": "53.13010235415598"]
        )
        XCTAssertEqual(rect.quantity("x") ?? -1, 3, accuracy: 1e-6)
        XCTAssertEqual(rect.quantity("y") ?? -1, 4, accuracy: 1e-6)
    }

    func testShortedStubEighthWave() throws {
        let solved = try ElectronicsLab.solve(
            .stubCancel,
            unknown: "length",
            inputs: [
                "x": "50", "z0": "50", "f": "300000000", "vf": "1",
                "kind": "shorted", "goal": "present",
            ]
        )
        let expected = 0.125 * 299_792_458.0 / 300_000_000
        XCTAssertEqual(solved.quantity("lengthM") ?? -1, expected, accuracy: 1e-9)
        XCTAssertEqual(solved.quantity("fraction") ?? -1, 0.125, accuracy: 1e-12)
    }

    func testOpenStubPresentingPositiveX() throws {
        let solved = try ElectronicsLab.solve(
            .stubCancel,
            unknown: "length",
            inputs: [
                "x": "50", "z0": "50", "f": "300000000", "vf": "1",
                "kind": "open", "goal": "present",
            ]
        )
        XCTAssertEqual(solved.quantity("fraction") ?? -1, 0.375, accuracy: 1e-12)
    }

    func testLMatchAndQuarterWave() throws {
        let match = try ElectronicsLab.solve(
            .lMatch,
            unknown: "parts",
            inputs: ["rs": "50", "rl": "200", "f": "1000000", "topology": "lowpass"]
        )
        XCTAssertEqual(match.quantity("q") ?? -1, sqrt(3), accuracy: 1e-9)
        XCTAssertEqual(match.quantity("xs") ?? -1, 50 * sqrt(3), accuracy: 1e-6)

        let line = try ElectronicsLab.solve(
            .quarterWave,
            unknown: "z0",
            inputs: ["zLoad": "200", "zIn": "50", "f": "100000000", "vf": "1"]
        )
        XCTAssertEqual(line.quantity("z0") ?? -1, 100, accuracy: 1e-9)
        XCTAssertEqual(line.quantity("lengthM") ?? -1, 299_792_458.0 / 400_000_000, accuracy: 1e-6)
    }

    func testEveryDefaultCircuitSolvesWithASchematic() throws {
        for info in ElectronicsLab.catalog {
            let solved = try ElectronicsLab.solve(info.id, unknown: info.defaultUnknown, inputs: info.defaults)
            XCTAssertFalse(solved.elements.isEmpty, info.title)
            XCTAssertFalse(solved.nodes.isEmpty, info.title)
            XCTAssertFalse(solved.notes.isEmpty, info.title)
            XCTAssertLessThanOrEqual(solved.notes.count, 4, info.title)
            XCTAssertLessThanOrEqual(solved.steps.count, 6, info.title)
            XCTAssertFalse(solved.headline.isEmpty, info.title)
            XCTAssertFalse(solved.io.expression.isEmpty, info.title)
            XCTAssertFalse(solved.io.plots.isEmpty, info.title)
            XCTAssertGreaterThanOrEqual(solved.io.plots[0].series.first?.points.count ?? 0, 2, info.title)
            let fields = ElectronicsLab.fields(for: info.id, unknown: info.defaultUnknown)
            XCTAssertFalse(fields.isEmpty, info.title)
        }
        XCTAssertEqual(ElectronicsLab.catalog.count, ElectronicsCircuit.allCases.count)
    }

    func testSevenSegmentEightLightsEverySegment() throws {
        let solved = try ElectronicsLab.solve(
            .sevenSegment,
            unknown: "map",
            inputs: ["digit": "8", "vcc": "5", "vf": "2", "r": "330"]
        )
        XCTAssertEqual(solved.quantity("count") ?? -1, 7, accuracy: 0.1)
        let each = 3.0 / 330
        XCTAssertEqual(solved.quantity("iseg") ?? -1, each, accuracy: 1e-12)
        XCTAssertEqual(solved.quantity("itotal") ?? -1, 7 * each, accuracy: 1e-12)
        XCTAssertEqual(solved.io.transferKind, .none)
    }

    func testDividerTransferAndSinePeak() throws {
        let solved = try ElectronicsLab.solve(
            .voltageDivider,
            unknown: "vout",
            inputs: ["vin": "12", "r1": "10000", "r2": "10000"]
        )
        XCTAssertEqual(solved.io.transferKind, .closedForm)
        XCTAssertEqual(LabSignals.dividerRatio(r1: 10_000, r2: 10_000), 0.5, accuracy: 1e-12)
        let vout = solved.io.plots[0].series.first { $0.id == "vout" }
        let peak = vout?.points.map(\.y).max() ?? -1
        XCTAssertEqual(peak, 6, accuracy: 1e-6)
        let atQuarter = LabSignals.sineValue(frequency: 1_000, time: 0.00025, amplitude: 12)
        XCTAssertEqual(atQuarter * 0.5, 6, accuracy: 1e-9)
    }

    func testFirstOrderAndIntegratorAndRLCFormulas() {
        let low = LabSignals.lowpassPhasor(frequency: 1_000, cutoff: 1_000)
        XCTAssertEqual(low.magnitude, 1 / sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(low.phaseDeg, -45, accuracy: 1e-9)
        let high = LabSignals.highpassPhasor(frequency: 1_000, cutoff: 1_000)
        XCTAssertEqual(high.magnitude, 1 / sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(high.phaseDeg, 45, accuracy: 1e-9)
        let r = 10_000.0
        let c = 1e-7
        let unity = 1 / (2 * .pi * r * c)
        XCTAssertEqual(LabSignals.integratorMagnitude(frequency: unity, resistance: r, capacitance: c), 1, accuracy: 1e-9)
        let l = 1e-3
        let f0 = 1 / (2 * .pi * sqrt(l * c))
        XCTAssertEqual(
            LabSignals.seriesRLCCurrentGain(resistance: 50, inductance: l, capacitance: c, frequency: f0),
            1 / 50,
            accuracy: 1e-6
        )
    }

    func testShortedStubReactanceAndNonlinearKinds() throws {
        XCTAssertEqual(LabSignals.shortedStubReactance(z0: 50, lengthOverLambda: 0.125), 50, accuracy: 1e-9)
        let timer = try ElectronicsLab.solve(
            .astable555,
            unknown: "frequency",
            inputs: ["vcc": "5", "r1": "1000", "r2": "1000", "c": "0.000001"]
        )
        XCTAssertEqual(timer.io.transferKind, .none)
        XCTAssertTrue(timer.io.expression.contains("No linear"))
        let bias = try ElectronicsLab.solve(
            .bjtBias,
            unknown: ElectronicsLab.info(.bjtBias).defaultUnknown,
            inputs: ElectronicsLab.info(.bjtBias).defaults
        )
        XCTAssertEqual(bias.io.transferKind, .operatingPoint)
        XCTAssertFalse(bias.io.plots.isEmpty)
    }

    func testEngineeringSuffixesSolveTheBench() throws {
        let divider = try ElectronicsLab.solve(
            .voltageDivider,
            unknown: "vout",
            inputs: ["vin": "12", "r1": "10k", "r2": "10k"]
        )
        XCTAssertEqual(divider.quantity("vout") ?? -1, 6, accuracy: 1e-6)

        let filter = try ElectronicsLab.solve(
            .firstOrderFilter,
            unknown: "cutoff",
            inputs: ["kind": "lowpass", "r": "10k", "c": "10n", "f": "1k"]
        )
        let expected = 1 / (2 * .pi * 10_000 * 10e-9)
        XCTAssertEqual(filter.quantity("fc") ?? -1, expected, accuracy: 1e-3)
    }

    func testClosedFormTransfersAreTypeset() throws {
        let divider = try ElectronicsLab.solve(
            .voltageDivider,
            unknown: "vout",
            inputs: ["vin": "12", "r1": "10000", "r2": "10000"]
        )
        let dividerTex = try XCTUnwrap(divider.io.expressionTeX)
        XCTAssertEqual(dividerTex, #"H = \frac{V_{out}}{V_{in}} = \frac{R_2}{R_1 + R_2}"#)
        XCTAssertEqual(divider.io.evaluated, "0.5")
        let dividerMath = try XCTUnwrap(LabMath.parse(dividerTex))
        XCTAssertEqual(dividerMath.fractionCount, 2)
        XCTAssertTrue(divider.io.expression.contains("0.5"))

        let low = try ElectronicsLab.solve(
            .firstOrderFilter,
            unknown: "cutoff",
            inputs: ElectronicsLab.info(.firstOrderFilter).defaults
        )
        XCTAssertEqual(low.io.expressionTeX, #"H(s) = \frac{1}{1 + sRC}"#)
        XCTAssertEqual(LabMath.parse(low.io.expressionTeX ?? "")?.fractionCount, 1)

        let high = try ElectronicsLab.solve(
            .firstOrderFilter,
            unknown: "cutoff",
            inputs: ["kind": "highpass", "r": "10000", "c": "0.00000001", "f": "1000"]
        )
        XCTAssertEqual(high.io.expressionTeX, #"H(s) = \frac{sRC}{1 + sRC}"#)

        let integrator = try ElectronicsLab.solve(
            .integrator,
            unknown: ElectronicsLab.info(.integrator).defaultUnknown,
            inputs: ElectronicsLab.info(.integrator).defaults
        )
        XCTAssertEqual(integrator.io.expressionTeX, #"H(s) = -\frac{1}{sRC}"#)
        XCTAssertEqual(LabMath.parse(integrator.io.expressionTeX ?? "")?.fractionCount, 1)

        let amp = try ElectronicsLab.solve(
            .invertingAmp,
            unknown: "gain",
            inputs: ElectronicsLab.info(.invertingAmp).defaults
        )
        XCTAssertEqual(amp.io.expressionTeX, #"H = -\frac{R_f}{R_{in}}"#)
        XCTAssertFalse(amp.io.evaluated?.isEmpty ?? true)

        for info in ElectronicsLab.catalog {
            let solved = try ElectronicsLab.solve(info.id, unknown: info.defaultUnknown, inputs: info.defaults)
            if solved.io.transferKind == .closedForm {
                let tex = try XCTUnwrap(solved.io.expressionTeX, info.title)
                XCTAssertNotNil(LabMath.parse(tex), "\(info.title): \(tex)")
            } else if solved.io.transferKind == .none {
                XCTAssertNil(solved.io.expressionTeX, info.title)
            }
            if let tex = solved.io.expressionTeX {
                XCTAssertNotNil(LabMath.parse(tex), "\(info.title): \(tex)")
            }
            XCTAssertFalse(solved.io.expression.isEmpty, info.title)
        }
    }

    func testSourceSwitchesBetweenDCAndAC() throws {
        let acRect = try ElectronicsLab.solve(
            .halfWave,
            unknown: "report",
            inputs: ElectronicsLab.info(.halfWave).defaults
        )
        XCTAssertEqual(acRect.quantity("vpk") ?? -1, 12 * sqrt(2) - 0.7, accuracy: 1e-9)
        XCTAssertEqual(acRect.quantity("ac") ?? -1, 1, accuracy: 0.1)
        let acMark = try XCTUnwrap(acRect.elements.first { $0.part == .voltageSource })
        XCTAssertEqual(acMark.flags, LabSourceSpeech.acSineFlag)
        XCTAssertTrue(acMark.detail.contains("Vrms"))
        let acSpoken = LabSourceSpeech.schematicSummary(acRect.elements)
        XCTAssertTrue(acSpoken.contains("AC sine"))
        XCTAssertTrue(acSpoken.contains("Vrms"))
        XCTAssertEqual(
            LabSourceSpeech.pairedAmplitude(id: "vrms", raw: "12"),
            "Peak \(LabKit.eng(12 * sqrt(2))) volts, from \(LabKit.eng(12)) volts RMS"
        )

        var five = ElectronicsLab.info(.halfWave).defaults
        five["vrms"] = "5"
        let custom = try ElectronicsLab.solve(.halfWave, unknown: "report", inputs: five)
        XCTAssertEqual(custom.quantity("vpk") ?? -1, 5 * sqrt(2) - 0.7, accuracy: 1e-9)

        var dcRectInputs = ElectronicsLab.info(.halfWave).defaults
        dcRectInputs["source"] = "dc"
        dcRectInputs["vdc"] = "12"
        let dcRect = try ElectronicsLab.solve(.halfWave, unknown: "report", inputs: dcRectInputs)
        XCTAssertEqual(dcRect.quantity("vdcCap") ?? -1, 11.3, accuracy: 1e-9)
        XCTAssertEqual(dcRect.quantity("ripple") ?? -1, 0, accuracy: 1e-12)
        XCTAssertEqual(dcRect.quantity("ac") ?? -1, 0, accuracy: 0.1)
        XCTAssertNil(dcRect.quantity("vrms"))
        let dcMark = try XCTUnwrap(dcRect.elements.first { $0.part == .voltageSource })
        XCTAssertEqual(dcMark.flags, 0)
        XCTAssertTrue(dcMark.detail.contains("Vdc"))
        let dcSpoken = LabSourceSpeech.schematicSummary(dcRect.elements)
        XCTAssertTrue(dcSpoken.contains("DC source"))
        XCTAssertFalse(dcSpoken.contains("AC sine"))
        let divider = try ElectronicsLab.solve(
            .voltageDivider,
            unknown: "vout",
            inputs: ElectronicsLab.info(.voltageDivider).defaults
        )
        XCTAssertFalse(divider.elements.contains { $0.flags & LabSourceSpeech.acSineFlag != 0 })
        let dcBoard = try XCTUnwrap(BreadboardLayouts.make(dcRect))
        XCTAssertTrue(dcBoard.supplies.contains { $0.label.contains("Vdc") })
        XCTAssertThrowsError(try ElectronicsLab.solve(.halfWave, unknown: "c", inputs: dcRectInputs))

        let acFields = ElectronicsLab.fields(for: .halfWave, unknown: "report", inputs: ["source": "ac"]).map(\.id)
        XCTAssertTrue(acFields.contains("vrms"))
        XCTAssertTrue(acFields.contains("f"))
        XCTAssertFalse(acFields.contains("vdc"))
        let dcFields = ElectronicsLab.fields(for: .halfWave, unknown: "report", inputs: ["source": "dc"]).map(\.id)
        XCTAssertTrue(dcFields.contains("vdc"))
        XCTAssertFalse(dcFields.contains("vrms"))
        XCTAssertFalse(dcFields.contains("f"))
        let series = ElectronicsLab.fields(for: .seriesResistors, unknown: "current").map(\.id)
        XCTAssertFalse(series.contains("source"))

        var filt = ElectronicsLab.info(.firstOrderFilter).defaults
        filt["source"] = "dc"
        filt["vdc"] = "5"
        let lowDC = try ElectronicsLab.solve(.firstOrderFilter, unknown: "cutoff", inputs: filt)
        XCTAssertEqual(lowDC.node("out")?.value ?? -1, 5, accuracy: 1e-9)
        XCTAssertEqual(lowDC.branch("i")?.value ?? -1, 0, accuracy: 1e-12)
        XCTAssertEqual(lowDC.elements.first { $0.part == .voltageSource }?.flags, 0)
        XCTAssertTrue(LabSourceSpeech.schematicSummary(lowDC.elements).contains("Vdc"))
        filt["kind"] = "highpass"
        let highDC = try ElectronicsLab.solve(.firstOrderFilter, unknown: "cutoff", inputs: filt)
        XCTAssertEqual(highDC.node("out")?.value ?? -1, 0, accuracy: 1e-12)

        let r = 10_000.0
        let c = 1e-8
        let fc = 1 / (2 * .pi * r * c)
        var acFilt = ElectronicsLab.info(.firstOrderFilter).defaults
        acFilt["source"] = "ac"
        acFilt["vp"] = "2"
        acFilt["f"] = String(fc)
        let acLow = try ElectronicsLab.solve(.firstOrderFilter, unknown: "cutoff", inputs: acFilt)
        XCTAssertEqual(acLow.node("out")?.value ?? -1, 2 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(acLow.io.expressionTeX, #"H(s) = \frac{1}{1 + sRC}"#)
        XCTAssertEqual(acLow.elements.first { $0.part == .voltageSource }?.flags, LabSourceSpeech.acSineFlag)
        XCTAssertTrue(LabSourceSpeech.schematicSummary(acLow.elements).contains("Vpk"))
        XCTAssertTrue((LabSourceSpeech.pairedAmplitude(id: "vp", raw: "2") ?? "").contains("volts peak"))

        var rlc = ElectronicsLab.info(.seriesRLC).defaults
        rlc["source"] = "dc"
        rlc["vdc"] = "5"
        let rlcDC = try ElectronicsLab.solve(.seriesRLC, unknown: "response", inputs: rlc)
        XCTAssertEqual(rlcDC.branch("i")?.value ?? -1, 0, accuracy: 1e-12)
        XCTAssertNil(rlcDC.quantity("zMag"))
        XCTAssertFalse(rlcDC.io.plots.isEmpty)

        let l = 0.001
        let cRLC = 1e-7
        let f0 = 1 / (2 * .pi * sqrt(l * cRLC))
        rlc["source"] = "ac"
        rlc["vp"] = "2"
        rlc["f"] = String(f0)
        let rlcAC = try ElectronicsLab.solve(.seriesRLC, unknown: "response", inputs: rlc)
        XCTAssertEqual(rlcAC.branch("i")?.value ?? -1, 0.2, accuracy: 1e-6)

        var clip = ElectronicsLab.info(.shuntClipper).defaults
        clip["source"] = "dc"
        clip["vdc"] = "5"
        let clipped = try ElectronicsLab.solve(.shuntClipper, unknown: "report", inputs: clip)
        XCTAssertEqual(clipped.quantity("vout") ?? -1, 0.7, accuracy: 1e-9)
        XCTAssertEqual(clipped.quantity("ac") ?? -1, 0, accuracy: 0.1)
        let clipBoard = try XCTUnwrap(BreadboardLayouts.make(clipped))
        XCTAssertTrue(clipBoard.supplies.contains { $0.label.contains("Vdc") })
    }
}
