import XCTest
@testable import Settings

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "SettingsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaults() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.values.imageFormat, .png)
        XCTAssertFalse(store.values.autoSaveEnabled)
        XCTAssertEqual(store.values.saveFolder, NSHomeDirectory() + "/Pictures/Snip")
        XCTAssertEqual(store.values.autoSaveFolder, NSHomeDirectory() + "/Pictures/Snip/Auto")
        XCTAssertNil(store.values.interfaceFontFamily)
    }

    func testPersistenceRoundTrip() {
        let first = SettingsStore(defaults: defaults)
        first.values.imageFormat = .jpeg
        first.values.autoSaveEnabled = true
        first.values.saveFolder = "/tmp/save"
        first.values.autoSaveFolder = "/tmp/auto"
        first.values.filenamePattern = "Shot {yyyyMMdd}"
        first.values.interfaceFontFamily = "Helvetica Neue"

        let second = SettingsStore(defaults: defaults)
        XCTAssertEqual(second.values, first.values)
    }

    func testMissingKeysFallBackToDefaults() {
        defaults.set(Data(#"{"imageFormat":"jpeg","autoSaveFolder":"/old","autoSaveEnabled":true}"#.utf8),
                     forKey: "settingsValues")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.values.imageFormat, .jpeg)
        XCTAssertTrue(store.values.autoSaveEnabled)
        XCTAssertEqual(store.values.autoSaveFolder, "/old")
        XCTAssertEqual(store.values.saveFolder, SettingsValues().saveFolder)
        XCTAssertEqual(store.values.filenamePattern, SettingsValues().filenamePattern)
    }

    func testUndecodableDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: "settingsValues")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.values, SettingsValues())
    }
}
