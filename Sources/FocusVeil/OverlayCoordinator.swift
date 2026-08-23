import AppKit
import CoreGraphics

@MainActor
final class OverlayCoordinator: NSObject {
    private var windows: [CGDirectDisplayID: ScreenOverlayWindow] = [:]
    private var isVisible = false
    private var snapshot: FocusedWindowSnapshot?
    private var intensity = Preferences.defaultIntensity
    private var backgroundTreatment = BackgroundTreatment.defaultValue

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func update(
        isVisible: Bool,
        snapshot: FocusedWindowSnapshot?,
        intensity: Double,
        backgroundTreatment: BackgroundTreatment
    ) {
        self.isVisible = isVisible
        self.snapshot = snapshot
        self.intensity = intensity
        self.backgroundTreatment = backgroundTreatment
        render()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        hideAll(animated: false)
        windows.removeAll()
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        render()
    }

    private func render() {
        let animated = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        guard isVisible,
              let snapshot,
              let primaryScreen = NSScreen.screens.first
        else {
            hideAll(animated: animated)
            return
        }

        synchronizeWindows()

        let focusedFrame = ScreenCoordinateConverter.cocoaRect(
            fromAX: snapshot.frame,
            primaryScreenFrame: primaryScreen.frame
        )

        for screen in NSScreen.screens {
            guard let displayID = Self.displayID(for: screen),
                  let window = windows[displayID]
            else {
                continue
            }

            window.updateFrame(for: screen)
            let localCutout = ScreenCoordinateConverter.localCutout(
                for: focusedFrame,
                in: screen.visibleFrame
            )
            window.update(
                intensity: intensity,
                backgroundTreatment: backgroundTreatment,
                localCutout: localCutout,
                animated: animated
            )
            window.showWithoutActivating(animated: animated)
        }
    }

    private func synchronizeWindows() {
        var activeDisplayIDs = Set<CGDirectDisplayID>()

        for screen in NSScreen.screens {
            guard let displayID = Self.displayID(for: screen) else { continue }

            activeDisplayIDs.insert(displayID)
            if windows[displayID] == nil {
                windows[displayID] = ScreenOverlayWindow(screen: screen)
            }
        }

        let removedDisplayIDs = windows.keys.filter { !activeDisplayIDs.contains($0) }
        for displayID in removedDisplayIDs {
            windows[displayID]?.hideOverlay(animated: false)
            windows.removeValue(forKey: displayID)
        }
    }

    private func hideAll(animated: Bool) {
        for window in windows.values {
            window.hideOverlay(animated: animated)
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
