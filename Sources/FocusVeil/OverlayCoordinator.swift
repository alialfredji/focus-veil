import AppKit
import CoreGraphics

@MainActor
final class OverlayCoordinator: NSObject {
    private var windows: [CGDirectDisplayID: ScreenOverlayWindow] = [:]
    private var isVisible = false
    private var snapshot: FocusedWindowSnapshot?
    private var preset: AppearancePreset = .medium

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
        preset: AppearancePreset
    ) {
        self.isVisible = isVisible
        self.snapshot = snapshot
        self.preset = preset
        render()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        hideAll()
        windows.removeAll()
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        render()
    }

    private func render() {
        guard isVisible,
              let snapshot,
              let primaryScreen = NSScreen.screens.first
        else {
            hideAll()
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
            window.update(preset: preset, localCutout: localCutout)
            window.showWithoutActivating()
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
            windows[displayID]?.hideOverlay()
            windows.removeValue(forKey: displayID)
        }
    }

    private func hideAll() {
        for window in windows.values {
            window.hideOverlay()
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
