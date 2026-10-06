import CoreGraphics
import Foundation
import ScreenCaptureKit

/// One frozen display image plus the geometry needed to map it back to screen coordinates.
public struct DisplayCapture {
    public let displayID: CGDirectDisplayID
    /// Display frame in global screen points (origin at the top-left of the main display).
    public let frame: CGRect
    /// Pixels per point for this display (2 on Retina).
    public let pointPixelScale: CGFloat
    /// Native-resolution image of the whole display, without the mouse cursor.
    public let image: CGImage

    public init(displayID: CGDirectDisplayID, frame: CGRect, pointPixelScale: CGFloat, image: CGImage) {
        self.displayID = displayID
        self.frame = frame
        self.pointPixelScale = pointPixelScale
        self.image = image
    }
}

public enum CaptureError: Error {
    case noDisplays
}

public final class ScreenCapturer {
    public init() {}

    /// Captures every connected display concurrently at native pixel size, excluding this app's own windows and the cursor.
    public func captureAllDisplays() async throws -> [DisplayCapture] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !content.displays.isEmpty else { throw CaptureError.noDisplays }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == ownPID }

        return try await withThrowingTaskGroup(of: DisplayCapture.self) { group in
            for display in content.displays {
                group.addTask {
                    try await Self.capture(display: display, excludingApplications: ownApps)
                }
            }
            var results: [DisplayCapture] = []
            for try await capture in group { results.append(capture) }
            return results.sorted { $0.displayID < $1.displayID }
        }
    }

    private static func capture(display: SCDisplay, excludingApplications apps: [SCRunningApplication]) async throws -> DisplayCapture {
        let filter = SCContentFilter(display: display, excludingApplications: apps, exceptingWindows: [])
        let scale = CGFloat(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        configuration.width = Int((filter.contentRect.width * scale).rounded())
        configuration.height = Int((filter.contentRect.height * scale).rounded())
        configuration.showsCursor = false
        configuration.captureResolution = .best
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return DisplayCapture(displayID: display.displayID, frame: display.frame, pointPixelScale: scale, image: image)
    }
}
