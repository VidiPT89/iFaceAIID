import CoreGraphics

/// Classifies a `HandLandmarks` snapshot into one of the supported Phase-1 gestures,
/// using the same tip/pip/mcp distance-to-wrist heuristic as the web prototype.
public enum HandGestureClassifier {
    public static func classify(_ hand: HandLandmarks) -> DetectedGesture {
        guard let wrist = hand.point(.wrist)?.location else { return .none }

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
            let tipDistance = GeometryHelpers.distance(tip, wrist)
            let pipDistance = GeometryHelpers.distance(pip, wrist)
            let mcpDistance = GeometryHelpers.distance(mcp, wrist)
            return tipDistance > pipDistance && pipDistance > mcpDistance * 0.9
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

        if nonThumbExtendedCount == 4 {
            return .openPalm
        }

        if indexExtended, middleExtended, !ringExtended, !pinkyExtended {
            return .peaceSign
        }

        if indexExtended, !middleExtended, !ringExtended, !pinkyExtended {
            return .pointing
        }

        if !thumbExtended, nonThumbExtendedCount == 0 {
            return .closedFist
        }

        return .none
    }
}
