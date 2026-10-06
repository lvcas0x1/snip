import Foundation

public enum ImageFormat: String, Codable, CaseIterable, Sendable {
    case png
    case jpeg
}

public struct SettingsValues: Codable, Equatable, Sendable {
    public var imageFormat: ImageFormat = .png
    public var autoSaveFolder: String = SettingsValues.defaultFolder("Auto")
    public var autoSaveEnabled: Bool = false
    /// Text with `{...}` groups; each group is a `DateFormatter` pattern, e.g. `Snip {yyyy-MM-dd HH.mm.ss}`.
    public var filenamePattern: String = "Snip {yyyy-MM-dd HH.mm.ss}"
    /// Font family for interface text; `nil` means the system font.
    public var interfaceFontFamily: String?

    public init() {}

    static func defaultFolder(_ name: String) -> String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Pictures/Snip/\(name)")
    }
}

/// Persists user settings as JSON in `UserDefaults`; missing keys fall back to defaults.
public final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let storageKey: String

    @Published public var values: SettingsValues {
        didSet { persist() }
    }

    public init(defaults: UserDefaults = .standard, storageKey: String = "settingsValues") {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(SettingsValues.self, from: data) {
            values = decoded
        } else {
            values = SettingsValues()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
