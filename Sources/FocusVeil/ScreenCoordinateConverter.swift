import Foundation

enum ScreenCoordinateConverter {
    static func cocoaRect(fromAX axRect: CGRect, primaryScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: axRect.minX,
            y: primaryScreenFrame.maxY - axRect.minY - axRect.height,
            width: axRect.width,
            height: axRect.height
        )
    }

    static func localCutout(for cocoaRect: CGRect, in overlayFrame: CGRect) -> CGRect? {
        let intersection = cocoaRect.intersection(overlayFrame)

        guard !intersection.isNull, !intersection.isEmpty else {
            return nil
        }

        return intersection.offsetBy(dx: -overlayFrame.minX, dy: -overlayFrame.minY)
    }
}
