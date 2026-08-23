import AppKit
import QuartzCore

@MainActor
final class BlurOverlayView: NSView {
    private static let cutoutExpansion: CGFloat = 2
    private static let cutoutCornerRadius: CGFloat = 12

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
        effectView.state = .active
        addSubview(effectView)

        tintView.wantsLayer = true
        tintView.autoresizingMask = [.width, .height]
        tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
        addSubview(tintView)

        maskLayer.fillColor = NSColor.black.cgColor
        maskLayer.fillRule = .evenOdd
        layer?.mask = maskLayer

        update(preset: .medium, cutoutRect: nil)
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
        updateMaskPath()
        CATransaction.commit()
    }

    func update(preset: AppearancePreset, cutoutRect: CGRect?) {
        self.cutoutRect = cutoutRect

        let appearance = Self.appearance(for: preset)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        effectView.material = appearance.material
        tintView.layer?.backgroundColor = NSColor.black
            .withAlphaComponent(appearance.tintAlpha)
            .cgColor
        updateMaskPath()
        CATransaction.commit()
    }

    private func updateMaskPath() {
        let path = CGMutablePath()
        path.addRect(bounds)

        if let cutoutRect {
            let expandedCutout = cutoutRect
                .insetBy(dx: -Self.cutoutExpansion, dy: -Self.cutoutExpansion)

            if !expandedCutout.isNull,
               !expandedCutout.isInfinite,
               !expandedCutout.isEmpty
            {
                path.addRoundedRect(
                    in: expandedCutout,
                    cornerWidth: Self.cutoutCornerRadius,
                    cornerHeight: Self.cutoutCornerRadius
                )
            }
        }

        maskLayer.path = path
    }

    private static func appearance(
        for preset: AppearancePreset
    ) -> (material: NSVisualEffectView.Material, tintAlpha: CGFloat) {
        switch preset {
        case .soft:
            (.underWindowBackground, 0.12)
        case .medium:
            (.underWindowBackground, 0.22)
        case .strong:
            (.underWindowBackground, 0.34)
        }
    }
}
