import CoreGraphics

public enum PinGeometry {
    /// Converts a rectangle in global top-left points (the snip's coordinates) to AppKit screen coordinates,
    /// whose origin is the bottom-left of the main display.
    public static func appKitFrame(fromTopLeft frame: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryDisplayHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
