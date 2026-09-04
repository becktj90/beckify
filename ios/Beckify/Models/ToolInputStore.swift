import SwiftUI
import BeckifyMath

/// On-device last-used inputs, keyed per tool. Not a cloud project, not analytics.
enum ToolInputStore {
    static let prefix = "com.beckify.toolbox.input."

    static func key(_ tool: ToolID, _ field: String) -> String {
        prefix + tool.rawValue + "." + field
    }

    /// Best-effort restore of a saved job into the tool's last-used fields.
    /// Unknown or empty keys are skipped. Does not block opening the tool.
    static func restore(from job: SavedJob, defaults: UserDefaults = .standard) {
        if !job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(job.name, forKey: key(job.toolID, "jobName"))
        }
        let fields = ToolHomeAreaPolicy.storedFields(toolID: job.toolID.rawValue, inputs: job.inputs)
        for (field, value) in fields {
            defaults.set(value, forKey: key(job.toolID, field))
        }
    }
}

/// String field persisted in UserDefaults / AppStorage for one tool.
@propertyWrapper
struct StoredInput: DynamicProperty {
    @AppStorage private var value: String

    init(_ tool: ToolID, _ field: String, default defaultValue: String) {
        _value = AppStorage(wrappedValue: defaultValue, ToolInputStore.key(tool, field))
    }

    var wrappedValue: String {
        get { value }
        nonmutating set { value = newValue }
    }

    var projectedValue: Binding<String> { $value }
}

/// Bool field persisted per tool.
@propertyWrapper
struct StoredToggle: DynamicProperty {
    @AppStorage private var value: Bool

    init(_ tool: ToolID, _ field: String, default defaultValue: Bool) {
        _value = AppStorage(wrappedValue: defaultValue, ToolInputStore.key(tool, field))
    }

    var wrappedValue: Bool {
        get { value }
        nonmutating set { value = newValue }
    }

    var projectedValue: Binding<Bool> { $value }
}

/// Int field persisted per tool.
@propertyWrapper
struct StoredCount: DynamicProperty {
    @AppStorage private var value: Int

    init(_ tool: ToolID, _ field: String, default defaultValue: Int) {
        _value = AppStorage(wrappedValue: defaultValue, ToolInputStore.key(tool, field))
    }

    var wrappedValue: Int {
        get { value }
        nonmutating set { value = newValue }
    }

    var projectedValue: Binding<Int> { $value }
}

/// Double field persisted per tool.
@propertyWrapper
struct StoredNumber: DynamicProperty {
    @AppStorage private var value: Double

    init(_ tool: ToolID, _ field: String, default defaultValue: Double) {
        _value = AppStorage(wrappedValue: defaultValue, ToolInputStore.key(tool, field))
    }

    var wrappedValue: Double {
        get { value }
        nonmutating set { value = newValue }
    }

    var projectedValue: Binding<Double> { $value }
}

/// String-backed enum persisted per tool.
@propertyWrapper
struct StoredChoice<Value: RawRepresentable>: DynamicProperty where Value.RawValue == String {
    @AppStorage private var raw: String
    private let fallback: Value

    init(_ tool: ToolID, _ field: String, default defaultValue: Value) {
        fallback = defaultValue
        let key = ToolInputStore.key(tool, field)
        if let stored = UserDefaults.standard.string(forKey: key),
           Value(rawValue: stored) == nil {
            UserDefaults.standard.set(defaultValue.rawValue, forKey: key)
        }
        _raw = AppStorage(wrappedValue: defaultValue.rawValue, key)
    }

    var wrappedValue: Value {
        get { Value(rawValue: raw) ?? fallback }
        nonmutating set { raw = newValue.rawValue }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

enum CalcCatch {
    static func run<T>(_ body: () throws -> T) -> Result<T, CalcError> {
        do {
            return .success(try body())
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }
}
