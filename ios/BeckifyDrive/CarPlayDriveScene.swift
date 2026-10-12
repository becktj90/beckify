import BeckifyMath
import CarPlay
import UIKit

/// Driving-task CarPlay scene. Templates only — no WKWebView, no custom map.
/// Data items refresh at most once every 10 seconds (Apple driving-task rule).
/// Attaches to the shared dashboard model so the trip, regen, efficiency, and
/// weather estimators run while only CarPlay is on screen.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, OBDSessionObserving {
    private var interfaceController: CPInterfaceController?
    private var lastPublish: Date?
    private var lastCopy: DriveCarPlayCopy?
    private var lastExtras: DriveCarPlayExtras?

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
        lastPublish = nil
        lastCopy = nil
        lastExtras = nil
    }

    func obdSessionDidUpdate() {
        publish(force: false)
    }

    private func publish(force: Bool) {
        guard let interfaceController else { return }
        let now = Date()
        guard force || CarPlayPublishPolicy.shouldPublish(since: lastPublish, now: now) else { return }
        let copy = OBDBluetoothSession.shared.presentation.carPlay
        let extras = DashboardModel.shared.carPlayExtras
        guard force || copy != lastCopy || extras != lastExtras else { return }
        lastCopy = copy
        lastExtras = extras
        lastPublish = now
        // Nine rows, two columns. Estimates carry "est." in their text.
        let items = [
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
        let template = CPInformationTemplate(
            title: "Beckify Drive",
            layout: .twoColumn,
            items: items,
            actions: [CPTextButton]()
        )
        interfaceController.setRootTemplate(template, animated: false) { _, _ in }
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
        let copy = OBDBluetoothSession.shared.presentation.carPlay
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
