import CoreGraphics
import Foundation

/// The annotations of one snip, with Undo/Redo and flattening onto the snip image.
public final class AnnotationDocument {
    public private(set) var items: [any Annotation] = []
    private var undone: [any Annotation] = []

    /// Called after every change, so views can redraw.
    public var onChange: (() -> Void)?

    public init() {}

    public var canUndo: Bool { !items.isEmpty }
    public var canRedo: Bool { !undone.isEmpty }
    public var isEmpty: Bool { items.isEmpty }

    /// Adds an annotation. Anything that was undone can no longer be redone.
    public func add(_ item: any Annotation) {
        items.append(item)
        undone.removeAll()
        onChange?()
    }

    public func undo() {
        guard let last = items.popLast() else { return }
        undone.append(last)
        onChange?()
    }

    public func redo() {
        guard let next = undone.popLast() else { return }
        items.append(next)
        onChange?()
    }

    /// Removes every annotation. This cannot be undone: the redo history is discarded as well.
    public func clearAll() {
        guard !items.isEmpty || !undone.isEmpty else { return }
        items.removeAll()
        undone.removeAll()
        onChange?()
    }

    /// Draws all annotations onto a copy of `base`, producing an image of the same pixel size.
    /// - Parameters:
    ///   - scale: Output pixels per point of `base`.
    ///   - origin: Global top-left point of `base`'s top-left pixel (the snip's origin).
    public func flatten(base: CGImage, scale: CGFloat, origin: CGPoint) -> CGImage? {
        guard !items.isEmpty else { return base }
        guard scale > 0,
              let context = Self.makeContext(width: base.width, height: base.height, matching: base)
        else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        context.draw(base, in: bounds)

        // Pixel space is bottom-left based; annotations use global points with a top-left origin.
        context.translateBy(x: 0, y: CGFloat(base.height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -origin.x, y: -origin.y)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        draw(in: AnnotationRenderContext(context: context, scale: scale, base: base, origin: origin))
        return context.makeImage()
    }

    /// Draws every annotation, then `draft` (the in-progress shape) on top, each in an isolated graphics state.
    /// `context.context` must already map user space to global top-left points.
    public func draw(in context: AnnotationRenderContext, draft: (any Annotation)? = nil) {
        for item in items + (draft.map { [$0] } ?? []) {
            context.context.saveGState()
            item.render(in: context)
            context.context.restoreGState()
        }
    }

    private static func makeContext(width: Int, height: Int, matching base: CGImage) -> CGContext? {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        if let space = base.colorSpace, space.model == .rgb,
           let context = CGContext(
               data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
               space: space, bitmapInfo: bitmapInfo
           ) {
            return context
        }
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: srgb, bitmapInfo: bitmapInfo
        )
    }
}
