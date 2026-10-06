import CoreGraphics
import Foundation

public enum FilenameFormatter {
    /// Expands each `{...}` group of `pattern` with `date` using `DateFormatter` syntax, e.g. `Snip {yyyy-MM-dd HH.mm.ss}`.
    /// Path separators and colons in the result are replaced so the name is always a single valid file name.
    public static func name(pattern: String, date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone

        var result = ""
        var rest = Substring(pattern)
        while let open = rest.firstIndex(of: "{") {
            result += rest[rest.startIndex..<open]
            let afterOpen = rest.index(after: open)
            guard let close = rest[afterOpen...].firstIndex(of: "}") else {
                result += rest[open...]
                rest = ""
                break
            }
            formatter.dateFormat = String(rest[afterOpen..<close])
            result += formatter.string(from: date)
            rest = rest[rest.index(after: close)...]
        }
        result += rest

        let cleaned = result
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Snip" : cleaned
    }

    /// `folder/baseName.ext`, or `folder/baseName 2.ext`, `baseName 3.ext`, ... when that name is taken.
    public static func uniqueURL(
        folder: URL, baseName: String, fileExtension: String, fileManager: FileManager = .default
    ) -> URL {
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName) \(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }
}

public enum OutputWriter {
    /// Writes `data` into `folder` (created if missing) without overwriting existing files. Returns the file URL.
    @discardableResult
    public static func write(
        _ data: Data, folder: URL, baseName: String, fileExtension: String, fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = FilenameFormatter.uniqueURL(
            folder: folder, baseName: baseName, fileExtension: fileExtension, fileManager: fileManager
        )
        try data.write(to: url, options: .withoutOverwriting)
        return url
    }
}

public extension OutputFormat {
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

public struct RenderedSnip {
    public let image: CGImage
    /// Output pixels per point; annotations need it to flatten at native resolution.
    public let scale: CGFloat
    /// The selection in global top-left points.
    public let rect: CGRect
}

public enum SnipOutput {
    /// Renders `selection` (global top-left points) from the frozen `captures` into one image.
    public static func render(selection: CGRect, captures: [DisplayCapture]) -> RenderedSnip? {
        let displays = captures.map { DisplayGeometry(id: $0.displayID, frame: $0.frame, scale: $0.pointPixelScale) }
        guard let layout = Geometry.layout(selection: selection, displays: displays) else { return nil }
        let images = Dictionary(uniqueKeysWithValues: captures.map { ($0.displayID, $0.image) })
        guard let image = SnipRenderer.render(layout: layout, images: images) else { return nil }
        return RenderedSnip(image: image, scale: layout.scale, rect: selection)
    }

    public static func image(selection: CGRect, captures: [DisplayCapture]) -> CGImage? {
        render(selection: selection, captures: captures)?.image
    }
}
