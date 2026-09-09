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

        // ASL/LGP fingerspelling letter "O": thumb and index tips pinched
        // together into a circle, the other three fingers curled. Checked
        // first, before closedFist would otherwise claim this shape. The
        // pinch distance is normalized by wrist-to-middle-MCP distance
        // (hand scale) so it stays correct regardless of hand-to-camera
        // distance.
        if let thumbTip = hand.point(.thumbTip)?.location,
           let indexTip = hand.point(.indexTip)?.location,
           let wrist = hand.point(.wrist)?.location,
           let middleMcp = hand.point(.middleMCP)?.location {
            let handScale = GeometryHelpers.distance(wrist, middleMcp)
            if handScale > 0 {
                let pinch = GeometryHelpers.distance(thumbTip, indexTip) / handScale
                if pinch < 0.25, !indexExtended, !middleExtended, !ringExtended, !pinkyExtended {
                    return .letterO
                }
            }
        }

        // ASL/LGP fingerspelling letter "L": thumb and index extended,
        // other three fingers closed.
        if thumbExtended, indexExtended, !middleExtended, !ringExtended, !pinkyExtended {
            return .letterL
        }

        if thumbExtended, nonThumbExtendedCount == 0,
           let thumbTip = hand.point(.thumbTip)?.location,
           let thumbMcp = hand.point(.thumbCMC)?.location {
            // Vision's coordinate space is bottom-left origin, so "up" means a larger y.
            if thumbTip.y > thumbMcp.y + 0.02 { return .thumbsUp }
            if thumbTip.y < thumbMcp.y - 0.02 { return .thumbsDown }
        }

        // Shaka / ASL-LGP "Y": thumb and pinky extended, the three middle
        // fingers closed.
        if thumbExtended, pinkyExtended, !indexExtended, !middleExtended, !ringExtended {
            return .shaka
        }

        // ASL "I love you": thumb, index and pinky extended, middle and ring closed.
        if thumbExtended, indexExtended, pinkyExtended, !middleExtended, !ringExtended {
            return .iLoveYou
        }

        if indexExtended, middleExtended, !ringExtended, !pinkyExtended {
            return .peaceSign
        }

        // W / number 3: checked before the tolerant "openPalm" fallback
        // below, which would otherwise swallow it (3 non-thumb extended).
        if indexExtended, middleExtended, ringExtended, !pinkyExtended {
            return .threeFingers
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
