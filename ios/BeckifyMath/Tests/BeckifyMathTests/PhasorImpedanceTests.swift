import XCTest
@testable import BeckifyMath

final class PhasorImpedanceTests: XCTestCase {

    private let hz = 60.0

    func testAngleWrapsIntoOpenClosedRange() {
        XCTAssertEqual(PhasorImpedance.wrapDegrees(0), 0, accuracy: 1e-9)
        XCTAssertEqual(PhasorImpedance.wrapDegrees(180), 180, accuracy: 1e-9)
        XCTAssertEqual(PhasorImpedance.wrapDegrees(-180), 180, accuracy: 1e-9)
        XCTAssertEqual(PhasorImpedance.wrapDegrees(190), -170, accuracy: 1e-9)
        XCTAssertEqual(PhasorImpedance.wrapDegrees(-190), 170, accuracy: 1e-9)
        XCTAssertEqual(PhasorImpedance.wrapDegrees(360), 0, accuracy: 1e-9)
        XCTAssertEqual(PhasorImpedance.wrapDegrees(540), 180, accuracy: 1e-9)
    }

    func testCosineAndSineMapToPeakPhasors() throws {
        let cosine = try PhasorImpedance.makeSinusoid(peak: 10, hertz: hz, phaseDegrees: 30, basis: .cosine)
        let cosinePhasor = cosine.peakPhasor
        XCTAssertEqual(cosinePhasor.magnitude, 10, accuracy: 1e-9)
        XCTAssertEqual(cosinePhasor.angleDegrees, 30, accuracy: 1e-9)
        XCTAssertEqual(cosinePhasor.real, 10 * cos(30 * .pi / 180), accuracy: 1e-9)
        XCTAssertEqual(cosinePhasor.imaginary, 10 * sin(30 * .pi / 180), accuracy: 1e-9)

        let sine = try PhasorImpedance.makeSinusoid(peak: 10, hertz: hz, phaseDegrees: 30, basis: .sine)
        XCTAssertEqual(sine.peakPhasor.magnitude, 10, accuracy: 1e-9)
        XCTAssertEqual(sine.peakPhasor.angleDegrees, -60, accuracy: 1e-6)
        XCTAssertEqual(sine.value(at: 0), 10 * sin(30 * .pi / 180), accuracy: 1e-9)
        XCTAssertEqual(cosine.value(at: 0), 10 * cos(30 * .pi / 180), accuracy: 1e-9)
    }

    func testRectangularPolarAndExponentialRoundTrip() throws {
        let rectangular = PhasorImpedance.ComplexAmplitude(real: 3, imaginary: 4)
        XCTAssertEqual(rectangular.magnitude, 5, accuracy: 1e-12)
        XCTAssertEqual(rectangular.angleDegrees, atan2(4, 3) * 180 / .pi, accuracy: 1e-9)

        let polar = PhasorImpedance.ComplexAmplitude(magnitude: rectangular.magnitude, angleDegrees: rectangular.angleDegrees)
        XCTAssertEqual(polar.real, 3, accuracy: 1e-9)
        XCTAssertEqual(polar.imaginary, 4, accuracy: 1e-9)

        let rebuilt = try PhasorImpedance.sinusoid(from: polar, hertz: 50, basis: .cosine)
        XCTAssertEqual(rebuilt.peakPhasor.real, polar.real, accuracy: 1e-9)
        XCTAssertEqual(rebuilt.peakPhasor.imaginary, polar.imaginary, accuracy: 1e-9)

        let asSine = try PhasorImpedance.sinusoid(from: polar, hertz: 50, basis: .sine)
        XCTAssertEqual(asSine.peakPhasor.angleDegrees, polar.angleDegrees, accuracy: 1e-6)
        XCTAssertEqual(asSine.phaseDegrees, polar.angleDegrees + 90, accuracy: 1e-6)
    }

    func testRMSKeepsTheAngle() throws {
        let wave = try PhasorImpedance.makeSinusoid(peak: 10, hertz: hz, phaseDegrees: -20, basis: .cosine)
        XCTAssertEqual(wave.rmsPhasor.magnitude, 10 / sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(wave.rmsPhasor.angleDegrees, -20, accuracy: 1e-9)
    }

    func testLeadLagAndTimeShift() throws {
        let leading = try PhasorImpedance.makeSinusoid(peak: 120, hertz: hz, phaseDegrees: 30, basis: .cosine)
        let reference = try PhasorImpedance.makeSinusoid(peak: 80, hertz: hz, phaseDegrees: 0, basis: .cosine)
        let lead = try PhasorImpedance.leadLag(first: leading, firstName: "A", second: reference, secondName: "B")
        XCTAssertEqual(lead.relation, .leads)
        XCTAssertEqual(lead.deltaDegrees, 30, accuracy: 1e-9)
        XCTAssertEqual(lead.earlierBySeconds, 30 / 360 / hz, accuracy: 1e-12)

        let lag = try PhasorImpedance.leadLag(first: reference, firstName: "B", second: leading, secondName: "A")
        XCTAssertEqual(lag.relation, .lags)
        XCTAssertEqual(lag.deltaDegrees, -30, accuracy: 1e-9)

        let matched = try PhasorImpedance.leadLag(first: reference, firstName: "A", second: reference, secondName: "B")
        XCTAssertEqual(matched.relation, .inPhase)
        XCTAssertEqual(matched.deltaDegrees, 0, accuracy: 1e-12)
        XCTAssertEqual(matched.earlierBySeconds, 0, accuracy: 1e-12)
    }

    func testSineLagsCosineByNinetyDegrees() throws {
        let sine = try PhasorImpedance.makeSinusoid(peak: 1, hertz: 50, phaseDegrees: 0, basis: .sine)
        let cosine = try PhasorImpedance.makeSinusoid(peak: 1, hertz: 50, phaseDegrees: 0, basis: .cosine)
        let reading = try PhasorImpedance.leadLag(first: sine, firstName: "Sine", second: cosine, secondName: "Cosine")
        XCTAssertEqual(reading.relation, .lags)
        XCTAssertEqual(reading.deltaDegrees, -90, accuracy: 1e-6)
    }

    func testLeadLagRejectsTwoFrequencies() throws {
        let a = try PhasorImpedance.makeSinusoid(peak: 1, hertz: 60, phaseDegrees: 0, basis: .cosine)
        let b = try PhasorImpedance.makeSinusoid(peak: 1, hertz: 50, phaseDegrees: 0, basis: .cosine)
        XCTAssertThrowsError(try PhasorImpedance.leadLag(first: a, firstName: "A", second: b, secondName: "B"))
    }

    func testComplexArithmetic() {
        let left = PhasorImpedance.ComplexAmplitude(real: 3, imaginary: 4)
        let right = PhasorImpedance.ComplexAmplitude(real: 1, imaginary: -2)
        let sum = left + right
        XCTAssertEqual(sum.real, 4, accuracy: 1e-12)
        XCTAssertEqual(sum.imaginary, 2, accuracy: 1e-12)
        let product = left * PhasorImpedance.ComplexAmplitude(real: 0, imaginary: 1)
        XCTAssertEqual(product.real, -4, accuracy: 1e-12)
        XCTAssertEqual(product.imaginary, 3, accuracy: 1e-12)
        let quotient = left / left
        XCTAssertEqual(quotient?.real ?? 0, 1, accuracy: 1e-12)
        XCTAssertEqual(quotient?.imaginary ?? 1, 0, accuracy: 1e-12)
        XCTAssertNil(left / PhasorImpedance.ComplexAmplitude(real: 0, imaginary: 0))
        XCTAssertEqual(left.conjugate.imaginary, -4, accuracy: 1e-12)
    }

    func testResistorInductorAndCapacitorLaws() throws {
        let voltage = PhasorImpedance.ComplexAmplitude(magnitude: 20, angleDegrees: 0)
        let resistor = try PhasorImpedance.element(kind: .resistor, value: 10, hertz: hz, voltage: voltage)
        XCTAssertEqual(resistor.impedance.real, 10, accuracy: 1e-12)
        XCTAssertEqual(resistor.impedance.imaginary, 0, accuracy: 1e-12)
        XCTAssertEqual(resistor.current.magnitude, 2, accuracy: 1e-9)
        XCTAssertEqual(resistor.voltageLeadsCurrentDegrees, 0, accuracy: 1e-6)
        XCTAssertEqual(resistor.atDC, .unchanged)
        XCTAssertEqual(resistor.atHighFrequency, .unchanged)

        let inductor = try PhasorImpedance.element(kind: .inductor, value: 0.2, hertz: 50, voltage: voltage)
        let expectedXL = 2 * Double.pi * 50 * 0.2
        XCTAssertEqual(inductor.impedance.imaginary, expectedXL, accuracy: 1e-9)
        XCTAssertEqual(inductor.impedance.real, 0, accuracy: 1e-9)
        XCTAssertEqual(inductor.voltageLeadsCurrentDegrees, 90, accuracy: 1e-6)
        XCTAssertEqual(inductor.atDC, .short)
        XCTAssertEqual(inductor.atHighFrequency, .open)

        let capacitor = try PhasorImpedance.element(kind: .capacitor, value: 100e-6, hertz: hz, voltage: voltage)
        let expectedXC = -1 / (2 * Double.pi * hz * 100e-6)
        XCTAssertEqual(capacitor.impedance.imaginary, expectedXC, accuracy: 1e-6)
        XCTAssertEqual(capacitor.voltageLeadsCurrentDegrees, -90, accuracy: 1e-6)
        XCTAssertEqual(capacitor.atDC, .open)
        XCTAssertEqual(capacitor.atHighFrequency, .short)
        XCTAssertEqual(capacitor.current.angleDegrees, 90, accuracy: 1e-6)
    }

    func testInductorShortsAtDCAndCapacitorShortsAtHighFrequency() throws {
        let low = try PhasorImpedance.impedance(kind: .inductor, value: 1, hertz: 1e-6)
        let high = try PhasorImpedance.impedance(kind: .inductor, value: 1, hertz: 1e6)
        XCTAssertLessThan(low.magnitude, 1e-4)
        XCTAssertGreaterThan(high.magnitude, 1e6)
        XCTAssertGreaterThan(high.magnitude / low.magnitude, 1e9)

        let open = try PhasorImpedance.impedance(kind: .capacitor, value: 1e-6, hertz: 1e-3)
        let shunt = try PhasorImpedance.impedance(kind: .capacitor, value: 1e-6, hertz: 1e6)
        XCTAssertGreaterThan(open.magnitude, 1e8)
        XCTAssertLessThan(shunt.magnitude, 1)
        XCTAssertLessThan(shunt.magnitude, open.magnitude / 1e8)
    }

    func testImpedanceAndAdmittance() throws {
        let omega = 2 * Double.pi * hz
        let voltage = PhasorImpedance.ComplexAmplitude(magnitude: 5, angleDegrees: 0)
        let lagging = try PhasorImpedance.series(
            resistance: 3,
            inductanceHenries: 4 / omega,
            capacitanceFarads: nil,
            hertz: hz,
            voltage: voltage
        )
        XCTAssertEqual(lagging.impedance.real, 3, accuracy: 1e-9)
        XCTAssertEqual(lagging.impedance.imaginary, 4, accuracy: 1e-9)
        XCTAssertEqual(lagging.impedance.magnitude, 5, accuracy: 1e-9)
        XCTAssertEqual(lagging.admittance.real, 0.12, accuracy: 1e-9)
        XCTAssertEqual(lagging.admittance.imaginary, -0.16, accuracy: 1e-9)
        XCTAssertEqual(lagging.conductance, 3 / 25, accuracy: 1e-12)
        XCTAssertEqual(lagging.susceptance, -4 / 25, accuracy: 1e-12)
        XCTAssertEqual(lagging.character, .lagging)
        XCTAssertEqual(lagging.current.magnitude, 1, accuracy: 1e-9)
        XCTAssertEqual(lagging.current.angleDegrees, -atan2(4, 3) * 180 / .pi, accuracy: 1e-6)

        let leading = try PhasorImpedance.series(
            resistance: 3,
            inductanceHenries: nil,
            capacitanceFarads: 1 / (omega * 4),
            hertz: hz,
            voltage: voltage
        )
        XCTAssertEqual(leading.netReactance, -4, accuracy: 1e-8)
        XCTAssertEqual(leading.character, .leading)
        XCTAssertEqual(leading.susceptance, 0.16, accuracy: 1e-8)
        XCTAssertGreaterThan(leading.current.angleDegrees, 0)

        let y = PhasorImpedance.admittance(of: PhasorImpedance.ComplexAmplitude(real: 3, imaginary: 4))
        XCTAssertEqual(y?.real ?? 0, 0.12, accuracy: 1e-12)
        XCTAssertEqual(y?.imaginary ?? 0, -0.16, accuracy: 1e-12)
    }

    func testSeriesResonanceCancelsReactance() throws {
        let f = 50.0
        let inductance = 0.1
        let omega = 2 * Double.pi * f
        let capacitance = 1 / (omega * omega * inductance)
        let result = try PhasorImpedance.series(
            resistance: 10,
            inductanceHenries: inductance,
            capacitanceFarads: capacitance,
            hertz: f,
            voltage: PhasorImpedance.ComplexAmplitude(magnitude: 10, angleDegrees: 15)
        )
        XCTAssertEqual(result.netReactance, 0, accuracy: 1e-6)
        XCTAssertEqual(result.character, .resistive)
        XCTAssertEqual(result.impedance.magnitude, 10, accuracy: 1e-6)
        XCTAssertEqual(result.current.angleDegrees, 15, accuracy: 1e-4)
        XCTAssertEqual(result.admittance.real, 0.1, accuracy: 1e-6)
        XCTAssertEqual(result.admittance.imaginary, 0, accuracy: 1e-6)
    }

    func testShortImpedanceIsRejected() {
        XCTAssertThrowsError(
            try PhasorImpedance.series(
                resistance: 0,
                inductanceHenries: nil,
                capacitanceFarads: nil,
                hertz: hz,
                voltage: PhasorImpedance.ComplexAmplitude(magnitude: 1, angleDegrees: 0)
            )
        )
    }

    func testSweepShowsInductiveRiseAndCapacitiveFall() {
        let points = PhasorImpedance.sweep(
            resistance: 10,
            inductanceHenries: 0.05,
            capacitanceFarads: 100e-6,
            aroundHertz: hz,
            factor: 8,
            samples: 41
        )
        XCTAssertEqual(points.count, 41)
        XCTAssertLessThan(points.first?.inductiveReactance ?? 1, points.last?.inductiveReactance ?? 0)
        XCTAssertGreaterThan(abs(points.first?.capacitiveReactance ?? 0), abs(points.last?.capacitiveReactance ?? 1))
        XCTAssertTrue(points.allSatisfy { $0.hertz > 0 && $0.impedanceMagnitude.isFinite })
        let nearest = points.min { abs($0.hertz - hz) < abs($1.hertz - hz) }
        XCTAssertNotNil(nearest)
        XCTAssertEqual(nearest?.hertz ?? 0, hz, accuracy: hz * 0.2)
    }

    func testWaveformSamplesAndRotatingProjection() throws {
        let cosine = try PhasorImpedance.makeSinusoid(peak: 4, hertz: 50, phaseDegrees: 0, basis: .cosine)
        XCTAssertEqual(cosine.value(at: 0), 4, accuracy: 1e-12)
        XCTAssertEqual(cosine.value(at: 0.005), 0, accuracy: 1e-9)
        XCTAssertEqual(cosine.value(at: 0.01), -4, accuracy: 1e-9)
        XCTAssertEqual(PhasorImpedance.positivePeakTime(cosine), 0, accuracy: 1e-12)

        let sine = try PhasorImpedance.makeSinusoid(peak: 4, hertz: 50, phaseDegrees: 0, basis: .sine)
        XCTAssertEqual(sine.value(at: 0), 0, accuracy: 1e-12)
        XCTAssertEqual(PhasorImpedance.positivePeakTime(sine), 0.005, accuracy: 1e-12)

        let traces = try PhasorImpedance.traces([
            (name: "V", sinusoid: cosine, unit: "V"),
            (name: "I", sinusoid: sine, unit: "A"),
        ], cycles: 2, samples: 21)
        XCTAssertEqual(traces.count, 2)
        XCTAssertEqual(traces[0].unit, "V")
        XCTAssertEqual(traces[1].unit, "A")
        XCTAssertEqual(traces[0].samples.first?.value ?? 0, 4, accuracy: 1e-9)
        XCTAssertEqual(traces[0].samples.last?.time ?? 0, 2 / 50, accuracy: 1e-12)
        XCTAssertEqual(traces[0].positivePeak, 4, accuracy: 1e-12)
        XCTAssertEqual(traces[0].value(at: 0), 4, accuracy: 1e-9)
        XCTAssertEqual(traces[0].value(at: 0.005), 0, accuracy: 1e-6)

        let time = 0.003
        XCTAssertEqual(
            PhasorImpedance.instantaneous(cosine.peakPhasor, hertz: 50, time: time),
            cosine.value(at: time),
            accuracy: 1e-9
        )
        XCTAssertEqual(
            PhasorImpedance.instantaneous(sine.peakPhasor, hertz: 50, time: time),
            sine.value(at: time),
            accuracy: 1e-9
        )
        let spun = PhasorImpedance.rotate(cosine.peakPhasor, hertz: 50, time: 0)
        XCTAssertEqual(spun.angleDegrees, cosine.peakPhasor.angleDegrees, accuracy: 1e-6)
    }

    func testWaveformWindowsKeepVoltsAndAmpsApart() throws {
        let voltage = try PhasorImpedance.makeSinusoid(peak: 10, hertz: 60, phaseDegrees: 0, basis: .cosine)
        let current = try PhasorImpedance.makeSinusoid(peak: 2, hertz: 60, phaseDegrees: -90, basis: .cosine)
        let traces = try PhasorImpedance.traces([
            (name: "V", sinusoid: voltage, unit: "V"),
            (name: "I", sinusoid: current, unit: "A"),
        ])
        let volts = traces.filter { $0.unit == "V" }
        let amps = traces.filter { $0.unit == "A" }
        let time = PhasorImpedance.timeWindow(of: volts + amps)
        XCTAssertEqual(time.start, 0, accuracy: 1e-12)
        XCTAssertEqual(time.end, 2 / 60, accuracy: 1e-12)
        XCTAssertEqual(time.mid, time.end / 2, accuracy: 1e-12)
        XCTAssertEqual(time.fraction(time.start), 0, accuracy: 1e-12)
        XCTAssertEqual(time.fraction(time.end), 1, accuracy: 1e-12)
        XCTAssertEqual(time.fraction(time.mid), 0.5, accuracy: 1e-12)
        XCTAssertEqual(time.value(atFraction: 0.5), time.mid, accuracy: 1e-12)

        let voltWindow = PhasorImpedance.symmetricAmplitudeWindow(of: volts)
        let ampWindow = PhasorImpedance.symmetricAmplitudeWindow(of: amps)
        XCTAssertEqual(voltWindow.mid, 0, accuracy: 1e-12)
        XCTAssertEqual(voltWindow.start, -voltWindow.end, accuracy: 1e-9)
        XCTAssertEqual(voltWindow.end, 10, accuracy: 1e-6)
        XCTAssertEqual(ampWindow.end, 2, accuracy: 1e-6)
        XCTAssertLessThan(ampWindow.end, voltWindow.end)
        XCTAssertEqual(voltWindow.fraction(0), 0.5, accuracy: 1e-12)
        XCTAssertEqual(voltWindow.fraction(voltWindow.end), 1, accuracy: 1e-12)

        let quiet = PhasorImpedance.symmetricAmplitudeWindow(of: [])
        XCTAssertEqual(quiet.mid, 0, accuracy: 1e-12)
        XCTAssertGreaterThan(quiet.end, 0)
    }

    func testNegativePeakAndBlankFrequencyFail() {
        XCTAssertThrowsError(try PhasorImpedance.makeSinusoid(peak: -1, hertz: 60, phaseDegrees: 0, basis: .cosine))
        XCTAssertThrowsError(try PhasorImpedance.makeSinusoid(peak: 1, hertz: 0, phaseDegrees: 0, basis: .sine))
        XCTAssertThrowsError(try PhasorImpedance.impedance(kind: .resistor, value: 0, hertz: 60))
    }
}
