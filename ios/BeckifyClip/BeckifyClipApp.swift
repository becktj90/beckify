import SwiftUI

/// Voltage Drop only. This target does not embed the toolbox, sensors, or Crew Talk.
@main
struct BeckifyClipApp: App {
    var body: some Scene {
        WindowGroup {
            VoltageDropClipView()
        }
    }
}
