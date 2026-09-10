import CoreGraphics
import Vision

/// Raw geometric measurements behind the expression heuristic, exposed so a
/// debug overlay can show the live numbers — much faster to recalibrate
/// against real user feedback than guessing at thresholds blind again.
public struct ExpressionScores: Sendable {
    public let mouthCornerLift: CGFloat
    public let mouthOpenAmount: CGFloat
    public let eyeOpenRatio: CGFloat
    public let browRaise: CGFloat
}

/// Classifies a Vision `VNFaceLandmarks2D` snapshot into one of the Phase-2
/// facial expressions, using simple geometric heuristics on the landmark
/// regions (no ML model beyond Vision's own face-landmark detector).
public enum FacialExpressionClassifier {
    public static func scores(_ landmarks: VNFaceLandmarks2D) -> ExpressionScores? {
        guard let outerLips = landmarks.outerLips?.normalizedPoints, outerLips.count > 4,
              let leftEyebrow = landmarks.leftEyebrow?.normalizedPoints,
              let rightEyebrow = landmarks.rightEyebrow?.normalizedPoints,
              let leftEye = landmarks.leftEye?.normalizedPoints, leftEye.count > 2,
              let rightEye = landmarks.rightEye?.normalizedPoints, rightEye.count > 2
        else { return nil }

        let innerLipsHeight = (landmarks.innerLips?.normalizedPoints).map(height) ?? 0

        let eyeHeight = (height(leftEye) + height(rightEye)) / 2
        let eyeWidth = (width(leftEye) + width(rightEye)) / 2
        let eyeOpenRatio = eyeWidth > 0 ? eyeHeight / eyeWidth : 1

        let browEyeGapLeft = averageY(leftEyebrow) - averageY(leftEye)
        let browEyeGapRight = averageY(rightEyebrow) - averageY(rightEye)
        let browRaise = (browEyeGapLeft + browEyeGapRight) / 2

        guard let mouthCornerLift = mouthCornerLift(outerLips) else { return nil }

        return ExpressionScores(
            mouthCornerLift: mouthCornerLift,
            mouthOpenAmount: innerLipsHeight,
            eyeOpenRatio: eyeOpenRatio,
            browRaise: browRaise
        )
    }

    /// How far the mouth corners sit above (positive) or below (negative)
    /// the rest of the outer lip contour — the core smile/sad signal.
    /// Pulled out as a pure function of plain points (rather than inline
    /// inside `scores`) so it can be unit tested directly without needing
    /// to construct a real `VNFaceLandmarks2D`, which has no public
    /// initializer.
    static func mouthCornerLift(_ outerLips: [CGPoint]) -> CGFloat? {
        guard outerLips.count > 2 else { return nil }

        // The actual mouth corners are the leftmost/rightmost points in the
        // region, found by x-coordinate — NOT a fixed index like
        // outerLips[0]/outerLips[count/2]. Assuming a fixed index position
        // was a real bug: Vision's `outerLips` point ordering doesn't
        // guarantee the corners land there, so the "corners" being measured
        // were sometimes two points near the top or bottom lip instead —
        // this made mouthCornerLift barely respond to an actual smile at
        // all, however clearly the mouth corners moved, because the wrong
        // points were being measured the whole time.
        let sortedByX = outerLips.indices.sorted { outerLips[$0].x < outerLips[$1].x }
        guard let leftIdx = sortedByX.first, let rightIdx = sortedByX.last, leftIdx != rightIdx else { return nil }
        let cornerAvgY = (outerLips[leftIdx].y + outerLips[rightIdx].y) / 2

        // Excludes the corners themselves from the baseline, otherwise a
        // smile's own corner movement drags the average toward it and mutes
        // the signal we're trying to detect against.
        let midlinePoints = outerLips.enumerated().filter { $0.offset != leftIdx && $0.offset != rightIdx }.map(\.element)
        let mouthMidY = midlinePoints.map(\.y).reduce(0, +) / CGFloat(max(midlinePoints.count, 1))

        return cornerAvgY - mouthMidY
    }

    private static func height(_ points: [CGPoint]) -> CGFloat {
        guard let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return 0 }
        return maxY - minY
    }

    private static func width(_ points: [CGPoint]) -> CGFloat {
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max() else { return 0 }
        return maxX - minX
    }

    private static func averageY(_ points: [CGPoint]) -> CGFloat {
        points.map(\.y).reduce(0, +) / CGFloat(max(points.count, 1))
    }
}
