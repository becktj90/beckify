import SwiftUI
import BeckifyMath

// MARK: - E-Bike Torque / RPM

struct EbikeTorqueRPMView: View {
    enum Solve: String, CaseIterable, Identifiable {
        case torque = "Torque"
        case rpm = "RPM"
        var id: String { rawValue }
        var math: EbikeTorqueSolve { self == .torque ? .torque : .rpm }
    }

    enum PowerUnit: String, CaseIterable, Identifiable {
        case kilowatts = "kW"
        case watts = "W"
        case horsepower = "hp"
        var id: String { rawValue }
        var math: EbikePowerUnit {
            switch self {
            case .kilowatts: return .kilowatts
            case .watts: return .watts
            case .horsepower: return .horsepower
            }
        }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.eBikeTorqueRPM, "solve", default: Solve.torque) private var solve
    @StoredChoice(.eBikeTorqueRPM, "unit", default: PowerUnit.kilowatts) private var unit
    @StoredInput(.eBikeTorqueRPM, "power", default: "2") private var power
    @StoredInput(.eBikeTorqueRPM, "rpm", default: "3200") private var rpm
    @StoredInput(.eBikeTorqueRPM, "torque", default: "6") private var torque
    @StoredInput(.eBikeTorqueRPM, "jobName", default: "E-bike torque") private var jobName
    @State private var session = ExplicitCalculationState<EbikeTorqueRPMResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(solve)|\(unit)|\(power)|\(rpm)|\(torque)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .eBikeTorqueRPM,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .eBikeTorqueRPM,
                symbolic: "P(W) = T(N·m) × 2π × RPM / 60",
                substituted: substituted,
                meaning: "Same shaft identity as an industrial motor. Solve torque at a known RPM, or RPM at a known torque. Horsepower here is mechanical 746 W — not a controller rating."
            )
            TryExampleButton(title: "2 kW hub at 3200 RPM") {
                applyExample()
                session.prepareForNewInputs()
            }

            MenuField(title: "Solve for", selection: $solve, options: Solve.allCases) { $0.rawValue }
            MenuField(title: "Power unit", selection: $unit, options: PowerUnit.allCases) { $0.rawValue }
            NumberField(title: "Power", unit: unit.rawValue, text: $power, fieldID: "power", onSubmit: calculate)
            if solve == .torque {
                NumberField(title: "RPM", unit: "rpm", text: $rpm, fieldID: "rpm", onSubmit: calculate)
            } else {
                NumberField(title: "Torque", unit: "N·m", text: $torque, fieldID: "torque", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    applyExample()
                    session.prepareForNewInputs()
                },
                exampleTitle: "2 kW @ 3200 rpm"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Power", value: Format.watts(r.powerWatts))
                    ResultRow(label: "RPM", value: "\(Format.number(r.rpm, digits: 2)) rpm", emphasis: r.solved == .rpm, tone: r.solved == .rpm ? Theme.good : Theme.foreground)
                    ResultRow(
                        label: "Torque",
                        value: "\(Format.number(r.torqueNewtonMetres, digits: 3)) N·m  ·  \(Format.number(r.torquePoundFeet, digits: 3)) lb-ft",
                        emphasis: r.solved == .torque,
                        tone: r.solved == .torque ? Theme.good : Theme.foreground
                    )
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func applyExample() {
        solve = .torque
        unit = .kilowatts
        power = "2"
        rpm = "3200"
        torque = "6"
    }

    private func calculate() {
        session.calculate {
            try EbikeTorqueRPM.solve(
                power: power.parsedDouble ?? .nan,
                unit: unit.math,
                solveFor: solve.math,
                rpm: rpm.parsedDouble ?? .nan,
                torqueNewtonMetres: torque.parsedDouble ?? .nan
            )
        }
        tickSuccess()
    }

    private func reset() {
        power = ""; rpm = ""; torque = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        if r.solved == .torque {
            return "T = \(Format.number(r.powerWatts, digits: 1)) × 60 / (2π × \(Format.number(r.rpm, digits: 1))) = \(Format.number(r.torqueNewtonMetres, digits: 3)) N·m"
        }
        return "RPM = \(Format.number(r.powerWatts, digits: 1)) × 60 / (2π × \(Format.number(r.torqueNewtonMetres, digits: 3))) = \(Format.number(r.rpm, digits: 2))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        if r.solved == .torque {
            return "\(Format.number(r.torqueNewtonMetres, digits: 3)) N·m  ·  \(Format.number(r.torquePoundFeet, digits: 3)) lb-ft"
        }
        return "\(Format.number(r.rpm, digits: 2)) rpm"
    }

    private func save(_ r: EbikeTorqueRPMResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .eBikeTorqueRPM,
            inputs: ["P": "\(power) \(unit.rawValue)", "solve": solve.rawValue],
            outputs: [
                "torque": "\(Format.number(r.torqueNewtonMetres, digits: 3)) N·m",
                "rpm": "\(Format.number(r.rpm, digits: 2)) rpm",
            ]
        ))
    }

    private func tickSuccess() {
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }
}

// MARK: - Sprocket Ratio Designer

struct EbikeSprocketView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case ratio = "Ratio"
        case target = "Target size"
        var id: String { rawValue }
    }

    private enum Output: Equatable {
        case ratio(EbikeSprocketRatioResult)
        case target(EbikeTargetSprocketResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.eBikeSprocket, "mode", default: Mode.ratio) private var mode
    @StoredInput(.eBikeSprocket, "motorRPM", default: "3200") private var motorRPM
    @StoredInput(.eBikeSprocket, "motorTorque", default: "6") private var motorTorque
    @StoredInput(.eBikeSprocket, "driveTeeth", default: "14") private var driveTeeth
    @StoredInput(.eBikeSprocket, "drivenTeeth", default: "56") private var drivenTeeth
    @StoredInput(.eBikeSprocket, "efficiency", default: "92") private var efficiency
    @StoredInput(.eBikeSprocket, "wheelDiam", default: "26") private var wheelDiam
    @StoredInput(.eBikeSprocket, "targetRPM", default: "800") private var targetRPM
    @StoredInput(.eBikeSprocket, "targetTorque", default: "20") private var targetTorque
    @StoredInput(.eBikeSprocket, "jobName", default: "Sprocket") private var jobName
    @State private var session = ExplicitCalculationState<Output>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(motorRPM)|\(motorTorque)|\(driveTeeth)|\(drivenTeeth)|\(efficiency)|\(wheelDiam)|\(targetRPM)|\(targetTorque)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .eBikeSprocket,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .eBikeSprocket,
                symbolic: mode == .ratio
                    ? "ratio = driven / drive     n_out = n_motor / ratio     T_out = T_motor · ratio · η"
                    : "ratio_n = n_motor / n_out     ratio_T = T_out / (T_motor · η)",
                substituted: substituted,
                meaning: "Reduction multiplies torque and divides RPM. Efficiency is a planning derate on output torque only — chain wear, alignment, and wheel slip are not in this number. Wheel speed uses circumference from diameter."
            )
            TryExampleButton(title: "14T / 56T, 26 in wheel") {
                applyExample()
                session.prepareForNewInputs()
            }

            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }
            NumberField(title: "Motor RPM", unit: "rpm", text: $motorRPM, fieldID: "motorRPM", onSubmit: calculate)
            NumberField(title: "Motor torque", unit: "N·m", text: $motorTorque, fieldID: "motorTorque", onSubmit: calculate)
            NumberField(title: "Drive sprocket", unit: "teeth", text: $driveTeeth, fieldID: "driveTeeth", onSubmit: calculate)
            if mode == .ratio {
                NumberField(title: "Driven sprocket", unit: "teeth", text: $drivenTeeth, fieldID: "drivenTeeth", onSubmit: calculate)
                NumberField(title: "Drivetrain efficiency", unit: "%", text: $efficiency, fieldID: "efficiency", onSubmit: calculate)
                NumberField(title: "Wheel diameter", unit: "in", text: $wheelDiam, optional: true, fieldID: "wheelDiam", onSubmit: calculate)
            } else {
                NumberField(title: "Target output RPM", unit: "rpm", text: $targetRPM, optional: true, fieldID: "targetRPM", onSubmit: calculate)
                NumberField(title: "Target output torque", unit: "N·m", text: $targetTorque, optional: true, fieldID: "targetTorque", onSubmit: calculate)
                NumberField(title: "Drivetrain efficiency", unit: "%", text: $efficiency, fieldID: "efficiency", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    applyExample()
                    session.prepareForNewInputs()
                },
                exampleTitle: mode == .ratio ? "14T/56T" : "800 rpm / 20 N·m"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                switch output {
                case .ratio(let r):
                    ResultCard(copyText: sticky) {
                        ResultRow(label: "Gear ratio (driven/drive)", value: "\(Format.number(r.ratio, digits: 3)):1", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Output RPM", value: "\(Format.number(r.outputRPM, digits: 1)) rpm", emphasis: true)
                        ResultRow(label: "Output torque", value: "\(Format.number(r.outputTorqueNewtonMetres, digits: 3)) N·m  ·  \(Format.number(r.outputTorquePoundFeet, digits: 3)) lb-ft")
                        ResultRow(label: "Input mechanical power", value: Format.watts(r.inputMechanicalWatts))
                        if let mph = r.wheelSpeedMilesPerHour {
                            ResultRow(label: "Estimated wheel speed", value: "\(Format.number(mph, digits: 2)) mph")
                        }
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                case .target(let r):
                    ResultCard(copyText: sticky) {
                        if let ratio = r.rpmRatio, let teeth = r.rpmDrivenTeethRounded {
                            ResultRow(label: "Required ratio for target RPM", value: "\(Format.number(ratio, digits: 3)):1", emphasis: true, tone: Theme.good)
                            ResultRow(label: "Suggested driven teeth (RPM)", value: "\(teeth)")
                        }
                        if let ratio = r.torqueRatio, let teeth = r.torqueDrivenTeethRounded {
                            ResultRow(label: "Required ratio for target torque", value: "\(Format.number(ratio, digits: 3)):1", emphasis: r.rpmRatio == nil, tone: r.rpmRatio == nil ? Theme.good : Theme.foreground)
                            ResultRow(label: "Suggested driven teeth (torque)", value: "\(teeth)")
                        }
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                }
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(output) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func applyExample() {
        motorRPM = "3200"
        motorTorque = "6"
        driveTeeth = "14"
        drivenTeeth = "56"
        efficiency = "92"
        wheelDiam = "26"
        targetRPM = "800"
        targetTorque = "20"
    }

    private func calculate() {
        session.calculate {
            if mode == .ratio {
                return .ratio(try EbikeSprocket.ratio(
                    motorRPM: motorRPM.parsedDouble ?? .nan,
                    motorTorqueNewtonMetres: motorTorque.parsedDouble ?? .nan,
                    driveTeeth: driveTeeth.parsedDouble ?? .nan,
                    drivenTeeth: drivenTeeth.parsedDouble ?? .nan,
                    efficiencyPercent: efficiency.parsedDouble ?? .nan,
                    wheelDiameterInches: wheelDiam.parsedDouble
                ))
            }
            return .target(try EbikeSprocket.target(
                motorRPM: motorRPM.parsedDouble ?? .nan,
                motorTorqueNewtonMetres: motorTorque.parsedDouble ?? .nan,
                driveTeeth: driveTeeth.parsedDouble ?? .nan,
                efficiencyPercent: efficiency.parsedDouble ?? .nan,
                targetOutputRPM: targetRPM.parsedDouble,
                targetOutputTorqueNewtonMetres: targetTorque.parsedDouble
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        motorRPM = ""; motorTorque = ""; driveTeeth = ""; drivenTeeth = ""
        efficiency = ""; wheelDiam = ""; targetRPM = ""; targetTorque = ""
        session.reset()
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .ratio(let r):
            var line = "\(drivenTeeth) / \(driveTeeth) = \(Format.number(r.ratio, digits: 3)):1  →  \(Format.number(r.outputRPM, digits: 1)) rpm, \(Format.number(r.outputTorqueNewtonMetres, digits: 3)) N·m"
            if let mph = r.wheelSpeedMilesPerHour {
                line += "  ·  \(Format.number(mph, digits: 2)) mph"
            }
            return line
        case .target(let r):
            var parts: [String] = []
            if let ratio = r.rpmRatio, let teeth = r.rpmDrivenTeethRounded {
                parts.append("RPM \(Format.number(ratio, digits: 3)):1 → \(teeth)T")
            }
            if let ratio = r.torqueRatio, let teeth = r.torqueDrivenTeethRounded {
                parts.append("torque \(Format.number(ratio, digits: 3)):1 → \(teeth)T")
            }
            return parts.joined(separator: "  ·  ")
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .ratio(let r):
            return "\(Format.number(r.ratio, digits: 3)):1  ·  \(Format.number(r.outputRPM, digits: 1)) rpm"
        case .target(let r):
            if let teeth = r.rpmDrivenTeethRounded {
                return "\(teeth)T driven (RPM target)"
            }
            if let teeth = r.torqueDrivenTeethRounded {
                return "\(teeth)T driven (torque target)"
            }
            return nil
        }
    }

    private func save(_ output: Output) {
        switch output {
        case .ratio(let r):
            jobs.save(SavedJob(
                name: jobName,
                toolID: .eBikeSprocket,
                inputs: ["teeth": "\(driveTeeth)/\(drivenTeeth)", "η": "\(efficiency) %"],
                outputs: ["ratio": "\(Format.number(r.ratio, digits: 3)):1", "out": "\(Format.number(r.outputRPM, digits: 1)) rpm"]
            ))
        case .target(let r):
            jobs.save(SavedJob(
                name: jobName,
                toolID: .eBikeSprocket,
                inputs: ["drive": driveTeeth, "targets": "\(targetRPM) rpm / \(targetTorque) N·m"],
                outputs: [
                    "rpmT": r.rpmDrivenTeethRounded.map { "\($0)" } ?? "—",
                    "torqueT": r.torqueDrivenTeethRounded.map { "\($0)" } ?? "—",
                ]
            ))
        }
    }
}

// MARK: - Range Estimator

struct EbikeRangeView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.eBikeRange, "volts", default: "52") private var volts
    @StoredInput(.eBikeRange, "ampHours", default: "20") private var ampHours
    @StoredInput(.eBikeRange, "whPerMile", default: "28") private var whPerMile
    @StoredInput(.eBikeRange, "avgPower", default: "700") private var avgPower
    @StoredInput(.eBikeRange, "jobName", default: "E-bike range") private var jobName
    @State private var session = ExplicitCalculationState<EbikeRangeResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(volts)|\(ampHours)|\(whPerMile)|\(avgPower)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .eBikeRange,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale,
            disclaimer: .designAidExtra("Real-world range varies with rider mass, grade, wind, tire pressure, assist level, and ambient temperature. This is pack V×Ah / Wh/mi — no depth-of-discharge or Peukert. Use Battery Bank Sizing if you need usable DoD and inverter efficiency.")
        ) {
            ShowWorkCard(
                toolID: .eBikeRange,
                symbolic: "Wh = V · Ah     mi = Wh / (Wh/mi)     t = Wh / P_avg",
                substituted: substituted,
                meaning: "Implied speed is range divided by runtime at the stated average power — algebraically P_avg / (Wh/mi). It is not a GPS speed.",
                referenceTool: .batteryBank
            )
            TryExampleButton(title: "52 V 20 Ah, 28 Wh/mi, 700 W") {
                applyExample()
                session.prepareForNewInputs()
            }

            NumberField(title: "Battery voltage", unit: "V", text: $volts, fieldID: "volts", onSubmit: calculate)
            NumberField(title: "Battery capacity", unit: "Ah", text: $ampHours, fieldID: "ampHours", onSubmit: calculate)
            NumberField(title: "Expected consumption", unit: "Wh/mi", text: $whPerMile, fieldID: "whPerMile", onSubmit: calculate)
            NumberField(title: "Average power draw", unit: "W", text: $avgPower, fieldID: "avgPower", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    applyExample()
                    session.prepareForNewInputs()
                },
                exampleTitle: "52 V 20 Ah"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Battery energy", value: "\(Format.number(r.batteryWattHours, digits: 1)) Wh  ·  \(Format.number(r.batteryWattHours / 1000, digits: 2)) kWh", emphasis: true)
                    ResultRow(label: "Estimated range", value: "\(Format.number(r.miles, digits: 2)) mi  ·  \(Format.number(r.kilometers, digits: 2)) km", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Runtime at avg power", value: "\(Format.number(r.runtimeHours, digits: 2)) h")
                    ResultRow(label: "Avg speed implied", value: "\(Format.number(r.impliedMilesPerHour, digits: 2)) mph")
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func applyExample() {
        volts = "52"; ampHours = "20"; whPerMile = "28"; avgPower = "700"
    }

    private func calculate() {
        session.calculate {
            try EbikeRange.estimate(
                batteryVolts: volts.parsedDouble ?? .nan,
                batteryAmpHours: ampHours.parsedDouble ?? .nan,
                wattHoursPerMile: whPerMile.parsedDouble ?? .nan,
                averagePowerWatts: avgPower.parsedDouble ?? .nan
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        volts = ""; ampHours = ""; whPerMile = ""; avgPower = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(volts) × \(ampHours) = \(Format.number(r.batteryWattHours, digits: 1)) Wh  →  \(Format.number(r.miles, digits: 2)) mi at \(whPerMile) Wh/mi"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.miles, digits: 2)) mi  ·  \(Format.number(r.runtimeHours, digits: 2)) h"
    }

    private func save(_ r: EbikeRangeResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .eBikeRange,
            inputs: ["pack": "\(volts) V / \(ampHours) Ah", "use": "\(whPerMile) Wh/mi"],
            outputs: ["range": "\(Format.number(r.miles, digits: 2)) mi", "runtime": "\(Format.number(r.runtimeHours, digits: 2)) h"]
        ))
    }
}

// MARK: - Battery Pack Designer

struct EbikePackDesignerView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case plan = "Plan from target"
        case check = "Check S×P"
        var id: String { rawValue }
    }

    enum CellPreset: String, CaseIterable, Identifiable {
        case cell18650 = "18650"
        case cell21700 = "21700"
        case custom = "Custom"
        var id: String { rawValue }
    }

    enum Pattern: String, CaseIterable, Identifiable {
        case honeycomb = "Honeycomb"
        case grid = "Grid"
        var id: String { rawValue }
        var math: EbikePackPattern { self == .honeycomb ? .honeycomb : .grid }
    }

    private enum Output: Equatable {
        case plan(EbikePackPlanResult)
        case check(EbikePackAnalyzeResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.eBikePackDesigner, "mode", default: Mode.plan) private var mode
    @StoredChoice(.eBikePackDesigner, "pattern", default: Pattern.honeycomb) private var pattern
    @StoredInput(.eBikePackDesigner, "targetV", default: "36") private var targetV
    @StoredInput(.eBikePackDesigner, "current", default: "20") private var current
    @StoredInput(.eBikePackDesigner, "power", default: "") private var power
    @StoredInput(.eBikePackDesigner, "series", default: "14") private var series
    @StoredInput(.eBikePackDesigner, "parallel", default: "10") private var parallel
    @StoredInput(.eBikePackDesigner, "cellV", default: "3.6") private var cellV
    @StoredInput(.eBikePackDesigner, "cellAh", default: "2.5") private var cellAh
    @StoredInput(.eBikePackDesigner, "cellA", default: "20") private var cellA
    @StoredInput(.eBikePackDesigner, "loadA", default: "40") private var loadA
    @StoredInput(.eBikePackDesigner, "diameter", default: "18.5") private var diameter
    @StoredInput(.eBikePackDesigner, "length", default: "65.2") private var length
    @StoredInput(.eBikePackDesigner, "mass", default: "") private var mass
    @StoredInput(.eBikePackDesigner, "encW", default: "") private var encW
    @StoredInput(.eBikePackDesigner, "encH", default: "") private var encH
    @StoredInput(.eBikePackDesigner, "jobName", default: "E-bike pack") private var jobName
    @State private var session = ExplicitCalculationState<Output>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(pattern)|\(targetV)|\(current)|\(power)|\(series)|\(parallel)|\(cellV)|\(cellAh)|\(cellA)|\(loadA)|\(diameter)|\(length)|\(mass)|\(encW)|\(encH)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .eBikePackDesigner,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale,
            disclaimer: .designAidExtra("Planning aid only — not a BMS design, weld certification, or thermal model. Verify the cell datasheet, BMS, fusing, nickel strip or busbar ampacity, and enclosure limits before you build. Battery Bank Sizing covers usable DoD and runtime at a watt load.")
        ) {
            ShowWorkCard(
                toolID: .eBikePackDesigner,
                symbolic: mode == .plan
                    ? "S ≈ round(V / V_cell)     P = ceil(I_req / I_cell)     I_req = max(I, P_W / V_nom)"
                    : "V = S · V_cell     Ah = P · Ah_cell     I_pack = P · I_cell     V_max = S · 4.2",
                substituted: substituted,
                meaning: "Series adds voltage; parallel adds amp-hours and current share. Charge ceiling is S × 4.2 V for typical Li-ion — confirm the cell chemistry. This is not the Battery Bank runtime tool.",
                referenceTool: .batteryBank
            )
            TryExampleButton(title: mode == .plan ? "36 V, 20 A, 18650" : "52 V · 14S10P 18650") {
                applyExample()
                session.prepareForNewInputs()
            }

            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }

            ThumbButtonRow {
                ForEach(CellPreset.allCases) { preset in
                    Button(preset.rawValue) { applyCellPreset(preset) }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                }
            }

            if mode == .check {
                ThumbButtonRow {
                    Button("36 V 10S10P") { series = "10"; parallel = "10" }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                    Button("48 V 13S8P") { series = "13"; parallel = "8" }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                    Button("52 V 14S10P") { series = "14"; parallel = "10" }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                    Button("72 V 20S10P") { series = "20"; parallel = "10" }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                }
            }

            if mode == .plan {
                NumberField(title: "Nominal pack voltage", unit: "V", text: $targetV, fieldID: "targetV", onSubmit: calculate)
                NumberField(title: "Continuous current", unit: "A", text: $current, optional: true, fieldID: "current", onSubmit: calculate)
                NumberField(title: "Continuous power", unit: "W", text: $power, optional: true, fieldID: "power", onSubmit: calculate)
            } else {
                NumberField(title: "Series count", unit: "S", text: $series, fieldID: "series", onSubmit: calculate)
                NumberField(title: "Parallel count", unit: "P", text: $parallel, fieldID: "parallel", onSubmit: calculate)
                NumberField(title: "Pack load current", unit: "A", text: $loadA, optional: true, fieldID: "loadA", onSubmit: calculate)
            }

            NumberField(title: "Cell voltage", unit: "V", text: $cellV, fieldID: "cellV", onSubmit: calculate)
            NumberField(title: "Cell capacity", unit: "Ah", text: $cellAh, fieldID: "cellAh", onSubmit: calculate)
            NumberField(title: "Cell continuous current", unit: "A", text: $cellA, fieldID: "cellA", onSubmit: calculate)

            if mode == .plan {
                MenuField(title: "Packing", selection: $pattern, options: Pattern.allCases) { $0.rawValue }
                NumberField(title: "Cell diameter", unit: "mm", text: $diameter, optional: true, fieldID: "diameter", onSubmit: calculate)
                NumberField(title: "Cell length", unit: "mm", text: $length, optional: true, fieldID: "length", onSubmit: calculate)
                NumberField(title: "Cell mass", unit: "g", text: $mass, optional: true, fieldID: "mass", onSubmit: calculate)
                NumberField(title: "Enclosure width", unit: "mm", text: $encW, optional: true, fieldID: "encW", onSubmit: calculate)
                NumberField(title: "Enclosure height", unit: "mm", text: $encH, optional: true, fieldID: "encH", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    applyExample()
                    session.prepareForNewInputs()
                },
                exampleTitle: mode == .plan ? "36 V 20 A" : "14S10P"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                switch output {
                case .plan(let r):
                    ResultCard(copyText: sticky) {
                        ResultRow(label: "Architecture", value: "\(r.architecture)  ·  \(r.cellCount) cells", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Nominal / max voltage", value: "\(Format.volts(r.nominalVolts))  /  \(Format.volts(r.maxVolts))")
                        ResultRow(label: "Required current", value: Format.amps(r.requiredAmps))
                        ResultRow(label: "Per-cell current / C-rate", value: "\(Format.amps(r.perCellAmps))  ·  \(Format.number(r.cRate, digits: 2)) C", tone: r.loadOk ? Theme.good : Theme.bad)
                        ResultRow(label: "Pack capacity / energy", value: "\(Format.number(r.capacityAmpHours, digits: 1)) Ah  /  \(Format.number(r.energyWattHours, digits: 0)) Wh")
                        ResultRow(label: "Pack capability (cell limit)", value: Format.amps(r.packCapabilityAmps))
                        if r.columnPitchMM > 0 {
                            ResultRow(label: "String layout", value: "\(r.cellsPerRow) × \(r.rows)  ·  \(pattern.rawValue.lowercased()) \(Format.number(r.columnPitchMM, digits: 1)) × \(Format.number(r.rowPitchMM, digits: 1)) mm")
                            let lengthNote = r.cellLengthMM.map { "; cell length \(Format.number($0, digits: 1)) mm" } ?? ""
                            ResultRow(label: "Layout envelope", value: "≈ \(Format.number(r.envelopeWidthMM, digits: 0)) × \(Format.number(r.envelopeHeightMM, digits: 0)) mm\(lengthNote)")
                        }
                        if r.geometryImpossible {
                            ResultRow(label: "Enclosure check", value: "Too small for \(r.series) series string(s) at this diameter.", tone: Theme.bad)
                        } else if r.spaceLimited {
                            let need = r.minHeightNeededMM.map { Format.number($0, digits: 0) } ?? "—"
                            ResultRow(label: "Enclosure check", value: "Space-limited to \(r.parallel)P — target needs \(r.requiredParallel)P. Grow height to ≈\(need) mm or accept this Ah.", tone: Theme.warn)
                        } else if let headroom = r.enclosureHeadroomCells {
                            ResultRow(label: "Enclosure check", value: "Fits, with \(headroom) cell slot(s) of headroom.", tone: Theme.good)
                        }
                        if let massKg = r.packMassKilograms, let density = r.energyDensityWhPerKg {
                            ResultRow(label: "Estimated pack mass", value: "\(Format.number(massKg, digits: 2)) kg (cells only)")
                            ResultRow(label: "Energy density (cells)", value: "\(Format.number(density, digits: 0)) Wh/kg")
                        }
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                case .check(let r):
                    ResultCard(copyText: sticky) {
                        ResultRow(label: "Architecture", value: "\(r.architecture)  ·  \(r.cellCount) cells", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Nominal / max voltage", value: "\(Format.volts(r.nominalVolts))  /  \(Format.volts(r.maxVolts))")
                        ResultRow(label: "Pack capacity / energy", value: "\(Format.number(r.capacityAmpHours, digits: 1)) Ah  /  \(Format.number(r.energyWattHours, digits: 0)) Wh", emphasis: true)
                        ResultRow(label: "Pack continuous current", value: Format.amps(r.packContinuousAmps))
                        if let perCell = r.perCellLoadAmps, let crate = r.cRate {
                            ResultRow(label: "Per-cell load / C-rate", value: "\(Format.amps(perCell))  ·  \(Format.number(crate, digits: 2)) C", tone: r.loadOk ? Theme.good : Theme.bad)
                        }
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                }
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(output) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func applyCellPreset(_ preset: CellPreset) {
        switch preset {
        case .cell18650:
            cellV = "3.6"; cellAh = "2.5"; cellA = "20"
            diameter = "18.5"; length = "65.2"
        case .cell21700:
            cellV = "3.6"; cellAh = "4.0"; cellA = "15"
            diameter = "21.2"; length = "70.5"
        case .custom:
            cellV = "3.6"; cellAh = "3.0"; cellA = "10"
            diameter = "18.5"; length = "65.0"
        }
    }

    private func applyExample() {
        if mode == .plan {
            targetV = "36"; current = "20"; power = ""
            applyCellPreset(.custom)
        } else {
            series = "14"; parallel = "10"; loadA = "40"
            applyCellPreset(.cell18650)
        }
    }

    private func calculate() {
        session.calculate {
            if mode == .plan {
                return .plan(try EbikePack.plan(
                    targetVolts: targetV.parsedDouble ?? .nan,
                    continuousAmps: current.parsedDouble,
                    continuousWatts: power.parsedDouble,
                    cellVolts: cellV.parsedDouble ?? .nan,
                    cellAmpHours: cellAh.parsedDouble ?? .nan,
                    cellContinuousAmps: cellA.parsedDouble ?? .nan,
                    cellDiameterMM: diameter.parsedDouble,
                    cellLengthMM: length.parsedDouble,
                    cellMassGrams: mass.parsedDouble,
                    enclosureWidthMM: encW.parsedDouble,
                    enclosureHeightMM: encH.parsedDouble,
                    pattern: pattern.math
                ))
            }
            return .check(try EbikePack.analyze(
                seriesCount: series.parsedDouble ?? .nan,
                parallelCount: parallel.parsedDouble ?? .nan,
                cellVolts: cellV.parsedDouble ?? .nan,
                cellAmpHours: cellAh.parsedDouble ?? .nan,
                cellContinuousAmps: cellA.parsedDouble ?? .nan,
                loadAmps: loadA.parsedDouble
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        targetV = ""; current = ""; power = ""
        series = ""; parallel = ""
        cellV = ""; cellAh = ""; cellA = ""; loadA = ""
        diameter = ""; length = ""; mass = ""; encW = ""; encH = ""
        session.reset()
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .plan(let r):
            return "\(r.architecture)  ·  \(Format.volts(r.nominalVolts))  ·  \(Format.number(r.capacityAmpHours, digits: 1)) Ah  ·  \(Format.number(r.energyWattHours, digits: 0)) Wh"
        case .check(let r):
            return "\(r.architecture)  ·  \(Format.volts(r.nominalVolts))  ·  \(Format.number(r.capacityAmpHours, digits: 1)) Ah  ·  \(Format.number(r.energyWattHours, digits: 0)) Wh"
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .plan(let r):
            return "\(r.architecture)  ·  \(Format.number(r.energyWattHours, digits: 0)) Wh"
        case .check(let r):
            return "\(r.architecture)  ·  \(Format.number(r.energyWattHours, digits: 0)) Wh"
        }
    }

    private func save(_ output: Output) {
        switch output {
        case .plan(let r):
            jobs.save(SavedJob(
                name: jobName,
                toolID: .eBikePackDesigner,
                inputs: ["target": "\(targetV) V", "I": current],
                outputs: ["arch": r.architecture, "Wh": Format.number(r.energyWattHours, digits: 0)]
            ))
        case .check(let r):
            jobs.save(SavedJob(
                name: jobName,
                toolID: .eBikePackDesigner,
                inputs: ["config": r.architecture, "cell": "\(cellV) V / \(cellAh) Ah"],
                outputs: ["V": Format.volts(r.nominalVolts), "Wh": Format.number(r.energyWattHours, digits: 0)]
            ))
        }
    }
}

// MARK: - Nickel Strip

struct NickelStripView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.nickelStrip, "width", default: "8") private var width
    @StoredInput(.nickelStrip, "thickness", default: "0.15") private var thickness
    @StoredInput(.nickelStrip, "contJ", default: "5") private var contJ
    @StoredInput(.nickelStrip, "pulseJ", default: "10") private var pulseJ
    @StoredInput(.nickelStrip, "jobName", default: "Nickel strip") private var jobName
    @State private var session = ExplicitCalculationState<NickelStripResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(width)|\(thickness)|\(contJ)|\(pulseJ)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .nickelStrip,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale,
            disclaimer: .designAidExtra("Derate for nickel-plated steel, long paths, poor welds, insulation, and temperature rise. Planning current only — not a weld certification or a substitute for the cell/BMS datasheet.")
        ) {
            ShowWorkCard(
                toolID: .nickelStrip,
                symbolic: "A = w × t     I = A × J",
                substituted: substituted,
                meaning: "Cross-section times a planning current density. 5 A/mm² continuous and 10 A/mm² short-pulse are the website defaults — not a listed ampacity. Confirm the strip alloy.",
                referenceTool: .eBikePackDesigner
            )
            TryExampleButton(title: "8 × 0.15 mm at 5 / 10 A/mm²") {
                applyExample()
                session.prepareForNewInputs()
            }

            ThumbButtonRow {
                ForEach(NickelStrip.commonSizes) { size in
                    Button("\(Format.number(size.widthMM, digits: 0))×\(Format.number(size.thicknessMM, digits: 2))") {
                        width = formatStrip(size.widthMM)
                        thickness = formatStrip(size.thicknessMM)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                }
            }

            NumberField(title: "Strip width", unit: "mm", text: $width, fieldID: "width", onSubmit: calculate)
            NumberField(title: "Thickness", unit: "mm", text: $thickness, fieldID: "thickness", onSubmit: calculate)
            NumberField(title: "Continuous density", unit: "A/mm²", text: $contJ, fieldID: "contJ", onSubmit: calculate)
            NumberField(title: "Short-pulse density", unit: "A/mm²", text: $pulseJ, fieldID: "pulseJ", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    applyExample()
                    session.prepareForNewInputs()
                },
                exampleTitle: "8 × 0.15 mm"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: sticky) {
                    ResultRow(label: "Cross section", value: "\(Format.number(r.crossSectionMM2, digits: 3)) mm²", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Continuous planning current", value: Format.amps(r.continuousAmps), emphasis: true)
                    ResultRow(label: "Short-pulse planning current", value: Format.amps(r.pulseAmps))
                }
                .opacity(session.isStale ? 0.72 : 1)

                ResultCard(title: "Common sizes at these densities") {
                    ForEach(NickelStrip.commonSizes) { size in
                        let area = size.widthMM * size.thicknessMM
                        ResultRow(
                            label: "\(Format.number(size.widthMM, digits: 0)) × \(Format.number(size.thicknessMM, digits: 2)) mm",
                            value: "\(Format.number(area, digits: 3)) mm²  ·  \(Format.number(area * r.continuousDensity, digits: 1)) A / \(Format.number(area * r.pulseDensity, digits: 1)) A"
                        )
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func formatStrip(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%g", value)
    }

    private func applyExample() {
        width = "8"; thickness = "0.15"; contJ = "5"; pulseJ = "10"
    }

    private func calculate() {
        session.calculate {
            try NickelStrip.size(
                widthMM: width.parsedDouble ?? .nan,
                thicknessMM: thickness.parsedDouble ?? .nan,
                continuousDensity: contJ.parsedDouble ?? .nan,
                pulseDensity: pulseJ.parsedDouble ?? .nan
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        width = ""; thickness = ""; contJ = ""; pulseJ = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.widthMM, digits: 2)) × \(Format.number(r.thicknessMM, digits: 2)) = \(Format.number(r.crossSectionMM2, digits: 3)) mm²  →  \(Format.number(r.continuousAmps, digits: 1)) A / \(Format.number(r.pulseAmps, digits: 1)) A"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.crossSectionMM2, digits: 3)) mm²  ·  \(Format.number(r.continuousAmps, digits: 1)) A"
    }

    private func save(_ r: NickelStripResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .nickelStrip,
            inputs: ["strip": "\(width) × \(thickness) mm"],
            outputs: ["A": "\(Format.number(r.crossSectionMM2, digits: 3)) mm²", "I": Format.amps(r.continuousAmps)]
        ))
    }
}
