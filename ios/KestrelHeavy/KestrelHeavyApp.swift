import AVFoundation
import SwiftUI
import UIKit

@main
struct KestrelHeavyApp: App {
    @UIApplicationDelegateAdaptor(KestrelHeavyAppDelegate.self) private var appDelegate

    init() {
        KestrelHeavyAudioSession.activate()
        KestrelHeavyOrientation.lockScene()
    }

    var body: some Scene {
        WindowGroup {
            KestrelHeavyRootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .supportedInterfaceOrientations(.portrait.union(.portraitUpsideDown))
        }
    }
}

enum KestrelHeavyOrientation {
    static let mask: UIInterfaceOrientationMask = [.portrait, .portraitUpsideDown]

    static func lockScene() {
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.requestGeometryUpdate(prefs) { _ in }
        }
    }
}

/// Info.plist is portrait-only; this keeps WKWebView from inheriting a landscape mask.
final class KestrelHeavyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        KestrelHeavyOrientation.mask
    }
}

enum KestrelHeavyAudioSession {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
