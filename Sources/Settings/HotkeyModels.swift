import Carbon.HIToolbox
import Foundation

public enum HotkeyAction: String, CaseIterable, Codable, Sendable {
    case snip
}

/// A key combination expressed in Carbon terms (virtual key code + Carbon modifier mask).
public struct KeyCombo: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let defaults: [HotkeyAction: KeyCombo] = [
        // Option-only combinations are rejected by macOS 15.0 and 15.1; macOS 15.2 and later accept them.
        .snip: KeyCombo(keyCode: UInt32(kVK_ANSI_Slash), modifiers: UInt32(optionKey)),
    ]
}

public enum HotkeyError: Error, Equatable {
    case registrationFailed(OSStatus)
}
