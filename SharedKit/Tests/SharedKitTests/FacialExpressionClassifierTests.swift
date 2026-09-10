import XCTest
@testable import SharedKit

final class FacialExpressionClassifierTests: XCTestCase {
    /// A rough oval of outer-lip points, deliberately starting at the *top*
    /// of the mouth (not a corner) and going clockwise — this is the kind
    /// of ordering Vision's `outerLips` region is not guaranteed to avoid,
    /// and exactly what broke the old fixed-index assumption
    /// (`outerLips[0]`/`outerLips[count/2]`).
    private func mouthOval(cornerLift: CGFloat) -> [CGPoint] {
        let midY: CGFloat = 0.5
        return [
            CGPoint(x: 0.50, y: midY + 0.02),   // top lip center (index 0 — NOT a corner)
            CGPoint(x: 0.55, y: midY + 0.015),
            CGPoint(x: 0.60, y: midY + cornerLift), // right corner
            CGPoint(x: 0.55, y: midY - 0.015),
            CGPoint(x: 0.50, y: midY - 0.02),   // bottom lip center (index 4 — NOT a corner)
            CGPoint(x: 0.45, y: midY - 0.015),
            CGPoint(x: 0.40, y: midY + cornerLift), // left corner
            CGPoint(x: 0.45, y: midY + 0.015),
        ]
    }

    func testFindsRealCornersRegardlessOfPointOrder() {
        // Regression test for the real bug reported this session: a user's
        // "lift" debug number barely moved between a neutral face and a
        // clear smile. Root cause was assuming the corners live at fixed
        // indices (0 and count/2) in `outerLips`, when Vision doesn't
        // guarantee that ordering — the fixed indices sometimes landed on
        // the top/bottom lip midpoints instead of the actual corners.
        let neutral = mouthOval(cornerLift: 0)
        let smiling = mouthOval(cornerLift: 0.03)

        let neutralLift = FacialExpressionClassifier.mouthCornerLift(neutral)
        let smilingLift = FacialExpressionClassifier.mouthCornerLift(smiling)

        XCTAssertNotNil(neutralLift)
        XCTAssertNotNil(smilingLift)
        // The whole point of the metric: a real smile must move it by
        // something close to the actual corner displacement, not by
        // whatever tiny residual the wrong points happened to pick up.
        XCTAssertGreaterThan(smilingLift! - neutralLift!, 0.02)
    }

    func testReturnsNilForTooFewPoints() {
        XCTAssertNil(FacialExpressionClassifier.mouthCornerLift([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]))
    }
}
