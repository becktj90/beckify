import SwiftUI
import BeckifyMath

struct NoiseMeterView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var spectrum = MicrophoneSpectrumCenter.shared
    @State private var micToken = UUID()
    @State private var peak = SoundLevel.silenceFloorDBFS
    @State private var levelTrace: [Double] = []
    @State private var frozenBands: [AcousticDisplayBand]?
    @State private var frozenRatio: Double?
    @State private var frozenRate: Double = 0
    @StoredInput(.noiseMeter, "jobName", default: "Noise snapshot") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .noiseMeter,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Spectrum bars are relative dBFS in the audible band, not calibrated dB SPL. Saving stores the numeric snapshot only — not a recording. Acoustic Imager and Room & Rig Check share this microphone tap.")
        ) {
            ShowWorkCard(
                toolID: .noiseMeter,
                symbolic: "dBFS = 20 × log₁₀(RMS)    band dBFS from an on-device real FFT",
                substituted: sticky,
                meaning: "Relative to full-scale digital. Not dB SPL, not A-weighted, not OSHA, not a calibrated SLM. The bars are the same audible FFT as Acoustic Imager, without the time-activity map."
            )
            if spectrum.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "This meter needs the microphone permission for uncalibrated dBFS and a spectrum. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            }
            ResultCard(title: "Level", copyText: copyText) {
                ResultRow(label: "Now", value: Format.dbfs(spectrum.rmsDBFS), emphasis: true, tone: Theme.good)
                ResultRow(label: "Peak hold", value: Format.dbfs(peak), tone: Theme.warn)
                ResultRow(label: "Peak band", value: peakLabel, tone: Theme.copper)
                ResultRow(label: "Rough harmonics", value: harmonicLabel)
                ResultRow(label: "Engine", value: spectrum.status)
                levelBar
                Text("Level over the last moments. Not a recording.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)
                TraceSparkline(
                    samples: levelTrace,
                    accessibilityLabel: "Recent microphone level. Amplitude in dBFS versus time.",
                    showsDBFSTimeAxes: true,
                    fullscreenTitle: "Level"
                )
            }
            DiagramCard(
                title: frozenBands == nil ? "Spectrum" : "Spectrum frozen",
                accessibilitySummary: shareSummary,
                exportName: "beckify-noise-spectrum"
            ) {
                Text("Audible band, relative dBFS. \(RelativeHarmonicEnergy.honestLimit) Not a sound camera and not ultrasonic.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                Picker("Window", selection: $spectrum.windowKind) {
                    ForEach(SpectrumWindowKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                SpectrumPlot(bands: shownBands, footnote: spectrumFootnote)
                    .padding(.top, 8)
                Button(frozenBands == nil ? "Freeze" : "Live") { toggleFreeze() }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            }
            Button("Reset peak") { peak = SoundLevel.silenceFloorDBFS }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
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
        .onChange(of: spectrum.rmsDBFS) { _, db in
            if db > peak { peak = db }
            guard spectrum.hasReading else { return }
            levelTrace = MagSweepMath.appendTrace(levelTrace, sample: db, limit: 80)
        }
    }

    private var shownBands: [AcousticDisplayBand] {
        frozenBands ?? spectrum.bands
    }

    private var shownRatio: Double? {
        frozenBands == nil ? spectrum.harmonicRatio : frozenRatio
    }

    private var shownRate: Double {
        frozenBands == nil ? spectrum.sampleRateHz : frozenRate
    }

    private var harmonicLabel: String {
        guard let ratio = shownRatio, ratio.isFinite else { return "—" }
        return "\(Format.number(ratio * 100, digits: 0))% relative"
    }

    private var spectrumFootnote: String {
        let rate = shownRate
        let nyquist = CoupledVibrationMath.nyquistHz(sampleRateHz: rate)
        let fs = rate > 0 ? "fs \(Format.number(rate, digits: 0)) Hz" : "fs —"
        let nq = nyquist.map { "Nyquist \(Format.number($0, digits: 0)) Hz" } ?? "Nyquist —"
        return "\(fs) · \(nq) · \(spectrum.windowKind.title) window · display floor \(Format.number(AcousticSpectrum.displayFloorDBFS, digits: 0)) dBFS. Dashed line is this window’s median band, not a calibrated noise floor."
    }

    private var shareSummary: String {
        let stamp = NoiseMeterView.stamp.string(from: Date())
        return "\(stamp). \(spectrumFootnote) \(harmonicLabel). Not SPL. No location."
    }

    private func toggleFreeze() {
        if frozenBands == nil {
            frozenBands = spectrum.bands
            frozenRatio = spectrum.harmonicRatio
            frozenRate = spectrum.sampleRateHz
        } else {
            frozenBands = nil
            frozenRatio = nil
            frozenRate = 0
        }
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private func retainMic() {
        spectrum.retain(micToken, role: "Noise Meter")
    }

    private var sticky: String? {
        guard spectrum.hasReading else { return nil }
        return "\(Format.dbfs(spectrum.rmsDBFS)) · \(peakLabel)"
    }

    private var copyText: String? {
        guard spectrum.hasReading else { return nil }
        return "Now \(Format.dbfs(spectrum.rmsDBFS)), peak \(Format.dbfs(peak)), peak band \(peakLabel). Relative dBFS, not SPL."
    }

    private var peakLabel: String {
        guard let hz = spectrum.peakHz, hz.isFinite else { return "—" }
        return "\(Format.number(hz, digits: 0)) Hz"
    }

    private var levelBar: some View {
        let clamped = min(0, max(SoundLevel.silenceFloorDBFS, spectrum.rmsDBFS))
        let t = (clamped - SoundLevel.silenceFloorDBFS) / -SoundLevel.silenceFloorDBFS
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.surfaceRaised)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: max(4, geo.size.width * t))
            }
        }
        .frame(height: 10)
        .padding(.top, 8)
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .noiseMeter,
            notes: notes,
            inputs: ["formula": "20 log10(RMS) + audible FFT bands"],
            outputs: [
                "dBFS": Format.dbfs(spectrum.rmsDBFS),
                "peak": Format.dbfs(peak),
                "peakHz": peakLabel,
                "spl": "not claimed — uncalibrated",
            ]
        ))
    }
}
