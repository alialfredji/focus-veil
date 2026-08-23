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

    func testDefaultsToEnabledAndBalancedIntensity() {
        let preferences = Preferences(userDefaults: userDefaults)

        XCTAssertTrue(preferences.isEnabled)
        XCTAssertEqual(preferences.intensity, 0.55)
    }

    func testPersistsEnabledStateAndIntensity() {
        let preferences = Preferences(userDefaults: userDefaults)
        preferences.isEnabled = false
        preferences.intensity = 0.78

        let reloadedPreferences = Preferences(userDefaults: userDefaults)

        XCTAssertFalse(reloadedPreferences.isEnabled)
        XCTAssertEqual(reloadedPreferences.intensity, 0.78)
    }

    func testIntensityIsClampedToSupportedRange() {
        let preferences = Preferences(userDefaults: userDefaults)

        preferences.intensity = -1
        XCTAssertEqual(preferences.intensity, Preferences.minimumIntensity)

        preferences.intensity = 2
        XCTAssertEqual(preferences.intensity, Preferences.maximumIntensity)
    }

    func testInvalidStoredIntensityFallsBackToDefault() {
        userDefaults.set("unexpected", forKey: Preferences.intensityKey)

        XCTAssertEqual(
            Preferences(userDefaults: userDefaults).intensity,
            Preferences.defaultIntensity
        )
    }
}
