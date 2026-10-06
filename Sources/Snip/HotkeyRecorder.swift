import AppKit
import Settings
import SwiftUI

/// Click to record: captures the next key combination and reports it. Escape cancels.
struct HotkeyRecorder: NSViewRepresentable {
    let combo: KeyCombo
    let onRecord: (KeyCombo) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let view = RecorderButton()
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ view: RecorderButton, context: Context) {
        view.onRecord = onRecord
        view.combo = combo
    }
}

final class RecorderButton: NSButton {
    var onRecord: ((KeyCombo) -> Void)?
    var combo = KeyCombo(keyCode: 0, modifiers: 0) { didSet { refreshTitle() } }
    private var isRecording = false { didSet { refreshTitle() } }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        setAccessibilityLabel("Record hotkey")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }

    @objc private func toggleRecording() {
        isRecording.toggle()
        if isRecording { window?.makeFirstResponder(self) }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        if event.keyCode == 53 { // Escape
            isRecording = false
            return
        }
        let recorded = KeyCombo(
            keyCode: UInt32(event.keyCode),
            modifiers: KeyCombo.carbonModifiers(from: event.modifierFlags)
        )
        isRecording = false
        onRecord?(recorded)
    }

    private func refreshTitle() {
        title = isRecording ? "Type shortcut…" : combo.displayString
    }
}
