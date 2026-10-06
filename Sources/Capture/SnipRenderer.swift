import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum OutputFormat: Equatable {
    case png
    case jpeg
}

public enum SnipRenderer {
    /// Composes the pieces of `layout` into one native-resolution image.
    /// - Parameters:
    ///   - images: Full-display images keyed by display ID.
    public static func render(layout: SnipLayout, images: [UInt32: CGImage]) -> CGImage? {
        let width = Int(layout.pixelSize.width)
        let height = Int(layout.pixelSize.height)
        guard width > 0, height > 0 else { return nil }
        guard let context = makeContext(width: width, height: height, matching: layout.pieces.compactMap { images[$0.displayID] }.first)
        else { return nil }
        context.interpolationQuality = .high

        for piece in layout.pieces {
            guard let image = images[piece.displayID], let cropped = image.cropping(to: piece.source) else { continue }
            // Layout rects use a top-left origin; CGContext uses bottom-left.
            let destination = CGRect(
                x: piece.destination.minX,
                y: CGFloat(height) - piece.destination.maxY,
                width: piece.destination.width,
                height: piece.destination.height
            )
            context.draw(cropped, in: destination)
        }
        return context.makeImage()
    }

    /// Prefers the capture's own color space so wide-gamut displays keep their colors; falls back to sRGB.
    private static func makeContext(width: Int, height: Int, matching sample: CGImage?) -> CGContext? {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        if let space = sample?.colorSpace, space.model == .rgb,
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

public enum ImageEncoder {
    /// Encodes `image`. JPEG has no alpha channel, so any transparent areas are filled with white first.
    public static func encode(_ image: CGImage, as format: OutputFormat, jpegQuality: CGFloat = 0.9) -> Data? {
        let source = format == .jpeg ? (flattenedOnWhite(image) ?? image) : image
        let type = format == .png ? UTType.png : UTType.jpeg
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        let properties: [CFString: Any] = format == .jpeg
            ? [kCGImageDestinationLossyCompressionQuality: jpegQuality]
            : [:]
        CGImageDestinationAddImage(destination, source, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    static func flattenedOnWhite(_ image: CGImage) -> CGImage? {
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard let space,
              let context = CGContext(
                  data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(image, in: bounds)
        return context.makeImage()
    }
}
