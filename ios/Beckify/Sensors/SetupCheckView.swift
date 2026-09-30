import SwiftUI
import BeckifyMath

/// Field → Instruments. One room-and-rig screen on the shared microphone FFT.
/// Optional test signals play from the phone speaker on that same engine.
struct SetupCheckView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var spectrum = MicrophoneSpectrumCenter.shared
    @State private var micToken = UUID()
    @State private var stimulus: RoomRigStimulusKind = .listen
    @State private var peakHold = SoundLevel.silenceFloorDBFS
    @State private var levelTrace: [Double] = []
    @State private var quietTrace: [Double] = []
    @State private var noiseFloor: Double?
    @State private var spectrogram: [[Double]] = []
    @State private var response: [RoomRigPoint] = []
    @State private var frozen = false
    @State private var frozenBands: [AcousticDisplayBand]?
    @State private var frozenRTA: [AcousticDisplayBand]?
    @State private var frozenSpectrogram: [[Double]]?
    @State private var frozenTrace: [Double]?
    @State private var frozenResponse: [RoomRigPoint]?
    @StoredInput(.setupCheck, "jobName", default: "Setup check") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .setupCheck,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: RoomRigMath.honestLimit + " Audio is processed on this device, is not recorded, and is not uploaded. Noise Meter and Acoustic Imager share this tap.")
        ) {
            ShowWorkCard(
                toolID: .setupCheck,
                symbolic: "relative dBFS    crest = 20·log₁₀(peak / RMS)    sweep shape, not SPL",
                substituted: sticky,
                meaning: "The shared microphone FFT draws the live spectrum, RTA bands, and a short spectrogram. Pink noise, a log sweep, or a tone burst can play from this phone’s speaker so you can A/B a seat or a rig. The curve is a shape on this phone, not a calibrated frequency response."
            )
            Text(RoomRigMath.honestLimit)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if spectrum.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "Setup Check needs the microphone for a relative spectrum. Test signals stay on this phone. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            }
            Picker("Test signal", selection: $stimulus) {
                ForEach(RoomRigStimulusKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Test signal")
            Text(signalCaption)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ResultCard(title: "Reading", copyText: copyText) {
                ResultRow(label: "Level", value: Format.dbfs(spectrum.rmsDBFS), emphasis: true, tone: Theme.good)
                ResultRow(label: "Peak hold", value: Format.dbfs(peakHold), tone: Theme.warn)
                ResultRow(label: "Crest", value: crestLabel, tone: Theme.copper)
                ResultRow(label: "Above quiet", value: aboveLabel)
                ResultRow(label: "Relative range", value: rangeLabel)
                ResultRow(label: "Clip", value: clipLabel, tone: spectrum.clipFraction >= 0.01 ? Theme.bad : Theme.foreground)
                ResultRow(label: "Harmonics", value: harmonicLabel)
                ResultRow(label: "Loop delay", value: latencyLabel)
                ResultRow(label: "Mic path", value: pathLabel)
                ResultRow(label: "Engine", value: spectrum.status)
                if let balance = spectrum.channelBalance {
                    Text("Right minus left, from two input channels. Not a soundstage measurement.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 6)
                    BalanceBar(balance: balance)
                        .padding(.top, 4)
                } else {
                    Text("One microphone path on this phone. Stereo balance stays blank until a second channel shows up.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 6)
                }
            }

            DiagramCard(
                title: frozen ? "FFT frozen" : "Live FFT",
                accessibilitySummary: fftSummary,
                exportName: "beckify-setup-fft"
            ) {
                Picker("Window", selection: $spectrum.windowKind) {
                    ForEach(SpectrumWindowKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                SpectrumPlot(bands: shownBands, footnote: spectrumFootnote)
                    .padding(.top, 8)
            }

            DiagramCard(
                title: "RTA bands",
                accessibilitySummary: rtaSummary,
                exportName: "beckify-setup-rta"
            ) {
                Text("Approximate 1/3-octave energy. Not an IEC 61260 class filter bank, and not dB SPL.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                SpectrumPlot(
                    bands: shownRTA,
                    plotHeight: 128,
                    accessibilityLabel: "Third-octave relative spectrum",
                    footnote: "Nominal centers 50 Hz–8 kHz, limited by this phone’s sample rate."
                )
                .padding(.top, 8)
            }

            DiagramCard(
                title: "Spectrogram",
                accessibilitySummary: spectrogramSummary,
                exportName: "beckify-setup-spectrogram"
            ) {
                Text("Recent audible bands. Newer rows sit at the bottom. Relative energy only.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                SetupSpectrogram(rows: shownSpectrogram)
                    .padding(.top, 8)
            }

            DiagramCard(
                title: "Level",
                accessibilitySummary: levelSummary,
                exportName: "beckify-setup-level"
            ) {
                Text("Level over the last moments. Not a recording.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                TraceSparkline(samples: shownTrace, accessibilityLabel: "Level versus time")
                    .padding(.top, 6)
            }

            DiagramCard(
                title: "Sweep shape",
                accessibilitySummary: responseSummary,
                exportName: "beckify-setup-sweep"
            ) {
                Text("Unsmoothed 1/3-octave buckets from the log sweep, plus a 1/3-octave smooth. 0 dB is the loudest bucket on this pass — a shape, not a calibration.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SetupResponsePlot(raw: shownShape, smooth: smoothedShape)
                    .padding(.top, 8)
            }

            HStack(spacing: 12) {
                Button(frozen ? "Live" : "Freeze") { toggleFreeze() }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                Button("Reset peak") {
                    peakHold = spectrum.rmsDBFS
                    noiseFloor = nil
                    quietTrace = []
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
            .frame(minHeight: Theme.touchTarget)
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: spectrum.hasReading) { save() }
        }
        .preferredColorScheme(.dark)
        .onAppear { retainMic() }
        .onDisappear {
            spectrum.endStimulus()
            spectrum.release(micToken)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                retainMic()
            case .background:
                stimulus = .listen
                spectrum.endStimulus()
                spectrum.release(micToken)
            default:
                break
            }
        }
        .onChange(of: stimulus) { _, kind in
            if kind == .sweep { response = [] }
            spectrum.setStimulus(kind)
        }
        .onChange(of: spectrum.rmsDBFS) { _, db in
            guard !frozen, spectrum.hasReading, db.isFinite else { return }
            if db > peakHold { peakHold = db }
            levelTrace = MagSweepMath.appendTrace(levelTrace, sample: db, limit: 120)
            guard stimulus == .listen else { return }
            quietTrace = MagSweepMath.appendTrace(quietTrace, sample: db, limit: 40)
            noiseFloor = RoomRigMath.percentile(quietTrace, p: 0.2)
        }
        .onChange(of: spectrum.bands) { _, bands in
            guard !frozen, !bands.isEmpty else { return }
            spectrogram = RoomRigMath.appendSpectrogram(spectrogram, row: bands.map(\.dbFS), limit: 48)
        }
        .onChange(of: spectrum.stimulusHz) { _, hz in
            guard !frozen, spectrum.stimulus == .sweep, let hz, hz > 0 else { return }
            guard let band = spectrum.rtaBands.min(by: {
                abs(log(max($0.centerHz, 1)) - log(hz)) < abs(log(max($1.centerHz, 1)) - log(hz))
            }) else { return }
            response = RoomRigMath.updateResponse(response, hz: hz, db: band.dbFS)
        }
    }

    private var shownBands: [AcousticDisplayBand] { frozenBands ?? spectrum.bands }
    private var shownRTA: [AcousticDisplayBand] { frozenRTA ?? spectrum.rtaBands }
    private var shownSpectrogram: [[Double]] { frozenSpectrogram ?? spectrogram }
    private var shownTrace: [Double] { frozenTrace ?? levelTrace }
    private var shownResponse: [RoomRigPoint] { frozenResponse ?? response }
    private var shownShape: [RoomRigPoint] { RoomRigMath.normalizeToPeak(shownResponse) }
    private var smoothedShape: [RoomRigPoint] { RoomRigMath.smoothOneThirdOctave(shownShape) }

    private var signalCaption: String {
        switch stimulus {
        case .listen:
            return "Listening only. Play a signal when you want a speaker-to-mic A/B."
        case .pink:
            return "Pink noise from this phone’s speaker. Compare seats or rigs. Not a reference generator."
        case .sweep:
            return "Log sweep, \(Format.number(RoomRigMath.sweepStartHz, digits: 0))–\(Format.number(RoomRigMath.sweepEndHz, digits: 0)) Hz. The shape fills in over about \(Format.number(RoomRigMath.sweepDuration, digits: 0)) seconds."
        case .burst:
            return "1 kHz tone bursts. Loop delay is a rough speaker-to-mic gap when the burst rises out of the room."
        }
    }

    private var crestLabel: String {
        guard let crest = spectrum.crestDB, crest.isFinite else { return "—" }
        return "\(Format.number(crest, digits: 1)) dB"
    }

    private var aboveLabel: String {
        guard let floor = noiseFloor, let above = RoomRigMath.signalAboveFloorDB(levelDBFS: spectrum.rmsDBFS, floorDBFS: floor) else {
            return "Listen quietly first"
        }
        return String(format: "%+.1f dB", above)
    }

    private var rangeLabel: String {
        guard let floor = noiseFloor, let range = RoomRigMath.relativeDynamicRangeDB(peakDBFS: peakHold, floorDBFS: floor) else {
            return "—"
        }
        return "\(Format.number(range, digits: 1)) dB"
    }

    private var clipLabel: String {
        guard spectrum.hasReading else { return "—" }
        if spectrum.clipFraction >= 0.01 {
            return "Clipping \(Format.number(spectrum.clipFraction * 100, digits: 0))%"
        }
        return "No clip"
    }

    private var harmonicLabel: String {
        if let second = spectrum.harmonicOrders.first(where: { $0.order == 2 }), second.relativeEnergy.isFinite {
            return "2nd \(Format.number(second.relativeEnergy * 100, digits: 0))% of f"
        }
        guard let ratio = spectrum.harmonicRatio, ratio.isFinite else { return "—" }
        return "\(Format.number(ratio * 100, digits: 0))% leftover"
    }

    private var latencyLabel: String {
        guard let latency = spectrum.latencySeconds, latency.isFinite else { return "—" }
        return "\(Format.number(latency * 1000, digits: 0)) ms rough"
    }

    private var pathLabel: String {
        let count = spectrum.inputChannelCount
        if count >= 2 { return "\(count) channels" }
        if count == 1 { return "1 mic path" }
        return "—"
    }

    private var spectrumFootnote: String {
        let rate = spectrum.sampleRateHz
        let nyquist = CoupledVibrationMath.nyquistHz(sampleRateHz: rate)
        let fs = rate > 0 ? "fs \(Format.number(rate, digits: 0)) Hz" : "fs —"
        let nq = nyquist.map { "Nyquist \(Format.number($0, digits: 0)) Hz" } ?? "Nyquist —"
        return "\(fs) · \(nq) · \(spectrum.windowKind.title) window. Relative dBFS. Not SPL."
    }

    private var stampText: String {
        SetupCheckView.stamp.string(from: Date())
    }

    private var fftSummary: String {
        "\(stampText). Live FFT. \(spectrumFootnote) \(harmonicLabel). Not SPL. No location."
    }

    private var rtaSummary: String {
        "\(stampText). Approximate third-octave RTA, relative dBFS. Not IEC 61260. Not SPL."
    }

    private var spectrogramSummary: String {
        "\(stampText). Short spectrogram of audible bands. Relative energy. Not a recording."
    }

    private var levelSummary: String {
        "\(stampText). Level versus time, \(Format.dbfs(spectrum.rmsDBFS)). Relative dBFS. Not a recording."
    }

    private var responseSummary: String {
        let tone = spectrum.stimulusHz.map { "Sweep near \(Format.number($0, digits: 0)) Hz." } ?? "No sweep yet."
        return "\(stampText). \(tone) Relative frequency shape, peak normalized to 0 dB. Not a calibrated curve."
    }

    private var sticky: String? {
        guard spectrum.hasReading else { return nil }
        return "\(Format.dbfs(spectrum.rmsDBFS)) · \(crestLabel) crest"
    }

    private var copyText: String? {
        guard spectrum.hasReading else { return nil }
        return "\(Format.dbfs(spectrum.rmsDBFS)), crest \(crestLabel), \(clipLabel), harmonics \(harmonicLabel). Relative phone speaker and mic. Not SPL."
    }

    private func retainMic() {
        spectrum.retain(micToken, role: "Setup Check")
        if stimulus != .listen {
            spectrum.setStimulus(stimulus)
        }
    }

    private func toggleFreeze() {
        if frozen {
            frozen = false
            frozenBands = nil
            frozenRTA = nil
            frozenSpectrogram = nil
            frozenTrace = nil
            frozenResponse = nil
        } else {
            frozenBands = spectrum.bands
            frozenRTA = spectrum.rtaBands
            frozenSpectrogram = spectrogram
            frozenTrace = levelTrace
            frozenResponse = response
            frozen = true
        }
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .setupCheck,
            notes: notes,
            inputs: [
                "signal": stimulus.title,
                "formula": "shared mic FFT, relative dBFS",
            ],
            outputs: [
                "dBFS": Format.dbfs(spectrum.rmsDBFS),
                "crest": crestLabel,
                "clip": clipLabel,
                "harmonics": harmonicLabel,
                "latency": latencyLabel,
                "spl": "not claimed — uncalibrated",
            ]
        ))
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

private struct BalanceBar: View {
    var balance: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = min(1, max(-1, balance))
            let x = geo.size.width * (0.5 + CGFloat(clamped) * 0.5)
            ZStack {
                Capsule().fill(Theme.surfaceRaised)
                Rectangle()
                    .fill(Theme.muted.opacity(0.7))
                    .frame(width: 1, height: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                Circle()
                    .fill(Theme.copper)
                    .frame(width: 12, height: 12)
                    .position(x: x, y: geo.size.height / 2)
            }
        }
        .frame(height: 18)
        .accessibilityLabel("Stereo balance \(Format.number(balance, digits: 2)), right minus left")
    }
}

private struct SetupSpectrogram: View {
    var rows: [[Double]]

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            guard !rows.isEmpty else { return }
            let rowH = size.height / CGFloat(rows.count)
            for (rowIndex, row) in rows.enumerated() {
                guard !row.isEmpty else { continue }
                let colW = size.width / CGFloat(row.count)
                for (colIndex, db) in row.enumerated() {
                    let heat = AcousticSpectrum.heat(dbFS: db)
                    let rect = CGRect(
                        x: CGFloat(colIndex) * colW,
                        y: CGFloat(rowIndex) * rowH,
                        width: colW + 0.5,
                        height: rowH + 0.5
                    )
                    context.fill(Path(rect), with: .color(cell(heat)))
                }
            }
        }
        .frame(height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Spectrogram of recent audible bands")
    }

    private func cell(_ heat: Double) -> Color {
        if heat < 0.06 { return .black }
        if heat > 0.78 { return Theme.bad.opacity(0.55 + heat * 0.45) }
        if heat > 0.45 { return Theme.copper.opacity(0.35 + heat * 0.55) }
        return Theme.accent.opacity(0.20 + heat * 0.75)
    }
}

private struct SetupResponsePlot: View {
    var raw: [RoomRigPoint]
    var smooth: [RoomRigPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                guard raw.count >= 2 else {
                    let label = Text("Play Sweep").foregroundStyle(Theme.muted)
                    context.draw(context.resolve(label), at: CGPoint(x: size.width / 2, y: size.height / 2))
                    return
                }
                stroke(raw, color: Theme.copper.opacity(0.85), width: 1.25, in: context, size: size)
                if smooth.count >= 2 {
                    stroke(smooth, color: Theme.accent, width: 2.25, in: context, size: size)
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            HStack {
                Text("80 Hz")
                Spacer()
                Text("Copper raw · teal smooth")
                Spacer()
                Text("8 kHz")
            }
            .font(Theme.TypeRole.help)
            .foregroundStyle(Theme.muted)
        }
        .accessibilityLabel(raw.count >= 2
            ? "Relative sweep shape, \(raw.count) bands, peak at 0 dB"
            : "Sweep shape empty")
    }

    private func stroke(_ points: [RoomRigPoint], color: Color, width: CGFloat, in context: GraphicsContext, size: CGSize) {
        let usable = points.filter { $0.hz > 0 && $0.db.isFinite }
        guard usable.count >= 2 else { return }
        let minHz = log(RoomRigMath.sweepStartHz)
        let maxHz = log(RoomRigMath.sweepEndHz)
        let span = max(maxHz - minHz, 0.01)
        let floor = -36.0
        let ceiling = 6.0
        var path = Path()
        for (index, point) in usable.enumerated() {
            let x = size.width * CGFloat((log(point.hz) - minHz) / span)
            let yNorm = (min(ceiling, max(floor, point.db)) - floor) / (ceiling - floor)
            let y = size.height * (1 - CGFloat(yNorm))
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}
