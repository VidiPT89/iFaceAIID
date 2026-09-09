import CoreGraphics
import Vision

/// Classifies a Vision `VNFaceLandmarks2D` snapshot into one of the Phase-2
/// facial expressions, using simple geometric heuristics on the landmark
/// regions (no ML model beyond Vision's own face-landmark detector).
public enum FacialExpressionClassifier {
    public static func classify(_ landmarks: VNFaceLandmarks2D) -> FacialExpression {
        guard let outerLips = landmarks.outerLips?.normalizedPoints, outerLips.count > 4,
              let leftEyebrow = landmarks.leftEyebrow?.normalizedPoints,
              let rightEyebrow = landmarks.rightEyebrow?.normalizedPoints,
              let leftEye = landmarks.leftEye?.normalizedPoints, leftEye.count > 2,
              let rightEye = landmarks.rightEye?.normalizedPoints, rightEye.count > 2
        else { return .none }

        let mouthCornerLeft = outerLips[0]
        let mouthCornerRight = outerLips[outerLips.count / 2]
        // Excludes the corners themselves from the baseline, otherwise a
        // smile's own corner movement drags the average toward it and mutes
        // the signal we're trying to detect against.
        let midlinePoints = outerLips.enumerated().filter { $0.offset != 0 && $0.offset != outerLips.count / 2 }.map(\.element)
        let mouthMidY = midlinePoints.map(\.y).reduce(0, +) / CGFloat(max(midlinePoints.count, 1))
        let cornerAvgY = (mouthCornerLeft.y + mouthCornerRight.y) / 2

        let innerLipsHeight = (landmarks.innerLips?.normalizedPoints).map(height) ?? 0
        let mouthOpen = innerLipsHeight > 0.04

        let eyeHeight = (height(leftEye) + height(rightEye)) / 2
        let eyeWidth = (width(leftEye) + width(rightEye)) / 2
        let eyesClosed = eyeWidth > 0 && (eyeHeight / eyeWidth) < 0.18

        let browEyeGapLeft = averageY(leftEyebrow) - averageY(leftEye)
        let browEyeGapRight = averageY(rightEyebrow) - averageY(rightEye)
        let browRaised = (browEyeGapLeft + browEyeGapRight) / 2 > 0.06
        let browLowered = (browEyeGapLeft + browEyeGapRight) / 2 < 0.05

        // These geometric margins are deliberately loose: they're a heuristic
        // approximation (no ML expression model on macOS/iOS), and requiring
        // a large corner movement made most natural expressions register as
        // "none" — a looser threshold trades a little precision for actually
        // detecting anything at typical webcam quality.
        let smile = cornerAvgY > mouthMidY + 0.006 && !mouthOpen
        let sad = cornerAvgY < mouthMidY - 0.004 && !browRaised
        let surprised = browRaised && mouthOpen
        let angry = browLowered && !mouthOpen

        if surprised { return .surprised }
        if angry { return .angry }
        if sad { return .sad }
        if smile { return .smile }
        if eyesClosed { return .blink }
        return .none
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
