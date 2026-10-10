import SwiftUI
import StoreKit
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
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    private var code: ElectricalCode {
        ElectricalCode(rawValue: codeRaw) ?? .nec
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Electrical code", selection: codeBinding) {
                        ForEach(ElectricalCode.allCases, id: \.self) { item in
                            Text(L(item.displayName)).tag(item)
                        }
                    }
                    .accessibilityIdentifier("electricalCodePicker")
                    Text(L(code.detail))
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
                            Text(L(item.displayName)).tag(item)
                        }
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Follow code uses feet on NEC Voltage Drop and metres on the AS/NZS path. Conductor identity stays with the code: AWG for NEC, mm² for AS/NZS. Switching units does not convert a number you already typed.")
                }

                Section {
                    Picker("Language", selection: $languageRaw) {
                        ForEach(AppLanguage.allCases) { item in
                            Text(item.pickerLabel).tag(item.rawValue)
                        }
                    }
                    .accessibilityIdentifier("languagePicker")
                } header: {
                    Text("Language")
                } footer: {
                    Text("System follows this iPhone or iPad. Calculator math and Crew Talk translation do not change.")
                }

                Section {
                    Picker("Appearance", selection: appearanceBinding) {
                        ForEach(ToolboxAppearance.allCases) { item in
                            Text(L(item.displayName)).tag(item)
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

                ToolboxTipJarSection()
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


/// Optional StoreKit tips. Easy to miss: Settings only, no prompt, not required to calculate or share.
private struct ToolboxTipJarSection: View {
    @StateObject private var store = ToolboxTipStore()

    var body: some View {
        Section {
            if store.products.isEmpty {
                Text("Optional.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.products) { product in
                    Button {
                        Task { await store.buy(product) }
                    } label: {
                        HStack {
                            Text(product.displayName)
                            Spacer()
                            Text(product.displayPrice)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(store.purchasing)
                    .accessibilityIdentifier("tipProduct.\(product.id)")
                }
            }
            if let note = store.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Tip")
        } footer: {
            Text("Optional. Calculators, copy, and saved jobs stay free. Apple processes the payment.")
        }
        .task { await store.load() }
        .accessibilityIdentifier("tipJar")
    }
}

@MainActor
private final class ToolboxTipStore: ObservableObject {
    /// Consumable products Trevor creates in App Store Connect. Prices come from the store, not this app.
    static let ids: Set<String> = [
        "com.beckify.toolbox.tip.small",
        "com.beckify.toolbox.tip.medium",
        "com.beckify.toolbox.tip.large",
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasing = false
    @Published private(set) var note: String?

    func load() async {
        do {
            let found = try await Product.products(for: Self.ids)
            products = found.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func buy(_ product: Product) async {
        guard !purchasing else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    note = "Thanks."
                case .unverified:
                    note = "That purchase could not be verified."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            note = "Purchase did not complete."
        }
    }
}
