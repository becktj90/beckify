import BeckifyMath
import Foundation
import SwiftUI

/// Conversation Mode. Two people take turns on one phone, or link two phones.
/// This is a plain VStack, not `ToolScaffold`, so the transcript, mic, and
/// text field share the space between the nav bar and the tab bar without
/// pinned insets stacking on top of each other.
struct CrewTalkConversationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = CrewTalkConversationModel()

    var body: some View {
        Group {
            switch model.stage {
            case .setup:
                CrewTalkConversationSetup(model: model)
            case .local, .linked:
                CrewTalkConversationTalk(model: model)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.stage != .setup {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("End") { model.endConversation() }
                        .accessibilityIdentifier("crewTalk.conversation.end")
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.interrupt() }
        }
        .onDisappear { model.shutdown() }
    }
}

// MARK: - Setup

private struct CrewTalkConversationSetup: View {
    @ObservedObject var model: CrewTalkConversationModel
    @State private var joinCode = ""
    @FocusState private var codeFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("Each person picks a translator who speaks their language, so you both hear the other side in a familiar voice.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)

                localCard
                linkCard

                if let message = model.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.warn)
                        .accessibilityIdentifier("crewTalk.conversation.error")
                }
            }
            .padding(Theme.Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var localCard: some View {
        ResultCard(title: "One phone") {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Pass it back and forth. The translator reads each line out loud, then it's the other person's turn.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                seatPicker(title: "English speaker hears", language: .english, seat: 0)
                seatPicker(title: "Español: escucha a", language: .spanish, seat: 1)
                Button {
                    model.startLocal(
                        englishCrew: model.localTalk.seats[0].crew,
                        spanishCrew: model.localTalk.seats[1].crew
                    )
                } label: {
                    Label("Start", systemImage: "person.2.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityIdentifier("crewTalk.conversation.startLocal")
            }
        }
    }

    private func seatPicker(title: String, language: CrewTalkConversationLanguage, seat: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.TypeRole.fieldLabel)
                .foregroundStyle(Theme.muted)
            CrewTalkCrewChips(
                roster: language.roster,
                selection: model.localTalk.seats[seat].crew
            ) { model.setLocalCrew($0, seat: seat) }
        }
    }

    private var linkCard: some View {
        ResultCard(title: "Two phones") {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Quick chat between two phones with Beckify. One starts a room and shares the code. Messages are not saved.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)

                Picker("My language", selection: Binding(
                    get: { model.linkLanguage },
                    set: { model.setLinkLanguage($0) }
                )) {
                    ForEach(CrewTalkConversationLanguage.allCases, id: \.rawValue) { language in
                        Text(language.label).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("crewTalk.conversation.myLanguage")

                Text("I hear")
                    .font(Theme.TypeRole.fieldLabel)
                    .foregroundStyle(Theme.muted)
                CrewTalkCrewChips(
                    roster: model.linkLanguage.roster,
                    selection: model.linkCrew
                ) { model.linkCrew = $0 }

                Button {
                    Task { await model.startRoom() }
                } label: {
                    Label("Start a room", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
                .disabled(model.isConnectingRoom)
                .accessibilityIdentifier("crewTalk.conversation.startRoom")

                HStack(spacing: 8) {
                    TextField("Room code", text: $joinCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($codeFocused)
                        .submitLabel(.join)
                        .onSubmit(join)
                        .accessibilityIdentifier("crewTalk.conversation.code")
                    Button("Join", action: join)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                        .disabled(model.isConnectingRoom || !CrewTalkRoomCode.isComplete(joinCode))
                        .accessibilityIdentifier("crewTalk.conversation.join")
                }
                if model.isConnectingRoom {
                    ProgressView()
                }
            }
        }
    }

    private func join() {
        codeFocused = false
        let code = joinCode
        Task { await model.joinRoom(code: code) }
    }
}

private struct CrewTalkCrewChips: View {
    let roster: [CrewTalkMember]
    let selection: CrewTalkMember
    let onSelect: (CrewTalkMember) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(roster, id: \.rawValue) { member in
                    Button {
                        onSelect(member)
                    } label: {
                        Text(member.firstName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(member == selection ? Theme.background : Theme.foreground)
                            .frame(minWidth: Theme.touchTarget, minHeight: Theme.touchTarget)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(member == selection ? Theme.accent : Theme.surfaceRaised)
                            )
                            .overlay(Capsule(style: .continuous).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(member.displayName)
                    .accessibilityAddTraits(member == selection ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Talk

private struct CrewTalkConversationTalk: View {
    @ObservedObject var model: CrewTalkConversationModel
    @State private var typed = ""
    @FocusState private var typedFocused: Bool

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            header
            sprites
            transcript
            if !model.liveTranscript.isEmpty {
                Text(model.liveTranscript)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
                    .accessibilityIdentifier("crewTalk.conversation.live")
            }
            if let message = model.errorMessage, !message.isEmpty {
                Text(message)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.warn)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("crewTalk.conversation.error")
            }
            micButton
            typedRow
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.xs)
        .padding(.bottom, Theme.Space.sm)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 4) {
            if model.stage == .linked {
                linkHeader
            } else {
                Text("\(model.localTalk.speaker.language.label), your turn")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.foreground)
                    .accessibilityIdentifier("crewTalk.conversation.turn")
            }
            Text(model.statusText.isEmpty ? " " : model.statusText)
                .font(Theme.TypeRole.help)
                .foregroundStyle(statusTone)
                .accessibilityIdentifier("crewTalk.conversation.status")
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var linkHeader: some View {
        if let session = model.session {
            HStack(spacing: 8) {
                Text(session.code)
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.foreground)
                    .textSelection(.enabled)
                    .accessibilityLabel("Room code \(session.code.map(String.init).joined(separator: " "))")
                    .accessibilityIdentifier("crewTalk.conversation.roomCode")
                ShareLink(item: "Join my Beckify conversation. Open Crew Talk → Conversation → Two phones, and enter code \(session.code).") {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share room code")
            }
            Text(linkStatus)
                .font(Theme.TypeRole.help)
                .foregroundStyle(model.partnerOnline ? Theme.good : Theme.muted)
                .accessibilityIdentifier("crewTalk.conversation.link")
        }
    }

    private var linkStatus: String {
        switch model.connection {
        case .connecting: return "Connecting…"
        case .reconnecting: return "Reconnecting…"
        case .lost: return "Disconnected"
        case .connected:
            guard let partner = model.partnerLanguage else { return "Waiting for the other person…" }
            return model.partnerOnline ? "\(partner.label) is here" : "\(partner.label) stepped away"
        }
    }

    private var statusTone: Color {
        switch model.phase {
        case .listening: return Theme.good
        case .failed: return Theme.warn
        default: return Theme.copper
        }
    }

    // MARK: Sprites

    private var sprites: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.md) {
            if model.stage == .linked {
                sprite(model.linkCrew)
            } else {
                ForEach(0..<2, id: \.self) { seat in
                    sprite(model.localTalk.seats[seat].crew)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func sprite(_ crew: CrewTalkMember) -> some View {
        VStack(spacing: 2) {
            CrewTalkSprite(crew: crew, isTalking: model.talkingCrew == crew, height: typedFocused ? 44 : 72)
            Text(crew.firstName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.foreground)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.entries) { entry in
                        bubble(entry)
                            .id(entry.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: model.entries) { _, entries in
                guard let last = entries.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .accessibilityIdentifier("crewTalk.conversation.transcript")
    }

    private func bubble(_ entry: CrewTalkConversationModel.Entry) -> some View {
        let mine = entry.side == 0
        return VStack(alignment: mine ? .leading : .trailing, spacing: 3) {
            Text(entry.text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(mine ? .leading : .trailing)
                .textSelection(.enabled)
            if !entry.original.isEmpty {
                Text("“\(entry.original)”")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(mine ? .leading : .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(mine ? Theme.surfaceRaised : Theme.accent.opacity(0.18))
        )
        .frame(maxWidth: .infinity, alignment: mine ? .leading : .trailing)
    }

    // MARK: Controls

    private var micButton: some View {
        Button {
            typedFocused = false
            model.tapTalk()
        } label: {
            Label(model.micLabel, systemImage: micSymbol)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.phase == .listening ? Theme.warn : Theme.accent)
        .disabled(!model.canTalk || model.phase == .starting)
        .accessibilityIdentifier("crewTalk.conversation.mic")
    }

    private var micSymbol: String {
        switch model.phase {
        case .listening: return "stop.circle.fill"
        case .translating, .preparingVoice, .playing: return "forward.end.fill"
        default: return "mic.circle.fill"
        }
    }

    private var typedRow: some View {
        HStack(spacing: 8) {
            TextField("Or type here", text: $typed)
                .textFieldStyle(.roundedBorder)
                .focused($typedFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .accessibilityIdentifier("crewTalk.conversation.typed")
            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .frame(width: Theme.touchTarget, height: Theme.touchTarget)
            }
            .buttonStyle(.bordered)
            .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.canTalk)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("crewTalk.conversation.send")
        }
    }

    private func send() {
        let text = typed
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        typed = ""
        model.sendTyped(text)
    }
}

// MARK: - Sprite

/// Full-body 16-bit helper. Two existing frames, nearest-neighbor so pixels stay crisp.
/// Talk is a syllable beat (idle held longer than the talk pose), not a 150 ms hard swap.
/// Junie's talk frame is the idle pose with the mouth open. Sloane is centered on the canvas.
/// The bob is a small continuous offset, independent of the frame cut.
struct CrewTalkSprite: View {
    let crew: CrewTalkMember
    let isTalking: Bool
    var height: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hopTick = 0

    /// One beat. Longer than a display frame so a timeline tick cannot skip the pose.
    private static let beat: TimeInterval = 0.10
    /// Closed, closed, open, closed, closed, open, closed, open.
    private static let mouthOpenOnBeat: [Bool] = [false, false, true, false, false, true, false, true]
    /// Talking: a quick bounce with a little squash. Idle: slow breathing.
    private static let talkPeriod: TimeInterval = 0.55
    private static let breathPeriod: TimeInterval = 3.4

    /// Where the sprite is in its motion this instant.
    private struct Pose {
        var mouthOpen: Bool
        var lift: CGFloat
        var squash: CGFloat
    }

    var body: some View {
        Group {
            if reduceMotion {
                still(mouthOpen: isTalking)
            } else {
                // Talking runs at 30 fps. The idle breath is slow, so 12 fps is plenty and sips battery.
                TimelineView(.periodic(from: .now, by: isTalking ? 1.0 / 30.0 : 1.0 / 12.0)) { context in
                    animated(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !reduceMotion { hopTick += 1 } }
        .accessibilityElement(children: .ignore)
        // With Reduce Motion there is no hop, so the sprite is not offered as a button.
        .accessibilityAddTraits(reduceMotion ? [] : .isButton)
        .accessibilityHint(reduceMotion ? "" : "Makes \(crew.firstName) hop")
        .accessibilityIdentifier("spanishTranslator.crewPortrait")
        .accessibilityLabel(isTalking ? "\(crew.displayName), talking" : crew.displayName)
    }

    private func pose(at t: TimeInterval) -> Pose {
        if isTalking {
            let beatIndex = Int(t / Self.beat) % Self.mouthOpenOnBeat.count
            let phase = sin(t * (2 * .pi) / Self.talkPeriod)
            return Pose(
                mouthOpen: Self.mouthOpenOnBeat[beatIndex],
                lift: CGFloat(max(phase, 0)) * height * 0.05,
                squash: 1 + CGFloat(max(-phase, 0)) * 0.03
            )
        }
        let breath = sin(t * (2 * .pi) / Self.breathPeriod)
        return Pose(mouthOpen: false, lift: CGFloat(breath) * 0.8, squash: 1 + CGFloat(breath) * 0.018)
    }

    private func animated(at t: TimeInterval) -> some View {
        let pose = pose(at: t)
        return sprite(mouthOpen: pose.mouthOpen)
            .scaleEffect(x: 1, y: pose.squash, anchor: .bottom)
            .offset(y: -pose.lift)
            .keyframeAnimator(initialValue: CGFloat(0), trigger: hopTick) { content, hop in
                content.offset(y: -hop)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(height * 0.16, duration: 0.12)
                    CubicKeyframe(0, duration: 0.16)
                    CubicKeyframe(height * 0.05, duration: 0.07)
                    CubicKeyframe(0, duration: 0.08)
                }
            }
            .background(alignment: .bottom) { shadow(lift: pose.lift) }
    }

    private func still(mouthOpen: Bool) -> some View {
        sprite(mouthOpen: mouthOpen)
            .background(alignment: .bottom) { shadow(lift: 0) }
    }

    /// A small ground shadow that shrinks as the sprite lifts, so the bounce reads as a bounce.
    private func shadow(lift: CGFloat) -> some View {
        Ellipse()
            .fill(Color.black.opacity(0.18))
            .frame(width: height * 0.55 * (1 - min(lift / max(height, 1), 0.3)), height: max(height * 0.07, 3))
            .offset(y: 2)
            .accessibilityHidden(true)
    }

    private func sprite(mouthOpen: Bool) -> some View {
        Image(mouthOpen ? crew.talkAssetName : crew.portraitAssetName)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            // Instant cut. A linear animation on the frame smears two poses and fights nearest-neighbor.
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}
