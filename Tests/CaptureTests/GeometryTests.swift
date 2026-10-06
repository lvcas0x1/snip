import XCTest
@testable import Capture

final class GeometryTests: XCTestCase {
    private let retina = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 1800, height: 1169), scale: 2)

    func testRetinaCropIsPointsTimesScale() {
        let crop = Geometry.cropRect(selection: CGRect(x: 10, y: 20, width: 200, height: 100), in: retina)
        XCTAssertEqual(crop, CGRect(x: 20, y: 40, width: 400, height: 200))
    }

    func testSelectionOutsideDisplayHasNoCrop() {
        XCTAssertNil(Geometry.cropRect(selection: CGRect(x: 2000, y: 0, width: 50, height: 50), in: retina))
    }

    func testSelectionIsClippedToDisplay() {
        let crop = Geometry.cropRect(selection: CGRect(x: 1700, y: 1100, width: 300, height: 300), in: retina)
        XCTAssertEqual(crop, CGRect(x: 3400, y: 2200, width: 200, height: 138))
    }

    func testFractionalPointsRoundToSharedPixelEdges() {
        let display = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100), scale: 2)
        let crop = try! XCTUnwrap(Geometry.cropRect(selection: CGRect(x: 0.25, y: 0, width: 10.5, height: 10), in: display))
        // minX 0.5 -> 1 (rounded), maxX 21.5 -> 22: width 21, no drift from independent rounding of width.
        XCTAssertEqual(crop.minX, 1)
        XCTAssertEqual(crop.maxX, 22)
    }

    func testMixedScaleLayoutSpanningTwoDisplays() throws {
        let left = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), scale: 1)
        let right = DisplayGeometry(id: 2, frame: CGRect(x: 1000, y: 0, width: 1000, height: 800), scale: 2)
        let selection = CGRect(x: 900, y: 100, width: 200, height: 100)

        let layout = try XCTUnwrap(Geometry.layout(selection: selection, displays: [left, right]))

        XCTAssertEqual(layout.scale, 2)
        XCTAssertEqual(layout.pixelSize, CGSize(width: 400, height: 200))
        XCTAssertEqual(layout.pieces.count, 2)

        let l = try XCTUnwrap(layout.pieces.first { $0.displayID == 1 })
        XCTAssertEqual(l.source, CGRect(x: 900, y: 100, width: 100, height: 100))
        XCTAssertEqual(l.destination, CGRect(x: 0, y: 0, width: 200, height: 200))
        XCTAssertEqual(l.resampleFactor, 0.5)

        let r = try XCTUnwrap(layout.pieces.first { $0.displayID == 2 })
        XCTAssertEqual(r.source, CGRect(x: 0, y: 200, width: 200, height: 200))
        XCTAssertEqual(r.destination, CGRect(x: 200, y: 0, width: 200, height: 200))
        XCTAssertEqual(r.resampleFactor, 1)
    }

    func testPiecesTileTheOutputWithoutGaps() throws {
        let a = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), scale: 2)
        let b = DisplayGeometry(id: 2, frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), scale: 1)
        let layout = try XCTUnwrap(Geometry.layout(selection: CGRect(x: 1400.3, y: 10.1, width: 100.4, height: 50.2), displays: [a, b]))
        let first = layout.pieces[0].destination, second = layout.pieces[1].destination
        XCTAssertEqual(first.maxX, second.minX)
        XCTAssertEqual(second.maxX, layout.pixelSize.width)
    }

    func testSingleDisplayLayoutMatchesCrop() throws {
        let layout = try XCTUnwrap(Geometry.layout(selection: CGRect(x: 10, y: 20, width: 200, height: 100), displays: [retina]))
        XCTAssertEqual(layout.pixelSize, CGSize(width: 400, height: 200))
        XCTAssertEqual(layout.pieces.count, 1)
        XCTAssertEqual(layout.pieces[0].source, CGRect(x: 20, y: 40, width: 400, height: 200))
        XCTAssertEqual(layout.pieces[0].destination, CGRect(x: 0, y: 0, width: 400, height: 200))
    }

    func testAppKitToTopLeftConversion() {
        let rect = Geometry.topLeftRect(fromAppKit: CGRect(x: 100, y: 50, width: 200, height: 100), primaryDisplayHeight: 1000)
        XCTAssertEqual(rect, CGRect(x: 100, y: 850, width: 200, height: 100))
    }
}
