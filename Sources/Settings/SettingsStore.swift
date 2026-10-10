import Foundation

public enum ImageFormat: String, Codable, CaseIterable, Sendable {
    case png
    case jpeg
}

public struct SettingsValues: Codable, Equatable, Sendable {
    public var imageFormat: ImageFormat = .png
    /// Where the Save panel opens.
    public var saveFolder: String = SettingsValues.defaultFolder("Pictures/Snip")
    /// Where Auto Save writes.
    public var autoSaveFolder: String = SettingsValues.defaultFolder("Pictures/Snip/Auto")
    public var autoSaveEnabled: Bool = false
    /// Text with `{...}` groups; each group is a `DateFormatter` pattern, e.g. `Snip {yyyy-MM-dd HH.mm.ss}`.
    public var filenamePattern: String = "Snip {yyyy-MM-dd HH.mm.ss}"
    /// Font family for interface text; `nil` means the system font.
    public var interfaceFontFamily: String?

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SettingsValues()
        imageFormat = try container.decodeIfPresent(ImageFormat.self, forKey: .imageFormat) ?? defaults.imageFormat
        saveFolder = try container.decodeIfPresent(String.self, forKey: .saveFolder) ?? defaults.saveFolder
        autoSaveFolder = try container.decodeIfPresent(String.self, forKey: .autoSaveFolder) ?? defaults.autoSaveFolder
        autoSaveEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSaveEnabled) ?? defaults.autoSaveEnabled
        filenamePattern = try container.decodeIfPresent(String.self, forKey: .filenamePattern) ?? defaults.filenamePattern
        interfaceFontFamily = try container.decodeIfPresent(String.self, forKey: .interfaceFontFamily)
    }

    static func defaultFolder(_ path: String) -> String {
        (NSHomeDirectory() as NSString).appendingPathComponent(path)
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
