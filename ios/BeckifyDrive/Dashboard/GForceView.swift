import BeckifyMath
import SwiftUI

/// G-ball: smoothed lateral (x) and longitudinal (y) acceleration with a fading trail and a peak.
struct GForceCard: View {
    @ObservedObject var feed: GForceFeed
    let locationAccess: SensorAccess
    let requestLocation: () -> Void
    let openSettings: () -> Void

    var body: some View {
        let tracker = feed.tracker
        let current = feed.aligned ? tracker.current : nil
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "gyroscope")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(current == nil ? DriveTheme.muted : DriveTheme.accent)
                Text("G-force")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DriveTheme.muted)
                Spacer()
                if tracker.peak > 0 {
                    Button {
                        feed.resetPeak()
                    } label: {
                        Label("Reset peak", systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .tint(DriveTheme.muted)
                }
            }
            HStack(alignment: .center, spacing: 16) {
                GBall(trail: feed.aligned ? tracker.trail : [], current: current, scale: GBallScale.radius(peak: tracker.peak))
                    .frame(width: 132, height: 132)
                VStack(alignment: .leading, spacing: 8) {
                    readout("Peak", tracker.peak > 0 ? String(format: "%.2f", tracker.peak) : nil)
                    readout("Accel / brake", current.map { String(format: "%+.2f", $0.longitudinal) })
                    readout("Lateral", current.map { String(format: "%+.2f", $0.lateral) })
                }
                Spacer(minLength: 0)
            }
            if !feed.aligned {
                VStack(alignment: .leading, spacing: 6) {
                    Text(alignmentNote)
                        .font(.caption)
                        .foregroundStyle(DriveTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    PermissionPrompt(access: locationAccess, askTitle: "Allow Location", ask: requestLocation, openSettings: openSettings)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .driveCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("G-force")
        .accessibilityValue(spoken(current: current, peak: tracker.peak))
    }

    private var alignmentNote: String {
        switch locationAccess {
        case .allowed:
            return "Lines up with the car once GPS sees you moving. Phone axes alone do not say which way the car points."
        case .notAsked, .denied:
            return "G-force uses GPS course to tell forward from sideways, so it needs Location."
        case .unavailable:
            return "This device cannot line motion up with the car."
        }
    }

    private func readout(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DriveTheme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value ?? "—")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(value == nil ? DriveTheme.muted : DriveTheme.text)
                if value != nil {
                    Text("g")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DriveTheme.muted)
                }
            }
        }
    }

    private func spoken(current: GVector?, peak: Double) -> String {
        guard let current else { return "Not aligned yet" }
        return String(
            format: "%.2f g forward, %.2f g sideways, peak %.2f g",
            current.longitudinal, current.lateral, peak
        )
    }
}

/// The plot. Up is speeding up, down is braking, right is a push to the right.
struct GBall: View {
    let trail: [GVector]
    let current: GVector?
    /// Outer ring in g.
    let scale: Double

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - 6
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func point(_ g: GVector) -> CGPoint {
                let x = min(max(g.lateral / scale, -1), 1)
                let y = min(max(g.longitudinal / scale, -1), 1)
                return CGPoint(x: center.x + CGFloat(x) * radius, y: center.y - CGFloat(y) * radius)
            }
            var step = 0.25
            while step <= scale + 0.000_1 {
                let r = radius * CGFloat(step / scale)
                let ring = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                context.stroke(ring, with: .color(DriveTheme.track), lineWidth: 1)
                step += 0.25
            }
            var cross = Path()
            cross.move(to: CGPoint(x: center.x - radius, y: center.y))
            cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            cross.move(to: CGPoint(x: center.x, y: center.y - radius))
            cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            context.stroke(cross, with: .color(DriveTheme.track), lineWidth: 1)
            for (index, g) in trail.enumerated() {
                let alpha = Double(index + 1) / Double(max(trail.count, 1))
                let p = point(g)
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                    with: .color(DriveTheme.accent.opacity(alpha * 0.45))
                )
            }
            if let current {
                let p = point(current)
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)),
                    with: .color(DriveTheme.accent)
                )
            }
        }
        .overlay(alignment: .top) { axisLabel("Accel") }
        .overlay(alignment: .bottom) { axisLabel("Brake") }
        .overlay(alignment: .topTrailing) {
            Text(String(format: "%.2f g", scale))
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(DriveTheme.muted)
        }
        .accessibilityHidden(true)
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(DriveTheme.muted)
            .padding(.horizontal, 3)
            .background(DriveTheme.background.opacity(0.7), in: Capsule())
    }
}
