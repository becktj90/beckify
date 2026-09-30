import BeckifyMath
import SwiftUI
import UIKit

struct DriveRootView: View {
    @ObservedObject private var session = OBDBluetoothSession.shared
    @State private var showAdapter = false

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        statusRow
                        hero
                        tileGrid
                        detailList
                        Text(session.presentation.designAid)
                            .font(.footnote)
                            .foregroundStyle(DriveTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Beckify Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Adapter") { showAdapter = true }
                        .foregroundStyle(DriveTheme.accent)
                }
            }
            .sheet(isPresented: $showAdapter) {
                DriveAdapterSheet(session: session)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { session.activate() }
    }

    private var presentation: DrivePresentation { session.presentation }

    private var background: some View {
        ZStack {
            DriveTheme.background.ignoresSafeArea()
            RadialGradient(
                colors: [DriveTheme.accent.opacity(0.16), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var statusRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.linkTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(DriveTheme.text)
                Text(session.profile.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DriveTheme.accent)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            Spacer()
            Circle()
                .fill(session.carPlayLink.hasPrefix("Live") ? DriveTheme.accent : DriveTheme.dim)
                .frame(width: 10, height: 10)
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(DriveTheme.dim, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: ringFraction)
                    .stroke(
                        DriveTheme.ringColor(percent: presentation.heroPercent),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.45), value: ringFraction)
                VStack(spacing: 2) {
                    Text(presentation.heroValue)
                        .font(.system(size: presentation.layout == .ev ? 64 : 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DriveTheme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(presentation.heroCaption)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DriveTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 36)
            }
            .frame(width: 250, height: 250)
            .frame(maxWidth: .infinity)
            Text(session.linkDetail)
                .font(.footnote)
                .foregroundStyle(DriveTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    private var ringFraction: CGFloat {
        guard presentation.layout == .ev, let percent = presentation.heroPercent else { return 0 }
        return CGFloat(min(max(percent / 100, 0), 1))
    }

    private var tileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(presentation.tiles) { tile in
                VStack(alignment: .leading, spacing: 6) {
                    Text(tile.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DriveTheme.muted)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(tile.value)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DriveTheme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(tile.caption)
                        .font(.caption2)
                        .foregroundStyle(DriveTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                .background(DriveTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DriveTheme.stroke, lineWidth: 1)
                )
            }
        }
    }

    private var detailList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Live signals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DriveTheme.muted)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.bottom, 8)
            ForEach(presentation.rows) { row in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .foregroundStyle(DriveTheme.text)
                        Spacer()
                        Text(row.value)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DriveTheme.accent)
                    }
                    Text(row.note)
                        .font(.caption2)
                        .foregroundStyle(DriveTheme.muted)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(DriveTheme.stroke).frame(height: 1)
                }
            }
        }
    }
}

private struct DriveAdapterSheet: View {
    @ObservedObject var session: OBDBluetoothSession
    @Environment(\.dismiss) private var dismiss
    @State private var showUnlikely = false

    var body: some View {
        NavigationStack {
            ZStack {
                DriveTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        profilePicker
                        planning
                        scanHeader
                        adapterList
                        if session.bluetoothDenied {
                            Button("Open Settings") {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url)
                            }
                            .foregroundStyle(DriveTheme.accent)
                        }
                        Text("Bluetooth LE only. This is not an MFi or classic Bluetooth pairing. Vehicle data stays on this device.")
                            .font(.footnote)
                            .foregroundStyle(DriveTheme.muted)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Adapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { session.activate() }
    }

    private var profilePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehicle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DriveTheme.muted)
                .textCase(.uppercase)
            Picker("Vehicle", selection: Binding(
                get: { session.profile },
                set: { session.select(profile: $0) }
            )) {
                ForEach(VehicleProfile.allCases, id: \.self) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            Text(session.profile.summary)
                .font(.footnote)
                .foregroundStyle(DriveTheme.muted)
        }
    }

    private var planning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planning range")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DriveTheme.muted)
                .textCase(.uppercase)
            if !session.profile.nominalPackChoicesKWh.isEmpty {
                HStack {
                    ForEach(session.profile.nominalPackChoicesKWh, id: \.self) { kWh in
                        Button("\(Int(kWh)) kWh nominal") {
                            session.packKWhText = String(Int(kWh))
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DriveTheme.cardRaised, in: Capsule())
                        .foregroundStyle(DriveTheme.text)
                    }
                }
            }
            labeledField("Pack energy kWh", text: $session.packKWhText, prompt: "Assumed, not measured")
            labeledField("Wh per mile", text: $session.whPerMileText, prompt: "Your figure, not EPA")
            Text("Range appears only when displayed SoC is actually read and both numbers are filled in. It is labeled planning.")
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
            TextField(prompt, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .padding(12)
                .background(DriveTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(DriveTheme.text)
        }
    }

    private var scanHeader: some View {
        HStack {
            Button(session.isScanning ? "Stop scan" : "Scan") {
                if session.isScanning { session.stopScan() } else { session.startScan() }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(DriveTheme.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DriveTheme.accent, in: Capsule())
            Spacer()
            Button(session.carPlayLink == "No adapter" ? "Idle" : "Disconnect") {
                session.disconnect()
            }
            .foregroundStyle(DriveTheme.muted)
            .disabled(session.carPlayLink == "No adapter")
        }
    }

    private var visibleAdapters: [DriveAdapter] {
        let likely = session.adapters.filter(\.likely)
        if showUnlikely || likely.isEmpty { return session.adapters }
        return likely
    }

    private var adapterList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show other nearby devices", isOn: $showUnlikely)
                .font(.footnote)
                .tint(DriveTheme.accent)
                .foregroundStyle(DriveTheme.muted)
            if visibleAdapters.isEmpty {
                Text("No adapters yet. Common names are VEEPEAK, VLINK, OBDII, and CARISTA.")
                    .font(.footnote)
                    .foregroundStyle(DriveTheme.muted)
            }
            ForEach(visibleAdapters) { adapter in
                Button {
                    session.connect(id: adapter.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(adapter.name)
                                .foregroundStyle(DriveTheme.text)
                            Text(adapter.likely ? "Likely OBD · \(adapter.rssi) dBm" : "Other BLE · \(adapter.rssi) dBm")
                                .font(.caption)
                                .foregroundStyle(DriveTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "link")
                            .foregroundStyle(DriveTheme.accent)
                    }
                    .padding(12)
                    .background(DriveTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
