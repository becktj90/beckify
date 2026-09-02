import Foundation

/// Pitch/roll and plumb math from a gravity vector (device coordinates, g units).
/// iOS: +X right, +Y toward the top of the screen, +Z toward the user.
public enum LevelMath {
    /// Face-up bubble: (0, 0) when gravity is (0, 0, −1). `x` is left/right, `y` is toward the top.
    public static func faceUpTiltDegrees(gravityX: Double, gravityY: Double, gravityZ: Double) -> (x: Double, y: Double) {
        let x = atan2(gravityX, hypot(gravityY, gravityZ)) * 180 / .pi
        let y = atan2(gravityY, hypot(gravityX, gravityZ)) * 180 / .pi
        return (x, y)
    }

    /// Angle from portrait plumb (gravity along −Y). 0° = phone standing, screen toward you.
    public static func portraitPlumbDeviationDegrees(gravityX: Double, gravityY: Double, gravityZ: Double) -> Double {
        let mag = magnitude(gravityX, gravityY, gravityZ)
        guard mag > 0, mag.isFinite else { return .nan }
        let cosine = max(-1, min(1, -gravityY / mag))
        return acos(cosine) * 180 / .pi
    }

    public static func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        hypot(hypot(x, y), z)
    }
}

/// Magnetometer helpers. Inputs are microteslas unless noted.
public enum MagneticMath {
    public static func magnitudeMicrotesla(x: Double, y: Double, z: Double) -> Double {
        hypot(hypot(x, y), z)
    }

    /// Heading in degrees [0, 360): 0 = +Y (north if the vector is already in magnetic-north frame), 90 = +X (east).
    public static func headingDegrees(x: Double, y: Double) -> Double {
        var deg = atan2(x, y) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    /// 1 gauss = 100 µT.
    public static func gauss(fromMicrotesla microtesla: Double) -> Double {
        microtesla / 100
    }
}

/// Uncalibrated audio level math. Not a sound-level meter.
public enum SoundLevel {
    public static let silenceFloorDBFS: Double = -120

    /// dB full-scale from linear RMS (1.0 = 0 dBFS). Non-positive RMS maps to the silence floor.
    public static func dbfs(rms: Double) -> Double {
        guard rms.isFinite, rms > 0 else { return silenceFloorDBFS }
        return max(silenceFloorDBFS, 20 * log10(rms))
    }
}

/// Linear acceleration helpers.
public enum MotionMath {
    public static let standardGravityMS2: Double = 9.80665

    public static func magnitudeG(x: Double, y: Double, z: Double) -> Double {
        hypot(hypot(x, y), z)
    }

    public static func metersPerSecondSquared(fromG g: Double) -> Double {
        g * standardGravityMS2
    }
}

/// Great-circle homework helpers on a spherical Earth.
public enum GeoMath {
    public static let earthRadiusMeters: Double = 6_371_000

    public static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadiusMeters * c
    }

    /// Initial bearing in degrees [0, 360): 0 = north, 90 = east.
    public static func initialBearingDegrees(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        var deg = atan2(y, x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    /// Local east/north meters from an origin using an equirectangular approximation.
    public static func eastNorthMeters(originLat: Double, originLon: Double, lat: Double, lon: Double) -> (east: Double, north: Double) {
        let φ = originLat * .pi / 180
        let north = (lat - originLat) * .pi / 180 * earthRadiusMeters
        let east = (lon - originLon) * .pi / 180 * earthRadiusMeters * cos(φ)
        return (east, north)
    }
}

/// Coverage-sketch math for Apple's public `NEHotspotNetwork.signalStrength` (0…1).
/// This is not RSSI and not dBm — iOS does not give third-party apps those values.
public struct WiFiAmplitudeSample: Equatable, Sendable {
    public var east: Double
    public var north: Double
    public var strength: Double

    public init(east: Double, north: Double, strength: Double) {
        self.east = east
        self.north = north
        self.strength = strength
    }
}

public enum WiFiCoverageMath {
    public static func clampStrength(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    public static func percent(_ strength: Double) -> Double {
        clampStrength(strength) * 100
    }

    /// 0…4 bars from Apple's 0…1 scale. Not a carrier signal-bar algorithm.
    public static func bars(_ strength: Double) -> Int {
        let s = clampStrength(strength)
        if s <= 0 { return 0 }
        if s < 0.25 { return 1 }
        if s < 0.5 { return 2 }
        if s < 0.75 { return 3 }
        return 4
    }

    /// Inverse-distance weighting. `power` is typically 2.
    public static func idw(east: Double, north: Double, samples: [WiFiAmplitudeSample], power: Double = 2) -> Double {
        guard !samples.isEmpty, power > 0, east.isFinite, north.isFinite else { return .nan }
        var num = 0.0
        var den = 0.0
        for sample in samples {
            let s = clampStrength(sample.strength)
            guard s.isFinite else { continue }
            let dx = east - sample.east
            let dy = north - sample.north
            let d2 = dx * dx + dy * dy
            if d2 < 1e-12 { return s }
            let w = 1.0 / pow(sqrt(d2), power)
            num += w * s
            den += w
        }
        guard den > 0 else { return .nan }
        return num / den
    }

    public static func bounds(_ samples: [WiFiAmplitudeSample], padding: Double = 1) -> (minE: Double, maxE: Double, minN: Double, maxN: Double)? {
        guard let first = samples.first else { return nil }
        var minE = first.east, maxE = first.east, minN = first.north, maxN = first.north
        for s in samples.dropFirst() {
            minE = min(minE, s.east)
            maxE = max(maxE, s.east)
            minN = min(minN, s.north)
            maxN = max(maxN, s.north)
        }
        let pad = max(0, padding)
        if abs(maxE - minE) < 1e-9 {
            minE -= 1
            maxE += 1
        }
        if abs(maxN - minN) < 1e-9 {
            minN -= 1
            maxN += 1
        }
        return (minE - pad, maxE + pad, minN - pad, maxN + pad)
    }
}
