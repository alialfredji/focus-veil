import AppKit
import QuartzCore

@MainActor
final class BlurOverlayView: NSView {
    private static let cutoutInset: CGFloat = 0.5
    private static let cutoutCornerRadius: CGFloat = 17
    private static let transitionDuration: TimeInterval = 0.16

    private let effectView: NSVisualEffectView
    private let tintView: NSView
    private let maskLayer = CAShapeLayer()
    private let focusLiftLayer = CAShapeLayer()
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

        focusLiftLayer.fillColor = NSColor.clear.cgColor
        focusLiftLayer.strokeColor = NSColor.white.withAlphaComponent(0.34).cgColor
        focusLiftLayer.lineWidth = 1.5
        focusLiftLayer.lineJoin = .round
        focusLiftLayer.shadowColor = NSColor.black.cgColor
        focusLiftLayer.shadowOpacity = 0.72
        focusLiftLayer.shadowRadius = 24
        focusLiftLayer.shadowOffset = CGSize(width: 0, height: -3)
        focusLiftLayer.allowsEdgeAntialiasing = true
        layer?.addSublayer(focusLiftLayer)

        update(
            intensity: Preferences.defaultIntensity,
            backgroundTreatment: .defaultValue,
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
        focusLiftLayer.frame = bounds
        updateMaskPath(previousCutout: nil, animated: false)
        CATransaction.commit()
    }

    func update(
        intensity: Double,
        backgroundTreatment: BackgroundTreatment,
        cutoutRect: CGRect?,
        animated: Bool
    ) {
        let previousCutout = self.cutoutRect
        self.cutoutRect = cutoutRect

        let clampedIntensity = min(max(intensity, 0), 1)
        let appearance = Self.appearance(
            for: backgroundTreatment,
            intensity: clampedIntensity
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                effectView.animator().alphaValue = appearance.effectAlpha
                tintView.animator().alphaValue = appearance.tintAlpha
            }
        } else {
            effectView.alphaValue = appearance.effectAlpha
            tintView.alphaValue = appearance.tintAlpha
        }

        updateFocusLiftOpacity(
            Float(0.68 + (clampedIntensity * 0.32)),
            animated: animated
        )
        updateMaskPath(previousCutout: previousCutout, animated: animated)
    }

    private func updateMaskPath(previousCutout: CGRect?, animated: Bool) {
        let newPath = makeMaskPath()
        let newFocusPath = makeFocusPath()
        let currentPath = maskLayer.presentation()?.path ?? maskLayer.path
        let currentFocusPath = focusLiftLayer.presentation()?.path ?? focusLiftLayer.path
        let currentShadowPath = focusLiftLayer.presentation()?.shadowPath
            ?? focusLiftLayer.shadowPath

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.path = newPath
        focusLiftLayer.path = newFocusPath
        focusLiftLayer.shadowPath = newFocusPath
        focusLiftLayer.isHidden = newFocusPath == nil
        CATransaction.commit()

        guard animated,
              previousCutout != nil,
              cutoutRect != nil,
              previousCutout != cutoutRect,
              let currentPath
        else {
            maskLayer.removeAnimation(forKey: "cutoutPath")
            focusLiftLayer.removeAnimation(forKey: "focusPath")
            focusLiftLayer.removeAnimation(forKey: "focusShadowPath")
            return
        }

        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = currentPath
        animation.toValue = newPath
        animation.duration = Self.transitionDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        maskLayer.add(animation, forKey: "cutoutPath")

        if let currentFocusPath, let newFocusPath {
            let focusAnimation = CABasicAnimation(keyPath: "path")
            focusAnimation.fromValue = currentFocusPath
            focusAnimation.toValue = newFocusPath
            focusAnimation.duration = Self.transitionDuration
            focusAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            focusLiftLayer.add(focusAnimation, forKey: "focusPath")
        }

        if let currentShadowPath, let newFocusPath {
            let shadowAnimation = CABasicAnimation(keyPath: "shadowPath")
            shadowAnimation.fromValue = currentShadowPath
            shadowAnimation.toValue = newFocusPath
            shadowAnimation.duration = Self.transitionDuration
            shadowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            focusLiftLayer.add(shadowAnimation, forKey: "focusShadowPath")
        }
    }

    private func makeMaskPath() -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)

        if let geometry = cutoutGeometry() {
            path.addRoundedRect(
                in: geometry.rect,
                cornerWidth: geometry.cornerRadius,
                cornerHeight: geometry.cornerRadius
            )
        }

        return path
    }

    private func makeFocusPath() -> CGPath? {
        guard let geometry = cutoutGeometry(), !geometry.fillsOverlay else { return nil }

        return CGPath(
            roundedRect: geometry.rect,
            cornerWidth: geometry.cornerRadius,
            cornerHeight: geometry.cornerRadius,
            transform: nil
        )
    }

    private func cutoutGeometry() -> (
        rect: CGRect,
        cornerRadius: CGFloat,
        fillsOverlay: Bool
    )? {
        guard let cutoutRect else { return nil }

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

        guard !adjustedCutout.isNull,
              !adjustedCutout.isInfinite,
              !adjustedCutout.isEmpty
        else {
            return nil
        }

        let cornerRadius = min(
            Self.cutoutCornerRadius,
            adjustedCutout.width / 2,
            adjustedCutout.height / 2
        )
        return (adjustedCutout, cornerRadius, fillsOverlay)
    }

    private func updateFocusLiftOpacity(_ opacity: Float, animated: Bool) {
        let currentOpacity = focusLiftLayer.presentation()?.opacity
            ?? focusLiftLayer.opacity

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        focusLiftLayer.opacity = opacity
        CATransaction.commit()

        guard animated, abs(currentOpacity - opacity) > 0.001 else {
            focusLiftLayer.removeAnimation(forKey: "focusOpacity")
            return
        }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = currentOpacity
        animation.toValue = opacity
        animation.duration = Self.transitionDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        focusLiftLayer.add(animation, forKey: "focusOpacity")
    }

    private static func appearance(
        for treatment: BackgroundTreatment,
        intensity: Double
    ) -> (effectAlpha: CGFloat, tintAlpha: CGFloat) {
        let intensity = CGFloat(intensity)

        switch treatment {
        case .softFrost:
            return (
                effectAlpha: 0.16 + (intensity * 0.68),
                tintAlpha: 0.01 + (intensity * 0.18)
            )
        case .balanced:
            return (
                effectAlpha: 0.15 + (intensity * 0.85),
                tintAlpha: 0.02 + (intensity * 0.32)
            )
        case .deepFocus:
            return (
                effectAlpha: 0.28 + (intensity * 0.72),
                tintAlpha: 0.08 + (intensity * 0.44)
            )
        }
    }
}
