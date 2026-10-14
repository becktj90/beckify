import BeckifyMath
import CarPlay
import SwiftUI
import UIKit

@main
final class BeckifyDriveAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        // Fixture launches (CI screenshots) never touch Bluetooth.
        if DriveLaunchFixture.scenario != nil || DriveLaunchFixture.carPlayPreview { return true }
        #endif
        OBDBluetoothSession.shared.activate()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
            config.sceneClass = CPTemplateApplicationScene.self
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        if connectingSceneSession.role.rawValue == "CPTemplateApplicationDashboardSceneSessionRoleApplication" {
            let config = UISceneConfiguration(name: "CarPlay-Dashboard", sessionRole: connectingSceneSession.role)
            config.sceneClass = CPTemplateApplicationDashboardScene.self
            config.delegateClass = CarPlayDashboardSceneDelegate.self
            return config
        }
        let config = UISceneConfiguration(name: "Phone", sessionRole: connectingSceneSession.role)
        config.delegateClass = PhoneSceneDelegate.self
        return config
    }
}

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        // Dark by default; DashboardView applies the user's appearance setting.
        window.rootViewController = UIHostingController(rootView: DashboardView())
        #if DEBUG
        if let scenario = DriveLaunchFixture.scenario {
            window.rootViewController = UIHostingController(rootView: scenario.view)
        } else if DriveLaunchFixture.carPlayPreview {
            window.rootViewController = UIHostingController(rootView: CarPlayTilesPreview())
        }
        #endif
        self.window = window
        window.makeKeyAndVisible()
    }
}

#if DEBUG
/// Debug-only launch arguments for the CI screenshot job:
/// `-BeckifyDriveFixture boltDriving` opens a fixture state (see
/// `DashboardScenario`), `-BeckifyDriveScroll energy` scrolls to a section, and
/// `-BeckifyDriveCarPlayPreview YES` shows the CarPlay gauge tiles.
enum DriveLaunchFixture {
    static var carPlayPreview: Bool {
        UserDefaults.standard.bool(forKey: "BeckifyDriveCarPlayPreview")
    }

    static var scenario: DashboardScenario? {
        UserDefaults.standard.string(forKey: "BeckifyDriveFixture").flatMap(DashboardScenario.init(rawValue:))
    }

    static var scrollSection: DashboardSection? {
        UserDefaults.standard.string(forKey: "BeckifyDriveScroll").flatMap(DashboardSection.init(rawValue:))
    }
}
#endif
