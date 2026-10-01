import Foundation
import BeckifyMath

/// On-device pinned / favorites list — one-tap access from home Pinned strip and Favorites tab.
/// Ordered; not synced; nothing leaves the device.
@MainActor
final class FavoritesStore: ObservableObject {
    /// Pin order (newest pin first when toggled on).
    @Published private(set) var orderedIDs: [ToolID] = []

    /// Membership set for cheap lookups and animation identity.
    var ids: Set<ToolID> { Set(orderedIDs) }

    private let key = "com.beckify.toolbox.favorites"
    private let defaults: UserDefaults

    /// First-launch / empty-store seeds — former Field Quick strip, editable after.
    private static let defaultPinnedRaw: [String] = ToolHomeAreaPolicy.fieldQuickIDs

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isFavorite(_ id: ToolID) -> Bool {
        orderedIDs.contains(id)
    }

    func toggle(_ id: ToolID) {
        if let idx = orderedIDs.firstIndex(of: id) {
            orderedIDs.remove(at: idx)
        } else {
            orderedIDs.insert(id, at: 0)
        }
        persist()
    }

    /// Reorder within the Favorites tab edit mode.
    func move(from offsets: IndexSet, to destination: Int) {
        orderedIDs.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    private func load() {
        // Missing key → first launch: seed former Quick strip (editable).
        // Empty array → user cleared every pin; respect that.
        guard let raw = defaults.stringArray(forKey: key) else {
            orderedIDs = Self.defaultPinnedRaw.compactMap(ToolID.init(rawValue:))
            persist()
            return
        }
        var seen = Set<ToolID>()
        orderedIDs = raw.compactMap { ToolID(rawValue: $0) }.filter { seen.insert($0).inserted }
    }

    private func persist() {
        defaults.set(orderedIDs.map(\.rawValue), forKey: key)
    }
}
