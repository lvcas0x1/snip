import CoreGraphics
import Foundation

/// A display's placement in global screen points (origin at the top-left of the main display, y grows downward).
public struct DisplayGeometry: Equatable {
    public let id: UInt32
    public let frame: CGRect
    /// Pixels per point (2 on Retina).
    public let scale: CGFloat

    public init(id: UInt32, frame: CGRect, scale: CGFloat) {
        self.id = id
        self.frame = frame
        self.scale = scale
    }
}

/// One display's contribution to a snip: where to read in its image and where to draw in the output.
public struct SnipPiece: Equatable {
    public let displayID: UInt32
    /// Pixel rectangle inside the display's own image (origin at its top-left).
    public let source: CGRect
    /// Pixel rectangle inside the output image (origin at its top-left).
    public let destination: CGRect
    /// Source pixels per output pixel (1 when the display's scale equals the output scale).
    public let resampleFactor: CGFloat
}

public struct SnipLayout: Equatable {
    /// Output size in pixels.
    public let pixelSize: CGSize
    /// Output pixels per point: the largest scale among the displays the selection touches.
    public let scale: CGFloat
    public let pieces: [SnipPiece]
}

public enum Geometry {
    /// Rounds a point-space interval to whole pixels so adjacent rects share edges and sizes never drift.
    static func pixelRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let minX = (rect.minX * scale).rounded()
        let minY = (rect.minY * scale).rounded()
        let maxX = (rect.maxX * scale).rounded()
        let maxY = (rect.maxY * scale).rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Converts an AppKit rect (origin at the bottom-left of the main display) to global top-left points.
    public static func topLeftRect(fromAppKit rect: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryDisplayHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Pixel rectangle of `selection` within one display's image, or `nil` when they do not overlap.
    public static func cropRect(selection: CGRect, in display: DisplayGeometry) -> CGRect? {
        let overlap = selection.intersection(display.frame)
        guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return nil }
        let local = overlap.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        let crop = pixelRect(local, scale: display.scale)
        return crop.width > 0 && crop.height > 0 ? crop : nil
    }

    /// Lays out a selection that may span several displays, possibly with different scales.
    /// The output uses the largest scale of the touched displays; lower-scale pieces are upsampled by `resampleFactor` < 1.
    public static func layout(selection: CGRect, displays: [DisplayGeometry]) -> SnipLayout? {
        let touched = displays.filter { cropRect(selection: selection, in: $0) != nil }
        guard let scale = touched.map(\.scale).max() else { return nil }
        let outputRect = pixelRect(CGRect(origin: .zero, size: selection.size), scale: scale)
        let pieces = touched.compactMap { display -> SnipPiece? in
            guard let source = cropRect(selection: selection, in: display) else { return nil }
            let overlap = selection.intersection(display.frame)
            let relative = overlap.offsetBy(dx: -selection.minX, dy: -selection.minY)
            let destination = pixelRect(relative, scale: scale)
            return SnipPiece(
                displayID: display.id,
                source: source,
                destination: destination,
                resampleFactor: display.scale / scale
            )
        }
        return SnipLayout(pixelSize: outputRect.size, scale: scale, pieces: pieces)
    }
}
