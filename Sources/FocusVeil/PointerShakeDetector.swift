import AppKit
import os

struct PointerShakeGestureRecognizer {
    private static let maximumSequenceDuration: TimeInterval = 2.0
    private static let maximumEventGap: TimeInterval = 0.45
    private static let cooldownDuration: TimeInterval = 1.8
    private static let minimumSampleDistance: CGFloat = 4
    private static let minimumLegDistance: CGFloat = 45
    private static let minimumTotalDistance: CGFloat = 320
    private static let requiredReversals = 4

    private var lastPoint: CGPoint?
    private var lastEventTime: TimeInterval?
    private var sequenceStartTime: TimeInterval?
    private var horizontalDirection: CGFloat = 0
    private var legDistance: CGFloat = 0
    private var totalDistance: CGFloat = 0
    private var reversalCount = 0
    private var cooldownUntil: TimeInterval = 0

    mutating func process(point: CGPoint, timestamp: TimeInterval) -> Bool {
        defer {
            lastPoint = point
            lastEventTime = timestamp
        }

        guard timestamp >= cooldownUntil else { return false }
        guard let lastPoint, let lastEventTime else { return false }

        guard timestamp - lastEventTime <= Self.maximumEventGap else {
            resetSequence()
            return false
        }

        let horizontalDelta = point.x - lastPoint.x
        let sampleDistance = abs(horizontalDelta)
        guard sampleDistance >= Self.minimumSampleDistance else { return false }

        if sequenceStartTime == nil {
            sequenceStartTime = timestamp
        }

        guard let sequenceStartTime,
              timestamp - sequenceStartTime <= Self.maximumSequenceDuration
        else {
            resetSequence()
            self.sequenceStartTime = timestamp
            horizontalDirection = horizontalDelta.sign == .minus ? -1 : 1
            legDistance = sampleDistance
            totalDistance = sampleDistance
            return false
        }

        totalDistance += sampleDistance
        let newDirection: CGFloat = horizontalDelta.sign == .minus ? -1 : 1

        if horizontalDirection == 0 {
            horizontalDirection = newDirection
            legDistance = sampleDistance
        } else if newDirection == horizontalDirection {
            legDistance += sampleDistance
        } else if legDistance >= Self.minimumLegDistance {
            reversalCount += 1
            horizontalDirection = newDirection
            legDistance = sampleDistance
        } else {
            legDistance = max(0, legDistance - sampleDistance)
        }

        guard reversalCount >= Self.requiredReversals,
              totalDistance >= Self.minimumTotalDistance
        else {
            return false
        }

        cooldownUntil = timestamp + Self.cooldownDuration
        resetSequence()
        return true
    }

    private mutating func resetSequence() {
        sequenceStartTime = nil
        horizontalDirection = 0
        legDistance = 0
        totalDistance = 0
        reversalCount = 0
    }
}

@MainActor
final class PointerShakeDetector {
    var onShake: (() -> Void)?

    private let logger = Logger(
        subsystem: "com.alialfredji.focusveil",
        category: "pointer-shake"
    )
    private var monitor: Any?
    private var recognizer = PointerShakeGestureRecognizer()

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) {
            [weak self] event in
            let point = NSEvent.mouseLocation
            let timestamp = event.timestamp

            Task { @MainActor [weak self] in
                self?.process(point: point, timestamp: timestamp)
            }
        }
    }

    func stop() {
        guard let monitor else { return }

        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func process(point: CGPoint, timestamp: TimeInterval) {
        guard recognizer.process(point: point, timestamp: timestamp) else { return }

        logger.notice("event=pointer_shake_detected")
        onShake?()
    }
}
