import Foundation

/// Captive-portal / local-connectivity verdict. Not RSSI and not dBm.
public enum LookCheckKind: String, Equatable, Sendable {
    case checking = "Checking"
    case online = "Online"
    case captive = "Captive"
    case localOnly = "Local only"
    case offline = "Offline"
    case unclear = "Unclear"
}

/// NWPath facts the verdict is allowed to use. No interface names, no invented RF.
public struct LookCheckPathContext: Equatable, Sendable {
    public var satisfied: Bool
    public var usesWiFi: Bool
    public var usesCellular: Bool
    public var usesWired: Bool

    public init(
        satisfied: Bool,
        usesWiFi: Bool = false,
        usesCellular: Bool = false,
        usesWired: Bool = false
    ) {
        self.satisfied = satisfied
        self.usesWiFi = usesWiFi
        self.usesCellular = usesCellular
        self.usesWired = usesWired
    }

    public var fingerprint: String {
        [
            satisfied ? "up" : "down",
            usesWiFi ? "wifi" : nil,
            usesCellular ? "cell" : nil,
            usesWired ? "wired" : nil,
        ].compactMap { $0 }.joined(separator: "|")
    }

    public var transportLabel: String {
        var parts: [String] = []
        if usesWiFi { parts.append("Wi-Fi") }
        if usesCellular { parts.append("cellular") }
        if usesWired { parts.append("wired") }
        return parts.isEmpty ? "—" : parts.joined(separator: " + ")
    }
}

/// Parsed HTTP/1.x response from the Look Check probe. Body is decoded text.
public struct LookCheckHTTPResponse: Equatable, Sendable {
    public var status: Int
    public var reason: String
    public var headers: [String: String]
    public var body: String
    public var raw: String

    public init(status: Int, reason: String, headers: [String: String], body: String, raw: String) {
        self.status = status
        self.reason = reason
        self.headers = headers
        self.body = body
        self.raw = raw
    }

    public var location: String? { headers["location"] }
}

/// Field-facing Look Check result. Copy stays connectivity-honest — never a dBm row.
public struct LookCheckVerdict: Equatable, Sendable {
    public var kind: LookCheckKind
    public var headline: String
    public var detail: String
    public var transportLabel: String
    public var httpStatus: Int?
    public var probeHost: String
    public var localIPv4: String?
    public var localAddress: String?

    public init(
        kind: LookCheckKind,
        headline: String,
        detail: String,
        transportLabel: String,
        httpStatus: Int? = nil,
        probeHost: String = LookCheck.probeHost,
        localIPv4: String? = nil,
        localAddress: String? = nil
    ) {
        self.kind = kind
        self.headline = headline
        self.detail = detail
        self.transportLabel = transportLabel
        self.httpStatus = httpStatus
        self.probeHost = probeHost
        self.localIPv4 = localIPv4
        self.localAddress = localAddress
    }

    public var copyLine: String {
        var parts = ["Look Check: \(headline)"]
        if transportLabel != "—" { parts.append(transportLabel) }
        if let ip = localIPv4 { parts.append("local IPv4 \(ip)") }
        else if let addr = localAddress { parts.append("local \(addr)") }
        return parts.joined(separator: " · ")
    }
}

/// App Store–safe captive / local-connectivity helpers.
/// Probe target is Apple’s public hotspot-detect page. This is not a speed test
/// and not a substitute for Wi-Fi RSSI/dBm (which iOS does not expose).
public enum LookCheck {
    public static let probeHost = "captive.apple.com"
    public static let probePath = "/hotspot-detect.html"
    public static let probePort = 80
    public static let expectedToken = "Success"
    public static let userAgent = "Beckify-LookCheck"

    public static func httpRequest() -> String {
        "GET \(probePath) HTTP/1.1\r\nHost: \(probeHost)\r\nAccept: */*\r\nConnection: close\r\nUser-Agent: \(userAgent)\r\n\r\n"
    }

    public static func classify(
        path: LookCheckPathContext,
        response: LookCheckHTTPResponse?,
        connected: Bool,
        localEndpoint: String? = nil
    ) -> LookCheckVerdict {
        let ipv4 = ipv4Host(fromEndpoint: localEndpoint)
        let address = hostFromEndpoint(localEndpoint)
        let transport = path.transportLabel

        func verdict(
            _ kind: LookCheckKind,
            headline: String,
            detail: String,
            status: Int? = nil
        ) -> LookCheckVerdict {
            LookCheckVerdict(
                kind: kind,
                headline: headline,
                detail: detail,
                transportLabel: transport,
                httpStatus: status,
                localIPv4: ipv4,
                localAddress: address
            )
        }

        if !path.satisfied {
            return verdict(
                .offline,
                headline: "No path",
                detail: "No satisfied network path. Look Check stays blank until a path is up. This is not a signal reading."
            )
        }

        if let response {
            if isAppleSuccess(response) {
                return verdict(
                    .online,
                    headline: "No captive portal",
                    detail: "Apple hotspot-detect returned Success. No captive splash on this path. Not a speed test and not RSSI.",
                    status: response.status
                )
            }
            if isRedirect(response.status) || looksLikePortalPage(response) {
                return verdict(
                    .captive,
                    headline: "Captive portal",
                    detail: "The probe was redirected or did not return Apple’s Success page. Typical guest / hotel splash — open Safari to sign in. This is not a signal reading.",
                    status: response.status
                )
            }
            return verdict(
                .unclear,
                headline: "Unclear",
                detail: "The probe answered but it was not Apple’s Success page and not a clear splash redirect. The tool will not guess. Try Safari.",
                status: response.status
            )
        }

        if connected {
            return verdict(
                .unclear,
                headline: "Unclear",
                detail: "TCP reached the look-check host but the HTTP body was empty or unreadable. The tool will not invent a verdict. Try Safari."
            )
        }

        return verdict(
            .localOnly,
            headline: "Local only",
            detail: "The path looks up, but captive.apple.com did not answer. Isolated LAN, DNS fail, or a portal that black-holes HTTP. Not RSSI and not dBm."
        )
    }

    public static func isAppleSuccess(_ response: LookCheckHTTPResponse) -> Bool {
        guard (200...299).contains(response.status) else { return false }
        let words = visibleText(response.body)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        return !words.isEmpty && words.allSatisfy {
            $0.compare(expectedToken, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    public static func isRedirect(_ status: Int) -> Bool {
        [301, 302, 303, 307, 308].contains(status)
    }

    public static func looksLikePortalPage(_ response: LookCheckHTTPResponse) -> Bool {
        guard (200...299).contains(response.status) else { return false }
        let lower = response.body.lowercased()
        if lower.contains("<form") { return true }
        if lower.contains("login") { return true }
        if lower.contains("accept") && lower.contains("terms") { return true }
        if visibleText(response.body).count > 80 { return true }
        return false
    }

    public static func visibleText(_ html: String) -> String {
        var out = ""
        var inTag = false
        for ch in html {
            if ch == "<" {
                inTag = true
                if let last = out.last, !last.isWhitespace {
                    out.append(" ")
                }
                continue
            }
            if ch == ">" {
                inTag = false
                continue
            }
            if !inTag { out.append(ch) }
        }
        return out
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
    }

    public static func parseHTTPResponse(_ raw: String) -> LookCheckHTTPResponse? {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        guard let sep = normalized.range(of: "\n\n") else { return nil }
        let headerBlock = String(normalized[..<sep.lowerBound])
        var body = String(normalized[sep.upperBound...])
        let headerLines = headerBlock.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = headerLines.first else { return nil }
        let parts = first.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2, parts[0].hasPrefix("HTTP/"), let status = Int(parts[1]) else { return nil }
        let reason = parts.count >= 3 ? parts[2] : ""
        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { headers[key] = value }
        }
        if headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            body = decodeChunkedBody(body)
        }
        if let len = contentLength(from: headers), body.utf8.count > len {
            let bytes = Array(body.utf8.prefix(len))
            body = String(decoding: bytes, as: UTF8.self)
        }
        return LookCheckHTTPResponse(
            status: status,
            reason: reason,
            headers: headers,
            body: body,
            raw: raw
        )
    }

    public static func contentLength(from headers: [String: String]) -> Int? {
        guard let raw = headers["content-length"], let n = Int(raw), n >= 0 else { return nil }
        return n
    }

    /// True when headers are in and `Content-Length` bytes have arrived.
    /// Without a length, the caller waits for the connection to close.
    public static func hasCompleteHTTPMessage(_ raw: String) -> Bool {
        guard let parsed = parseHTTPResponse(raw) else { return false }
        if parsed.headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
            return normalized.contains("\n0\n") || normalized.contains("\n0\n\n")
        }
        guard let len = contentLength(from: parsed.headers) else { return false }
        return parsed.body.utf8.count >= len
    }

    public static func decodeChunkedBody(_ body: String) -> String {
        var rest = body.replacingOccurrences(of: "\r\n", with: "\n")
        var out = ""
        while !rest.isEmpty {
            guard let nl = rest.firstIndex(of: "\n") else { break }
            let sizeLine = rest[..<nl].trimmingCharacters(in: .whitespacesAndNewlines)
            let sizeHex = sizeLine.split(separator: ";")[0]
            guard let size = Int(sizeHex, radix: 16) else { break }
            rest = String(rest[rest.index(after: nl)...])
            if size == 0 { break }
            guard let end = rest.index(rest.startIndex, offsetBy: size, limitedBy: rest.endIndex) else { break }
            out += String(rest[rest.startIndex..<end])
            rest = String(rest[end...])
            if rest.hasPrefix("\n") { rest.removeFirst() }
        }
        return out
    }

    public static func hostFromLocation(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("/") { return probeHost }
        if s.hasPrefix("//") { s = "http:" + s }
        if let url = URL(string: s), let host = url.host, !host.isEmpty {
            return host.lowercased()
        }
        return nil
    }

    public static func isAppleLocation(_ location: String?) -> Bool {
        guard let location, let host = hostFromLocation(location) else { return false }
        return host == probeHost || host.hasSuffix(".\(probeHost)")
    }

    public static func hostFromEndpoint(_ endpoint: String?) -> String? {
        guard let endpoint else { return nil }
        let s = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("[") {
            guard let close = s.firstIndex(of: "]") else { return nil }
            let host = String(s[s.index(after: s.startIndex)..<close])
            return host.isEmpty ? nil : host
        }
        let colonCount = s.filter { $0 == ":" }.count
        if colonCount == 1, let idx = s.lastIndex(of: ":") {
            let host = String(s[..<idx])
            return host.isEmpty ? nil : host
        }
        if colonCount == 0 { return s }
        return s
    }

    public static func ipv4Host(fromEndpoint endpoint: String?) -> String? {
        guard let host = hostFromEndpoint(endpoint), isIPv4(host) else { return nil }
        return host
    }

    public static func isIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4 else { return false }
        let octets = parts.compactMap { Int($0) }
        guard octets.count == 4, zip(parts, octets).allSatisfy({ $0.0 == String($0.1) }) else { return false }
        return octets.allSatisfy { (0...255).contains($0) }
    }
}
