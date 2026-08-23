import AppKit
import CoreGraphics
import QuartzCore

@MainActor
final class ScreenOverlayWindow: NSWindow {
    private static let fadeDuration: TimeInterval = 0.18

    let displayID: CGDirectDisplayID

    private let overlayView: BlurOverlayView
    private var transitionGeneration = 0

    init?(screen: NSScreen) {
        guard let displayID = Self.displayID(for: screen) else { return nil }

        self.displayID = displayID
        overlayView = BlurOverlayView(
            frame: NSRect(origin: .zero, size: screen.visibleFrame.size)
        )

        super.init(
            contentRect: screen.visibleFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        level = NSWindow.Level(rawValue: NSWindow.Level.modalPanel.rawValue - 1)

        var behavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .transient,
            .ignoresCycle,
        ]
        if #available(macOS 26.0, *) {
            behavior.insert(.canJoinAllApplications)
        } else {
            behavior.insert(.fullScreenAuxiliary)
        }
        collectionBehavior = behavior

        contentView = overlayView
    }

    override var canBecomeKey: Bool { false }

    override var canBecomeMain: Bool { false }

    func updateFrame(for screen: NSScreen) {
        guard Self.displayID(for: screen) == displayID else { return }

        setFrame(screen.visibleFrame, display: false, animate: false)
    }

    func update(intensity: Double, localCutout: CGRect?, animated: Bool) {
        overlayView.update(
            intensity: intensity,
            cutoutRect: localCutout,
            animated: animated
        )
    }

    func showWithoutActivating(animated: Bool) {
        transitionGeneration += 1

        if !isVisible {
            alphaValue = animated ? 0 : 1
            orderFrontRegardless()
        }

        guard animated else {
            alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 1
        }
    }

    func hideOverlay(animated: Bool = true) {
        guard isVisible else { return }

        transitionGeneration += 1
        let generation = transitionGeneration

        guard animated else {
            orderOut(nil)
            alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.transitionGeneration == generation
                else {
                    return
                }

                self.orderOut(nil)
                self.alphaValue = 1
            }
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
