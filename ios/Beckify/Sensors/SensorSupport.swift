import SwiftUI
import UIKit
import BeckifyMath

/// Honest RF copy **above** the big gauge — not buried in Show Work.
struct RFHonestyBanner: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.warn.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct SensorDisclaimer: View {
    var extra: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclaimerBanner(text: Theme.sensorDisclaimer)
            if let extra {
                Text(extra)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

struct SettingsLinkButton: View {
    var body: some View {
        Button("Open Settings") {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
        .frame(minHeight: Theme.touchTarget)
        .accessibilityLabel("Open Settings")
        .accessibilityHint("Opens iOS Settings so you can allow this tool’s permission.")
        .onAppear {
            // Showing the deny → Settings path is not a win. Do not follow it
            // with Apple’s review sheet this session.
            ReviewAskStore.shared.notePermissionDenied()
        }
    }
}

func formatCoordinate(_ value: Double, digits: Int = 6) -> String {
    String(format: "%.\(digits)f", value)
}

/// First-class Look Check card — captive / local / online, never a dBm row.
struct LookCheckCard: View {
    @ObservedObject var model: LookCheckModel
    var onCheck: () -> Void

    var body: some View {
        ResultCard(title: "Look check", copyText: model.copyLine) {
            ResultRow(
                label: "Verdict",
                value: model.verdict?.headline ?? (model.measuring ? "Checking…" : "—"),
                emphasis: true,
                tone: verdictTone
            )
            ResultRow(label: "Path", value: model.verdict?.transportLabel ?? "—")
            ResultRow(label: "Local IPv4", value: model.localIPv4 ?? "—")
            if let addr = model.localAddress, model.localIPv4 == nil {
                ResultRow(label: "Local address", value: addr)
            }
            ResultRow(label: "Probe", value: "\(LookCheck.probeHost)\(LookCheck.probePath)")
            if let status = model.verdict?.httpStatus {
                ResultRow(label: "HTTP", value: "\(status)")
            }
            Text(model.verdict?.detail ?? model.message)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
            Button(model.measuring ? "Checking…" : "Look check") {
                onCheck()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            .padding(.top, 6)
            .disabled(model.measuring)
            .accessibilityLabel(model.measuring ? "Look check in progress" : "Run look check")
            .accessibilityHint("Fetches Apple’s hotspot-detect page over HTTP. Success means no captive splash. Not RSSI and not dBm.")
        }
    }

    private var verdictTone: Color {
        switch model.verdict?.kind {
        case .online: return Theme.good
        case .captive, .localOnly, .offline: return Theme.bad
        case .unclear: return Theme.warn
        default: return Theme.muted
        }
    }
}

/// NWPath chrome Trevor does not want on the default field view.
struct AdvancedPathDisclosure<Content: View>: View {
    @State private var open = false
    @ViewBuilder var content: Content

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: 2) {
                content
            }
            .padding(.top, 8)
        } label: {
            Text("Advanced path")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .frame(minHeight: Theme.touchTarget, alignment: .leading)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityHint("Interface names and path flags for debugging. Not the field verdict.")
        .accessibilityIdentifier("advancedPathDisclosure")
    }
}
