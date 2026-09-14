import SwiftUI

/// Full-bleed Phaser 4 cabinet. Play happens in the bundled `Game/` pack,
/// not on beckify.com. Safe-area padding lives in the cabinet CSS.
struct KestrelHeavyRootView: View {
    var body: some View {
        ZStack {
            Color(red: 5 / 255, green: 5 / 255, blue: 13 / 255)
                .ignoresSafeArea()

            if KestrelHeavyGameView.packAvailable() {
                KestrelHeavyGameView()
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Text("KESTREL HEAVY")
                        .font(.system(size: 22, weight: .heavy, design: .default))
                        .foregroundStyle(Color(red: 0.72, green: 0.67, blue: 1))
                    Text("The local game pack is missing from this build. On a Mac, run `python3 ios/scripts/pack_kestrelheavy_game.py` and rebuild the KestrelHeavy scheme.")
                        .font(.system(.callout, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.60, green: 0.64, blue: 0.78))
                        .padding(.horizontal, 28)
                }
            }
        }
    }
}

#Preview {
    KestrelHeavyRootView()
}
