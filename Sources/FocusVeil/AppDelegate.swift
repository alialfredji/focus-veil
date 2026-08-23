import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()

    private var accessibilityPermissionController: AccessibilityPermissionController?
    private var focusedWindowTracker: FocusedWindowTracker?
    private var overlayCoordinator: OverlayCoordinator?
    private var pointerShakeDetector: PointerShakeDetector?
    private var statusMenuController: StatusMenuController?
    private var focusedWindowSnapshot: FocusedWindowSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let permissionController = AccessibilityPermissionController(promptOnLaunch: true)
        let windowTracker = FocusedWindowTracker()
        let overlayCoordinator = OverlayCoordinator()
        let pointerShakeDetector = PointerShakeDetector()
        let menuController = StatusMenuController()

        accessibilityPermissionController = permissionController
        focusedWindowTracker = windowTracker
        self.overlayCoordinator = overlayCoordinator
        self.pointerShakeDetector = pointerShakeDetector
        statusMenuController = menuController

        permissionController.onChange = { [weak self] _ in
            self?.reconcileState()
        }
        windowTracker.onChange = { [weak self] snapshot in
            self?.focusedWindowSnapshot = snapshot
            self?.reconcileOverlay()
        }
        menuController.onEnabledChange = { [weak self] isEnabled in
            guard let self else { return }
            preferences.isEnabled = isEnabled
            reconcileState()
        }
        menuController.onIntensityChange = { [weak self] intensity in
            guard let self else { return }
            preferences.intensity = intensity
            reconcileState()
        }
        menuController.onPermissionRefresh = { [weak permissionController] shouldPrompt in
            permissionController?.refresh(prompt: shouldPrompt)
        }
        pointerShakeDetector.onShake = { [weak self] in
            guard let self else { return }
            preferences.isEnabled.toggle()
            reconcileState()
        }

        pointerShakeDetector.start()
        permissionController.startMonitoring()
        reconcileState()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        accessibilityPermissionController?.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusedWindowTracker?.stop()
        focusedWindowTracker = nil
        focusedWindowSnapshot = nil

        overlayCoordinator?.stop()
        overlayCoordinator = nil

        pointerShakeDetector?.stop()
        pointerShakeDetector = nil

        accessibilityPermissionController?.stop()
        accessibilityPermissionController = nil

        statusMenuController?.stop()
        statusMenuController = nil
    }

    private func reconcileState() {
        guard let permissionController = accessibilityPermissionController,
              let windowTracker = focusedWindowTracker,
              let menuController = statusMenuController
        else {
            return
        }

        let shouldTrack = permissionController.isTrusted && preferences.isEnabled
        if shouldTrack {
            windowTracker.start()
        } else {
            windowTracker.stop()
            focusedWindowSnapshot = nil
        }

        reconcileOverlay()

        menuController.update(
            isEnabled: preferences.isEnabled,
            intensity: preferences.intensity,
            permissionGranted: permissionController.isTrusted
        )
    }

    private func reconcileOverlay() {
        guard let permissionController = accessibilityPermissionController,
              let overlayCoordinator
        else {
            return
        }

        let shouldShow = permissionController.isTrusted
            && preferences.isEnabled
            && focusedWindowSnapshot != nil
        overlayCoordinator.update(
            isVisible: shouldShow,
            snapshot: focusedWindowSnapshot,
            intensity: preferences.intensity
        )
    }
}
