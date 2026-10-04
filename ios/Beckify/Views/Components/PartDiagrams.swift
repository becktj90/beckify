import SwiftUI
import BeckifyMath

/// Real pin numbers for an op-amp symbol: the signal pins, the supply pins and the part name.
struct OpAmpPinNumbers {
    var minus: Int
    var plus: Int
    var out: Int
    var vPlus: Int
    var vMinus: Int
    var name: String

    init(part: WorkbenchOpAmpPart) {
        let amp = part.primary
        minus = amp.inMinus
        plus = amp.inPlus
        out = amp.out
        vPlus = part.vPlus
        vMinus = part.vMinus
        name = part.name
    }
}

// MARK: - Schematic pen

/// Tiny schematic vocabulary in a fixed drawing space. Callers draw at base size and the view scales it.
private enum Sch {
    static let wireColor = Theme.accent

    static func wire(_ context: GraphicsContext, _ points: [CGPoint], color: Color = Sch.wireColor) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }

    static func dot(_ context: GraphicsContext, _ point: CGPoint) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - 2.6, y: point.y - 2.6, width: 5.2, height: 5.2)), with: .color(wireColor))
    }

    static func terminal(_ context: GraphicsContext, _ point: CGPoint) {
        let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: rect), with: .color(Theme.surfaceRaised))
        context.stroke(Path(ellipseIn: rect), with: .color(wireColor), lineWidth: 1.4)
    }

    static func text(
        _ context: GraphicsContext,
        _ string: String,
        _ point: CGPoint,
        anchor: UnitPoint = .center,
        size: CGFloat = 11,
        weight: Font.Weight = .semibold,
        color: Color = Theme.foreground
    ) {
        context.draw(
            Text(string).font(.system(size: size, weight: weight, design: .rounded)).foregroundColor(color),
            at: point,
            anchor: anchor
        )
    }

    /// Zig-zag between two points on any axis.
    static func resistor(_ context: GraphicsContext, from a: CGPoint, to b: CGPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = max((dx * dx + dy * dy).squareRoot(), 1)
        let ux = dx / length
        let uy = dy / length
        let nx = -uy
        let ny = ux
        let lead = length * 0.16
        let amplitude: CGFloat = 5
        let zigs = 6
        var points: [CGPoint] = [a, CGPoint(x: a.x + ux * lead, y: a.y + uy * lead)]
        let body = length - 2 * lead
        for index in 0..<zigs {
            let along = lead + body * (CGFloat(index) + 0.5) / CGFloat(zigs)
            let side: CGFloat = index % 2 == 0 ? amplitude : -amplitude
            points.append(CGPoint(x: a.x + ux * along + nx * side, y: a.y + uy * along + ny * side))
        }
        points.append(CGPoint(x: b.x - ux * lead, y: b.y - uy * lead))
        points.append(b)
        wire(context, points)
    }

    /// Two plates across the line between the points.
    static func capacitor(_ context: GraphicsContext, from a: CGPoint, to b: CGPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = max((dx * dx + dy * dy).squareRoot(), 1)
        let ux = dx / length
        let uy = dy / length
        let nx = -uy
        let ny = ux
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let gap: CGFloat = 3.5
        let half: CGFloat = 9
        let p1 = CGPoint(x: mid.x - ux * gap, y: mid.y - uy * gap)
        let p2 = CGPoint(x: mid.x + ux * gap, y: mid.y + uy * gap)
        wire(context, [a, p1])
        wire(context, [p2, b])
        wire(context, [CGPoint(x: p1.x + nx * half, y: p1.y + ny * half), CGPoint(x: p1.x - nx * half, y: p1.y - ny * half)])
        wire(context, [CGPoint(x: p2.x + nx * half, y: p2.y + ny * half), CGPoint(x: p2.x - nx * half, y: p2.y - ny * half)])
    }

    static func ground(_ context: GraphicsContext, at point: CGPoint) {
        wire(context, [point, CGPoint(x: point.x, y: point.y + 6)])
        for (index, half) in [CGFloat(9), 6, 3].enumerated() {
            let y = point.y + 6 + CGFloat(index) * 3.2
            wire(context, [CGPoint(x: point.x - half, y: y), CGPoint(x: point.x + half, y: y)])
        }
    }

    struct OpAmpPins {
        var minus: CGPoint
        var plus: CGPoint
        var out: CGPoint
    }

    /// Triangle pointing right. `flipped` puts + on top and − on the bottom.
    /// With `pins`, each terminal carries its package pin number and the supply stubs show V+ and V−.
    @discardableResult
    static func opAmp(
        _ context: GraphicsContext,
        center: CGPoint,
        width: CGFloat = 56,
        height: CGFloat = 56,
        flipped: Bool = false,
        pins: OpAmpPinNumbers? = nil
    ) -> OpAmpPins {
        var body = Path()
        body.move(to: CGPoint(x: center.x - width / 2, y: center.y - height / 2))
        body.addLine(to: CGPoint(x: center.x - width / 2, y: center.y + height / 2))
        body.addLine(to: CGPoint(x: center.x + width / 2, y: center.y))
        body.closeSubpath()
        context.fill(body, with: .color(Theme.surfaceRaised))
        context.stroke(body, with: .color(Theme.foreground), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        let top = CGPoint(x: center.x - width / 2, y: center.y - height / 4)
        let bottom = CGPoint(x: center.x - width / 2, y: center.y + height / 4)
        let minus = flipped ? bottom : top
        let plus = flipped ? top : bottom
        text(context, "−", CGPoint(x: minus.x + 7, y: minus.y), size: 13, color: Theme.foreground)
        text(context, "+", CGPoint(x: plus.x + 7, y: plus.y), size: 13, color: Theme.foreground)
        let out = CGPoint(x: center.x + width / 2, y: center.y)
        if let pins {
            let tint = Theme.accent
            // Pin number badges sit just outside the terminals.
            text(context, "\(pins.minus)", CGPoint(x: minus.x - 9, y: minus.y + (flipped ? 10 : -10)), size: 9.5, weight: .bold, color: tint)
            text(context, "\(pins.plus)", CGPoint(x: plus.x - 9, y: plus.y + (flipped ? -10 : 10)), size: 9.5, weight: .bold, color: tint)
            text(context, "\(pins.out)", CGPoint(x: out.x + 11, y: out.y - 10), size: 9.5, weight: .bold, color: tint)
            // Supply stubs leave the slanted edges to the right of the inputs.
            let stubX = center.x + width / 6
            let edge = height / 6
            wire(context, [CGPoint(x: stubX, y: center.y - edge), CGPoint(x: stubX, y: center.y - edge - 12)], color: Theme.bad)
            text(context, "V+ \(pins.vPlus)", CGPoint(x: stubX, y: center.y - edge - 21), size: 9, weight: .bold, color: Theme.bad)
            wire(context, [CGPoint(x: stubX, y: center.y + edge), CGPoint(x: stubX, y: center.y + edge + 12)], color: Theme.muted)
            text(context, "V− \(pins.vMinus)", CGPoint(x: stubX, y: center.y + edge + 21), size: 9, weight: .bold, color: Theme.muted)
            text(context, pins.name, CGPoint(x: center.x - width / 6, y: center.y), size: 8.5, weight: .bold, color: Theme.muted)
        }
        return OpAmpPins(minus: minus, plus: plus, out: out)
    }

    /// Scales a base-size drawing into the available canvas, centered.
    static func fit(_ context: GraphicsContext, size: CGSize, base: CGSize) -> GraphicsContext {
        var scaled = context
        let k = min(size.width / base.width, size.height / base.height)
        scaled.translateBy(x: (size.width - base.width * k) / 2, y: (size.height - base.height * k) / 2)
        scaled.scaleBy(x: k, y: k)
        return scaled
    }
}

// MARK: - Part pinout

private enum PinInk {
    static func color(_ role: PinRole) -> Color {
        switch role {
        case .supplyPlus, .powerIn: return Theme.bad
        case .supplyMinus, .ground, .noConnect: return Theme.muted
        case .inputPlus, .inputMinus: return Theme.good
        case .output, .powerOut: return Theme.copper
        case .adjust, .gain, .reference, .offset: return Theme.accent
        }
    }
}

/// Package outline with every pin numbered and named. Dual and quad parts label each amplifier A–D.
struct PartPinoutDiagram: View {
    let part: PartPinout

    private var height: CGFloat {
        switch part.package {
        case .dip(let count): return CGFloat(count / 2) * 32 + 64
        case .sot23_5: return 210
        case .to220: return 270
        case .sot223: return 250
        }
    }

    private var summary: String {
        let pins = part.pins.map { "pin \($0.number) \($0.name)" }.joined(separator: ", ")
        return "\(part.name) \(part.package.label). \(pins)."
    }

    var body: some View {
        Canvas { context, size in draw(context, size) }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
            .accessibilityIdentifier("pinout.\(part.id)")
    }

    private func pin(_ number: Int) -> PartPin? {
        part.pins.first { $0.number == number }
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize) {
        switch part.package {
        case .dip(let count): drawDIP(context, size, count: count)
        case .sot23_5: drawSOT23(context, size)
        case .to220: drawTab(context, size, bodyWidth: 100, tabWidth: 100, tabHeight: 44, leadSpacing: 34, hole: true)
        case .sot223: drawTab(context, size, bodyWidth: 84, tabWidth: 84, tabHeight: 26, leadSpacing: 26, hole: false)
        }
    }

    private func nameLabel(_ context: GraphicsContext, _ pin: PartPin, at point: CGPoint, anchor: UnitPoint) {
        let tint = PinInk.color(pin.role)
        context.draw(
            Text(pin.name).font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundColor(tint),
            at: point,
            anchor: anchor
        )
    }

    private func numberBadge(_ context: GraphicsContext, _ number: Int, at point: CGPoint, tint: Color) {
        let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.2)))
        context.draw(
            Text("\(number)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(Theme.foreground),
            at: point,
            anchor: .center
        )
    }

    private func drawDIP(_ context: GraphicsContext, _ size: CGSize, count: Int) {
        let rows = count / 2
        let pitch: CGFloat = 32
        let bodyW: CGFloat = 110
        let bodyH = CGFloat(rows) * pitch + 12
        let body = CGRect(x: (size.width - bodyW) / 2, y: 28, width: bodyW, height: bodyH)
        context.fill(Path(roundedRect: body, cornerRadius: 6), with: .color(Color(white: 0.16)))
        context.stroke(Path(roundedRect: body, cornerRadius: 6), with: .color(Theme.border), lineWidth: 1.2)
        // Notch at the pin 1 end.
        var notch = Path()
        for step in 0...16 {
            let angle = Double.pi * Double(step) / 16
            let point = CGPoint(x: body.midX + CGFloat(cos(angle)) * 9, y: body.minY + CGFloat(sin(angle)) * 9)
            if step == 0 { notch.move(to: point) } else { notch.addLine(to: point) }
        }
        context.stroke(notch, with: .color(Theme.border), lineWidth: 1.2)
        context.fill(Path(ellipseIn: CGRect(x: body.minX + 8, y: body.minY + 8, width: 6, height: 6)), with: .color(Color(white: 0.55)))
        context.draw(
            Text(part.name).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color(white: 0.85)),
            at: CGPoint(x: body.midX, y: body.midY),
            anchor: .center
        )
        for row in 0..<rows {
            let y = body.minY + 6 + pitch * (CGFloat(row) + 0.5)
            if let left = pin(row + 1) {
                var lead = Path()
                lead.move(to: CGPoint(x: body.minX - 18, y: y))
                lead.addLine(to: CGPoint(x: body.minX, y: y))
                context.stroke(lead, with: .color(PinInk.color(left.role)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                numberBadge(context, left.number, at: CGPoint(x: body.minX + 14, y: y), tint: PinInk.color(left.role))
                nameLabel(context, left, at: CGPoint(x: body.minX - 24, y: y), anchor: .trailing)
            }
            if let right = pin(count - row) {
                var lead = Path()
                lead.move(to: CGPoint(x: body.maxX, y: y))
                lead.addLine(to: CGPoint(x: body.maxX + 18, y: y))
                context.stroke(lead, with: .color(PinInk.color(right.role)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                numberBadge(context, right.number, at: CGPoint(x: body.maxX - 14, y: y), tint: PinInk.color(right.role))
                nameLabel(context, right, at: CGPoint(x: body.maxX + 24, y: y), anchor: .leading)
            }
        }
    }

    /// Pins 1–3 along the bottom, left to right. Pin 4 is top right and pin 5 top left.
    private func drawSOT23(_ context: GraphicsContext, _ size: CGSize) {
        let body = CGRect(x: (size.width - 92) / 2, y: 76, width: 92, height: 44)
        context.fill(Path(roundedRect: body, cornerRadius: 4), with: .color(Color(white: 0.16)))
        context.stroke(Path(roundedRect: body, cornerRadius: 4), with: .color(Theme.border), lineWidth: 1.2)
        context.fill(Path(ellipseIn: CGRect(x: body.minX + 7, y: body.maxY - 13, width: 6, height: 6)), with: .color(Color(white: 0.55)))
        context.draw(
            Text(part.name).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(Color(white: 0.85)),
            at: CGPoint(x: body.midX, y: body.midY - 2),
            anchor: .center
        )
        let bottomX = [body.minX + 14, body.midX, body.maxX - 14]
        for (index, x) in bottomX.enumerated() {
            guard let item = pin(index + 1) else { continue }
            var lead = Path()
            lead.move(to: CGPoint(x: x, y: body.maxY))
            lead.addLine(to: CGPoint(x: x, y: body.maxY + 22))
            context.stroke(lead, with: .color(PinInk.color(item.role)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            numberBadge(context, item.number, at: CGPoint(x: x, y: body.maxY + 36), tint: PinInk.color(item.role))
            nameLabel(context, item, at: CGPoint(x: x, y: body.maxY + 56), anchor: .center)
        }
        let topPins: [(Int, CGFloat)] = [(5, body.minX + 14), (4, body.maxX - 14)]
        for (number, x) in topPins {
            guard let item = pin(number) else { continue }
            var lead = Path()
            lead.move(to: CGPoint(x: x, y: body.minY))
            lead.addLine(to: CGPoint(x: x, y: body.minY - 22))
            context.stroke(lead, with: .color(PinInk.color(item.role)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            numberBadge(context, item.number, at: CGPoint(x: x, y: body.minY - 36), tint: PinInk.color(item.role))
            nameLabel(context, item, at: CGPoint(x: x, y: body.minY - 56), anchor: .center)
        }
    }

    /// TO-220 and SOT-223 front views: tab on top, three leads underneath, left to right.
    private func drawTab(
        _ context: GraphicsContext,
        _ size: CGSize,
        bodyWidth: CGFloat,
        tabWidth: CGFloat,
        tabHeight: CGFloat,
        leadSpacing: CGFloat,
        hole: Bool
    ) {
        let top: CGFloat = part.tabNote == nil ? 34 : 44
        let tab = CGRect(x: (size.width - tabWidth) / 2, y: top, width: tabWidth, height: tabHeight)
        let body = CGRect(x: (size.width - bodyWidth) / 2, y: tab.maxY, width: bodyWidth, height: 62)
        context.fill(Path(roundedRect: tab, cornerRadius: 4), with: .color(Color(white: 0.62)))
        context.stroke(Path(roundedRect: tab, cornerRadius: 4), with: .color(Theme.border), lineWidth: 1.2)
        if hole {
            context.fill(Path(ellipseIn: CGRect(x: tab.midX - 8, y: tab.midY - 8, width: 16, height: 16)), with: .color(Theme.surfaceRaised))
        }
        context.fill(Path(roundedRect: body, cornerRadius: 4), with: .color(Color(white: 0.16)))
        context.stroke(Path(roundedRect: body, cornerRadius: 4), with: .color(Theme.border), lineWidth: 1.2)
        context.draw(
            Text(part.name).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color(white: 0.85)),
            at: CGPoint(x: body.midX, y: body.midY),
            anchor: .center
        )
        if let note = part.tabNote {
            context.draw(
                Text(note).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundColor(Theme.copper),
                at: CGPoint(x: tab.midX, y: tab.minY - 14),
                anchor: .center
            )
        }
        let xs = [body.midX - leadSpacing, body.midX, body.midX + leadSpacing]
        for (index, x) in xs.enumerated() {
            guard let item = pin(index + 1) else { continue }
            var lead = Path()
            lead.move(to: CGPoint(x: x, y: body.maxY))
            lead.addLine(to: CGPoint(x: x, y: body.maxY + 40))
            context.stroke(lead, with: .color(PinInk.color(item.role)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            numberBadge(context, item.number, at: CGPoint(x: x, y: body.maxY + 54), tint: PinInk.color(item.role))
            nameLabel(context, item, at: CGPoint(x: x, y: body.maxY + 74), anchor: .center)
        }
    }
}

/// Part picker plus the pinout drawing. The pick is remembered per family.
struct PartPinoutCard: View {
    let family: PartFamily
    var title: String = "Pinout"
    @AppStorage private var partID: String

    init(family: PartFamily, title: String = "Pinout") {
        self.family = family
        self.title = title
        let first = PartPinouts.parts(family: family).first?.id ?? ""
        _partID = AppStorage(wrappedValue: first, "partPinout.\(family.rawValue)")
    }

    private var parts: [PartPinout] { PartPinouts.parts(family: family) }

    private var part: PartPinout {
        parts.first { $0.id == partID } ?? parts[0]
    }

    var body: some View {
        DiagramCard(
            title: title,
            accessibilitySummary: "\(part.name) pinout. \(part.summary)",
            exportName: "pinout-\(part.id)"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                MenuField(title: "Part", selection: $partID, options: parts.map(\.id)) { id in
                    PartPinouts.part(id: id)?.name ?? id
                }
                Text(part.package.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                PartPinoutDiagram(part: part)
                Text(part.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Standard pinout for the common package. Check the data sheet for your exact suffix and package before you wire it.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("partPinout.\(family.rawValue)")
    }
}

// MARK: - Op-amp stage schematic

struct OpAmpStageSchematic: View {
    let topology: OpAmpTopology
    /// Component labels such as `["rin": "Rin 10 kΩ"]`. Missing keys fall back to the plain name.
    var labels: [String: String] = [:]
    /// Real package pin numbers for the part picked above the diagram. Nil draws the bare symbol.
    var pins: OpAmpPinNumbers?

    private func text(_ key: String, _ fallback: String) -> String {
        labels[key] ?? fallback
    }

    private var summary: String {
        if let pins {
            return "\(topology.displayName) op-amp stage schematic on a \(pins.name). IN− pin \(pins.minus), IN+ pin \(pins.plus), OUT pin \(pins.out), V+ pin \(pins.vPlus), V− pin \(pins.vMinus)."
        }
        return "\(topology.displayName) op-amp stage schematic."
    }

    var body: some View {
        DiagramCard(title: "\(topology.displayName) schematic", accessibilitySummary: summary, exportName: "opamp-\(topology.rawValue)") {
            Canvas { context, size in
                draw(Sch.fit(context, size: size, base: CGSize(width: 320, height: 190)))
            }
            .aspectRatio(320.0 / 190.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
        }
        .accessibilityIdentifier("opamp.schematic")
    }

    private func draw(_ c: GraphicsContext) {
        let amp = Sch.opAmp(c, center: CGPoint(x: 180, y: 100), width: 64, height: 64, pins: pins)
        // Output and its terminal.
        let outNode = CGPoint(x: 240, y: 100)
        Sch.wire(c, [amp.out, CGPoint(x: 296, y: 100)])
        Sch.dot(c, outNode)
        Sch.terminal(c, CGPoint(x: 296, y: 100))
        Sch.text(c, text("vout", "Vout"), CGPoint(x: 296, y: 86), size: 11)

        func ground(at point: CGPoint) { Sch.ground(c, at: point) }
        func feedbackTop(through part: String?, node: CGPoint) {
            // Out node up, across the top, down to the inverting node.
            Sch.wire(c, [outNode, CGPoint(x: 240, y: 36), CGPoint(x: 206, y: 36)])
            if part == "cap" {
                Sch.capacitor(c, from: CGPoint(x: 206, y: 36), to: CGPoint(x: 154, y: 36))
                Sch.text(c, text("c", "C"), CGPoint(x: 180, y: 20), size: 10.5, color: Theme.good)
            } else if part == "r" {
                Sch.resistor(c, from: CGPoint(x: 206, y: 36), to: CGPoint(x: 154, y: 36))
                Sch.text(c, text("rf", "Rf"), CGPoint(x: 180, y: 20), size: 10.5, color: Theme.good)
            } else {
                Sch.wire(c, [CGPoint(x: 206, y: 36), CGPoint(x: 154, y: 36)])
            }
            Sch.wire(c, [CGPoint(x: 154, y: 36), CGPoint(x: node.x, y: 36), node])
        }

        let minusNode = CGPoint(x: 120, y: amp.minus.y)
        let plusNode = CGPoint(x: 120, y: amp.plus.y)
        Sch.wire(c, [minusNode, amp.minus])
        Sch.wire(c, [plusNode, amp.plus])

        switch topology {
        case .inverting:
            Sch.terminal(c, CGPoint(x: 18, y: minusNode.y))
            Sch.text(c, text("vin", "Vin"), CGPoint(x: 18, y: minusNode.y - 14), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: minusNode.y), CGPoint(x: 34, y: minusNode.y)])
            Sch.resistor(c, from: CGPoint(x: 34, y: minusNode.y), to: CGPoint(x: 94, y: minusNode.y))
            Sch.wire(c, [CGPoint(x: 94, y: minusNode.y), minusNode])
            Sch.text(c, text("rin", "Rin"), CGPoint(x: 64, y: minusNode.y + 16), size: 10.5, color: Theme.good)
            Sch.dot(c, minusNode)
            feedbackTop(through: "r", node: minusNode)
            Sch.wire(c, [plusNode, CGPoint(x: plusNode.x, y: 150)])
            ground(at: CGPoint(x: plusNode.x, y: 150))
        case .noninverting:
            Sch.terminal(c, CGPoint(x: 18, y: plusNode.y))
            Sch.text(c, text("vin", "Vin"), CGPoint(x: 18, y: plusNode.y + 14), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: plusNode.y), plusNode])
            Sch.dot(c, minusNode)
            feedbackTop(through: "r", node: minusNode)
            // Rg from the inverting node down to ground, kept left of the + wire.
            Sch.wire(c, [minusNode, CGPoint(x: 78, y: minusNode.y)])
            Sch.resistor(c, from: CGPoint(x: 78, y: minusNode.y), to: CGPoint(x: 78, y: 150))
            Sch.ground(c, at: CGPoint(x: 78, y: 150))
            Sch.text(c, text("rg", "Rg"), CGPoint(x: 66, y: 120), anchor: .trailing, size: 10.5, color: Theme.good)
        case .follower:
            Sch.terminal(c, CGPoint(x: 18, y: plusNode.y))
            Sch.text(c, text("vin", "Vin"), CGPoint(x: 18, y: plusNode.y + 14), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: plusNode.y), plusNode])
            Sch.dot(c, minusNode)
            feedbackTop(through: nil, node: minusNode)
        case .difference:
            let top = minusNode
            let bottom = plusNode
            Sch.terminal(c, CGPoint(x: 18, y: top.y))
            Sch.text(c, text("v1", "V1"), CGPoint(x: 18, y: top.y - 14), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: top.y), CGPoint(x: 34, y: top.y)])
            Sch.resistor(c, from: CGPoint(x: 34, y: top.y), to: CGPoint(x: 94, y: top.y))
            Sch.wire(c, [CGPoint(x: 94, y: top.y), top])
            Sch.text(c, text("rin", "Rin"), CGPoint(x: 64, y: top.y - 14), size: 10.5, color: Theme.good)
            Sch.dot(c, top)
            feedbackTop(through: "r", node: top)
            Sch.terminal(c, CGPoint(x: 18, y: bottom.y))
            Sch.text(c, text("v2", "V2"), CGPoint(x: 18, y: bottom.y + 14), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: bottom.y), CGPoint(x: 34, y: bottom.y)])
            Sch.resistor(c, from: CGPoint(x: 34, y: bottom.y), to: CGPoint(x: 94, y: bottom.y))
            Sch.wire(c, [CGPoint(x: 94, y: bottom.y), bottom])
            Sch.text(c, text("rin", "Rin"), CGPoint(x: 64, y: bottom.y + 16), size: 10.5, color: Theme.good)
            Sch.dot(c, bottom)
            Sch.resistor(c, from: CGPoint(x: bottom.x, y: bottom.y), to: CGPoint(x: bottom.x, y: 156))
            Sch.ground(c, at: CGPoint(x: bottom.x, y: 156))
            Sch.text(c, text("rf", "Rf"), CGPoint(x: bottom.x + 8, y: 142), anchor: .leading, size: 10.5, color: Theme.good)
        case .summing:
            let bus = CGPoint(x: 126, y: minusNode.y)
            Sch.wire(c, [minusNode, bus])
            Sch.terminal(c, CGPoint(x: 18, y: 58))
            Sch.text(c, text("v1", "V1"), CGPoint(x: 18, y: 44), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: 58), CGPoint(x: 34, y: 58)])
            Sch.resistor(c, from: CGPoint(x: 34, y: 58), to: CGPoint(x: 100, y: 58))
            Sch.wire(c, [CGPoint(x: 100, y: 58), CGPoint(x: bus.x, y: 58), bus])
            Sch.text(c, text("r1", "R1"), CGPoint(x: 67, y: 70), size: 10.5, color: Theme.good)
            Sch.terminal(c, CGPoint(x: 18, y: 108))
            Sch.text(c, text("v2", "V2"), CGPoint(x: 18, y: 122), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: 108), CGPoint(x: 34, y: 108)])
            Sch.resistor(c, from: CGPoint(x: 34, y: 108), to: CGPoint(x: 100, y: 108))
            Sch.wire(c, [CGPoint(x: 100, y: 108), CGPoint(x: bus.x, y: 108), bus])
            Sch.text(c, text("r2", "R2"), CGPoint(x: 67, y: 122), size: 10.5, color: Theme.good)
            Sch.dot(c, bus)
            Sch.dot(c, CGPoint(x: bus.x, y: 58))
            feedbackTop(through: "r", node: CGPoint(x: bus.x, y: 58))
            Sch.wire(c, [plusNode, CGPoint(x: plusNode.x, y: 150)])
            ground(at: CGPoint(x: plusNode.x, y: 150))
        case .integrator:
            Sch.terminal(c, CGPoint(x: 18, y: minusNode.y))
            Sch.text(c, text("vin", "Vin"), CGPoint(x: 18, y: minusNode.y - 14), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: minusNode.y), CGPoint(x: 34, y: minusNode.y)])
            Sch.resistor(c, from: CGPoint(x: 34, y: minusNode.y), to: CGPoint(x: 94, y: minusNode.y))
            Sch.wire(c, [CGPoint(x: 94, y: minusNode.y), minusNode])
            Sch.text(c, text("rin", "Rin"), CGPoint(x: 64, y: minusNode.y + 16), size: 10.5, color: Theme.good)
            Sch.dot(c, minusNode)
            feedbackTop(through: "cap", node: minusNode)
            Sch.wire(c, [plusNode, CGPoint(x: plusNode.x, y: 150)])
            ground(at: CGPoint(x: plusNode.x, y: 150))
        case .differentiator:
            Sch.terminal(c, CGPoint(x: 18, y: minusNode.y))
            Sch.text(c, text("vin", "Vin"), CGPoint(x: 18, y: minusNode.y - 14), size: 11)
            Sch.wire(c, [CGPoint(x: 18, y: minusNode.y), CGPoint(x: 40, y: minusNode.y)])
            Sch.capacitor(c, from: CGPoint(x: 40, y: minusNode.y), to: CGPoint(x: 94, y: minusNode.y))
            Sch.wire(c, [CGPoint(x: 94, y: minusNode.y), minusNode])
            Sch.text(c, text("c", "C"), CGPoint(x: 67, y: minusNode.y + 16), size: 10.5, color: Theme.good)
            Sch.dot(c, minusNode)
            feedbackTop(through: "r", node: minusNode)
            Sch.wire(c, [plusNode, CGPoint(x: plusNode.x, y: 150)])
            ground(at: CGPoint(x: plusNode.x, y: 150))
        }
    }
}

// MARK: - Instrumentation amp schematic

/// Classic 3-op-amp instrumentation amplifier, or the single-amp difference stage.
struct InstrumentationAmpSchematic: View {
    let mode: InAmpMode
    /// Plain values such as "25 kΩ". Empty draws the bare symbol.
    var rText = ""
    var rgText = ""
    var gainText: String?

    private var rLabel: String { rText.isEmpty ? "R" : "R \(rText)" }
    private var rgLabel: String { rgText.isEmpty ? "Rg" : "Rg \(rgText)" }

    private var summary: String {
        switch mode {
        case .threeOpAmp:
            return "Three op-amp instrumentation amplifier. Gain resistor Rg joins the two input stages, and a difference stage subtracts them. \(gainText.map { "Gain \($0)." } ?? "")"
        case .difference:
            return "Four-resistor difference amplifier."
        }
    }

    var body: some View {
        if mode == .difference {
            OpAmpStageSchematic(topology: .difference, labels: [
                "rin": rgText.isEmpty ? "Rin" : "Rin \(rgText)",
                "rf": rText.isEmpty ? "Rf" : "Rf \(rText)",
            ])
        } else {
            DiagramCard(title: "3-op-amp InAmp", accessibilitySummary: summary, exportName: "inamp-three-opamp") {
                VStack(alignment: .leading, spacing: 6) {
                    Canvas { context, size in
                        draw(Sch.fit(context, size: size, base: CGSize(width: 340, height: 196)))
                    }
                    .aspectRatio(340.0 / 196.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    if let gainText {
                        Text("G = 1 + 2R / Rg = \(gainText)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.good)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(summary)
            }
            .accessibilityIdentifier("inamp.schematic")
        }
    }

    private func draw(_ c: GraphicsContext) {
        let a1 = Sch.opAmp(c, center: CGPoint(x: 100, y: 52), width: 56, height: 56, flipped: true)
        let a2 = Sch.opAmp(c, center: CGPoint(x: 100, y: 148), width: 56, height: 56)
        let a3 = Sch.opAmp(c, center: CGPoint(x: 252, y: 100), width: 56, height: 56)

        // Inputs.
        Sch.terminal(c, CGPoint(x: 14, y: a1.plus.y))
        Sch.text(c, "V1", CGPoint(x: 14, y: a1.plus.y - 13), size: 11)
        Sch.wire(c, [CGPoint(x: 14, y: a1.plus.y), a1.plus])
        Sch.terminal(c, CGPoint(x: 14, y: a2.plus.y))
        Sch.text(c, "V2", CGPoint(x: 14, y: a2.plus.y + 13), size: 11)
        Sch.wire(c, [CGPoint(x: 14, y: a2.plus.y), a2.plus])

        // Gain resistor between the two inverting inputs.
        let minusTop = CGPoint(x: 50, y: a1.minus.y)
        let minusBottom = CGPoint(x: 50, y: a2.minus.y)
        Sch.wire(c, [minusTop, a1.minus])
        Sch.wire(c, [minusBottom, a2.minus])
        Sch.resistor(c, from: minusTop, to: minusBottom)
        Sch.dot(c, minusTop)
        Sch.dot(c, minusBottom)
        Sch.text(c, rgLabel, CGPoint(x: 44, y: 100), anchor: .trailing, size: 10.5, color: Theme.good)

        // Feedback resistors under A1 and above A2.
        let fbTopY = a1.minus.y + 18
        let fbBottomY = a2.minus.y - 18
        Sch.wire(c, [a1.out, CGPoint(x: 140, y: a1.out.y), CGPoint(x: 140, y: fbTopY), CGPoint(x: 124, y: fbTopY)])
        Sch.resistor(c, from: CGPoint(x: 124, y: fbTopY), to: CGPoint(x: 76, y: fbTopY))
        Sch.wire(c, [CGPoint(x: 76, y: fbTopY), CGPoint(x: 62, y: fbTopY), CGPoint(x: 62, y: a1.minus.y)])
        Sch.dot(c, CGPoint(x: 62, y: a1.minus.y))
        Sch.text(c, rLabel, CGPoint(x: 100, y: fbTopY + 14), size: 10.5, color: Theme.good)
        Sch.wire(c, [a2.out, CGPoint(x: 140, y: a2.out.y), CGPoint(x: 140, y: fbBottomY), CGPoint(x: 124, y: fbBottomY)])
        Sch.resistor(c, from: CGPoint(x: 124, y: fbBottomY), to: CGPoint(x: 76, y: fbBottomY))
        Sch.wire(c, [CGPoint(x: 76, y: fbBottomY), CGPoint(x: 62, y: fbBottomY), CGPoint(x: 62, y: a2.minus.y)])
        Sch.dot(c, CGPoint(x: 62, y: a2.minus.y))
        Sch.text(c, rLabel, CGPoint(x: 100, y: fbBottomY - 14), size: 10.5, color: Theme.good)
        Sch.dot(c, CGPoint(x: 140, y: a1.out.y))
        Sch.dot(c, CGPoint(x: 140, y: a2.out.y))

        // Output stage inputs.
        let joinX: CGFloat = 206
        Sch.wire(c, [CGPoint(x: 140, y: a1.out.y), CGPoint(x: 152, y: a1.out.y)])
        Sch.resistor(c, from: CGPoint(x: 152, y: a1.out.y), to: CGPoint(x: 188, y: a1.out.y))
        Sch.wire(c, [CGPoint(x: 188, y: a1.out.y), CGPoint(x: joinX, y: a1.out.y), CGPoint(x: joinX, y: a3.minus.y), a3.minus])
        Sch.text(c, "R3", CGPoint(x: 170, y: a1.out.y - 12), size: 10, color: Theme.good)
        Sch.dot(c, CGPoint(x: joinX, y: a1.out.y))
        Sch.wire(c, [CGPoint(x: 140, y: a2.out.y), CGPoint(x: 152, y: a2.out.y)])
        Sch.resistor(c, from: CGPoint(x: 152, y: a2.out.y), to: CGPoint(x: 188, y: a2.out.y))
        Sch.wire(c, [CGPoint(x: 188, y: a2.out.y), CGPoint(x: joinX, y: a2.out.y), CGPoint(x: joinX, y: a3.plus.y), a3.plus])
        Sch.text(c, "R3", CGPoint(x: 170, y: a2.out.y + 12), size: 10, color: Theme.good)

        // Reference leg from the + input of the output stage.
        let refX: CGFloat = 214
        Sch.dot(c, CGPoint(x: refX, y: a3.plus.y))
        Sch.resistor(c, from: CGPoint(x: refX, y: a3.plus.y), to: CGPoint(x: refX, y: 160))
        Sch.terminal(c, CGPoint(x: refX, y: 168))
        Sch.wire(c, [CGPoint(x: refX, y: 160), CGPoint(x: refX, y: 168)])
        Sch.text(c, "REF", CGPoint(x: refX + 8, y: 174), anchor: .leading, size: 10.5)
        Sch.text(c, "R3", CGPoint(x: refX + 8, y: 138), anchor: .leading, size: 10, color: Theme.good)

        // Output stage feedback and output.
        let outNode = CGPoint(x: 290, y: a3.out.y)
        Sch.wire(c, [a3.out, CGPoint(x: 322, y: a3.out.y)])
        Sch.dot(c, outNode)
        Sch.terminal(c, CGPoint(x: 322, y: a3.out.y))
        Sch.text(c, "Vout", CGPoint(x: 322, y: a3.out.y - 14), size: 11)
        Sch.wire(c, [outNode, CGPoint(x: 290, y: 24), CGPoint(x: 262, y: 24)])
        Sch.resistor(c, from: CGPoint(x: 262, y: 24), to: CGPoint(x: 220, y: 24))
        Sch.wire(c, [CGPoint(x: 220, y: 24), CGPoint(x: joinX, y: 24), CGPoint(x: joinX, y: a1.out.y)])
        Sch.text(c, "R3", CGPoint(x: 241, y: 11), size: 10, color: Theme.good)
    }
}

// MARK: - Regulator schematic

/// Adjustable (LM317-style) regulator with its divider, caps, and load.
struct RegulatorSchematic: View {
    var vin: String
    var vout: String
    var r1: String
    var r2: String
    var detail: String?

    private var summary: String {
        "Adjustable linear regulator schematic. Input \(vin), output \(vout). R1 \(r1) from output to adjust, R2 \(r2) from adjust to ground."
    }

    var body: some View {
        DiagramCard(title: "Regulator schematic", accessibilitySummary: summary, exportName: "regulator-schematic") {
            VStack(alignment: .leading, spacing: 6) {
                Canvas { context, size in
                    draw(Sch.fit(context, size: size, base: CGSize(width: 330, height: 190)))
                }
                .aspectRatio(330.0 / 190.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                if let detail {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
        }
        .accessibilityIdentifier("regulator.schematic")
    }

    private func draw(_ c: GraphicsContext) {
        let block = CGRect(x: 112, y: 36, width: 86, height: 62)
        c.fill(Path(roundedRect: block, cornerRadius: 6), with: .color(Theme.surfaceRaised))
        c.stroke(Path(roundedRect: block, cornerRadius: 6), with: .color(Theme.foreground), lineWidth: 1.6)
        Sch.text(c, "REG", CGPoint(x: block.midX, y: block.midY - 6), size: 13, weight: .bold)
        Sch.text(c, "LM317 / LDO", CGPoint(x: block.midX, y: block.midY + 10), size: 9.5, weight: .medium, color: Theme.muted)
        let inPin = CGPoint(x: block.minX, y: 58)
        let outPin = CGPoint(x: block.maxX, y: 58)
        let adjPin = CGPoint(x: block.midX, y: block.maxY)
        Sch.text(c, "IN", CGPoint(x: block.minX + 6, y: 58), anchor: .leading, size: 9.5, weight: .medium, color: Theme.muted)
        Sch.text(c, "OUT", CGPoint(x: block.maxX - 6, y: 58), anchor: .trailing, size: 9.5, weight: .medium, color: Theme.muted)
        Sch.text(c, "ADJ", CGPoint(x: block.midX, y: block.maxY - 8), size: 9.5, weight: .medium, color: Theme.muted)

        // Input side.
        Sch.terminal(c, CGPoint(x: 16, y: 58))
        Sch.text(c, "Vin", CGPoint(x: 16, y: 44), size: 11)
        Sch.text(c, vin, CGPoint(x: 16, y: 74), size: 10, weight: .medium, color: Theme.muted)
        Sch.wire(c, [CGPoint(x: 16, y: 58), inPin])
        Sch.dot(c, CGPoint(x: 62, y: 58))
        Sch.capacitor(c, from: CGPoint(x: 62, y: 58), to: CGPoint(x: 62, y: 112))
        Sch.ground(c, at: CGPoint(x: 62, y: 112))
        Sch.text(c, "Cin", CGPoint(x: 72, y: 88), anchor: .leading, size: 10, color: Theme.good)

        // Output side.
        let outNode = CGPoint(x: 226, y: 58)
        Sch.wire(c, [outPin, CGPoint(x: 316, y: 58)])
        Sch.dot(c, outNode)
        Sch.terminal(c, CGPoint(x: 316, y: 58))
        Sch.text(c, "Vout", CGPoint(x: 316, y: 44), size: 11)
        Sch.text(c, vout, CGPoint(x: 316, y: 74), size: 10, weight: .medium, color: Theme.good)
        Sch.dot(c, CGPoint(x: 276, y: 58))
        Sch.capacitor(c, from: CGPoint(x: 276, y: 58), to: CGPoint(x: 276, y: 112))
        Sch.ground(c, at: CGPoint(x: 276, y: 112))
        Sch.text(c, "Cout", CGPoint(x: 286, y: 100), anchor: .leading, size: 10, color: Theme.good)

        // Divider: R1 from OUT to ADJ, R2 from ADJ to ground.
        let adjNode = CGPoint(x: adjPin.x, y: 122)
        Sch.resistor(c, from: outNode, to: CGPoint(x: 226, y: 116))
        Sch.wire(c, [CGPoint(x: 226, y: 116), CGPoint(x: 226, y: 122), adjNode])
        Sch.wire(c, [adjPin, adjNode])
        Sch.dot(c, adjNode)
        Sch.resistor(c, from: adjNode, to: CGPoint(x: adjNode.x, y: 168))
        Sch.ground(c, at: CGPoint(x: adjNode.x, y: 168))
        Sch.text(c, "R1 \(r1)", CGPoint(x: 234, y: 92), anchor: .leading, size: 10.5, color: Theme.good)
        Sch.text(c, "R2 \(r2)", CGPoint(x: adjNode.x + 8, y: 146), anchor: .leading, size: 10.5, color: Theme.good)
    }
}

// MARK: - Filter schematic

/// Schematic for each Analog Workbench filter family, drawn with the same part values as the board.
struct FilterSchematic: View {
    let family: AnalogFilterFamily
    var rText = ""
    var cText = ""
    /// Sallen–Key gain network, for example "Rb 5.86 kΩ / Ra 10 kΩ". Empty when K = 1.
    var gainText = ""
    var pins: OpAmpPinNumbers?

    private var r: String { rText.isEmpty ? "R" : "R \(rText)" }
    private var c: String { cText.isEmpty ? "C" : "C \(cText)" }

    private var summary: String {
        var base = "\(family.displayName) schematic."
        if let pins, WorkbenchBoards.filterUsesOpAmp(family) {
            base += " Op-amp \(pins.name): IN− pin \(pins.minus), IN+ pin \(pins.plus), OUT pin \(pins.out)."
        }
        return base
    }

    var body: some View {
        DiagramCard(title: "\(family.displayName) schematic", accessibilitySummary: summary, exportName: "filter-\(family.rawValue)") {
            Canvas { context, size in
                draw(Sch.fit(context, size: size, base: CGSize(width: 320, height: 200)))
            }
            .aspectRatio(320.0 / 200.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
        }
        .accessibilityIdentifier("filter.schematic")
    }

    private func label(_ c: GraphicsContext, _ string: String, _ point: CGPoint, anchor: UnitPoint = .center) {
        Sch.text(c, string, point, anchor: anchor, size: 10.5, color: Theme.good)
    }

    private func draw(_ c: GraphicsContext) {
        switch family {
        case .rcLowpass, .rcHighpass: drawRC(c, lowpass: family == .rcLowpass)
        case .sallenKeyLowpass, .sallenKeyHighpass: drawSallenKey(c, lowpass: family == .sallenKeyLowpass)
        case .twinTNotch: drawTwinT(c)
        case .firstOrderAllpass: drawAllpass(c)
        }
    }

    private func vin(_ c: GraphicsContext, _ point: CGPoint) {
        Sch.terminal(c, point)
        Sch.text(c, "Vin", CGPoint(x: point.x, y: point.y - 14), size: 11)
    }

    private func vout(_ c: GraphicsContext, _ point: CGPoint) {
        Sch.terminal(c, point)
        Sch.text(c, "Vout", CGPoint(x: point.x, y: point.y - 14), size: 11)
    }

    private func drawRC(_ ctx: GraphicsContext, lowpass: Bool) {
        let y: CGFloat = 80
        vin(ctx, CGPoint(x: 20, y: y))
        Sch.wire(ctx, [CGPoint(x: 20, y: y), CGPoint(x: 46, y: y)])
        let node = CGPoint(x: 190, y: y)
        if lowpass {
            Sch.resistor(ctx, from: CGPoint(x: 46, y: y), to: CGPoint(x: 150, y: y))
            label(ctx, r, CGPoint(x: 98, y: y - 16))
            Sch.wire(ctx, [CGPoint(x: 150, y: y), node])
            Sch.capacitor(ctx, from: node, to: CGPoint(x: node.x, y: 138))
            label(ctx, c, CGPoint(x: node.x + 10, y: 112), anchor: .leading)
        } else {
            Sch.capacitor(ctx, from: CGPoint(x: 46, y: y), to: CGPoint(x: 150, y: y))
            label(ctx, c, CGPoint(x: 98, y: y - 16))
            Sch.wire(ctx, [CGPoint(x: 150, y: y), node])
            Sch.resistor(ctx, from: node, to: CGPoint(x: node.x, y: 138))
            label(ctx, r, CGPoint(x: node.x + 10, y: 112), anchor: .leading)
        }
        Sch.ground(ctx, at: CGPoint(x: node.x, y: 138))
        Sch.dot(ctx, node)
        Sch.wire(ctx, [node, CGPoint(x: 296, y: y)])
        vout(ctx, CGPoint(x: 296, y: y))
    }

    private func drawTwinT(_ ctx: GraphicsContext) {
        let mid: CGFloat = 100
        vin(ctx, CGPoint(x: 18, y: mid))
        let node = CGPoint(x: 30, y: mid)
        Sch.wire(ctx, [CGPoint(x: 18, y: mid), node])
        Sch.dot(ctx, node)
        let out = CGPoint(x: 196, y: mid)
        // Top T: R, R and 2C to ground.
        Sch.wire(ctx, [node, CGPoint(x: 30, y: 45), CGPoint(x: 46, y: 45)])
        Sch.resistor(ctx, from: CGPoint(x: 46, y: 45), to: CGPoint(x: 98, y: 45))
        Sch.dot(ctx, CGPoint(x: 110, y: 45))
        Sch.wire(ctx, [CGPoint(x: 98, y: 45), CGPoint(x: 122, y: 45)])
        Sch.resistor(ctx, from: CGPoint(x: 122, y: 45), to: CGPoint(x: 172, y: 45))
        Sch.wire(ctx, [CGPoint(x: 172, y: 45), CGPoint(x: out.x, y: 45), out])
        Sch.capacitor(ctx, from: CGPoint(x: 110, y: 45), to: CGPoint(x: 110, y: 78))
        Sch.ground(ctx, at: CGPoint(x: 110, y: 78))
        label(ctx, r, CGPoint(x: 72, y: 31), anchor: .center)
        label(ctx, r, CGPoint(x: 147, y: 31), anchor: .center)
        label(ctx, "2C", CGPoint(x: 120, y: 66), anchor: .leading)
        // Bottom T: C, C and R/2 to ground.
        Sch.wire(ctx, [node, CGPoint(x: 30, y: 150), CGPoint(x: 46, y: 150)])
        Sch.capacitor(ctx, from: CGPoint(x: 46, y: 150), to: CGPoint(x: 98, y: 150))
        Sch.dot(ctx, CGPoint(x: 110, y: 150))
        Sch.wire(ctx, [CGPoint(x: 98, y: 150), CGPoint(x: 122, y: 150)])
        Sch.capacitor(ctx, from: CGPoint(x: 122, y: 150), to: CGPoint(x: 172, y: 150))
        Sch.wire(ctx, [CGPoint(x: 172, y: 150), CGPoint(x: out.x, y: 150), out])
        Sch.resistor(ctx, from: CGPoint(x: 110, y: 150), to: CGPoint(x: 110, y: 182))
        Sch.ground(ctx, at: CGPoint(x: 110, y: 182))
        label(ctx, c, CGPoint(x: 72, y: 136))
        label(ctx, c, CGPoint(x: 147, y: 136))
        label(ctx, "R/2", CGPoint(x: 120, y: 168), anchor: .leading)
        Sch.dot(ctx, out)
        Sch.wire(ctx, [out, CGPoint(x: 296, y: mid)])
        vout(ctx, CGPoint(x: 296, y: mid))
    }

    private func drawAllpass(_ ctx: GraphicsContext) {
        let amp = Sch.opAmp(ctx, center: CGPoint(x: 210, y: 95), width: 60, height: 60, pins: pins)
        vin(ctx, CGPoint(x: 18, y: 95))
        let node = CGPoint(x: 30, y: 95)
        Sch.wire(ctx, [CGPoint(x: 18, y: 95), node])
        Sch.dot(ctx, node)
        // Inverting side: Ra in, Rb feedback.
        Sch.wire(ctx, [node, CGPoint(x: 30, y: 80), CGPoint(x: 44, y: 80)])
        Sch.resistor(ctx, from: CGPoint(x: 44, y: 80), to: CGPoint(x: 110, y: 80))
        Sch.wire(ctx, [CGPoint(x: 110, y: 80), CGPoint(x: 150, y: 80), amp.minus])
        Sch.dot(ctx, CGPoint(x: 150, y: 80))
        label(ctx, "Ra \(rText)", CGPoint(x: 77, y: 66))
        let outNode = CGPoint(x: 262, y: 95)
        Sch.wire(ctx, [amp.out, CGPoint(x: 296, y: 95)])
        Sch.dot(ctx, outNode)
        Sch.wire(ctx, [CGPoint(x: 150, y: 80), CGPoint(x: 150, y: 36), CGPoint(x: 176, y: 36)])
        Sch.resistor(ctx, from: CGPoint(x: 176, y: 36), to: CGPoint(x: 236, y: 36))
        Sch.wire(ctx, [CGPoint(x: 236, y: 36), CGPoint(x: 262, y: 36), outNode])
        label(ctx, "Rb \(rText)", CGPoint(x: 206, y: 22))
        // Non-inverting side: R in, C to ground.
        Sch.wire(ctx, [node, CGPoint(x: 30, y: 110), CGPoint(x: 44, y: 110)])
        Sch.resistor(ctx, from: CGPoint(x: 44, y: 110), to: CGPoint(x: 120, y: 110))
        Sch.wire(ctx, [CGPoint(x: 120, y: 110), CGPoint(x: 150, y: 110), amp.plus])
        Sch.dot(ctx, CGPoint(x: 132, y: 110))
        Sch.capacitor(ctx, from: CGPoint(x: 132, y: 110), to: CGPoint(x: 132, y: 156))
        Sch.ground(ctx, at: CGPoint(x: 132, y: 156))
        label(ctx, r, CGPoint(x: 82, y: 126))
        label(ctx, c, CGPoint(x: 142, y: 138), anchor: .leading)
        vout(ctx, CGPoint(x: 296, y: 95))
    }

    /// Vin → R1 → A → R2 → IN+. The feedback part runs from A to Vout. The shunt part runs from IN+ to ground.
    /// Ra and Rb set the gain K from the − input.
    private func drawSallenKey(_ ctx: GraphicsContext, lowpass: Bool) {
        let amp = Sch.opAmp(ctx, center: CGPoint(x: 196, y: 74), width: 60, height: 60, flipped: true, pins: pins)
        let y = amp.plus.y
        vin(ctx, CGPoint(x: 16, y: y))
        Sch.wire(ctx, [CGPoint(x: 16, y: y), CGPoint(x: 26, y: y)])
        let junction = CGPoint(x: 92, y: y)
        let plusNode = CGPoint(x: 150, y: y)
        let outNode = CGPoint(x: 252, y: amp.out.y)
        func series(_ from: CGPoint, _ to: CGPoint, resistor: Bool, text: String) {
            if resistor { Sch.resistor(ctx, from: from, to: to) } else { Sch.capacitor(ctx, from: from, to: to) }
            label(ctx, text, CGPoint(x: (from.x + to.x) / 2, y: from.y - 15))
        }
        // Each part carries its value so the schematic is enough to build from.
        let rv = rText.isEmpty ? "" : " \(rText)"
        let cv = cText.isEmpty ? "" : " \(cText)"
        // Series arm, then the junction.
        series(CGPoint(x: 26, y: y), CGPoint(x: 80, y: y), resistor: lowpass, text: lowpass ? "R1\(rv)" : "C1\(cv)")
        Sch.wire(ctx, [CGPoint(x: 80, y: y), junction, CGPoint(x: 104, y: y)])
        Sch.dot(ctx, junction)
        series(CGPoint(x: 104, y: y), CGPoint(x: 142, y: y), resistor: lowpass, text: lowpass ? "R2\(rv)" : "C2\(cv)")
        Sch.wire(ctx, [CGPoint(x: 142, y: y), plusNode, amp.plus])
        Sch.dot(ctx, plusNode)
        // Shunt from IN+ to ground.
        let groundY: CGFloat = 150
        if lowpass {
            Sch.capacitor(ctx, from: plusNode, to: CGPoint(x: plusNode.x, y: groundY))
            label(ctx, "C2\(cv)", CGPoint(x: plusNode.x - 8, y: 104), anchor: .trailing)
        } else {
            Sch.resistor(ctx, from: plusNode, to: CGPoint(x: plusNode.x, y: groundY))
            label(ctx, "R2\(rv)", CGPoint(x: plusNode.x - 8, y: 104), anchor: .trailing)
        }
        Sch.ground(ctx, at: CGPoint(x: plusNode.x, y: groundY))
        // Feedback from the junction over the top to Vout.
        Sch.wire(ctx, [junction, CGPoint(x: junction.x, y: 22), CGPoint(x: 130, y: 22)])
        if lowpass {
            Sch.capacitor(ctx, from: CGPoint(x: 130, y: 22), to: CGPoint(x: 176, y: 22))
            label(ctx, "C1\(cv)", CGPoint(x: 153, y: 9))
        } else {
            Sch.resistor(ctx, from: CGPoint(x: 130, y: 22), to: CGPoint(x: 176, y: 22))
            label(ctx, "R1\(rv)", CGPoint(x: 153, y: 9))
        }
        Sch.wire(ctx, [CGPoint(x: 176, y: 22), CGPoint(x: outNode.x, y: 22), outNode])
        Sch.wire(ctx, [amp.out, CGPoint(x: 296, y: amp.out.y)])
        Sch.dot(ctx, outNode)
        vout(ctx, CGPoint(x: 296, y: amp.out.y))
        // Gain network from the − input.
        if gainText.isEmpty {
            Sch.wire(ctx, [amp.minus, CGPoint(x: 166, y: amp.minus.y), CGPoint(x: 166, y: 126), CGPoint(x: outNode.x, y: 126), outNode])
            Sch.text(ctx, "K = 1", CGPoint(x: 210, y: 140), size: 10.5, color: Theme.good)
        } else {
            let tap = CGPoint(x: 166, y: 126)
            Sch.wire(ctx, [amp.minus, CGPoint(x: 166, y: amp.minus.y), tap])
            Sch.dot(ctx, tap)
            Sch.resistor(ctx, from: tap, to: CGPoint(x: 232, y: 126))
            Sch.wire(ctx, [CGPoint(x: 232, y: 126), CGPoint(x: outNode.x, y: 126), outNode])
            Sch.resistor(ctx, from: tap, to: CGPoint(x: tap.x, y: 186))
            Sch.ground(ctx, at: CGPoint(x: tap.x, y: 186))
            Sch.text(ctx, "Rb", CGPoint(x: 199, y: 140), size: 10.5, color: Theme.good)
            Sch.text(ctx, "Ra", CGPoint(x: tap.x + 8, y: 158), anchor: .leading, size: 10.5, color: Theme.good)
            Sch.text(ctx, gainText, CGPoint(x: 296, y: 176), anchor: .trailing, size: 9.5, weight: .semibold, color: Theme.muted)
        }
    }
}
