import AVFoundation
import SwiftUI

@main
struct KestrelHeavyApp: App {
    init() {
        KestrelHeavyAudioSession.activate()
    }

    var body: some Scene {
        WindowGroup {
            KestrelHeavyRootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

enum KestrelHeavyAudioSession {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
