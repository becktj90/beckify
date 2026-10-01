import SwiftUI
import BeckifyMath

private enum MagneticsScreen: String, CaseIterable, Identifiable {
    case series
    case threeLeg
    case machines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .series: return "Series core"
        case .threeLeg: return "Three-leg core"
        case .machines: return "Machines"
        }
    }

    var blurb: String {
        switch self {
        case .series:
            return "One steel path and an optional gap. Reluctance, flux, inductance, and stored energy."
        case .threeLeg:
            return "Center post and two returns. Flux splits. The gaps usually take the ampere-turns."
        case .machines:
            return "The same gap field on a transformer link, one motor conductor, or one generator conductor."
        }
    }
}

private enum MachineKind: String, CaseIterable, Identifiable {
    case transformer
    case motor
    case generator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transformer: return "Transformer"
        case .motor: return "Motor"
        case .generator: return "Generator"
        }
    }
}

struct MagneticsLabView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.magneticsLab, "screen", default: MagneticsScreen.series.rawValue) private var screenRaw
    @StoredInput(.magneticsLab, "turns", default: "500") private var turns
    @StoredInput(.magneticsLab, "current", default: "0.6") private var current
    @StoredInput(.magneticsLab, "length", default: "0.2") private var length
    @StoredInput(.magneticsLab, "area", default: "1") private var areaCm2
    @StoredInput(.magneticsLab, "muR", default: "2000") private var muR
    @StoredInput(.magneticsLab, "gap", default: "0.5") private var gapMm
    @StoredInput(.magneticsLab, "stack", default: "0.95") private var stacking
    @StoredInput(.magneticsLab, "fringe", default: "1.05") private var fringing
    @StoredInput(.magneticsLab, "cLen", default: "0.08") private var centerLength
    @StoredInput(.magneticsLab, "cArea", default: "4") private var centerArea
    @StoredInput(.magneticsLab, "cGap", default: "0") private var centerGap
    @StoredInput(.magneticsLab, "sLen", default: "0.25") private var sideLength
    @StoredInput(.magneticsLab, "sArea", default: "2") private var sideArea
    @StoredInput(.magneticsLab, "sGap", default: "0.5") private var sideGap
    @StoredInput(.magneticsLab, "rLen", default: "0.25") private var rightLength
    @StoredInput(.magneticsLab, "rArea", default: "2") private var rightArea
    @StoredInput(.magneticsLab, "rGap", default: "0.5") private var rightGap
    @StoredToggle(.magneticsLab, "matchRight", default: true) private var matchRight
    @StoredInput(.magneticsLab, "machine", default: MachineKind.transformer.rawValue) private var machineRaw
    @StoredInput(.magneticsLab, "n2", default: "100") private var secondaryTurns
    @StoredInput(.magneticsLab, "v1", default: "") private var primaryVolts
    @StoredInput(.magneticsLab, "hertz", default: "") private var hertz
    @StoredInput(.magneticsLab, "iWire", default: "10") private var wireCurrent
    @StoredInput(.magneticsLab, "active", default: "5") private var activeCm
    @StoredInput(.magneticsLab, "angle", default: "90") private var angle
    @StoredInput(.magneticsLab, "speed", default: "5") private var speed
    @StoredInput(.magneticsLab, "jobName", default: "Magnetics lab") private var jobName

    private var screen: MagneticsScreen {
        MagneticsScreen(rawValue: screenRaw) ?? .series
    }

    var body: some View {
        ToolScaffold(toolID: .magneticsLab, stickyAnswer: sticky, copyText: sticky) {
            if didOpen {
                detail
            } else {
                hub
            }
        }
    }

    @StoredToggle(.magneticsLab, "open", default: false) private var didOpen

    private var hub: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Core checks and the three machines that move energy through a magnetic field.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(MagneticsScreen.allCases) { item in
                Button {
                    screenRaw = item.rawValue
                    didOpen = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                        Text(item.blurb)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.sm)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("magneticsLab.\(item.rawValue)")
            }
        }
        .accessibilityIdentifier("magneticsLab.hub")
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Button {
                didOpen = false
            } label: {
                Label("All checks", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: Theme.touchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)

            Text(screen.title)
                .font(.title3.weight(.semibold))
            Text(screen.blurb)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            TryExampleButton(title: exampleTitle) { applyExample() }

            switch screen {
            case .series:
                seriesFields
                seriesResult
            case .threeLeg:
                threeLegFields
                threeLegResult
            case .machines:
                seriesFields
                machineFields
                machineResult
            }
        }
    }

    private var seriesFields: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            NumberField(title: "Turns", unit: "", text: $turns, fieldID: "turns")
            NumberField(title: "Current", unit: "A", text: $current, fieldID: "current")
            NumberField(title: "Mean steel length", unit: "m", text: $length, fieldID: "length")
            NumberField(title: "Steel area", unit: "cm²", text: $areaCm2, fieldID: "area")
            NumberField(title: "Relative permeability", unit: "µr", text: $muR, fieldID: "muR")
            NumberField(title: "Air gap", unit: "mm", text: $gapMm, helpText: "Zero is a closed steel path.", fieldID: "gap")
            NumberField(title: "Stacking factor", unit: "", text: $stacking, helpText: "Share of the stack that is steel. 1 if it is solid.", fieldID: "stack")
            NumberField(title: "Gap fringing", unit: "", text: $fringing, helpText: "1 ignores bulge. 1.05 is a modest wider gap face.", fieldID: "fringe")
        }
    }

    private var threeLegFields: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            NumberField(title: "Turns on the center", unit: "", text: $turns, fieldID: "turns")
            NumberField(title: "Current", unit: "A", text: $current, fieldID: "current")
            NumberField(title: "µr", unit: "", text: $muR, fieldID: "muR")
            NumberField(title: "Stacking factor", unit: "", text: $stacking, fieldID: "stack")
            NumberField(title: "Gap fringing", unit: "", text: $fringing, fieldID: "fringe")
            sectionLabel("Center")
            NumberField(title: "Steel length", unit: "m", text: $centerLength, fieldID: "cLen")
            NumberField(title: "Area", unit: "cm²", text: $centerArea, fieldID: "cArea")
            NumberField(title: "Gap", unit: "mm", text: $centerGap, fieldID: "cGap")
            sectionLabel("Left return")
            NumberField(title: "Steel length", unit: "m", text: $sideLength, fieldID: "sLen")
            NumberField(title: "Area", unit: "cm²", text: $sideArea, fieldID: "sArea")
            NumberField(title: "Gap", unit: "mm", text: $sideGap, fieldID: "sGap")
            Toggle("Right matches left", isOn: $matchRight)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            if !matchRight {
                sectionLabel("Right return")
                NumberField(title: "Steel length", unit: "m", text: $rightLength, fieldID: "rLen")
                NumberField(title: "Area", unit: "cm²", text: $rightArea, fieldID: "rArea")
                NumberField(title: "Gap", unit: "mm", text: $rightGap, fieldID: "rGap")
            }
        }
    }

    private var machineFields: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Picker("Machine", selection: $machineRaw) {
                ForEach(MachineKind.allCases) { kind in
                    Text(kind.title).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            switch MachineKind(rawValue: machineRaw) ?? .transformer {
            case .transformer:
                NumberField(title: "Secondary turns", unit: "", text: $secondaryTurns, fieldID: "n2")
                NumberField(title: "Primary voltage", unit: "V", text: $primaryVolts, optional: true, helpText: "Optional. With frequency, shows the sine peak flux for that voltage.", fieldID: "v1")
                NumberField(title: "Frequency", unit: "Hz", text: $hertz, optional: true, fieldID: "hertz")
            case .motor:
                NumberField(title: "Conductor current", unit: "A", text: $wireCurrent, fieldID: "iWire")
                NumberField(title: "Active length", unit: "cm", text: $activeCm, fieldID: "active")
                NumberField(title: "Angle to B", unit: "°", text: $angle, fieldID: "angle")
            case .generator:
                NumberField(title: "Speed", unit: "m/s", text: $speed, fieldID: "speed")
                NumberField(title: "Active length", unit: "cm", text: $activeCm, fieldID: "active")
                NumberField(title: "Angle to B", unit: "°", text: $angle, fieldID: "angle")
            }
        }
    }

    @ViewBuilder
    private var seriesResult: some View {
        if let failure = seriesFailure {
            ErrorText(message: failure)
        } else if let solved = seriesSolution {
            coreBody(solved, diagram: AnyView(MagneticCoreDiagram(
                flux: solved.coilFlux,
                mmf: solved.mmf,
                gapFraction: solved.gapMMFFraction,
                hasGap: solved.drop(named: "Air gap") != nil,
                steelB: solved.drop(named: "Steel")?.fluxDensity ?? 0,
                gapB: solved.drop(named: "Air gap")?.fluxDensity
            )))
        }
    }

    @ViewBuilder
    private var threeLegResult: some View {
        if let failure = threeFailure {
            ErrorText(message: failure)
        } else if let solved = threeSolution {
            coreBody(solved, diagram: AnyView(ThreeLegDiagram(
                coilFlux: solved.coilFlux,
                leftFlux: solved.leftFlux ?? 0,
                rightFlux: solved.rightFlux ?? 0,
                gapFraction: solved.gapMMFFraction
            )))
        }
    }

    @ViewBuilder
    private var machineResult: some View {
        if let failure = seriesFailure {
            ErrorText(message: failure)
        } else if let solved = seriesSolution {
            let density = solved.drop(named: "Air gap")?.fluxDensity ?? solved.drop(named: "Steel")?.fluxDensity ?? 0
            MachineRoleDiagram(role: machineRole, detail: machineDetail(solved, density: density))
            if let machineFailure {
                ErrorText(message: machineFailure)
            } else if let row = machineRow(solved, density: density) {
                ResultCard(copyText: sticky) {
                    ResultRow(label: row.0, value: row.1, emphasis: true, tone: Theme.good)
                    ResultRow(label: "Gap or steel B", value: "\(Format.number(density, digits: 3)) T")
                    ResultRow(label: "Coil flux", value: "\(Format.number(solved.coilFlux * 1e3, digits: 3)) mWb")
                }
            }
            warningList(solved.warnings)
            SaveJobBar(jobName: $jobName, canSave: true) { saveMachine(solved) }
        }
    }

    private func coreBody(_ solved: MagneticsLab.Solution, diagram: AnyView) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            diagram
            ResultCard(copyText: sticky) {
                ResultRow(label: "Reluctance", value: "\(Format.number(solved.equivalentReluctance, digits: 3)) At/Wb", emphasis: true, tone: Theme.good)
                ResultRow(label: "Flux", value: "\(Format.number(solved.coilFlux * 1e3, digits: 4)) mWb")
                ResultRow(label: "MMF", value: "\(Format.number(solved.mmf, digits: 2)) At")
                ResultRow(label: "Inductance", value: "\(Format.number(solved.inductance * 1e3, digits: 3)) mH")
                ResultRow(label: "Stored energy", value: "\(Format.number(solved.energy * 1e3, digits: 3)) mJ")
                ResultRow(label: "Gap share of MMF", value: Format.percent(solved.gapMMFFraction * 100))
                ForEach(solved.drops, id: \.name) { drop in
                    ResultRow(
                        label: drop.name,
                        value: "\(Format.number(drop.fluxDensity, digits: 3)) T"
                    )
                }
            }
            if let left = solved.leftFlux, let right = solved.rightFlux {
                Text("Center \(Format.number(solved.coilFlux * 1e3, digits: 3)) mWb = left \(Format.number(left * 1e3, digits: 3)) + right \(Format.number(right * 1e3, digits: 3)).")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.foreground)
            }
            warningList(solved.warnings)
            Text("µ₀ = 4π×10⁻⁷ H/m. ℜ = ℓ /(µ A). ℱ = NI = ℜ Φ. L = N² / ℜ. W = ½ L I².")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            SaveJobBar(jobName: $jobName, canSave: true) { saveCore(solved) }
        }
    }

    private func warningList(_ warnings: [String]) -> some View {
        ForEach(warnings, id: \.self) { warning in
            Text(warning)
                .font(.footnote)
                .foregroundStyle(Theme.warn)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.TypeRole.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
            .padding(.top, 4)
    }

    private var seriesSolution: MagneticsLab.Solution? {
        try? MagneticsLab.series(
            turns: num(turns),
            current: num(current),
            steelLength: num(length),
            steelArea: cm2(areaCm2),
            relativePermeability: num(muR),
            gapLength: mm(gapMm),
            stackingFactor: num(stacking),
            fringing: num(fringing)
        )
    }

    private var seriesFailure: String? {
        guard seriesSolution == nil else { return nil }
        return message {
            _ = try MagneticsLab.series(
                turns: num(turns),
                current: num(current),
                steelLength: num(length),
                steelArea: cm2(areaCm2),
                relativePermeability: num(muR),
                gapLength: mm(gapMm),
                stackingFactor: num(stacking),
                fringing: num(fringing)
            )
        }
    }

    private var threeSolution: MagneticsLab.Solution? {
        try? MagneticsLab.threeLeg(
            turns: num(turns),
            current: num(current),
            center: leg(centerLength, centerArea, centerGap),
            left: leg(sideLength, sideArea, sideGap),
            right: matchRight ? leg(sideLength, sideArea, sideGap) : leg(rightLength, rightArea, rightGap)
        )
    }

    private var threeFailure: String? {
        guard threeSolution == nil else { return nil }
        do {
            _ = try MagneticsLab.threeLeg(
                turns: num(turns),
                current: num(current),
                center: leg(centerLength, centerArea, centerGap),
                left: leg(sideLength, sideArea, sideGap),
                right: matchRight ? leg(sideLength, sideArea, sideGap) : leg(rightLength, rightArea, rightGap)
            )
            return nil
        } catch let error as CalcError {
            return error.message
        } catch {
            return error.localizedDescription
        }
    }

    private var machineFailure: String? {
        guard let solved = seriesSolution else { return nil }
        let density = solved.drop(named: "Air gap")?.fluxDensity ?? solved.drop(named: "Steel")?.fluxDensity ?? 0
        switch MachineKind(rawValue: machineRaw) ?? .transformer {
        case .transformer:
            return message {
                _ = try MagneticsLab.transformerLink(
                    sharedFlux: solved.coilFlux,
                    primaryTurns: num(turns),
                    secondaryTurns: num(secondaryTurns),
                    primaryRMS: optionalNum(primaryVolts),
                    frequencyHz: optionalNum(hertz)
                )
            }
        case .motor:
            return message {
                _ = try MagneticsLab.conductorForce(
                    current: num(wireCurrent),
                    length: cm(activeCm),
                    fluxDensity: density,
                    angleDegrees: num(angle)
                )
            }
        case .generator:
            return message {
                _ = try MagneticsLab.motionalEMF(
                    fluxDensity: density,
                    length: cm(activeCm),
                    speed: num(speed),
                    angleDegrees: num(angle)
                )
            }
        }
    }

    private func machineRow(_ solved: MagneticsLab.Solution, density: Double) -> (String, String)? {
        switch MachineKind(rawValue: machineRaw) ?? .transformer {
        case .transformer:
            guard let link = try? MagneticsLab.transformerLink(
                sharedFlux: solved.coilFlux,
                primaryTurns: num(turns),
                secondaryTurns: num(secondaryTurns),
                primaryRMS: optionalNum(primaryVolts),
                frequencyHz: optionalNum(hertz)
            ) else { return nil }
            if let peak = link.acPeakFlux {
                return ("AC peak flux", "\(Format.number(peak * 1e3, digits: 3)) mWb")
            }
            return ("Turns ratio N2/N1", Format.number(link.turnsRatio, digits: 3))
        case .motor:
            guard let force = try? MagneticsLab.conductorForce(
                current: num(wireCurrent), length: cm(activeCm), fluxDensity: density, angleDegrees: num(angle)
            ) else { return nil }
            return ("Force", "\(Format.number(force.newtons, digits: 3)) N")
        case .generator:
            guard let emf = try? MagneticsLab.motionalEMF(
                fluxDensity: density, length: cm(activeCm), speed: num(speed), angleDegrees: num(angle)
            ) else { return nil }
            return ("Induced emf", "\(Format.number(emf.volts, digits: 3)) V")
        }
    }

    private func machineDetail(_ solved: MagneticsLab.Solution, density: Double) -> String {
        switch MachineKind(rawValue: machineRaw) ?? .transformer {
        case .transformer:
            return (try? MagneticsLab.transformerLink(
                sharedFlux: solved.coilFlux,
                primaryTurns: num(turns),
                secondaryTurns: num(secondaryTurns),
                primaryRMS: optionalNum(primaryVolts),
                frequencyHz: optionalNum(hertz)
            ).note) ?? "Both windings link the core flux."
        case .motor:
            return (try? MagneticsLab.conductorForce(
                current: num(wireCurrent), length: cm(activeCm), fluxDensity: density, angleDegrees: num(angle)
            ).note) ?? "Force on one conductor."
        case .generator:
            return (try? MagneticsLab.motionalEMF(
                fluxDensity: density, length: cm(activeCm), speed: num(speed), angleDegrees: num(angle)
            ).note) ?? "Emf on one conductor."
        }
    }

    private var machineRole: MachineRoleDiagram.Role {
        switch MachineKind(rawValue: machineRaw) ?? .transformer {
        case .transformer: return .transformer
        case .motor: return .motor
        case .generator: return .generator
        }
    }

    private var sticky: String? {
        switch screen {
        case .series:
            guard let solved = seriesSolution else { return nil }
            return "Φ \(Format.number(solved.coilFlux * 1e3, digits: 3)) mWb · L \(Format.number(solved.inductance * 1e3, digits: 2)) mH"
        case .threeLeg:
            guard let solved = threeSolution else { return nil }
            return "Φc \(Format.number(solved.coilFlux * 1e3, digits: 3)) mWb · gap \(Format.percent(solved.gapMMFFraction * 100))"
        case .machines:
            guard let solved = seriesSolution else { return nil }
            let density = solved.drop(named: "Air gap")?.fluxDensity ?? solved.drop(named: "Steel")?.fluxDensity ?? 0
            guard let row = machineRow(solved, density: density) else { return nil }
            return "\(row.0) \(row.1)"
        }
    }

    private var exampleTitle: String {
        switch screen {
        case .series: return "500 turns, 0.6 A, 0.5 mm gap"
        case .threeLeg: return "Center post, 0.5 mm side gaps"
        case .machines: return "Contactor core, then a second winding"
        }
    }

    private func applyExample() {
        turns = "500"
        current = "0.6"
        muR = "2000"
        stacking = "0.95"
        fringing = "1.05"
        switch screen {
        case .series, .machines:
            length = "0.2"
            areaCm2 = "1"
            gapMm = "0.5"
            secondaryTurns = "100"
            primaryVolts = ""
            hertz = ""
            machineRaw = MachineKind.transformer.rawValue
        case .threeLeg:
            centerLength = "0.08"
            centerArea = "4"
            centerGap = "0"
            sideLength = "0.25"
            sideArea = "2"
            sideGap = "0.5"
            matchRight = true
            muR = "4000"
            stacking = "0.96"
            fringing = "1.1"
        }
    }

    private func saveCore(_ solved: MagneticsLab.Solution) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .magneticsLab,
            inputs: ["N": turns, "I": current, "screen": screen.title],
            outputs: [
                "flux": "\(Format.number(solved.coilFlux * 1e3, digits: 3)) mWb",
                "L": "\(Format.number(solved.inductance * 1e3, digits: 3)) mH",
            ]
        ))
    }

    private func saveMachine(_ solved: MagneticsLab.Solution) {
        let density = solved.drop(named: "Air gap")?.fluxDensity ?? solved.drop(named: "Steel")?.fluxDensity ?? 0
        let row = machineRow(solved, density: density)
        jobs.save(SavedJob(
            name: jobName,
            toolID: .magneticsLab,
            inputs: ["N": turns, "I": current, "machine": machineRaw],
            outputs: [row?.0 ?? "B": row?.1 ?? "\(Format.number(density, digits: 3)) T"]
        ))
    }

    private func leg(_ lengthText: String, _ areaText: String, _ gapText: String) -> MagneticsLab.CoreLeg {
        MagneticsLab.CoreLeg(
            steelLength: num(lengthText),
            steelArea: cm2(areaText),
            gapLength: mm(gapText),
            relativePermeability: num(muR),
            stackingFactor: num(stacking),
            fringing: num(fringing)
        )
    }

    private func num(_ text: String) -> Double { text.parsedDouble ?? .nan }
    private func optionalNum(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.parsedDouble
    }
    private func cm2(_ text: String) -> Double { num(text) * 1e-4 }
    private func cm(_ text: String) -> Double { num(text) * 0.01 }
    private func mm(_ text: String) -> Double { num(text) * 1e-3 }

    private func message(_ work: () throws -> Void) -> String? {
        do {
            try work()
            return nil
        } catch let error as CalcError {
            return error.message
        } catch {
            return error.localizedDescription
        }
    }

}
