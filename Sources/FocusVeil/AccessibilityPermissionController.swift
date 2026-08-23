@preconcurrency import ApplicationServices
import Foundation
import os

@MainActor
final class AccessibilityPermissionController: NSObject {
    var onChange: ((Bool) -> Void)?

    private(set) var isTrusted: Bool

    private let logger = Logger(
        subsystem: "com.alialfredji.focusveil",
        category: "accessibility-permission"
    )
    private var isMonitoring = false
    private var pollingTimer: Timer?

    init(promptOnLaunch: Bool = true) {
        isTrusted = Self.readTrust(prompt: promptOnLaunch)
        super.init()

        logger.notice("event=permission_initial trusted=\(self.isTrusted, privacy: .public)")
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        refresh()
    }

    func stop() {
        isMonitoring = false
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func refresh(prompt: Bool = false) {
        let updatedTrust = Self.readTrust(prompt: prompt)
        let didChange = updatedTrust != isTrusted

        isTrusted = updatedTrust

        if isMonitoring && !updatedTrust {
            startPollingIfNeeded()
        } else {
            pollingTimer?.invalidate()
            pollingTimer = nil
        }

        guard didChange else { return }

        logger.notice("event=permission_changed trusted=\(updatedTrust, privacy: .public)")
        onChange?(updatedTrust)
    }

    @objc private func pollingTimerFired(_ timer: Timer) {
        refresh()
    }

    private func startPollingIfNeeded() {
        guard pollingTimer == nil else { return }

        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(pollingTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer

        logger.debug("event=permission_polling_started")
    }

    private static func readTrust(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt,
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
