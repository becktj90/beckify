import Foundation

/// On-device favorites list — pinned tools for one-tap access from the Favorites tab.
/// Not synced, not analytics; nothing leaves the device.
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<ToolID> = []

    private let key = "com.beckify.toolbox.favorites"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isFavorite(_ id: ToolID) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: ToolID) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        persist()
    }

    private func load() {
        guard let raw = defaults.stringArray(forKey: key) else { return }
        ids = Set(raw.compactMap(ToolID.init(rawValue:)))
    }

    private func persist() {
        defaults.set(ids.map(\.rawValue), forKey: key)
    }
}
