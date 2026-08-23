import Foundation

final class Preferences {
    static let minimumIntensity = 0.2
    static let maximumIntensity = 1.0
    static let defaultIntensity = 0.55

    static let isEnabledKey = "focusVeil.isEnabled"
    static let intensityKey = "focusVeil.intensity"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isEnabled: Bool {
        get {
            (userDefaults.object(forKey: Self.isEnabledKey) as? Bool) ?? true
        }
        set {
            userDefaults.set(newValue, forKey: Self.isEnabledKey)
        }
    }

    var intensity: Double {
        get {
            guard let value = userDefaults.object(forKey: Self.intensityKey) as? NSNumber else {
                return Self.defaultIntensity
            }

            return Self.clampedIntensity(value.doubleValue)
        }
        set {
            userDefaults.set(Self.clampedIntensity(newValue), forKey: Self.intensityKey)
        }
    }

    private static func clampedIntensity(_ value: Double) -> Double {
        min(max(value, minimumIntensity), maximumIntensity)
    }
}
