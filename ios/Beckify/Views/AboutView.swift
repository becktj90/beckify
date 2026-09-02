import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: "bolt.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient(colors: [Theme.accent.opacity(0.3), Theme.accent2.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Beckify")
                                .font(.title.weight(.bold))
                            Text("Field EE toolbox")
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    Text("Professional electrical calculators and public-API sensors for field work and homework. Native SwiftUI — not a website wrapper, not a project gallery.")
                        .foregroundStyle(Theme.foreground)

                    ResultCard(title: "Author") {
                        ResultRow(label: "Name", value: "Trevor Beck")
                        ResultRow(label: "Role", value: "Electrical Engineer")
                        ResultRow(label: "Site", value: "beckify.com")
                        ResultRow(label: "Email", value: "trevorjohnbeck@gmail.com")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if let url = URL(string: "https://beckify.com") {
                            Link("beckify.com", destination: url)
                                .frame(minHeight: Theme.touchTarget, alignment: .leading)
                                .accessibilityLabel("Beckify website")
                        }
                        if let mail = URL(string: "mailto:trevorjohnbeck@gmail.com") {
                            Link("trevorjohnbeck@gmail.com", destination: mail)
                                .frame(minHeight: Theme.touchTarget, alignment: .leading)
                                .accessibilityLabel("Email Trevor Beck")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.accent)

                    DisclaimerBanner()

                    ResultCard(title: "Privacy") {
                        Text("No ads, no analytics, no tracking, no account. Microphone, Bluetooth, and location are used only inside those tools, on this device. Saved jobs and last-used calculator inputs stay on this device. This app does not load beckify.com in a web view.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }

                    Text("v1.0 · Bundle com.beckify.toolbox")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("About")
        }
    }
}
