import XCTest
@testable import FocusVeil

final class ScreenCoordinateConverterTests: XCTestCase {
    func testConvertsAXRectOnPrimaryScreen() {
        let axRect = CGRect(x: 100, y: 80, width: 300, height: 200)
        let primaryScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertEqual(
            ScreenCoordinateConverter.cocoaRect(
                fromAX: axRect,
                primaryScreenFrame: primaryScreenFrame
            ),
            CGRect(x: 100, y: 620, width: 300, height: 200)
        )
    }

    func testReturnsLocalCutoutOnRightSecondaryDisplay() {
        let cutout = ScreenCoordinateConverter.localCutout(
            for: CGRect(x: 1_600, y: 100, width: 300, height: 200),
            in: CGRect(x: 1_440, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(cutout, CGRect(x: 160, y: 100, width: 300, height: 200))
    }

    func testReturnsLocalCutoutOnLeftSecondaryDisplay() {
        let cutout = ScreenCoordinateConverter.localCutout(
            for: CGRect(x: -1_200, y: 200, width: 400, height: 300),
            in: CGRect(x: -1_440, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(cutout, CGRect(x: 240, y: 200, width: 400, height: 300))
    }

    func testReturnsLocalCutoutOnDisplayAbovePrimary() {
        let cutout = ScreenCoordinateConverter.localCutout(
            for: CGRect(x: 80, y: 1_000, width: 300, height: 200),
            in: CGRect(x: 0, y: 900, width: 1_440, height: 900)
        )

        XCTAssertEqual(cutout, CGRect(x: 80, y: 100, width: 300, height: 200))
    }

    func testReturnsLocalCutoutOnDisplayBelowPrimary() {
        let cutout = ScreenCoordinateConverter.localCutout(
            for: CGRect(x: 80, y: -600, width: 300, height: 200),
            in: CGRect(x: 0, y: -800, width: 1_440, height: 800)
        )

        XCTAssertEqual(cutout, CGRect(x: 80, y: 200, width: 300, height: 200))
    }

    func testConvertsNegativeOverlayOriginsToLocalCoordinates() {
        let cutout = ScreenCoordinateConverter.localCutout(
            for: CGRect(x: -1_560, y: -800, width: 300, height: 200),
            in: CGRect(x: -1_600, y: -900, width: 1_000, height: 900)
        )

        XCTAssertEqual(cutout, CGRect(x: 40, y: 100, width: 300, height: 200))
    }

    func testIntersectsPartiallyOffScreenWindowBeforeReturningLocalCutout() {
        let cutout = ScreenCoordinateConverter.localCutout(
            for: CGRect(x: -100, y: 100, width: 250, height: 200),
            in: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(cutout, CGRect(x: 0, y: 100, width: 150, height: 200))
    }

    func testReturnsNilForEmptyIntersection() {
        let cutout = ScreenCoordinateConverter.localCutout(
            for: CGRect(x: 2_000, y: 100, width: 300, height: 200),
            in: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertNil(cutout)
    }
}
