import Foundation

/// Website `#sec-ebike-tools` / battery-build constants.
/// Ported from `artifacts/beckify/public/toolbox/js/app.js`,
/// `ebike-battery-designer.js`, and `battery-tools.js`.
public enum EbikeMath {
    /// Mechanical horsepower used by the website torque/RPM card (`× 746`).
    public static let wattsPerHorsepower: Double = 746
    /// Website display conversion `T_lbft = T_Nm × 0.737562`.
    public static let poundFeetPerNewtonMetre: Double = 0.737562
    public static let milesToKilometers: Double = 1.609344
    /// Li-ion charge ceiling used by both pack tools (`S × 4.2`).
    public static let lithiumCellMaxVolts: Double = 4.2
    /// Cell-to-cell clearance in the 18650 planner (`col = diameter + 3`).
    public static let packClearanceMM: Double = 3
    public static let packMarginWidthMM: Double = 30
    public static let packMarginHeightMM: Double = 35
    public static let packGroupGapMM: Double = 10
    /// Website honeycomb row factor (`col × 0.8660254`), not recomputed √3/2.
    public static let honeycombRowFactor: Double = 0.8660254

    public static func powerToWatts(_ power: Double, unit: EbikePowerUnit) -> Double {
        switch unit {
        case .watts: return power
        case .kilowatts: return power * 1000
        case .horsepower: return power * wattsPerHorsepower
        }
    }

    public static func newtonMetresToPoundFeet(_ newtonMetres: Double) -> Double {
        newtonMetres * poundFeetPerNewtonMetre
    }

    /// `mph = rpm × π × (diam_in / 12) × 60 / 5280`.
    public static func wheelSpeedMilesPerHour(outputRPM: Double, wheelDiameterInches: Double) -> Double? {
        guard outputRPM.isFinite, outputRPM > 0, wheelDiameterInches.isFinite, wheelDiameterInches > 0 else {
            return nil
        }
        let diameterFeet = wheelDiameterInches / 12
        let circumferenceFeet = Double.pi * diameterFeet
        return outputRPM * circumferenceFeet * 60 / 5280
    }

    public static func roundHalfAwayFromZero(_ value: Double) -> Int {
        Int(value.rounded(.toNearestOrAwayFromZero))
    }
}

public enum EbikePowerUnit: String, CaseIterable, Sendable, Hashable {
    case kilowatts
    case watts
    case horsepower
}

public enum EbikeTorqueSolve: String, CaseIterable, Sendable, Hashable {
    case torque
    case rpm
}

public struct EbikeTorqueRPMResult: Equatable, Sendable {
    public var powerWatts: Double
    public var rpm: Double
    public var torqueNewtonMetres: Double
    public var torquePoundFeet: Double
    public var solved: EbikeTorqueSolve

    public init(
        powerWatts: Double,
        rpm: Double,
        torqueNewtonMetres: Double,
        torquePoundFeet: Double,
        solved: EbikeTorqueSolve
    ) {
        self.powerWatts = powerWatts
        self.rpm = rpm
        self.torqueNewtonMetres = torqueNewtonMetres
        self.torquePoundFeet = torquePoundFeet
        self.solved = solved
    }
}

/// `P(W) = T(N·m) × 2π × RPM / 60` — website `calcEbTorqueRpm`.
public enum EbikeTorqueRPM {
    public static func solve(
        power: Double,
        unit: EbikePowerUnit,
        solveFor: EbikeTorqueSolve,
        rpm: Double = .nan,
        torqueNewtonMetres: Double = .nan
    ) throws -> EbikeTorqueRPMResult {
        let watts = try Positive.require(EbikeMath.powerToWatts(power, unit: unit), name: "Power")
        switch solveFor {
        case .torque:
            let speed = try Positive.require(rpm, name: "RPM")
            let torque = watts * 60 / (2 * Double.pi * speed)
            return EbikeTorqueRPMResult(
                powerWatts: watts,
                rpm: speed,
                torqueNewtonMetres: torque,
                torquePoundFeet: EbikeMath.newtonMetresToPoundFeet(torque),
                solved: .torque
            )
        case .rpm:
            let torque = try Positive.require(torqueNewtonMetres, name: "Torque")
            let speed = watts * 60 / (2 * Double.pi * torque)
            return EbikeTorqueRPMResult(
                powerWatts: watts,
                rpm: speed,
                torqueNewtonMetres: torque,
                torquePoundFeet: EbikeMath.newtonMetresToPoundFeet(torque),
                solved: .rpm
            )
        }
    }
}

public struct EbikeSprocketRatioResult: Equatable, Sendable {
    public var ratio: Double
    public var outputRPM: Double
    public var outputTorqueNewtonMetres: Double
    public var outputTorquePoundFeet: Double
    public var inputMechanicalWatts: Double
    public var wheelSpeedMilesPerHour: Double?

    public init(
        ratio: Double,
        outputRPM: Double,
        outputTorqueNewtonMetres: Double,
        outputTorquePoundFeet: Double,
        inputMechanicalWatts: Double,
        wheelSpeedMilesPerHour: Double?
    ) {
        self.ratio = ratio
        self.outputRPM = outputRPM
        self.outputTorqueNewtonMetres = outputTorqueNewtonMetres
        self.outputTorquePoundFeet = outputTorquePoundFeet
        self.inputMechanicalWatts = inputMechanicalWatts
        self.wheelSpeedMilesPerHour = wheelSpeedMilesPerHour
    }
}

public struct EbikeTargetSprocketResult: Equatable, Sendable {
    public var rpmRatio: Double?
    public var rpmDrivenTeeth: Double?
    public var rpmDrivenTeethRounded: Int?
    public var torqueRatio: Double?
    public var torqueDrivenTeeth: Double?
    public var torqueDrivenTeethRounded: Int?

    public init(
        rpmRatio: Double? = nil,
        rpmDrivenTeeth: Double? = nil,
        rpmDrivenTeethRounded: Int? = nil,
        torqueRatio: Double? = nil,
        torqueDrivenTeeth: Double? = nil,
        torqueDrivenTeethRounded: Int? = nil
    ) {
        self.rpmRatio = rpmRatio
        self.rpmDrivenTeeth = rpmDrivenTeeth
        self.rpmDrivenTeethRounded = rpmDrivenTeethRounded
        self.torqueRatio = torqueRatio
        self.torqueDrivenTeeth = torqueDrivenTeeth
        self.torqueDrivenTeethRounded = torqueDrivenTeethRounded
    }
}

/// Website `calcEbSprocket` / `calcEbTargetSprocket`.
public enum EbikeSprocket {
    public static func ratio(
        motorRPM: Double,
        motorTorqueNewtonMetres: Double,
        driveTeeth: Double,
        drivenTeeth: Double,
        efficiencyPercent: Double,
        wheelDiameterInches: Double? = nil
    ) throws -> EbikeSprocketRatioResult {
        let rpm = try Positive.require(motorRPM, name: "Motor RPM")
        let torque = try Positive.require(motorTorqueNewtonMetres, name: "Motor torque")
        let drive = try Positive.require(driveTeeth, name: "Drive sprocket teeth")
        let driven = try Positive.require(drivenTeeth, name: "Driven sprocket teeth")
        let efficiency = try efficiencyFraction(efficiencyPercent)

        let ratio = driven / drive
        let outputRPM = rpm / ratio
        let outputTorque = torque * ratio * efficiency
        let inputWatts = torque * rpm * 2 * Double.pi / 60
        let speed = EbikeMath.wheelSpeedMilesPerHour(
            outputRPM: outputRPM,
            wheelDiameterInches: wheelDiameterInches ?? .nan
        )

        return EbikeSprocketRatioResult(
            ratio: ratio,
            outputRPM: outputRPM,
            outputTorqueNewtonMetres: outputTorque,
            outputTorquePoundFeet: EbikeMath.newtonMetresToPoundFeet(outputTorque),
            inputMechanicalWatts: inputWatts,
            wheelSpeedMilesPerHour: speed
        )
    }

    public static func target(
        motorRPM: Double,
        motorTorqueNewtonMetres: Double,
        driveTeeth: Double,
        efficiencyPercent: Double,
        targetOutputRPM: Double? = nil,
        targetOutputTorqueNewtonMetres: Double? = nil
    ) throws -> EbikeTargetSprocketResult {
        let rpm = try Positive.require(motorRPM, name: "Motor RPM")
        let torque = try Positive.require(motorTorqueNewtonMetres, name: "Motor torque")
        let drive = try Positive.require(driveTeeth, name: "Drive sprocket teeth")
        let efficiency = try efficiencyFraction(efficiencyPercent)

        var result = EbikeTargetSprocketResult()
        if let targetRPM = targetOutputRPM, targetRPM.isFinite, targetRPM > 0 {
            let ratio = rpm / targetRPM
            let teeth = drive * ratio
            result.rpmRatio = ratio
            result.rpmDrivenTeeth = teeth
            result.rpmDrivenTeethRounded = EbikeMath.roundHalfAwayFromZero(teeth)
        }
        if let targetTorque = targetOutputTorqueNewtonMetres, targetTorque.isFinite, targetTorque > 0 {
            let ratio = targetTorque / (torque * efficiency)
            let teeth = drive * ratio
            result.torqueRatio = ratio
            result.torqueDrivenTeeth = teeth
            result.torqueDrivenTeethRounded = EbikeMath.roundHalfAwayFromZero(teeth)
        }
        guard result.rpmRatio != nil || result.torqueRatio != nil else {
            throw CalcError.outOfRange("Enter a target RPM and/or target torque greater than zero.")
        }
        return result
    }

    private static func efficiencyFraction(_ percent: Double) throws -> Double {
        guard percent.isFinite, percent > 0, percent <= 100 else {
            throw CalcError.outOfRange("Drivetrain efficiency is between 0 and 100 %.")
        }
        return percent / 100
    }
}

public struct EbikeRangeResult: Equatable, Sendable {
    public var batteryWattHours: Double
    public var miles: Double
    public var kilometers: Double
    public var runtimeHours: Double
    public var impliedMilesPerHour: Double

    public init(
        batteryWattHours: Double,
        miles: Double,
        kilometers: Double,
        runtimeHours: Double,
        impliedMilesPerHour: Double
    ) {
        self.batteryWattHours = batteryWattHours
        self.miles = miles
        self.kilometers = kilometers
        self.runtimeHours = runtimeHours
        self.impliedMilesPerHour = impliedMilesPerHour
    }
}

/// Website `calcEbRange` — pack V×Ah / Wh/mi, no DoD or Peukert.
public enum EbikeRange {
    public static func estimate(
        batteryVolts: Double,
        batteryAmpHours: Double,
        wattHoursPerMile: Double,
        averagePowerWatts: Double
    ) throws -> EbikeRangeResult {
        let volts = try Positive.require(batteryVolts, name: "Battery voltage")
        let ampHours = try Positive.require(batteryAmpHours, name: "Battery capacity")
        let consumption = try Positive.require(wattHoursPerMile, name: "Consumption")
        let power = try Positive.require(averagePowerWatts, name: "Average power")

        let wattHours = volts * ampHours
        let miles = wattHours / consumption
        let hours = wattHours / power
        return EbikeRangeResult(
            batteryWattHours: wattHours,
            miles: miles,
            kilometers: miles * EbikeMath.milesToKilometers,
            runtimeHours: hours,
            impliedMilesPerHour: miles / hours
        )
    }
}

public struct EbikePackAnalyzeResult: Equatable, Sendable {
    public var series: Int
    public var parallel: Int
    public var cellCount: Int
    public var nominalVolts: Double
    public var maxVolts: Double
    public var capacityAmpHours: Double
    public var energyWattHours: Double
    public var packContinuousAmps: Double
    public var perCellLoadAmps: Double?
    public var cRate: Double?
    public var loadOk: Bool

    public init(
        series: Int,
        parallel: Int,
        cellCount: Int,
        nominalVolts: Double,
        maxVolts: Double,
        capacityAmpHours: Double,
        energyWattHours: Double,
        packContinuousAmps: Double,
        perCellLoadAmps: Double?,
        cRate: Double?,
        loadOk: Bool
    ) {
        self.series = series
        self.parallel = parallel
        self.cellCount = cellCount
        self.nominalVolts = nominalVolts
        self.maxVolts = maxVolts
        self.capacityAmpHours = capacityAmpHours
        self.energyWattHours = energyWattHours
        self.packContinuousAmps = packContinuousAmps
        self.perCellLoadAmps = perCellLoadAmps
        self.cRate = cRate
        self.loadOk = loadOk
    }

    public var architecture: String { "\(series)S\(parallel)P" }
}

public enum EbikePackPattern: String, CaseIterable, Sendable, Hashable {
    case grid
    case honeycomb
}

public struct EbikePackPlanResult: Equatable, Sendable {
    public var series: Int
    public var parallel: Int
    public var cellCount: Int
    public var nominalVolts: Double
    public var maxVolts: Double
    public var requiredAmps: Double
    public var capacityAmpHours: Double
    public var energyWattHours: Double
    public var perCellAmps: Double
    public var cRate: Double
    public var packCapabilityAmps: Double
    public var loadOk: Bool
    public var cellsPerRow: Int
    public var rows: Int
    public var columnPitchMM: Double
    public var rowPitchMM: Double
    public var envelopeWidthMM: Double
    public var envelopeHeightMM: Double
    public var spaceLimited: Bool
    public var geometryImpossible: Bool
    public var enclosureHeadroomCells: Int?
    public var minHeightNeededMM: Double?
    public var requiredParallel: Int
    public var packMassKilograms: Double?
    public var energyDensityWhPerKg: Double?
    public var cellLengthMM: Double?

    public init(
        series: Int,
        parallel: Int,
        cellCount: Int,
        nominalVolts: Double,
        maxVolts: Double,
        requiredAmps: Double,
        capacityAmpHours: Double,
        energyWattHours: Double,
        perCellAmps: Double,
        cRate: Double,
        packCapabilityAmps: Double,
        loadOk: Bool,
        cellsPerRow: Int,
        rows: Int,
        columnPitchMM: Double,
        rowPitchMM: Double,
        envelopeWidthMM: Double,
        envelopeHeightMM: Double,
        spaceLimited: Bool,
        geometryImpossible: Bool,
        enclosureHeadroomCells: Int?,
        minHeightNeededMM: Double?,
        requiredParallel: Int,
        packMassKilograms: Double?,
        energyDensityWhPerKg: Double?,
        cellLengthMM: Double?
    ) {
        self.series = series
        self.parallel = parallel
        self.cellCount = cellCount
        self.nominalVolts = nominalVolts
        self.maxVolts = maxVolts
        self.requiredAmps = requiredAmps
        self.capacityAmpHours = capacityAmpHours
        self.energyWattHours = energyWattHours
        self.perCellAmps = perCellAmps
        self.cRate = cRate
        self.packCapabilityAmps = packCapabilityAmps
        self.loadOk = loadOk
        self.cellsPerRow = cellsPerRow
        self.rows = rows
        self.columnPitchMM = columnPitchMM
        self.rowPitchMM = rowPitchMM
        self.envelopeWidthMM = envelopeWidthMM
        self.envelopeHeightMM = envelopeHeightMM
        self.spaceLimited = spaceLimited
        self.geometryImpossible = geometryImpossible
        self.enclosureHeadroomCells = enclosureHeadroomCells
        self.minHeightNeededMM = minHeightNeededMM
        self.requiredParallel = requiredParallel
        self.packMassKilograms = packMassKilograms
        self.energyDensityWhPerKg = energyDensityWhPerKg
        self.cellLengthMM = cellLengthMM
    }

    public var architecture: String { "\(series)S\(parallel)P" }
}

/// Series/parallel pack planning — website Battery Pack Designer `analyzeLayout`
/// (balanced S×P) plus 18650 planner `calc18650Pack`. Not Battery Bank runtime/DoD.
public enum EbikePack {
    /// Balanced S×P electricals from the visual pack designer (`analyzeLayout`).
    public static func analyze(
        seriesCount: Double,
        parallelCount: Double,
        cellVolts: Double,
        cellAmpHours: Double,
        cellContinuousAmps: Double,
        loadAmps: Double? = nil
    ) throws -> EbikePackAnalyzeResult {
        let series = try WholeCount.parse(seriesCount, name: "Series count")
        let parallel = try WholeCount.parse(parallelCount, name: "Parallel count")
        let cellV = try Positive.require(cellVolts, name: "Cell voltage")
        let cellAh = try Positive.require(cellAmpHours, name: "Cell capacity")
        let cellA = try Positive.require(cellContinuousAmps, name: "Cell continuous current")

        let nominal = Double(series) * cellV
        let capacity = Double(parallel) * cellAh
        let load: Double?
        if let loadAmps, loadAmps.isFinite, loadAmps > 0 {
            load = loadAmps
        } else {
            load = nil
        }
        let perCell = load.map { $0 / Double(parallel) }
        let crate = perCell.map { $0 / cellAh }
        let loadOk = perCell.map { $0 <= cellA } ?? true

        return EbikePackAnalyzeResult(
            series: series,
            parallel: parallel,
            cellCount: series * parallel,
            nominalVolts: nominal,
            maxVolts: Double(series) * EbikeMath.lithiumCellMaxVolts,
            capacityAmpHours: capacity,
            energyWattHours: nominal * capacity,
            packContinuousAmps: Double(parallel) * cellA,
            perCellLoadAmps: perCell,
            cRate: crate,
            loadOk: loadOk
        )
    }

    /// Target voltage + current/power → recommended S×P (`calc18650Pack`).
    public static func plan(
        targetVolts: Double,
        continuousAmps: Double? = nil,
        continuousWatts: Double? = nil,
        cellVolts: Double,
        cellAmpHours: Double,
        cellContinuousAmps: Double,
        cellDiameterMM: Double? = nil,
        cellLengthMM: Double? = nil,
        cellMassGrams: Double? = nil,
        enclosureWidthMM: Double? = nil,
        enclosureHeightMM: Double? = nil,
        pattern: EbikePackPattern = .honeycomb
    ) throws -> EbikePackPlanResult {
        let targetV = try Positive.require(targetVolts, name: "Pack voltage")
        let cellV = try Positive.require(cellVolts, name: "Cell voltage")
        let cellAh = try Positive.require(cellAmpHours, name: "Cell capacity")
        let cellA = try Positive.require(cellContinuousAmps, name: "Cell continuous current")

        let current = positiveOrNil(continuousAmps)
        let power = positiveOrNil(continuousWatts)
        guard current != nil || power != nil else {
            throw CalcError.outOfRange("Enter a continuous current and/or continuous power greater than zero.")
        }

        let series = max(1, EbikeMath.roundHalfAwayFromZero(targetV / cellV))
        let nominal = Double(series) * cellV
        let required = max(current ?? 0, power.map { $0 / nominal } ?? 0)
        guard required > 0 else {
            throw CalcError.outOfRange("Enter a continuous current and/or continuous power greater than zero.")
        }
        let requiredParallel = max(1, Int(ceil(required / cellA)))

        let diameter = positiveOrNil(cellDiameterMM)
        let maxW = positiveOrNil(enclosureWidthMM)
        let maxH = positiveOrNil(enclosureHeightMM)
        let honeycomb = pattern == .honeycomb

        var parallel = requiredParallel
        var perRow = max(1, Int(ceil(sqrt(Double(parallel)))))
        var rows = Int(ceil(Double(parallel) / Double(perRow)))
        var spaceLimited = false
        var geometryImpossible = false
        var headroom: Int?
        var minHeight: Double?
        var colPitch = (diameter ?? 0) + EbikeMath.packClearanceMM
        var rowPitch = honeycomb ? colPitch * EbikeMath.honeycombRowFactor : colPitch

        if let diameter, let maxW, let maxH {
            colPitch = diameter + EbikeMath.packClearanceMM
            rowPitch = honeycomb ? colPitch * EbikeMath.honeycombRowFactor : colPitch
            let groupBudget = (maxW - EbikeMath.packMarginWidthMM) / Double(series) - EbikeMath.packGroupGapMM
            let geomPerRow = max(0, Int(floor(groupBudget / colPitch)))
            let geomRows = max(0, Int(floor((maxH - EbikeMath.packMarginHeightMM) / rowPitch)))
            if geomPerRow > 0 && geomRows > 0 {
                let parallelGeom = geomPerRow * geomRows
                parallel = min(requiredParallel, parallelGeom)
                spaceLimited = parallelGeom < requiredParallel
                rows = min(geomRows, max(1, Int(ceil(Double(parallel) / Double(geomPerRow)))))
                perRow = min(geomPerRow, max(1, Int(ceil(Double(parallel) / Double(rows)))))
                if spaceLimited {
                    minHeight = ceil(Double(requiredParallel) / Double(geomPerRow)) * rowPitch + EbikeMath.packMarginHeightMM
                } else {
                    headroom = parallelGeom - parallel
                }
            } else {
                geometryImpossible = true
            }
        } else if let diameter {
            colPitch = diameter + EbikeMath.packClearanceMM
            rowPitch = honeycomb ? colPitch * EbikeMath.honeycombRowFactor : colPitch
        }

        let capacity = Double(parallel) * cellAh
        let wattHours = nominal * capacity
        let cellCurrent = required / Double(parallel)
        let packW = Double(series) * (Double(perRow) * colPitch + EbikeMath.packGroupGapMM) - EbikeMath.packGroupGapMM
        let packH = max(0, Double(rows - 1)) * rowPitch + colPitch
        let massKg: Double?
        if let grams = positiveOrNil(cellMassGrams) {
            massKg = Double(series * parallel) * grams / 1000
        } else {
            massKg = nil
        }

        return EbikePackPlanResult(
            series: series,
            parallel: parallel,
            cellCount: series * parallel,
            nominalVolts: nominal,
            maxVolts: Double(series) * EbikeMath.lithiumCellMaxVolts,
            requiredAmps: required,
            capacityAmpHours: capacity,
            energyWattHours: wattHours,
            perCellAmps: cellCurrent,
            cRate: cellCurrent / cellAh,
            packCapabilityAmps: Double(parallel) * cellA,
            loadOk: cellCurrent <= cellA,
            cellsPerRow: perRow,
            rows: rows,
            columnPitchMM: colPitch,
            rowPitchMM: rowPitch,
            envelopeWidthMM: packW,
            envelopeHeightMM: packH,
            spaceLimited: spaceLimited,
            geometryImpossible: geometryImpossible,
            enclosureHeadroomCells: headroom,
            minHeightNeededMM: minHeight,
            requiredParallel: requiredParallel,
            packMassKilograms: massKg,
            energyDensityWhPerKg: massKg.map { wattHours / $0 },
            cellLengthMM: positiveOrNil(cellLengthMM)
        )
    }

    private static func positiveOrNil(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}

public struct NickelStripResult: Equatable, Sendable {
    public var widthMM: Double
    public var thicknessMM: Double
    public var crossSectionMM2: Double
    public var continuousAmps: Double
    public var pulseAmps: Double
    public var continuousDensity: Double
    public var pulseDensity: Double

    public init(
        widthMM: Double,
        thicknessMM: Double,
        crossSectionMM2: Double,
        continuousAmps: Double,
        pulseAmps: Double,
        continuousDensity: Double,
        pulseDensity: Double
    ) {
        self.widthMM = widthMM
        self.thicknessMM = thicknessMM
        self.crossSectionMM2 = crossSectionMM2
        self.continuousAmps = continuousAmps
        self.pulseAmps = pulseAmps
        self.continuousDensity = continuousDensity
        self.pulseDensity = pulseDensity
    }
}

public struct NickelStripSize: Equatable, Sendable, Identifiable {
    public var widthMM: Double
    public var thicknessMM: Double
    public var id: String { "\(widthMM)x\(thicknessMM)" }

    public init(widthMM: Double, thicknessMM: Double) {
        self.widthMM = widthMM
        self.thicknessMM = thicknessMM
    }
}

/// Website `calcNickelStrip` — `I = width × thickness × current density`.
public enum NickelStrip {
    /// Common sizes listed on the website strip table.
    public static let commonSizes: [NickelStripSize] = [
        NickelStripSize(widthMM: 6, thicknessMM: 0.1),
        NickelStripSize(widthMM: 8, thicknessMM: 0.1),
        NickelStripSize(widthMM: 6, thicknessMM: 0.15),
        NickelStripSize(widthMM: 8, thicknessMM: 0.15),
        NickelStripSize(widthMM: 10, thicknessMM: 0.15),
        NickelStripSize(widthMM: 8, thicknessMM: 0.2),
        NickelStripSize(widthMM: 10, thicknessMM: 0.2),
    ]

    public static func size(
        widthMM: Double,
        thicknessMM: Double,
        continuousDensity: Double,
        pulseDensity: Double
    ) throws -> NickelStripResult {
        let width = try Positive.require(widthMM, name: "Strip width")
        let thickness = try Positive.require(thicknessMM, name: "Strip thickness")
        let continuousJ = try Positive.require(continuousDensity, name: "Continuous density")
        let pulseJ = try Positive.require(pulseDensity, name: "Pulse density")
        let area = width * thickness
        return NickelStripResult(
            widthMM: width,
            thicknessMM: thickness,
            crossSectionMM2: area,
            continuousAmps: area * continuousJ,
            pulseAmps: area * pulseJ,
            continuousDensity: continuousJ,
            pulseDensity: pulseJ
        )
    }
}
