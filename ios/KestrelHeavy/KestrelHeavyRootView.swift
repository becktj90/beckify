import SwiftUI

/// Full-bleed Phaser 4 cabinet. Play happens in the bundled `Game/` pack,
/// not on beckify.com. Safe-area padding lives in the cabinet CSS.
struct KestrelHeavyRootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Color(red: 5 / 255, green: 5 / 255, blue: 13 / 255)
                .ignoresSafeArea()

            if KestrelHeavyGameView.packAvailable() {
                KestrelHeavyGameView(onCabinetReady: dismissSplash)
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
                .onAppear(perform: dismissSplash)
            }

            if showSplash {
                KestrelHeavySplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .supportedInterfaceOrientations(.portrait.union(.portraitUpsideDown))
        .onAppear {
            KestrelHeavyOrientation.lockScene()
            // Never leave the brand screen up if WKWebView stalls.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: dismissSplash)
        }
    }

    private func dismissSplash() {
        guard showSplash else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            showSplash = false
        }
    }
}

/// In-app hold while the cabinet boots. Matches LaunchScreen so the handoff is quiet.
struct KestrelHeavySplashView: View {
    var body: some View {
        ZStack {
            Color(red: 5 / 255, green: 5 / 255, blue: 13 / 255)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image("LaunchMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .accessibilityHidden(true)

                Text("KESTREL HEAVY")
                    .font(.system(size: 26, weight: .heavy, design: .default))
                    .tracking(2.4)
                    .foregroundStyle(Color(red: 183 / 255, green: 171 / 255, blue: 1))

                Text("PIER 7")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(5)
                    .foregroundStyle(Color(red: 140 / 255, green: 224 / 255, blue: 1))
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Kestrel Heavy")
    }
}

#Preview {
    KestrelHeavyRootView()
}
