import SwiftUI
import BeckifyMath

struct BreadboardCard: View {
    var layout: BreadboardLayout
    var annotationLayer: LabAnnotationLayer = .values
    var selectedComponentID: String? = nil
    var highlightedNets: Set<String> = []
    var onSelectComponent: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("BREADBOARD")
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                PlotFullscreenControl(title: "Breadboard", plotName: "breadboard") {
                    BreadboardFitView(layout: layout, baseHeight: 420, annotationLayer: annotationLayer, selectedComponentID: selectedComponentID, highlightedNets: highlightedNets, onSelectComponent: onSelectComponent)
                    meterStrip
                    Text(layout.caption)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(layout.caption)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            BreadboardFitView(layout: layout, baseHeight: 220, annotationLayer: annotationLayer, selectedComponentID: selectedComponentID, highlightedNets: highlightedNets, onSelectComponent: onSelectComponent)
                .accessibilityIdentifier("electronicsLab.breadboard")
            meterStrip
            Text("Whole board on open. Pinch to zoom, drag when zoomed, double-tap to reset. Tap a part to inspect. Dense readings stay in the inspector.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private var meterStrip: some View {
        let line = BreadboardMeters.summaryLine(layout.meters)
        if !line.isEmpty {
            Text(line)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                )
                .accessibilityIdentifier("electronicsLab.breadboard.meters")
                .accessibilityLabel("Readings \(line)")
        }
    }
}

/// Fits the full solderless board into the available width, then allows pinch/pan.
struct BreadboardFitView: View {
    var layout: BreadboardLayout
    var baseHeight: CGFloat
    var annotationLayer: LabAnnotationLayer = .values
    var selectedComponentID: String? = nil
    var highlightedNets: Set<String> = []
    var onSelectComponent: ((String) -> Void)? = nil

    @State private var zoom: CGFloat = 1
    @State private var liveZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panOrigin: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let fitted = Self.fitPitch(forWidth: geo.size.width, height: geo.size.height)
            let picture = BreadboardPicture(layout: layout, pitch: fitted, annotationLayer: annotationLayer, selectedComponentID: selectedComponentID, highlightedNets: highlightedNets)
            let size = BreadboardPaint.size(pitch: fitted)
            let framed = picture
                .frame(width: size.width, height: size.height)
                .scaleEffect(zoom * liveZoom, anchor: .center)
                .offset(pan)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(magnify)
                .onTapGesture(count: 2) {
                    zoom = 1
                    liveZoom = 1
                    pan = .zero
                    panOrigin = .zero
                }
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        guard let onSelectComponent else { return }
                        if let id = BreadboardPaint.hitComponent(
                            layout,
                            at: value.location,
                            pitch: fitted,
                            viewSize: geo.size,
                            zoom: zoom * liveZoom,
                            pan: pan
                        ) {
                            onSelectComponent(id)
                        }
                    }
                )
            Group {
                if zoom > 1.02 {
                    framed.simultaneousGesture(panGesture)
                } else {
                    framed
                }
            }
        }
        .frame(height: baseHeight)
        .clipped()
        .background(Theme.surface.opacity(0.35), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .accessibilityHint("Shows the whole breadboard. Pinch to zoom. Double-tap to reset.")
    }

    private static func fitPitch(forWidth width: CGFloat, height: CGFloat) -> CGFloat {
        // size = (92 + columns*pitch + 16, 28 + 15.4*pitch + 20)
        let pad: CGFloat = 8
        let usableW = max(width - pad * 2, 40)
        let usableH = max(height - pad * 2, 40)
        let pitchW = (usableW - 92 - 16) / CGFloat(BreadboardBoard.columns)
        let pitchH = (usableH - 28 - 20) / 15.4
        return max(4.5, min(pitchW, pitchH, 22))
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { liveZoom = $0 }
            .onEnded { value in
                zoom = min(4, max(1, zoom * value))
                liveZoom = 1
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                pan = CGSize(
                    width: panOrigin.width + value.translation.width,
                    height: panOrigin.height + value.translation.height
                )
            }
            .onEnded { _ in
                panOrigin = pan
            }
    }
}

struct BreadboardPicture: View {
    var layout: BreadboardLayout
    var pitch: CGFloat
    var annotationLayer: LabAnnotationLayer = .values
    var selectedComponentID: String? = nil
    var highlightedNets: Set<String> = []

    var body: some View {
        let size = BreadboardPaint.size(pitch: pitch)
        Canvas { context, _ in
            BreadboardPaint.draw(
                layout,
                in: context,
                pitch: pitch,
                annotationLayer: annotationLayer,
                selectedComponentID: selectedComponentID,
                highlightedNets: highlightedNets
            )
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BreadboardPaint.summary(layout))
    }
}

enum BreadboardPaint {
    static func size(pitch: CGFloat) -> CGSize {
        CGSize(width: 92 + CGFloat(BreadboardBoard.columns) * pitch + 16, height: 28 + 15.4 * pitch + 20)
    }

    static func summary(_ layout: BreadboardLayout) -> String {
        let parts = layout.components.map { partName($0, layer: .values) }.joined(separator: ", ")
        let meters = BreadboardMeters.summaryLine(layout.meters)
        let meterBit = meters.isEmpty ? "" : " Readings: \(meters)."
        return "Breadboard. \(parts). \(layout.caption)\(meterBit)"
    }

    static func draw(
        _ layout: BreadboardLayout,
        in context: GraphicsContext,
        pitch: CGFloat,
        annotationLayer: LabAnnotationLayer = .values,
        selectedComponentID: String? = nil,
        highlightedNets: Set<String> = []
    ) {
        let map = Map(pitch: pitch)
        drawBoard(in: context, map: map)
        drawRails(layout, in: context, map: map)
        drawHoles(columns: layout.columns, in: context, map: map)
        drawIndexes(columns: layout.columns, in: context, map: map)
        for supply in layout.supplies {
            drawSupply(supply, in: context, map: map)
        }
        for jumper in layout.jumpers {
            drawJumper(jumper, in: context, map: map, emphasized: highlightedNets.contains(jumper.net))
        }
        for component in layout.components {
            drawComponent(component, in: context, map: map)
            if component.id == selectedComponentID {
                highlightSelection(component, in: context, map: map)
            }
        }
        let showMeters = annotationLayer == .measurements || annotationLayer == .all || (annotationLayer == .values && pitch >= 12)
        if showMeters {
            for meter in layout.meters.prefix(annotationLayer == .values ? 4 : layout.meters.count) {
                drawMeter(meter, in: context, map: map)
            }
        }
        drawComponentLabels(layout, in: context, map: map, annotationLayer: annotationLayer)
    }

    static func hitComponent(
        _ layout: BreadboardLayout,
        at point: CGPoint,
        pitch: CGFloat,
        viewSize: CGSize,
        zoom: CGFloat,
        pan: CGSize
    ) -> String? {
        let map = Map(pitch: pitch)
        let board = size(pitch: pitch)
        let originX = (viewSize.width - board.width * zoom) / 2 + pan.width
        let originY = (viewSize.height - board.height * zoom) / 2 + pan.height
        let local = CGPoint(x: (point.x - originX) / zoom, y: (point.y - originY) / zoom)
        var best: (String, CGFloat)?
        for component in layout.components {
            let centers = component.leads.map { map.center($0.hole) }
            guard !centers.isEmpty else { continue }
            let mid = CGPoint(
                x: centers.map(\.x).reduce(0, +) / CGFloat(centers.count),
                y: centers.map(\.y).reduce(0, +) / CGFloat(centers.count)
            )
            let distance = hypot(mid.x - local.x, mid.y - local.y)
            if distance < pitch * 1.8, best == nil || distance < best!.1 {
                best = (component.id, distance)
            }
        }
        return best?.0
    }

    private static func highlightSelection(_ component: BBComponent, in context: GraphicsContext, map: Map) {
        let centers = component.leads.map { map.center($0.hole) }
        guard !centers.isEmpty else { return }
        let mid = CGPoint(
            x: centers.map(\.x).reduce(0, +) / CGFloat(centers.count),
            y: centers.map(\.y).reduce(0, +) / CGFloat(centers.count)
        )
        let radius = map.pitch * 1.6
        let rect = CGRect(x: mid.x - radius, y: mid.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(Color.cyan.opacity(0.95)), lineWidth: 2)
    }

    private struct Map {
        var pitch: CGFloat
        var origin = CGPoint(x: 92, y: 22)

        func center(_ hole: BBHole) -> CGPoint {
            CGPoint(
                x: origin.x + CGFloat(hole.column - 1) * pitch,
                y: origin.y + CGFloat(hole.row.unitY) * pitch
            )
        }

        func center(column: Int, row: BBRow) -> CGPoint {
            center(BBHole(column: column, row: row))
        }
    }

    private static func drawBoard(in context: GraphicsContext, map: Map) {
        let pitch = map.pitch
        let left = map.center(column: 1, row: .a).x - pitch * 0.85
        let right = map.center(column: BreadboardBoard.columns, row: .a).x + pitch * 0.85
        let top = map.center(column: 1, row: .topPlus).y - pitch * 0.85
        let bottom = map.center(column: 1, row: .botPlus).y + pitch * 0.85
        let board = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        let shadow = board.offsetBy(dx: 0, dy: 3)
        context.fill(Path(roundedRect: shadow, cornerRadius: 14), with: .color(Color.black.opacity(0.18)))
        let body = Path(roundedRect: board, cornerRadius: 12)
        context.fill(
            body,
            with: .linearGradient(
                Gradient(colors: [rgb(0xE4DDD2), rgb(0xC9C2B6)]),
                startPoint: CGPoint(x: board.minX, y: board.minY),
                endPoint: CGPoint(x: board.minX, y: board.maxY)
            )
        )
        context.stroke(body, with: .color(rgb(0x8E877C)), lineWidth: 1.2)

        let gutterTop = map.center(column: 1, row: .e).y + pitch * 0.42
        let gutterBottom = map.center(column: 1, row: .f).y - pitch * 0.42
        let gutter = CGRect(x: left + 8, y: gutterTop, width: right - left - 16, height: gutterBottom - gutterTop)
        context.fill(Path(roundedRect: gutter, cornerRadius: 5), with: .color(rgb(0xB7A99A)))
        context.stroke(Path(roundedRect: gutter, cornerRadius: 5), with: .color(rgb(0x9A8C7E).opacity(0.7)), lineWidth: 0.8)
    }

    private static func drawRails(_ layout: BreadboardLayout, in context: GraphicsContext, map: Map) {
        let pitch = map.pitch
        let x0 = map.center(column: 1, row: .a).x - pitch * 0.45
        let x1 = map.center(column: layout.columns, row: .a).x + pitch * 0.45
        func stripe(_ row: BBRow, above: Bool, color: Color) {
            let y = map.center(column: 1, row: row).y + (above ? -pitch * 0.46 : pitch * 0.28)
            let rect = CGRect(x: x0, y: y, width: x1 - x0, height: pitch * 0.16)
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
        }
        stripe(.topPlus, above: true, color: rgb(0xE23B32))
        stripe(.topMinus, above: false, color: rgb(0x2A57C4))
        stripe(.botMinus, above: true, color: rgb(0x2A57C4))
        stripe(.botPlus, above: false, color: rgb(0xE23B32))

        for column in stride(from: 1, to: layout.columns + 1, by: 5) {
            mark("+", at: map.center(column: column, row: .topPlus), pitch: pitch, color: rgb(0xE23B32), in: context)
            mark("−", at: map.center(column: column, row: .topMinus), pitch: pitch, color: rgb(0x2A57C4), in: context)
            mark("−", at: map.center(column: column, row: .botMinus), pitch: pitch, color: rgb(0x2A57C4), in: context)
            mark("+", at: map.center(column: column, row: .botPlus), pitch: pitch, color: rgb(0xE23B32), in: context)
        }
        for label in layout.railLabels {
            let point = map.center(column: 1, row: label.row)
            let text = context.resolve(
                Text(label.text).font(.system(size: max(8, pitch * 0.42), weight: .bold)).foregroundColor(rgb(0x3E3A34))
            )
            context.draw(text, at: CGPoint(x: point.x - pitch * 0.95, y: point.y), anchor: .trailing)
        }
    }

    private static func drawHoles(columns: Int, in context: GraphicsContext, map: Map) {
        let diameter = map.pitch * 0.34
        for column in 1...columns {
            for row in BBRow.allCases {
                let center = map.center(column: column, row: row)
                let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(rgb(0x2C3036)))
                let glint = diameter * 0.28
                let glintRect = CGRect(x: center.x - diameter * 0.18, y: center.y - diameter * 0.2, width: glint, height: glint)
                context.fill(Path(ellipseIn: glintRect), with: .color(Color.white.opacity(0.35)))
                let pit = diameter * 0.28
                let pitRect = CGRect(x: center.x - pit / 2, y: center.y - pit / 2 + diameter * 0.04, width: pit, height: pit)
                context.fill(Path(ellipseIn: pitRect), with: .color(rgb(0x121418)))
            }
        }
    }

    private static func drawIndexes(columns: Int, in context: GraphicsContext, map: Map) {
        let rows: [BBRow] = [.a, .b, .c, .d, .e, .f, .g, .h, .i, .j]
        for row in rows {
            let point = map.center(column: 1, row: row)
            let text = context.resolve(
                Text(row.rawValue).font(.system(size: max(7, map.pitch * 0.36), weight: .medium)).foregroundColor(rgb(0x6E675C))
            )
            context.draw(text, at: CGPoint(x: point.x - map.pitch * 0.72, y: point.y), anchor: .trailing)
        }
        for column in [1, 5, 10, 15, 20, 25, 30] where column <= columns {
            let point = map.center(column: column, row: .topPlus)
            let text = context.resolve(
                Text("\(column)").font(.system(size: max(7, map.pitch * 0.34), weight: .semibold)).foregroundColor(rgb(0x5C564C))
            )
            context.draw(text, at: CGPoint(x: point.x, y: point.y - map.pitch * 0.78), anchor: .bottom)
        }
    }

    private static func drawSupply(_ supply: BBSupply, in context: GraphicsContext, map: Map) {
        guard let first = supply.leads.first else { return }
        let anchor = map.center(first.hole)
        let brick = CGRect(x: 8, y: anchor.y - 16, width: 52, height: 16 + CGFloat(max(0, supply.leads.count - 1)) * map.pitch * 0.9 + 20)
        context.fill(Path(roundedRect: brick, cornerRadius: 6), with: .color(rgb(0x2F343C)))
        context.stroke(Path(roundedRect: brick, cornerRadius: 6), with: .color(rgb(0x1B1E24)), lineWidth: 1)
        let title = context.resolve(
            Text(supply.label).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
        )
        context.draw(title, at: CGPoint(x: brick.midX, y: brick.midY), anchor: .center)
        for lead in supply.leads {
            let end = map.center(lead.hole)
            var path = Path()
            path.move(to: CGPoint(x: brick.maxX, y: brick.midY))
            path.addLine(to: CGPoint(x: end.x - map.pitch * 0.2, y: brick.midY))
            path.addLine(to: end)
            strokeWire(path, color: wireColor(forNet: lead.net), width: map.pitch * 0.14, in: context)
            plug(at: end, color: wireColor(forNet: lead.net), pitch: map.pitch, in: context)
        }
    }

    private static func drawJumper(_ jumper: BBJumper, in context: GraphicsContext, map: Map, emphasized: Bool = false) {
        let points = BreadboardRoute.manhattan(from: jumper.a, to: jumper.b).map {
            CGPoint(x: map.origin.x + CGFloat($0.x - 1) * map.pitch, y: map.origin.y + CGFloat($0.y) * map.pitch)
        }
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        let color = wireColor(jumper.color)
        context.stroke(
            path,
            with: .color(color.opacity(0.35)),
            style: StrokeStyle(lineWidth: map.pitch * 0.22, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: max(emphasized ? 3.4 : 2.2, map.pitch * (emphasized ? 0.22 : 0.16)), lineCap: .round, lineJoin: .round)
        )
        plug(at: points[0], color: color, pitch: map.pitch, in: context)
        plug(at: points[points.count - 1], color: color, pitch: map.pitch, in: context)
    }

    private static func drawComponent(_ component: BBComponent, in context: GraphicsContext, map: Map) {
        switch component.part {
        case .resistor(_, _, let bands):
            guard component.leads.count == 2 else { return }
            drawResistor(from: map.center(component.leads[0].hole), to: map.center(component.leads[1].hole), bands: bands, label: "", pitch: map.pitch, in: context)
        case .ceramic:
            guard component.leads.count == 2 else { return }
            drawDisc(from: map.center(component.leads[0].hole), to: map.center(component.leads[1].hole), label: "", pitch: map.pitch, in: context)
        case .electrolytic:
            guard component.leads.count == 2 else { return }
            drawCan(
                positive: map.center(component.leads[0].hole),
                negative: map.center(component.leads[1].hole),
                label: "",
                pitch: map.pitch,
                in: context
            )
        case .led:
            guard component.leads.count == 2 else { return }
            drawLED(anode: map.center(component.leads[0].hole), cathode: map.center(component.leads[1].hole), label: "", pitch: map.pitch, in: context)
        case .diode:
            guard component.leads.count == 2 else { return }
            drawDiode(anode: map.center(component.leads[0].hole), cathode: map.center(component.leads[1].hole), label: "", pitch: map.pitch, in: context)
        case .inductor:
            guard component.leads.count == 2 else { return }
            drawInductor(from: map.center(component.leads[0].hole), to: map.center(component.leads[1].hole), label: "", pitch: map.pitch, in: context)
        case .npn:
            drawTO92(component.leads.map { map.center($0.hole) }, name: "Q", marks: ["E", "B", "C"], pitch: map.pitch, in: context)
        case .nmos:
            drawTO92(component.leads.map { map.center($0.hole) }, name: "M", marks: ["S", "G", "D"], pitch: map.pitch, in: context)
        case .pmos:
            drawTO92(component.leads.map { map.center($0.hole) }, name: "M", marks: ["S", "G", "D"], pitch: map.pitch, in: context)
        case .dip8(let name, _):
            drawDIP(component.leads.map { map.center($0.hole) }, name: name, pitch: map.pitch, in: context)
        case .display(_, let digit, let mask, _):
            drawDisplay(component.leads.map { map.center($0.hole) }, digit: digit, mask: mask, pitch: map.pitch, in: context)
        case .source:
            guard component.leads.count == 2 else { return }
            drawCell(positive: map.center(component.leads[0].hole), negative: map.center(component.leads[1].hole), label: "", pitch: map.pitch, in: context)
        }
    }

    private static func drawComponentLabels(
        _ layout: BreadboardLayout,
        in context: GraphicsContext,
        map: Map,
        annotationLayer: LabAnnotationLayer
    ) {
        let boardSize = size(pitch: map.pitch)
        var obstacles: [LabRect2] = []
        var requests: [LabAnnotationRequest] = []

        for component in layout.components {
            let centers = component.leads.map { map.center($0.hole) }
            guard !centers.isEmpty else { continue }
            let padding = map.pitch * 0.65
            let minX = centers.map(\.x).min() ?? 0
            let maxX = centers.map(\.x).max() ?? 0
            let minY = centers.map(\.y).min() ?? 0
            let maxY = centers.map(\.y).max() ?? 0
            obstacles.append(LabRect2(
                x: Double(minX - padding),
                y: Double(minY - padding),
                width: Double(max(maxX - minX + padding * 2, map.pitch * 1.7)),
                height: Double(max(maxY - minY + padding * 2, map.pitch * 1.7))
            ))
            let anchor = CGPoint(
                x: centers.map(\.x).reduce(0, +) / CGFloat(centers.count),
                y: centers.map(\.y).reduce(0, +) / CGFloat(centers.count)
            )
            requests.append(LabAnnotationRequest(
                id: "component-\(component.id)",
                text: partName(component, layer: annotationLayer),
                anchor: LabVec2(x: Double(anchor.x), y: Double(anchor.y)),
                layer: annotationLayer,
                fontSize: 13
            ))
        }

        for jumper in layout.jumpers {
            let points = BreadboardRoute.manhattan(from: jumper.a, to: jumper.b).map {
                CGPoint(x: map.origin.x + CGFloat($0.x - 1) * map.pitch, y: map.origin.y + CGFloat($0.y) * map.pitch)
            }
            for (a, b) in zip(points, points.dropFirst()) {
                let padding: CGFloat = 3
                obstacles.append(LabRect2(
                    x: Double(min(a.x, b.x) - padding),
                    y: Double(min(a.y, b.y) - padding),
                    width: Double(max(abs(a.x - b.x) + padding * 2, padding * 2)),
                    height: Double(max(abs(a.y - b.y) + padding * 2, padding * 2))
                ))
            }
        }

        for supply in layout.supplies {
            guard let first = supply.leads.first else { continue }
            let anchor = map.center(first.hole)
            let height = 36 + CGFloat(max(0, supply.leads.count - 1)) * map.pitch * 0.9
            obstacles.append(LabRect2(x: 8, y: Double(anchor.y - 16), width: 52, height: Double(height)))
        }

        for meter in layout.meters {
            let anchor = map.center(meter.hole)
            let title = "\(meter.title) \(meter.reading)"
            let measured = LabAnnotationEngine.measure(title, fontSize: 13)
            obstacles.append(LabRect2(
                x: Double(anchor.x) - measured.width / 2 - 6,
                y: Double(anchor.y - map.pitch * 0.95 - 12),
                width: measured.width + 12,
                height: 24
            ))
        }

        let placed = LabAnnotationEngine.place(
            requests: requests,
            obstacles: obstacles,
            canvas: LabRect2(x: 0, y: 0, width: Double(boardSize.width), height: Double(boardSize.height)),
            activeLayers: [.values]
        )
        for item in placed {
            let rect = CGRect(x: item.frame.x, y: item.frame.y, width: item.frame.width, height: item.frame.height)
            if let from = item.leaderFrom {
                var leader = Path()
                leader.move(to: CGPoint(x: from.x, y: from.y))
                leader.addLine(to: CGPoint(x: item.leaderTo.x, y: item.leaderTo.y))
                context.stroke(leader, with: .color(rgb(0x6E675C)), lineWidth: 0.8)
            }
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(rgb(0xE4DDD2).opacity(0.98)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(rgb(0x8E877C)), lineWidth: 0.8)
            let text = context.resolve(
                Text(item.text)
                    .font(.system(size: CGFloat(item.fontSize), weight: .semibold).monospacedDigit())
                    .foregroundColor(rgb(0x2C2924))
            )
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        }
    }

    private static func drawResistor(from a: CGPoint, to b: CGPoint, bands: [String], label: String, pitch: CGFloat, in context: GraphicsContext) {
        lead(from: a, to: b, pitch: pitch, in: context)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let length = max(hypot(b.x - a.x, b.y - a.y) * 0.62, pitch * 1.15)
        let height = pitch * 0.42
        var body = Path(roundedRect: CGRect(x: -length / 2, y: -height / 2, width: length, height: height), cornerRadius: height / 2)
        let transform = CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle)
        body = body.applying(transform)
        context.fill(body, with: .color(rgb(0xE4C99A)))
        context.stroke(body, with: .color(rgb(0xC4A574)), lineWidth: 0.6)
        let count = max(bands.count, 1)
        for (index, name) in bands.enumerated() {
            let t = -0.28 + CGFloat(index) * (index == count - 1 ? 0.2 : 0.13)
            let along = CGPoint(x: mid.x + cos(angle) * length * t, y: mid.y + sin(angle) * length * t)
            var band = Path(CGRect(x: -pitch * 0.055, y: -height / 2, width: pitch * 0.11, height: height))
            band = band.applying(CGAffineTransform(translationX: along.x, y: along.y).rotated(by: angle))
            context.fill(band, with: .color(bandColor(name)))
        }
        labelAbove(label, at: mid, pitch: pitch, in: context)
    }

    private static func drawDisc(from a: CGPoint, to b: CGPoint, label: String, pitch: CGFloat, in context: GraphicsContext) {
        lead(from: a, to: b, pitch: pitch, in: context)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let radius = pitch * 0.48
        let rect = CGRect(x: mid.x - radius, y: mid.y - radius * 0.82, width: radius * 2, height: radius * 1.64)
        context.fill(Path(ellipseIn: rect), with: .color(rgb(0xE07A32)))
        context.stroke(Path(ellipseIn: rect), with: .color(rgb(0xA8501C)), lineWidth: 0.8)
        let text = context.resolve(Text(label).font(.system(size: max(7, pitch * 0.34), weight: .bold)).foregroundColor(rgb(0x3A2414)))
        context.draw(text, at: mid, anchor: .center)
    }

    private static func drawCan(positive: CGPoint, negative: CGPoint, label: String, pitch: CGFloat, in context: GraphicsContext) {
        lead(from: positive, to: negative, pitch: pitch, in: context)
        let mid = CGPoint(x: (positive.x + negative.x) / 2, y: (positive.y + negative.y) / 2)
        let angle = atan2(negative.y - positive.y, negative.x - positive.x)
        let length = max(hypot(negative.x - positive.x, negative.y - positive.y) * 0.5, pitch * 0.9)
        let height = pitch * 0.7
        var body = Path(roundedRect: CGRect(x: -length / 2, y: -height / 2, width: length, height: height), cornerRadius: 3)
        body = body.applying(CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle))
        context.fill(body, with: .color(rgb(0x1E4E86)))
        context.stroke(body, with: .color(rgb(0x0E2C52)), lineWidth: 0.8)
        var stripe = Path(CGRect(x: length * 0.18, y: -height / 2, width: pitch * 0.16, height: height))
        stripe = stripe.applying(CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle))
        context.fill(stripe, with: .color(.white.opacity(0.92)))
        let minus = context.resolve(Text("−").font(.system(size: max(8, pitch * 0.4), weight: .bold)).foregroundColor(rgb(0x1E4E86)))
        let stripePoint = CGPoint(x: mid.x + cos(angle) * length * 0.28, y: mid.y + sin(angle) * length * 0.28)
        context.draw(minus, at: stripePoint, anchor: .center)
        let plus = context.resolve(Text("+").font(.system(size: max(8, pitch * 0.38), weight: .bold)).foregroundColor(.white))
        let plusPoint = CGPoint(x: mid.x - cos(angle) * length * 0.22, y: mid.y - sin(angle) * length * 0.22)
        context.draw(plus, at: plusPoint, anchor: .center)
        labelAbove(label, at: mid, pitch: pitch, in: context)
    }

    private static func drawLED(anode: CGPoint, cathode: CGPoint, label: String, pitch: CGFloat, in context: GraphicsContext) {
        lead(from: anode, to: cathode, pitch: pitch, in: context)
        let mid = CGPoint(x: (anode.x + cathode.x) / 2, y: (anode.y + cathode.y) / 2)
        let radius = pitch * 0.42
        let glow = CGRect(x: mid.x - radius * 1.35, y: mid.y - radius * 1.35, width: radius * 2.7, height: radius * 2.7)
        context.fill(Path(ellipseIn: glow), with: .color(rgb(0xFF3B30).opacity(0.28)))
        let body = CGRect(x: mid.x - radius, y: mid.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: body),
            with: .radialGradient(
                Gradient(colors: [rgb(0xFF8A80), rgb(0xE10600)]),
                center: CGPoint(x: mid.x - radius * 0.25, y: mid.y - radius * 0.3),
                startRadius: 0,
                endRadius: radius
            )
        )
        let angle = atan2(cathode.y - anode.y, cathode.x - anode.x)
        var flat = Path()
        let cut = CGPoint(x: mid.x + cos(angle) * radius * 0.72, y: mid.y + sin(angle) * radius * 0.72)
        flat.move(to: CGPoint(x: cut.x + CGFloat(-sin(angle)) * radius, y: cut.y + CGFloat(cos(angle)) * radius))
        flat.addLine(to: CGPoint(x: cut.x - CGFloat(-sin(angle)) * radius, y: cut.y - CGFloat(cos(angle)) * radius))
        context.stroke(flat, with: .color(rgb(0x7A120C)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        let glint = CGRect(x: mid.x - radius * 0.45, y: mid.y - radius * 0.5, width: radius * 0.38, height: radius * 0.28)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.7)))
        labelAbove(label, at: mid, pitch: pitch, in: context)
    }

    private static func drawCell(positive: CGPoint, negative: CGPoint, label: String, pitch: CGFloat, in context: GraphicsContext) {
        lead(from: positive, to: negative, pitch: pitch, in: context)
        let mid = CGPoint(x: (positive.x + negative.x) / 2, y: (positive.y + negative.y) / 2)
        let angle = atan2(negative.y - positive.y, negative.x - positive.x)
        let w = pitch * 0.85
        let h = pitch * 0.55
        var body = Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: 3)
        body = body.applying(CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle))
        context.fill(body, with: .color(rgb(0xF4F0E6)))
        context.stroke(body, with: .color(rgb(0x3E3A34)), lineWidth: 1)
        let plus = context.resolve(Text("+").font(.system(size: max(8, pitch * 0.4), weight: .bold)).foregroundColor(rgb(0xC62828)))
        let minus = context.resolve(Text("−").font(.system(size: max(8, pitch * 0.4), weight: .bold)).foregroundColor(rgb(0x1A1A1A)))
        context.draw(plus, at: CGPoint(x: mid.x - cos(angle) * w * 0.22, y: mid.y - sin(angle) * w * 0.22), anchor: .center)
        context.draw(minus, at: CGPoint(x: mid.x + cos(angle) * w * 0.22, y: mid.y + sin(angle) * w * 0.22), anchor: .center)
        labelAbove(label, at: mid, pitch: pitch, in: context)
    }

    private static func drawTO92(_ pins: [CGPoint], name: String, marks: [String], pitch: CGFloat, in context: GraphicsContext) {
        guard pins.count == 3 else { return }
        let mid = CGPoint(
            x: (pins[0].x + pins[2].x) / 2,
            y: (pins.map(\.y).min() ?? pins[0].y) - pitch * 0.15
        )
        for pin in pins {
            lead(from: pin, to: CGPoint(x: pin.x, y: mid.y), pitch: pitch, in: context)
        }
        let body = CGRect(x: mid.x - pitch * 0.85, y: mid.y - pitch * 0.95, width: pitch * 1.7, height: pitch * 1.15)
        var shape = Path()
        shape.addArc(center: CGPoint(x: body.midX, y: body.minY + body.width / 2), radius: body.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        shape.addLine(to: CGPoint(x: body.maxX, y: body.maxY))
        shape.addLine(to: CGPoint(x: body.minX, y: body.maxY))
        shape.closeSubpath()
        context.fill(shape, with: .color(rgb(0x1A1A1A)))
        context.stroke(shape, with: .color(rgb(0x0A0A0A)), lineWidth: 0.8)
        let title = context.resolve(Text(name).font(.system(size: max(6, min(9, pitch * 0.48)), weight: .bold)).foregroundColor(.white))
        context.draw(title, at: CGPoint(x: body.midX, y: body.midY - 1), anchor: .center)
        for (pin, mark) in zip(pins, marks) {
            let text = context.resolve(Text(mark).font(.system(size: max(7, pitch * 0.32), weight: .bold)).foregroundColor(rgb(0x3E3A34)))
            context.draw(text, at: CGPoint(x: pin.x, y: pin.y + pitch * 0.38), anchor: .top)
        }
    }

    private static func drawDIP(_ pins: [CGPoint], name: String, pitch: CGFloat, in context: GraphicsContext) {
        guard pins.count >= 8 else { return }
        let left = pins[0].x
        let right = pins[3].x
        let top = pins[0].y
        let bottom = pins[7].y
        let body = CGRect(x: left - pitch * 0.28, y: top + pitch * 0.28, width: (right - left) + pitch * 0.56, height: (bottom - top) - pitch * 0.56)
        for (index, pin) in pins.enumerated() {
            let onTop = index < 4
            let edge = CGPoint(x: pin.x, y: onTop ? body.minY : body.maxY)
            var leg = Path()
            leg.move(to: pin)
            leg.addLine(to: edge)
            context.stroke(leg, with: .color(rgb(0xC5CCD2)), style: StrokeStyle(lineWidth: max(1.4, pitch * 0.09), lineCap: .square))
            plug(at: pin, color: rgb(0x9AA3AB), pitch: pitch * 0.7, in: context)
        }
        let chip = Path(roundedRect: body, cornerRadius: 3)
        context.fill(
            chip,
            with: .linearGradient(
                Gradient(colors: [rgb(0x3A3A3A), rgb(0x141414)]),
                startPoint: CGPoint(x: body.minX, y: body.minY),
                endPoint: CGPoint(x: body.minX, y: body.maxY)
            )
        )
        context.stroke(chip, with: .color(rgb(0x0A0A0A)), lineWidth: 1)
        var notch = Path()
        notch.addArc(
            center: CGPoint(x: body.minX, y: body.midY),
            radius: pitch * 0.22,
            startAngle: .degrees(-70),
            endAngle: .degrees(70),
            clockwise: false
        )
        context.stroke(notch, with: .color(rgb(0xD7D3CC)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        let dot = CGRect(x: body.minX + pitch * 0.18, y: body.minY + pitch * 0.16, width: pitch * 0.16, height: pitch * 0.16)
        context.fill(Path(ellipseIn: dot), with: .color(.white))
        let title = context.resolve(Text(name).font(.system(size: max(11, pitch * 0.62), weight: .bold)).foregroundColor(.white))
        context.draw(title, at: CGPoint(x: body.midX, y: body.midY), anchor: .center)
    }

    private static func drawDisplay(_ pins: [CGPoint], digit: Int, mask: Int, pitch: CGFloat, in context: GraphicsContext) {
        guard pins.count >= 10 else { return }
        let left = pins[0].x
        let right = pins[4].x
        let top = pins[0].y
        let bottom = pins[9].y
        let body = CGRect(
            x: left - pitch * 0.35,
            y: top + pitch * 0.22,
            width: (right - left) + pitch * 0.7,
            height: max(pitch * 2.1, (bottom - top) - pitch * 0.44)
        )
        for (index, pin) in pins.enumerated() {
            let onTop = index < 5
            let edgeY = onTop ? body.minY : body.maxY
            var leg = Path()
            leg.move(to: pin)
            leg.addLine(to: CGPoint(x: pin.x, y: edgeY))
            context.stroke(leg, with: .color(rgb(0xC5CCD2)), style: StrokeStyle(lineWidth: max(1.3, pitch * 0.08), lineCap: .square))
        }
        context.fill(Path(roundedRect: body, cornerRadius: 4), with: .color(rgb(0x1A1A1A)))
        let face = body.insetBy(dx: pitch * 0.28, dy: pitch * 0.22)
        context.fill(Path(roundedRect: face, cornerRadius: 3), with: .color(rgb(0x120806)))
        drawSegments(mask: mask, in: face, pitch: pitch, context: context)
        let caption = context.resolve(
            Text("\(digit)").font(.system(size: max(8, pitch * 0.36), weight: .bold)).foregroundColor(rgb(0xE7E2D8))
        )
        context.draw(caption, at: CGPoint(x: body.midX, y: body.maxY + pitch * 0.08), anchor: .top)
    }

    private static func drawSegments(mask: Int, in face: CGRect, pitch: CGFloat, context: GraphicsContext) {
        let t = max(2.2, pitch * 0.13)
        let inset = t * 0.8
        let midY = face.midY
        func segment(_ bit: Int, _ rect: CGRect) {
            let on = mask & (1 << bit) != 0
            let path = Path(roundedRect: rect, cornerRadius: t / 2)
            if on {
                let glow = rect.insetBy(dx: -1.5, dy: -1.5)
                context.fill(Path(roundedRect: glow, cornerRadius: t), with: .color(rgb(0xFF2A1A).opacity(0.45)))
            }
            context.fill(path, with: .color(on ? rgb(0xFF2D1F) : rgb(0x3A1412)))
        }
        segment(0, CGRect(x: face.minX + inset, y: face.minY + 1, width: face.width - inset * 2, height: t))
        segment(6, CGRect(x: face.minX + inset, y: midY - t / 2, width: face.width - inset * 2, height: t))
        segment(3, CGRect(x: face.minX + inset, y: face.maxY - t - 1, width: face.width - inset * 2, height: t))
        let upper = midY - face.minY - t - 2
        let lower = face.maxY - midY - t - 2
        segment(5, CGRect(x: face.minX + 1, y: face.minY + t + 1, width: t, height: upper))
        segment(1, CGRect(x: face.maxX - t - 1, y: face.minY + t + 1, width: t, height: upper))
        segment(4, CGRect(x: face.minX + 1, y: midY + 2, width: t, height: lower))
        segment(2, CGRect(x: face.maxX - t - 1, y: midY + 2, width: t, height: lower))
    }

    private static func drawDiode(anode: CGPoint, cathode: CGPoint, label: String, pitch: CGFloat, in context: GraphicsContext) {
        lead(from: anode, to: cathode, pitch: pitch, in: context)
        let mid = CGPoint(x: (anode.x + cathode.x) / 2, y: (anode.y + cathode.y) / 2)
        let angle = atan2(cathode.y - anode.y, cathode.x - anode.x)
        let body = pitch * 0.55
        let half = pitch * 0.28
        var triangle = Path()
        triangle.move(to: CGPoint(x: -body / 2, y: -half))
        triangle.addLine(to: CGPoint(x: body / 2, y: 0))
        triangle.addLine(to: CGPoint(x: -body / 2, y: half))
        triangle.closeSubpath()
        let transform = CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle)
        context.fill(triangle.applying(transform), with: .color(rgb(0x2B2B2B)))
        var bar = Path()
        bar.move(to: CGPoint(x: body / 2, y: -half))
        bar.addLine(to: CGPoint(x: body / 2, y: half))
        context.stroke(bar.applying(transform), with: .color(rgb(0xE8E2D8)), lineWidth: max(1.4, pitch * 0.1))
        labelAbove(label, at: CGPoint(x: mid.x, y: mid.y - pitch * 0.15), pitch: pitch, in: context)
    }

    private static func drawInductor(from a: CGPoint, to b: CGPoint, label: String, pitch: CGFloat, in context: GraphicsContext) {
        lead(from: a, to: b, pitch: pitch, in: context)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let length = max(hypot(b.x - a.x, b.y - a.y) * 0.55, pitch * 1.1)
        let amp = pitch * 0.22
        var coils = Path()
        let turns = 4
        coils.move(to: CGPoint(x: -length / 2, y: 0))
        for index in 0..<turns {
            let x0 = -length / 2 + CGFloat(index) * length / CGFloat(turns)
            let x1 = x0 + length / CGFloat(turns)
            coils.addCurve(
                to: CGPoint(x: x1, y: 0),
                control1: CGPoint(x: x0 + (x1 - x0) * 0.25, y: -amp),
                control2: CGPoint(x: x0 + (x1 - x0) * 0.75, y: -amp)
            )
        }
        let transform = CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle)
        context.stroke(
            coils.applying(transform),
            with: .color(rgb(0x4A5560)),
            style: StrokeStyle(lineWidth: max(1.6, pitch * 0.12), lineCap: .round, lineJoin: .round)
        )
        labelAbove(label, at: CGPoint(x: mid.x, y: mid.y - pitch * 0.2), pitch: pitch, in: context)
    }

    private static func drawMeter(_ meter: BBMeter, in context: GraphicsContext, map: Map) {
        let anchor = map.center(meter.hole)
        let pitch = map.pitch
        let title = "\(meter.title) \(meter.reading)"
        let fontSize = min(15, max(12, pitch * 0.55))
        let resolved = context.resolve(
            Text(title)
                .font(.system(size: fontSize, weight: .bold).monospacedDigit())
                .foregroundColor(meter.kind == .current ? rgb(0x0B3D91) : rgb(0x1B5E20))
        )
        let textSize = resolved.measure(in: CGSize(width: 240, height: 40))
        let padX: CGFloat = 6
        let padY: CGFloat = 3
        let width = textSize.width + padX * 2
        let height = max(textSize.height + padY * 2, pitch * 0.7)
        let offsetY: CGFloat = meter.kind == .current ? -pitch * 0.95 : -pitch * 0.72
        let rect = CGRect(
            x: anchor.x - width / 2,
            y: anchor.y + offsetY - height / 2,
            width: width,
            height: height
        )
        let fill = meter.kind == .current ? rgb(0xD6E6FF) : rgb(0xDFF5E2)
        let stroke = meter.kind == .current ? rgb(0x3D6FB4) : rgb(0x3D8B4F)
        context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(fill.opacity(0.94)))
        context.stroke(Path(roundedRect: rect, cornerRadius: 5), with: .color(stroke), lineWidth: 1)
        context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    private static func lead(from a: CGPoint, to b: CGPoint, pitch: CGFloat, in context: GraphicsContext) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        context.stroke(path, with: .color(rgb(0xB7BDC4)), style: StrokeStyle(lineWidth: max(1.2, pitch * 0.07), lineCap: .round))
    }

    private static func labelAbove(_ text: String, at point: CGPoint, pitch: CGFloat, in context: GraphicsContext) {
        guard !text.isEmpty else { return }
        let fontSize = min(15, max(11, pitch * 0.55))
        let resolved = context.resolve(
            Text(text).font(.system(size: fontSize, weight: .semibold).monospacedDigit()).foregroundColor(rgb(0x2C2924))
        )
        context.draw(resolved, at: CGPoint(x: point.x, y: point.y - pitch * 0.55), anchor: .bottom)
    }

    private static func plug(at point: CGPoint, color: Color, pitch: CGFloat, in context: GraphicsContext) {
        let d = pitch * 0.22
        let rect = CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)
        context.fill(Path(ellipseIn: rect), with: .color(color))
        context.stroke(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.35)), lineWidth: 0.6)
    }

    private static func strokeWire(_ path: Path, color: Color, width: CGFloat, in context: GraphicsContext) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func mark(_ glyph: String, at point: CGPoint, pitch: CGFloat, color: Color, in context: GraphicsContext) {
        let text = context.resolve(Text(glyph).font(.system(size: max(7, pitch * 0.32), weight: .bold)).foregroundColor(color))
        context.draw(text, at: CGPoint(x: point.x + pitch * 0.34, y: point.y), anchor: .leading)
    }

    private static func partName(_ component: BBComponent, layer: LabAnnotationLayer) -> String {
        let fullName: String
        switch component.part {
        case .resistor(_, let label, _): fullName = label
        case .ceramic(_, let label), .electrolytic(_, let label): fullName = label
        case .led(let label), .diode(let label): fullName = label
        case .inductor(_, let label): fullName = label
        case .npn(let name), .nmos(let name), .pmos(let name): fullName = "\(component.id.uppercased())  \(name)"
        case .dip8(let name, _): fullName = "\(component.id.uppercased())  \(name)"
        case .display(let name, let digit, _, _): fullName = "\(component.id.uppercased())  \(name) digit \(digit)"
        case .source(let label): fullName = label
        }
        guard layer == .minimal else { return fullName }
        return fullName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? fullName
    }

    private static func wireColor(_ color: BBWireColor) -> Color {
        switch color {
        case .red: return rgb(0xE23B32)
        case .black: return rgb(0x1C1C1C)
        case .blue: return rgb(0x2457C5)
        case .yellow: return rgb(0xE6B400)
        case .green: return rgb(0x2E9E45)
        case .orange: return rgb(0xF07A14)
        case .violet: return rgb(0x7A3FF0)
        case .white: return rgb(0xF7F4EE)
        }
    }

    private static func wireColor(forNet net: String) -> Color {
        if net == "GND" { return wireColor(.black) }
        if net == "−V" { return wireColor(.blue) }
        return wireColor(.red)
    }

    private static func bandColor(_ name: String) -> Color {
        switch name {
        case "black": return rgb(0x1A1A1A)
        case "brown": return rgb(0x8B4513)
        case "red": return rgb(0xD32F2F)
        case "orange": return rgb(0xF57C00)
        case "yellow": return rgb(0xF6D000)
        case "green": return rgb(0x2E7D32)
        case "blue": return rgb(0x1565C0)
        case "violet": return rgb(0x6A1B9A)
        case "gray": return rgb(0x9E9E9E)
        case "white": return rgb(0xF5F5F5)
        case "gold": return rgb(0xD4AF37)
        case "silver": return rgb(0xC0C0C0)
        default: return rgb(0x888888)
        }
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
