import Foundation

/// Site / system scale used for default derates and DC:AC guidance.
public enum SolarSystemScale: String, Sendable, CaseIterable {
    case residential
    case commercial
    case utility
}

/// How optional energy storage is sized.
public enum SolarStorageMode: String, Sendable, CaseIterable {
    /// Overnight / multi-day backup of daily load energy.
    case autonomy
    /// Cover evening peak for a stated number of hours at peak load.
    case peakShave
    /// Self-consumption buffer as a fraction of daily PV production.
    case selfConsumption
}

public struct SolarOrientationAdvice: Equatable, Sendable {
    /// Year-round fixed-tilt starting point ≈ |latitude|.
    public var yearRoundTiltDegrees: Double
    public var summerTiltDegrees: Double
    public var winterTiltDegrees: Double
    /// 180° = true south (northern hemisphere); 0° = true north (southern).
    public var optimalAzimuthDegrees: Double
    public var hemisphere: String

    public init(
        yearRoundTiltDegrees: Double,
        summerTiltDegrees: Double,
        winterTiltDegrees: Double,
        optimalAzimuthDegrees: Double,
        hemisphere: String
    ) {
        self.yearRoundTiltDegrees = yearRoundTiltDegrees
        self.summerTiltDegrees = summerTiltDegrees
        self.winterTiltDegrees = winterTiltDegrees
        self.optimalAzimuthDegrees = optimalAzimuthDegrees
        self.hemisphere = hemisphere
    }
}

public struct SolarStorageResult: Equatable, Sendable {
    public var nameplateKwh: Double
    public var usableKwh: Double
    public var autonomyHoursAtAverageLoad: Double
    public var recommendedPowerKw: Double
    public var modeLabel: String

    public init(
        nameplateKwh: Double,
        usableKwh: Double,
        autonomyHoursAtAverageLoad: Double,
        recommendedPowerKw: Double,
        modeLabel: String
    ) {
        self.nameplateKwh = nameplateKwh
        self.usableKwh = usableKwh
        self.autonomyHoursAtAverageLoad = autonomyHoursAtAverageLoad
        self.recommendedPowerKw = recommendedPowerKw
        self.modeLabel = modeLabel
    }
}

public struct SolarDesignResult: Equatable, Sendable {
    public var scale: SolarSystemScale
    public var arrayKwDc: Double
    public var panelCount: Int
    public var panelWatts: Double
    public var dailyProductionKwh: Double
    public var annualProductionKwh: Double
    public var specificYieldKwhPerKwp: Double
    public var orientationFactor: Double
    public var systemEfficiency: Double
    public var inverterKwAc: Double
    public var dcAcRatio: Double
    public var peakSunHours: Double
    public var advice: SolarOrientationAdvice
    public var tiltErrorDegrees: Double
    public var azimuthErrorDegrees: Double
    public var storage: SolarStorageResult?
    public var roofOrGroundAreaM2: Double

    public init(
        scale: SolarSystemScale,
        arrayKwDc: Double,
        panelCount: Int,
        panelWatts: Double,
        dailyProductionKwh: Double,
        annualProductionKwh: Double,
        specificYieldKwhPerKwp: Double,
        orientationFactor: Double,
        systemEfficiency: Double,
        inverterKwAc: Double,
        dcAcRatio: Double,
        peakSunHours: Double,
        advice: SolarOrientationAdvice,
        tiltErrorDegrees: Double,
        azimuthErrorDegrees: Double,
        storage: SolarStorageResult?,
        roofOrGroundAreaM2: Double
    ) {
        self.scale = scale
        self.arrayKwDc = arrayKwDc
        self.panelCount = panelCount
        self.panelWatts = panelWatts
        self.dailyProductionKwh = dailyProductionKwh
        self.annualProductionKwh = annualProductionKwh
        self.specificYieldKwhPerKwp = specificYieldKwhPerKwp
        self.orientationFactor = orientationFactor
        self.systemEfficiency = systemEfficiency
        self.inverterKwAc = inverterKwAc
        self.dcAcRatio = dcAcRatio
        self.peakSunHours = peakSunHours
        self.advice = advice
        self.tiltErrorDegrees = tiltErrorDegrees
        self.azimuthErrorDegrees = azimuthErrorDegrees
        self.storage = storage
        self.roofOrGroundAreaM2 = roofOrGroundAreaM2
    }
}

/// Transparent PV planning math — not a shade study, PE stamp, or utility interconnection model.
public enum SolarDesign {
    /// Typical peak-sun-hour presets (kWh/m²/day ≈ PSH for STC planning). Editable in the UI.
    public static let peakSunHourPresets: [(id: String, label: String, hours: Double)] = [
        ("arid", "Arid / desert (6.0)", 6.0),
        ("southwest", "US Southwest / Mediterranean (5.5)", 5.5),
        ("temperate", "Temperate sunny (4.5)", 4.5),
        ("mixed", "Mixed / cloudy temperate (3.5)", 3.5),
        ("cloudy", "Cloudy / high latitude (2.5)", 2.5),
        ("custom", "Custom", 4.5),
    ]

    public static let defaultSystemEfficiencyPercent: [SolarSystemScale: Double] = [
        .residential: 80,
        .commercial: 82,
        .utility: 85,
    ]

    public static let defaultDcAcRatio: [SolarSystemScale: Double] = [
        .residential: 1.20,
        .commercial: 1.25,
        .utility: 1.30,
    ]

    /// Approximate module footprint including aisle / racking allowance (m² per STC kW).
    public static let areaM2PerKwDc: [SolarSystemScale: Double] = [
        .residential: 6.0,
        .commercial: 5.5,
        .utility: 5.0,
    ]

    // MARK: - Orientation

    public static func orientationAdvice(latitudeDegrees: Double) throws -> SolarOrientationAdvice {
        guard latitudeDegrees.isFinite, abs(latitudeDegrees) <= 90 else {
            throw CalcError.outOfRange("Latitude must be between −90° and +90°.")
        }
        let absLat = abs(latitudeDegrees)
        let yearRound = absLat
        let summer = max(0, absLat - 15)
        let winter = min(90, absLat + 15)
        let southern = latitudeDegrees < 0
        return SolarOrientationAdvice(
            yearRoundTiltDegrees: yearRound,
            summerTiltDegrees: summer,
            winterTiltDegrees: winter,
            optimalAzimuthDegrees: southern ? 0 : 180,
            hemisphere: southern ? "southern" : (latitudeDegrees > 0 ? "northern" : "equatorial")
        )
    }

    /// Smallest absolute difference between two compass headings on a circle.
    public static func azimuthErrorDegrees(measured: Double, target: Double) -> Double {
        var d = abs(normalizeDegrees(measured) - normalizeDegrees(target))
        if d > 180 { d = 360 - d }
        return d
    }

    public static func normalizeDegrees(_ deg: Double) -> Double {
        guard deg.isFinite else { return .nan }
        var x = deg.truncatingRemainder(dividingBy: 360)
        if x < 0 { x += 360 }
        return x
    }

    /**
     Relative irradiance factor for a fixed array vs an optimally aimed one.
     Uses a transparent cosine model of tilt and azimuth error — not Perez/Hay-Davies.
     */
    public static func orientationFactor(
        tiltDegrees: Double,
        azimuthDegrees: Double,
        advice: SolarOrientationAdvice
    ) throws -> (factor: Double, tiltError: Double, azimuthError: Double) {
        guard tiltDegrees.isFinite, tiltDegrees >= 0, tiltDegrees <= 90 else {
            throw CalcError.outOfRange("Tilt must be between 0° and 90°.")
        }
        guard azimuthDegrees.isFinite else {
            throw CalcError.outOfRange("Azimuth must be a finite compass heading.")
        }
        let tiltErr = abs(tiltDegrees - advice.yearRoundTiltDegrees)
        let azErr = azimuthErrorDegrees(measured: azimuthDegrees, target: advice.optimalAzimuthDegrees)
        let tiltRad = tiltErr * .pi / 180
        let azRad = azErr * .pi / 180
        let tiltWeight = advice.yearRoundTiltDegrees * .pi / 180
        // Azimuth matters more on steep arrays; flat roofs are nearly insensitive.
        let azWeight = sin(max(0.05, tiltWeight))
        let cosInc = cos(tiltRad) * cos(azRad * azWeight)
        let factor = max(0.25, min(1.0, cosInc))
        return (factor, tiltErr, azErr)
    }

    /**
     Panel plane tilt from horizontal when the phone lies face-up on the panel.
     Gravity in device coords (+X right, +Y toward top of screen, +Z toward user).
     */
    public static func panelTiltFromGravityDegrees(gravityX: Double, gravityY: Double, gravityZ: Double) -> Double {
        let mag = LevelMath.magnitude(gravityX, gravityY, gravityZ)
        guard mag > 1e-9, mag.isFinite else { return .nan }
        let cosine = max(-1.0, min(1.0, abs(gravityZ) / mag))
        return acos(cosine) * 180 / .pi
    }

    // MARK: - Array & production

    public static func size(
        scale: SolarSystemScale,
        latitudeDegrees: Double,
        dailyLoadKwh: Double,
        peakSunHours: Double,
        panelWatts: Double,
        tiltDegrees: Double,
        azimuthDegrees: Double,
        systemEfficiencyPercent: Double? = nil,
        dcAcRatio: Double? = nil,
        panelCountOverride: Double? = nil,
        includeStorage: Bool = false,
        storageMode: SolarStorageMode = .autonomy,
        autonomyDays: Double = 1,
        peakLoadKw: Double = 0,
        peakDurationHours: Double = 4,
        selfConsumptionFractionPercent: Double = 40,
        storageDodPercent: Double = 90,
        storageRoundTripEfficiencyPercent: Double = 90
    ) throws -> SolarDesignResult {
        let load = try Positive.require(dailyLoadKwh, name: "Daily load")
        let psh = try Positive.require(peakSunHours, name: "Peak sun hours")
        guard psh <= 12 else {
            throw CalcError.outOfRange("Peak sun hours above 12 is not physical for a daily average.")
        }
        let watts = try Positive.require(panelWatts, name: "Panel wattage")
        let advice = try orientationAdvice(latitudeDegrees: latitudeDegrees)
        let orient = try orientationFactor(
            tiltDegrees: tiltDegrees,
            azimuthDegrees: azimuthDegrees,
            advice: advice
        )

        let etaPct = systemEfficiencyPercent ?? defaultSystemEfficiencyPercent[scale]!
        guard etaPct.isFinite, etaPct > 0, etaPct <= 100 else {
            throw CalcError.outOfRange("System efficiency is between 0 and 100 %.")
        }
        let eta = etaPct / 100

        let ratio = dcAcRatio ?? defaultDcAcRatio[scale]!
        guard ratio.isFinite, ratio >= 0.8, ratio <= 2.0 else {
            throw CalcError.outOfRange("DC:AC ratio should be between 0.8 and 2.0 for planning.")
        }

        let panelCount: Int
        let arrayKw: Double
        if let override = panelCountOverride, override.isFinite, override > 0 {
            panelCount = max(1, Int(override.rounded()))
            arrayKw = Double(panelCount) * watts / 1000
        } else {
            // Array_kW = Daily_kWh / (PSH × η × orientation)
            let denom = psh * eta * orient.factor
            guard denom > 0 else {
                throw CalcError.outOfRange("Effective sun hours after losses must be greater than zero.")
            }
            let neededKw = load / denom
            panelCount = max(1, Int(ceil(neededKw * 1000 / watts - 1e-9)))
            arrayKw = Double(panelCount) * watts / 1000
        }

        let dailyProd = arrayKw * psh * eta * orient.factor
        let annual = dailyProd * 365
        let specific = arrayKw > 0 ? annual / arrayKw : 0
        let inverterKw = arrayKw / ratio
        let area = arrayKw * (areaM2PerKwDc[scale] ?? 5.5)

        var storage: SolarStorageResult?
        if includeStorage {
            storage = try sizeStorage(
                mode: storageMode,
                dailyLoadKwh: load,
                dailyProductionKwh: dailyProd,
                autonomyDays: autonomyDays,
                peakLoadKw: peakLoadKw > 0 ? peakLoadKw : load / 24 * 2,
                peakDurationHours: peakDurationHours,
                selfConsumptionFractionPercent: selfConsumptionFractionPercent,
                dodPercent: storageDodPercent,
                roundTripEfficiencyPercent: storageRoundTripEfficiencyPercent,
                arrayKwDc: arrayKw
            )
        }

        return SolarDesignResult(
            scale: scale,
            arrayKwDc: arrayKw,
            panelCount: panelCount,
            panelWatts: watts,
            dailyProductionKwh: dailyProd,
            annualProductionKwh: annual,
            specificYieldKwhPerKwp: specific,
            orientationFactor: orient.factor,
            systemEfficiency: eta,
            inverterKwAc: inverterKw,
            dcAcRatio: ratio,
            peakSunHours: psh,
            advice: advice,
            tiltErrorDegrees: orient.tiltError,
            azimuthErrorDegrees: orient.azimuthError,
            storage: storage,
            roofOrGroundAreaM2: area
        )
    }

    public static func sizeStorage(
        mode: SolarStorageMode,
        dailyLoadKwh: Double,
        dailyProductionKwh: Double,
        autonomyDays: Double,
        peakLoadKw: Double,
        peakDurationHours: Double,
        selfConsumptionFractionPercent: Double,
        dodPercent: Double,
        roundTripEfficiencyPercent: Double,
        arrayKwDc: Double
    ) throws -> SolarStorageResult {
        let load = try Positive.require(dailyLoadKwh, name: "Daily load")
        guard dodPercent.isFinite, dodPercent > 0, dodPercent <= 100 else {
            throw CalcError.outOfRange("Storage depth of discharge is between 0 and 100 %.")
        }
        guard roundTripEfficiencyPercent.isFinite, roundTripEfficiencyPercent > 0, roundTripEfficiencyPercent <= 100 else {
            throw CalcError.outOfRange("Round-trip efficiency is between 0 and 100 %.")
        }
        let dod = dodPercent / 100
        let rte = roundTripEfficiencyPercent / 100
        let denom = dod * rte
        guard denom > 0 else {
            throw CalcError.outOfRange("DoD × round-trip efficiency must be greater than zero.")
        }

        let usableNeeded: Double
        let powerKw: Double
        let label: String

        switch mode {
        case .autonomy:
            let days = try Positive.require(autonomyDays, name: "Autonomy days")
            usableNeeded = load * days
            powerKw = max(arrayKwDc * 0.5, load / 24 * 1.5)
            label = "Autonomy (\(formatDays(days)) d)"
        case .peakShave:
            let pk = try Positive.require(peakLoadKw, name: "Peak load")
            let hrs = try Positive.require(peakDurationHours, name: "Peak duration")
            guard hrs <= 24 else {
                throw CalcError.outOfRange("Peak duration should be 24 hours or less.")
            }
            usableNeeded = pk * hrs
            powerKw = pk
            label = "Peak-shave (\(formatHours(hrs)) h)"
        case .selfConsumption:
            guard selfConsumptionFractionPercent.isFinite,
                  selfConsumptionFractionPercent > 0,
                  selfConsumptionFractionPercent <= 100 else {
                throw CalcError.outOfRange("Self-consumption fraction is between 0 and 100 %.")
            }
            let prod = try Positive.require(dailyProductionKwh, name: "Daily production")
            usableNeeded = prod * (selfConsumptionFractionPercent / 100)
            powerKw = max(arrayKwDc * 0.4, usableNeeded / 6)
            label = "Self-consumption (\(Int(selfConsumptionFractionPercent.rounded())) % of daily PV)"
        }

        let nameplate = usableNeeded / denom
        let avgLoadKw = load / 24
        let autonomyHours = avgLoadKw > 0 ? usableNeeded / avgLoadKw : 0

        return SolarStorageResult(
            nameplateKwh: nameplate,
            usableKwh: usableNeeded,
            autonomyHoursAtAverageLoad: autonomyHours,
            recommendedPowerKw: powerKw,
            modeLabel: label
        )
    }

    private static func formatDays(_ d: Double) -> String {
        if abs(d - d.rounded()) < 1e-9 { return String(Int(d.rounded())) }
        return String(format: "%.1f", d)
    }

    private static func formatHours(_ h: Double) -> String {
        if abs(h - h.rounded()) < 1e-9 { return String(Int(h.rounded())) }
        return String(format: "%.1f", h)
    }
}
