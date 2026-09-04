import Combine
import Network
import BeckifyMath

/// Outcome of one App Store–safe HTTP look-check probe. Not RSSI and not dBm.
struct LookCheckProbeOutcome: Equatable {
    var response: LookCheckHTTPResponse?
    var connected: Bool
    var localEndpoint: String?
    var elapsedMS: Double
}

private final class LookCheckProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var sawReady = false
    private var buffer = Data()

    func markFinished() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }

    func markReady() {
        lock.lock()
        sawReady = true
        lock.unlock()
    }

    func append(_ data: Data) -> Data {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        return buffer
    }

    func snapshot() -> (buffer: Data, connected: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (buffer, sawReady)
    }
}

/// Plain HTTP GET to Apple’s hotspot-detect host via Network.framework.
/// Avoids an ATS exception: this is a TCP probe, not URLSession cleartext.
enum LookCheckClient {
    static func probe(
        timeout: TimeInterval = 5,
        requiredInterface: Network.NWInterface.InterfaceType? = nil
    ) async -> LookCheckProbeOutcome {
        guard let port = Network.NWEndpoint.Port(rawValue: UInt16(clamping: LookCheck.probePort)) else {
            return LookCheckProbeOutcome(response: nil, connected: false, localEndpoint: nil, elapsedMS: 0)
        }
        let parameters = Network.NWParameters.tcp
        if let requiredInterface {
            parameters.requiredInterfaceType = requiredInterface
        }
        let connection = Network.NWConnection(
            host: Network.NWEndpoint.Host(LookCheck.probeHost),
            port: port,
            using: parameters
        )
        return await withCheckedContinuation { continuation in
            let state = LookCheckProbeState()
            let start = CFAbsoluteTimeGetCurrent()

            @Sendable func finish() {
                guard state.markFinished() else { return }
                let local = WiFiRTTClient.endpointSummary(connection.currentPath?.localEndpoint)
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                connection.stateUpdateHandler = nil
                connection.cancel()
                let snap = state.snapshot()
                let text = snap.buffer.isEmpty
                    ? ""
                    : (String(data: snap.buffer, encoding: .utf8) ?? String(decoding: snap.buffer, as: UTF8.self))
                let parsed = text.isEmpty ? nil : LookCheck.parseHTTPResponse(text)
                continuation.resume(returning: LookCheckProbeOutcome(
                    response: parsed,
                    connected: snap.connected,
                    localEndpoint: local,
                    elapsedMS: max(0, elapsed)
                ))
            }

            @Sendable func receiveLoop() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024) { data, _, isComplete, error in
                    if let data, !data.isEmpty {
                        let snapshot = state.append(data)
                        if snapshot.count > 65_536 {
                            finish()
                            return
                        }
                        let text = String(data: snapshot, encoding: .utf8) ?? String(decoding: snapshot, as: UTF8.self)
                        if LookCheck.hasCompleteHTTPMessage(text) {
                            finish()
                            return
                        }
                    }
                    if isComplete || error != nil {
                        finish()
                        return
                    }
                    receiveLoop()
                }
            }

            connection.stateUpdateHandler = { connState in
                switch connState {
                case .ready:
                    if let requiredInterface {
                        guard let path = connection.currentPath, path.usesInterfaceType(requiredInterface) else {
                            finish()
                            return
                        }
                    }
                    state.markReady()
                    let req = Data(LookCheck.httpRequest().utf8)
                    connection.send(content: req, completion: .contentProcessed { error in
                        if error != nil {
                            finish()
                            return
                        }
                        receiveLoop()
                    })
                case .failed, .cancelled:
                    finish()
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                finish()
            }
        }
    }
}

@MainActor
final class LookCheckModel: ObservableObject {
    @Published private(set) var measuring = false
    @Published private(set) var verdict: LookCheckVerdict?
    @Published var message = "Online / Captive fetches Apple’s hotspot-detect page over HTTP. Success means no captive splash — not RSSI and not dBm."

    private var task: Task<Void, Never>?
    private var generation = 0
    private(set) var checkedFingerprint: String?

    var localIPv4: String? { verdict?.localIPv4 }
    var localAddress: String? { verdict?.localAddress }
    var copyLine: String? { verdict?.copyLine }

    func isStale(path: LookCheckPathContext) -> Bool {
        guard verdict != nil, !measuring else { return false }
        return checkedFingerprint != path.fingerprint
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        measuring = false
    }

    func run(path: LookCheckPathContext, force: Bool = false) {
        if !force, measuring { return }
        if !force, checkedFingerprint == path.fingerprint, verdict != nil { return }
        cancel()
        if !path.satisfied {
            let v = LookCheck.classify(path: path, response: nil, connected: false, localEndpoint: nil)
            verdict = v
            checkedFingerprint = path.fingerprint
            message = v.detail
            return
        }
        measuring = true
        message = "Checking Apple hotspot-detect… not a speed test and not RSSI."
        let capturedGeneration = generation
        task = Task { [weak self] in
            let outcome = await LookCheckClient.probe()
            await MainActor.run {
                guard let self, self.generation == capturedGeneration else { return }
                let v = LookCheck.classify(
                    path: path,
                    response: outcome.response,
                    connected: outcome.connected,
                    localEndpoint: outcome.localEndpoint
                )
                self.verdict = v
                self.checkedFingerprint = path.fingerprint
                self.measuring = false
                self.task = nil
                self.message = v.detail
            }
        }
    }
}
