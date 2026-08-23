import Foundation
import XCTest
@testable import FocusVeil

final class PreferencesTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()

        suiteName = "FocusVeilTests.Preferences.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil

        super.tearDown()
    }

    func testDefaultsToEnabledAndMediumPreset() {
        let preferences = Preferences(userDefaults: userDefaults)

        XCTAssertTrue(preferences.isEnabled)
        XCTAssertEqual(preferences.preset, .medium)
    }

    func testPresetTitlesAreLiteral() {
        XCTAssertEqual(AppearancePreset.soft.title, "Soft")
        XCTAssertEqual(AppearancePreset.medium.title, "Medium")
        XCTAssertEqual(AppearancePreset.strong.title, "Strong")
    }

    func testPersistsEnabledStateAndPreset() {
        let preferences = Preferences(userDefaults: userDefaults)
        preferences.isEnabled = false
        preferences.preset = .strong

        let reloadedPreferences = Preferences(userDefaults: userDefaults)

        XCTAssertFalse(reloadedPreferences.isEnabled)
        XCTAssertEqual(reloadedPreferences.preset, .strong)
    }

    func testInvalidStoredPresetFallsBackToMedium() {
        userDefaults.set("unexpected", forKey: Preferences.presetKey)

        XCTAssertEqual(Preferences(userDefaults: userDefaults).preset, .medium)
    }
}
