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
    /// Room & Rig Check opts in. The axis titles stay on every spectrum either way.
    var showsRelativeDBFSScale: Bool
    var xAxis: PlotAxis
    var yAxis: PlotAxis
    var barReadouts: [String]
    var inspection: PlotInspection

    init(
        heights: [Double],
        leadingCaption: String? = nil,
        trailingCaption: String? = nil,
        footnote: String? = nil,
        plotHeight: CGFloat = 112,
        accessibilityLabel: String,
        referenceHeight: Double? = nil,
        peakIndex: Int? = nil,
        showsRelativeDBFSScale: Bool = false,
        xAxis: PlotAxis? = nil,
        yAxis: PlotAxis? = nil,
        barReadouts: [String] = [],
        inspection: PlotInspection = .inspect
    ) {
        self.heights = heights
        self.leadingCaption = leadingCaption
        self.trailingCaption = trailingCaption
        self.footnote = footnote
        self.plotHeight = plotHeight
        self.accessibilityLabel = accessibilityLabel
        self.referenceHeight = referenceHeight
        self.peakIndex = peakIndex
        self.showsRelativeDBFSScale = showsRelativeDBFSScale
        self.xAxis = xAxis ?? PlotAxis(
            title: "Frequency",
            unit: "Hz",
            start: leadingCaption ?? "",
            end: trailingCaption ?? ""
        )
        if let yAxis {
            self.yAxis = yAxis
        } else if showsRelativeDBFSScale {
            self.yAxis = Self.dbfsAxis
        } else {
            self.yAxis = PlotAxis(title: "Level", unit: "relative", start: "0", mid: "0.5", end: "1")
        }
        self.barReadouts = barReadouts
        self.inspection = inspection
    }

    /// Audible-band microphone bars. Heat uses the Acoustic Imager display stops.
    init(
        bands: [AcousticDisplayBand],
        plotHeight: CGFloat = 112,
        accessibilityLabel: String? = nil,
        footnote: String? = nil,
        showsRelativeDBFSScale: Bool = false
    ) {
        // Locals only. A closure over `self.heights` here captures every stored
        // property, including `showsRelativeDBFSScale`, before it is set.
        let levels = bands.map { AcousticSpectrum.heat(dbFS: $0.dbFS, isAvailable: $0.isAvailable) }
        let showsRelative = showsRelativeDBFSScale
        let finite = zip(bands, levels).compactMap { band, level -> Double? in
            band.isAvailable && level.isFinite ? level : nil
        }.sorted()
        let peak = bands.indices.filter { bands[$0].isAvailable }.max { levels[$0] < levels[$1] }
        let leading = bands.first.map { Self.hertz($0.lowHz) }
        let trailing = bands.last.map { Self.hertz($0.highHz) }
        let readouts = bands.map { band in
            if band.isAvailable {
                return "\(Self.hertz(band.centerHz)), \(Format.number(band.dbFS, digits: 0)) dBFS"
            }
            return "\(Self.hertz(band.centerHz)), unavailable"
        }
        heights = levels
        leadingCaption = leading
        trailingCaption = trailing
        self.footnote = footnote
        self.plotHeight = plotHeight
        self.accessibilityLabel = accessibilityLabel ?? (bands.isEmpty
            ? "Spectrum idle"
            : "Audible spectrum, \(bands.count) bands, amplitude in dBFS, frequency in hertz")
        referenceHeight = finite.isEmpty ? nil : finite[finite.count / 2]
        peakIndex = peak
        self.showsRelativeDBFSScale = showsRelative
        xAxis = PlotAxis(
            title: "Frequency",
            unit: "Hz",
            start: leading ?? "",
            end: trailing ?? ""
        )
        yAxis = Self.dbfsAxis
        barReadouts = readouts
        inspection = .inspect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledPlotChrome(
                xAxis: xAxis,
                yAxis: yAxis,
                accessibilityLabel: accessibilityLabel,
                inspection: inspection,
                plotHeight: plotHeight,
                fullscreenTitle: "Spectrum",
                readout: describe
            ) {
                barCanvas
            }
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func describe(x: CGFloat, y: CGFloat) -> String {
        guard !heights.isEmpty else { return "No spectrum yet" }
        let index = min(heights.count - 1, max(0, Int(x * CGFloat(heights.count))))
        if barReadouts.indices.contains(index) {
            return barReadouts[index]
        }
        let level = heights[index]
        let shown = level.isFinite ? Format.number(level, digits: 2) : "—"
        return "Bin \(index + 1) of \(heights.count), relative \(shown)"
    }

    private var barCanvas: some View {
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
                context.stroke(line, with: .color(Theme.foreground.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }

    private func barColor(_ heat: CGFloat) -> Color {
        if heat > 0.72 { return Theme.bad }
        if heat > 0.4 { return Theme.warn }
        return Theme.accent
    }

    private static var dbfsAxis: PlotAxis {
        PlotAxis(
            title: "Amplitude",
            unit: "dBFS",
            start: dbfsTick(AcousticSpectrum.displayFloorDBFS),
            mid: dbfsTick((AcousticSpectrum.displayCeilingDBFS + AcousticSpectrum.displayFloorDBFS) / 2),
            end: dbfsTick(AcousticSpectrum.displayCeilingDBFS)
        )
    }

    private static func dbfsTick(_ db: Double) -> String {
        Format.number(db, digits: 0)
    }

    private static func hertz(_ hz: Double) -> String {
        guard hz.isFinite else { return "" }
        if hz >= 1000 {
            return "\(Format.number(hz / 1000, digits: hz >= 10_000 ? 0 : 1)) kHz"
        }
        return "\(Format.number(hz, digits: 0)) Hz"
    }
}

/// Time-domain trace. Used for Mag Sweep |B|, noise level, and the vibration preview.
struct TraceSparkline: View {
    var samples: [Double]
    var accessibilityLabel: String
    var yAxis: PlotAxis
    var xAxis: PlotAxis
    var inspection: PlotInspection
    var fullscreenTitle: String

    init(
        samples: [Double],
        accessibilityLabel: String,
        showsDBFSTimeAxes: Bool = false,
        yAxis: PlotAxis? = nil,
        xAxis: PlotAxis? = nil,
        inspection: PlotInspection = .inspect,
        fullscreenTitle: String = "Trace"
    ) {
        self.samples = samples
        self.accessibilityLabel = accessibilityLabel
        self.inspection = inspection
        self.fullscreenTitle = fullscreenTitle
        let finite = samples.filter(\.isFinite)
        let top = finite.max()
        let bottom = finite.min()
        if let yAxis {
            self.yAxis = yAxis
        } else if showsDBFSTimeAxes {
            self.yAxis = PlotAxis(
                title: "Amplitude",
                unit: "dBFS",
                start: Self.tick(bottom),
                end: Self.tick(top)
            )
        } else {
            self.yAxis = PlotAxis(
                title: "Value",
                unit: "",
                start: Self.tick(bottom),
                end: Self.tick(top)
            )
        }
        self.xAxis = xAxis ?? PlotAxis(title: "Time", unit: "", start: "older", end: "now")
    }

    var body: some View {
        LabeledPlotChrome(
            xAxis: displayedX,
            yAxis: displayedY,
            accessibilityLabel: accessibilityLabel,
            inspection: inspection,
            plotHeight: 96,
            fullscreenTitle: fullscreenTitle,
            readout: describe
        ) {
            sparkCanvas
        }
    }

    private var displayedY: PlotAxis {
        let finite = samples.filter(\.isFinite)
        var axis = yAxis
        let low = finite.min()
        let high = finite.max()
        axis.start = Self.tick(low)
        axis.end = Self.tick(high)
        if let low, let high, low.isFinite, high.isFinite {
            axis.mid = Self.tick((low + high) / 2)
        }
        return axis
    }

    private var displayedX: PlotAxis { xAxis }

    private func describe(x: CGFloat, y: CGFloat) -> String {
        let finiteCount = samples.count
        guard finiteCount >= 1 else { return "No samples yet" }
        let index = min(finiteCount - 1, max(0, Int((x * CGFloat(finiteCount - 1)).rounded())))
        let sample = samples[index]
        let value = sample.isFinite ? Format.number(sample, digits: 2) : "—"
        return "\(xAxis.titleWithUnit) sample \(index + 1) of \(finiteCount), \(yAxis.titleWithUnit) \(value)"
    }

    private static func tick(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return Format.number(value, digits: 0)
    }

    private var sparkCanvas: some View {
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
    }
}
