import XCTest
@testable import SharedKit

private let neutral = ExpressionScores(mouthCornerLift: 0.001, mouthOpenAmount: 0.01, eyeOpenRatio: 0.3, browRaise: 0.05)

/// Feeds `count` frames of `scores` through the tracker and returns the last
/// classification. The tracker has two deliberately slow stages (a fast EMA
/// smoothing filter, then a hysteresis streak requirement) that only settle
/// after several repeated frames — a single call isn't representative of how
/// it behaves live, so tests always feed a run of frames like the real
/// detection loop does.
private func feed(_ tracker: ExpressionBaselineTracker, _ scores: ExpressionScores, _ count: Int) -> FacialExpression {
    var last: FacialExpression = .none
    for _ in 0..<count {
        last = tracker.classify(scores)
    }
    return last
}

final class ExpressionBaselineTrackerTests: XCTestCase {
    func testStaysNoneOnStillNeutralFace() {
        let tracker = ExpressionBaselineTracker()
        XCTAssertEqual(feed(tracker, neutral, 30), .none)
    }

    func testIgnoresSmallFrameToFrameJitter() {
        // Regression test for the bug found this session: classifying
        // straight off raw per-frame scores let ordinary landmark jitter
        // alone cross the (very small) delta thresholds and flip the badge
        // with no real expression change.
        let tracker = ExpressionBaselineTracker()
        _ = feed(tracker, neutral, 10)
        let jitterUp = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift + 0.001,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise
        )
        let jitterDown = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift - 0.001,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise
        )
        var sawNonNone = false
        for i in 0..<20 {
            if tracker.classify(i % 2 == 0 ? jitterUp : jitterDown) != .none {
                sawNonNone = true
            }
        }
        XCTAssertFalse(sawNonNone)
    }

    func testDetectsHeldSmile() {
        let tracker = ExpressionBaselineTracker()
        _ = feed(tracker, neutral, 10)
        let smiling = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift + 0.02,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise
        )
        XCTAssertEqual(feed(tracker, smiling, 20), .smile)
    }

    func testDetectsHeldSad() {
        let tracker = ExpressionBaselineTracker()
        _ = feed(tracker, neutral, 10)
        let sad = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift - 0.02,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise
        )
        XCTAssertEqual(feed(tracker, sad, 20), .sad)
    }

    func testDetectsHeldAngry() {
        let tracker = ExpressionBaselineTracker()
        _ = feed(tracker, neutral, 10)
        let angry = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise - 0.06
        )
        XCTAssertEqual(feed(tracker, angry, 20), .angry)
    }

    func testDetectsHeldSurprised() {
        let tracker = ExpressionBaselineTracker()
        _ = feed(tracker, neutral, 10)
        let surprised = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift,
            mouthOpenAmount: neutral.mouthOpenAmount + 0.08,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise + 0.07
        )
        XCTAssertEqual(feed(tracker, surprised, 20), .surprised)
    }

    func testDetectsBlinkFromRawScore() {
        let tracker = ExpressionBaselineTracker()
        _ = feed(tracker, neutral, 10)
        let blinking = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: 0.05,
            browRaise: neutral.browRaise
        )
        XCTAssertEqual(feed(tracker, blinking, 5), .blink)
    }

    func testResetClearsBaselineAndHysteresis() {
        let tracker = ExpressionBaselineTracker()
        _ = feed(tracker, neutral, 10)
        let smiling = ExpressionScores(
            mouthCornerLift: neutral.mouthCornerLift + 0.02,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise
        )
        _ = feed(tracker, smiling, 20)
        tracker.reset()
        // Right after a reset there's no baseline yet, so even a
        // dramatically different first frame must read as "none" rather
        // than immediately re-triggering the previous classification.
        XCTAssertEqual(tracker.classify(smiling), .none)
    }

    func testAdaptsBaselineToADifferentRestingFace() {
        // A face with a naturally different resting mouth-corner score
        // should settle back to "none" once treated as the new neutral,
        // instead of permanently reading as "smiling" — the whole point of
        // a baseline instead of a fixed absolute threshold.
        let tracker = ExpressionBaselineTracker()
        let differentRestingFace = ExpressionScores(
            mouthCornerLift: 0.03,
            mouthOpenAmount: neutral.mouthOpenAmount,
            eyeOpenRatio: neutral.eyeOpenRatio,
            browRaise: neutral.browRaise
        )
        XCTAssertEqual(feed(tracker, differentRestingFace, 300), .none)
    }
}
