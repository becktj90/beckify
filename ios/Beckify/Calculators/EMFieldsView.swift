import SwiftUI
import BeckifyMath

private enum EMScreen: String, CaseIterable, Identifiable {
    case faraday
    case charges
    case lorentz
    case vectors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .faraday: return "Induced emf"
        case .charges: return "Point charges"
        case .lorentz: return "Moving charge"
        case .vectors: return "Vector check"
        }
    }

    var blurb: String {
        switch self {
        case .faraday:
            return "Emf from a changing flux through a loop, and which way the induced current runs."
        case .charges:
            return "Field of several charges, the force on a test charge, and a flag when the sum is nearly zero."
        case .lorentz:
            return "F = q(E + v × B). A straight push or a curve — not a tracked flight."
        case .vectors:
            return "Cartesian, cylindrical, and spherical. Dot, cross, and four sample fields."
        }
    }
}

private enum FaradayMode: String, CaseIterable, Identifiable {
    case rate
    case span
    case flux

    var id: String { rawValue }
    var title: String {
        switch self {
        case .rate: return "dB/dt"
        case .span: return "Two readings"
        case .flux: return "dΦ/dt"
        }
    }
}

private enum VectorMode: String, CaseIterable, Identifiable {
    case frames
    case products
    case sample

    var id: String { rawValue }
    var title: String {
        switch self {
        case .frames: return "Frames"
        case .products: return "Products"
        case .sample: return "Samples"
        }
    }
}

struct EMFieldsView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.emFields, "screen", default: EMScreen.faraday.rawValue) private var screenRaw
    @StoredToggle(.emFields, "open", default: false) private var didOpen
    @StoredInput(.emFields, "jobName", default: "EM fields") private var jobName

    @StoredInput(.emFields, "faradayMode", default: FaradayMode.rate.rawValue) private var faradayMode
    @StoredInput(.emFields, "turns", default: "10") private var turns
    @StoredInput(.emFields, "area", default: "100") private var areaCm2
    @StoredInput(.emFields, "dBdt", default: "0.5") private var densityRate
    @StoredInput(.emFields, "b0", default: "0") private var startB
    @StoredInput(.emFields, "b1", default: "0.2") private var endB
    @StoredInput(.emFields, "dt", default: "0.1") private var seconds
    @StoredInput(.emFields, "dPhi", default: "0.01") private var fluxRate

    @StoredInput(.emFields, "q1", default: "1") private var q1
    @StoredInput(.emFields, "x1", default: "-0.1") private var x1
    @StoredInput(.emFields, "y1", default: "0") private var y1
    @StoredInput(.emFields, "z1", default: "0") private var z1
    @StoredInput(.emFields, "q2", default: "-1") private var q2
    @StoredInput(.emFields, "x2", default: "0.1") private var x2
    @StoredInput(.emFields, "y2", default: "0") private var y2
    @StoredInput(.emFields, "z2", default: "0") private var z2
    @StoredInput(.emFields, "q3", default: "") private var q3
    @StoredInput(.emFields, "x3", default: "0") private var x3
    @StoredInput(.emFields, "y3", default: "0.2") private var y3
    @StoredInput(.emFields, "z3", default: "0") private var z3
    @StoredInput(.emFields, "px", default: "0") private var px
    @StoredInput(.emFields, "py", default: "0.1") private var py
    @StoredInput(.emFields, "pz", default: "0") private var pz
    @StoredInput(.emFields, "qt", default: "1") private var testNano

    @StoredInput(.emFields, "lq", default: "1") private var lqMicro
    @StoredInput(.emFields, "ex", default: "0") private var ex
    @StoredInput(.emFields, "ey", default: "0") private var ey
    @StoredInput(.emFields, "ez", default: "0") private var ez
    @StoredInput(.emFields, "vx", default: "20") private var vx
    @StoredInput(.emFields, "vy", default: "0") private var vy
    @StoredInput(.emFields, "vz", default: "0") private var vz
    @StoredInput(.emFields, "bx", default: "0") private var bx
    @StoredInput(.emFields, "by", default: "0") private var by
    @StoredInput(.emFields, "bz", default: "0.05") private var bz
    @StoredInput(.emFields, "mass", default: "") private var massGrams

    @StoredInput(.emFields, "vectorMode", default: VectorMode.frames.rawValue) private var vectorMode
    @StoredInput(.emFields, "cx", default: "1") private var cx
    @StoredInput(.emFields, "cy", default: "1") private var cy
    @StoredInput(.emFields, "cz", default: "1") private var cz
    @StoredInput(.emFields, "ax", default: "2") private var ax
    @StoredInput(.emFields, "ay", default: "2") private var ay
    @StoredInput(.emFields, "az", default: "0") private var az
    @StoredInput(.emFields, "bxv", default: "1") private var bxv
    @StoredInput(.emFields, "byv", default: "0") private var byv
    @StoredInput(.emFields, "bzv", default: "0") private var bzv
    @StoredInput(.emFields, "sample", default: EMFields.SampleField.swirl.rawValue) private var sampleRaw
    @StoredInput(.emFields, "sx", default: "1") private var sx
    @StoredInput(.emFields, "sy", default: "0.5") private var sy
    @StoredInput(.emFields, "sz", default: "0") private var sz

    private var screen: EMScreen { EMScreen(rawValue: screenRaw) ?? .faraday }

    var body: some View {
        ToolScaffold(toolID: .emFields, stickyAnswer: sticky, copyText: sticky) {
            if didOpen {
                detail
            } else {
                hub
            }
        }
    }

    private var hub: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Field checks that sit next to the core lab: induced emf, charges, a moving charge, and vectors.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(EMScreen.allCases) { item in
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
                .accessibilityIdentifier("emFields.\(item.rawValue)")
            }
        }
        .accessibilityIdentifier("emFields.hub")
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
            case .faraday: faradayBody
            case .charges: chargeBody
            case .lorentz: lorentzBody
            case .vectors: vectorBody
            }
        }
    }

    private var faradayBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Picker("Drive", selection: $faradayMode) {
                ForEach(FaradayMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            NumberField(title: "Turns", unit: "", text: $turns, fieldID: "turns")
            switch FaradayMode(rawValue: faradayMode) ?? .rate {
            case .rate:
                NumberField(title: "Loop area", unit: "cm²", text: $areaCm2, fieldID: "area")
                NumberField(title: "dB/dt", unit: "T/s", text: $densityRate, helpText: "Positive means B toward you is increasing.", fieldID: "dBdt")
            case .span:
                NumberField(title: "Loop area", unit: "cm²", text: $areaCm2, fieldID: "area")
                NumberField(title: "Starting B", unit: "T", text: $startB, fieldID: "b0")
                NumberField(title: "Ending B", unit: "T", text: $endB, fieldID: "b1")
                NumberField(title: "Time span", unit: "s", text: $seconds, fieldID: "dt")
            case .flux:
                NumberField(title: "dΦ/dt", unit: "Wb/s", text: $fluxRate, helpText: "Positive flux is toward you.", fieldID: "dPhi")
            }
            if let failure = faradayFailure {
                ErrorText(message: failure)
            } else if let result = faradayResult {
                FaradayLoopDiagram(
                    circulation: result.circulation,
                    emf: result.emf,
                    startB: (FaradayMode(rawValue: faradayMode) == .span) ? num(startB) : nil,
                    endB: (FaradayMode(rawValue: faradayMode) == .span) ? num(endB) : nil,
                    seconds: (FaradayMode(rawValue: faradayMode) == .span) ? num(seconds) : nil
                )
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Induced emf", value: "\(Format.number(result.emf, digits: 4)) V", emphasis: true, tone: Theme.good)
                    ResultRow(label: "dΦ/dt", value: "\(Format.number(result.fluxRate, digits: 4)) Wb/s")
                    ResultRow(label: "Circulation", value: result.circulation)
                }
                Text(result.note)
                    .font(.footnote)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("ε = −N dΦ/dt. Uniform B is taken perpendicular to the area. A tilted field is not resolved here.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SaveJobBar(jobName: $jobName, canSave: true) {
                    save(["emf": "\(Format.number(result.emf, digits: 4)) V"])
                }
            }
        }
    }

    private var chargeBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            chargeSlot("Charge 1", q: $q1, x: $x1, y: $y1, z: $z1, prefix: "1")
            chargeSlot("Charge 2", q: $q2, x: $x2, y: $y2, z: $z2, prefix: "2")
            chargeSlot("Charge 3", q: $q3, x: $x3, y: $y3, z: $z3, prefix: "3", optional: true)
            sectionLabel("Test point")
            NumberField(title: "x", unit: "m", text: $px, fieldID: "px")
            NumberField(title: "y", unit: "m", text: $py, fieldID: "py")
            NumberField(title: "z", unit: "m", text: $pz, fieldID: "pz")
            NumberField(title: "Test charge", unit: "nC", text: $testNano, optional: true, helpText: "Leave blank to skip the force.", fieldID: "qt")
            if let failure = chargeFailure {
                ErrorText(message: failure)
            } else if let result = chargeResult {
                ChargePlaneDiagram(charges: chargeList, point: testPoint, field: result.electricField)
                ResultCard(copyText: sticky) {
                    ResultRow(label: "|E|", value: "\(Format.number(result.magnitude, digits: 3)) V/m", emphasis: true, tone: result.nearEquilibrium ? Theme.warn : Theme.good)
                    ResultRow(label: "Ex", value: "\(Format.number(result.electricField.x, digits: 3)) V/m")
                    ResultRow(label: "Ey", value: "\(Format.number(result.electricField.y, digits: 3)) V/m")
                    ResultRow(label: "Ez", value: "\(Format.number(result.electricField.z, digits: 3)) V/m")
                    if let force = result.force {
                        ResultRow(label: "|F|", value: "\(Format.number(force.magnitude, digits: 4)) N")
                    }
                }
                if result.nearEquilibrium {
                    Text("The contributions nearly cancel. A test charge here feels almost no force — an equilibrium of this pass, not a proof it is stable.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Point charges in free space. Conductors, dielectrics, and images are not in this sum.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                SaveJobBar(jobName: $jobName, canSave: true) {
                    save(["E": "\(Format.number(result.magnitude, digits: 3)) V/m"])
                }
            }
        }
    }

    private var lorentzBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            NumberField(title: "Charge", unit: "µC", text: $lqMicro, fieldID: "lq")
            sectionLabel("E")
            triple($ex, $ey, $ez, unit: "V/m", prefix: "e")
            sectionLabel("Velocity")
            triple($vx, $vy, $vz, unit: "m/s", prefix: "v")
            sectionLabel("B")
            triple($bx, $by, $bz, unit: "T", prefix: "b")
            NumberField(title: "Mass", unit: "g", text: $massGrams, optional: true, helpText: "Needed only for the arc radius.", fieldID: "mass")
            if let failure = lorentzFailure {
                ErrorText(message: failure)
            } else if let result = lorentzResult {
                LorentzSketchDiagram(
                    velocity: FieldVector(x: num(vx), y: num(vy), z: num(vz)),
                    force: result.force,
                    magnetic: FieldVector(x: num(bx), y: num(by), z: num(bz)),
                    path: result.path,
                    radius: result.radius
                )
                ResultCard(copyText: sticky) {
                    ResultRow(label: "|F|", value: "\(Format.number(result.force.magnitude, digits: 4)) N", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Fx Fy Fz", value: vectorText(result.force))
                    ResultRow(label: "Path", value: result.path)
                    if let radius = result.radius {
                        ResultRow(label: "Arc radius", value: "\(Format.number(radius, digits: 3)) m")
                    }
                }
                Text(result.note)
                    .font(.footnote)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                SaveJobBar(jobName: $jobName, canSave: true) {
                    save(["F": "\(Format.number(result.force.magnitude, digits: 4)) N", "path": result.path])
                }
            }
        }
    }

    private var vectorBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Picker("Check", selection: $vectorMode) {
                ForEach(VectorMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            switch VectorMode(rawValue: vectorMode) ?? .frames {
            case .frames:
                sectionLabel("Cartesian")
                triple($cx, $cy, $cz, unit: "", prefix: "c")
                framesResult
            case .products:
                sectionLabel("A")
                triple($ax, $ay, $az, unit: "", prefix: "a")
                sectionLabel("B")
                triple($bxv, $byv, $bzv, unit: "", prefix: "bv")
                productsResult
            case .sample:
                Picker("Field", selection: $sampleRaw) {
                    ForEach(EMFields.SampleField.allCases, id: \.rawValue) { field in
                        Text(field.title).tag(field.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                triple($sx, $sy, $sz, unit: "", prefix: "s")
                sampleResult
            }
        }
    }

    @ViewBuilder
    private var framesResult: some View {
        if let failure = frameFailure {
            ErrorText(message: failure)
        } else if let pair = framePair {
            ResultCard(copyText: sticky) {
                ResultRow(label: "ρ, φ, z", value: "\(Format.number(pair.cyl.rho, digits: 3)), \(Format.number(pair.cyl.phiDegrees, digits: 2))°, \(Format.number(pair.cyl.z, digits: 3))", emphasis: true)
                ResultRow(label: "r, θ, φ", value: "\(Format.number(pair.sph.r, digits: 3)), \(Format.number(pair.sph.thetaDegrees, digits: 2))°, \(Format.number(pair.sph.phiDegrees, digits: 2))°")
            }
            Text("φ is from +x toward +y. θ is from +z. Degrees.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            SaveJobBar(jobName: $jobName, canSave: true) {
                save(["phi": "\(Format.number(pair.cyl.phiDegrees, digits: 2))°"])
            }
        }
    }

    @ViewBuilder
    private var productsResult: some View {
        if let failure = productFailure {
            ErrorText(message: failure)
        } else if let products = vectorProducts {
            ResultCard(copyText: sticky) {
                ResultRow(label: "A · B", value: Format.number(products.dot, digits: 4), emphasis: true, tone: Theme.good)
                ResultRow(label: "A × B", value: vectorText(products.cross))
                ResultRow(label: "A onto B", value: vectorText(products.projection))
                ResultRow(label: "Unit A", value: products.unitA.map(vectorText) ?? "—")
                ResultRow(label: "Unit B", value: products.unitB.map(vectorText) ?? "—")
            }
            Text("Projection is the part of A along B. A zero vector has no unit vector.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            SaveJobBar(jobName: $jobName, canSave: true) {
                save(["dot": Format.number(products.dot, digits: 4)])
            }
        }
    }

    @ViewBuilder
    private var sampleResult: some View {
        if let field = EMFields.SampleField(rawValue: sampleRaw), let probe = sampleProbe {
            SampleFieldDiagram(field: field, point: FieldVector(x: num(sx), y: num(sy), z: num(sz)))
            ResultCard(copyText: sticky) {
                ResultRow(label: "Value", value: vectorText(probe.value), emphasis: true)
                ResultRow(label: "Divergence", value: Format.number(probe.divergence, digits: 2))
                ResultRow(label: "Curl", value: vectorText(probe.curl))
            }
            Text(probe.circulationNote)
                .font(.footnote)
                .foregroundStyle(Theme.foreground)
            Text(probe.fluxNote)
                .font(.footnote)
                .foregroundStyle(Theme.foreground)
            Text("Four fixed fields only. This is not a general derivative solver.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            SaveJobBar(jobName: $jobName, canSave: true) {
                save(["div": Format.number(probe.divergence, digits: 2), "field": field.title])
            }
        } else if let failure = sampleFailure {
            ErrorText(message: failure)
        }
    }

    private func chargeSlot(
        _ title: String,
        q: Binding<String>,
        x: Binding<String>,
        y: Binding<String>,
        z: Binding<String>,
        prefix: String,
        optional: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            sectionLabel(title)
            NumberField(title: "Charge", unit: "nC", text: q, optional: optional, fieldID: "q\(prefix)")
            NumberField(title: "x", unit: "m", text: x, fieldID: "x\(prefix)")
            NumberField(title: "y", unit: "m", text: y, fieldID: "y\(prefix)")
            NumberField(title: "z", unit: "m", text: z, fieldID: "z\(prefix)")
        }
    }

    private func triple(_ x: Binding<String>, _ y: Binding<String>, _ z: Binding<String>, unit: String, prefix: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            NumberField(title: "x", unit: unit, text: x, fieldID: "\(prefix)x")
            NumberField(title: "y", unit: unit, text: y, fieldID: "\(prefix)y")
            NumberField(title: "z", unit: unit, text: z, fieldID: "\(prefix)z")
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.TypeRole.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
    }

    private var faradayResult: EMFields.InducedEMF? {
        switch FaradayMode(rawValue: faradayMode) ?? .rate {
        case .rate:
            return try? EMFields.faradayDensityRate(turns: num(turns), area: cm2(areaCm2), densityRate: num(densityRate))
        case .span:
            return try? EMFields.faradayLinearDensity(
                turns: num(turns), area: cm2(areaCm2),
                startDensity: num(startB), endDensity: num(endB), seconds: num(seconds)
            )
        case .flux:
            return try? EMFields.faradayFluxRate(turns: num(turns), fluxRate: num(fluxRate))
        }
    }

    private var faradayFailure: String? {
        guard faradayResult == nil else { return nil }
        switch FaradayMode(rawValue: faradayMode) ?? .rate {
        case .rate:
            return failure { _ = try EMFields.faradayDensityRate(turns: num(turns), area: cm2(areaCm2), densityRate: num(densityRate)) }
        case .span:
            return failure { _ = try EMFields.faradayLinearDensity(turns: num(turns), area: cm2(areaCm2), startDensity: num(startB), endDensity: num(endB), seconds: num(seconds)) }
        case .flux:
            return failure { _ = try EMFields.faradayFluxRate(turns: num(turns), fluxRate: num(fluxRate)) }
        }
    }

    private var chargeList: [EMFields.PointCharge] {
        var list: [EMFields.PointCharge] = []
        func add(_ q: String, _ x: String, _ y: String, _ z: String) {
            let trimmed = q.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let coulombs = trimmed.parsedDouble else { return }
            list.append(.init(x: num(x), y: num(y), z: num(z), coulombs: coulombs * 1e-9))
        }
        add(q1, x1, y1, z1)
        add(q2, x2, y2, z2)
        add(q3, x3, y3, z3)
        return list
    }

    private var testPoint: FieldVector { FieldVector(x: num(px), y: num(py), z: num(pz)) }

    private var chargeResult: EMFields.ChargeField? {
        let test = testNano.trimmingCharacters(in: .whitespaces)
        let qTest = test.isEmpty ? nil : test.parsedDouble.map { $0 * 1e-9 }
        return try? EMFields.pointChargeField(charges: chargeList, at: testPoint, testCharge: qTest)
    }

    private var chargeFailure: String? {
        guard chargeResult == nil else { return nil }
        let test = testNano.trimmingCharacters(in: .whitespaces)
        let qTest = test.isEmpty ? nil : test.parsedDouble.map { $0 * 1e-9 }
        return failure { _ = try EMFields.pointChargeField(charges: chargeList, at: testPoint, testCharge: qTest) }
    }

    private var lorentzResult: EMFields.LorentzResult? {
        try? EMFields.lorentz(
            charge: num(lqMicro) * 1e-6,
            electric: FieldVector(x: num(ex), y: num(ey), z: num(ez)),
            velocity: FieldVector(x: num(vx), y: num(vy), z: num(vz)),
            magnetic: FieldVector(x: num(bx), y: num(by), z: num(bz)),
            mass: massGrams.trimmingCharacters(in: .whitespaces).isEmpty ? nil : num(massGrams) * 1e-3
        )
    }

    private var lorentzFailure: String? {
        guard lorentzResult == nil else { return nil }
        return failure {
            _ = try EMFields.lorentz(
                charge: num(lqMicro) * 1e-6,
                electric: FieldVector(x: num(ex), y: num(ey), z: num(ez)),
                velocity: FieldVector(x: num(vx), y: num(vy), z: num(vz)),
                magnetic: FieldVector(x: num(bx), y: num(by), z: num(bz)),
                mass: massGrams.trimmingCharacters(in: .whitespaces).isEmpty ? nil : num(massGrams) * 1e-3
            )
        }
    }

    private var framePair: (cyl: EMFields.Cylindrical, sph: EMFields.Spherical)? {
        let vector = FieldVector(x: num(cx), y: num(cy), z: num(cz))
        guard let cyl = try? EMFields.cylindrical(from: vector),
              let sph = try? EMFields.spherical(from: vector) else { return nil }
        return (cyl, sph)
    }

    private var frameFailure: String? {
        guard framePair == nil else { return nil }
        return failure { _ = try EMFields.cylindrical(from: FieldVector(x: num(cx), y: num(cy), z: num(cz))) }
    }

    private var vectorProducts: EMFields.VectorProducts? {
        try? EMFields.products(
            a: FieldVector(x: num(ax), y: num(ay), z: num(az)),
            b: FieldVector(x: num(bxv), y: num(byv), z: num(bzv))
        )
    }

    private var productFailure: String? {
        guard vectorProducts == nil else { return nil }
        return failure {
            _ = try EMFields.products(
                a: FieldVector(x: num(ax), y: num(ay), z: num(az)),
                b: FieldVector(x: num(bxv), y: num(byv), z: num(bzv))
            )
        }
    }

    private var sampleProbe: EMFields.SampleProbe? {
        guard let field = EMFields.SampleField(rawValue: sampleRaw) else { return nil }
        return try? EMFields.probe(field: field, at: FieldVector(x: num(sx), y: num(sy), z: num(sz)))
    }

    private var sampleFailure: String? {
        guard sampleProbe == nil else { return nil }
        guard let field = EMFields.SampleField(rawValue: sampleRaw) else { return "Pick a sample field." }
        return failure { _ = try EMFields.probe(field: field, at: FieldVector(x: num(sx), y: num(sy), z: num(sz))) }
    }

    private var sticky: String? {
        switch screen {
        case .faraday:
            return faradayResult.map { "ε \(Format.number($0.emf, digits: 4)) V" }
        case .charges:
            return chargeResult.map { "|E| \(Format.number($0.magnitude, digits: 3)) V/m" }
        case .lorentz:
            return lorentzResult.map { "\( $0.path ) · |F| \(Format.number($0.force.magnitude, digits: 3)) N" }
        case .vectors:
            switch VectorMode(rawValue: vectorMode) ?? .frames {
            case .frames:
                return framePair.map { "φ \(Format.number($0.cyl.phiDegrees, digits: 1))°" }
            case .products:
                return vectorProducts.map { "A·B \(Format.number($0.dot, digits: 3))" }
            case .sample:
                return sampleProbe.map { "div \(Format.number($0.divergence, digits: 2))" }
            }
        }
    }

    private var exampleTitle: String {
        switch screen {
        case .faraday: return "10 turns, 100 cm², 0.5 T/s"
        case .charges: return "±1 nC, test point above the midpoint"
        case .lorentz: return "1 µC at 20 m/s across 0.05 T"
        case .vectors: return "Swirl field at (1, 0.5, 0)"
        }
    }

    private func applyExample() {
        switch screen {
        case .faraday:
            faradayMode = FaradayMode.rate.rawValue
            turns = "10"
            areaCm2 = "100"
            densityRate = "0.5"
        case .charges:
            q1 = "1"; x1 = "-0.1"; y1 = "0"; z1 = "0"
            q2 = "-1"; x2 = "0.1"; y2 = "0"; z2 = "0"
            q3 = ""
            px = "0"; py = "0.1"; pz = "0"
            testNano = "1"
        case .lorentz:
            lqMicro = "1"
            ex = "0"; ey = "0"; ez = "0"
            vx = "20"; vy = "0"; vz = "0"
            bx = "0"; by = "0"; bz = "0.05"
            massGrams = "1"
        case .vectors:
            vectorMode = VectorMode.sample.rawValue
            sampleRaw = EMFields.SampleField.swirl.rawValue
            sx = "1"; sy = "0.5"; sz = "0"
        }
    }

    private func save(_ outputs: [String: String]) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .emFields,
            inputs: ["screen": screen.title],
            outputs: outputs
        ))
    }

    private func num(_ text: String) -> Double { text.parsedDouble ?? .nan }
    private func cm2(_ text: String) -> Double { num(text) * 1e-4 }

    private func failure(_ work: () throws -> Void) -> String? {
        do {
            try work()
            return nil
        } catch let error as CalcError {
            return error.message
        } catch {
            return error.localizedDescription
        }
    }

    private func vectorText(_ vector: FieldVector) -> String {
        "\(Format.number(vector.x, digits: 3)), \(Format.number(vector.y, digits: 3)), \(Format.number(vector.z, digits: 3))"
    }
}
