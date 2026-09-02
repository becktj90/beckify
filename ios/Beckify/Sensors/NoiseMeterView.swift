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
    @State private var jobName = "Noise snapshot"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "dBFS = 20 × log₁₀(RMS)",
                    citation: "Relative to full-scale digital. Not dB SPL, not A-weighted, not OSHA, not a calibrated SLM."
                )
                ResultCard(title: "Level") {
                    ResultRow(label: "Now", value: Format.dbfs(model.dbfs), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Peak hold", value: Format.dbfs(model.peak), tone: Theme.warn)
                    ResultRow(label: "Engine", value: model.status)
                    levelBar
                }
                if model.permissionDenied {
                    SettingsLinkButton()
                }
                HStack {
                    Button("Reset peak") { model.resetPeak() }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                }
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.running || model.dbfs > SoundLevel.silenceFloorDBFS) { save() }
                SensorDisclaimer(extra: "Saving stores the numeric dBFS snapshot only — not a recording.")
            }
            .padding(20)
        }
        .navigationTitle("Noise Meter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
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
