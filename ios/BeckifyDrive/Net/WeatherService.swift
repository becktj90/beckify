import BeckifyMath
import Foundation

/// Current temperature and wind near the car, for the weather-adjusted range card.
protocol WeatherProviding: AnyObject {
    var current: OpenMeteoCurrent? { get }
    var status: WeatherStatus { get }
    func refreshIfNeeded(at point: GeoPoint, now: Date)
}

enum WeatherStatus: Equatable {
    case idle
    case loading
    /// The last request failed; `current` (if any) is the cached reading.
    case failed
}

/// Open-Meteo (no key). Sends only a location rounded to 0.01°. The last
/// reading is cached in UserDefaults so the card has something offline.
/// Never blocks the dashboard: every request runs in the background.
final class WeatherService: ObservableObject, WeatherProviding {
    @Published private(set) var current: OpenMeteoCurrent?
    @Published private(set) var status: WeatherStatus = .idle

    /// After a failure, wait this long before trying again.
    private static let retryAfter: TimeInterval = 120
    private static let cacheKey = "beckify.drive.weather.current"

    private let session: URLSession?
    private let defaults: UserDefaults?
    private var task: Task<Void, Never>?
    private var lastAttempt: Date?

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.cacheKey) {
            current = try? JSONDecoder().decode(OpenMeteoCurrent.self, from: data)
        }
    }

    /// Fixture service for previews. Never touches the network.
    init(preview current: OpenMeteoCurrent?, status: WeatherStatus = .idle) {
        session = nil
        defaults = nil
        self.current = current
        self.status = status
    }

    deinit {
        task?.cancel()
    }

    func refreshIfNeeded(at point: GeoPoint, now: Date) {
        guard let session, task == nil else { return }
        if let current, !current.needsRefresh(now: now, latitude: point.latitude, longitude: point.longitude) { return }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < Self.retryAfter { return }
        guard let url = OpenMeteoCurrent.requestURL(latitude: point.latitude, longitude: point.longitude) else { return }
        lastAttempt = now
        status = .loading
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        // Runs on the main actor; only the network await leaves it.
        task = Task { @MainActor [weak self] in
            let reading: OpenMeteoCurrent?
            do {
                let (data, response) = try await session.data(for: request)
                let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
                reading = ok ? OpenMeteoCurrent.decode(data, fetchedAt: Date()) : nil
            } catch {
                reading = nil
            }
            self?.finish(reading)
        }
    }

    private func finish(_ reading: OpenMeteoCurrent?) {
        task = nil
        guard let reading else {
            status = .failed
            return
        }
        current = reading
        status = .idle
        if let data = try? JSONEncoder().encode(reading) {
            defaults?.set(data, forKey: Self.cacheKey)
        }
    }
}
