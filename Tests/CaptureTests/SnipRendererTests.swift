import ImageIO
import XCTest
@testable import Capture

/// Test helpers: solid images and RGBA pixel reads (origin at the top-left).
private enum Pixels {
    static func solid(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    static func rgba(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &buffer, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Draw the image shifted so that pixel (x, y) from the top-left lands on the 1x1 context.
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return buffer
    }

    static func decode(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }
}

final class SnipRendererTests: XCTestCase {
    private func retinaLayout(width: CGFloat = 100, height: CGFloat = 50) -> (SnipLayout, [UInt32: CGImage]) {
        let display = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), scale: 2)
        let layout = Geometry.layout(selection: CGRect(x: 10, y: 10, width: width, height: height), displays: [display])!
        return (layout, [1: Pixels.solid(width: 800, height: 600, red: 255, green: 0, blue: 0)])
    }

    func testOutputIsAtNativePixelResolution() throws {
        let (layout, images) = retinaLayout(width: 200, height: 100)
        let image = try XCTUnwrap(SnipRenderer.render(layout: layout, images: images))
        XCTAssertEqual(image.width, 400)
        XCTAssertEqual(image.height, 200)
    }

    func testCornersStayOpaque() throws {
        let (layout, images) = retinaLayout()
        let image = try XCTUnwrap(SnipRenderer.render(layout: layout, images: images))
        for (x, y) in [(0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)] {
            XCTAssertEqual(Pixels.rgba(image, x: x, y: y), [255, 0, 0, 255], "corner \(x),\(y)")
        }
    }

    func testMixedScaleSelectionComposesBothDisplays() throws {
        let left = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100), scale: 1)
        let right = DisplayGeometry(id: 2, frame: CGRect(x: 100, y: 0, width: 100, height: 100), scale: 2)
        let layout = try XCTUnwrap(Geometry.layout(selection: CGRect(x: 80, y: 10, width: 40, height: 20), displays: [left, right]))
        let images: [UInt32: CGImage] = [
            1: Pixels.solid(width: 100, height: 100, red: 255, green: 0, blue: 0),
            2: Pixels.solid(width: 200, height: 200, red: 0, green: 0, blue: 255),
        ]
        let image = try XCTUnwrap(SnipRenderer.render(layout: layout, images: images))
        XCTAssertEqual(image.width, 80)  // 40 pt at the larger scale (2)
        XCTAssertEqual(image.height, 40)
        XCTAssertEqual(Pixels.rgba(image, x: 5, y: 20), [255, 0, 0, 255])   // left display part
        XCTAssertEqual(Pixels.rgba(image, x: 75, y: 20), [0, 0, 255, 255])  // right display part
    }

    func testPngRoundTripKeepsPixels() throws {
        let (layout, images) = retinaLayout()
        let rendered = try XCTUnwrap(SnipRenderer.render(layout: layout, images: images))
        let data = try XCTUnwrap(ImageEncoder.encode(rendered, as: .png))
        let decoded = try XCTUnwrap(Pixels.decode(data))
        XCTAssertEqual(decoded.width, rendered.width)
        XCTAssertEqual(Pixels.rgba(decoded, x: 0, y: 0), [255, 0, 0, 255])
    }

    func testJpegRoundTripIsOpaqueAndKeepsColor() throws {
        let (layout, images) = retinaLayout()
        let rendered = try XCTUnwrap(SnipRenderer.render(layout: layout, images: images))
        let data = try XCTUnwrap(ImageEncoder.encode(rendered, as: .jpeg))
        let decoded = try XCTUnwrap(Pixels.decode(data))
        let center = Pixels.rgba(decoded, x: decoded.width / 2, y: decoded.height / 2)
        XCTAssertEqual(center[3], 255, "JPEG has no alpha")
        XCTAssertGreaterThan(center[0], 240)
        XCTAssertLessThan(center[1], 20)
    }

    func testJpegFillsTransparentPixelsWithWhite() throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let clear = try XCTUnwrap(CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage())
        let data = try XCTUnwrap(ImageEncoder.encode(clear, as: .jpeg))
        let decoded = try XCTUnwrap(Pixels.decode(data))
        for channel in Pixels.rgba(decoded, x: 1, y: 1).prefix(3) { XCTAssertGreaterThan(channel, 240) }
    }

    func testEmptyLayoutRendersNothing() {
        let layout = SnipLayout(pixelSize: .zero, scale: 1, pieces: [])
        XCTAssertNil(SnipRenderer.render(layout: layout, images: [:]))
    }
}
