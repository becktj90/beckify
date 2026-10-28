import Foundation

/// Acceleration in the car's frame, in g.
/// Positive longitudinal is speeding up; positive lateral pushes toward the right.
public struct GVector: Equatable, Sendable {
    public var longitudinal: Double
    public var lateral: Double

    public init(longitudinal: Double, lateral: Double) {
        self.longitudinal = longitudinal
        self.lateral = lateral
    }

    public static let zero = GVector(longitudinal: 0, lateral: 0)

    public var magnitude: Double {
        (longitudinal * longitudinal + lateral * lateral).squareRoot()
    }
}

public enum GForceMath {
    /// Device-frame user acceleration (g) into the attitude reference frame.
    ///
    /// `matrix` is `CMAttitude.rotationMatrix` row-major (m11, m12, m13, m21, …).
    /// That matrix takes reference-frame vectors into the device frame, so the
    /// transpose takes the device vector back out.
    public static func toReference(
        device: (x: Double, y: Double, z: Double),
        matrix m: [Double]
    ) -> (x: Double, y: Double, z: Double)? {
        guard m.count == 9, m.allSatisfy(\.isFinite) else { return nil }
        let x = m[0] * device.x + m[3] * device.y + m[6] * device.z
        let y = m[1] * device.x + m[4] * device.y + m[7] * device.z
        let z = m[2] * device.x + m[5] * device.y + m[8] * device.z
        return (x, y, z)
    }

    /// Horizontal acceleration in `xTrueNorthZVertical` (X north, Y west, Z up)
    /// rotated into the car's frame using GPS course, degrees clockwise from true north.
    public static func vehicleFrame(northG: Double, westG: Double, courseDegrees: Double) -> GVector? {
        guard northG.isFinite, westG.isFinite, courseDegrees.isFinite, courseDegrees >= 0 else { return nil }
        let theta = courseDegrees * .pi / 180.0
        let eastG = -westG
        let forward = northG * cos(theta) + eastG * sin(theta)
        let right = -northG * sin(theta) + eastG * cos(theta)
        return GVector(longitudinal: forward, lateral: right)
    }
}

public enum CompassMath {
    private static let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    /// Eight-point cardinal for a heading in degrees clockwise from north.
    public static func cardinal(degrees: Double) -> String? {
        guard degrees.isFinite, degrees >= 0 else { return nil }
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        let index = Int((wrapped / 45.0).rounded()) % points.count
        return points[index]
    }
}

/// Full-scale radius for the G-ball plot: 0.5 g, growing in 0.25 g steps so a
/// hard stop stays on the plot. A display scale, not a limit.
public enum GBallScale {
    public static func radius(peak: Double) -> Double {
        guard peak.isFinite, peak > 0.5 else { return 0.5 }
        return (peak / 0.25).rounded(.up) * 0.25
    }
}

/// Extremes of the smoothed G vector over a short window (the driving score
/// takes one a second). Braking and launch are magnitudes; lateral is signed.
public struct GWindow: Equatable, Sendable {
    public var peakBrakeG: Double
    public var peakAccelG: Double
    /// Lateral G with the largest magnitude in the window; positive is toward the right.
    public var peakLateralG: Double
    public var samples: Int

    public init(peakBrakeG: Double = 0, peakAccelG: Double = 0, peakLateralG: Double = 0, samples: Int = 0) {
        self.peakBrakeG = peakBrakeG
        self.peakAccelG = peakAccelG
        self.peakLateralG = peakLateralG
        self.samples = samples
    }
}

/// Smoothed G readout, a short fading trail, and the session peak.
public struct GForceTracker: Equatable, Sendable {
    /// Exponential smoothing weight per sample. At 30 Hz, 0.2 settles in about
    /// a quarter second: steady enough to read, quick enough for a corner.
    public let smoothing: Double
    public let trailCapacity: Int
    public private(set) var current: GVector?
    public private(set) var trail: [GVector]
    public private(set) var peak: Double
    private var window = GWindow()

    public init(smoothing: Double = 0.2, trailCapacity: Int = 45) {
        self.smoothing = min(max(smoothing, 0.01), 1)
        self.trailCapacity = max(1, trailCapacity)
        current = nil
        trail = []
        peak = 0
    }

    public mutating func add(_ sample: GVector) {
        guard sample.longitudinal.isFinite, sample.lateral.isFinite else { return }
        let next: GVector
        if let current {
            next = GVector(
                longitudinal: current.longitudinal + smoothing * (sample.longitudinal - current.longitudinal),
                lateral: current.lateral + smoothing * (sample.lateral - current.lateral)
            )
        } else {
            next = sample
        }
        current = next
        trail.append(next)
        if trail.count > trailCapacity {
            trail.removeFirst(trail.count - trailCapacity)
        }
        // Peak follows the smoothed value so one pothole does not set it.
        peak = max(peak, next.magnitude)
        window.peakBrakeG = max(window.peakBrakeG, max(0, -next.longitudinal))
        window.peakAccelG = max(window.peakAccelG, max(0, next.longitudinal))
        if abs(next.lateral) > abs(window.peakLateralG) { window.peakLateralG = next.lateral }
        window.samples += 1
    }

    /// The extremes since the last call, then a fresh window. Nil when no sample
    /// arrived (phone not lined up with the car, or sensors off).
    public mutating func takeWindow() -> GWindow? {
        defer { window = GWindow() }
        return window.samples > 0 ? window : nil
    }

    public mutating func resetPeak() {
        peak = current?.magnitude ?? 0
    }

    public mutating func clear() {
        current = nil
        trail = []
        peak = 0
        window = GWindow()
    }
}
