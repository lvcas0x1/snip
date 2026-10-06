import AppKit
import Capture
import Pinning
import Settings
import os

enum AppCommand: String {
    case snip, preferences
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let log = Logger(subsystem: "dev.lvcas0x1.snip", category: "app")
    private let settings = SettingsStore()
    private let hotkeys = HotkeyManager(store: HotkeyStore())
    private lazy var preferences = PreferencesWindowController(settings: settings, hotkeys: hotkeys)
    private let permission = PermissionService()
    private let onboarding = OnboardingWindowController()
    private let pins = PinManager()
    private lazy var snipSession: SnipSessionController = {
        let session = SnipSessionController(settings: settings)
        session.onPin = { [pins] image, frame in
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            pins.pin(image: image, frame: frame, primaryDisplayHeight: primaryHeight)
        }
        return session
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Snip")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        for action in HotkeyAction.allCases {
            hotkeys.setHandler(for: action) { [weak self] in
                switch action {
                case .snip: self?.perform(.snip)
                }
            }
        }
        do {
            try hotkeys.start()
            log.notice("hotkeys registered")
        } catch {
            log.error("hotkey registration failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Menu bar

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            perform(.snip)
        }
    }

    private func showMenu() {
        guard let item = statusItem else { return }
        let menu = buildMenu()
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ command: AppCommand, action: HotkeyAction? = nil) {
            let entry = NSMenuItem(title: title, action: #selector(menuItemChosen(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = command.rawValue
            if let action {
                // Display-only: the hotkey is global; the key equivalent is not used to trigger.
                entry.title = "\(title)    \(hotkeys.store.combo(for: action).displayString)"
            }
            menu.addItem(entry)
        }
        add("Snip", .snip, action: .snip)
        menu.addItem(.separator())
        add("Preferences…", .preferences)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func menuItemChosen(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let command = AppCommand(rawValue: raw) else { return }
        perform(command)
    }

    // MARK: Commands

    private func requestPermission(for command: AppCommand) {
        log.notice("\(command.rawValue, privacy: .public) blocked: Screen Recording permission missing")
        permission.requestAccess()
        onboarding.show()
    }

    func perform(_ command: AppCommand) {
        log.notice("command: \(command.rawValue, privacy: .public)")
        switch command {
        case .snip:
            permission.guarded({ snipSession.start() }, onDenied: { requestPermission(for: command) })
        case .preferences:
            preferences.show()
        }
    }

}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
