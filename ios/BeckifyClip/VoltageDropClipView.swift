import StoreKit
import SwiftUI
import UIKit
import BeckifyMath

/// Existing production permalink. Do not invent a new public path.
enum ClipInvocation {
    static let urlString = "https://beckify.com/toolbox/voltage-drop/"

    static func matches(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        guard host == "beckify.com" || host == "www.beckify.com" else { return false }
        var path = url.path
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path.lowercased() == "/toolbox/voltage-drop"
    }
}

private enum ClipChrome {
    static let charcoal = Color(red: 28 / 255, green: 31 / 255, blue: 36 / 255)
    static let navy = Color(red: 7 / 255, green: 12 / 255, blue: 28 / 255)
    static let card = Color(red: 14 / 255, green: 22 / 255, blue: 42 / 255)
    static let cyan = Color(red: 64 / 255, green: 186 / 255, blue: 214 / 255)
    static let good = Color(red: 86 / 255, green: 214 / 255, blue: 164 / 255)
    static let warn = Color(red: 240 / 255, green: 188 / 255, blue: 72 / 255)
    static let bad = Color(red: 244 / 255, green: 112 / 255, blue: 120 / 255)
    static let muted = Color.white.opacity(0.62)
}

/// Clip-sized NEC field-K voltage drop. Math is `VoltageDropSizing` in BeckifyMath.
/// No JobStore, catalog, sensors, camera, microphone, BLE, or speech.
struct VoltageDropClipView: View {
    @AppStorage("clip.voltageDrop.system") private var systemRaw = ElectricalSystem.threePhase.rawValue
    @AppStorage("clip.voltageDrop.material") private var materialRaw = ConductorMaterial.copper.rawValue
    @AppStorage("clip.voltageDrop.voltage") private var voltage = "480"
    @AppStorage("clip.voltageDrop.current") private var current = "45"
    @AppStorage("clip.voltageDrop.length") private var length = "250"
    @AppStorage("clip.voltageDrop.size") private var size = "4"
    @AppStorage("clip.voltageDrop.runs") private var runs = "1"
    @AppStorage("clip.voltageDrop.target") private var target = "3"

    @State private var result: VoltageDropSizingResult?
    @State private var errorText: String?
    @State private var invocationNote: String?
    private var system: ElectricalSystem {
        ElectricalSystem(rawValue: systemRaw) ?? .threePhase
    }

    private var material: ConductorMaterial {
        ConductorMaterial(rawValue: materialRaw) ?? .copper
    }

    private var sizes: [String] {
        NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Field K near 75 °C (≈12.9 Cu / 21.2 Al). Not Chapter 9 Table 9. Design aid — not a PE stamp.")
                        .font(.caption)
                        .foregroundStyle(ClipChrome.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let invocationNote {
                        Text(invocationNote)
                            .font(.caption.monospaced())
                            .foregroundStyle(ClipChrome.cyan)
                    }

                    Picker("System", selection: $systemRaw) {
                        ForEach(ElectricalSystem.allCases, id: \.rawValue) { item in
                            Text(item.displayName).tag(item.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Material", selection: $materialRaw) {
                        ForEach(ConductorMaterial.allCases, id: \.rawValue) { item in
                            Text(item.displayName).tag(item.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    ClipField(title: "Supply voltage", unit: "V", text: $voltage)
                    ClipField(title: "Load current", unit: "A", text: $current)
                    ClipField(title: "One-way length", unit: "ft", text: $length)
                    sizeRow
                    ClipField(title: "Parallel runs", unit: "runs", text: $runs)
                    ClipField(title: "Preferred target", unit: "%", text: $target)

                    HStack(spacing: 10) {
                        Button("Calculate", action: calculate)
                            .buttonStyle(ClipPrimaryButtonStyle())
                        Button("Example", action: loadExample)
                            .buttonStyle(ClipSecondaryButtonStyle())
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.callout)
                            .foregroundStyle(ClipChrome.bad)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let result {
                        resultCard(result)
                    }

                    Text("This clip is Voltage Drop only. The full Beckify toolbox is a separate free app — no in-app purchases.")
                        .font(.caption)
                        .foregroundStyle(ClipChrome.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Get the full Beckify toolbox", action: presentFullAppCard)
                        .buttonStyle(ClipSecondaryButtonStyle())
                }
                .padding(16)
            }
        }
        .background(ClipChrome.navy.ignoresSafeArea())
        .tint(ClipChrome.cyan)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            acceptInvocation(activity)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("voltageDrop")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .padding(6)
                .background(Circle().fill(ClipChrome.navy))
                .overlay(Circle().stroke(ClipChrome.cyan, lineWidth: 1.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("VOLTAGE DROP")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ClipChrome.cyan)
                    .tracking(1.1)
                Text("Beckify App Clip")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ClipChrome.charcoal)
        .accessibilityElement(children: .combine)
    }

    private var sizeRow: some View {
        HStack {
            Text("Conductor")
                .foregroundStyle(Color.white.opacity(0.86))
            Spacer()
            Picker("Conductor", selection: $size) {
                ForEach(sizes, id: \.self) { item in
                    Text(NECTables.wireLabel(item)).tag(item)
                }
            }
            .labelsHidden()
            .tint(ClipChrome.cyan)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ClipChrome.card)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ClipChrome.cyan.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func resultCard(_ result: VoltageDropSizingResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.formula)
                .font(.caption2.monospaced())
                .foregroundStyle(ClipChrome.muted)
                .fixedSize(horizontal: false, vertical: true)
            row("Voltage drop", String(format: "%.2f V", result.dropVolts), emphasis: true)
            row("Drop", String(format: "%.2f%%", result.dropPercent), emphasis: true)
            row("Receiving end", String(format: "%.1f V", result.receivingVolts))
            row(
                "Target \(String(format: "%.1f%%", result.targetDropPercent))",
                result.meetsTarget ? "MEETS" : "OVER",
                tone: result.meetsTarget ? ClipChrome.good : ClipChrome.warn
            )
            row(
                "3% informational note",
                result.meets3Percent ? "WITHIN" : "OVER",
                tone: result.meets3Percent ? ClipChrome.good : ClipChrome.warn
            )
            row(
                "5% informational note (this run)",
                result.meets5Percent ? "WITHIN" : "OVER",
                tone: result.meets5Percent ? ClipChrome.good : ClipChrome.bad
            )
            if let amp = result.ampacity75C {
                row(
                    "310.16 75 °C × runs",
                    "\(amp) A" + (result.ampacityOK ? "  meets load" : "  undersized"),
                    tone: result.ampacityOK ? ClipChrome.good : ClipChrome.bad
                )
            }
            if let rec = result.recommendedLabel {
                row("Recommended", rec, emphasis: true, tone: ClipChrome.good)
            }
            ForEach(Array(result.warnings.prefix(3)), id: \.self) { warning in
                Text(warning.message)
                    .font(.caption2)
                    .foregroundStyle(ClipChrome.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClipChrome.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ClipChrome.cyan.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ label: String, _ value: String, emphasis: Bool = false, tone: Color = .white) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(ClipChrome.muted)
            Spacer(minLength: 8)
            Text(value)
                .font(emphasis ? .body.weight(.semibold).monospacedDigit() : .callout.monospacedDigit())
                .foregroundStyle(tone)
                .multilineTextAlignment(.trailing)
        }
    }

    private func calculate() {
        errorText = nil
        let input = VoltageDropSizingInput(
            system: system,
            supplyVolts: Double(voltage.replacingOccurrences(of: ",", with: "")) ?? .nan,
            current: Double(current.replacingOccurrences(of: ",", with: "")) ?? .nan,
            oneWayFeet: Double(length.replacingOccurrences(of: ",", with: "")) ?? .nan,
            size: size,
            material: material,
            parallelRuns: Int(runs) ?? 0,
            targetDropPercent: Double(target.replacingOccurrences(of: ",", with: "")) ?? .nan,
            method: .kFactorApproximation
        )
        do {
            result = try VoltageDropSizing.calculate(input)
        } catch let error as CalcError {
            result = nil
            errorText = error.message
        } catch {
            result = nil
            errorText = error.localizedDescription
        }
    }

    private func loadExample() {
        systemRaw = ElectricalSystem.threePhase.rawValue
        materialRaw = ConductorMaterial.copper.rawValue
        voltage = "480"
        current = "45"
        length = "250"
        size = "4"
        runs = "1"
        target = "3"
        calculate()
    }

    private func acceptInvocation(_ activity: NSUserActivity) {
        guard let url = activity.webpageURL else { return }
        guard ClipInvocation.matches(url) else { return }
        invocationNote = "Opened from \(ClipInvocation.urlString)"
    }

    private func presentFullAppCard() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }
        let config = SKOverlay.AppClipConfiguration(position: .bottom)
        SKOverlay(configuration: config).present(in: scene)
    }
}

private struct ClipField: View {
    let title: String
    let unit: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.white.opacity(0.86))
            Spacer(minLength: 8)
            TextField(unit, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(ClipChrome.cyan)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 140)
            Text(unit)
                .font(.caption.monospaced())
                .foregroundStyle(ClipChrome.cyan)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ClipChrome.card)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ClipChrome.cyan.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ClipPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(ClipChrome.navy)
            .background(ClipChrome.cyan.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ClipSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(ClipChrome.cyan)
            .background(ClipChrome.charcoal.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ClipChrome.cyan.opacity(0.7), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
