import Foundation

enum AppearancePreset: String, CaseIterable, Sendable {
    case soft
    case medium
    case strong

    var title: String {
        switch self {
        case .soft:
            "Soft"
        case .medium:
            "Medium"
        case .strong:
            "Strong"
        }
    }
}

final class Preferences {
    static let isEnabledKey = "focusVeil.isEnabled"
    static let presetKey = "focusVeil.preset"

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

    var preset: AppearancePreset {
        get {
            guard let rawValue = userDefaults.string(forKey: Self.presetKey),
                  let preset = AppearancePreset(rawValue: rawValue)
            else {
                return .medium
            }

            return preset
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Self.presetKey)
        }
    }
}
