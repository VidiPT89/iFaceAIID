import CoreGraphics
import Vision

/// Maps a Vision hand-pose observation to the platform-agnostic `HandLandmarks`
/// model, shared by the macOS and iOS capture services so the mapping table
/// (and the 0.3 confidence threshold) only exists once.
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
            if let point = try? observation.recognizedPoint(visionJoint), point.confidence > 0.3 {
                points[joint] = HandPoint(x: point.location.x, y: point.location.y, confidence: CGFloat(point.confidence))
            }
        }
        return HandLandmarks(points: points)
    }
}
