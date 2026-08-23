import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    var onEnabledChange: ((Bool) -> Void)?
    var onPresetChange: ((AppearancePreset) -> Void)?
    var onPermissionRefresh: ((Bool) -> Void)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var toggleItem: NSMenuItem!
    private var strengthItems: [AppearancePreset: NSMenuItem] = [:]
    private var permissionStatusItem: NSMenuItem!
    private var requestPermissionItem: NSMenuItem!
    private var permissionGranted = false
    private var isEffectEnabled = true

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func stop() {
        menu.delegate = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func update(
        isEnabled: Bool,
        preset: AppearancePreset,
        permissionGranted: Bool
    ) {
        isEffectEnabled = isEnabled
        self.permissionGranted = permissionGranted

        toggleItem.state = isEnabled ? .on : .off
        toggleItem.isEnabled = permissionGranted

        for (itemPreset, item) in strengthItems {
            item.state = itemPreset == preset ? .on : .off
            item.isEnabled = permissionGranted
        }

        permissionStatusItem.isHidden = permissionGranted
        requestPermissionItem.isHidden = permissionGranted
        updateAccessibilityLabel()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(
            systemSymbolName: "circle.lefthalf.filled",
            accessibilityDescription: "Focus Veil"
        )
        image?.isTemplate = true
        button.image = image
        updateAccessibilityLabel()
    }

    private func configureMenu() {
        menu.delegate = self

        toggleItem = NSMenuItem(
            title: "Focus Veil",
            action: #selector(toggleEffect(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let strengthMenu = NSMenu()
        for (index, preset) in AppearancePreset.allCases.enumerated() {
            let item = NSMenuItem(
                title: preset.title,
                action: #selector(selectPreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            strengthItems[preset] = item
            strengthMenu.addItem(item)
        }

        let strengthItem = NSMenuItem(title: "Strength", action: nil, keyEquivalent: "")
        strengthItem.submenu = strengthMenu
        menu.addItem(strengthItem)
        menu.addItem(.separator())

        permissionStatusItem = NSMenuItem(
            title: "Accessibility Access Required",
            action: nil,
            keyEquivalent: ""
        )
        permissionStatusItem.isEnabled = false
        menu.addItem(permissionStatusItem)

        requestPermissionItem = NSMenuItem(
            title: "Request Accessibility Access…",
            action: #selector(requestPermission),
            keyEquivalent: ""
        )
        requestPermissionItem.target = self
        menu.addItem(requestPermissionItem)
        menu.addItem(.separator())

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.1.0"
        let versionItem = NSMenuItem(
            title: "Version \(version)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(
            title: "Quit Focus Veil",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        onPermissionRefresh?(false)
    }

    @objc private func toggleEffect(_ sender: NSMenuItem) {
        onEnabledChange?(sender.state != .on)
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard AppearancePreset.allCases.indices.contains(sender.tag) else { return }
        onPresetChange?(AppearancePreset.allCases[sender.tag])
    }

    @objc private func requestPermission() {
        onPermissionRefresh?(true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateAccessibilityLabel() {
        let state: String
        if !permissionGranted {
            state = "Accessibility access required"
        } else if isEffectEnabled {
            state = "enabled"
        } else {
            state = "disabled"
        }

        statusItem.button?.setAccessibilityLabel("Focus Veil, \(state)")
    }
}
