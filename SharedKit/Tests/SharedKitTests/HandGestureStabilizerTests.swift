import XCTest
@testable import SharedKit

final class HandGestureStabilizerTests: XCTestCase {
    func testStaysNoneUntilAGestureRepeatsEnoughTimes() {
        let stabilizer = HandGestureStabilizer()
        XCTAssertEqual(stabilizer.push(.openPalm), .none)
        XCTAssertEqual(stabilizer.push(.openPalm), .none)
        XCTAssertEqual(stabilizer.push(.openPalm), .openPalm)
    }

    func testToleratesAnOccasionalMisclassifiedFrameInAnOtherwiseHeldGesture() {
        // Regression test for the same class of bug fixed in
        // ExpressionBaselineTracker: showing the raw per-frame
        // classification directly means a single frame where the hand's
        // angle briefly pushes one finger across a threshold flashes the
        // wrong gesture (or .none) before correcting itself. A majority
        // vote over a small window must tolerate that instead of losing
        // the real gesture entirely.
        let stabilizer = HandGestureStabilizer()
        let sequence: [DetectedGesture] = [.openPalm, .openPalm, .none, .openPalm, .openPalm, .pointing, .openPalm]
        var last: DetectedGesture = .none
        for gesture in sequence { last = stabilizer.push(gesture) }
        XCTAssertEqual(last, .openPalm)
    }

    func testSwitchesToANewGestureOnceItDominatesTheWindow() {
        let stabilizer = HandGestureStabilizer()
        for _ in 0..<5 { _ = stabilizer.push(.openPalm) }
        var last: DetectedGesture = .none
        for _ in 0..<5 { last = stabilizer.push(.closedFist) }
        XCTAssertEqual(last, .closedFist)
    }
}
