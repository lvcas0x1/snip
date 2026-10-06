import Annotation
import AppKit
import Capture
import Settings
import SwiftUI
import UniformTypeIdentifiers
import os

/// Runs one snip session: freezes every display, shows one overlay panel per display, and tracks the selection.
extension ImageFormat {
    var output: OutputFormat { self == .png ? .png : .jpeg }
}

final class SnipSessionController {
    private let log = Logger(subsystem: "dev.lvcas0x1.snip", category: "snip")
    private let capturer = ScreenCapturer()
    private let settings: SettingsStore
    private var captures: [DisplayCapture] = []
    private var isDragging = false
    /// Marks drawn on the current snip; flattened into every output.
    let annotations: AnnotationDocument
    let drawing: DrawingController
    let toolbarModel = SnipToolbarModel()
    private lazy var colorPanelBridge = ColorPanelBridge { [weak self] color in self?.applyCustomColor(color) }
    private enum Gesture { case none, selection, drawing }
    private var gesture = Gesture.none

    /// Receives the finished image and its on-screen frame (global top-left points) when the user pins a snip.
    var onPin: ((_ image: CGImage, _ frame: CGRect) -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
        annotations = AnnotationDocument()
        drawing = DrawingController(document: annotations)
        annotations.onChange = { [weak self] in self?.redraw() }
        drawing.onDraftChange = { [weak self] in self?.redraw() }
        wireToolbar()
    }

    private func wireToolbar() {
        toolbarModel.selectTool = { [weak self] tool in
            guard let self else { return }
            self.drawing.tool = self.drawing.tool == tool ? nil : tool
            self.redraw()
        }
        toolbarModel.undo = { [weak self] in self?.undo() }
        toolbarModel.redo = { [weak self] in self?.redo() }
        toolbarModel.clearAll = { [weak self] in self?.clearAnnotations() }
        toolbarModel.setColor = { [weak self] color in self?.drawing.setColor(color); self?.redraw() }
        toolbarModel.setAlpha = { [weak self] value in self?.drawing.setAlpha(value); self?.redraw() }
        toolbarModel.setWidth = { [weak self] value in self?.drawing.setWidth(value); self?.redraw() }
        toolbarModel.openColorPanel = { [weak self] in self?.openColorPanel() }
        toolbarModel.copy = { [weak self] in self?.copy() }
        toolbarModel.save = { [weak self] in self?.save() }
        toolbarModel.pin = { [weak self] in self?.pin() }
        toolbarModel.close = { [weak self] in self?.cancel() }
    }

    /// Copies drawing state into the toolbar model. Returns `true` when something visible changed.
    @discardableResult
    private func syncToolbarModel() -> Bool {
        var changed = false
        func assign<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<SnipToolbarModel, T>, _ value: T) {
            if toolbarModel[keyPath: keyPath] != value {
                toolbarModel[keyPath: keyPath] = value
                changed = true
            }
        }
        assign(\.tool, drawing.tool)
        assign(\.baseColor, drawing.baseColor)
        assign(\.alpha, drawing.alpha)
        assign(\.width, drawing.width)
        assign(\.canUndo, annotations.canUndo)
        assign(\.canRedo, annotations.canRedo)
        return changed
    }

    // MARK: Custom color panel

    /// The system color panel sits at a normal window level, so it is lifted above the full-screen overlay.
    private func openColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.color = NSColor(
            srgbRed: drawing.baseColor.red, green: drawing.baseColor.green, blue: drawing.baseColor.blue, alpha: drawing.alpha
        )
        panel.setTarget(colorPanelBridge)
        panel.setAction(#selector(ColorPanelBridge.colorChanged(_:)))
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.orderFrontRegardless()
    }

    private func applyCustomColor(_ color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return }
        drawing.setColor(AnnotationColor(
            red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent, alpha: srgb.alphaComponent
        ))
        redraw()
    }
    private var panels: [OverlayPanel] = []
    private(set) var model = SelectionModel(bounds: .zero)
    private var isStarting = false
    private var windows: [WindowInfo] = []
    /// Bounds of the window under the cursor while no selection exists.
    private(set) var hoverRect: CGRect?

    var isActive: Bool { !panels.isEmpty || isStarting }

    /// Called on the main thread when the session ends. `selection` is nil when aborted.
    var onFinish: ((_ selection: CGRect?) -> Void)?

    func start() {
        guard !isActive else { return }
        isStarting = true
        hoverRect = nil
        windows = WindowDetector.snapshot()
        Task { @MainActor in
            defer { self.isStarting = false }
            do {
                let captures = try await self.capturer.captureAllDisplays()
                self.present(captures)
            } catch {
                self.log.error("capture failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    @MainActor
    private func present(_ captures: [DisplayCapture]) {
        self.captures = captures
        annotations.clearAll()
        drawing.tool = nil
        toolbarModel.annotationBarVisible = true
        gesture = .none
        isDragging = false
        let bounds = captures.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        model = SelectionModel(bounds: bounds)
        let screens = Dictionary(uniqueKeysWithValues: NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return (number.uint32Value, screen)
        })
        panels = captures.compactMap { capture in
            guard let screen = screens[capture.displayID] else { return nil }
            return OverlayPanel(capture: capture, screen: screen, controller: self)
        }
        NSApp.activate(ignoringOtherApps: true)
        updateHover(at: currentGlobalMouse())
        let mouse = NSEvent.mouseLocation
        let keyPanel = panels.first { $0.frame.contains(mouse) } ?? panels.first
        for panel in panels { panel.orderFrontRegardless() }
        keyPanel?.makeKey()
        keyPanel?.makeFirstResponder(keyPanel?.contentView)
        applyCrosshair()
        log.notice("snip session started displays=\(self.panels.count) bounds=\(Int(bounds.width))x\(Int(bounds.height))")
    }

    /// A hotkey start happens while another app is active, so the system can reset the cursor right after the
    /// overlay appears and cursor rects only refresh on mouse movement. Set it now and once more after the activation settles.
    private func applyCrosshair() {
        for panel in panels { panel.invalidateCursorRects(for: panel.contentView ?? NSView()) }
        NSCursor.crosshair.set()
        DispatchQueue.main.async { [weak self] in
            guard self?.panels.isEmpty == false else { return }
            NSCursor.crosshair.set()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard self?.panels.isEmpty == false else { return }
            NSCursor.crosshair.set()
        }
    }

    // MARK: Events from overlay views

    func globalPoint(for event: NSEvent) -> CGPoint {
        let screenPoint = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: screenPoint.x, y: primaryHeight - screenPoint.y)
    }

    private func currentGlobalMouse() -> CGPoint {
        let location = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: location.x, y: primaryHeight - location.y)
    }

    private func updateHover(at point: CGPoint) {
        hoverRect = model.rect == nil ? WindowDetector.hit(point, in: windows)?.frame : nil
    }

    func mouseMoved(_ event: NSEvent) {
        let point = globalPoint(for: event)
        if drawing.isEditing {
            drawing.pointerMoved(to: point)
        } else {
            updateHover(at: point)
        }
        redraw()
    }

    func mouseDown(_ event: NSEvent) {
        let point = globalPoint(for: event)
        isDragging = true
        if drawing.isEditing {
            // While a tool is active, presses inside the selection draw; presses outside are ignored.
            if let rect = model.rect, rect.contains(point) {
                gesture = .drawing
                drawing.pointerDown(at: point, shift: event.modifierFlags.contains(.shift))
            } else {
                gesture = .none
                isDragging = false
            }
            redraw()
            return
        }
        // Keep the hover highlight until a real drag starts, so a plain click does not flash the dim layer.
        gesture = .selection
        model.mouseDown(at: point)
        redraw()
    }

    func mouseDragged(_ event: NSEvent) {
        let point = globalPoint(for: event)
        switch gesture {
        case .drawing:
            drawing.pointerDragged(to: point, shift: event.modifierFlags.contains(.shift))
        case .selection:
            model.mouseDragged(to: point)
            if model.didDrag { hoverRect = nil }
        case .none:
            return
        }
        redraw()
    }

    func mouseUp(_ event: NSEvent) {
        let point = globalPoint(for: event)
        let current = gesture
        gesture = .none
        isDragging = false
        switch current {
        case .none:
            redraw()
            return
        case .drawing:
            drawing.pointerUp(at: point)
            redraw()
            return
        case .selection:
            break
        }
        let wasClick = model.mouseUp(at: point)
        if model.endedWithOutsideClick {
            cancel()
            return
        }
        if wasClick, let window = WindowDetector.hit(point, in: windows) {
            model.setRect(window.frame)
            hoverRect = nil
        } else {
            updateHover(at: point)
        }
        redraw()
    }

    /// Right-click finishes the current shape while a tool is active; otherwise it aborts the snip.
    func rightClick() {
        if drawing.isEditing {
            drawing.finishDraft()
        } else {
            cancel()
        }
    }

    func scroll(_ event: NSEvent) {
        guard drawing.tool?.usesStrokeWidth == true, event.scrollingDeltaY != 0 else { return }
        drawing.adjustWidth(by: event.scrollingDeltaY > 0 ? 1 : -1)
        redraw()
    }

    /// Keys that stay once the toolbar exists: Tab (line/arrow), 1/2 (pen width), Space (show/hide annotation controls).
    func handleKey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.shift).isEmpty,
              let key = event.charactersIgnoringModifiers else { return false }
        switch key {
        case "\t":
            guard drawing.toggleLineArrow() else { return false }
        case "1":
            guard drawing.tool?.usesStrokeWidth == true else { return false }
            drawing.adjustWidth(by: -1)
        case "2":
            guard drawing.tool?.usesStrokeWidth == true else { return false }
            drawing.adjustWidth(by: 1)
        case " ":
            toolbarModel.annotationBarVisible.toggle()
            if !toolbarModel.annotationBarVisible { drawing.tool = nil }
        default:
            return false
        }
        redraw()
        return true
    }

    /// One-line usage hint for the active tool, shown under the size label.
    var toolHint: String? {
        switch drawing.tool {
        case .line: "Click to add points, right-click to finish \u{00B7} Drag for one line \u{00B7} Tab: arrow"
        case .arrow: "Drag to draw \u{00B7} Tab: line"
        case .mosaic, .blur: "Drag over the area to hide"
        case .text: "Click to place text \u{00B7} Drag a corner to scale (Shift: level) \u{00B7} Drag the top handle to rotate \u{00B7} Esc: done"
        default: nil
        }
    }

    func undo() {
        // While typing, undo throws the unfinished text away instead of removing an earlier annotation.
        if drawing.isEditingText { drawing.cancelText() } else { annotations.undo() }
    }
    func redo() { annotations.redo() }
    func clearAnnotations() { annotations.clearAll() }

    func cancel() { end(selection: nil) }

    // MARK: Output actions

    private func renderSelection() -> (image: CGImage, rect: CGRect)? {
        drawing.commitText() // text still being typed becomes part of the output
        guard let rect = model.rect,
              let snip = SnipOutput.render(selection: rect, captures: captures),
              let image = annotations.flatten(base: snip.image, scale: snip.scale, origin: rect.origin)
        else {
            log.error("render failed for selection \(self.model.rect.map { "\($0)" } ?? "none", privacy: .public)")
            return nil
        }
        return (image, rect)
    }

    /// Copies the selection to the clipboard and ends the session.
    func copy() {
        guard let (image, rect) = renderSelection(), let png = ImageEncoder.encode(image, as: .png) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        if let tiff = NSBitmapImageRep(cgImage: image).tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
        autoSaveIfEnabled(image)
        end(selection: rect)
    }

    /// Asks where to save, using the format from Preferences. Cancelling returns to the overlay.
    func save() {
        guard let (image, rect) = renderSelection() else { return }
        let format = settings.values.imageFormat.output
        guard let data = ImageEncoder.encode(image, as: format) else { return }

        for panel in panels { panel.orderOut(nil) }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [format == .png ? .png : .jpeg]
        savePanel.nameFieldStringValue = FilenameFormatter.name(
            pattern: settings.values.filenamePattern, date: Date()
        ) + "." + format.fileExtension
        NSApp.activate(ignoringOtherApps: true)
        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            restoreOverlay()
            return
        }
        do {
            try data.write(to: url)
            log.notice("saved \(url.path, privacy: .public)")
        } catch {
            log.error("save failed: \(String(describing: error), privacy: .public)")
            restoreOverlay()
            return
        }
        autoSaveIfEnabled(image)
        end(selection: rect)
    }

    /// Hands the snip to the pin layer at its on-screen position and ends the session.
    func pin() {
        guard let (image, rect) = renderSelection() else { return }
        autoSaveIfEnabled(image)
        onPin?(image, rect)
        end(selection: rect)
    }

    private func restoreOverlay() {
        NSApp.activate(ignoringOtherApps: true)
        for panel in panels { panel.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        let keyPanel = panels.first { $0.frame.contains(mouse) } ?? panels.first
        keyPanel?.makeKey()
        keyPanel?.makeFirstResponder(keyPanel?.contentView)
    }

    private func autoSaveIfEnabled(_ image: CGImage) {
        guard settings.values.autoSaveEnabled else { return }
        let format = settings.values.imageFormat.output
        guard let data = ImageEncoder.encode(image, as: format) else { return }
        let name = FilenameFormatter.name(pattern: settings.values.filenamePattern, date: Date())
        do {
            let url = try OutputWriter.write(
                data, folder: URL(fileURLWithPath: settings.values.autoSaveFolder),
                baseName: name, fileExtension: format.fileExtension
            )
            log.notice("auto-saved \(url.path, privacy: .public)")
        } catch {
            log.error("auto save failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Toolbar placement

    var showsToolbar: Bool { model.rect != nil && !isDragging }

    /// Top-left of the toolbar (including its outer padding) in global points: below the selection, right-aligned;
    /// above it when there is no room below; inside its bottom edge as a last resort.
    func toolbarOrigin(size: CGSize) -> CGPoint? {
        guard let rect = model.rect else { return nil }
        let pad = SnipToolbarView.outerPadding
        let gap: CGFloat = 6
        let bounds = model.bounds
        var x = rect.maxX - size.width + pad
        x = min(max(x, bounds.minX), bounds.maxX - size.width)
        var y = rect.maxY + gap - pad
        if y + size.height - pad > bounds.maxY {
            y = rect.minY - gap - size.height + pad
            if y + pad < bounds.minY { y = rect.maxY - size.height + pad - gap }
        }
        return CGPoint(x: x, y: y)
    }

    private func end(selection: CGRect?) {
        NSColorPanel.shared.orderOut(nil)
        for panel in panels { panel.orderOut(nil) }
        panels.removeAll()
        log.notice("snip session ended selection=\(selection.map { "\($0)" } ?? "none", privacy: .public)")
        onFinish?(selection)
    }

    func redraw() {
        let modelChanged = syncToolbarModel()
        refreshOverlays()
        if modelChanged {
            // SwiftUI applies the model change on its next layout pass, so size the toolbar once more afterwards.
            DispatchQueue.main.async { [weak self] in self?.refreshOverlays() }
        }
    }

    private func refreshOverlays() {
        for panel in panels { (panel.contentView as? OverlayView)?.refresh() }
    }

    /// Pixel dimensions of the current selection, using the scale of the display under its top-left corner.
    func pixelSize(of rect: CGRect) -> CGSize {
        let scale = panels.map(\.capture).first { $0.frame.contains(rect.origin) }?.pointPixelScale ?? 1
        return CGSize(width: (rect.width * scale).rounded(), height: (rect.height * scale).rounded())
    }
}

private final class OverlayPanel: NSPanel {
    let capture: DisplayCapture

    init(capture: DisplayCapture, screen: NSScreen, controller: SnipSessionController) {
        self.capture = capture
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .screenSaver
        acceptsMouseMovedEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = OverlayView(capture: capture, controller: controller)
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class OverlayView: NSView {
    private static let dimAlpha: CGFloat = 0.3
    private let capture: DisplayCapture
    private unowned let controller: SnipSessionController
    private lazy var image = NSImage(cgImage: capture.image, size: capture.frame.size)
    private let toolbarHost: NSHostingView<SnipToolbarView>
    private var toolbarSize: CGSize = .zero
    /// Watches for the input method's candidate windows while text is being composed.
    fileprivate var candidateTimer: Timer?

    init(capture: DisplayCapture, controller: SnipSessionController) {
        self.capture = capture
        self.controller = controller
        toolbarHost = NSHostingView(rootView: SnipToolbarView(model: controller.toolbarModel))
        super.init(frame: NSRect(origin: .zero, size: capture.frame.size))
        toolbarHost.isHidden = true
        addSubview(toolbarHost)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
        if !toolbarHost.isHidden { addCursorRect(toolbarHost.frame, cursor: .arrow) }
    }

    func refresh() {
        needsDisplay = true
        updateToolbar()
    }

    private func updateToolbar() {
        let wasHidden = toolbarHost.isHidden
        let oldFrame = toolbarHost.frame
        toolbarHost.layoutSubtreeIfNeeded()
        toolbarSize = toolbarHost.fittingSize
        if controller.showsToolbar, let origin = controller.toolbarOrigin(size: toolbarSize) {
            let center = CGPoint(x: origin.x + toolbarSize.width / 2, y: origin.y + toolbarSize.height / 2)
            if capture.frame.contains(center) {
                toolbarHost.frame = CGRect(
                    x: origin.x - capture.frame.minX, y: origin.y - capture.frame.minY,
                    width: toolbarSize.width, height: toolbarSize.height
                )
                toolbarHost.isHidden = false
            } else {
                toolbarHost.isHidden = true
            }
        } else {
            toolbarHost.isHidden = true
        }
        if wasHidden != toolbarHost.isHidden || oldFrame != toolbarHost.frame {
            window?.invalidateCursorRects(for: self)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()
        switch (flags, key) {
        case (.command, "c"): controller.copy()
        case (.command, "s"): controller.save()
        case (.command, "z"): controller.undo()
        case (.command, "y"): controller.redo()
        case ([.command, .shift], "z"): controller.clearAnnotations()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self, userInfo: nil
        ))
    }

    private func cursor(at point: CGPoint) -> NSCursor {
        !toolbarHost.isHidden && toolbarHost.frame.contains(point) ? .arrow : .crosshair
    }

    override func cursorUpdate(with event: NSEvent) {
        cursor(at: convert(event.locationInWindow, from: nil)).set()
    }

    override func mouseMoved(with event: NSEvent) {
        cursor(at: convert(event.locationInWindow, from: nil)).set()
        controller.mouseMoved(event)
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        controller.mouseDown(event)
    }
    override func mouseDragged(with event: NSEvent) { controller.mouseDragged(event) }
    override func mouseUp(with event: NSEvent) { controller.mouseUp(event) }
    override func rightMouseDown(with event: NSEvent) { controller.rightClick() }
    override func scrollWheel(with event: NSEvent) { controller.scroll(event) }

    override func keyDown(with event: NSEvent) {
        // While text is being edited every key goes to the input method (Japanese composition, Return, Delete, Esc).
        if controller.drawing.isEditingText {
            interpretKeyEvents([event])
            return
        }
        switch event.keyCode {
        case 53: controller.cancel() // Escape
        case 36, 76: controller.copy() // Return, keypad Enter
        default:
            if !controller.handleKey(event) { super.keyDown(with: event) }
        }
    }

    // MARK: Drawing

    private func local(_ globalRect: CGRect) -> CGRect {
        globalRect.offsetBy(dx: -capture.frame.minX, dy: -capture.frame.minY)
    }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        NSColor.black.withAlphaComponent(Self.dimAlpha).setFill()
        bounds.fill()

        let isSelected = controller.model.rect != nil
        guard let selection = controller.model.rect ?? controller.hoverRect else { return }
        let rect = local(selection)
        let visible = rect.intersection(bounds)
        if !visible.isNull, visible.width > 0, visible.height > 0 {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: visible).addClip()
            image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
        }
        if isSelected { drawAnnotations(clippedTo: visible) }
        drawBorder(rect)
        drawTextEditor()
        if isSelected && !controller.drawing.isEditing { drawHandles(for: selection) }
        drawSizeLabel(for: selection)
    }

    /// Draws committed annotations and the in-progress shape, clipped to the selection (as in the final output).
    private func drawAnnotations(clippedTo visible: CGRect) {
        guard !visible.isNull, let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.clip(to: visible)
        // Annotations live in global top-left points; this flipped view is offset from them by the display origin.
        cg.translateBy(x: -capture.frame.minX, y: -capture.frame.minY)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        controller.annotations.draw(
            in: AnnotationRenderContext(
                context: cg, scale: capture.pointPixelScale, base: capture.image, origin: capture.frame.origin
            ),
            draft: controller.drawing.draft
        )
        if let text = controller.drawing.textDraft {
            let renderContext = AnnotationRenderContext(
                context: cg, scale: capture.pointPixelScale, base: capture.image, origin: capture.frame.origin
            )
            cg.saveGState()
            text.render(in: renderContext)
            cg.restoreGState()
        }
        cg.restoreGState()
    }

    /// Frame, corner handles, rotation handle, and caret of the text being edited (not part of the output).
    private func drawTextEditor() {
        guard let box = controller.drawing.textDraft, let cg = NSGraphicsContext.current?.cgContext else { return }
        func toLocal(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - capture.frame.minX, y: p.y - capture.frame.minY) }
        let accent = NSColor.controlAccentColor
        let corners = box.corners.map(toLocal)
        cg.saveGState()
        accent.setStroke()
        cg.setLineWidth(1)
        cg.setLineDash(phase: 0, lengths: [4, 3])
        cg.beginPath()
        cg.addLines(between: corners)
        cg.closePath()
        cg.strokePath()
        cg.setLineDash(phase: 0, lengths: [])

        let topCenter = toLocal(CGPoint(
            x: (box.point(of: .topLeft).x + box.point(of: .topRight).x) / 2,
            y: (box.point(of: .topLeft).y + box.point(of: .topRight).y) / 2
        ))
        let rotate = toLocal(box.point(of: .rotate))
        cg.beginPath()
        cg.move(to: topCenter)
        cg.addLine(to: rotate)
        cg.strokePath()

        NSColor.white.setFill()
        cg.setLineWidth(1.5)
        for corner in corners {
            let r = CGRect(x: corner.x - 4, y: corner.y - 4, width: 8, height: 8)
            cg.fill(r)
            cg.stroke(r)
        }
        let circle = CGRect(x: rotate.x - 5, y: rotate.y - 5, width: 10, height: 10)
        cg.fillEllipse(in: circle)
        cg.strokeEllipse(in: circle)

        let caret = box.caret
        cg.setLineWidth(1.5)
        cg.beginPath()
        cg.move(to: toLocal(caret.top))
        cg.addLine(to: toLocal(caret.bottom))
        cg.strokePath()
        cg.restoreGState()
    }

    private func drawBorder(_ rect: CGRect) {
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawHandles(for selection: CGRect) {
        let size: CGFloat = 8
        for handle in ResizeHandle.allCases {
            let point = local(CGRect(origin: handle.position(on: selection), size: .zero)).origin
            guard bounds.insetBy(dx: -size, dy: -size).contains(point) else { continue }
            let box = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
            let path = NSBezierPath(roundedRect: box, xRadius: 2, yRadius: 2)
            NSColor.white.setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    private func drawSizeLabel(for selection: CGRect) {
        guard capture.frame.contains(selection.origin) else { return }
        let pixels = controller.pixelSize(of: selection)
        let label = "\(Int(pixels.width)) \u{00D7} \(Int(pixels.height))"
        let text = label as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let hint = controller.toolHint as NSString?
        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85),
        ]
        let textSize = text.size(withAttributes: attributes)
        let hintSize = hint?.size(withAttributes: hintAttributes) ?? .zero
        let pad = CGSize(width: 8, height: 4)
        let contentWidth = max(textSize.width, hintSize.width)
        let contentHeight = textSize.height + (hint == nil ? 0 : hintSize.height + 2)
        let origin = local(selection).origin
        var box = CGRect(
            x: origin.x, y: origin.y - contentHeight - pad.height * 2 - 6,
            width: contentWidth + pad.width * 2, height: contentHeight + pad.height * 2
        )
        if box.minY < 4 { box.origin.y = origin.y + 6 }
        box.origin.x = min(max(box.origin.x, 4), bounds.maxX - box.width - 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6).fill()
        text.draw(at: CGPoint(x: box.minX + pad.width, y: box.minY + pad.height), withAttributes: attributes)
        hint?.draw(
            at: CGPoint(x: box.minX + pad.width, y: box.minY + pad.height + textSize.height + 2),
            withAttributes: hintAttributes
        )
    }
}

// MARK: Text input (typing and Japanese/CJK composition for the text tool)

extension OverlayView: NSTextInputClient {
    private static func plain(_ value: Any) -> String {
        (value as? NSAttributedString)?.string ?? (value as? String) ?? ""
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        controller.drawing.insertText(Self.plain(string))
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        controller.drawing.setMarkedText(Self.plain(string))
        startCandidateWatch()
    }

    /// The input method's candidate list is a normal-level window of this process (class `NSPanel.ViewBridge.*`),
    /// so the full-screen overlay at screen-saver level would hide it. While text is being composed, check every
    /// 0.1 s and lift such windows above the overlay; they are created after the key press that opens them.
    private func startCandidateWatch() {
        raiseCandidateWindows()
        guard candidateTimer == nil else { return }
        candidateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self, self.hasMarkedText() else {
                timer.invalidate()
                self?.candidateTimer = nil
                return
            }
            self.raiseCandidateWindows()
        }
    }

    private func raiseCandidateWindows() {
        let overlayLevel = window?.level ?? .screenSaver
        for other in NSApp.windows where !(other is OverlayPanel) && other.isVisible && Self.isCandidateWindow(other) {
            if other.level.rawValue <= overlayLevel.rawValue {
                other.level = NSWindow.Level(rawValue: overlayLevel.rawValue + 1)
                other.orderFrontRegardless()
            }
        }
    }

    private static func isCandidateWindow(_ window: NSWindow) -> Bool {
        let name = String(describing: type(of: window)).lowercased()
        return name.contains("viewbridge") || name.contains("candidate")
    }

    func unmarkText() { controller.drawing.unmarkText() }

    func selectedRange() -> NSRange {
        NSRange(location: controller.drawing.committedTextLength + controller.drawing.markedTextLength, length: 0)
    }

    func markedRange() -> NSRange {
        controller.drawing.markedTextLength == 0
            ? NSRange(location: NSNotFound, length: 0)
            : NSRange(location: controller.drawing.committedTextLength, length: controller.drawing.markedTextLength)
    }

    func hasMarkedText() -> Bool { controller.drawing.markedTextLength > 0 }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? { nil }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }

    /// Where the input method shows its candidate window: just below the caret, in screen coordinates.
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let caret = controller.drawing.textDraft?.caret else { return .zero }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: caret.bottom.x, y: primaryHeight - caret.bottom.y, width: 1, height: caret.bottom.y - caret.top.y)
    }

    func characterIndex(for point: NSPoint) -> Int { 0 }

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(NSResponder.deleteBackward(_:)): controller.drawing.deleteBackward()
        case #selector(NSResponder.insertNewline(_:)): controller.drawing.insertNewline()
        case #selector(NSResponder.cancelOperation(_:)): controller.drawing.commitText() // Esc finishes the text
        default: break
        }
    }
}

/// Receives color changes from the shared `NSColorPanel` (target/action needs an Objective-C compatible object).
final class ColorPanelBridge: NSObject {
    private let onChange: (NSColor) -> Void

    init(onChange: @escaping (NSColor) -> Void) {
        self.onChange = onChange
    }

    @objc func colorChanged(_ sender: NSColorPanel) {
        onChange(sender.color)
    }
}
