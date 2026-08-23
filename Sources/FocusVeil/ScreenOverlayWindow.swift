import AppKit
import CoreGraphics

@MainActor
final class ScreenOverlayWindow: NSWindow {
    let displayID: CGDirectDisplayID

    private let overlayView: BlurOverlayView

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
            .stationary,
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

    func update(preset: AppearancePreset, localCutout: CGRect?) {
        overlayView.update(preset: preset, cutoutRect: localCutout)
    }

    func showWithoutActivating() {
        orderFrontRegardless()
    }

    func hideOverlay() {
        orderOut(nil)
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
