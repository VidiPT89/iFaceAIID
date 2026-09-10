import CoreGraphics

/// Classifies facial expression by how far the current frame's geometric
/// scores deviate from a slow-moving "neutral face" baseline, instead of
/// comparing to fixed absolute thresholds.
///
/// Fixed thresholds don't work well here: two different people's resting,
/// neutral face already sits at very different absolute values for these
/// ratios (natural mouth-corner height, glasses shifting the brow-eye gap,
/// camera angle) — a threshold loose enough to catch one face's smile is
/// often already past where another face's *neutral* expression sits. This
/// tracker sidesteps the problem by learning each session's own neutral
/// baseline live and classifying relative to it.
public final class ExpressionBaselineTracker {
    private var baseline: ExpressionScores?
    /// A fast-moving average of the raw scores, recomputed every frame.
    /// Vision's landmark positions jitter noticeably frame-to-frame even on
    /// a perfectly still, neutral face — classifying straight off the raw
    /// per-frame values let that jitter alone cross the (very small) delta
    /// thresholds and flip the badge between expressions with no real
    /// change in the face. Smoothing first removes that noise; the slower
    /// baseline below tracks genuine drift (lighting, pose, a different
    /// person) on top of the smoothed signal.
    private var smoothed: ExpressionScores?
    private let smoothRate: CGFloat = 0.35
    /// How fast the baseline drifts toward frames classified as neutral.
    /// Slow enough that a brief expression doesn't get "absorbed" into the
    /// baseline mid-hold, fast enough to track real drift (lighting,
    /// camera angle, person swap) within a couple of seconds at ~30fps.
    private let adaptRate: CGFloat = 0.02

    /// Hysteresis on top of the per-frame classification: the displayed
    /// expression is the most common result over the last few frames
    /// instead of the raw per-frame value.
    ///
    /// An earlier version required a classification to repeat for 3
    /// *consecutive* frames before it could be displayed — that turned out
    /// to be a real bug, not just an over-cautious setting: a real held
    /// expression is never perfectly stable frame-to-frame even after
    /// smoothing (an occasional frame reads as "none" as the mouth/eyes
    /// move slightly), and any single outlier frame reset the whole streak
    /// back to zero. In practice this meant a genuinely held expression
    /// could stay stuck showing "none" indefinitely. A small majority vote
    /// tolerates that kind of one-off noise instead of being wiped out by it.
    private var recentWindow: [FacialExpression] = []
    private let windowSize = 5
    private let requiredVotes = 3

    public init() {}

    public func reset() {
        baseline = nil
        smoothed = nil
        recentWindow = []
    }

    public func classify(_ scores: ExpressionScores) -> FacialExpression {
        guard let previousSmoothed = smoothed else {
            // First frame after (re)starting: nothing to compare against
            // yet, so seed both trackers directly rather than guessing.
            smoothed = scores
            baseline = scores
            return .none
        }

        let s = ExpressionScores(
            mouthCornerLift: previousSmoothed.mouthCornerLift + (scores.mouthCornerLift - previousSmoothed.mouthCornerLift) * smoothRate,
            mouthOpenAmount: previousSmoothed.mouthOpenAmount + (scores.mouthOpenAmount - previousSmoothed.mouthOpenAmount) * smoothRate,
            eyeOpenRatio: previousSmoothed.eyeOpenRatio + (scores.eyeOpenRatio - previousSmoothed.eyeOpenRatio) * smoothRate,
            browRaise: previousSmoothed.browRaise + (scores.browRaise - previousSmoothed.browRaise) * smoothRate
        )
        smoothed = s

        guard let base = baseline else {
            baseline = s
            return .none
        }

        let liftDelta = s.mouthCornerLift - base.mouthCornerLift
        let openDelta = s.mouthOpenAmount - base.mouthOpenAmount
        let eyeDelta = s.eyeOpenRatio - base.eyeOpenRatio
        let browDelta = s.browRaise - base.browRaise

        let mouthOpen = openDelta > 0.045
        let eyesClosed = eyeDelta < -0.12
        let browRaised = browDelta > 0.035
        let browLowered = browDelta < -0.03

        let surprised = browRaised && mouthOpen
        let angry = browLowered && !mouthOpen && !browRaised
        let sad = liftDelta < -0.006 && !browRaised
        let smile = liftDelta > 0.006 && !mouthOpen

        let expression: FacialExpression
        if surprised {
            expression = .surprised
        } else if angry {
            expression = .angry
        } else if sad {
            expression = .sad
        } else if smile {
            expression = .smile
        } else if eyesClosed {
            expression = .blink
        } else {
            expression = .none
        }

        recentWindow.append(expression)
        if recentWindow.count > windowSize {
            recentWindow.removeFirst(recentWindow.count - windowSize)
        }

        var voteCounts: [FacialExpression: Int] = [:]
        for vote in recentWindow { voteCounts[vote, default: 0] += 1 }
        // Among non-"none" expressions that reach the required vote count,
        // pick the most frequent one — a real expression should dominate
        // its own window even with a little frame-to-frame noise; "none"
        // only wins when nothing else clears the bar.
        let winner = voteCounts
            .filter { $0.key != .none && $0.value >= requiredVotes }
            .max { $0.value < $1.value }?.key
        let displayed = winner ?? .none

        // Freeze the baseline on the *displayed* (post-vote) result, not the
        // raw instant one: an earlier version froze on the raw per-frame
        // value, so an occasional weak/neutral-reading frame in the middle
        // of a genuinely held expression let the baseline creep toward it
        // and, over several such dips, gradually cancel out the real
        // signal — the expression would eventually stop registering even
        // though the face never actually changed.
        if displayed == .none {
            baseline = ExpressionScores(
                mouthCornerLift: base.mouthCornerLift + liftDelta * adaptRate,
                mouthOpenAmount: base.mouthOpenAmount + openDelta * adaptRate,
                eyeOpenRatio: base.eyeOpenRatio + eyeDelta * adaptRate,
                browRaise: base.browRaise + browDelta * adaptRate
            )
        }

        return displayed
    }
}
