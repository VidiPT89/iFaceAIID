import CoreGraphics
import Vision

/// Maps a Vision hand-pose observation to the platform-agnostic `HandLandmarks`
/// model, shared by the macOS and iOS capture services so the mapping table
/// (and the confidence threshold) only exists once.
public enum VisionHandMapping {
    private static let jointMapping: [(HandLandmarks.Joint, VNHumanHandPoseObservation.JointName)] = [
        (.wrist, .wrist),
        (.thumbCMC, .thumbCMC), (.thumbMP, .thumbMP), (.thumbIP, .thumbIP), (.thumbTip, .thumbTip),
        (.indexMCP, .indexMCP), (.indexPIP, .indexPIP), (.indexDIP, .indexDIP), (.indexTip, .indexTip),
        (.middleMCP, .middleMCP), (.middlePIP, .middlePIP), (.middleDIP, .middleDIP), (.middleTip, .middleTip),
        (.ringMCP, .ringMCP), (.ringPIP, .ringPIP), (.ringDIP, .ringDIP), (.ringTip, .ringTip),
        (.littleMCP, .littleMCP), (.littlePIP, .littlePIP), (.littleDIP, .littleDIP), (.littleTip, .littleTip),
    ]

    public static func landmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks {
        var points: [HandLandmarks.Joint: HandPoint] = [:]
        for (joint, visionJoint) in jointMapping {
            // 0.2 rather than Vision's own higher internal bar: a slightly
            // lower joint-confidence cutoff means fewer fingers silently
            // drop out of the gesture classifier at typical webcam distance
            // and lighting, at the cost of very occasionally keeping a noisy
            // point — an acceptable trade for gesture classification.
            if let point = try? observation.recognizedPoint(visionJoint), point.confidence > 0.2 {
                points[joint] = HandPoint(x: point.location.x, y: point.location.y, confidence: CGFloat(point.confidence))
            }
        }
        return HandLandmarks(points: points)
    }
}
