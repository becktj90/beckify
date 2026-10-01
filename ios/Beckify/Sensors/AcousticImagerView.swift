import SwiftUI
import BeckifyMath

struct AcousticImagerView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var spectrum = MicrophoneSpectrumCenter.shared
    @State private var micToken = UUID()
    @State private var history: [[Double]] = []
    @StoredInput(.acousticImager, "jobName", default: "Acoustic snapshot") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .acousticImager,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Field visualization only. Not a Fluke acoustic camera, not ultrasonic beamforming, not a gas-leak locator, and not a calibrated SPL meter. A single microphone cannot place a leak. Saving stores numbers — not a recording. Noise Meter and Room & Rig Check share this microphone tap.")
        ) {
            ShowWorkCard(
                toolID: .acousticImager,
                symbolic: "Band dBFS from an on-device real FFT",
                substituted: sticky,
                meaning: "The microphone tap feeds an Accelerate FFT. Bars are relative energy by frequency. The level map is those same bands over the last few seconds. One microphone cannot locate a leak."
            )
            if spectrum.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "Acoustic Imager needs the microphone for a live spectrum. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            }
            ResultCard(title: "Spectrum", copyText: copyText) {
                ResultRow(label: "Level", value: Format.dbfs(spectrum.rmsDBFS), emphasis: true, tone: Theme.good)
                ResultRow(label: "Peak band", value: peakLabel, tone: Theme.copper)
                ResultRow(label: "Engine", value: spectrum.status)
                SpectrumPlot(
                    bands: spectrum.bands,
                    footnote: imagerFootnote
                )
                .padding(.top, 8)
            }
            ResultCard(title: "Time activity") {
                Text("Recent audible bands. Left is lower frequency, bottom is newer. Brighter means more relative energy on this phone. Not a leak position, not SPL, not ultrasonic.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                AcousticLevelMap(
                    history: history,
                    lowLabel: spectrum.bands.first.map { Self.hertz($0.lowHz) } ?? "low",
                    highLabel: spectrum.bands.last.map { Self.hertz($0.highHz) } ?? "high"
                )
                    .padding(.top, 6)
            }
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: spectrum.hasReading) { save() }
        }
        .onAppear { retainMic() }
        .onDisappear { spectrum.release(micToken) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: retainMic()
            case .background: spectrum.release(micToken)
            default: break
            }
        }
        .onChange(of: spectrum.bands) { _, bands in
            guard !bands.isEmpty else { return }
            history.append(bands.map(\.dbFS))
            if history.count > 36 { history.removeFirst(history.count - 36) }
        }
    }

    private func retainMic() {
        spectrum.retain(micToken, role: "Acoustic Imager")
    }

    private var sticky: String? {
        guard spectrum.hasReading else { return nil }
        return "\(Format.dbfs(spectrum.rmsDBFS)) · \(peakLabel)"
    }

    private var copyText: String? {
        guard spectrum.hasReading else { return nil }
        return "\(Format.dbfs(spectrum.rmsDBFS)), peak band \(peakLabel). Level, spectrum, and time activity. Not SPL. Not a leak position."
    }

    private var imagerFootnote: String {
        let rate = spectrum.sampleRateHz
        let nyquist = CoupledVibrationMath.nyquistHz(sampleRateHz: rate)
        let fs = rate > 0 ? "fs \(Format.number(rate, digits: 0)) Hz" : "fs —"
        let nq = nyquist.map { "Nyquist \(Format.number($0, digits: 0)) Hz" } ?? "Nyquist —"
        return "\(fs) · \(nq) · \(spectrum.windowKind.title) window · display floor \(Format.number(AcousticSpectrum.displayFloorDBFS, digits: 0)) dBFS. Not SPL. Dashed line is the median band in this window."
    }

    private static func hertz(_ hz: Double) -> String {
        guard hz.isFinite else { return "" }
        if hz >= 1000 { return "\(Format.number(hz / 1000, digits: hz >= 10_000 ? 0 : 1)) kHz" }
        return "\(Format.number(hz, digits: 0)) Hz"
    }

    private var peakLabel: String {
        guard let hz = spectrum.peakHz, hz.isFinite else { return "—" }
        return "\(Format.number(hz, digits: 0)) Hz"
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .acousticImager,
            notes: notes,
            inputs: ["formula": "on-device FFT bands, audible ceiling 8 kHz"],
            outputs: [
                "dBFS": Format.dbfs(spectrum.rmsDBFS),
                "peakHz": peakLabel,
                "spl": "not claimed",
                "leakPosition": "not claimed",
            ]
        ))
    }
}

private struct AcousticLevelMap: View {
    var history: [[Double]]
    var lowLabel: String
    var highLabel: String

    var body: some View {
        LabeledPlotChrome(
            xAxis: PlotAxis(title: "Frequency", unit: "Hz", start: lowLabel, end: highLabel),
            yAxis: PlotAxis(title: "Time", unit: "", start: "newer", end: "older"),
            accessibilityLabel: "Time activity of recent audible bands. Frequency from \(lowLabel) to \(highLabel). Color is relative dBFS.",
            inspection: .inspect,
            plotHeight: 140,
            fullscreenTitle: "Time activity",
            readout: describe
        ) {
            mapCanvas
        }
    }

    private func describe(x: CGFloat, y: CGFloat) -> String {
        guard !history.isEmpty, let widest = history.max(by: { $0.count < $1.count }), !widest.isEmpty else {
            return "No time activity yet"
        }
        let column = min(widest.count - 1, max(0, Int(x * CGFloat(widest.count))))
        let rowFromTop = min(history.count - 1, max(0, Int((1 - y) * CGFloat(history.count))))
        let row = history[rowFromTop]
        guard !row.isEmpty else { return "Empty row" }
        let db = row[min(column, row.count - 1)]
        let level = db.isFinite ? Format.number(db, digits: 0) : "—"
        return "\(lowLabel) toward \(highLabel), \(level) dBFS"
    }

    private var mapCanvas: some View {
        Canvas { context, size in
            let rows = history
            guard !rows.isEmpty else {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.surfaceRaised))
                return
            }
            let rowH = size.height / CGFloat(rows.count)
            for (rowIndex, row) in rows.enumerated() {
                let cols = row.count
                guard cols > 0 else { continue }
                let colW = size.width / CGFloat(cols)
                for (colIndex, db) in row.enumerated() {
                    let heat = AcousticSpectrum.heat(dbFS: db)
                    let rect = CGRect(
                        x: CGFloat(colIndex) * colW,
                        y: CGFloat(rowIndex) * rowH,
                        width: colW + 0.5,
                        height: rowH + 0.5
                    )
                    context.fill(Path(rect), with: .color(cellColor(heat)))
                }
            }
        }
    }

    private func cellColor(_ heat: Double) -> Color {
        if heat < 0.08 { return Theme.surfaceRaised }
        if heat > 0.72 { return Theme.bad.opacity(0.55 + heat * 0.4) }
        if heat > 0.4 { return Theme.warn.opacity(0.45 + heat * 0.4) }
        return Theme.accent.opacity(0.25 + heat * 0.7)
    }
}
