import AVFoundation
import BeckifyMath
import Foundation
import Speech

/// Conversation Mode. Two people, two languages, one translator each.
///
/// Local: one phone, the turn passes after each line.
/// Linked: each person has a phone. The sender posts the words, and the receiving
/// phone translates and speaks them with the character that person picked.
@MainActor
final class CrewTalkConversationModel: ObservableObject {
    enum Stage: Equatable {
        case setup
        case local
        case linked
    }

    enum Phase: Equatable {
        case idle
        case starting
        case listening
        case translating
        case preparingVoice
        case playing
        case failed
    }

    enum Connection: Equatable {
        case connecting
        case connected
        case reconnecting
        case lost
    }

    /// One line on screen. `side` is the seat index (local) or 0 = me, 1 = partner (linked).
    struct Entry: Identifiable, Equatable {
        let id = UUID()
        var side: Int
        /// What this person reads or hears.
        var text: String
        /// What the speaker actually said. Empty for lines you sent.
        var original: String
    }

    // MARK: Published state

    @Published private(set) var stage: Stage = .setup
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var liveTranscript = ""
    @Published var errorMessage: String?

    @Published private(set) var localTalk = CrewTalkLocalConversation()

    @Published var linkLanguage: CrewTalkConversationLanguage = .english
    @Published var linkCrew: CrewTalkMember = CrewTalkConversationLanguage.english.defaultCrew
    @Published private(set) var session: CrewTalkRoomSession?
    @Published private(set) var connection: Connection = .connecting
    @Published private(set) var partnerLanguage: CrewTalkConversationLanguage?
    @Published private(set) var partnerOnline = false
    @Published private(set) var isConnectingRoom = false

    // MARK: Private state

    private let capture = CrewTalkSpeechCapture()
    private let output = CrewTalkSpeechOutput()
    private var turn: UInt64 = 0
    private var eventTask: Task<Void, Never>?
    private var incoming: [(language: CrewTalkConversationLanguage, text: String)] = []
    private var seenMessageIDs = Set<String>()
    private var isDraining = false

    // MARK: Derived

    var speakerLanguage: CrewTalkConversationLanguage {
        stage == .linked ? (session?.language ?? linkLanguage) : localTalk.speaker.language
    }

    /// Whose voice is playing, or who will play next. Drives the sprites.
    var talkingCrew: CrewTalkMember? {
        guard phase == .playing else { return nil }
        return stage == .linked ? linkCrew : localTalk.listener.crew
    }

    var statusText: String {
        switch phase {
        case .idle: return ""
        case .starting: return "Getting the mic ready…"
        case .listening: return "Listening…"
        case .translating: return "Translating…"
        case .preparingVoice: return "Getting the voice ready…"
        case .playing: return "Speaking…"
        case .failed: return "Didn't work. Try again."
        }
    }

    var canTalk: Bool {
        if stage == .linked {
            return session != nil && partnerLanguage != nil && connection != .lost
        }
        return stage == .local
    }

    var micLabel: String {
        switch phase {
        case .listening: return "Tap when done"
        case .starting: return "Getting ready…"
        case .translating, .preparingVoice, .playing: return "Skip"
        case .idle, .failed:
            if stage == .linked { return "Tap to talk" }
            return "\(localTalk.speaker.language.label) · tap to talk"
        }
    }

    // MARK: Setup

    func startLocal(englishCrew: CrewTalkMember, spanishCrew: CrewTalkMember) {
        resetConversation()
        localTalk = CrewTalkLocalConversation(englishCrew: englishCrew, spanishCrew: spanishCrew)
        stage = .local
    }

    func setLocalCrew(_ crew: CrewTalkMember, seat: Int) {
        var next = localTalk
        if next.setCrew(crew, forSeat: seat) { localTalk = next }
    }

    func setLinkLanguage(_ language: CrewTalkConversationLanguage) {
        linkLanguage = language
        linkCrew = language.resolvedCrew(linkCrew)
    }

    func startRoom() async {
        await connectRoom { try await CrewTalkRoomClient.create(language: self.linkLanguage) }
    }

    func joinRoom(code: String) async {
        guard CrewTalkRoomCode.isComplete(code) else {
            errorMessage = "Enter the 6-character room code."
            return
        }
        await connectRoom { try await CrewTalkRoomClient.join(code: code, language: self.linkLanguage) }
    }

    private func connectRoom(_ open: () async throws -> CrewTalkRoomSession) async {
        guard !isConnectingRoom else { return }
        isConnectingRoom = true
        errorMessage = nil
        defer { isConnectingRoom = false }
        do {
            let opened = try await open()
            resetConversation()
            session = opened
            partnerLanguage = opened.partnerLanguage
            partnerOnline = false
            connection = .connecting
            stage = .linked
            listen(to: opened)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Back to the setup screen. Leaves the room if linked.
    func endConversation() {
        resetConversation()
        stage = .setup
    }

    /// The screen went away or the app left the foreground.
    func interrupt() {
        turn &+= 1
        capture.cancel()
        output.stop()
        liveTranscript = ""
        if phase != .idle { phase = .idle }
    }

    func shutdown() {
        resetConversation()
        stage = .setup
    }

    private func resetConversation() {
        interrupt()
        eventTask?.cancel()
        eventTask = nil
        if let leaving = session {
            Task { await CrewTalkRoomClient.leave(leaving) }
        }
        session = nil
        partnerLanguage = nil
        partnerOnline = false
        connection = .connecting
        entries = []
        incoming = []
        seenMessageIDs = []
        errorMessage = nil
        localTalk = CrewTalkLocalConversation(
            englishCrew: localTalk.seats[0].crew,
            spanishCrew: localTalk.seats[1].crew
        )
    }

    // MARK: Talking

    func tapTalk() {
        switch phase {
        case .listening:
            Task { await finishListening() }
        case .idle, .failed:
            Task { await beginListening() }
        case .translating, .preparingVoice, .playing:
            interrupt()
            Task { await drainIncoming() }
        case .starting:
            break
        }
    }

    func sendTyped(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, canTalk, phase == .idle || phase == .failed else { return }
        errorMessage = nil
        Task { await handleSpoken(text) }
    }

    private func beginListening() async {
        guard canTalk else { return }
        errorMessage = nil
        phase = .starting
        let status = await CrewTalkSpeechCapture.requestAuthorization()
        guard phase == .starting else { return }
        switch status {
        case .authorized:
            break
        case .denied, .restricted:
            fail("Enable Speech Recognition for Beckify in Settings, or type instead.")
            return
        default:
            fail("Allow Speech Recognition when prompted, or type instead.")
            return
        }
        output.stop()
        capture.onPartial = { [weak self] heard in
            self?.liveTranscript = heard
        }
        do {
            try capture.start(language: speakerLanguage)
            liveTranscript = ""
            phase = .listening
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func finishListening() async {
        guard phase == .listening else { return }
        let heard = await capture.stop()
        liveTranscript = ""
        guard phase == .listening else { return }
        phase = .idle
        guard !heard.isEmpty else {
            errorMessage = "Didn't catch that. Try again."
            await drainIncoming()
            return
        }
        await handleSpoken(heard)
    }

    private func handleSpoken(_ text: String) async {
        if stage == .linked {
            await sendToRoom(text)
        } else {
            let speaker = localTalk.speaker
            let listener = localTalk.listener
            let delivered = await deliver(
                text: text,
                from: speaker.language,
                crew: listener.crew,
                side: localTalk.speakerIndex
            )
            if delivered { localTalk.passTurn() }
        }
    }

    private func sendToRoom(_ text: String) async {
        guard let session else { return }
        do {
            try await CrewTalkRoomClient.send(text, in: session)
            entries.append(Entry(side: 0, text: text, original: ""))
        } catch {
            errorMessage = error.localizedDescription
        }
        await drainIncoming()
    }

    // MARK: Translate and speak

    /// Translate `text` for the listener, show it, and speak it in the listener's character.
    /// Returns true when the line played to the end.
    @discardableResult
    private func deliver(
        text: String,
        from language: CrewTalkConversationLanguage,
        crew: CrewTalkMember,
        side: Int
    ) async -> Bool {
        turn &+= 1
        let token = turn
        phase = .translating
        errorMessage = nil
        do {
            let draft = try await CrewTalkTranslationService.translate(text, from: language, listener: crew)
            guard token == turn else { return false }
            let lines = CrewTalkConversation.lines(
                sourceText: text,
                translation: draft.translation,
                from: language,
                listenerCrew: crew
            )
            entries.append(Entry(side: side, text: lines.display, original: text))
            phase = .preparingVoice
            do {
                let audio = try await CrewTalkTranslationService.speechAudio(lines.speak, crew: crew)
                guard token == turn else { return false }
                phase = .playing
                try await output.play(audio: audio)
            } catch {
                guard token == turn else { return false }
                phase = .playing
                await output.speak(apple: lines.speak, crew: crew)
            }
            guard token == turn else { return false }
            phase = .idle
            return true
        } catch {
            guard token == turn else { return false }
            fail(error.localizedDescription)
            return false
        }
    }

    private func fail(_ message: String) {
        capture.cancel()
        liveTranscript = ""
        phase = .failed
        errorMessage = message
    }

    // MARK: Linked room

    private func listen(to opened: CrewTalkRoomSession) {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                do {
                    for try await event in CrewTalkRoomClient.events(for: opened) {
                        guard let self else { return }
                        attempt = 0
                        self.handle(event)
                    }
                } catch let error as CrewTalkConversationError where error.fatal {
                    self?.roomEnded(error.message)
                    return
                } catch {
                    if Task.isCancelled { return }
                }
                if Task.isCancelled { return }
                attempt += 1
                guard let self else { return }
                if attempt > 6 {
                    self.roomEnded("Lost the connection. Leave and start again.")
                    return
                }
                self.connection = .reconnecting
                try? await Task.sleep(nanoseconds: UInt64(min(attempt, 5)) * 1_500_000_000)
            }
        }
    }

    private func roomEnded(_ message: String) {
        connection = .lost
        partnerOnline = false
        errorMessage = message
    }

    private func handle(_ event: CrewTalkRoomEvent) {
        switch event {
        case .ready(let partner, let online):
            connection = .connected
            if let partner { partnerLanguage = partner }
            partnerOnline = online
        case .peer(let language, let online):
            partnerLanguage = language
            partnerOnline = online
        case .message(let id, let language, let text):
            guard seenMessageIDs.insert(id).inserted else { return }
            incoming.append((language: language, text: text))
            Task { await drainIncoming() }
        case .closed:
            roomEnded("That room has ended.")
        }
    }

    /// Speak queued messages one at a time, only while the mic and speaker are free.
    private func drainIncoming() async {
        guard stage == .linked, !isDraining else { return }
        isDraining = true
        defer { isDraining = false }
        while stage == .linked, phase == .idle || phase == .failed, !incoming.isEmpty {
            let next = incoming.removeFirst()
            await deliver(text: next.text, from: next.language, crew: linkCrew, side: 1)
        }
    }
}
