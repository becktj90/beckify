import AVFoundation
import SwiftUI
import UIKit

@main
struct KestrelHeavyApp: App {
    @UIApplicationDelegateAdaptor(KestrelHeavyAppDelegate.self) private var appDelegate

    init() {
        KestrelHeavyAudioSession.activate()
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

/// Info.plist is portrait-only; this keeps WKWebView from inheriting a landscape mask.
final class KestrelHeavyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        [.portrait, .portraitUpsideDown]
    }
}

enum KestrelHeavyAudioSession {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
