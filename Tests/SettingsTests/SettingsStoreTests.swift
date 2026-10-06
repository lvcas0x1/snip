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
        XCTAssertNil(store.values.interfaceFontFamily)
    }

    func testPersistenceRoundTrip() {
        let first = SettingsStore(defaults: defaults)
        first.values.imageFormat = .jpeg
        first.values.autoSaveEnabled = true
        first.values.autoSaveFolder = "/tmp/auto"
        first.values.filenamePattern = "Shot {yyyyMMdd}"
        first.values.interfaceFontFamily = "Helvetica Neue"

        let second = SettingsStore(defaults: defaults)
        XCTAssertEqual(second.values, first.values)
    }

    func testUndecodableDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: "settingsValues")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.values, SettingsValues())
    }
}
