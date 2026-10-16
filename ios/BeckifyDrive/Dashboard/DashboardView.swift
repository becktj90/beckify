import BeckifyMath
import SwiftUI

/// Beckify Drive root: link status, hero, then card sections for the vehicle
/// profile and the phone. Replaces the first single-scroll gauge screen.
struct DashboardView: View {
    @StateObject private var model: DashboardModel
    @StateObject private var preferences: DashboardPreferences

    init(
        model: @autoclosure @escaping () -> DashboardModel = .shared,
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
            GeometryReader { geo in
                let landscape = GaugeLayoutMath.isLandscape(width: geo.size.width, height: geo.size.height) && geo.size.width >= 560
                let diameter = GaugeLayoutMath.heroDiameter(width: geo.size.width, height: geo.size.height)
                let paneWidth = landscape ? max(geo.size.width - diameter - 48, 280) : geo.size.width - 32
                ScrollViewReader { proxy in
                    Group {
                        if landscape {
                            HStack(alignment: .center, spacing: 16) {
                                VStack(spacing: 10) {
                                    linkPill
                                    Spacer(minLength: 0)
                                    SpeedHero(model: model, units: preferences.units)
                                    Spacer(minLength: 0)
                                }
                                .frame(width: diameter + 8)
                                .padding(.vertical, 8)
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 14) {
                                        if model.layout == .ev {
                                            PowerHero(model: model, units: preferences.units)
                                        }
                                        sections
                                    }
                                    .padding(.bottom, 24)
                                }
                            }
                            .padding(.horizontal, 16)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 14) {
                                    linkPill
                                    heroes
                                    sections
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .padding(.bottom, 32)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .environment(\.dashboardViewport, geo.size)
                    .environment(\.dashboardPaneWidth, paneWidth)
                    .background { DashboardBackground() }
                    #if DEBUG
                    .task {
                        guard let section = DriveLaunchFixture.scrollSection else { return }
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        proxy.scrollTo(section, anchor: .top)
                    }
                    #endif
                }
            }
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
        .onAppear { model.attach(.phone) }
        .onDisappear { model.detach(.phone) }
        .onChange(of: scenePhase) { _, phase in
            // CarPlay keeps the model running on its own while the phone is locked.
            if phase == .active {
                model.attach(.phone)
            } else if phase == .background {
                model.detach(.phone)
            }
        }
    }

    private var linkPill: some View {
        LinkStatusPill(
            title: model.linkTitle,
            detail: model.linkDetail,
            carPlay: model.carPlayLink,
            profile: model.profile.title,
            state: linkState
        ) {
            showAdapter = true
        }
    }

    @ViewBuilder private var heroes: some View {
        if model.layout == .ev {
            PowerHero(model: model, units: preferences.units)
        }
        SpeedHero(model: model, units: preferences.units)
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(DashboardSection.sections(for: model.layout), id: \.self) { section in
                let cards = preferences.layout.cards(in: section, for: model.layout)
                if !cards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        DashboardSectionHeader(section: section)
                            .id(section)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Label("CarPlay shows: \(carPlay)", systemImage: "car.fill")
                        .labelStyle(.titleAndIcon)
                        .fixedSize()
                    Text("·")
                    Text(detail)
                        .lineLimit(2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("CarPlay shows: \(carPlay)", systemImage: "car.fill")
                        .labelStyle(.titleAndIcon)
                    Text(detail)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

/// Lays cards out: narrow cards fill every column (the last row stretches, so
/// there is no blank cell); wide cards take a row of their own.
struct CardFlow<Content: View>: View {
    let cards: [DashboardCardID]
    @ViewBuilder let content: (DashboardCardID) -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dashboardPaneWidth) private var paneWidth

    private let spacing: CGFloat = 12

    private var columns: Int {
        let minCell = GaugeLayoutMath.minCellWidth(containerWidth: Double(paneWidth), accessibilitySize: dynamicTypeSize.isAccessibilitySize)
        return GaugeLayoutMath.columnCount(width: Double(paneWidth), minCell: minCell, spacing: Double(spacing))
    }

    private var cardWidth: CGFloat {
        (paneWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Self.runs(cards)) { run in
                if run.wide, let card = run.cards.first {
                    content(card)
                        .environment(\.dashboardCardWidth, paneWidth)
                } else {
                    FillGridLayout(columns: columns, spacing: spacing) {
                        ForEach(run.cards, id: \.self) { card in
                            content(card)
                        }
                    }
                    .environment(\.dashboardCardWidth, cardWidth)
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
