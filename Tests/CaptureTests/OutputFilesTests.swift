import XCTest
@testable import Capture

final class OutputFilesTests: XCTestCase {
    // 2026-10-06 22:10:00 UTC
    private let date = Date(timeIntervalSince1970: 1_791_324_600)
    private let utc = TimeZone(identifier: "UTC")!

    func testPatternGroupsAreExpandedAsDateFormats() {
        XCTAssertEqual(
            FilenameFormatter.name(pattern: "Snip {yyyy-MM-dd HH.mm.ss}", date: date, timeZone: utc),
            "Snip 2026-10-06 22.10.00"
        )
        XCTAssertEqual(FilenameFormatter.name(pattern: "{yyyy}-{MM}", date: date, timeZone: utc), "2026-10")
    }

    func testLiteralPatternAndUnbalancedBrace() {
        XCTAssertEqual(FilenameFormatter.name(pattern: "Shot", date: date, timeZone: utc), "Shot")
        XCTAssertEqual(FilenameFormatter.name(pattern: "Shot {yyyy", date: date, timeZone: utc), "Shot {yyyy")
    }

    func testSeparatorsAreSanitized() {
        XCTAssertEqual(FilenameFormatter.name(pattern: "a/b:{yyyy}", date: date, timeZone: utc), "a-b.2026")
    }

    func testEmptyResultFallsBackToDefaultName() {
        XCTAssertEqual(FilenameFormatter.name(pattern: "  ", date: date, timeZone: utc), "Snip")
        XCTAssertEqual(FilenameFormatter.name(pattern: "", date: date, timeZone: utc), "Snip")
    }

    private func makeTempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OutputFilesTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testWriterCreatesMissingFolderAndWritesBytes() throws {
        let folder = try makeTempFolder().appendingPathComponent("nested/deeper")
        let url = try OutputWriter.write(Data([1, 2, 3]), folder: folder, baseName: "A", fileExtension: "png")
        XCTAssertEqual(url.lastPathComponent, "A.png")
        XCTAssertEqual(try Data(contentsOf: url), Data([1, 2, 3]))
    }

    func testWriterNeverOverwritesExistingFiles() throws {
        let folder = try makeTempFolder()
        let first = try OutputWriter.write(Data([1]), folder: folder, baseName: "A", fileExtension: "png")
        let second = try OutputWriter.write(Data([2]), folder: folder, baseName: "A", fileExtension: "png")
        let third = try OutputWriter.write(Data([3]), folder: folder, baseName: "A", fileExtension: "png")
        XCTAssertEqual([first, second, third].map(\.lastPathComponent), ["A.png", "A 2.png", "A 3.png"])
        XCTAssertEqual(try Data(contentsOf: first), Data([1]))
        XCTAssertEqual(try Data(contentsOf: second), Data([2]))
    }

    func testFileExtensions() {
        XCTAssertEqual(OutputFormat.png.fileExtension, "png")
        XCTAssertEqual(OutputFormat.jpeg.fileExtension, "jpg")
    }
}
