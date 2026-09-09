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
    /// How fast the baseline drifts toward frames classified as neutral.
    /// Slow enough that a brief expression doesn't get "absorbed" into the
    /// baseline mid-hold, fast enough to track real drift (lighting,
    /// camera angle, person swap) within a couple of seconds at ~30fps.
    private let adaptRate: CGFloat = 0.02

    public init() {}

    public func reset() {
        baseline = nil
    }

    public func classify(_ scores: ExpressionScores) -> FacialExpression {
        guard let base = baseline else {
            // First frame after (re)starting: nothing to compare against
            // yet, so seed the baseline directly rather than guessing.
            baseline = scores
            return .none
        }

        let liftDelta = scores.mouthCornerLift - base.mouthCornerLift
        let openDelta = scores.mouthOpenAmount - base.mouthOpenAmount
        let eyeDelta = scores.eyeOpenRatio - base.eyeOpenRatio
        let browDelta = scores.browRaise - base.browRaise

        let mouthOpen = openDelta > 0.03
        let eyesClosed = eyeDelta < -0.08
        let browRaised = browDelta > 0.02
        let browLowered = browDelta < -0.015

        let surprised = browRaised && mouthOpen
        let angry = browLowered && !mouthOpen
        let sad = liftDelta < -0.0015 && !browRaised
        let smile = liftDelta > 0.0015 && !mouthOpen

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

        return expression
    }
}
