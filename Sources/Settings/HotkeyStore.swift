import Foundation

/// Holds the action -> key combination bindings and persists them.
public final class HotkeyStore {
    private let defaults: UserDefaults
    private let storageKey: String
    public private(set) var bindings: [HotkeyAction: KeyCombo]

    public init(defaults: UserDefaults = .standard, storageKey: String = "hotkeyBindings") {
        self.defaults = defaults
        self.storageKey = storageKey
        var loaded = KeyCombo.defaults
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([HotkeyAction: KeyCombo].self, from: data) {
            loaded.merge(stored) { _, new in new }
        }
        self.bindings = loaded
    }

    public func combo(for action: HotkeyAction) -> KeyCombo {
        bindings[action] ?? KeyCombo.defaults[action]!
    }

    public func set(_ combo: KeyCombo, for action: HotkeyAction) {
        bindings[action] = combo
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
