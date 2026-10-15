import BeckifyMath
import CarPlay
import SwiftUI
import UIKit

/// Driving-task CarPlay scene. Templates only — no WKWebView, no custom map.
/// Data items refresh at most once every 10 seconds (Apple driving-task rule).
/// Attaches to the shared dashboard model so the trip, regen, efficiency, and
/// weather estimators run while only CarPlay is on screen.
///
/// Root: gauge-tile rows drawn like the phone dashboard (driving-task apps
/// can't draw their own CarPlay views, so the tiles are images in list image
/// rows), then every other reading as list rows, as many as the car allows.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, OBDSessionObserving {
    private var interfaceController: CPInterfaceController?
    private var rootTemplate: CPListTemplate?
    private var detailsTemplate: CPListTemplate?
    /// Per-tile detail screen (iOS 26 card row) and which tile it opened on.
    private var gaugeTemplate: CPListTemplate?
    private var gaugeFocus: DriveCarPlayTile.Kind?
    private var lastPublish: Date?
    private var lastCopy: DriveCarPlayCopy?
    private var lastReadings: [DriveCarPlayReadingSection]?
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
        gaugeTemplate = nil
        gaugeFocus = nil
        lastPublish = nil
        lastCopy = nil
        lastReadings = nil
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
        let copy = CarPlayCopySource.current().copy
        let inputs = CarPlayCopySource.tileInputs()
        let tiles = DriveCarPlayTiles.make(inputs, units: units)
        let readings = DriveCarPlayReadings.make(inputs, units: units, link: copy.link)
        let headline = DriveCarPlayTiles.headline(flow: DashboardModel.shared.flow, link: copy.link)
        guard force || copy != lastCopy || readings != lastReadings || tiles != lastTiles || headline != lastHeadline else { return }
        lastCopy = copy
        lastReadings = readings
        lastTiles = tiles
        lastHeadline = headline
        lastPublish = now

        let sections = makeSections(tiles: tiles, readings: readings, headline: headline, interfaceController: interfaceController)
        if let rootTemplate {
            rootTemplate.updateSections(sections)
        } else {
            let template = CPListTemplate(title: "Beckify Drive", sections: sections)
            rootTemplate = template
            interfaceController.setRootTemplate(template, animated: false) { _, _ in }
        }
        detailsTemplate?.updateSections(readingSections(readings, usedItems: 0, usedSections: 0, linkWhenTruncated: false))
        refreshGauge(tiles: tiles, readings: readings)
    }

    // MARK: Gauges

    private func makeSections(
        tiles: [DriveCarPlayTile],
        readings: [DriveCarPlayReadingSection],
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
        return [CPListSection(items: rows)]
            + readingSections(readings, usedItems: rows.count, usedSections: 1, linkWhenTruncated: true)
    }

    #if compiler(>=6.2)
    /// iOS 26 element row: each tile is a rounded image with its reading as
    /// the caption, e.g. "Power 15 hp est.".
    @available(iOS 26.0, *)
    private func elementRow(text: String, tiles: [DriveCarPlayTile], scale: CGFloat) -> CPListImageRowItem {
        let size = CPListImageRowItemImageGridElement.maximumImageSize
        let elements = tiles.map { tile in
            // Short name under the tile where VoiceOver can read the full value
            // from the accessibility label (26.4+); the full reading before that.
            let element = CPListImageRowItemImageGridElement(
                image: CarPlayTileRenderer.image(tile, size: size, scale: scale),
                imageShape: .roundedRectangle,
                title: Self.hasElementAccessibilityLabel ? tile.title : tile.spoken,
                accessorySymbolName: nil
            )
            if #available(iOS 26.4, *) {
                element.accessibilityLabel = tile.spoken
            }
            return element
        }
        return withHandlers(CPListImageRowItem(text: text, imageGridElements: elements, allowsMultipleLines: true), tiles: tiles)
    }
    #endif

    /// `CPListImageRowItemElement.accessibilityLabel` is iOS 26.4+ in newer SDKs.
    private static var hasElementAccessibilityLabel: Bool {
        if #available(iOS 26.4, *) { return true }
        return false
    }

    /// "Power 54 hp est. Peak 82 hp, torque 200 lb-ft, HV amps 115 A."
    private static func spokenCard(_ tile: DriveCarPlayTile) -> String {
        let extras = tile.readouts
            .filter { $0.value != DriveCarPlayTiles.missing }
            .map { "\($0.label.capitalized) \($0.value)" }
            .joined(separator: ", ")
        return extras.isEmpty ? tile.spoken : "\(tile.spoken). \(extras)."
    }

    private func legacyRow(text: String, tiles: [DriveCarPlayTile], size: CGSize, scale: CGFloat) -> CPListImageRowItem {
        let images = tiles.map { CarPlayTileRenderer.image($0, size: size, scale: scale) }
        let row: CPListImageRowItem
        if #available(iOS 17.4, *) {
            row = CPListImageRowItem(text: text, images: images, imageTitles: tiles.map(\.spoken))
        } else {
            row = CPListImageRowItem(text: text, images: images)
        }
        return withHandlers(row, tiles: tiles)
    }

    /// Tapping a tile opens that gauge large; tapping the row itself opens the text list.
    private func withHandlers(_ row: CPListImageRowItem, tiles: [DriveCarPlayTile]) -> CPListImageRowItem {
        let kinds = tiles.map(\.kind)
        row.handler = { [weak self] _, completion in
            self?.showDetails()
            completion()
        }
        row.listImageRowHandler = { [weak self] _, index, completion in
            if kinds.indices.contains(index) {
                self?.showGauge(kinds[index])
            } else {
                self?.showDetails()
            }
            completion()
        }
        return row
    }

    // MARK: Gauge detail

    /// iOS 26+ opens the tile as a large retro gauge card, the tapped gauge
    /// first and the rest of the cluster after it. Earlier iOS has no large
    /// image rows, so it opens the text list.
    private func showGauge(_ kind: DriveCarPlayTile.Kind) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), let interfaceController, let tiles = lastTiles, !tiles.isEmpty {
            if let gaugeTemplate, interfaceController.templates.contains(gaugeTemplate) { return }
            gaugeFocus = kind
            let sections = gaugeSections(tiles: tiles, readings: lastReadings ?? [], focus: kind, interfaceController: interfaceController)
            let template = CPListTemplate(title: "Gauges", sections: sections)
            gaugeTemplate = template
            interfaceController.pushTemplate(template, animated: true) { _, _ in }
            return
        }
        #endif
        showDetails()
    }

    private func refreshGauge(tiles: [DriveCarPlayTile], readings: [DriveCarPlayReadingSection]) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), let interfaceController, let gaugeTemplate, let gaugeFocus,
           interfaceController.templates.contains(gaugeTemplate) {
            gaugeTemplate.updateSections(gaugeSections(tiles: tiles, readings: readings, focus: gaugeFocus, interfaceController: interfaceController))
        }
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private func gaugeSections(
        tiles: [DriveCarPlayTile],
        readings: [DriveCarPlayReadingSection],
        focus: DriveCarPlayTile.Kind,
        interfaceController: CPInterfaceController
    ) -> [CPListSection] {
        let scale = interfaceController.carTraitCollection.displayScale
        let size = CPListImageRowItemCardElement.maximumFullHeightImageSize
        let ordered = tiles.filter { $0.kind == focus } + tiles.filter { $0.kind != focus }
        let cards = ordered.map { tile in
            // The card image draws its own name, reading and readouts, so no
            // CarPlay caption covers the gauge where VoiceOver can use the
            // accessibility label (26.4+). Before that the caption is the label.
            let card = CPListImageRowItemCardElement(
                image: CarPlayTileRenderer.clusterImage(tile, size: size, scale: scale),
                showsImageFullHeight: true,
                title: Self.hasElementAccessibilityLabel ? nil : tile.spoken,
                subtitle: nil,
                tintColor: nil
            )
            if #available(iOS 26.4, *) {
                card.accessibilityLabel = Self.spokenCard(tile)
            }
            return card
        }
        let row = CPListImageRowItem(text: nil, cardElements: cards, allowsMultipleLines: false)
        // Every other reading under the cards, so the screen is full of data.
        return [CPListSection(items: [row])]
            + readingSections(readings, usedItems: 1, usedSections: 1, linkWhenTruncated: true)
    }
    #endif

    private static func chunks(_ tiles: [DriveCarPlayTile], of size: Int) -> [[DriveCarPlayTile]] {
        stride(from: 0, to: tiles.count, by: size).map { Array(tiles[$0..<min($0 + size, tiles.count)]) }
    }

    /// Second-row label from what the row holds, e.g. "Range · Efficiency · Pack".
    private static func rowTitle(_ tiles: [DriveCarPlayTile]) -> String {
        tiles.map(\.title).joined(separator: " · ")
    }

    // MARK: Readings

    /// Reading rows that fit after `usedItems` items and `usedSections` sections
    /// (the car sets both limits). Adds an "All readings" link when rows had to
    /// be left off.
    private func readingSections(
        _ readings: [DriveCarPlayReadingSection],
        usedItems: Int,
        usedSections: Int,
        linkWhenTruncated: Bool
    ) -> [CPListSection] {
        var itemBudget = Int(CPListTemplate.maximumItemCount) - usedItems
        var sectionBudget = Int(CPListTemplate.maximumSectionCount) - usedSections
        let total = readings.reduce(0) { $0 + $1.rows.count }
        let truncating = linkWhenTruncated && (total > itemBudget || readings.count > sectionBudget)
        if truncating {
            itemBudget -= 1
            sectionBudget -= 1
        }
        var sections: [CPListSection] = []
        for reading in readings where itemBudget > 0 && sectionBudget > 0 {
            let items: [CPListTemplateItem] = reading.rows.prefix(itemBudget).map(Self.listItem)
            sections.append(CPListSection(items: items, header: reading.header.uppercased(), sectionIndexTitle: nil))
            itemBudget -= items.count
            sectionBudget -= 1
        }
        if truncating {
            let all = CPListItem(text: "All readings", detailText: "Every value, grouped")
            all.accessoryType = .disclosureIndicator
            all.handler = { [weak self] _, completion in
                self?.showDetails()
                completion()
            }
            sections.append(CPListSection(items: [all]))
        }
        return sections
    }

    /// "Charge: 88 %" with the source underneath and a glowing icon.
    private static func listItem(_ row: DriveCarPlayReading) -> CPListItem {
        let missing = row.value == DriveCarPlayTiles.missing
        let color = missing ? UIColor.systemGray : UIColor(DriveTheme.accent)
        let image = UIImage(systemName: row.symbol)?.withTintColor(color, renderingMode: .alwaysOriginal)
        return CPListItem(
            text: "\(row.title): \(row.value)",
            detailText: row.detail.isEmpty ? nil : row.detail,
            image: image
        )
    }

    private func showDetails() {
        guard let interfaceController else { return }
        if let detailsTemplate, interfaceController.templates.contains(detailsTemplate) { return }
        let readings = lastReadings ?? DriveCarPlayReadings.make(
            CarPlayCopySource.tileInputs(),
            units: DriveUnitPreference.region,
            link: CarPlayCopySource.current().copy.link
        )
        let template = CPListTemplate(
            title: "All readings",
            sections: readingSections(readings, usedItems: 0, usedSections: 0, linkWhenTruncated: false)
        )
        detailsTemplate = template
        interfaceController.pushTemplate(template, animated: true) { _, _ in }
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
        let energy = model.insights.energy
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
            // Same figure range uses: typed, else measured this trip, else the profile default.
            whPerMile: model.effectivePlanning.inputs.whPerMile,
            packTempC: model.value(.packTempC).value,
            rpm: model.value(.rpm).value,
            coolantC: model.value(.coolantC).value,
            fuelPercent: model.value(.fuelLevelPercent).value,
            moduleVolts: model.value(.moduleVolts).value,
            ambientC: model.value(.ambientC).value,
            hvCurrentAmps: model.value(.hvCurrentAmps).value,
            torqueNm: model.torqueNm,
            tripKm: model.trip.startedAt == nil ? nil : model.trip.distanceKilometers,
            maxSpeedKph: model.trip.maxSpeedKph,
            avgSpeedKph: model.trip.averageMovingSpeedKph,
            regenKWh: energy.isEmpty ? nil : energy.regenKWh,
            netKWh: energy.isEmpty ? nil : energy.netKWh,
            regenScore: model.insights.regen.score,
            motorTempC: model.value(.motorTempC).value,
            planningUsesDefaults: model.planningRangeMiles != nil && model.effectivePlanning.usesDefaults,
            rangeLowMiles: model.rangeBandMiles?.low,
            rangeHighMiles: model.rangeBandMiles?.high
        )
    }
}
