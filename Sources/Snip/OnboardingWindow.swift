import AppKit
import Capture
import SwiftUI

/// First-run window explaining the Screen Recording permission and detecting when it is granted.
final class OnboardingWindowController {
    private var window: NSWindow?
    private let monitor = PermissionMonitor()
    private let model = OnboardingModel()

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        model.granted = false
        let hosting = NSHostingView(rootView: OnboardingView(model: model) {
            NSWorkspace.shared.open(PermissionService.settingsURL)
        })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Screen Recording Permission"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        monitor.start { [weak self] in self?.model.granted = true }
    }

    func close() {
        monitor.stop()
        window?.close()
        window = nil
    }
}

final class OnboardingModel: ObservableObject {
    @Published var granted = false
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                model.granted ? "Permission granted" : "Screen Recording permission needed",
                systemImage: model.granted ? "checkmark.circle.fill" : "camera.viewfinder"
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(model.granted ? Color.green : Color.primary)
            Text(model.granted
                 ? "Capture is now available. You can close this window."
                 : "Snipping reads the contents of your screen, which macOS protects with the Screen Recording permission. Enable this app in System Settings > Privacy & Security > Screen Recording.")
                .fixedSize(horizontal: false, vertical: true)
            if !model.granted {
                Button("Open System Settings", action: openSettings)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420, alignment: .leading)
    }
}
