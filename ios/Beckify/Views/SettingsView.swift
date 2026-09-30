import SwiftUI
import BeckifyMath

enum ToolboxAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsToolbarButton: View {
    @State private var showSettings = false

    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("settingsButton")
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ToolboxPreferenceKey.electricalCode) private var codeRaw = ElectricalCode.nec.rawValue
    @AppStorage(ToolboxPreferenceKey.preferredUnits) private var unitsRaw = PreferredUnitSystem.followCode.rawValue
    @AppStorage(ToolboxPreferenceKey.appearance) private var appearanceRaw = ToolboxAppearance.system.rawValue

    private var code: ElectricalCode {
        ElectricalCode(rawValue: codeRaw) ?? .nec
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Electrical code", selection: codeBinding) {
                        ForEach(ElectricalCode.allCases, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .accessibilityIdentifier("electricalCodePicker")
                    Text(code.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Electrical code")
                } footer: {
                    Text("Default is NEC (US). Tools without an AS/NZS table keep the NEC result and say so. They do not relabel NEC numbers as AS/NZS.")
                }

                Section {
                    ForEach(PlannedElectricalCode.allCases, id: \.self) { planned in
                        LabeledContent(planned.displayName, value: planned.status)
                    }
                } header: {
                    Text("Later")
                } footer: {
                    Text("IEC 60364, the Canadian Electrical Code, and BS 7671 are named here so a later build can add them. They are not selectable.")
                }

                Section {
                    Picker("Length", selection: unitsBinding) {
                        ForEach(PreferredUnitSystem.allCases, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Follow code uses feet on NEC Voltage Drop and metres on the AS/NZS path. Conductor identity stays with the code: AWG for NEC, mm² for AS/NZS. Switching units does not convert a number you already typed.")
                }

                Section {
                    Picker("Appearance", selection: appearanceBinding) {
                        ForEach(ToolboxAppearance.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows this iPhone or iPad. Beckify does not force dark mode unless you pick Dark here.")
                }

                Section {
                    Text("Results are a design aid. They are not a PE stamp, an AEE stamp, a permit, or a substitute for the NEC, AS/NZS 3000, or AS/NZS 3008. Confirm the current standard and the authority having jurisdiction.")
                        .font(.footnote)
                } header: {
                    Text("Design aid")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settingsDone")
                }
            }
        }
    }

    private var codeBinding: Binding<ElectricalCode> {
        Binding(
            get: { ElectricalCode(rawValue: codeRaw) ?? .nec },
            set: { codeRaw = $0.rawValue }
        )
    }

    private var unitsBinding: Binding<PreferredUnitSystem> {
        Binding(
            get: { PreferredUnitSystem(rawValue: unitsRaw) ?? .followCode },
            set: { unitsRaw = $0.rawValue }
        )
    }

    private var appearanceBinding: Binding<ToolboxAppearance> {
        Binding(
            get: { ToolboxAppearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }
}

struct ElectricalCodeBannerView: View {
    let notice: ElectricalCodeNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notice.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(notice.kind == .necLabeledFallback ? Theme.warn : Theme.accent)
            if notice.showsDetail {
                Text(notice.message)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (notice.kind == .necLabeledFallback ? Theme.warn : Theme.accent).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notice.accessibilityLabel)
        .accessibilityIdentifier("electricalCodeBanner")
    }
}
