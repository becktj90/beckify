import BeckifyMath
import SwiftUI
import UIKit

/// Vehicle profile, planning inputs, and BLE adapter scan. Same behavior as
/// the first Drive screen; moved here when the dashboard replaced it.
struct DriveAdapterSheet: View {
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
                        if session.profile.dashboardLayout != .powertrain {
                            planning
                        }
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
        .onAppear { session.activate() }
    }

    private var profilePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehicle")
                .driveSectionLabel()
            Picker("Vehicle", selection: Binding(
                get: { session.profile },
                set: { session.select(profile: $0) }
            )) {
                ForEach(VehicleProfile.allCases, id: \.self) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            // Four profiles do not fit a segmented control on an iPhone SE.
            .pickerStyle(.menu)
            .tint(DriveTheme.accent)
            Text(session.profile.summary)
                .font(.footnote)
                .foregroundStyle(DriveTheme.muted)
            if let facts = session.profile.facts {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Engines: \(facts.engines.joined(separator: ", "))")
                    Text("Factory tire sizes vary by trim: \(facts.tireSizes.joined(separator: ", "))")
                    Text(facts.note)
                }
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
            }
        }
    }

    private var planning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planning range")
                .driveSectionLabel()
            if !session.profile.nominalPackChoicesKWh.isEmpty {
                HStack {
                    ForEach(session.profile.nominalPackChoicesKWh, id: \.self) { kWh in
                        Button("\(Int(kWh)) kWh nominal") {
                            session.packKWhText = String(Int(kWh))
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DriveTheme.elevated, in: Capsule())
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
                .background(DriveTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    .driveCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
