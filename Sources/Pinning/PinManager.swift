import AppKit

/// Owns the open pin windows and forgets each one when it closes.
public final class PinManager {
    public private(set) var windows: [PinWindow] = []
    private var closeObservers: [ObjectIdentifier: NSObjectProtocol] = [:]

    public init() {}

    deinit {
        closeObservers.values.forEach(NotificationCenter.default.removeObserver)
    }

    /// Shows `image` as a pin at `frame` (global top-left points) and returns the window.
    @discardableResult
    public func pin(image: CGImage, frame: CGRect, primaryDisplayHeight: CGFloat) -> PinWindow {
        let window = PinWindow(
            image: image,
            frame: PinGeometry.appKitFrame(fromTopLeft: frame, primaryDisplayHeight: primaryDisplayHeight)
        )
        windows.append(window)
        let id = ObjectIdentifier(window)
        closeObservers[id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in self?.forget(id) }
        window.orderFrontRegardless()
        return window
    }

    public func closeAll() {
        for window in windows { window.close() }
    }

    private func forget(_ id: ObjectIdentifier) {
        windows.removeAll { ObjectIdentifier($0) == id }
        if let observer = closeObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
