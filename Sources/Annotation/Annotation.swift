import CoreGraphics

/// Everything an annotation needs to draw itself while a snip is flattened.
public struct AnnotationRenderContext {
    /// Context whose user space is global screen points with the origin at the top-left (y grows downward).
    public let context: CGContext
    /// Output pixels per point.
    public let scale: CGFloat
    /// The un-annotated snip at native resolution. Redaction tools sample this, never the partially drawn result.
    public let base: CGImage
    /// Global top-left point corresponding to the top-left pixel of `base`.
    public let origin: CGPoint

    public init(context: CGContext, scale: CGFloat, base: CGImage, origin: CGPoint) {
        self.context = context
        self.scale = scale
        self.base = base
        self.origin = origin
    }

    /// The area covered by `base`, in global points.
    public var bounds: CGRect {
        CGRect(x: origin.x, y: origin.y, width: CGFloat(base.width) / scale, height: CGFloat(base.height) / scale)
    }
}

/// A drawable mark. Implementations are value types holding their geometry in global top-left points.
public protocol Annotation {
    func render(in context: AnnotationRenderContext)
}
