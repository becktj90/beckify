import SwiftUI
import BeckifyMath

// MARK: - NFPA 780 lightning protection wizard + chapter references

struct LightningProtectionView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case wizard = "Wizard"
        case ch4 = "Ch. 4"
        case ch7 = "Ch. 7"
        case ch8 = "Ch. 8"
        var id: String { rawValue }
    }

    @StoredInput(.lightningProtection, "section", default: "Wizard") private var sectionRaw
    @StoredInput(.lightningProtection, "length", default: "120") private var length
    @StoredInput(.lightningProtection, "width", default: "60") private var width
    @StoredInput(.lightningProtection, "height", default: "30") private var height
    @StoredInput(.lightningProtection, "rise", default: "0") private var rise
    @StoredInput(.lightningProtection, "terminal", default: "12") private var terminal
    @StoredToggle(.lightningProtection, "hazardous", default: false) private var hazardous
    @StoredInput(.lightningProtection, "mast", default: "50") private var mast
    @StoredInput(.lightningProtection, "objectDistance", default: "30") private var objectDistance
    @StoredInput(.lightningProtection, "objectHeight", default: "20") private var objectHeight

    private var section: Section { Section(rawValue: sectionRaw) ?? .wizard }

    private var structureResult: Result<LPSStructureResult, CalcError> {
        do {
            return .success(try LPSWizard.solve(LPSStructureInput(
                lengthFeet: length.parsedDouble ?? .nan,
                widthFeet: width.parsedDouble ?? .nan,
                heightFeet: height.parsedDouble ?? .nan,
                risePer12: rise.parsedDouble ?? .nan,
                terminalHeightInches: terminal.parsedDouble ?? .nan,
                hazardous: hazardous
            )))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.outOfRange("Check the inputs."))
        }
    }

    private var sphereRadius: Double { hazardous ? RollingSphere.hazardousRadiusFeet : RollingSphere.ordinaryRadiusFeet }

    var body: some View {
        ToolScaffold(toolID: .lightningProtection, stickyAnswer: sticky, copyText: sticky) {
            Picker("Section", selection: $sectionRaw) {
                ForEach(Section.allCases) { s in Text(s.rawValue).tag(s.rawValue) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lightningProtection.section")

            switch section {
            case .wizard:
                wizard
            case .ch4:
                CodeReferenceCardsView(heading: "Ch. 4 — " + (NFPA780Reference.chapterTitles[4] ?? ""), cards: NFPA780Reference.chapter4)
            case .ch7:
                CodeReferenceCardsView(heading: "Ch. 7 — " + (NFPA780Reference.chapterTitles[7] ?? ""), cards: NFPA780Reference.chapter7)
            case .ch8:
                CodeReferenceCardsView(heading: "Ch. 8 — " + (NFPA780Reference.chapterTitles[8] ?? ""), cards: NFPA780Reference.chapter8)
            }

            Text("\(NFPA780Reference.edition). \(NFPA780Reference.governs)")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder private var wizard: some View {
        Toggle("Flammable vapor or explosives structure (Ch. 7 / 8)", isOn: $hazardous)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)

        Text("ROLLING SPHERE · MAST")
            .font(Theme.TypeRole.sectionLabel)
            .foregroundStyle(Theme.muted)
        NumberField(title: "Mast / air terminal height", unit: "ft", text: $mast, fieldID: "mast")
        NumberField(title: "Object distance from mast", unit: "ft", text: $objectDistance, fieldID: "objectDistance")
        NumberField(title: "Object height", unit: "ft", text: $objectHeight, fieldID: "objectHeight")
        sphereSection

        Text("BUILDING LAYOUT")
            .font(Theme.TypeRole.sectionLabel)
            .foregroundStyle(Theme.muted)
        NumberField(title: "Length", unit: "ft", text: $length, fieldID: "length")
        NumberField(title: "Width", unit: "ft", text: $width, fieldID: "width")
        NumberField(title: "Height to eave / roof", unit: "ft", text: $height, fieldID: "height")
        NumberField(title: "Roof rise per 12 in run", unit: "in", text: $rise, helpText: "0 for a flat roof.", fieldID: "rise")
        NumberField(title: "Strike device height", unit: "in", text: $terminal, helpText: "24 in or taller allows 25 ft spacing.", fieldID: "terminal")
        structureSection
    }

    @ViewBuilder private var sphereSection: some View {
        let h = mast.parsedDouble ?? .nan
        let x = objectDistance.parsedDouble ?? .nan
        let oh = objectHeight.parsedDouble ?? .nan
        if h.isFinite, h > 0, x.isFinite, x >= 0, oh.isFinite, oh >= 0 {
            let ground = RollingSphere.protectedRadiusAtGround(mastHeight: h, sphereRadius: sphereRadius)
            let boundary = RollingSphere.protectedHeight(atDistance: x, mastHeight: h, sphereRadius: sphereRadius)
            let ok = RollingSphere.isProtected(objectHeight: oh, atDistance: x, mastHeight: h, sphereRadius: sphereRadius)
            RollingSphereDiagram(mastHeight: h, sphereRadius: sphereRadius, objectDistance: x, objectHeight: oh, protected: ok)
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rolling sphere cross-section. Protected radius at ground \(Format.number(ground)) feet. Object is \(ok ? "inside" : "outside") the zone.")
            ResultCard(title: "Zone of protection") {
                ResultRow(label: "Sphere radius", value: "\(Format.number(sphereRadius)) ft")
                ResultRow(label: "Protected radius at grade", value: "\(Format.number(ground)) ft", emphasis: true, tone: Theme.copper)
                ResultRow(label: "Boundary height at \(Format.number(x)) ft", value: "\(Format.number(boundary)) ft")
                ResultRow(label: "Object \(Format.number(oh)) ft tall", value: ok ? "Inside zone" : "Exposed", tone: ok ? Theme.good : Theme.bad)
                if h > sphereRadius {
                    Text("Mast is taller than the sphere: the part above one radius can take side strikes and adds no reach.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.warn)
                }
                if !hazardous, let cone = ProtectionCone.radiusAtGround(height: h) {
                    ResultRow(label: "Cone method (≤ 50 ft)", value: "\(Format.number(cone)) ft at grade", tone: Theme.muted)
                }
            }
        } else {
            ErrorText(message: "Enter a mast height above zero and a non-negative object distance and height.")
        }
    }

    @ViewBuilder private var structureSection: some View {
        switch structureResult {
        case .failure(let error):
            ErrorText(message: error.message)
        case .success(let r):
            ResultCard(title: "Layout estimate", copyText: layoutCopy(r)) {
                ResultRow(label: "Roof", value: r.roof.displayName)
                ResultRow(label: "Materials (4.2)", value: r.materialClass.displayName, tone: r.materialClass == .classII ? Theme.warn : Theme.foreground)
                ResultRow(label: "Device spacing", value: "≤ \(Format.number(r.spacingFeet)) ft")
                if r.roof == .steep {
                    ResultRow(label: "Ridge devices", value: "\(r.ridgeTerminals)", emphasis: true, tone: Theme.copper)
                } else {
                    ResultRow(label: "Perimeter devices", value: "\(r.perimeterTerminals)", emphasis: true, tone: Theme.copper)
                    ResultRow(label: "Field devices (50 ft grid)", value: "\(r.interiorTerminals)")
                }
                ResultRow(label: "Down conductors (4.8)", value: "\(r.downConductors) for \(Format.number(r.perimeterFeet)) ft perimeter", emphasis: true)
                ResultRow(label: "Grounding electrodes (4.12)", value: "\(r.downConductors), one per down conductor")
                ResultRow(label: "Bonding distance at roof, air (4.15)", value: "≈ \(Format.number(r.separationAirFeet)) ft")
            }
            ResultCard(title: "Notes") {
                ForEach(notes(r), id: \.self) { note in
                    Text(note)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private func notes(_ r: LPSStructureResult) -> [String] {
        var out = [
            "Plain rectangle estimate. Add devices for corners, dormers, chimneys, and rooftop units.",
            "Bond any metal within the bonding distance of a conductor, or keep it farther away.",
        ]
        if r.input.hazardous {
            out.append("Ch. 7 / 8 structures use the 100 ft sphere; see those tabs for tank and magazine specifics.")
        }
        if r.materialClass == .classII {
            out.append("Over 75 ft: use Class II conductors and devices, and add loop conductors for potential equalization (4.14).")
        }
        return out
    }

    private func layoutCopy(_ r: LPSStructureResult) -> String {
        "NFPA 780: \(r.roof.displayName) roof, \(r.totalTerminals) strike devices, \(r.downConductors) down conductors, \(r.materialClass.displayName)"
    }

    private var sticky: String? {
        guard section == .wizard, case .success(let r) = structureResult else { return nil }
        return "\(r.totalTerminals) devices · \(r.downConductors) downs · \(r.materialClass.displayName)"
    }
}

/// Side view of a mast, the rolling sphere resting on its tip and the ground, and one object.
struct RollingSphereDiagram: View {
    let mastHeight: Double
    let sphereRadius: Double
    let objectDistance: Double
    let objectHeight: Double
    let protected: Bool

    var body: some View {
        Canvas { context, size in
            let reach = RollingSphere.protectedRadiusAtGround(mastHeight: mastHeight, sphereRadius: sphereRadius)
            let spanX = max(reach, objectDistance) * 1.15 + 10
            let spanY = max(min(mastHeight, sphereRadius * 1.1), objectHeight) * 1.25 + 5
            let pad: CGFloat = 12
            let sx = (size.width - pad * 2) / CGFloat(spanX)
            let sy = (size.height - pad * 2) / CGFloat(spanY)
            let scale = min(sx, sy)
            let origin = CGPoint(x: pad + 8, y: size.height - pad)
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: origin.x + CGFloat(x) * scale, y: origin.y - CGFloat(y) * scale)
            }

            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: origin.y))
            ground.addLine(to: CGPoint(x: size.width, y: origin.y))
            context.stroke(ground, with: .color(Theme.muted), lineWidth: 1)

            // Protected zone fill under the sphere boundary.
            let profile = RollingSphere.profile(mastHeight: mastHeight, sphereRadius: sphereRadius)
            if let first = profile.first {
                var zone = Path()
                zone.move(to: pt(0, 0))
                zone.addLine(to: pt(first.x, first.y))
                for p in profile.dropFirst() { zone.addLine(to: pt(p.x, p.y)) }
                zone.closeSubpath()
                context.fill(zone, with: .color(Theme.good.opacity(0.18)))
                var edge = Path()
                edge.move(to: pt(first.x, first.y))
                for p in profile.dropFirst() { edge.addLine(to: pt(p.x, p.y)) }
                context.stroke(edge, with: .color(Theme.good), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }

            // Sphere outline (center at reach, radius R).
            let center = pt(reach, sphereRadius)
            let rr = CGFloat(sphereRadius) * scale
            let circle = Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2))
            context.stroke(circle, with: .color(Theme.accent.opacity(0.6)), lineWidth: 1)

            // Mast.
            var mastPath = Path()
            mastPath.move(to: pt(0, 0))
            mastPath.addLine(to: pt(0, mastHeight))
            context.stroke(mastPath, with: .color(Theme.copper), lineWidth: 3)

            // Object.
            let objW = max(4, CGFloat(spanX) * 0.03 * scale)
            let top = pt(objectDistance, objectHeight)
            let objRect = CGRect(x: top.x - objW / 2, y: top.y, width: objW, height: origin.y - top.y)
            context.fill(Path(objRect), with: .color(protected ? Theme.good : Theme.bad))
        }
    }
}

/// Section-numbered reference cards in plain language.
struct CodeReferenceCardsView: View {
    let heading: String
    let cards: [CodeReferenceCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(Theme.TypeRole.lead)
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)
            ForEach(cards) { card in
                ResultCard(title: card.title) {
                    Text(card.citation)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    ForEach(card.points, id: \.self) { point in
                        Text("• " + point)
                            .font(.subheadline)
                            .foregroundStyle(Theme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}
