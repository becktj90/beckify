import Foundation
import Combine

/// On-device recent tool history for the home launcher. Not analytics.
@MainActor
final class RecentsStore: ObservableObject {
    @Published private(set) var recentIDs: [ToolID] = []

    private let key = "com.beckify.toolbox.recentTools"
    private let limit = 8
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(_ id: ToolID) {
        guard id != .powerWizard else { return }
        var next = recentIDs.filter { $0 != id }
        next.insert(id, at: 0)
        if next.count > limit { next = Array(next.prefix(limit)) }
        recentIDs = next
        persist()
    }

    var tools: [ToolDefinition] {
        recentIDs.map(ToolboxCatalog.tool)
    }

    private func load() {
        guard let raw = defaults.array(forKey: key) as? [String] else { return }
        recentIDs = raw.compactMap(ToolID.init(rawValue:))
    }

    private func persist() {
        defaults.set(recentIDs.map(\.rawValue), forKey: key)
    }
}
