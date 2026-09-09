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

        let mouthCornerLeft = outerLips[0]
        let mouthCornerRight = outerLips[outerLips.count / 2]
        // Excludes the corners themselves from the baseline, otherwise a
        // smile's own corner movement drags the average toward it and mutes
        // the signal we're trying to detect against.
        let midlinePoints = outerLips.enumerated().filter { $0.offset != 0 && $0.offset != outerLips.count / 2 }.map(\.element)
        let mouthMidY = midlinePoints.map(\.y).reduce(0, +) / CGFloat(max(midlinePoints.count, 1))
        let cornerAvgY = (mouthCornerLeft.y + mouthCornerRight.y) / 2

        let innerLipsHeight = (landmarks.innerLips?.normalizedPoints).map(height) ?? 0

        let eyeHeight = (height(leftEye) + height(rightEye)) / 2
        let eyeWidth = (width(leftEye) + width(rightEye)) / 2
        let eyeOpenRatio = eyeWidth > 0 ? eyeHeight / eyeWidth : 1

        let browEyeGapLeft = averageY(leftEyebrow) - averageY(leftEye)
        let browEyeGapRight = averageY(rightEyebrow) - averageY(rightEye)
        let browRaise = (browEyeGapLeft + browEyeGapRight) / 2

        return ExpressionScores(
            mouthCornerLift: cornerAvgY - mouthMidY,
            mouthOpenAmount: innerLipsHeight,
            eyeOpenRatio: eyeOpenRatio,
            browRaise: browRaise
        )
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
