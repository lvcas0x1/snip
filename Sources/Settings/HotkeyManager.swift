import Carbon.HIToolbox
import Foundation

/// Registers global hotkeys with the Carbon Event Manager and dispatches presses to handlers.
public final class HotkeyManager {
    public let store: HotkeyStore
    private var handlers: [HotkeyAction: () -> Void] = [:]
    private var refs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private static let signature: OSType = 0x5343_5348 // 'SCSH'

    public init(store: HotkeyStore) {
        self.store = store
    }

    deinit {
        refs.values.forEach { UnregisterEventHotKey($0) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    public func setHandler(for action: HotkeyAction, _ handler: @escaping () -> Void) {
        handlers[action] = handler
    }

    /// Installs the event handler and registers every action's current combination.
    public func start() throws {
        try installEventHandlerIfNeeded()
        for action in HotkeyAction.allCases {
            try register(action, combo: store.combo(for: action))
        }
    }

    /// Rebinds `action`. On any failure the previous binding stays active and persisted.
    public func rebind(_ action: HotkeyAction, to combo: KeyCombo) throws {
        let previous = store.combo(for: action)
        unregister(action)
        do {
            try register(action, combo: combo)
        } catch {
            try? register(action, combo: previous)
            throw error
        }
        store.set(combo, for: action)
    }

    private func register(_ action: HotkeyAction, combo: KeyCombo) throws {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: Self.id(for: action))
        let status = RegisterEventHotKey(
            combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { throw HotkeyError.registrationFailed(status) }
        refs[action] = ref
    }

    private func unregister(_ action: HotkeyAction) {
        if let ref = refs.removeValue(forKey: action) { UnregisterEventHotKey(ref) }
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                guard result == noErr else { return result }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.fire(id: hotKeyID.id)
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler
        )
        guard status == noErr else { throw HotkeyError.registrationFailed(status) }
    }

    private func fire(id: UInt32) {
        guard let action = HotkeyAction.allCases.first(where: { Self.id(for: $0) == id }) else { return }
        handlers[action]?()
    }

    private static func id(for action: HotkeyAction) -> UInt32 {
        UInt32(HotkeyAction.allCases.firstIndex(of: action)! + 1)
    }
}
