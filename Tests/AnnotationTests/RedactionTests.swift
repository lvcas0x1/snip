import XCTest
@testable import Annotation

private enum Img {
    /// Horizontal gradient: red channel = x (mod 256), green = y (mod 256), opaque.
    static func gradient(width: Int, height: Int) -> CGImage {
        var data = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                data[i] = UInt8(x % 256)
                data[i + 1] = UInt8(y % 256)
                data[i + 2] = 40
            }
        }
        return image(from: data, width: width, height: height)
    }

    /// Left half black, right half white.
    static func splitBlackWhite(width: Int, height: Int) -> CGImage {
        var data = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width where x < width / 2 {
                let i = (y * width + x) * 4
                data[i] = 0; data[i + 1] = 0; data[i + 2] = 0
            }
        }
        return image(from: data, width: width, height: height)
    }

    static func image(from data: [UInt8], width: Int, height: Int) -> CGImage {
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }

    /// All RGBA bytes of an image drawn into a known-layout buffer (row 0 is the top row).
    static func pixels(_ image: CGImage) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(
            data: &buffer, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return buffer
    }

    static func rgb(_ pixels: [UInt8], width: Int, x: Int, y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return [pixels[i], pixels[i + 1], pixels[i + 2]]
    }
}

final class RedactionTests: XCTestCase {
    private func flatten(_ kind: RedactionAnnotation.Kind, region: CGRect, base: CGImage, scale: CGFloat = 1) throws -> [UInt8] {
        let document = AnnotationDocument()
        document.add(RedactionAnnotation(kind: kind, region: region))
        let result = try XCTUnwrap(document.flatten(base: base, scale: scale, origin: .zero))
        XCTAssertEqual(result.width, base.width)
        XCTAssertEqual(result.height, base.height)
        return Img.pixels(result)
    }

    // MARK: Mosaic

    func testMosaicReplacesTheRegionWithBlocksAndLeavesTheRestUntouched() throws {
        let width = 200, height = 120
        let base = Img.gradient(width: width, height: height)
        let source = Img.pixels(base)
        let region = CGRect(x: 40, y: 20, width: 96, height: 60)
        let result = try flatten(.mosaic, region: region, base: base)

        // Outside the region: byte-identical to the source.
        for (x, y) in [(0, 0), (39, 50), (136, 50), (80, 19), (80, 80), (199, 119)] {
            XCTAssertEqual(Img.rgb(result, width: width, x: x, y: y), Img.rgb(source, width: width, x: x, y: y), "(\(x),\(y))")
        }

        // Inside: far fewer distinct colors along a row than the gradient's one-per-pixel.
        var distinct = Set<[UInt8]>()
        for x in 40..<136 { distinct.insert(Img.rgb(result, width: width, x: x, y: 50)) }
        XCTAssertLessThanOrEqual(distinct.count, Int(96 / RedactionAnnotation.mosaicBlockPoints) + 2, "row should consist of blocks, got \(distinct.count) colors")
        XCTAssertLessThan(distinct.count, 96 / 2, "far fewer colors than pixels")

        // The content is no longer the source: many pixels in the region changed.
        var changed = 0
        for x in 40..<136 where Img.rgb(result, width: width, x: x, y: 50) != Img.rgb(source, width: width, x: x, y: 50) { changed += 1 }
        XCTAssertGreaterThan(changed, 60)
    }

    func testMosaicBlocksAreConstantColorSquares() throws {
        let width = 200, height = 120
        let base = Img.gradient(width: width, height: height)
        let result = try flatten(.mosaic, region: CGRect(x: 40, y: 20, width: 96, height: 60), base: base)
        // Pick the block containing (80, 50) by scanning left/right until the color changes.
        let reference = Img.rgb(result, width: width, x: 80, y: 50)
        var left = 80, right = 80
        while left > 40, Img.rgb(result, width: width, x: left - 1, y: 50) == reference { left -= 1 }
        while right < 135, Img.rgb(result, width: width, x: right + 1, y: 50) == reference { right += 1 }
        XCTAssertGreaterThanOrEqual(right - left + 1, Int(RedactionAnnotation.mosaicBlockPoints) - 1, "a block must span several pixels")
        // The same color fills the block vertically: constant down a column inside it.
        let column = (left + right) / 2
        var top = 50, bottom = 50
        while top > 20, Img.rgb(result, width: width, x: column, y: top - 1) == reference { top -= 1 }
        while bottom < 79, Img.rgb(result, width: width, x: column, y: bottom + 1) == reference { bottom += 1 }
        XCTAssertGreaterThanOrEqual(bottom - top + 1, Int(RedactionAnnotation.mosaicBlockPoints) - 1)
        for y in top...bottom {
            for x in left...right {
                XCTAssertEqual(Img.rgb(result, width: width, x: x, y: y), reference, "(\(x),\(y))")
            }
        }
    }

    func testMosaicWorksAtRetinaScale() throws {
        let width = 400, height = 240 // 200x120 pt at 2x
        let base = Img.gradient(width: width, height: height)
        let source = Img.pixels(base)
        let result = try flatten(.mosaic, region: CGRect(x: 20, y: 10, width: 60, height: 30), base: base, scale: 2)
        XCTAssertEqual(Img.rgb(result, width: width, x: 10, y: 10), Img.rgb(source, width: width, x: 10, y: 10))
        var distinct = Set<[UInt8]>()
        for x in 40..<160 { distinct.insert(Img.rgb(result, width: width, x: x, y: 40)) }
        // 120 px wide at 2x with blocks of mosaicBlockPoints * 2 px.
        XCTAssertLessThanOrEqual(distinct.count, Int(120 / (RedactionAnnotation.mosaicBlockPoints * 2)) + 2)
    }

    // MARK: Blur

    func testBlurSoftensASharpEdgeInsideTheRegionOnly() throws {
        let width = 200, height = 100
        let base = Img.splitBlackWhite(width: width, height: height)
        let source = Img.pixels(base)
        let result = try flatten(.blur, region: CGRect(x: 60, y: 20, width: 80, height: 60), base: base)

        // Right beside the edge (x=100) pixels are neither pure black nor pure white any more.
        let darkSide = Img.rgb(result, width: width, x: 98, y: 50)
        let lightSide = Img.rgb(result, width: width, x: 101, y: 50)
        XCTAssertGreaterThan(darkSide[0], 20, "black side picked up light from the white side")
        XCTAssertLessThan(lightSide[0], 235, "white side picked up dark from the black side")
        // Gradual transition: values rise monotonically across the edge.
        let ramp = (90...110).map { Int(Img.rgb(result, width: width, x: $0, y: 50)[0]) }
        XCTAssertEqual(ramp, ramp.sorted())
        XCTAssertGreaterThan(ramp.last! - ramp.first!, 100)

        // Outside the region nothing changes.
        for (x, y) in [(0, 0), (59, 50), (140, 50), (100, 19), (100, 80), (199, 99)] {
            XCTAssertEqual(Img.rgb(result, width: width, x: x, y: y), Img.rgb(source, width: width, x: x, y: y), "(\(x),\(y))")
        }
    }

    func testBlurDoesNotFadeToTransparentAtTheRegionEdge() throws {
        let width = 120, height = 80
        let base = Img.splitBlackWhite(width: width, height: height)
        let result = try flatten(.blur, region: CGRect(x: 10, y: 10, width: 100, height: 60), base: base)
        for (x, y) in [(10, 10), (109, 10), (10, 69), (109, 69), (60, 10)] {
            let i = (y * width + x) * 4
            XCTAssertEqual(result[i + 3], 255, "alpha at (\(x),\(y))")
        }
    }

    // MARK: Geometry and robustness

    func testRegionPartlyOutsideTheImageIsClipped() throws {
        let width = 100, height = 60
        let base = Img.gradient(width: width, height: height)
        let result = try flatten(.mosaic, region: CGRect(x: 70, y: 40, width: 100, height: 100), base: base)
        XCTAssertEqual(result.count, width * height * 4)
        XCTAssertEqual(Img.rgb(result, width: width, x: 10, y: 10), Img.rgb(Img.pixels(base), width: width, x: 10, y: 10))
    }

    func testRegionFullyOutsideDrawsNothing() throws {
        let width = 100, height = 60
        let base = Img.gradient(width: width, height: height)
        let result = try flatten(.blur, region: CGRect(x: 500, y: 500, width: 40, height: 40), base: base)
        XCTAssertEqual(result, Img.pixels(base))
    }

    func testRedactionIgnoresAnnotationsDrawnBeforeItAndSamplesTheBase() throws {
        let width = 120, height = 80
        let base = Img.splitBlackWhite(width: width, height: height)
        let document = AnnotationDocument()
        // A red rectangle drawn first, covering the region, must not leak into the redaction patch.
        document.add(RectangleAnnotation(rect: CGRect(x: 0, y: 0, width: 120, height: 80), style: StrokeStyle(color: AnnotationColor(red: 1, green: 0, blue: 0), width: 200)))
        document.add(RedactionAnnotation(kind: .mosaic, region: CGRect(x: 20, y: 20, width: 40, height: 30)))
        let result = Img.pixels(try XCTUnwrap(document.flatten(base: base, scale: 1, origin: .zero)))
        // x=30 lies on the black half of the base; the patch is built from the base, so it is gray/black, not red.
        let patch = Img.rgb(result, width: width, x: 30, y: 30)
        XCTAssertLessThan(patch[0], 60)
        XCTAssertLessThan(patch[1], 60)
    }

    func testRepeatedRendersGiveTheSamePixels() throws {
        let base = Img.gradient(width: 120, height: 80)
        let annotation = RedactionAnnotation(kind: .blur, region: CGRect(x: 20, y: 10, width: 60, height: 40))
        let document = AnnotationDocument()
        document.add(annotation)
        let first = Img.pixels(try XCTUnwrap(document.flatten(base: base, scale: 1, origin: .zero)))
        let second = Img.pixels(try XCTUnwrap(document.flatten(base: base, scale: 1, origin: .zero)))
        XCTAssertEqual(first, second)
    }
}
