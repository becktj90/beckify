import BeckifyMath
import CarPlay
import SwiftUI
import UIKit

/// CarPlay templates can't host SwiftUI, so each gauge is drawn to an image
/// and handed to a grid button or detail card. The look is a 90s vacuum-fluorescent
/// cluster: segmented gauges, glowing seven-segment digits over unlit "8"s,
/// scanlines, and a bezel. Always the dark palette: the images carry their own
/// background and read the same on light and dark CarPlay screens.
@MainActor
enum CarPlayTileRenderer {
    /// iOS 26 reports the connected display's grid image limit at runtime.
    /// Earlier CarPlay grids use the legacy 40-point button artwork size.
    static var gridImageSize: CGSize {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return CPGridTemplate.maximumGridButtonImageSize
        }
        #endif
        return CGSize(width: 40, height: 40)
    }

    /// Square tile for a home grid button.
    static func image(_ tile: DriveCarPlayTile, size: CGSize, scale: CGFloat) -> UIImage {
        let side = max(1, min(size.width, size.height))
        return render(CarPlayGaugeTileView(tile: tile, side: side).frame(width: side, height: side), scale: scale)
    }

    /// Full-bleed card for the Gauges screen: big gauge plus a readout panel.
    static func clusterImage(_ tile: DriveCarPlayTile, size: CGSize, scale: CGFloat) -> UIImage {
        let size = CGSize(width: max(1, size.width), height: max(1, size.height))
        return render(CarPlayGaugeClusterView(tile: tile, size: size).frame(width: size.width, height: size.height), scale: scale)
    }

    private static func render(_ content: some View, scale: CGFloat) -> UIImage {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, .dark))
        renderer.scale = max(1, scale)
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - Shared 90s styling

enum VFDStyle {
    /// Dark smoked glass behind the display.
    static let glass = Color(red: 0.016, green: 0.035, blue: 0.045)

    static func tint(_ tone: DriveCarPlayTile.Tone) -> Color {
        switch tone {
        case .accent: return DriveTheme.accent
        case .regen: return DriveTheme.regen
        case .caution: return DriveTheme.warning
        case .critical: return DriveTheme.critical
        case .cold: return DriveTheme.cold
        case .estimated: return DriveTheme.estimated
        case .muted: return DriveTheme.muted
        }
    }

    /// Numbers glow in the tile's color; estimates keep the violet estimate color.
    static func valueColor(_ tile: DriveCarPlayTile) -> Color {
        if tile.gauge == nil { return DriveTheme.muted }
        if tile.isEstimate { return DriveTheme.estimated }
        return tint(tile.tone)
    }

    static func isNumeric(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" }
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: max(1, size), weight: weight, design: .monospaced)
    }
}

/// Glass, glow, scanlines, and a double bezel line.
private struct VFDPanel: View {
    let tint: Color
    let cornerRadius: CGFloat
    let side: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(VFDStyle.glass)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(RadialGradient(colors: [tint.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: side * 0.75))
            Scanlines(spacing: max(2, side * 0.018))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: max(1, side * 0.008))
            RoundedRectangle(cornerRadius: cornerRadius * 0.8, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: max(0.5, side * 0.004))
                .padding(side * 0.022)
        }
    }
}

private struct Scanlines: View {
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: spacing * 0.4)), with: .color(.black.opacity(0.22)))
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Discrete LED-style segments along a ring, an open arc, or a top semicircle.
struct SegmentedArc: View {
    enum Style {
        /// Full circle from 12 o'clock.
        case ring
        /// 270°, open at the bottom.
        case arc
        /// Top semicircle with zero at 12 o'clock: negative fills left, positive right.
        case bipolar
    }

    let style: Style
    let fraction: Double
    let tint: Color
    let thickness: CGFloat
    var segments = 36

    var body: some View {
        Canvas { context, size in
            let (center, radius) = geometry(size)
            let (start, sweep) = angles
            let step = sweep / Double(segments)
            let gap = step * 0.22
            let lit = litRange
            for index in 0..<segments {
                let a0 = start + Double(index) * step + gap / 2
                let a1 = a0 + step - gap
                var path = Path()
                path.addArc(center: center, radius: radius, startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
                let on = lit.contains(index)
                if on {
                    var glow = context
                    glow.addFilter(.blur(radius: thickness * 0.55))
                    glow.stroke(path, with: .color(tint.opacity(0.75)), lineWidth: thickness)
                }
                context.stroke(path, with: .color(on ? tint : tint.opacity(0.13)), lineWidth: thickness)
            }
        }
    }

    private var angles: (start: Double, sweep: Double) {
        switch style {
        case .ring: return (-90, 360)
        case .arc: return (135, 270)
        case .bipolar: return (180, 180)
        }
    }

    private func geometry(_ size: CGSize) -> (CGPoint, CGFloat) {
        switch style {
        case .ring, .arc:
            let radius = max(1, min(size.width, size.height) / 2 - thickness)
            return (CGPoint(x: size.width / 2, y: size.height / 2), radius)
        case .bipolar:
            let radius = max(1, min(size.width / 2, size.height) - thickness)
            return (CGPoint(x: size.width / 2, y: size.height - thickness / 2), radius)
        }
    }

    private var litRange: Range<Int> {
        let f = fraction.isFinite ? fraction : 0
        switch style {
        case .ring, .arc:
            let count = Int((min(max(f, 0), 1) * Double(segments)).rounded())
            return 0..<count
        case .bipolar:
            let half = segments / 2
            let count = Int((min(abs(f), 1) * Double(half)).rounded())
            return f >= 0 ? half..<(half + count) : (half - count)..<half
        }
    }
}

/// A row of LED blocks, 0…1.
struct SegmentedBar: View {
    let fraction: Double
    let tint: Color
    var blocks = 16

    var body: some View {
        Canvas { context, size in
            let gap = size.width * 0.012
            let width = (size.width - gap * CGFloat(blocks - 1)) / CGFloat(blocks)
            let f = fraction.isFinite ? min(max(fraction, 0), 1) : 0
            let lit = Int((f * Double(blocks)).rounded())
            for index in 0..<blocks {
                let rect = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: size.height)
                let path = Path(roundedRect: rect, cornerRadius: min(width, size.height) * 0.18)
                let on = index < lit
                if on {
                    var glow = context
                    glow.addFilter(.blur(radius: size.height * 0.35))
                    glow.fill(path, with: .color(tint.opacity(0.7)))
                }
                context.fill(path, with: .color(on ? tint : tint.opacity(0.13)))
            }
        }
    }
}

/// Glowing seven-segment number padded with unlit "8"s, shrunk to fit.
private struct VFDNumber: View {
    let text: String
    let height: CGFloat
    let maxWidth: CGFloat
    let color: Color
    var ghostDigits = 3

    var body: some View {
        let width = RetroDigits.width(text, height: height, ghostDigits: ghostDigits)
        RetroDigits(text: text, height: height, color: color, ghostDigits: ghostDigits)
            .scaleEffect(width > maxWidth && width > 0 ? maxWidth / width : 1)
            .frame(width: min(width, maxWidth), height: height)
    }
}

/// Big number, or a heavy glowing word for states like REGEN.
private struct VFDReadout: View {
    let tile: DriveCarPlayTile
    let digitHeight: CGFloat
    let maxWidth: CGFloat
    let showUnit: Bool

    var body: some View {
        let color = VFDStyle.valueColor(tile)
        VStack(spacing: digitHeight * 0.1) {
            if VFDStyle.isNumeric(tile.value) {
                VFDNumber(text: tile.value, height: digitHeight, maxWidth: maxWidth, color: color)
            } else {
                Text(tile.value)
                    .font(VFDStyle.mono(digitHeight * 0.62, .heavy))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.8), radius: digitHeight * 0.12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: maxWidth)
            }
            if showUnit, !tile.unit.isEmpty {
                Text(tile.unit.uppercased())
                    .font(VFDStyle.mono(digitHeight * 0.3, .semibold))
                    .foregroundStyle(color.opacity(0.75))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Grid tile (home screen)

/// One square tile: segmented gauge, glowing digits, unit, corner icon.
struct CarPlayGaugeTileView: View {
    let tile: DriveCarPlayTile
    let side: CGFloat

    /// Very small tiles drop the unit and icon; the image title carries them.
    private var compact: Bool { side < 72 }
    private var tint: Color { VFDStyle.tint(tile.tone) }
    private var thickness: CGFloat { max(3, side * 0.075) }

    var body: some View {
        ZStack {
            VFDPanel(tint: tint, cornerRadius: side * 0.18, side: side)
            gauge
            if !compact {
                Image(systemName: tile.symbol)
                    .font(.system(size: side * 0.1, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.8), radius: side * 0.02)
                    .position(x: side * 0.14, y: side * 0.14)
            }
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder private var gauge: some View {
        switch tile.gauge {
        case .ring(let fraction)?:
            ZStack {
                SegmentedArc(style: .ring, fraction: fraction, tint: tint, thickness: thickness, segments: 30)
                readout(0.27)
            }
            .padding(side * 0.07)
        case .arc(let fraction)?:
            ZStack {
                SegmentedArc(style: .arc, fraction: fraction, tint: tint, thickness: thickness, segments: 27)
                readout(0.27)
            }
            .padding(side * 0.07)
        case .bipolar(let fraction)?:
            VStack(spacing: side * 0.02) {
                SegmentedArc(style: .bipolar, fraction: fraction, tint: tint, thickness: thickness, segments: 20)
                    .frame(width: side * 0.84, height: side * 0.4)
                readout(0.26)
            }
            .padding(.top, side * 0.08)
        case .bar(let fraction)?:
            VStack(spacing: side * 0.07) {
                readout(0.3)
                SegmentedBar(fraction: fraction, tint: tint, blocks: 10)
                    .frame(width: side * 0.76, height: thickness * 1.3)
            }
        case .symbol?:
            ZStack {
                Image(systemName: tile.symbol)
                    .font(.system(size: side * 0.46, weight: .bold))
                    .foregroundStyle(tint.opacity(0.14))
                readout(0.3)
            }
        case nil:
            ZStack {
                Image(systemName: tile.symbol)
                    .font(.system(size: side * 0.38, weight: .semibold))
                    .foregroundStyle(DriveTheme.track)
                Text(DriveCarPlayTiles.missing)
                    .font(VFDStyle.mono(side * 0.24))
                    .foregroundStyle(DriveTheme.muted)
            }
        }
    }

    private func readout(_ digitScale: CGFloat) -> some View {
        VFDReadout(tile: tile, digitHeight: side * digitScale, maxWidth: side * 0.66, showUnit: !compact)
    }
}

// MARK: - Detail card (Gauges screen)

/// The large card: header with icon, name and source badge; a big segmented
/// gauge with end labels; and a three-line readout panel underneath. All text
/// is drawn in the image, so the card needs no CarPlay caption over it.
struct CarPlayGaugeClusterView: View {
    let tile: DriveCarPlayTile
    let size: CGSize

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }
    private var unit: CGFloat { min(w, h) }
    private var pad: CGFloat { unit * 0.065 }
    private var tint: Color { VFDStyle.tint(tile.tone) }
    private var thickness: CGFloat { max(4, unit * 0.07) }

    var body: some View {
        ZStack {
            VFDPanel(tint: tint, cornerRadius: unit * 0.1, side: unit)
            VStack(spacing: h * 0.02) {
                header
                    .frame(height: h * 0.1)
                gaugeZone
                    .frame(height: h * 0.5)
                scaleRow
                    .frame(height: h * 0.05)
                readoutPanel
                    .frame(maxHeight: .infinity)
            }
            .padding(pad)
        }
        .frame(width: w, height: h)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: unit * 0.03) {
            Image(systemName: tile.symbol)
                .font(.system(size: h * 0.06, weight: .bold))
            Text(tile.title.uppercased())
                .font(VFDStyle.mono(h * 0.06, .heavy))
                .tracking(unit * 0.008)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            if !tile.note.isEmpty {
                Text(tile.note.uppercased())
                    .font(VFDStyle.mono(h * 0.04, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, unit * 0.02)
                    .padding(.vertical, unit * 0.006)
                    .foregroundStyle(badgeColor)
                    .overlay(RoundedRectangle(cornerRadius: unit * 0.015).stroke(badgeColor, lineWidth: max(1, unit * 0.006)))
            }
        }
        .foregroundStyle(tint)
        .shadow(color: tint.opacity(0.7), radius: unit * 0.015)
    }

    /// Amber "lamp" for estimates and missing readings, like a 90s warning indicator.
    private var badgeColor: Color {
        if tile.gauge == nil { return DriveTheme.warning }
        return tile.isEstimate ? DriveTheme.estimated : tint
    }

    // MARK: Gauge

    @ViewBuilder private var gaugeZone: some View {
        let zone = CGSize(width: w - pad * 2, height: h * 0.5)
        let dial = min(zone.width, zone.height)
        switch tile.gauge {
        case .ring(let fraction)?:
            ZStack {
                SegmentedArc(style: .ring, fraction: fraction, tint: tint, thickness: thickness, segments: 40)
                    .frame(width: dial, height: dial)
                readout(height: dial * 0.28, maxWidth: dial * 0.62)
            }
        case .arc(let fraction)?:
            ZStack {
                SegmentedArc(style: .arc, fraction: fraction, tint: tint, thickness: thickness, segments: 36)
                    .frame(width: dial, height: dial)
                readout(height: dial * 0.28, maxWidth: dial * 0.62)
            }
        case .bipolar(let fraction)?:
            VStack(spacing: zone.height * 0.03) {
                SegmentedArc(style: .bipolar, fraction: fraction, tint: tint, thickness: thickness, segments: 30)
                    .frame(width: min(zone.width, zone.height * 1.15), height: zone.height * 0.5)
                readout(height: zone.height * 0.3, maxWidth: zone.width * 0.8)
            }
        case .bar(let fraction)?:
            VStack(spacing: zone.height * 0.08) {
                readout(height: zone.height * 0.42, maxWidth: zone.width * 0.85)
                SegmentedBar(fraction: fraction, tint: tint, blocks: 16)
                    .frame(width: zone.width, height: zone.height * 0.12)
            }
        case .symbol?:
            ZStack {
                Image(systemName: tile.symbol)
                    .font(.system(size: dial * 0.6, weight: .bold))
                    .foregroundStyle(tint.opacity(0.12))
                readout(height: zone.height * 0.42, maxWidth: zone.width * 0.85)
            }
        case nil:
            ZStack {
                Image(systemName: tile.symbol)
                    .font(.system(size: dial * 0.5, weight: .semibold))
                    .foregroundStyle(DriveTheme.track)
                VStack(spacing: zone.height * 0.04) {
                    VFDNumber(text: "", height: zone.height * 0.34, maxWidth: zone.width * 0.8, color: DriveTheme.muted)
                    Text("NOT READ")
                        .font(VFDStyle.mono(zone.height * 0.09, .heavy))
                        .foregroundStyle(DriveTheme.warning)
                        .shadow(color: DriveTheme.warning.opacity(0.7), radius: unit * 0.015)
                }
            }
        }
    }

    private func readout(height: CGFloat, maxWidth: CGFloat) -> some View {
        VFDReadout(tile: tile, digitHeight: height, maxWidth: maxWidth, showUnit: true)
    }

    // MARK: Scale and readouts

    @ViewBuilder private var scaleRow: some View {
        if let labels = tile.scaleLabels {
            HStack {
                Text(labels.low)
                Spacer(minLength: 0)
                Text(labels.high)
            }
            .font(VFDStyle.mono(h * 0.04, .bold))
            .foregroundStyle(tint.opacity(0.75))
            .lineLimit(1)
        } else {
            Color.clear
        }
    }

    private var readoutPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(tile.readouts.prefix(3).enumerated()), id: \.offset) { index, line in
                if index > 0 {
                    Rectangle()
                        .fill(tint.opacity(0.18))
                        .frame(height: max(0.5, unit * 0.003))
                }
                HStack(spacing: unit * 0.02) {
                    Text(line.label)
                        .font(VFDStyle.mono(h * 0.038, .semibold))
                        .foregroundStyle(DriveTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    Text(line.value)
                        .font(VFDStyle.mono(h * 0.05, .heavy))
                        .foregroundStyle(line.value == DriveCarPlayTiles.missing ? DriveTheme.muted : tint)
                        .shadow(color: tint.opacity(line.value == DriveCarPlayTiles.missing ? 0 : 0.7), radius: unit * 0.012)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, unit * 0.035)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.035, style: .continuous)
                .fill(Color.black.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.035, style: .continuous)
                .strokeBorder(tint.opacity(0.3), lineWidth: max(0.5, unit * 0.004))
        )
    }
}

#if DEBUG
/// Debug-only stand-in for the CarPlay screens so CI can screenshot them:
/// `-BeckifyDriveCarPlayPreview YES`. Same renderer CarPlay gets, fixed inputs.
struct CarPlayTilesPreview: View {
    private static let us = DriveUnitPreference.systemDefault(measurementSystem: "us")

    private static let samples: [(headline: String, input: DriveCarPlayTileInputs)] = [
        ("DRIVE · Live · Bolt EUV", DriveCarPlayTileInputs(
            layout: .ev, socPercent: 89, powerKW: 40.3, peakPowerKW: 61, flow: .drive,
            speedKph: 96.6, speedSource: "OBD", rangeMiles: 214, weatherRangeMiles: 188,
            whPerMile: 290, packTempC: 29, ambientC: 9, hvCurrentAmps: 115, torqueNm: 271,
            tripKm: 23.4, maxSpeedKph: 112, avgSpeedKph: 54, regenKWh: 0.8, netKWh: 3.3,
            regenScore: 0.62, motorTempC: 41
        )),
        ("REGEN · Live · Bolt EUV", DriveCarPlayTileInputs(
            layout: .ev, socPercent: 12, powerKW: -24, peakPowerKW: 42, flow: .regen,
            speedKph: 52, speedSource: "OBD", whPerMile: 260, packTempC: 48
        )),
        ("Live · Generic OBD", DriveCarPlayTileInputs(
            layout: .powertrain, speedKph: 88.5, speedSource: "OBD", rpm: 2_430,
            coolantC: 91, fuelPercent: 63, moduleVolts: 14.3, ambientC: 9
        )),
    ]

    /// Close to the card size seen on a car's CarPlay screen.
    private static let cardSize = CGSize(width: 168, height: 200)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("CarPlay preview")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DriveTheme.text)
                ForEach(Array(Self.samples.enumerated()), id: \.offset) { _, sample in
                    let tiles = DriveCarPlayTiles.make(sample.input, units: Self.us)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(sample.headline)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DriveTheme.text)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(tiles) { tile in
                                VStack(spacing: 4) {
                                    Image(uiImage: CarPlayTileRenderer.image(tile, size: CarPlayTileRenderer.gridImageSize, scale: 3))
                                        .accessibilityHidden(true)
                                    Text(tile.spoken)
                                        .font(.caption2)
                                        .foregroundStyle(DriveTheme.text)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(tile.spoken)
                            }
                        }
                    }
                    .padding(12)
                    .background(DriveTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Text("Gauges and Readings are separate tabs. Layout here is illustrative; CarPlay controls the actual grid.")
                    .font(.caption)
                    .foregroundStyle(DriveTheme.muted)
                Text("Gauges screen (tap a tile)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DriveTheme.text)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(DriveCarPlayTiles.make(Self.samples[0].input, units: Self.us)) { tile in
                            Image(uiImage: CarPlayTileRenderer.clusterImage(tile, size: Self.cardSize, scale: 3))
                                .resizable()
                                .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(DriveTheme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
#endif
