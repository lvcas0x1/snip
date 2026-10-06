import AppKit

/// A snip kept on screen: borderless, above regular windows on every Space, draggable, closed with Escape or right-click.
public final class PinWindow: NSPanel {
    public init(image: CGImage, frame: CGRect) {
        super.init(
            contentRect: frame,
            // Non-activating: showing or clicking a pin does not pull the app (and its menu bar) to the front.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        contentView = PinImageView(image: image, size: frame.size)
        setFrame(frame, display: false)
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
        } else {
            super.keyDown(with: event)
        }
    }

    public override func cancelOperation(_ sender: Any?) { close() }
}

private final class PinImageView: NSView {
    private let image: NSImage

    init(image: CGImage, size: CGSize) {
        self.image = NSImage(cgImage: image, size: size)
        super.init(frame: NSRect(origin: .zero, size: size))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    }

    override func rightMouseDown(with event: NSEvent) { window?.close() }
}
