import Foundation
import BeckifyMath

/// App-side bridge for Continue-with-this-design conductor seeds.
enum ConductorHandoff {
    static func save(_ seed: ConductorDesignSeed) {
        if let data = try? DesignHandoffStore.encode(seed) {
            UserDefaults.standard.set(data, forKey: DesignHandoffStore.userDefaultsKey)
        }
    }

    static func consume() -> ConductorDesignSeed? {
        guard let data = UserDefaults.standard.data(forKey: DesignHandoffStore.userDefaultsKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: DesignHandoffStore.userDefaultsKey)
        return try? DesignHandoffStore.decode(data)
    }

    static func peek() -> ConductorDesignSeed? {
        guard let data = UserDefaults.standard.data(forKey: DesignHandoffStore.userDefaultsKey) else { return nil }
        return try? DesignHandoffStore.decode(data)
    }
}

extension ResultProvenance {
    var displayName: String {
        switch self {
        case .codeRequirement: return "Code requirement"
        case .informationalNote: return "Informational note"
        case .designPreference: return "Design preference"
        case .manufacturerDependent: return "Manufacturer-dependent"
        case .engineeringApproximation: return "Engineering approximation"
        case .missingInformation: return "Missing information"
        }
    }
}
