import SwiftUI
import UIKit

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
    }
}

func formatCoordinate(_ value: Double, digits: Int = 6) -> String {
    String(format: "%.\(digits)f", value)
}
