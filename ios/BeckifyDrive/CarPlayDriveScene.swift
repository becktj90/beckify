import BeckifyMath
import CarPlay
import UIKit

/// Driving-task CarPlay scene. Templates only — no WKWebView, no custom map.
/// Data items refresh at most once every 10 seconds (Apple driving-task rule).
/// Attaches to the shared dashboard model so the trip, regen, efficiency, and
/// weather estimators run while only CarPlay is on screen.
///
/// Root: a list with two rows of gauge tiles drawn like the phone dashboard
/// (driving-task apps can't draw their own CarPlay views, so the tiles are
/// images in list image rows). "All readings" pushes the nine-row text view.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, OBDSessionObserving {
    private var interfaceController: CPInterfaceController?
    private var rootTemplate: CPListTemplate?
    private var detailsTemplate: CPInformationTemplate?
    private var lastPublish: Date?
    private var lastCopy: DriveCarPlayCopy?
    private var lastExtras: DriveCarPlayExtras?
    private var lastTiles: [DriveCarPlayTile]?
    private var lastHeadline: String?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        OBDBluetoothSession.shared.addObserver(self)
        OBDBluetoothSession.shared.activate()
        DashboardModel.shared.attach(.carPlay)
        publish(force: true)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        OBDBluetoothSession.shared.removeObserver(self)
        DashboardModel.shared.detach(.carPlay)
        self.interfaceController = nil
        rootTemplate = nil
        detailsTemplate = nil
        lastPublish = nil
        lastCopy = nil
        lastExtras = nil
        lastTiles = nil
        lastHeadline = nil
    }

    func obdSessionDidUpdate() {
        publish(force: false)
    }

    private func publish(force: Bool) {
        guard let interfaceController else { return }
        let now = Date()
        guard force || CarPlayPublishPolicy.shouldPublish(since: lastPublish, now: now) else { return }
        let units = DriveUnitPreference.region
        let (copy, extras) = CarPlayCopySource.current()
        let tiles = DriveCarPlayTiles.make(CarPlayCopySource.tileInputs(), units: units)
        let headline = DriveCarPlayTiles.headline(flow: DashboardModel.shared.flow, link: copy.link)
        guard force || copy != lastCopy || extras != lastExtras || tiles != lastTiles || headline != lastHeadline else { return }
        lastCopy = copy
        lastExtras = extras
        lastTiles = tiles
        lastHeadline = headline
        lastPublish = now

        let sections = makeSections(tiles: tiles, headline: headline, interfaceController: interfaceController)
        if let rootTemplate {
            rootTemplate.updateSections(sections)
        } else {
            let template = CPListTemplate(title: "Beckify Drive", sections: sections)
            rootTemplate = template
            interfaceController.setRootTemplate(template, animated: false) { _, _ in }
        }
        detailsTemplate?.items = Self.detailItems(copy: copy, extras: extras)
    }

    // MARK: Gauges

    private func makeSections(
        tiles: [DriveCarPlayTile],
        headline: String,
        interfaceController: CPInterfaceController
    ) -> [CPListSection] {
        let scale = interfaceController.carTraitCollection.displayScale
        let size = CPListImageRowItem.maximumImageSize
        let perRow = max(1, min(4, CPMaximumNumberOfGridImages))
        var rows: [CPListTemplateItem] = []
        for (index, start) in stride(from: 0, to: tiles.count, by: perRow).enumerated() {
            let chunk = Array(tiles[start..<min(start + perRow, tiles.count)])
            let text = index == 0 ? headline : Self.rowTitle(chunk)
            rows.append(imageRow(text: text, tiles: chunk, size: size, scale: scale))
        }
        let all = CPListItem(text: "All readings", detailText: "Every value as text, with sources")
        all.accessoryType = .disclosureIndicator
        all.handler = { [weak self] _, completion in
            self?.showDetails()
            completion()
        }
        return [CPListSection(items: rows), CPListSection(items: [all])]
    }

    private func imageRow(text: String, tiles: [DriveCarPlayTile], size: CGSize, scale: CGFloat) -> CPListImageRowItem {
        let images = tiles.map { CarPlayTileRenderer.image($0, size: size, scale: scale) }
        let row: CPListImageRowItem
        if #available(iOS 17.4, *) {
            // Captions carry the full reading, e.g. "Power 15 hp est.".
            row = CPListImageRowItem(text: text, images: images, imageTitles: tiles.map(\.spoken))
        } else {
            row = CPListImageRowItem(text: text, images: images)
        }
        row.handler = { [weak self] _, completion in
            self?.showDetails()
            completion()
        }
        row.listImageRowHandler = { [weak self] _, _, completion in
            self?.showDetails()
            completion()
        }
        return row
    }

    /// Second-row label from what the row holds, e.g. "Range · Efficiency · Pack".
    private static func rowTitle(_ tiles: [DriveCarPlayTile]) -> String {
        tiles.map(\.title).joined(separator: " · ")
    }

    // MARK: Details

    private func showDetails() {
        guard let interfaceController else { return }
        if let detailsTemplate, interfaceController.templates.contains(detailsTemplate) { return }
        let (copy, extras) = CarPlayCopySource.current()
        let template = CPInformationTemplate(
            title: "All readings",
            layout: .twoColumn,
            items: Self.detailItems(copy: copy, extras: extras),
            actions: [CPTextButton]()
        )
        detailsTemplate = template
        interfaceController.pushTemplate(template, animated: true) { _, _ in }
    }

    /// Nine rows, two columns. Estimates carry "est." in their text.
    private static func detailItems(copy: DriveCarPlayCopy, extras: DriveCarPlayExtras) -> [CPInformationItem] {
        [
            CPInformationItem(title: "Charge", detail: copy.charge),
            CPInformationItem(title: "Power", detail: copy.power),
            CPInformationItem(title: "Regen", detail: extras.regen),
            CPInformationItem(title: "Speed", detail: copy.speed),
            CPInformationItem(title: "Range", detail: copy.range),
            CPInformationItem(title: "Weather range", detail: extras.weatherRange),
            CPInformationItem(title: "Efficiency", detail: extras.efficiency),
            CPInformationItem(title: "Temp", detail: copy.temperature),
            CPInformationItem(title: "Link", detail: copy.link),
        ]
    }
}

/// CarPlay Dashboard shortcuts. Same 10-second cadence as the main scene.
final class CarPlayDashboardSceneDelegate: UIResponder, CPTemplateApplicationDashboardSceneDelegate, OBDSessionObserving {
    private var dashboardController: CPDashboardController?
    private var lastPublish: Date?
    private var lastCopy: DriveCarPlayCopy?

    func templateApplicationDashboardScene(
        _ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene,
        didConnect dashboardController: CPDashboardController,
        to window: UIWindow
    ) {
        self.dashboardController = dashboardController
        OBDBluetoothSession.shared.addObserver(self)
        OBDBluetoothSession.shared.activate()
        DashboardModel.shared.attach(.carPlay)
        publish(force: true)
    }

    func templateApplicationDashboardScene(
        _ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene,
        didDisconnect dashboardController: CPDashboardController,
        from window: UIWindow
    ) {
        OBDBluetoothSession.shared.removeObserver(self)
        DashboardModel.shared.detach(.carPlay)
        self.dashboardController = nil
        lastPublish = nil
        lastCopy = nil
    }

    func obdSessionDidUpdate() {
        publish(force: false)
    }

    private func publish(force: Bool) {
        guard let dashboardController else { return }
        let now = Date()
        guard force || CarPlayPublishPolicy.shouldPublish(since: lastPublish, now: now) else { return }
        let copy = CarPlayCopySource.current().copy
        guard force || copy != lastCopy else { return }
        lastCopy = copy
        lastPublish = now
        let charge = CPDashboardButton(
            titleVariants: [copy.charge],
            subtitleVariants: ["Charge"],
            image: Self.symbol("bolt.fill")
        )
        // Power is an estimate (350 V nominal × measured current); its copy says "est.".
        let power = CPDashboardButton(
            titleVariants: [copy.power],
            subtitleVariants: ["Power"],
            image: Self.symbol("gauge.with.dots.needle.67percent")
        )
        dashboardController.shortcutButtons = [charge, power]
    }

    private static func symbol(_ name: String) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: config) ?? UIImage()
    }
}

/// CarPlay text in the iPhone's region units (Settings → General → Language
/// & Region), read on every publish so a region change shows up within 10 s.
/// The phone dashboard's own unit toggles do not apply here.
enum CarPlayCopySource {
    static func current() -> (copy: DriveCarPlayCopy, extras: DriveCarPlayExtras) {
        let units = DriveUnitPreference.region
        let session = OBDBluetoothSession.shared
        let copy = DrivePresentationBuilder.make(
            profile: session.profile,
            book: session.book,
            now: Date(),
            planning: session.planning,
            trip: session.trip,
            link: session.carPlayLink,
            units: units
        ).carPlay
        return (copy, DashboardModel.shared.carPlayExtras(units: units))
    }

    /// Numbers behind the CarPlay gauge tiles, from the shared dashboard model.
    static func tileInputs() -> DriveCarPlayTileInputs {
        let model = DashboardModel.shared
        let speed = model.heroSpeed
        return DriveCarPlayTileInputs(
            layout: model.layout,
            socPercent: model.value(.displayedSocPercent).value,
            powerKW: model.powerKW,
            peakPowerKW: model.insights.peakPowerKW,
            flow: model.flow,
            speedKph: speed?.kph,
            speedSource: speed?.source.rawValue,
            rangeMiles: model.planningRangeMiles,
            weatherRangeMiles: model.weatherAdjustment?.adjustedMiles,
            whPerMile: model.insights.efficiency.whPerMile(packKWh: model.planning.usableKWh),
            packTempC: model.value(.packTempC).value,
            rpm: model.value(.rpm).value,
            coolantC: model.value(.coolantC).value,
            fuelPercent: model.value(.fuelLevelPercent).value,
            moduleVolts: model.value(.moduleVolts).value,
            ambientC: model.value(.ambientC).value
        )
    }
}
