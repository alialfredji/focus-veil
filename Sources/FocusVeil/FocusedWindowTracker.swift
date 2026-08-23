import AppKit
import ApplicationServices
import Foundation
import os

struct FocusedWindowSnapshot: Equatable {
    let pid: pid_t
    let frame: CGRect
}

@MainActor
final class FocusedWindowTracker: NSObject {
    var onChange: ((FocusedWindowSnapshot?) -> Void)?

    private(set) var currentSnapshot: FocusedWindowSnapshot?

    private let ownPID: pid_t
    private let workspace: NSWorkspace
    private let logger = Logger(
        subsystem: "com.alialfredji.focusveil",
        category: "focused-window"
    )

    private var isStarted = false
    private var fallbackTimer: Timer?
    private var observedPID: pid_t?
    private var observedApplication: AXUIElement?
    private var observedWindow: AXUIElement?
    private var observer: AXObserver?

    init(ownPID: pid_t = ProcessInfo.processInfo.processIdentifier) {
        self.ownPID = ownPID
        workspace = .shared
        super.init()
    }

    func start() {
        guard !isStarted else { return }

        isStarted = true
        let center = workspace.notificationCenter
        center.addObserver(
            self,
            selector: #selector(workspaceStateChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceStateChanged(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        let timer = Timer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(fallbackTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        fallbackTimer = timer

        logger.notice("event=tracking_started")
        refresh()
    }

    func stop() {
        guard isStarted else { return }

        isStarted = false
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        workspace.notificationCenter.removeObserver(self)
        detachObserver()
        publish(nil, reason: "stopped")

        logger.notice("event=tracking_stopped")
    }

    func refresh() {
        guard isStarted else { return }

        guard let application = workspace.frontmostApplication else {
            detachObserver()
            publish(nil, reason: "no_frontmost_application")
            return
        }

        let pid = application.processIdentifier
        guard pid > 0, pid != ownPID, !application.isTerminated else {
            detachObserver()
            publish(nil, reason: "invalid_or_own_application")
            return
        }

        ensureObserver(for: pid)

        let applicationElement = observedApplication ?? AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(applicationElement, 0.35)

        guard let window = focusedOrMainWindow(of: applicationElement) else {
            updateObservedWindow(nil)
            publish(nil, reason: "no_focused_or_main_window")
            return
        }

        updateObservedWindow(window)

        guard let frame = frame(of: window) else {
            publish(nil, reason: "invalid_window_frame")
            return
        }

        publish(FocusedWindowSnapshot(pid: pid, frame: frame), reason: "valid_window")
    }

    @objc private func workspaceStateChanged(_ notification: Notification) {
        logger.debug("event=workspace_changed kind=\(notification.name.rawValue, privacy: .public)")
        refresh()
    }

    @objc private func fallbackTimerFired(_ timer: Timer) {
        refresh()
    }

    fileprivate func accessibilityNotificationReceived(_ notification: String) {
        logger.debug("event=ax_notification kind=\(notification, privacy: .public)")
        refresh()
    }

    private func ensureObserver(for pid: pid_t) {
        guard observedPID != pid else { return }

        detachObserver()

        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.35)

        var newObserver: AXObserver?
        let creationError = AXObserverCreate(pid, focusedWindowObserverCallback, &newObserver)
        guard creationError == .success, let newObserver else {
            logger.debug(
                "event=ax_observer_create_failed pid=\(pid, privacy: .public) error=\(creationError.rawValue, privacy: .public)"
            )
            return
        }

        observer = newObserver
        observedPID = pid
        observedApplication = application

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(newObserver),
            .commonModes
        )

        addNotification(kAXFocusedWindowChangedNotification as CFString, element: application)
        addNotification(kAXMainWindowChangedNotification as CFString, element: application)

        logger.notice("event=ax_observer_attached pid=\(pid, privacy: .public)")
    }

    private func updateObservedWindow(_ window: AXUIElement?) {
        if let observedWindow, let window, CFEqual(observedWindow, window) {
            return
        }

        if let observedWindow {
            removeNotification(kAXWindowMovedNotification as CFString, element: observedWindow)
            removeNotification(kAXWindowResizedNotification as CFString, element: observedWindow)
        }

        observedWindow = window

        if let window {
            addNotification(kAXWindowMovedNotification as CFString, element: window)
            addNotification(kAXWindowResizedNotification as CFString, element: window)
        }
    }

    private func detachObserver() {
        guard let observer else {
            observedPID = nil
            observedApplication = nil
            observedWindow = nil
            return
        }

        if let observedWindow {
            removeNotification(kAXWindowMovedNotification as CFString, element: observedWindow)
            removeNotification(kAXWindowResizedNotification as CFString, element: observedWindow)
        }
        if let observedApplication {
            removeNotification(kAXFocusedWindowChangedNotification as CFString, element: observedApplication)
            removeNotification(kAXMainWindowChangedNotification as CFString, element: observedApplication)
        }

        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )

        self.observer = nil
        observedPID = nil
        observedApplication = nil
        observedWindow = nil
    }

    private func addNotification(_ notification: CFString, element: AXUIElement) {
        guard let observer else { return }

        let error = AXObserverAddNotification(
            observer,
            element,
            notification,
            Unmanaged.passUnretained(self).toOpaque()
        )
        guard error != .success, error != .notificationAlreadyRegistered else { return }

        logger.debug(
            "event=ax_notification_add_failed kind=\(notification as String, privacy: .public) error=\(error.rawValue, privacy: .public)"
        )
    }

    private func removeNotification(_ notification: CFString, element: AXUIElement) {
        guard let observer else { return }

        let error = AXObserverRemoveNotification(observer, element, notification)
        guard error != .success, error != .notificationNotRegistered else { return }

        logger.debug(
            "event=ax_notification_remove_failed kind=\(notification as String, privacy: .public) error=\(error.rawValue, privacy: .public)"
        )
    }

    private func focusedOrMainWindow(of application: AXUIElement) -> AXUIElement? {
        if let focusedWindow = elementAttribute(
            kAXFocusedWindowAttribute as CFString,
            of: application
        ) {
            return focusedWindow
        }

        return elementAttribute(kAXMainWindowAttribute as CFString, of: application)
    }

    private func elementAttribute(_ attribute: CFString, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let positionValue = valueAttribute(kAXPositionAttribute as CFString, of: window),
              AXValueGetType(positionValue) == .cgPoint,
              let sizeValue = valueAttribute(kAXSizeAttribute as CFString, of: window),
              AXValueGetType(sizeValue) == .cgSize
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size),
              position.x.isFinite,
              position.y.isFinite,
              size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func valueAttribute(_ attribute: CFString, of element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        return unsafeDowncast(value, to: AXValue.self)
    }

    private func publish(_ snapshot: FocusedWindowSnapshot?, reason: StaticString) {
        guard snapshot != currentSnapshot else { return }

        currentSnapshot = snapshot
        if let snapshot {
            logger.notice(
                "event=snapshot_changed state=valid pid=\(snapshot.pid, privacy: .public) x=\(snapshot.frame.origin.x, privacy: .public) y=\(snapshot.frame.origin.y, privacy: .public) width=\(snapshot.frame.width, privacy: .public) height=\(snapshot.frame.height, privacy: .public)"
            )
        } else {
            logger.notice("event=snapshot_changed state=nil reason=\(reason, privacy: .public)")
        }
        onChange?(snapshot)
    }
}

private func focusedWindowObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }

    let tracker = Unmanaged<FocusedWindowTracker>.fromOpaque(refcon).takeUnretainedValue()
    let notificationName = notification as String
    MainActor.assumeIsolated {
        tracker.accessibilityNotificationReceived(notificationName)
    }
}
