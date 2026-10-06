import Carbon.HIToolbox
import XCTest
@testable import Settings

final class HotkeyStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "HotkeyStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testEveryActionHasADefault() {
        XCTAssertEqual(KeyCombo.defaults.count, HotkeyAction.allCases.count)
        let store = HotkeyStore(defaults: defaults)
        for action in HotkeyAction.allCases {
            XCTAssertEqual(store.combo(for: action), KeyCombo.defaults[action])
        }
    }

    func testSnipDefaultIsOptionSlash() {
        let combo = HotkeyStore(defaults: defaults).combo(for: .snip)
        XCTAssertEqual(combo.keyCode, UInt32(kVK_ANSI_Slash))
        XCTAssertEqual(combo.modifiers, UInt32(optionKey))
        XCTAssertTrue(combo.hasRequiredModifier)
        XCTAssertEqual(combo.displayString, "\u{2325}/")
    }

    func testRebindPersistsAcrossInstances() {
        let newCombo = KeyCombo(keyCode: UInt32(kVK_ANSI_9), modifiers: UInt32(controlKey | cmdKey))
        HotkeyStore(defaults: defaults).set(newCombo, for: .snip)

        XCTAssertEqual(HotkeyStore(defaults: defaults).combo(for: .snip), newCombo)
    }

    func testUndecodableDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: "hotkeyBindings")
        XCTAssertEqual(HotkeyStore(defaults: defaults).combo(for: .snip), KeyCombo.defaults[.snip])
    }
}

final class KeyComboDisplayTests: XCTestCase {
    func testModifierRequirement() {
        XCTAssertFalse(KeyCombo(keyCode: 0, modifiers: UInt32(shiftKey)).hasRequiredModifier)
        XCTAssertFalse(KeyCombo(keyCode: 0, modifiers: 0).hasRequiredModifier)
        XCTAssertTrue(KeyCombo(keyCode: 0, modifiers: UInt32(cmdKey)).hasRequiredModifier)
    }

    func testDisplayStringOrdersModifiers() {
        let combo = KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey))
        XCTAssertEqual(combo.displayString, "\u{2303}\u{2325}\u{21E7}\u{2318}Space")
    }

    func testCarbonModifierMapping() {
        XCTAssertEqual(KeyCombo.carbonModifiers(from: [.command, .option]), UInt32(cmdKey | optionKey))
    }
}
