import Foundation
import SwiftUI

/// Remembers recently opened tools for the home launcher.
@MainActor
final class RecentToolsStore: ObservableObject {
    static let shared = RecentToolsStore()

    private let defaultsKey = "com.beckify.toolbox.recentTools"
    private let limit = 5

    @Published private(set) var recentIDs: [ToolID] = []

    init() {
        let raw = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        recentIDs = Array(raw.compactMap(ToolID.init(rawValue:)).prefix(limit))
    }

    func record(_ id: ToolID) {
        guard id != .powerWizard else { return }
        var next = recentIDs.filter { $0 != id }
        next.insert(id, at: 0)
        if next.count > limit { next = Array(next.prefix(limit)) }
        recentIDs = next
        UserDefaults.standard.set(next.map(\.rawValue), forKey: defaultsKey)
    }

    var tools: [ToolDefinition] {
        recentIDs.map(ToolboxCatalog.tool)
    }
}
