import BeckifyMath
import SwiftUI
import UIKit

/// CarPlay templates can't host SwiftUI, so each gauge tile is drawn to an
/// image in the phone dashboard's style and handed to a list image row.
/// Tiles always use the dark palette: they carry their own background and
/// read the same on light and dark CarPlay screens.
@MainActor
enum CarPlayTileRenderer {
    static func image(_ tile: DriveCarPlayTile, size: CGSize, scale: CGFloat) -> UIImage {
        let side = max(1, min(size.width, size.height))
        let content = CarPlayGaugeTileView(tile: tile, side: side)
            .frame(width: side, height: side)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = max(1, scale)
        return renderer.uiImage ?? UIImage()
    }
}

/// One square tile: background glow, gauge, retro digits, unit, corner icon.
struct CarPlayGaugeTileView: View {
    let tile: DriveCarPlayTile
    let side: CGFloat

    /// Very small tiles drop the unit and icon; the image title carries them.
    private var compact: Bool { side < 72 }
    private var lineWidth: CGFloat { max(3, side * 0.075) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.2, style: .continuous)
                .fill(DriveTheme.background)
            RoundedRectangle(cornerRadius: side * 0.2, style: .continuous)
                .fill(RadialGradient(colors: [tint.opacity(0.32), .clear], center: .top, startRadius: 0, endRadius: side))
            RoundedRectangle(cornerRadius: side * 0.2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: max(1, side * 0.01))
            gauge
            if !compact {
                Image(systemName: tile.symbol)
                    .font(.system(size: side * 0.11, weight: .semibold))
                    .foregroundStyle(tint)
                    .position(x: side * 0.15, y: side * 0.15)
            }
        }
        .frame(width: side, height: side)
    }

    // MARK: Gauges

    @ViewBuilder private var gauge: some View {
        switch tile.gauge {
        case .ring(let fraction)?:
            ZStack {
                Circle().stroke(DriveTheme.track, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                readout(digitScale: 0.24)
            }
            .padding(side * 0.14)
        case .arc(let fraction)?:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(DriveTheme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: 0.75 * fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(135))
                readout(digitScale: 0.24)
            }
            .padding(side * 0.14)
        case .bipolar(let fraction)?:
            VStack(spacing: side * 0.02) {
                BipolarArc(fraction: fraction, tint: tint, lineWidth: lineWidth)
                    .frame(width: side * 0.78, height: side * 0.39)
                readout(digitScale: 0.24)
            }
            .padding(.top, side * 0.1)
        case .bar(let fraction)?:
            VStack(spacing: side * 0.06) {
                readout(digitScale: 0.26)
                ZStack(alignment: .leading) {
                    Capsule().fill(DriveTheme.track)
                    Capsule().fill(tint).frame(width: side * 0.7 * fraction)
                }
                .frame(width: side * 0.7, height: lineWidth)
            }
        case .symbol?:
            ZStack {
                Image(systemName: tile.symbol)
                    .font(.system(size: side * 0.42, weight: .bold))
                    .foregroundStyle(tint.opacity(0.16))
                readout(digitScale: 0.26)
            }
        case nil:
            ZStack {
                Image(systemName: tile.symbol)
                    .font(.system(size: side * 0.36, weight: .semibold))
                    .foregroundStyle(DriveTheme.track)
                Text(DriveCarPlayTiles.missing)
                    .font(.system(size: side * 0.24, weight: .bold, design: .rounded))
                    .foregroundStyle(DriveTheme.muted)
            }
        }
    }

    /// Retro digits for numbers, a heavy word for states like REGEN.
    private func readout(digitScale: CGFloat) -> some View {
        VStack(spacing: side * 0.01) {
            if Self.isNumeric(tile.value) {
                RetroDigits(text: tile.value, height: side * digitScale, color: valueColor)
                    .scaleEffect(Self.fitScale(tile.value, digitHeight: side * digitScale, maxWidth: side * 0.62))
            } else {
                Text(tile.value)
                    .font(.system(size: side * 0.16, weight: .heavy, design: .rounded))
                    .tracking(side * 0.01)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: side * 0.84)
            }
            if !compact, !tile.unit.isEmpty {
                Text(tile.unit)
                    .font(.system(size: side * 0.1, weight: .semibold, design: .rounded))
                    .foregroundStyle(DriveTheme.muted)
                    .lineLimit(1)
            }
        }
    }

    private var tint: Color {
        switch tile.tone {
        case .accent: return DriveTheme.accent
        case .regen: return DriveTheme.regen
        case .caution: return DriveTheme.warning
        case .critical: return DriveTheme.critical
        case .cold: return DriveTheme.cold
        case .estimated: return DriveTheme.estimated
        case .muted: return DriveTheme.muted
        }
    }

    /// Estimates keep the violet estimate color, as on the phone.
    private var valueColor: Color {
        if tile.isEstimate { return DriveTheme.estimated }
        switch tile.tone {
        case .caution, .critical, .cold: return tint
        default: return DriveTheme.text
        }
    }

    static func isNumeric(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" }
    }

    /// Shrinks long numbers (e.g. "2430") so they stay inside the gauge.
    static func fitScale(_ text: String, digitHeight: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let width = RetroDigits.glyphs(text).reduce(CGFloat(0)) { $0 + $1.advance(height: digitHeight) }
        guard width > maxWidth, width > 0 else { return 1 }
        return maxWidth / width
    }
}

/// Top semicircle with zero at 12 o'clock: drive fills right, regen fills left.
private struct BipolarArc: View {
    let fraction: Double
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height * 2)
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1)
                    .stroke(DriveTheme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if fraction != 0 {
                    Circle()
                        .trim(
                            from: fraction >= 0 ? 0.75 : 0.75 + 0.25 * fraction,
                            to: fraction >= 0 ? 0.75 + 0.25 * fraction : 0.75
                        )
                        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                }
                Capsule()
                    .fill(DriveTheme.muted)
                    .frame(width: max(2, lineWidth * 0.3), height: lineWidth + 4)
                    .offset(y: -(diameter - lineWidth) / 2)
            }
            .frame(width: diameter - lineWidth, height: diameter - lineWidth)
            .position(x: geo.size.width / 2, y: geo.size.height)
        }
    }
}

#if DEBUG
/// Debug-only stand-in for the CarPlay list so CI can screenshot the tiles:
/// `-BeckifyDriveCarPlayPreview YES`. Same renderer CarPlay gets, fixed inputs.
struct CarPlayTilesPreview: View {
    private static let us = DriveUnitPreference.systemDefault(measurementSystem: "us")

    private static let samples: [(headline: String, input: DriveCarPlayTileInputs)] = [
        ("DRIVE · Live · Bolt EUV", DriveCarPlayTileInputs(
            layout: .ev, socPercent: 64.7, powerKW: 11.2, peakPowerKW: 42, flow: .drive,
            speedKph: 96.6, speedSource: "OBD", rangeMiles: 167, weatherRangeMiles: 140,
            whPerMile: 290, packTempC: 29
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("CarPlay preview")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DriveTheme.text)
                ForEach(Array(Self.samples.enumerated()), id: \.offset) { _, sample in
                    let tiles = DriveCarPlayTiles.make(sample.input, units: Self.us)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(stride(from: 0, to: tiles.count, by: 4).enumerated()), id: \.offset) { row, start in
                            let chunk = Array(tiles[start..<min(start + 4, tiles.count)])
                            Text(row == 0 ? sample.headline : chunk.map(\.title).joined(separator: " · "))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DriveTheme.text)
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(chunk) { tile in
                                    VStack(spacing: 4) {
                                        Image(uiImage: CarPlayTileRenderer.image(tile, size: CGSize(width: 84, height: 84), scale: 3))
                                            .resizable()
                                            .frame(width: 84, height: 84)
                                        Text(tile.spoken)
                                            .font(.caption2)
                                            .foregroundStyle(DriveTheme.muted)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 84)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(DriveTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(16)
        }
        .background(DriveTheme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
#endif
