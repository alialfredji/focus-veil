import CoreGraphics
import XCTest
@testable import FocusVeil

final class PointerShakeGestureRecognizerTests: XCTestCase {
    func testDeliberateHorizontalShakeTriggersOnce() {
        var recognizer = PointerShakeGestureRecognizer()

        XCTAssertFalse(recognizer.process(point: CGPoint(x: 0, y: 0), timestamp: 0))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 80, y: 0), timestamp: 0.1))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 0, y: 0), timestamp: 0.2))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 80, y: 0), timestamp: 0.3))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 0, y: 0), timestamp: 0.4))
        XCTAssertTrue(recognizer.process(point: CGPoint(x: 80, y: 0), timestamp: 0.5))
    }

    func testOneWayMovementDoesNotTrigger() {
        var recognizer = PointerShakeGestureRecognizer()

        for index in 0 ... 8 {
            XCTAssertFalse(
                recognizer.process(
                    point: CGPoint(x: CGFloat(index * 60), y: 0),
                    timestamp: TimeInterval(index) * 0.1
                )
            )
        }
    }

    func testSlowReversalsDoNotCombineIntoShake() {
        var recognizer = PointerShakeGestureRecognizer()

        XCTAssertFalse(recognizer.process(point: CGPoint(x: 0, y: 0), timestamp: 0))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 100, y: 0), timestamp: 0.1))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 0, y: 0), timestamp: 0.6))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 100, y: 0), timestamp: 1.1))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 0, y: 0), timestamp: 1.6))
        XCTAssertFalse(recognizer.process(point: CGPoint(x: 100, y: 0), timestamp: 2.1))
    }

    func testCooldownPreventsImmediateSecondToggle() {
        var recognizer = PointerShakeGestureRecognizer()
        let points: [CGFloat] = [0, 80, 0, 80, 0, 80]

        for (index, point) in points.enumerated() {
            _ = recognizer.process(
                point: CGPoint(x: point, y: 0),
                timestamp: TimeInterval(index) * 0.1
            )
        }

        for (index, point) in points.enumerated() {
            XCTAssertFalse(
                recognizer.process(
                    point: CGPoint(x: point, y: 0),
                    timestamp: 0.7 + (TimeInterval(index) * 0.1)
                )
            )
        }
    }
}
