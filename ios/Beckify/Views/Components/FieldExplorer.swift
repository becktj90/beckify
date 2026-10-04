import SwiftUI
import BeckifyMath
import UIKit

// MARK: - Layers

enum FieldLayer: String, CaseIterable, Identifiable {
    case magnitude = "|B|"
    case lines = "Field lines"
    case electric = "Induced E"

    var id: String { rawValue }
}

// MARK: - Colour

private enum FieldPalette {
    /// Perceptual dark-purple to yellow ramp for magnitudes.
    static let ramp: [(Double, Double, Double)] = [
        (68, 1, 84), (59, 82, 139), (33, 145, 140), (94, 201, 98), (253, 231, 37),
    ]

    static func magnitude(_ t: Double) -> (Double, Double, Double) {
        let x = min(max(t, 0), 1) * Double(ramp.count - 1)
        let i = min(Int(x), ramp.count - 2)
        let f = x - Double(i)
        let a = ramp[i], b = ramp[i + 1]
        return (a.0 + (b.0 - a.0) * f, a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f)
    }

    /// Blue for negative, near-white for zero, red for positive.
    static func diverging(_ v: Double) -> (Double, Double, Double) {
        let t = min(max(v, -1), 1)
        let mid = (238.0, 238.0, 238.0)
        if t >= 0 {
            return (mid.0 + (214 - mid.0) * t, mid.1 + (59 - mid.1) * t, mid.2 + (45 - mid.2) * t)
        }
        let u = -t
        return (mid.0 + (42 - mid.0) * u, mid.1 + (98 - mid.1) * u, mid.2 + (196 - mid.2) * u)
    }
}

// MARK: - Formatting

enum FieldFormat {
    static func tesla(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1 { return "\(Format.number(value, digits: 3)) T" }
        if magnitude >= 1e-3 { return "\(Format.number(value * 1e3, digits: 2)) mT" }
        return "\(Format.number(value * 1e6, digits: 1)) µT"
    }

    static func volts(perMetre value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1 { return "\(Format.number(value, digits: 2)) V/m" }
        if magnitude >= 1e-3 { return "\(Format.number(value * 1e3, digits: 2)) mV/m" }
        return "\(Format.number(value * 1e6, digits: 1)) µV/m"
    }

    static func amps(perMetre value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1e3 { return "\(Format.number(value / 1e3, digits: 2)) kA/m" }
        return "\(Format.number(value, digits: 1)) A/m"
    }

    static func length(_ metres: Double) -> String {
        let magnitude = abs(metres)
        if magnitude >= 1 { return "\(Format.number(metres, digits: 2)) m" }
        if magnitude >= 0.01 { return "\(Format.number(metres * 1000, digits: 1)) mm" }
        return "\(Format.number(metres * 1000, digits: 2)) mm"
    }

    /// 1, 2 or 5 times a power of ten at or below `value`, for a scale bar.
    static func niceLength(upTo value: Double) -> Double {
        guard value > 0 else { return 0 }
        let exponent = floor(log10(value))
        let base = pow(10, exponent)
        for step in [5.0, 2.0, 1.0] where step * base <= value { return step * base }
        return base
    }
}

// MARK: - Bitmap

private enum FieldBitmap {
    static func percentile(_ values: [Double], _ p: Double) -> Double {
        let sorted = values.map { abs($0) }.filter { $0.isFinite }.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[min(Int(Double(sorted.count - 1) * p), sorted.count - 1)]
    }

    /// One pixel per grid cell, row 0 at the bottom of the picture.
    /// For the electric layer `ramp` is the entered dI/dt: `cap` is already scaled by |ramp|, and the sign flips the colors.
    static func make(raster: FieldRaster, layer: FieldLayer, cap: Double, ramp: Double = 1) -> UIImage? {
        let w = raster.columns, h = raster.rows
        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        let dim = layer == .lines ? 0.55 : 1.0
        for row in 0..<h {
            for column in 0..<w {
                let i = raster.index(column: column, row: row)
                var rgb: (Double, Double, Double)
                if layer == .electric {
                    rgb = FieldPalette.diverging(cap > 0 ? raster.ePerRamp[i] * ramp / cap : 0)
                } else {
                    let t = cap > 0 ? (raster.bMag[i] / cap).squareRoot() : 0
                    rgb = FieldPalette.magnitude(t)
                    rgb = (rgb.0 * dim, rgb.1 * dim, rgb.2 * dim)
                }
                switch raster.tag[i] {
                case FieldRaster.coil:
                    rgb = (rgb.0 * 0.4 + 214 * 0.6, rgb.1 * 0.4 + 128 * 0.6, rgb.2 * 0.4 + 40 * 0.6)
                case FieldRaster.steel where layer != .magnitude:
                    rgb = (rgb.0 * 0.6 + 150 * 0.4, rgb.1 * 0.6 + 150 * 0.4, rgb.2 * 0.6 + 160 * 0.4)
                default: break
                }
                let out = ((h - 1 - row) * w + column) * 4
                pixels[out] = UInt8(min(max(rgb.0, 0), 255))
                pixels[out + 1] = UInt8(min(max(rgb.1, 0), 255))
                pixels[out + 2] = UInt8(min(max(rgb.2, 0), 255))
                pixels[out + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: image)
    }
}

// MARK: - Explorer

/// Heat map, field lines, induced E and a draggable probe for a solved cross-section.
/// The raster is built off the main thread by the caller's closure and keyed so a new design recomputes it.
struct FieldExplorerCard: View {
    let title: String
    /// Changes whenever the inputs change, to recompute the raster.
    let key: String
    let note: String
    /// Positions are measured from the picture centre, as for a solenoid axis, instead of the lower-left corner.
    var centered: Bool = false
    let build: @Sendable () -> FieldRaster?

    @State private var raster: FieldRaster?
    @State private var failed = false
    @State private var layer: FieldLayer = .magnitude
    @State private var probe: CGPoint?
    @State private var didtText = "100"
    @State private var image: UIImage?
    @State private var segments: [FieldContours.Segment] = []
    @State private var cap = 0.0

    private var didt: Double { didtText.parsedDouble ?? 0 }

    var body: some View {
        DiagramCard(
            title: title,
            accessibilitySummary: "\(title). Drag across the picture to read B, H and induced E at a point.",
            exportName: "field-map"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Layer", selection: $layer) {
                    ForEach(FieldLayer.allCases) { Text($0.rawValue).tag($0) }
                }
                .segmentedControlStyle()
                .accessibilityIdentifier("fieldExplorer.layer")

                if layer == .electric {
                    NumberField(
                        title: "Current ramp dI/dt", unit: "A/s", text: $didtText,
                        helpText: "Faraday: E = −∂A/∂t. A rising current drives E against the winding current.",
                        fieldID: "fieldDidt"
                    )
                }

                if let raster {
                    plot(raster)
                    legend(raster)
                    readout(raster)
                } else if failed {
                    Text("The field map could not be drawn for these numbers.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Solving the field…")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }

                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("fieldExplorer")
        .task(id: key) {
            raster = nil
            failed = false
            probe = nil
            let make = build
            let built = await Task.detached(priority: .userInitiated) { make() }.value
            // A newer key cancels this task. The detached solve still finishes, but it must not publish over the new one.
            guard !Task.isCancelled else { return }
            raster = built
            failed = built == nil
            refreshDerived()
        }
        .onChange(of: layer) { _, _ in refreshDerived() }
        .onChange(of: didtText) { _, _ in refreshDerived() }
    }

    // MARK: Pieces

    private func refreshDerived() {
        guard let raster else { return }
        switch layer {
        case .electric:
            // Colors and legend follow the ramp the user entered. Zero ramp is a blank, neutral map.
            cap = FieldBitmap.percentile(raster.ePerRamp, 0.98) * abs(didt)
        default:
            cap = FieldBitmap.percentile(raster.bMag, 0.98)
        }
        image = FieldBitmap.make(raster: raster, layer: layer, cap: cap, ramp: didt)
        if layer == .lines {
            let low = raster.potential.min() ?? 0
            let high = raster.potential.max() ?? 0
            let levels = FieldContours.levels(low: low, high: high, count: 16)
            segments = levels.flatMap {
                FieldContours.segments(values: raster.potential, columns: raster.columns, rows: raster.rows, level: $0)
            }
        } else {
            segments = []
        }
    }

    private func plot(_ raster: FieldRaster) -> some View {
        let aspect = raster.widthM / max(raster.heightM, 1e-12)
        return GeometryReader { geo in
                let size = geo.size
                ZStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: size.width, height: size.height)
                    }
                    Canvas { context, canvas in
                        draw(context, canvas, raster)
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { probe = normalized($0.location, size) }
                )
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(layer.rawValue) layer. Drag to probe.")
    }

    private func normalized(_ point: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x / max(size.width, 1), 0), 1),
            y: min(max(point.y / max(size.height, 1), 0), 1)
        )
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize, _ raster: FieldRaster) {
        let sx = size.width / Double(raster.columns - 1)
        let sy = size.height / Double(raster.rows - 1)
        func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: size.height - y * sy) }

        if layer == .lines {
            var path = Path()
            for s in segments {
                path.move(to: point(s.x0, s.y0))
                path.addLine(to: point(s.x1, s.y1))
            }
            context.stroke(path, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }

        for item in labels(raster, size) {
            context.draw(
                Text(item.text).font(.system(size: 10.5, weight: .bold, design: .rounded)).foregroundColor(.white),
                at: item.at, anchor: item.anchor
            )
        }

        // Scale bar, lower left.
        let bar = FieldFormat.niceLength(upTo: raster.widthM * 0.25)
        if bar > 0 {
            let length = bar / raster.widthM * size.width
            let y = size.height - 12
            var path = Path()
            path.move(to: CGPoint(x: 10, y: y))
            path.addLine(to: CGPoint(x: 10 + length, y: y))
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.draw(
                Text(FieldFormat.length(bar)).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.white),
                at: CGPoint(x: 10, y: y - 8), anchor: .leading
            )
        }

        if let probe {
            let at = CGPoint(x: probe.x * size.width, y: probe.y * size.height)
            var cross = Path()
            cross.move(to: CGPoint(x: at.x, y: 0))
            cross.addLine(to: CGPoint(x: at.x, y: size.height))
            cross.move(to: CGPoint(x: 0, y: at.y))
            cross.addLine(to: CGPoint(x: size.width, y: at.y))
            context.stroke(cross, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
            let ring = CGRect(x: at.x - 6, y: at.y - 6, width: 12, height: 12)
            context.stroke(Path(ellipseIn: ring), with: .color(.black), lineWidth: 3)
            context.stroke(Path(ellipseIn: ring), with: .color(.white), lineWidth: 1.5)
        }
    }

    private struct PlotLabel {
        var text: String
        var at: CGPoint
        var anchor: UnitPoint
    }

    /// Names on the picture: where the winding, steel, gap and axis are.
    private func labels(_ raster: FieldRaster, _ size: CGSize) -> [PlotLabel] {
        var coil: (x: Double, y: Double, n: Double) = (0, 0, 0)
        var gap: (x: Double, y: Double, n: Double) = (0, 0, 0)
        var steelTop: (x: Double, y: Double, n: Double) = (0, 0, 0)
        for row in 0..<raster.rows {
            for column in 0..<raster.columns {
                let i = raster.index(column: column, row: row)
                let px = Double(column) / Double(raster.columns - 1) * size.width
                let py = size.height - Double(row) / Double(raster.rows - 1) * size.height
                let tag = raster.tag[i]
                if tag == FieldRaster.coil {
                    // One coil section is enough for a solenoid, which is mirrored about its axis.
                    if raster.kind == .core || column > raster.columns / 2 {
                        coil.x += px; coil.y += py; coil.n += 1
                    }
                } else if tag == FieldRaster.gap {
                    gap.x += px; gap.y += py; gap.n += 1
                } else if tag == FieldRaster.steel, row > raster.rows * 3 / 4 {
                    steelTop.x += px; steelTop.y += py; steelTop.n += 1
                }
            }
        }
        var out: [PlotLabel] = []
        if coil.n > 0 {
            let at = CGPoint(x: coil.x / coil.n, y: coil.y / coil.n)
            out.append(PlotLabel(text: "Winding", at: raster.kind == .solenoid ? CGPoint(x: at.x, y: max(at.y - size.height * 0.28, 14)) : at, anchor: .center))
        }
        if gap.n > 0 {
            out.append(PlotLabel(text: "Gap", at: CGPoint(x: gap.x / gap.n, y: gap.y / gap.n - 20), anchor: .center))
        }
        if raster.kind == .core, steelTop.n > 0 {
            out.append(PlotLabel(text: "Steel core", at: CGPoint(x: steelTop.x / steelTop.n, y: steelTop.y / steelTop.n), anchor: .center))
        }
        if raster.kind == .solenoid {
            out.append(PlotLabel(text: "axis", at: CGPoint(x: size.width / 2, y: 10), anchor: .center))
        }
        return out
    }

    private func legend(_ raster: FieldRaster) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LinearGradient(
                colors: layer == .electric
                    ? [Color(red: 42 / 255, green: 98 / 255, blue: 196 / 255), Color(white: 0.93), Color(red: 214 / 255, green: 59 / 255, blue: 45 / 255)]
                    : stride(from: 0.0, through: 1.0, by: 0.25).map {
                        let c = FieldPalette.magnitude($0)
                        return Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255)
                    },
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())
            HStack {
                if layer == .electric {
                    Text("−\(FieldFormat.volts(perMetre: cap))")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("+\(FieldFormat.volts(perMetre: cap))")
                } else {
                    Text("0")
                    Spacer()
                    Text(FieldFormat.tesla(cap))
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private func readout(_ raster: FieldRaster) -> some View {
        if let probe, let reading = probeReading(raster, probe) {
            VStack(alignment: .leading, spacing: 3) {
                Text("PROBE")
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Text(reading.position)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.foreground)
                Text("|B| \(FieldFormat.tesla(reading.probe.bMagnitude))   Bx \(FieldFormat.tesla(reading.probe.bx))   By \(FieldFormat.tesla(reading.probe.by))")
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Text("H \(FieldFormat.amps(perMetre: reading.probe.h)) in \(reading.probe.material.lowercased())   E \(FieldFormat.volts(perMetre: reading.probe.inducedE)) at \(Format.number(didt, digits: 0)) A/s")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("fieldExplorer.readout")
        } else {
            Text("Drag across the picture to read B, H, and induced E at any point.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    /// `point` is normalized: (0, 0) is the top-left of the picture and (1, 1) the bottom-right.
    private func probeReading(_ raster: FieldRaster, _ point: CGPoint) -> (probe: FieldRaster.Probe, position: String)? {
        let x = point.x * raster.widthM
        let y = (1 - point.y) * raster.heightM
        guard let probe = raster.probe(xM: x, yM: y, didt: didt) else { return nil }
        let position: String
        if centered {
            position = "x \(FieldFormat.length(x - raster.widthM / 2))   z \(FieldFormat.length(y - raster.heightM / 2))"
        } else {
            position = "x \(FieldFormat.length(x))   y \(FieldFormat.length(y))"
        }
        return (probe, position)
    }
}
