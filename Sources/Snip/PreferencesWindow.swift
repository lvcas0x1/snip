import AppKit
import DesignSystem
import Settings
import SwiftUI

final class PreferencesWindowController {
    private var window: NSWindow?
    private let settings: SettingsStore
    private let hotkeys: HotkeyManager

    init(settings: SettingsStore, hotkeys: HotkeyManager) {
        self.settings = settings
        self.hotkeys = hotkeys
    }

    func show() {
        if window == nil {
            let hosting = NSHostingView(rootView: ThemedPreferences(settings: settings, hotkeys: hotkeys))
            hosting.layoutSubtreeIfNeeded()
            // Fit the window to the form so no empty space is left below the last section.
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Preferences"
            window.contentView = hosting
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ThemedPreferences: View {
    @ObservedObject var settings: SettingsStore
    let hotkeys: HotkeyManager

    var body: some View {
        PreferencesView(settings: settings, hotkeys: hotkeys)
            .environment(\.interfaceFontFamily, settings.values.interfaceFontFamily)
            .interfaceFont()
    }
}

private extension HotkeyAction {
    var title: String {
        switch self {
        case .snip: "Snip"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    let hotkeys: HotkeyManager
    @State private var hotkeyRevision = 0
    @State private var hotkeyError: String?

    var body: some View {
        Form {
            Section("Hotkeys") {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    LabeledContent(action.title) {
                        HotkeyRecorder(combo: hotkeys.store.combo(for: action)) { combo in
                            record(combo, for: action)
                        }
                        .frame(width: 140, height: 24)
                        .id(hotkeyRevision)
                    }
                }
                if let hotkeyError {
                    Text(hotkeyError).foregroundStyle(.red).font(.callout)
                }
            }
            Section("Output") {
                Picker("Format", selection: $settings.values.imageFormat) {
                    ForEach(ImageFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                }
                TextField("Filename pattern", text: $settings.values.filenamePattern)
                FolderRow(title: "Save folder", path: $settings.values.saveFolder)
                Toggle("Auto Save on selection", isOn: $settings.values.autoSaveEnabled)
                FolderRow(title: "Auto Save folder", path: $settings.values.autoSaveFolder)
            }
            Section("Appearance") {
                Picker("Interface font", selection: $settings.values.interfaceFontFamily) {
                    Text("System").tag(String?.none)
                    ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                        Text(family).tag(Optional(family))
                    }
                }
                Text("Follows the system light/dark appearance and accent color.")
                    .interfaceFont(size: 11).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
    }

    private func record(_ combo: KeyCombo, for action: HotkeyAction) {
        guard combo.hasRequiredModifier else {
            hotkeyError = "Include Control, Option, or Command."
            hotkeyRevision += 1
            return
        }
        do {
            try hotkeys.rebind(action, to: combo)
            hotkeyError = nil
        } catch {
            hotkeyError = "Could not register this shortcut (\(error))."
        }
        hotkeyRevision += 1
    }
}

private struct FolderRow: View {
    let title: String
    @Binding var path: String

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text((path as NSString).abbreviatingWithTildeInPath)
                    .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = URL(fileURLWithPath: path)
                    if panel.runModal() == .OK, let url = panel.url { path = url.path }
                }
            }
        }
    }
}
