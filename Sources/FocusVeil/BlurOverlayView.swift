import AppKit
import QuartzCore

@MainActor
final class BlurOverlayView: NSView {
    private static let cutoutInset: CGFloat = 1
    private static let cutoutCornerRadius: CGFloat = 14
    private static let transitionDuration: TimeInterval = 0.16

    private let effectView: NSVisualEffectView
    private let tintView: NSView
    private let maskLayer = CAShapeLayer()
    private var cutoutRect: CGRect?

    override init(frame frameRect: NSRect) {
        effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: frameRect.size))
        tintView = NSView(frame: NSRect(origin: .zero, size: frameRect.size))
        super.init(frame: frameRect)

        wantsLayer = true

        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .behindWindow
        effectView.material = .underWindowBackground
        effectView.state = .active
        addSubview(effectView)

        tintView.wantsLayer = true
        tintView.autoresizingMask = [.width, .height]
        tintView.layer?.backgroundColor = NSColor.black.cgColor
        addSubview(tintView)

        maskLayer.fillColor = NSColor.black.cgColor
        maskLayer.fillRule = .evenOdd
        layer?.mask = maskLayer

        update(
            intensity: Preferences.defaultIntensity,
            cutoutRect: nil,
            animated: false
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        effectView.frame = bounds
        tintView.frame = bounds
        maskLayer.frame = bounds
        updateMaskPath(previousCutout: nil, animated: false)
        CATransaction.commit()
    }

    func update(intensity: Double, cutoutRect: CGRect?, animated: Bool) {
        let previousCutout = self.cutoutRect
        self.cutoutRect = cutoutRect

        let clampedIntensity = min(max(intensity, 0), 1)
        let effectAlpha = 0.15 + (clampedIntensity * 0.85)
        let tintAlpha = 0.02 + (clampedIntensity * 0.32)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                effectView.animator().alphaValue = effectAlpha
                tintView.animator().alphaValue = tintAlpha
            }
        } else {
            effectView.alphaValue = effectAlpha
            tintView.alphaValue = tintAlpha
        }

        updateMaskPath(previousCutout: previousCutout, animated: animated)
    }

    private func updateMaskPath(previousCutout: CGRect?, animated: Bool) {
        let newPath = makeMaskPath()
        let currentPath = maskLayer.presentation()?.path ?? maskLayer.path

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.path = newPath
        CATransaction.commit()

        guard animated,
              previousCutout != nil,
              cutoutRect != nil,
              previousCutout != cutoutRect,
              let currentPath
        else {
            maskLayer.removeAnimation(forKey: "cutoutPath")
            return
        }

        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = currentPath
        animation.toValue = newPath
        animation.duration = Self.transitionDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        maskLayer.add(animation, forKey: "cutoutPath")
    }

    private func makeMaskPath() -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)

        if let cutoutRect {
            let fillsOverlay = cutoutRect.contains(
                bounds.insetBy(dx: Self.cutoutInset, dy: Self.cutoutInset)
            )
            let adjustedCutout = fillsOverlay
                ? cutoutRect.insetBy(
                    dx: -Self.cutoutCornerRadius,
                    dy: -Self.cutoutCornerRadius
                )
                : cutoutRect.insetBy(
                    dx: Self.cutoutInset,
                    dy: Self.cutoutInset
                )

            if !adjustedCutout.isNull,
               !adjustedCutout.isInfinite,
               !adjustedCutout.isEmpty
            {
                path.addRoundedRect(
                    in: adjustedCutout,
                    cornerWidth: Self.cutoutCornerRadius,
                    cornerHeight: Self.cutoutCornerRadius
                )
            }
        }

        return path
    }
}
