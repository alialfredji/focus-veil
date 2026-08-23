import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    var onEnabledChange: ((Bool) -> Void)?
    var onIntensityChange: ((Double) -> Void)?
    var onPermissionRefresh: ((Bool) -> Void)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var toggleItem: NSMenuItem!
    private var intensityItem: NSMenuItem!
    private var intensityLabel: NSTextField!
    private var intensitySlider: NSSlider!
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
        intensity: Double,
        permissionGranted: Bool
    ) {
        isEffectEnabled = isEnabled
        self.permissionGranted = permissionGranted

        toggleItem.state = isEnabled ? .on : .off
        toggleItem.isEnabled = permissionGranted

        intensitySlider.doubleValue = intensity
        intensitySlider.isEnabled = permissionGranted
        intensityItem.isEnabled = permissionGranted
        updateIntensityDisplay(intensity)

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

        intensityItem = NSMenuItem(title: "Intensity", action: nil, keyEquivalent: "")
        intensityItem.view = makeIntensityView()
        menu.addItem(intensityItem)
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

    @objc private func intensityChanged(_ sender: NSSlider) {
        updateIntensityDisplay(sender.doubleValue)
        onIntensityChange?(sender.doubleValue)
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

    private func makeIntensityView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 46))

        intensityLabel = NSTextField(labelWithString: "Intensity")
        intensityLabel.font = NSFont.menuFont(ofSize: 0)
        intensityLabel.frame = NSRect(x: 14, y: 26, width: 192, height: 16)
        container.addSubview(intensityLabel)

        intensitySlider = NSSlider(
            value: Preferences.defaultIntensity,
            minValue: Preferences.minimumIntensity,
            maxValue: Preferences.maximumIntensity,
            target: self,
            action: #selector(intensityChanged(_:))
        )
        intensitySlider.isContinuous = true
        intensitySlider.controlSize = .small
        intensitySlider.frame = NSRect(x: 12, y: 3, width: 196, height: 22)
        intensitySlider.setAccessibilityLabel("Veil intensity")
        container.addSubview(intensitySlider)

        updateIntensityDisplay(Preferences.defaultIntensity)
        return container
    }

    private func updateIntensityDisplay(_ intensity: Double) {
        let percentage = Int((intensity * 100).rounded())
        intensityLabel?.stringValue = "Intensity  \(percentage)%"
        intensitySlider?.setAccessibilityValueDescription("\(percentage) percent")
    }
}
