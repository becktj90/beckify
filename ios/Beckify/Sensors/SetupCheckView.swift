import SwiftUI
import BeckifyMath

/// Field → Instruments. Room & Rig Check on the shared microphone FFT.
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
    @StoredInput(.setupCheck, "jobName", default: "Room and rig") private var jobName
    @State private var notes = ""
    @State private var testRunning = false
    @State private var testStarted: Date?
    @State private var testRunID = UUID()
    @State private var capture = RoomRigTestCapture()
    @State private var testResult: RoomRigTestSnapshot?
    @State private var spotA: RoomRigTestSnapshot?
    @State private var spotAMetadata: RoomRigPassMetadata?
    @State private var passMetadata: RoomRigPassMetadata?
    @State private var captureProtocol: RoomRigCaptureProtocol?
    @State private var quietBaseline: RoomRigQuietBaseline?
    @State private var baselineCapturing = false
    @State private var baselineLevels: [Double] = []
    @State private var baselineBandRows: [[Double]] = []
    @State private var baselineStartedSample: UInt64 = 0
    @State private var lastHandledFrameID: UInt64 = 0
    @State private var cancelNotice: String?
    @State private var abBlockedReason: String?

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
                meaning: "The DSP worker draws the live spectrum, RTA bands, and a short spectrogram from timestamped frames. Pink noise, a log sweep, or a tone burst can play from this phone’s speaker as a labeled demo so you can A/B a seat or a rig. Capture an explicit quiet-room baseline first. The curve is a shape on this phone, not a calibrated frequency response."
            )
            Text(RoomRigMath.honestLimit)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Leave this open while you listen. The meters and spectrum stay live. Start test when you want numbers for an A/B.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            if spectrum.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "Room & Rig Check needs the microphone for a relative spectrum. Test signals stay on this phone. Nothing is recorded or uploaded.",
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
            baselineControls
            if let cancelNotice {
                Text(cancelNotice)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.bad)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let abBlockedReason {
                Text(abBlockedReason)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            testControls
            if let testResult {
                testResultCard(testResult)
            }

            ResultCard(title: "Listening", copyText: copyText) {
                ResultRow(label: "Level", value: Format.dbfs(spectrum.rmsDBFS), emphasis: true, tone: Theme.good)
                ResultRow(label: "Peak hold", value: Format.dbfs(peakHold), tone: Theme.warn)
                ResultRow(label: "Crest", value: crestLabel, tone: Theme.copper)
                ResultRow(label: "Signal above background", value: aboveLabel)
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
                Text("Crest is peaks above the typical level. Harmonics are leftover mic energy, not THD. Loop delay shows up on bursts as a rough speaker-to-mic gap. Signal above background uses the quiet-room baseline you capture — not SNR. Relative range waits for that baseline.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
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
                Text("Which frequencies are louder right now. Left to right is frequency. Up is louder, in relative dBFS — not dB SPL.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SpectrumPlot(bands: shownBands, footnote: spectrumFootnote, showsRelativeDBFSScale: true)
                    .padding(.top, 8)
            }

            instructions
            viewGuide

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
                    accessibilityLabel: "Third-octave relative spectrum. Frequency across, relative dBFS up.",
                    footnote: "Nominal centers 50 Hz–8 kHz, limited by this phone’s sample rate. Not IEC 61260.",
                    showsRelativeDBFSScale: true
                )
                .padding(.top, 8)
            }

            DiagramCard(
                title: "Spectrogram",
                accessibilitySummary: spectrogramSummary,
                exportName: "beckify-setup-spectrogram"
            ) {
                Text("Recent audible bands. Left is lower frequency, top is older, bottom is newer. Color is relative dBFS, not a recording.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SetupSpectrogram(
                    rows: shownSpectrogram,
                    lowLabel: spectrogramLow,
                    highLabel: spectrogramHigh
                )
                    .padding(.top, 8)
            }

            DiagramCard(
                title: "Level",
                accessibilitySummary: levelSummary,
                exportName: "beckify-setup-level"
            ) {
                Text("Relative dBFS over the last moments. The vertical scale follows this trace. Not a recording and not dB SPL.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                TraceSparkline(
                    samples: shownTrace,
                    accessibilityLabel: "Level versus time, relative dBFS. Older on the left, now on the right.",
                    showsDBFSTimeAxes: true
                )
                    .padding(.top, 6)
            }

            DiagramCard(
                title: "Sweep shape",
                accessibilitySummary: responseSummary,
                exportName: "beckify-setup-sweep"
            ) {
                Text("Unsmoothed 1/3-octave buckets from the log sweep, plus a 1/3-octave smooth. Vertical axis is dB versus this pass’s peak. 0 dB is the loudest bucket — a shape, not a calibration.")
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
            if testRunning { cancelTest(.leftScreen) }
            if baselineCapturing { cancelBaseline() }
            spectrum.endStimulus()
            spectrum.release(micToken)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                retainMic()
            case .background:
                if testRunning { cancelTest(.backgrounded) }
                if baselineCapturing { cancelBaseline() }
                stimulus = .listen
                spectrum.endStimulus()
                spectrum.release(micToken)
            default:
                break
            }
        }
        .onChange(of: stimulus) { _, kind in
            if kind == .sweep { response = [] }
            if testRunning { cancelTest(.userStop) }
            spectrum.setStimulus(kind)
        }
        .onChange(of: spectrum.frameID) { _, id in
            handleWorkerFrame(id)
        }
        .onChange(of: spectrum.routeEpoch) { _, _ in
            invalidateBaselineForRoute()
            if testRunning { cancelTest(.routeOrGainChanged) }
            if baselineCapturing { cancelBaseline(route: true) }
        }
        .task(id: testRunID) {
            guard testRunning, let testStarted else { return }
            let remain = RoomRigTestMath.windowSeconds - Date().timeIntervalSince(testStarted)
            if remain > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remain * 1_000_000_000))
            }
            guard !Task.isCancelled, testRunning else { return }
            finishTest()
        }
        .task(id: baselineCapturing) {
            guard baselineCapturing else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled, baselineCapturing else { return }
            finishBaseline()
        }
    }

    private var shownBands: [AcousticDisplayBand] {
        if let frozenBands { return frozenBands }
        if spectrum.bassBands.isEmpty { return spectrum.bands }
        return mergeBass(live: spectrum.bands, bass: spectrum.bassBands)
    }
    private var shownRTA: [AcousticDisplayBand] { frozenRTA ?? spectrum.rtaBands }
    private var shownSpectrogram: [[Double]] { frozenSpectrogram ?? spectrogram }

    private var spectrogramLow: String {
        guard let hz = shownBands.first?.lowHz, hz.isFinite else { return "low" }
        return "\(Format.number(hz, digits: 0)) Hz"
    }

    private var spectrogramHigh: String {
        guard let hz = shownBands.last?.highHz, hz.isFinite else { return "high" }
        if hz >= 1000 { return "\(Format.number(hz / 1000, digits: 1)) kHz" }
        return "\(Format.number(hz, digits: 0)) Hz"
    }
    private var shownTrace: [Double] { frozenTrace ?? levelTrace }
    private var shownResponse: [RoomRigPoint] { frozenResponse ?? response }
    private var shownShape: [RoomRigPoint] { RoomRigMath.normalizeToPeak(shownResponse) }
    private var smoothedShape: [RoomRigPoint] { RoomRigMath.smoothOneThirdOctave(shownShape) }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How to A/B a room or a rig")
                .font(Theme.TypeRole.fieldLabel)
                .foregroundStyle(Theme.foreground)
            Text("1. Capture a quiet-room baseline. Leave the screen open. Play music, or pick a labeled phone-speaker demo (Pink, Sweep, Burst). The plots stay live.")
            Text("2. Tap Start test. It listens for about \(Format.number(RoomRigTestMath.windowSeconds, digits: 0)) seconds, or until you tap Stop. Each number underneath says what it means.")
            Text("3. Keep that pass as spot A. Move the phone or change the rig, run the test again, and read this pass minus A.")
            Text("4. Pink noise fills the band so two spots are easier to compare. Sweep draws a shape — 0 dB is that pass’s peak, not a calibration. Burst is a rough speaker-to-mic delay.")
        }
        .font(Theme.TypeRole.help)
        .foregroundStyle(Theme.muted)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var viewGuide: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What each view means")
                .font(Theme.TypeRole.fieldLabel)
                .foregroundStyle(Theme.foreground)
            Text("Live FFT — frequencies that are up right now. Horizontal axis is frequency. Vertical axis is relative dBFS.")
            Text("RTA — that energy in approximate third-octave buckets. Same relative scale. Not an IEC class filter.")
            Text("Spectrogram — those bands over the last moments. Left is lower frequency, top is older, bottom is newer. Color is relative dBFS.")
            Text("Level — relative dBFS versus time. Left is older, right is now.")
            Text("Sweep shape — fills in only while Sweep plays. Copper is raw, teal is a third-octave smooth.")
            Text("Keep the phone in the same place for each side of the A/B. This speaker and mic are not a calibrated measurement microphone.")
        }
        .font(Theme.TypeRole.help)
        .foregroundStyle(Theme.muted)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var signalCaption: String {
        switch stimulus {
        case .listen:
            return "Listening only. Capture a quiet-room baseline explicitly for signal-above-background (not SNR). Phone-speaker signals are demos when you turn them on."
        case .pink:
            return "Pink noise demo from this phone’s speaker. Use it to compare seats or rigs. Not a reference generator."
        case .sweep:
            return "Log sweep demo, \(Format.number(RoomRigMath.sweepStartHz, digits: 0))–\(Format.number(RoomRigMath.sweepEndHz, digits: 0)) Hz. The shape fills in over about \(Format.number(RoomRigMath.sweepDuration, digits: 0)) seconds. 0 dB is this pass’s peak."
        case .burst:
            return "1 kHz tone-burst demo. Loop delay is a rough speaker-to-mic gap when the burst rises out of the room."
        }
    }

    private var crestLabel: String {
        guard let crest = spectrum.crestDB, crest.isFinite else { return "—" }
        return "\(Format.number(crest, digits: 1)) dB"
    }

    private var aboveLabel: String {
        guard let above = RoomRigBaselineMath.signalAboveBackgroundDB(
            levelDBFS: spectrum.rmsDBFS,
            baseline: quietBaseline
        ) else {
            return "Capture quiet baseline"
        }
        return String(format: "%+.1f dB", above)
    }

    private var rangeLabel: String {
        guard let floor = quietBaseline?.floorDBFS,
              let range = RoomRigMath.relativeDynamicRangeDB(peakDBFS: peakHold, floorDBFS: floor)
        else {
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

    private var testControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(testRunning ? "Stop test" : "Start test") {
                if testRunning {
                    finishTest()
                } else {
                    startTest()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(testRunning ? Theme.warn : Theme.accent)
            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            .accessibilityHint(testRunning
                ? "Ends the capture and shows the explained numbers."
                : "Listens for about 8 seconds. The live plots stay up.")
            if testRunning, let testStarted {
                TimelineView(.periodic(from: testStarted, by: 0.25)) { context in
                    let elapsed = min(RoomRigTestMath.windowSeconds, max(0, context.date.timeIntervalSince(testStarted)))
                    Text("Capturing \(Format.number(elapsed, digits: 0)) s of \(Format.number(RoomRigTestMath.windowSeconds, digits: 0)) s. Plots stay live.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Text("Pink noise, a sweep, bursts, or whatever is already playing. The numbers are relative on this phone.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func testResultCard(_ snap: RoomRigTestSnapshot) -> some View {
        ResultCard(title: "Test · \(snap.stimulus)", copyText: testCopy(snap)) {
            Text("\(Format.number(snap.durationSeconds, digits: 0)) s on this phone. Relative A/B only — not SPL, not a lab RTA.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            explained("Level", Format.dbfs(snap.levelDBFS), RoomRigTestCopy.level, emphasis: true)
            explained("Peak", Format.dbfs(snap.peakDBFS), RoomRigTestCopy.peak)
            explained("Crest", snap.crestDB.map { "\(Format.number($0, digits: 1)) dB" } ?? "—", RoomRigTestCopy.crest)
            explained(
                "Clipping",
                "\(Format.number(snap.clipFraction * 100, digits: 1))%",
                RoomRigTestCopy.clip,
                tone: snap.clipFraction >= 0.01 ? Theme.bad : Theme.foreground
            )
            explained(
                "Signal above background",
                snap.aboveFloorDB.map { String(format: "%+.1f dB", $0) } ?? "Capture quiet baseline",
                RoomRigTestCopy.signalAboveBackground
            )
            explained("Peak freq", snap.peakHz.map { "\(Format.number($0, digits: 0)) Hz" } ?? "—", RoomRigTestCopy.peakHz)
            explained("Centroid", snap.centroidHz.map { "\(Format.number($0, digits: 0)) Hz" } ?? "—", RoomRigTestCopy.centroid)
            if let balance = snap.balance {
                explained(
                    "Bands vs loudest",
                    "L \(Format.number(balance.lowVsLoudestDB, digits: 0)) · M \(Format.number(balance.midVsLoudestDB, digits: 0)) · H \(Format.number(balance.highVsLoudestDB, digits: 0)) dB",
                    RoomRigTestCopy.balance
                )
            } else {
                explained("Bands vs loudest", "—", RoomRigTestCopy.balance)
            }
            if let spotA, spotA != snap {
                if let meta = passMetadata, let aMeta = spotAMetadata, RoomRigABMath.canCompare(a: aMeta, b: meta) {
                    Text(RoomRigTestCopy.versusA)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    ResultRow(
                        label: "Level vs A",
                        value: String(format: "%+.1f dB", snap.levelDBFS - spotA.levelDBFS),
                        emphasis: true,
                        tone: Theme.copper
                    )
                    if let crest = snap.crestDB, let crestA = spotA.crestDB {
                        ResultRow(label: "Crest vs A", value: String(format: "%+.1f dB", crest - crestA))
                    }
                    if let here = snap.centroidHz, let there = spotA.centroidHz {
                        ResultRow(label: "Centroid vs A", value: String(format: "%+.0f Hz", here - there))
                    }
                } else {
                    Text(abBlockedReason ?? "A/B needs matching stimulus, route, gain, and FFT settings.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            Button(spotA == nil ? "Keep as spot A" : "Replace spot A") {
                spotA = snap
                spotAMetadata = passMetadata
                abBlockedReason = nil
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)
        }
    }

    private func explained(
        _ label: String,
        _ value: String,
        _ explanation: String,
        emphasis: Bool = false,
        tone: Color = Theme.foreground
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ResultRow(label: label, value: value, emphasis: emphasis, tone: tone)
            Text(explanation)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func testCopy(_ snap: RoomRigTestSnapshot) -> String {
        "\(snap.stimulus) \(Format.number(snap.durationSeconds, digits: 0)) s, \(Format.dbfs(snap.levelDBFS)), crest \(snap.crestDB.map { Format.number($0, digits: 1) } ?? "—") dB. Relative phone mic. Not SPL."
    }

    private var baselineControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(baselineCapturing ? "Capturing quiet…" : (quietBaseline == nil ? "Capture quiet-room baseline" : "Recapture quiet baseline")) {
                if baselineCapturing {
                    cancelBaseline()
                } else {
                    startBaseline()
                }
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            .disabled(testRunning || stimulus != .listen)
            Text(RoomRigTestCopy.baselineHelp)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let quietBaseline {
                Text("Baseline \(Format.dbfs(quietBaseline.floorDBFS)) · signal above background, not SNR.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.good)
            }
            if spectrum.bassFFTLength > 0 {
                Text("Bass analysis window \(spectrum.bassFFTLength) samples (overlapping). Live plots stay on \(RoomRigMath.liveFFTLength).")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func handleWorkerFrame(_ id: UInt64) {
        guard id != lastHandledFrameID, let frame = spectrum.latestFrame, frame.frameID == id else { return }
        lastHandledFrameID = id
        let db = frame.rmsDBFS
        guard db.isFinite else { return }

        if baselineCapturing, stimulus == .listen {
            baselineLevels.append(db)
            let row = frame.bands.filter(\.isAvailable).map(\.dbFS)
            if !row.isEmpty {
                baselineBandRows.append(row)
            }
        }

        if testRunning, var proto = captureProtocol {
            if let reason = proto.append(frame) {
                captureProtocol = proto
                cancelTest(reason)
                return
            }
            captureProtocol = proto
            capture = proto.capture
        }

        guard !frozen else { return }
        if db > peakHold { peakHold = db }
        levelTrace = MagSweepMath.appendTrace(levelTrace, sample: db, limit: 120)
        let plotBands = spectrum.bassBands.isEmpty ? frame.bands : mergeBass(live: frame.bands, bass: spectrum.bassBands)
        if !plotBands.isEmpty {
            spectrogram = RoomRigMath.appendSpectrogram(
                spectrogram,
                row: plotBands.map { $0.isAvailable ? $0.dbFS : AcousticSpectrum.displayFloorDBFS },
                limit: 48
            )
        }
        if spectrum.stimulus == .sweep, let hz = spectrum.stimulusHz, hz > 0 {
            let source = frame.rtaBands.filter(\.isAvailable)
            if let band = source.min(by: {
                abs(log(max($0.centerHz, 1)) - log(hz)) < abs(log(max($1.centerHz, 1)) - log(hz))
            }) {
                response = RoomRigMath.updateResponse(response, hz: hz, db: band.dbFS)
            }
        }
    }

    private func mergeBass(live: [AcousticDisplayBand], bass: [AcousticDisplayBand]) -> [AcousticDisplayBand] {
        // Prefer longer-FFT availability below ~200 Hz; keep live above.
        live.map { band in
            guard band.centerHz < 200 else { return band }
            if let better = bass.first(where: { abs(log(max($0.centerHz, 1)) - log(max(band.centerHz, 1))) < 0.15 }),
               better.isAvailable {
                return better
            }
            return band
        }
    }

    private func startBaseline() {
        guard stimulus == .listen, !testRunning else { return }
        cancelNotice = nil
        baselineLevels = []
        baselineBandRows = []
        baselineStartedSample = spectrum.totalSampleCount
        baselineCapturing = true
    }

    private func finishBaseline() {
        guard baselineCapturing else { return }
        baselineCapturing = false
        guard let fingerprint = spectrum.routeFingerprint else {
            cancelNotice = "Baseline cancelled — no route fingerprint yet."
            return
        }
        quietBaseline = RoomRigBaselineMath.baseline(
            levels: baselineLevels,
            bandRows: baselineBandRows,
            fingerprint: fingerprint,
            sampleCount: spectrum.totalSampleCount &- baselineStartedSample,
            capturedAt: Date().timeIntervalSinceReferenceDate
        )
        noiseFloor = quietBaseline?.floorDBFS
        if quietBaseline == nil {
            cancelNotice = "Baseline incomplete — stay quiet and try again."
        } else {
            cancelNotice = nil
        }
    }

    private func cancelBaseline(route: Bool = false) {
        baselineCapturing = false
        baselineLevels = []
        baselineBandRows = []
        if route {
            quietBaseline = nil
            noiseFloor = nil
            cancelNotice = "Quiet baseline invalidated — audio route or gain changed."
        }
    }

    private func invalidateBaselineForRoute() {
        guard let baseline = quietBaseline, let fingerprint = spectrum.routeFingerprint else { return }
        if !baseline.isValid(for: fingerprint) {
            quietBaseline = nil
            noiseFloor = nil
            cancelNotice = "Quiet baseline invalidated — audio route or gain changed."
        }
    }

    private func makePassMetadata() -> RoomRigPassMetadata? {
        guard let fingerprint = spectrum.routeFingerprint else { return nil }
        return RoomRigPassMetadata(
            stimulus: stimulus,
            fingerprint: fingerprint,
            liveFFTLength: RoomRigMath.liveFFTLength,
            bassFFTLength: spectrum.bassFFTLength > 0 ? spectrum.bassFFTLength : nil,
            windowKind: spectrum.windowKind.title,
            isPhoneSpeakerDemo: stimulus != .listen
        )
    }

    private func startTest() {
        cancelNotice = nil
        abBlockedReason = nil
        guard let metadata = makePassMetadata() else {
            cancelNotice = "Cannot lock protocol — wait for the mic route."
            return
        }
        if let spotAMetadata, !RoomRigABMath.canCompare(a: spotAMetadata, b: metadata) {
            abBlockedReason = "Spot A used different stimulus/route/FFT. Keep A only for matching passes, or replace A."
        }
        let proto = RoomRigCaptureProtocol(
            metadata: metadata,
            startedSampleCount: spectrum.totalSampleCount,
            startedHostTime: Date().timeIntervalSinceReferenceDate
        )
        captureProtocol = proto
        passMetadata = metadata
        capture = RoomRigTestCapture()
        testStarted = Date()
        testRunning = true
        testRunID = UUID()
    }

    private func finishTest() {
        guard testRunning else { return }
        let started = testStarted ?? Date()
        let duration = min(RoomRigTestMath.windowSeconds, max(0, Date().timeIntervalSince(started)))
        let floor = quietBaseline?.floorDBFS
        let snap = captureProtocol?.finish(durationSeconds: duration, floorDBFS: floor)
            ?? capture.snapshot(
                stimulus: stimulus == .listen ? stimulus.title : "\(stimulus.title) · demo",
                durationSeconds: duration,
                floorDBFS: floor
            )
        testRunning = false
        testStarted = nil
        if let snap {
            testResult = snap
            cancelNotice = nil
        } else {
            cancelNotice = "Capture incomplete — no snapshot."
        }
    }

    private func cancelTest(_ reason: RoomRigCaptureCancelReason) {
        guard testRunning else { return }
        if var proto = captureProtocol {
            proto.cancel(reason)
            captureProtocol = proto
        }
        testRunning = false
        testStarted = nil
        let message: String
        switch reason {
        case .userStop: message = "Capture cancelled."
        case .incompleteWindow: message = "Capture cancelled — incomplete window."
        case .routeOrGainChanged: message = "Capture cancelled — route or gain changed."
        case .clipping: message = "Capture cancelled — clipping."
        case .lowHeadroom: message = "Capture cancelled — low headroom."
        case .leftScreen: message = "Capture cancelled — left screen."
        case .backgrounded: message = "Capture cancelled — backgrounded."
        }
        cancelNotice = message
        testResult = nil
    }

    private func retainMic() {
        spectrum.retain(micToken, role: "Room & Rig Check")
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
                "testLevel": testResult.map { Format.dbfs($0.levelDBFS) } ?? "—",
                "testCentroidHz": testResult?.centroidHz.map { Format.number($0, digits: 0) } ?? "—",
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
    var lowLabel: String
    var highLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledPlotChrome(
                xAxis: PlotAxis(title: "Frequency", unit: "Hz", start: lowLabel, end: highLabel),
                yAxis: PlotAxis(title: "Time", unit: "", start: "newer", end: "older"),
                accessibilityLabel: "Spectrogram. Frequency from \(lowLabel) to \(highLabel), older time at the top, color is relative dBFS.",
                inspection: .inspect,
                plotHeight: 180,
                fullscreenTitle: "Spectrogram",
                readout: describe
            ) {
                spectrogramCanvas
            }
            Text("Color: relative dBFS (\(Format.number(AcousticSpectrum.displayFloorDBFS, digits: 0)) dark → \(Format.number(AcousticSpectrum.displayCeilingDBFS, digits: 0)) bright). Not SPL.")
                .font(Theme.TypeRole.hud)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func describe(x: CGFloat, y: CGFloat) -> String {
        guard !rows.isEmpty, let widest = rows.max(by: { $0.count < $1.count }), !widest.isEmpty else {
            return "No spectrogram yet"
        }
        let column = min(widest.count - 1, max(0, Int(x * CGFloat(widest.count))))
        let rowFromTop = min(rows.count - 1, max(0, Int((1 - y) * CGFloat(rows.count))))
        let row = rows[rowFromTop]
        guard !row.isEmpty else { return "Empty row" }
        let sample = row[min(column, row.count - 1)]
        let db = sample.isFinite ? Format.number(sample, digits: 0) : "—"
        return "\(lowLabel) toward \(highLabel), \(db) dBFS"
    }

    private var spectrogramCanvas: some View {
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
            LabeledPlotChrome(
                xAxis: PlotAxis(
                    title: "Frequency",
                    unit: "Hz",
                    start: "\(Format.number(RoomRigMath.sweepStartHz, digits: 0)) Hz",
                    end: "\(Format.number(RoomRigMath.sweepEndHz / 1000, digits: 0)) kHz"
                ),
                yAxis: PlotAxis(title: "Level", unit: "dB vs peak", start: "−36", mid: "0", end: "+6"),
                accessibilityLabel: raw.count >= 2
                    ? "Relative sweep shape, \(raw.count) bands. Frequency in hertz, level in dB versus this pass’s peak."
                    : "Sweep shape empty",
                inspection: .inspect,
                plotHeight: 200,
                fullscreenTitle: "Sweep shape",
                readout: describe
            ) {
                responseCanvas
            }
            Text("Copper is raw. Teal is the third-octave smooth. 0 dB is this pass’s peak, not SPL.")
                .font(Theme.TypeRole.hud)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func describe(x: CGFloat, _: CGFloat) -> String {
        let minHz = log(RoomRigMath.sweepStartHz)
        let maxHz = log(RoomRigMath.sweepEndHz)
        let hz = exp(minHz + (maxHz - minHz) * Double(min(1, max(0, x))))
        guard raw.count >= 2 else { return "Play Sweep. \(Format.number(hz, digits: 0)) Hz" }
        let nearest = raw.min { lhs, rhs in
            abs(log(max(lhs.hz, 1)) - log(hz)) < abs(log(max(rhs.hz, 1)) - log(hz))
        }
        let db = nearest?.db
        let level = db.map { Format.number($0, digits: 1) } ?? "—"
        return "\(Format.number(hz, digits: 0)) Hz, \(level) dB vs peak"
    }

    private var responseCanvas: some View {
        Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                    guard raw.count >= 2 else {
                        let label = Text("Play Sweep").foregroundStyle(Theme.muted)
                        context.draw(context.resolve(label), at: CGPoint(x: size.width / 2, y: size.height / 2))
                        return
                    }
                    zeroLine(in: context, size: size)
                    stroke(raw, color: Theme.copper.opacity(0.85), width: 1.25, in: context, size: size)
                    if smooth.count >= 2 {
                        stroke(smooth, color: Theme.accent, width: 2.25, in: context, size: size)
                    }
        }
    }

    private func zeroLine(in context: GraphicsContext, size: CGSize) {
        let floor = -36.0
        let ceiling = 6.0
        let yNorm = (0 - floor) / (ceiling - floor)
        let y = size.height * (1 - CGFloat(yNorm))
        var line = Path()
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(line, with: .color(Theme.muted.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
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
