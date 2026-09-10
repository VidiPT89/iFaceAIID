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

    /// Hysteresis on top of the per-frame classification: a single frame's
    /// result only becomes the displayed expression once it has repeated
    /// for `requiredStreak` frames in a row. Without this, a classification
    /// that flips for just one frame (still possible even after smoothing,
    /// right at a threshold boundary) shows up as a visibly wrong badge
    /// before correcting itself a frame later.
    private var displayed: FacialExpression = .none
    private var pending: FacialExpression = .none
    private var pendingStreak = 0
    private let requiredStreak = 3

    public init() {}

    public func reset() {
        baseline = nil
        smoothed = nil
        displayed = .none
        pending = .none
        pendingStreak = 0
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

        // Only drift the baseline on frames that already read as neutral,
        // so holding an expression doesn't slowly erase its own signal.
        if expression == .none {
            baseline = ExpressionScores(
                mouthCornerLift: base.mouthCornerLift + liftDelta * adaptRate,
                mouthOpenAmount: base.mouthOpenAmount + openDelta * adaptRate,
                eyeOpenRatio: base.eyeOpenRatio + eyeDelta * adaptRate,
                browRaise: base.browRaise + browDelta * adaptRate
            )
        }

        if expression == pending {
            pendingStreak += 1
        } else {
            pending = expression
            pendingStreak = 1
        }
        if pendingStreak >= requiredStreak {
            displayed = expression
        }
        return displayed
    }
}
