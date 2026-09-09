import CoreGraphics

/// Classifies a `HandLandmarks` snapshot into one of the supported gestures.
///
/// Finger "extended" state is determined by the angle at the PIP joint
/// between (MCP→PIP) and (PIP→TIP) — close to 180° means the finger is
/// roughly straight. This is robust to the hand being rotated or tilted
/// toward the camera, unlike a pure tip-distance-from-wrist check (the
/// original approach here), which only works reliably when the hand is held
/// upright and flat to the camera — a real source of missed detections.
public enum HandGestureClassifier {
    public static func classify(_ hand: HandLandmarks) -> DetectedGesture {
        let fingers: [(tip: HandLandmarks.Joint, pip: HandLandmarks.Joint, mcp: HandLandmarks.Joint)] = [
            (.thumbTip, .thumbIP, .thumbCMC),
            (.indexTip, .indexPIP, .indexMCP),
            (.middleTip, .middlePIP, .middleMCP),
            (.ringTip, .ringPIP, .ringMCP),
            (.littleTip, .littlePIP, .littleMCP),
        ]

        let extended: [Bool] = fingers.map { finger in
            guard let tip = hand.point(finger.tip)?.location,
                  let pip = hand.point(finger.pip)?.location,
                  let mcp = hand.point(finger.mcp)?.location else { return false }
            let angle = GeometryHelpers.angleAtVertex(mcp, vertex: pip, tip)
            return angle > 140
        }

        let thumbExtended = extended[0]
        let indexExtended = extended[1]
        let middleExtended = extended[2]
        let ringExtended = extended[3]
        let pinkyExtended = extended[4]
        let nonThumbExtendedCount = extended[1...].filter { $0 }.count

        if thumbExtended, nonThumbExtendedCount == 0,
           let thumbTip = hand.point(.thumbTip)?.location,
           let thumbMcp = hand.point(.thumbCMC)?.location,
           thumbTip.y > thumbMcp.y + 0.02 {
            // Vision's coordinate space is bottom-left origin, so "up" means a larger y.
            return .thumbsUp
        }

        if indexExtended, middleExtended, !ringExtended, !pinkyExtended {
            return .peaceSign
        }

        if indexExtended, !middleExtended, !ringExtended, !pinkyExtended {
            return .pointing
        }

        // Tolerate one misdetected finger (commonly the pinky, which is
        // easiest to lose track of at an angle) instead of requiring a
        // perfect 4-of-4 or 0-of-4 match.
        if nonThumbExtendedCount >= 3 {
            return .openPalm
        }

        if nonThumbExtendedCount <= 1, !thumbExtended {
            return .closedFist
        }

        return .none
    }
}
