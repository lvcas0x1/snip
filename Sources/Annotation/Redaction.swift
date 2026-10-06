import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Obscures a region of the snip. The effect is computed from the original (un-annotated) base image and replaces
/// those pixels, so the underlying content cannot be recovered from the exported file.
public struct RedactionAnnotation: Annotation {
    public enum Kind: Equatable {
        case mosaic, blur
    }

    /// Mosaic block size and blur radius, in points. Large enough that text underneath is unreadable.
    public static let mosaicBlockPoints: CGFloat = 6
    public static let blurRadiusPoints: CGFloat = 10

    public let kind: Kind
    /// The area to obscure in global top-left points.
    public let region: CGRect
    private let cache = RenderCache()

    public init(kind: Kind, region: CGRect) {
        self.kind = kind
        self.region = region.standardized
    }

    public func render(in context: AnnotationRenderContext) {
        guard let patch = cache.patch(kind: kind, region: region, context: context) else { return }
        let ctx = context.context
        ctx.interpolationQuality = .none
        // The user space is y-down; flip locally so the bitmap is drawn upright.
        ctx.translateBy(x: patch.destination.minX, y: patch.destination.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(patch.image, in: CGRect(origin: .zero, size: patch.destination.size))
    }

    /// Pixel rectangle of `region` inside `base` (top-left origin), clipped to the image. `nil` when nothing is covered.
    static func pixelRect(region: CGRect, context: AnnotationRenderContext) -> CGRect? {
        let scale = context.scale
        let minX = ((region.minX - context.origin.x) * scale).rounded()
        let minY = ((region.minY - context.origin.y) * scale).rounded()
        let maxX = ((region.maxX - context.origin.x) * scale).rounded()
        let maxY = ((region.maxY - context.origin.y) * scale).rounded()
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .intersection(CGRect(x: 0, y: 0, width: context.base.width, height: context.base.height))
        return rect.isNull || rect.width < 1 || rect.height < 1 ? nil : rect
    }

    struct Patch {
        let image: CGImage
        /// Where the patch goes, in global top-left points.
        let destination: CGRect
    }

    /// Remembers the last computed patch: the overlay redraws on every mouse move, but the pixels only change
    /// when the region, kind, scale, or base image change.
    final class RenderCache {
        private struct Key: Equatable {
            let kind: Kind
            let pixelRect: CGRect
            let scale: CGFloat
            let base: UnsafeMutableRawPointer
        }

        private var key: Key?
        private var cached: Patch?
        private static let ciContext = CIContext()

        func patch(kind: Kind, region: CGRect, context: AnnotationRenderContext) -> Patch? {
            guard let pixels = RedactionAnnotation.pixelRect(region: region, context: context) else { return nil }
            let newKey = Key(kind: kind, pixelRect: pixels, scale: context.scale, base: Unmanaged.passUnretained(context.base).toOpaque())
            if key == newKey, let cached { return cached }
            guard let image = Self.makePatch(kind: kind, pixels: pixels, context: context) else { return nil }
            let destination = CGRect(
                x: context.origin.x + pixels.minX / context.scale,
                y: context.origin.y + pixels.minY / context.scale,
                width: pixels.width / context.scale,
                height: pixels.height / context.scale
            )
            let patch = Patch(image: image, destination: destination)
            key = newKey
            cached = patch
            return patch
        }

        private static func makePatch(kind: Kind, pixels: CGRect, context: AnnotationRenderContext) -> CGImage? {
            let base = CIImage(cgImage: context.base)
            let height = CGFloat(context.base.height)
            // Core Image uses a bottom-left origin.
            let target = CGRect(x: pixels.minX, y: height - pixels.maxY, width: pixels.width, height: pixels.height)

            let output: CIImage
            switch kind {
            case .mosaic:
                let filter = CIFilter.pixellate()
                filter.inputImage = base.cropped(to: target)
                filter.scale = Float(max(2, RedactionAnnotation.mosaicBlockPoints * context.scale))
                filter.center = CGPoint(x: target.minX, y: target.minY)
                guard let result = filter.outputImage else { return nil }
                output = result
            case .blur:
                let radius = RedactionAnnotation.blurRadiusPoints * context.scale
                // Read a margin around the region so edge pixels blend with their surroundings, then clamp
                // the margin's own edges so the blur does not fade to transparent.
                let source = base.cropped(to: target.insetBy(dx: -radius * 3, dy: -radius * 3))
                let filter = CIFilter.gaussianBlur()
                filter.inputImage = source.clampedToExtent()
                filter.radius = Float(radius)
                guard let result = filter.outputImage else { return nil }
                output = result
            }
            return ciContext.createCGImage(
                output.cropped(to: target), from: target, format: .RGBA8,
                colorSpace: context.base.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
            )
        }
    }
}
