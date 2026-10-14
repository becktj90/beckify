import BeckifyMath
import CarPlay
import UIKit

/// Driving-task CarPlay scene. Templates only — no WKWebView, no custom map.
/// Data items refresh at most once every 10 seconds (Apple driving-task rule).
/// Attaches to the shared dashboard model so the trip, regen, efficiency, and
/// weather estimators run while only CarPlay is on screen.
///
/// Root: a list of gauge-tile rows drawn like the phone dashboard
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
    /// GPS speed, weather range and timer-based efficiency change without an
    /// OBD callback, so a slow tick republishes too (still gated to 10 s).
    private var refreshTimer: Timer?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        OBDBluetoothSession.shared.addObserver(self)
        OBDBluetoothSession.shared.activate()
        DashboardModel.shared.attach(.carPlay)
        publish(force: true)
        startRefresh()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        refreshTimer?.invalidate()
        refreshTimer = nil
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

    private func startRefresh() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.publish(force: false)
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
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
        var rows: [CPListTemplateItem] = []
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // Rows of four that wrap onto a second line on narrow screens
            // instead of dropping tiles.
            rows = Self.chunks(tiles, of: 4).enumerated().map { index, chunk in
                elementRow(text: index == 0 ? headline : Self.rowTitle(chunk), tiles: chunk, scale: scale)
            }
        }
        #endif
        if rows.isEmpty {
            // Before iOS 26 a row can't wrap, and narrow screens show fewer
            // images than CPMaximumNumberOfGridImages, so keep rows to three.
            let perRow = max(1, min(3, CPMaximumNumberOfGridImages))
            let size = CPListImageRowItem.maximumImageSize
            rows = Self.chunks(tiles, of: perRow).enumerated().map { index, chunk in
                legacyRow(text: index == 0 ? headline : Self.rowTitle(chunk), tiles: chunk, size: size, scale: scale)
            }
        }
        let all = CPListItem(text: "All readings", detailText: "Every value as text, with sources")
        all.accessoryType = .disclosureIndicator
        all.handler = { [weak self] _, completion in
            self?.showDetails()
            completion()
        }
        return [CPListSection(items: rows), CPListSection(items: [all])]
    }

    #if compiler(>=6.2)
    /// iOS 26 element row: each tile is a rounded image with its reading as
    /// the caption, e.g. "Power 15 hp est.".
    @available(iOS 26.0, *)
    private func elementRow(text: String, tiles: [DriveCarPlayTile], scale: CGFloat) -> CPListImageRowItem {
        let size = CPListImageRowItemImageGridElement.maximumImageSize
        let elements = tiles.map { tile in
            let element = CPListImageRowItemImageGridElement(
                image: CarPlayTileRenderer.image(tile, size: size, scale: scale),
                imageShape: .roundedRectangle,
                title: tile.spoken,
                accessorySymbolName: nil
            )
            element.accessibilityLabel = tile.spoken
            return element
        }
        return withDetailsHandlers(CPListImageRowItem(text: text, imageGridElements: elements, allowsMultipleLines: true))
    }
    #endif

    private func legacyRow(text: String, tiles: [DriveCarPlayTile], size: CGSize, scale: CGFloat) -> CPListImageRowItem {
        let images = tiles.map { CarPlayTileRenderer.image($0, size: size, scale: scale) }
        let row: CPListImageRowItem
        if #available(iOS 17.4, *) {
            row = CPListImageRowItem(text: text, images: images, imageTitles: tiles.map(\.spoken))
        } else {
            row = CPListImageRowItem(text: text, images: images)
        }
        return withDetailsHandlers(row)
    }

    private func withDetailsHandlers(_ row: CPListImageRowItem) -> CPListImageRowItem {
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

    private static func chunks(_ tiles: [DriveCarPlayTile], of size: Int) -> [[DriveCarPlayTile]] {
        stride(from: 0, to: tiles.count, by: size).map { Array(tiles[$0..<min($0 + size, tiles.count)]) }
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
