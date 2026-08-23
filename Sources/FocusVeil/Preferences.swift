import Foundation

enum BackgroundTreatment: String, CaseIterable {
    case softFrost
    case balanced
    case deepFocus

    static let defaultValue: BackgroundTreatment = .balanced

    var displayName: String {
        switch self {
        case .softFrost:
            "Soft Frost"
        case .balanced:
            "Balanced"
        case .deepFocus:
            "Deep Focus"
        }
    }

    var symbolName: String {
        switch self {
        case .softFrost:
            "cloud.fog"
        case .balanced:
            "circle.lefthalf.filled"
        case .deepFocus:
            "moon.fill"
        }
    }
}

final class Preferences {
    static let minimumIntensity = 0.2
    static let maximumIntensity = 1.0
    static let defaultIntensity = 0.55

    static let isEnabledKey = "focusVeil.isEnabled"
    static let intensityKey = "focusVeil.intensity"
    static let backgroundTreatmentKey = "focusVeil.backgroundTreatment"

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

    var backgroundTreatment: BackgroundTreatment {
        get {
            guard let rawValue = userDefaults.string(forKey: Self.backgroundTreatmentKey),
                  let treatment = BackgroundTreatment(rawValue: rawValue)
            else {
                return .defaultValue
            }

            return treatment
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Self.backgroundTreatmentKey)
        }
    }

    private static func clampedIntensity(_ value: Double) -> Double {
        min(max(value, minimumIntensity), maximumIntensity)
    }
}
