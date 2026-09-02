import AVFoundation
import Combine
import SwiftUI
import BeckifyMath

@MainActor
final class NoiseMeterModel: ObservableObject {
    @Published var dbfs: Double = SoundLevel.silenceFloorDBFS
    @Published var peak: Double = SoundLevel.silenceFloorDBFS
    @Published var permissionDenied = false
    @Published var running = false
    @Published var hasReading = false
    @Published var status = "Microphone idle"

    private let engine = AVAudioEngine()
    private var installed = false
    private var wantsRunning = false

    func start() {
        wantsRunning = true
        requestThenRun()
    }

    func stop() {
        wantsRunning = false
        running = false
        status = "Microphone idle"
        if installed {
            engine.inputNode.removeTap(onBus: 0)
            installed = false
        }
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func resetPeak() {
        peak = SoundLevel.silenceFloorDBFS
    }

    private func requestThenRun() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, self.wantsRunning else { return }
                if granted {
                    self.permissionDenied = false
                    self.beginEngine()
                } else {
                    self.permissionDenied = true
                    self.status = "Microphone permission denied"
                }
            }
        }
    }

    private func beginEngine() {
        guard wantsRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            if installed {
                input.removeTap(onBus: 0)
                installed = false
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                let rms = Self.rms(buffer)
                let db = SoundLevel.dbfs(rms: rms)
                Task { @MainActor in
                    self?.dbfs = db
                    self?.hasReading = true
                    if db > (self?.peak ?? SoundLevel.silenceFloorDBFS) {
                        self?.peak = db
                    }
                }
            }
            installed = true
            try engine.start()
            running = true
            status = "Metering (uncalibrated dBFS)"
        } catch {
            status = "Could not start audio: \(error.localizedDescription)"
            running = false
        }
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Double = 0
        for i in 0..<n {
            let s = Double(channel[i])
            sum += s * s
        }
        return sqrt(sum / Double(n))
    }
}

struct NoiseMeterView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = NoiseMeterModel()
    @StoredInput(.noiseMeter, "jobName", default: "Noise snapshot") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .noiseMeter,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Saving stores the numeric dBFS snapshot only — not a recording.")
        ) {
            ShowWorkCard(
                toolID: .noiseMeter,
                symbolic: "dBFS = 20 × log₁₀(RMS)",
                substituted: sticky,
                meaning: "Relative to full-scale digital. Not dB SPL, not A-weighted, not OSHA, not a calibrated SLM."
            )
            if model.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "This meter needs the microphone permission for uncalibrated dBFS. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            }
            ResultCard(title: "Level", copyText: copyText) {
                ResultRow(label: "Now", value: Format.dbfs(model.dbfs), emphasis: true, tone: Theme.good)
                ResultRow(label: "Peak hold", value: Format.dbfs(model.peak), tone: Theme.warn)
                ResultRow(label: "Engine", value: model.status)
                levelBar
            }
            Button("Reset peak") { model.resetPeak() }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.hasReading) { save() }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var sticky: String? {
        guard model.hasReading else { return nil }
        return Format.dbfs(model.dbfs)
    }
    private var copyText: String? {
        guard model.hasReading else { return nil }
        return "Now \(Format.dbfs(model.dbfs)), peak \(Format.dbfs(model.peak))"
    }

    private var levelBar: some View {
        let clamped = min(0, max(SoundLevel.silenceFloorDBFS, model.dbfs))
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
            inputs: ["formula": "20 log10(RMS)"],
            outputs: [
                "dBFS": Format.dbfs(model.dbfs),
                "peak": Format.dbfs(model.peak),
                "spl": "not claimed — uncalibrated",
            ]
        ))
    }
}
