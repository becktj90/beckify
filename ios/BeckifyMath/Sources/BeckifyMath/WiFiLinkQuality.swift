import Foundation

/// Latency band for TCP/HTTPS round-trip time. This is **not** RSSI and **not** dBm.
public enum WiFiRTTBand: String, Equatable, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case slow = "Slow"
    case poor = "Poor"
    case unavailable = "Unavailable"
}

/// Summary of one link-quality probe set (successful RTTs in milliseconds).
public struct WiFiRTTSummary: Equatable, Sendable {
    public var successfulMS: [Double]
    public var attempts: Int
    public var minMS: Double?
    public var medianMS: Double?
    public var meanMS: Double?
    public var maxMS: Double?
    public var lossPercent: Double
    public var band: WiFiRTTBand

    public init(
        successfulMS: [Double],
        attempts: Int,
        minMS: Double?,
        medianMS: Double?,
        meanMS: Double?,
        maxMS: Double?,
        lossPercent: Double,
        band: WiFiRTTBand
    ) {
        self.successfulMS = successfulMS
        self.attempts = attempts
        self.minMS = minMS
        self.medianMS = medianMS
        self.meanMS = meanMS
        self.maxMS = maxMS
        self.lossPercent = lossPercent
        self.band = band
    }

    public var successCount: Int { successfulMS.count }
    public var failureCount: Int { max(0, attempts - successfulMS.count) }
}

/// App Store–safe Wi-Fi *link* helpers: TCP RTT math and host parsing.
/// iOS does not expose Wi-Fi RSSI/dBm to third-party apps; do not invent dBm here.
public enum WiFiLinkQuality {
    public static let defaultPublicPort = 443
    public static let defaultLANPort = 80

    /// Summarize probe results. `nil`, NaN, or negative samples count as loss.
    public static func summarize(samplesMS: [Double?]) -> WiFiRTTSummary {
        let ok = samplesMS.compactMap { sample -> Double? in
            guard let sample, sample.isFinite, sample >= 0 else { return nil }
            return sample
        }.sorted()
        let attempts = samplesMS.count
        let failures = attempts - ok.count
        let loss = attempts == 0 ? 100.0 : (Double(failures) / Double(attempts)) * 100
        let minMS = ok.first
        let maxMS = ok.last
        let meanMS = ok.isEmpty ? nil : ok.reduce(0, +) / Double(ok.count)
        let medianMS: Double?
        if ok.isEmpty {
            medianMS = nil
        } else if ok.count % 2 == 1 {
            medianMS = ok[ok.count / 2]
        } else {
            medianMS = (ok[ok.count / 2 - 1] + ok[ok.count / 2]) / 2
        }
        return WiFiRTTSummary(
            successfulMS: ok,
            attempts: attempts,
            minMS: minMS,
            medianMS: medianMS,
            meanMS: meanMS,
            maxMS: maxMS,
            lossPercent: loss,
            band: band(medianMS: medianMS, lossPercent: loss)
        )
    }

    /// Latency quality from median RTT. 100 % loss is unavailable — never mapped to dBm.
    public static func band(medianMS: Double?, lossPercent: Double) -> WiFiRTTBand {
        if !lossPercent.isFinite || lossPercent >= 100 { return .unavailable }
        guard let medianMS, medianMS.isFinite, medianMS >= 0 else { return .unavailable }
        if medianMS < 25 { return .excellent }
        if medianMS < 60 { return .good }
        if medianMS < 120 { return .fair }
        if medianMS < 250 { return .slow }
        return .poor
    }

    /// `"1.1.1.1"`, `"beckify.com:443"`, `"https://beckify.com/path"`, `"[::1]:80"`.
    public static func parseHostPort(_ raw: String, defaultPort: Int = defaultPublicPort) -> (host: String, port: Int)? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let scheme = s.range(of: "://") {
            s = String(s[scheme.upperBound...])
        }
        if let slash = s.firstIndex(of: "/") {
            s = String(s[..<slash])
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if s.hasPrefix("[") {
            guard let close = s.firstIndex(of: "]") else { return nil }
            let host = String(s[s.index(after: s.startIndex)..<close])
            guard !host.isEmpty else { return nil }
            let rest = s[s.index(after: close)...]
            if rest.isEmpty { return (host, defaultPort) }
            guard rest.first == ":" else { return nil }
            return parsePort(rest.dropFirst()).map { (host, $0) }
        }

        let parts = s.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2 {
            let host = String(parts[0])
            guard !host.isEmpty, let port = parsePort(parts[1]) else { return nil }
            return (host, port)
        }
        if parts.count > 2 {
            return (s, defaultPort)
        }
        return (s, defaultPort)
    }

    public static func defaultPort(forHost host: String) -> Int {
        needsLocalNetworkPrompt(host: host) ? defaultLANPort : defaultPublicPort
    }

    /// Private/LAN IPv4, IPv6 ULA/link-local, localhost, and `.local` names.
    /// Those targets typically trigger iOS Local Network permission.
    public static func needsLocalNetworkPrompt(host: String) -> Bool {
        let h = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        if h.isEmpty { return false }
        if h == "localhost" || h == "::1" || h.hasSuffix(".local") { return true }
        if isPrivateOrLocalIPv4(h) { return true }
        if isLocalIPv6(h) { return true }
        return false
    }

    public static func isPrivateOrLocalIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count == 4 else { return false }
        let octets = parts.compactMap { Int($0) }
        guard octets.count == 4, zip(parts, octets).allSatisfy({ $0.0 == String($0.1) }) else { return false }
        guard octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        let a = octets[0], b = octets[1]
        if a == 10 { return true }
        if a == 127 { return true }
        if a == 169 && b == 254 { return true }
        if a == 192 && b == 168 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        return false
    }

    private static func isLocalIPv6(_ host: String) -> Bool {
        let h = host.lowercased()
        guard h.contains(":") else { return false }
        if h == "::1" { return true }
        if h.hasPrefix("fe80:") { return true }
        // Unique local fc00::/7
        if h.hasPrefix("fc") || h.hasPrefix("fd") { return true }
        return false
    }

    private static func parsePort<S: StringProtocol>(_ raw: S) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmed), (1...65535).contains(port) else { return nil }
        return port
    }
}
