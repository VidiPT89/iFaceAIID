import CoreGraphics
import Vision

/// Maps a Vision hand-pose observation to the platform-agnostic `HandLandmarks`
/// model.
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
        var recognized: [VNHumanHandPoseObservation.JointName: (location: CGPoint, confidence: Float)] = [:]
        for (_, visionJoint) in jointMapping {
            if let point = try? observation.recognizedPoint(visionJoint) {
                recognized[visionJoint] = (point.location, point.confidence)
            }
        }
        return landmarks(from: recognized)
    }

    /// The mapping itself, separate from `VNHumanHandPoseObservation` (which
    /// can't be constructed outside Vision) so recorded points can be
    /// replayed in tests.
    static func landmarks(
        from recognized: [VNHumanHandPoseObservation.JointName: (location: CGPoint, confidence: Float)]
    ) -> HandLandmarks {
        var points: [HandLandmarks.Joint: HandPoint] = [:]
        for (joint, visionJoint) in jointMapping {
            // 0.2 rather than Vision's own higher internal bar: a slightly
            // lower joint-confidence cutoff means fewer fingers silently
            // drop out of the gesture classifier at typical webcam distance
            // and lighting, at the cost of very occasionally keeping a noisy
            // point — an acceptable trade for gesture classification.
            if let point = recognized[visionJoint], point.confidence > 0.2 {
                points[joint] = HandPoint(x: point.location.x, y: point.location.y, confidence: CGFloat(point.confidence))
            }
        }
        return HandLandmarks(points: points)
    }

    /// Vision's `chirality` is computed relative to the image as described
    /// by the `orientation` passed to `VNImageRequestHandler` — since
    /// `CaptureService` passes an orientation that already accounts for each
    /// platform's front-camera mirroring convention (`.leftMirrored` on a
    /// portrait-locked iPhone; a plain, un-mirrored `.up` on a Mac whose
    /// camera doesn't physically mirror), this maps directly with no swap.
    public static func handedness(from observation: VNHumanHandPoseObservation) -> Handedness {
        switch observation.chirality {
        case .left: return .left
        case .right: return .right
        default: return .unknown
        }
    }
}
