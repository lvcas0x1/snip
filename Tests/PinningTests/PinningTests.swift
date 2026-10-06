import AppKit
import XCTest
@testable import Pinning

private func makeImage(width: Int = 80, height: Int = 40) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

final class PinGeometryTests: XCTestCase {
    func testTopLeftFrameConvertsToAppKitCoordinates() {
        let frame = PinGeometry.appKitFrame(
            fromTopLeft: CGRect(x: 100, y: 200, width: 300, height: 150), primaryDisplayHeight: 1000
        )
        XCTAssertEqual(frame, CGRect(x: 100, y: 650, width: 300, height: 150))
    }

    func testFrameAtTheTopOfTheScreenSitsAtTheTopInAppKitCoordinates() {
        let frame = PinGeometry.appKitFrame(fromTopLeft: CGRect(x: 0, y: 0, width: 50, height: 50), primaryDisplayHeight: 800)
        XCTAssertEqual(frame.maxY, 800)
    }

    func testFrameAboveTheMainDisplayGetsAnAboveScreenAppKitOrigin() {
        // A second display above the main one has negative top-left y.
        let frame = PinGeometry.appKitFrame(fromTopLeft: CGRect(x: 0, y: -300, width: 100, height: 100), primaryDisplayHeight: 800)
        XCTAssertEqual(frame.minY, 1000)
    }
}

final class PinWindowTests: XCTestCase {
    override class func setUp() {
        _ = NSApplication.shared
    }

    private func keyEvent(_ code: UInt16, characters: String) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code
        )!
    }

    func testPinStaysAboveRegularWindowsOnEverySpace() {
        let window = PinWindow(image: makeImage(), frame: CGRect(x: 10, y: 10, width: 80, height: 40))
        XCTAssertEqual(window.level, .floating)
        XCTAssertGreaterThan(window.level.rawValue, NSWindow.Level.normal.rawValue)
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
    }

    func testPinIsBorderlessDraggableAndDoesNotActivateTheApp() {
        let window = PinWindow(image: makeImage(), frame: CGRect(x: 0, y: 0, width: 80, height: 40))
        XCTAssertTrue(window.styleMask.contains(.borderless))
        XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(window.styleMask.contains(.titled))
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertFalse(window.hidesOnDeactivate)
    }

    func testPinHasTheRequestedFrame() {
        let frame = CGRect(x: 120, y: 340, width: 200, height: 100)
        let window = PinWindow(image: makeImage(width: 400, height: 200), frame: frame)
        XCTAssertEqual(window.frame, frame)
    }

    func testEscapeClosesThePin() {
        let manager = PinManager()
        let window = manager.pin(image: makeImage(), frame: CGRect(x: 10, y: 10, width: 80, height: 40), primaryDisplayHeight: 800)
        XCTAssertTrue(window.isVisible)
        window.keyDown(with: keyEvent(53, characters: "\u{1B}"))
        XCTAssertFalse(window.isVisible)
        XCTAssertTrue(manager.windows.isEmpty)
    }

    func testOtherKeysDoNotClose() {
        let manager = PinManager()
        let window = manager.pin(image: makeImage(), frame: CGRect(x: 10, y: 10, width: 80, height: 40), primaryDisplayHeight: 800)
        window.keyDown(with: keyEvent(0, characters: "a"))
        XCTAssertTrue(window.isVisible)
        manager.closeAll()
    }

    func testRightClickClosesThePin() throws {
        let manager = PinManager()
        let window = manager.pin(image: makeImage(), frame: CGRect(x: 10, y: 10, width: 80, height: 40), primaryDisplayHeight: 800)
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseDown, location: NSPoint(x: 5, y: 5), modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        window.contentView?.rightMouseDown(with: event)
        XCTAssertFalse(window.isVisible)
        XCTAssertTrue(manager.windows.isEmpty)
    }

    func testManagerTracksSeveralPinsAndForgetsOnlyTheClosedOne() {
        let manager = PinManager()
        let a = manager.pin(image: makeImage(), frame: CGRect(x: 0, y: 0, width: 80, height: 40), primaryDisplayHeight: 800)
        let b = manager.pin(image: makeImage(), frame: CGRect(x: 100, y: 0, width: 80, height: 40), primaryDisplayHeight: 800)
        XCTAssertEqual(manager.windows.count, 2)
        a.close()
        XCTAssertEqual(manager.windows.count, 1)
        XCTAssertTrue(manager.windows.first === b)
        manager.closeAll()
        XCTAssertTrue(manager.windows.isEmpty)
    }

    func testPinConvertsTopLeftPositionToAppKitFrame() {
        let manager = PinManager()
        let window = manager.pin(image: makeImage(), frame: CGRect(x: 100, y: 200, width: 80, height: 40), primaryDisplayHeight: 1000)
        XCTAssertEqual(window.frame, CGRect(x: 100, y: 760, width: 80, height: 40))
        manager.closeAll()
    }
}
