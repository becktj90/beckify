import BeckifyMath
import SwiftUI

/// Beckify Drive root: link status, hero, then card sections for the vehicle
/// profile and the phone. Replaces the first single-scroll gauge screen.
struct DashboardView: View {
    @StateObject private var model: DashboardModel
    @StateObject private var preferences: DashboardPreferences

    init(
        model: @autoclosure @escaping () -> DashboardModel = DashboardModel(),
        preferences: @autoclosure @escaping () -> DashboardPreferences = DashboardPreferences()
    ) {
        _model = StateObject(wrappedValue: model())
        _preferences = StateObject(wrappedValue: preferences())
    }

    var body: some View {
        DashboardContent(model: model, sensors: model.sensors, preferences: preferences)
            .preferredColorScheme(preferences.appearance == .dark ? .dark : nil)
    }
}

private struct DashboardContent: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var sensors: PhoneSensorStore
    @ObservedObject var preferences: DashboardPreferences

    @State private var showAdapter = false
    @State private var showSettings = false
    #if DEBUG
    @State private var showInspector = false
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LinkStatusPill(
                        title: model.linkTitle,
                        detail: model.linkDetail,
                        carPlay: model.carPlayLink,
                        profile: model.profile.title,
                        state: linkState
                    ) {
                        showAdapter = true
                    }
                    SpeedHero(model: model, units: preferences.units)
                    ForEach(DashboardSection.sections(for: model.layout), id: \.self) { section in
                        let cards = preferences.layout.cards(in: section, for: model.layout)
                        if !cards.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                DashboardSectionHeader(section: section)
                                CardFlow(cards: cards) { card in
                                    DashboardCardView(
                                        card: card,
                                        model: model,
                                        sensors: sensors,
                                        units: preferences.units,
                                        openAdapter: { showAdapter = true }
                                    )
                                }
                            }
                        }
                    }
                    Text(DrivePresentation.designAid)
                        .font(.footnote)
                        .foregroundStyle(DriveTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
                .frame(maxWidth: 1_000)
                .frame(maxWidth: .infinity)
            }
            .background { DashboardBackground() }
            .navigationTitle("Beckify Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Units and Cards", systemImage: "slider.horizontal.3")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInspector = true
                    } label: {
                        Label("PID Inspector", systemImage: "ladybug")
                    }
                }
                #endif
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Adapter") { showAdapter = true }
                        .disabled(model.session == nil)
                }
            }
            .tint(DriveTheme.accent)
            .sheet(isPresented: $showAdapter) {
                if let session = model.session {
                    DriveAdapterSheet(session: session)
                }
            }
            .sheet(isPresented: $showSettings) {
                DashboardSettingsSheet(preferences: preferences, layout: model.layout)
            }
            #if DEBUG
            .sheet(isPresented: $showInspector) {
                PIDInspectorSheet(model: model)
            }
            #endif
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.start()
            } else if phase == .background {
                model.stop()
            }
        }
    }

    private var linkState: LinkStatusPill.LinkState {
        if model.isLive { return .live }
        if model.isConnecting { return .connecting }
        return .idle
    }
}

/// Near-black with a soft teal glow at the top, like the first Drive screen.
private struct DashboardBackground: View {
    var body: some View {
        ZStack {
            DriveTheme.background
            RadialGradient(
                colors: [DriveTheme.accent.opacity(0.16), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

/// Adapter link in one capsule. Tap to open the adapter sheet.
struct LinkStatusPill: View {
    enum LinkState {
        case live
        case connecting
        case idle
    }

    let title: String
    let detail: String
    let carPlay: String
    let profile: String
    let state: LinkState
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DriveTheme.text)
                    Text(profile)
                        .font(.subheadline)
                        .foregroundStyle(DriveTheme.muted)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DriveTheme.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(DriveTheme.surface)
                }
                .overlay(Capsule().strokeBorder(DriveTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adapter: \(title), \(profile)")
            .accessibilityHint("Opens adapter and vehicle settings")
            HStack(spacing: 6) {
                Label("CarPlay shows: \(carPlay)", systemImage: "car.fill")
                    .labelStyle(.titleAndIcon)
                Text("·")
                Text(detail)
                    .lineLimit(2)
            }
            .font(.caption)
            .foregroundStyle(DriveTheme.muted)
            .padding(.horizontal, 6)
        }
    }

    private var dotColor: Color {
        switch state {
        case .live: return DriveTheme.accent
        case .connecting: return DriveTheme.warning
        case .idle: return DriveTheme.track
        }
    }
}

/// Lays cards out: narrow cards in an adaptive grid, wide cards on their own row.
struct CardFlow<Content: View>: View {
    let cards: [DashboardCardID]
    @ViewBuilder let content: (DashboardCardID) -> Content

    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 12, alignment: .top)]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Self.runs(cards)) { run in
                if run.wide, let card = run.cards.first {
                    content(card)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(run.cards, id: \.self) { card in
                            content(card)
                        }
                    }
                }
            }
        }
    }

    struct Run: Identifiable {
        let id: Int
        let cards: [DashboardCardID]
        let wide: Bool
    }

    static func runs(_ cards: [DashboardCardID]) -> [Run] {
        var runs: [Run] = []
        var narrow: [DashboardCardID] = []
        func flush() {
            guard !narrow.isEmpty else { return }
            runs.append(Run(id: runs.count, cards: narrow, wide: false))
            narrow = []
        }
        for card in cards {
            if card.isWide {
                flush()
                runs.append(Run(id: runs.count, cards: [card], wide: true))
            } else {
                narrow.append(card)
            }
        }
        flush()
        return runs
    }
}
