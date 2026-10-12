import BeckifyMath
import SwiftUI

/// On-device trip from the best speed available each second (OBD, else GPS).
struct TripCard: View {
    let trip: DriveTripStats
    let source: DashboardModel.SpeedSource?
    let now: Date
    let units: DriveUnitPreference
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(trip.startedAt == nil ? DriveTheme.muted : DriveTheme.accent)
                    .accessibilityHidden(true)
                Text("Trip")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DriveTheme.muted)
                if let source {
                    Text(source.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DriveTheme.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(DriveTheme.elevated, in: Capsule())
                }
                Spacer()
                Button(action: reset) {
                    Label("Reset trip", systemImage: "arrow.counterclockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .tint(DriveTheme.muted)
                .disabled(trip.startedAt == nil)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    stat("Distance", distance, units.distanceLabel)
                    stat("Time", duration, "")
                }
                GridRow {
                    stat("Average", average, units.speed.label)
                    stat("Max", maximum, units.speed.label)
                }
            }
            Text("Integrated on this phone. Not an odometer. Average counts moving time only.")
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .driveCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trip")
    }

    private var distance: String? {
        guard trip.startedAt != nil else { return nil }
        return String(format: "%.2f", units.distance(fromKilometers: trip.distanceKilometers))
    }

    private var duration: String? {
        guard let seconds = trip.duration(now: now) else { return nil }
        return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }

    private var average: String? {
        trip.averageMovingSpeedKph.map { String(format: "%.0f", units.speed(fromKph: $0)) }
    }

    private var maximum: String? {
        trip.maxSpeedKph.map { String(format: "%.0f", units.speed(fromKph: $0)) }
    }

    private func stat(_ title: String, _ value: String?, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DriveTheme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value ?? "—")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(value == nil ? DriveTheme.muted : DriveTheme.text)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if value != nil, !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DriveTheme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
