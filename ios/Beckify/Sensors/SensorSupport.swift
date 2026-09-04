import SwiftUI
import UIKit

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
