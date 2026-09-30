import SwiftUI
import BeckifyMath

/// Shared bar spectrum. Heights are 0…1 display stops, not calibrated SPL or g.
/// Ink follows the toolbox theme (system light or dark). It does not force a black theme.
struct SpectrumPlot: View {
    var heights: [Double]
    var leadingCaption: String?
    var trailingCaption: String?
    var footnote: String?
    var plotHeight: CGFloat = 112
    var accessibilityLabel: String
    /// 0…1 from the bottom. A median or display floor, not a calibrated noise spec.
    var referenceHeight: Double?
    var peakIndex: Int?

    init(
        heights: [Double],
        leadingCaption: String? = nil,
        trailingCaption: String? = nil,
        footnote: String? = nil,
        plotHeight: CGFloat = 112,
        accessibilityLabel: String,
        referenceHeight: Double? = nil,
        peakIndex: Int? = nil
    ) {
        self.heights = heights
        self.leadingCaption = leadingCaption
        self.trailingCaption = trailingCaption
        self.footnote = footnote
        self.plotHeight = plotHeight
        self.accessibilityLabel = accessibilityLabel
        self.referenceHeight = referenceHeight
        self.peakIndex = peakIndex
    }

    /// Audible-band microphone bars. Heat uses the Acoustic Imager display stops.
    init(
        bands: [AcousticDisplayBand],
        plotHeight: CGFloat = 112,
        accessibilityLabel: String? = nil,
        footnote: String? = nil
    ) {
        heights = bands.map { AcousticSpectrum.heat(dbFS: $0.dbFS) }
        leadingCaption = bands.first.map { Self.hertz($0.lowHz) }
        trailingCaption = bands.last.map { Self.hertz($0.highHz) }
        self.footnote = footnote
        self.plotHeight = plotHeight
        self.accessibilityLabel = accessibilityLabel ?? (bands.isEmpty
            ? "Spectrum idle"
            : "Audible spectrum, \(bands.count) bands, relative dBFS")
        let finite = heights.filter(\.isFinite).sorted()
        referenceHeight = finite.isEmpty ? nil : finite[finite.count / 2]
        peakIndex = heights.indices.max { heights[$0] < heights[$1] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                let count = heights.count
                guard count > 0 else { return }
                let gap: CGFloat = count > 16 ? 2 : 3
                let width = max(1, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
                for (index, raw) in heights.enumerated() {
                    let heat = CGFloat(min(1, max(0, raw.isFinite ? raw : 0)))
                    let bar = max(2, size.height * heat)
                    let rect = CGRect(
                        x: CGFloat(index) * (width + gap),
                        y: size.height - bar,
                        width: width,
                        height: bar
                    )
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(barColor(heat)))
                if peakIndex == index, heat > 0.02 {
                    let marker = CGRect(x: rect.midX - 3, y: max(0, rect.minY - 6), width: 6, height: 6)
                    context.fill(Path(ellipseIn: marker), with: .color(Theme.copper))
                }
            }
            if let referenceHeight, referenceHeight.isFinite {
                let y = size.height * (1 - CGFloat(min(1, max(0, referenceHeight))))
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Theme.muted.opacity(0.85)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .frame(height: plotHeight)
        .padding(6)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            if leadingCaption != nil || trailingCaption != nil {
                HStack {
                    Text(leadingCaption ?? "")
                    Spacer()
                    Text(trailingCaption ?? "")
                }
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            }
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func barColor(_ heat: CGFloat) -> Color {
        if heat > 0.72 { return Theme.bad }
        if heat > 0.4 { return Theme.warn }
        return Theme.accent
    }

    private static func hertz(_ hz: Double) -> String {
        guard hz.isFinite else { return "" }
        if hz >= 1000 {
            return "\(Format.number(hz / 1000, digits: hz >= 10_000 ? 0 : 1)) kHz"
        }
        return "\(Format.number(hz, digits: 0)) Hz"
    }
}

/// Time-domain trace. Used for Mag Sweep |B| and the vibration RMS preview.
struct TraceSparkline: View {
    var samples: [Double]
    var accessibilityLabel: String

    var body: some View {
        Canvas { context, size in
            guard samples.count >= 2 else {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(path, with: .color(Theme.muted.opacity(0.5)), lineWidth: 1)
                return
            }
            let minV = samples.min() ?? 0
            let maxV = samples.max() ?? 1
            let span = max(maxV - minV, 1)
            var path = Path()
            for (index, sample) in samples.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(samples.count - 1)
                let y = size.height * (1 - CGFloat((sample - minV) / span))
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(
                path,
                with: .color(Theme.accent),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 72)
        .accessibilityLabel(accessibilityLabel)
    }
}
