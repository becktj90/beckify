import Combine
import CoreLocation
import CoreMotion
import SwiftUI
import BeckifyMath

// MARK: - Orientation sensor (tilt + magnetic heading)

@MainActor
final class SolarOrientationModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var tiltDegrees = 0.0
    @Published var headingDegrees = 0.0
    @Published var latitude: Double?
    @Published var motionAvailable = false
    @Published var hasMotion = false
    @Published var status = "Sensors idle"
    @Published var locationStatus = "Latitude is optional — enter it, or allow When In Use location."

    private let motion = CMMotionManager()
    private let location = CLLocationManager()
    private var didRequestLocation = false

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyKilometer
        motionAvailable = motion.isDeviceMotionAvailable
            && CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical)
    }

    func startMotion() {
        guard motion.isDeviceMotionAvailable,
              CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) else {
            motionAvailable = false
            status = "Device motion with magnetic north is not available on this hardware."
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 20.0
        motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.status = error.localizedDescription
                return
            }
            guard let data else { return }
            let grav = data.gravity
            self.tiltDegrees = SolarDesign.panelTiltFromGravityDegrees(
                gravityX: grav.x, gravityY: grav.y, gravityZ: grav.z
            )
            if data.heading >= 0 {
                self.headingDegrees = data.heading
            } else {
                let f = data.magneticField.field
                self.headingDegrees = MagneticMath.headingDegrees(x: f.x, y: f.y)
            }
            self.hasMotion = self.tiltDegrees.isFinite
            self.status = "CoreMotion — lay phone face-up on the module; top toward skyward edge"
        }
    }

    func stopMotion() {
        motion.stopDeviceMotionUpdates()
        status = "Sensors stopped"
    }

    func requestLatitude() {
        switch location.authorizationStatus {
        case .notDetermined:
            locationStatus = "Asking for When In Use location for latitude only."
            if !didRequestLocation {
                didRequestLocation = true
                location.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            location.requestLocation()
            locationStatus = "Reading approximate latitude…"
        default:
            locationStatus = "Location denied — type latitude manually."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                requestLatitude()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            latitude = loc.coordinate.latitude
            locationStatus = "Latitude from GPS (±\(Int(max(1, loc.horizontalAccuracy))) m)"
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationStatus = error.localizedDescription
        }
    }
}

// MARK: - Wizard

struct SolarDesignWizardView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var sensors = SolarOrientationModel()

    @StoredInput(.solarDesign, "scale", default: "residential") private var scaleRaw
    @StoredInput(.solarDesign, "latitude", default: "40") private var latitude
    @StoredInput(.solarDesign, "dailyKwh", default: "30") private var dailyKwh
    @StoredInput(.solarDesign, "psh", default: "4.5") private var psh
    @StoredInput(.solarDesign, "panelWatts", default: "400") private var panelWatts
    @StoredInput(.solarDesign, "panelCount", default: "") private var panelCount
    @StoredInput(.solarDesign, "tilt", default: "40") private var tilt
    @StoredInput(.solarDesign, "azimuth", default: "180") private var azimuth
    @StoredInput(.solarDesign, "eta", default: "80") private var eta
    @StoredInput(.solarDesign, "dcac", default: "1.20") private var dcac
    @StoredInput(.solarDesign, "includeStorage", default: "1") private var includeStorageRaw
    @StoredInput(.solarDesign, "storageMode", default: "autonomy") private var storageModeRaw
    @StoredInput(.solarDesign, "autonomyDays", default: "1") private var autonomyDays
    @StoredInput(.solarDesign, "peakKw", default: "5") private var peakKw
    @StoredInput(.solarDesign, "peakHours", default: "4") private var peakHours
    @StoredInput(.solarDesign, "selfPct", default: "40") private var selfPct
    @StoredInput(.solarDesign, "dod", default: "90") private var dod
    @StoredInput(.solarDesign, "rte", default: "90") private var rte
    @StoredInput(.solarDesign, "jobName", default: "Solar design") private var jobName

    @State private var session = ExplicitCalculationState<SolarDesignResult>()
    @State private var successTick = 0
    @State private var sensing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scale: SolarSystemScale {
        SolarSystemScale(rawValue: scaleRaw) ?? .residential
    }

    private var storageMode: SolarStorageMode {
        SolarStorageMode(rawValue: storageModeRaw) ?? .autonomy
    }

    private var includeStorage: Bool {
        includeStorageRaw == "1" || includeStorageRaw.lowercased() == "true"
    }

    private var inputFingerprint: String {
        [
            scaleRaw, latitude, dailyKwh, psh, panelWatts, panelCount, tilt, azimuth,
            eta, dcac, includeStorageRaw, storageModeRaw, autonomyDays, peakKw,
            peakHours, selfPct, dod, rte,
        ].joined(separator: "|")
    }

    var body: some View {
        ToolScaffold(
            toolID: .solarDesign,
            stickyAnswer: sticky,
            copyText: sticky,
            isResultStale: session.isStale,
            disclaimer: .sensor(extra: "Planning aid only — not a shade study, PE stamp, or interconnection model. IMU/compass are the phone’s sensors, not a survey instrument.")
        ) {
            ShowWorkCard(
                toolID: .solarDesign,
                symbolic: "Array_kW = E_day / (PSH · η · f_orient)     Nameplate_kWh = E_usable / (DoD · η_RTE)",
                substituted: substituted,
                meaning: "Fixed-tilt rules of thumb set the aim (tilt ≈ |lat|, face the equator). The orientation factor is a transparent cosine of your aim error. Storage divides usable energy by DoD and round-trip efficiency."
            )

            scalePicker
            NumberField(title: "Latitude", unit: "°", text: $latitude, fieldID: "latitude", onSubmit: calculate)
            locationRow
            NumberField(title: "Daily energy need", unit: "kWh/day", text: $dailyKwh, fieldID: "dailyKwh", onSubmit: calculate)
            NumberField(title: "Peak sun hours", unit: "h/day", text: $psh, helpText: "Arid ≈ 6, Southwest ≈ 5.5, temperate ≈ 4.5, cloudy ≈ 2.5", fieldID: "psh", onSubmit: calculate)
            NumberField(title: "Module STC power", unit: "W", text: $panelWatts, fieldID: "panelWatts", onSubmit: calculate)
            NumberField(title: "Panel count override", unit: "panels", text: $panelCount, optional: true, placeholder: "auto", fieldID: "panelCount", onSubmit: calculate)

            orientationSection
            sensorSection

            NumberField(title: "System efficiency", unit: "%", text: $eta, fieldID: "eta", onSubmit: calculate)
            NumberField(title: "DC:AC ratio", unit: "×", text: $dcac, fieldID: "dcac", onSubmit: calculate)

            storageSection

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: loadResidentialExample,
                exampleTitle: "30 kWh/day home + 1-day storage"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                resultBlock(r)
                    .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .onDisappear {
            sensors.stopMotion()
            sensing = false
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private var scalePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SYSTEM SCALE")
                .font(Theme.TypeRole.fieldLabel)
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Picker("System scale", selection: $scaleRaw) {
                Text("Residential").tag(SolarSystemScale.residential.rawValue)
                Text("Commercial").tag(SolarSystemScale.commercial.rawValue)
                Text("Utility / facility").tag(SolarSystemScale.utility.rawValue)
            }
            .pickerStyle(.segmented)
            .onChange(of: scaleRaw) { _, _ in
                if let e = SolarDesign.defaultSystemEfficiencyPercent[scale] {
                    eta = Format.number(e, digits: 0)
                }
                if let r = SolarDesign.defaultDcAcRatio[scale] {
                    dcac = String(format: "%.2f", r)
                }
                session.prepareForNewInputs()
            }
        }
    }

    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Use phone latitude") {
                sensors.requestLatitude()
                if let lat = sensors.latitude {
                    latitude = Format.number(lat, digits: 2)
                    applyOptimalOrientation()
                }
            }
            .buttonStyle(.bordered)
            .frame(minHeight: Theme.touchTarget)
            .onChange(of: sensors.latitude) { _, lat in
                guard let lat else { return }
                latitude = Format.number(lat, digits: 2)
                applyOptimalOrientation()
            }
            Text(sensors.locationStatus)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }
    }

    private var orientationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NumberField(title: "Tilt from horizontal", unit: "°", text: $tilt, fieldID: "tilt", onSubmit: calculate)
            NumberField(title: "Azimuth (from N, CW)", unit: "°", text: $azimuth, fieldID: "azimuth", onSubmit: calculate)
            Button("Apply optimal tilt & azimuth for latitude") {
                applyOptimalOrientation()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)
            if let advice = try? SolarDesign.orientationAdvice(latitudeDegrees: latitude.parsedDouble ?? .nan) {
                Text("Target \(Format.number(advice.yearRoundTiltDegrees, digits: 1))° tilt · \(Int(advice.optimalAzimuthDegrees))° azimuth (\(advice.hemisphere))")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var sensorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PHONE AIM")
                .font(Theme.TypeRole.fieldLabel)
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Text("Lay the phone face-up on the module for tilt. Point the top toward the skyward edge for azimuth.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            if !sensors.motionAvailable {
                ToolEmptyState(
                    title: "No orientation hardware",
                    detail: sensors.status,
                    systemImage: "gyroscope"
                )
            } else {
                ResultCard(title: "Live reading") {
                    ResultRow(label: "Measured tilt", value: sensors.hasMotion ? Format.degrees(sensors.tiltDegrees) : "—", emphasis: true)
                    ResultRow(label: "Measured heading", value: sensors.hasMotion ? Format.degrees(sensors.headingDegrees) : "—", emphasis: true)
                    ResultRow(label: "Status", value: sensors.status)
                    if sensors.hasMotion,
                       let tTarget = tilt.parsedDouble,
                       let aTarget = azimuth.parsedDouble {
                        let tErr = abs(sensors.tiltDegrees - tTarget)
                        let aErr = SolarDesign.azimuthErrorDegrees(measured: sensors.headingDegrees, target: aTarget)
                        let ok = tErr <= 3 && aErr <= 8
                        ResultRow(
                            label: "vs design",
                            value: ok ? "Aligned (±3° / ±8°)" : "Δ tilt \(Format.number(tErr, digits: 1))° · Δ az \(Format.number(aErr, digits: 1))°",
                            tone: ok ? Theme.good : Theme.warn
                        )
                    }
                }
                ThumbButtonRow {
                    Button(sensing ? "Stop sensors" : "Start sensors") {
                        if sensing {
                            sensors.stopMotion()
                            sensing = false
                        } else {
                            sensors.startMotion()
                            sensing = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                    Button("Use reading") {
                        guard sensors.hasMotion else { return }
                        tilt = Format.number(sensors.tiltDegrees, digits: 1)
                        azimuth = Format.number(sensors.headingDegrees, digits: 0)
                        calculate()
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: Theme.touchTarget)
                    .disabled(!sensors.hasMotion)
                }
            }
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { includeStorage },
                set: { includeStorageRaw = $0 ? "1" : "0"; session.prepareForNewInputs() }
            )) {
                Text("Include energy storage")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)

            if includeStorage {
                Picker("Storage mode", selection: $storageModeRaw) {
                    Text("Autonomy").tag(SolarStorageMode.autonomy.rawValue)
                    Text("Peak-shave").tag(SolarStorageMode.peakShave.rawValue)
                    Text("Self-consumption").tag(SolarStorageMode.selfConsumption.rawValue)
                }
                .pickerStyle(.segmented)
                .onChange(of: storageModeRaw) { _, _ in session.prepareForNewInputs() }

                switch storageMode {
                case .autonomy:
                    NumberField(title: "Days of autonomy", unit: "days", text: $autonomyDays, fieldID: "autonomyDays", onSubmit: calculate)
                case .peakShave:
                    NumberField(title: "Peak load to cover", unit: "kW", text: $peakKw, fieldID: "peakKw", onSubmit: calculate)
                    NumberField(title: "Duration", unit: "h", text: $peakHours, fieldID: "peakHours", onSubmit: calculate)
                case .selfConsumption:
                    NumberField(title: "Fraction of daily PV", unit: "%", text: $selfPct, fieldID: "selfPct", onSubmit: calculate)
                }
                NumberField(title: "Usable DoD", unit: "%", text: $dod, fieldID: "dod", onSubmit: calculate)
                NumberField(title: "Round-trip efficiency", unit: "%", text: $rte, fieldID: "rte", onSubmit: calculate)
            }
        }
    }

    @ViewBuilder
    private func resultBlock(_ r: SolarDesignResult) -> some View {
        ResultCard(title: "Array", copyText: sticky) {
            ResultRow(label: "Array DC", value: "\(Format.number(r.arrayKwDc, digits: 2)) kW", emphasis: true, tone: Theme.good)
            ResultRow(label: "Panels", value: "\(r.panelCount) × \(Format.number(r.panelWatts, digits: 0)) W")
            ResultRow(label: "Inverter AC", value: "\(Format.number(r.inverterKwAc, digits: 2)) kW")
            ResultRow(label: "DC:AC", value: Format.number(r.dcAcRatio, digits: 2))
            ResultRow(label: "Daily production", value: "\(Format.number(r.dailyProductionKwh, digits: 1)) kWh", emphasis: true)
            ResultRow(label: "Annual", value: "\(Format.number(r.annualProductionKwh, digits: 0)) kWh")
            ResultRow(label: "Specific yield", value: "\(Format.number(r.specificYieldKwhPerKwp, digits: 0)) kWh/kWp·yr")
            ResultRow(label: "Footprint (approx.)", value: "\(Format.number(r.roofOrGroundAreaM2, digits: 0)) m²")
        }
        ResultCard(title: "Orientation") {
            ResultRow(label: "Target tilt", value: Format.degrees(r.advice.yearRoundTiltDegrees))
            ResultRow(label: "Target azimuth", value: Format.degrees(r.advice.optimalAzimuthDegrees))
            ResultRow(label: "Tilt error", value: Format.degrees(r.tiltErrorDegrees))
            ResultRow(label: "Azimuth error", value: Format.degrees(r.azimuthErrorDegrees))
            ResultRow(label: "Orientation factor", value: "\(Format.number(r.orientationFactor * 100, digits: 1)) %", emphasis: true, tone: Theme.accent)
        }
        if let s = r.storage {
            ResultCard(title: "Energy storage — \(s.modeLabel)") {
                ResultRow(label: "Nameplate", value: "\(Format.number(s.nameplateKwh, digits: 1)) kWh", emphasis: true, tone: Theme.good)
                ResultRow(label: "Usable", value: "\(Format.number(s.usableKwh, digits: 1)) kWh")
                ResultRow(label: "PCS power (approx.)", value: "\(Format.number(s.recommendedPowerKw, digits: 1)) kW")
                ResultRow(label: "Hours at avg load", value: "\(Format.number(s.autonomyHoursAtAverageLoad, digits: 1)) h")
            }
        }
    }

    private func applyOptimalOrientation() {
        guard let lat = latitude.parsedDouble,
              let advice = try? SolarDesign.orientationAdvice(latitudeDegrees: lat) else { return }
        tilt = Format.number(advice.yearRoundTiltDegrees, digits: 1)
        azimuth = Format.number(advice.optimalAzimuthDegrees, digits: 0)
        session.prepareForNewInputs()
    }

    private func calculate() {
        session.calculate {
            try SolarDesign.size(
                scale: scale,
                latitudeDegrees: latitude.parsedDouble ?? .nan,
                dailyLoadKwh: dailyKwh.parsedDouble ?? .nan,
                peakSunHours: psh.parsedDouble ?? .nan,
                panelWatts: panelWatts.parsedDouble ?? .nan,
                tiltDegrees: tilt.parsedDouble ?? .nan,
                azimuthDegrees: azimuth.parsedDouble ?? .nan,
                systemEfficiencyPercent: eta.parsedDouble,
                dcAcRatio: dcac.parsedDouble,
                panelCountOverride: panelCount.trimmingCharacters(in: .whitespaces).isEmpty ? nil : panelCount.parsedDouble,
                includeStorage: includeStorage,
                storageMode: storageMode,
                autonomyDays: autonomyDays.parsedDouble ?? 1,
                peakLoadKw: peakKw.parsedDouble ?? 0,
                peakDurationHours: peakHours.parsedDouble ?? 4,
                selfConsumptionFractionPercent: selfPct.parsedDouble ?? 40,
                storageDodPercent: dod.parsedDouble ?? 90,
                storageRoundTripEfficiencyPercent: rte.parsedDouble ?? 90
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        scaleRaw = SolarSystemScale.residential.rawValue
        latitude = ""; dailyKwh = ""; psh = ""
        panelWatts = ""; panelCount = ""
        tilt = ""; azimuth = ""
        eta = ""; dcac = ""
        includeStorageRaw = "0"
        autonomyDays = ""; peakKw = ""; peakHours = ""; selfPct = ""
        dod = ""; rte = ""
        session.reset()
    }

    private func loadResidentialExample() {
        scaleRaw = SolarSystemScale.residential.rawValue
        latitude = "40"; dailyKwh = "30"; psh = "4.5"
        panelWatts = "400"; panelCount = ""
        eta = "80"; dcac = "1.20"
        includeStorageRaw = "1"
        storageModeRaw = SolarStorageMode.autonomy.rawValue
        autonomyDays = "1"; dod = "90"; rte = "90"
        applyOptimalOrientation()
        session.prepareForNewInputs()
        calculate()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        var s = "\(Format.number(r.arrayKwDc, digits: 2)) kWdc · \(r.panelCount) panels · \(Format.number(r.annualProductionKwh, digits: 0)) kWh/yr"
        if let st = r.storage {
            s += " · storage \(Format.number(st.nameplateKwh, digits: 0)) kWh"
        }
        return s
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        if let st = r.storage {
            return "\(Format.number(r.arrayKwDc, digits: 2)) kWdc · \(Format.number(st.nameplateKwh, digits: 0)) kWh batt"
        }
        return "\(Format.number(r.arrayKwDc, digits: 2)) kWdc · \(r.panelCount) × \(Format.number(r.panelWatts, digits: 0)) W"
    }

    private func save(_ r: SolarDesignResult) {
        var outputs: [String: String] = [
            "array": "\(Format.number(r.arrayKwDc, digits: 2)) kWdc",
            "panels": "\(r.panelCount)",
            "annual": "\(Format.number(r.annualProductionKwh, digits: 0)) kWh",
        ]
        if let s = r.storage {
            outputs["storage"] = "\(Format.number(s.nameplateKwh, digits: 1)) kWh"
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .solarDesign,
            inputs: [
                "scale": scale.rawValue,
                "load": "\(dailyKwh) kWh/day",
                "tilt": "\(tilt)°",
                "azimuth": "\(azimuth)°",
            ],
            outputs: outputs
        ))
    }
}
