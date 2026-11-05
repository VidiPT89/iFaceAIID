import CoreGraphics

/// Raw numbers behind the thumb/pinch-dependent gestures, exposed for a
/// debug overlay — the same "show real numbers instead of guessing again"
/// approach already used for facial expression scores.
public struct HandDebugInfo: Sendable {
    public let thumbAngle: CGFloat
    public let thumbExtended: Bool
    public let pinch: CGFloat
}

/// Classifies a `HandLandmarks` snapshot into one of the supported gestures.
///
/// Finger "extended" state is determined by the angle at the PIP joint
/// between (MCP→PIP) and (PIP→TIP) — close to 180° means the finger is
/// roughly straight. This is robust to the hand being rotated or tilted
/// toward the camera, unlike a pure tip-distance-from-wrist check (the
/// original approach here), which only works reliably when the hand is held
/// upright and flat to the camera — a real source of missed detections.
public enum HandGestureClassifier {
    /// The thumb's own joint doesn't straighten as close to 180° as the
    /// other fingers' do even when held straight out, so it gets a looser bar.
    private static let thumbExtendAngle: CGFloat = 120
    private static let fingerExtendAngle: CGFloat = 140
    /// Folded fingers measured 27-65° on MediaPipe's fist and pointing test
    /// photos; relaxed, half-open ones 125-150°. Shapes that need a finger
    /// folded require it below this, so a relaxed hand doesn't read as a
    /// letter.
    private static let fingerCurledAngle: CGFloat = 120
    /// "L" needs the thumb clearly straight: a natural pointing hand holds
    /// it at ~136-140°, open-palm thumbs measured 169-177°.
    private static let thumbStraightAngle: CGFloat = 150
    /// Index/middle fingertip gap (relative to hand size) below which a V
    /// reads as the fingers held together ("U").
    private static let fingersTogetherGap: CGFloat = 0.25

    public static func debugInfo(_ hand: HandLandmarks) -> HandDebugInfo? {
        guard let thumbTip = hand.point(.thumbTip)?.location,
              let thumbIp = hand.point(.thumbIP)?.location,
              let thumbCmc = hand.point(.thumbCMC)?.location,
              let indexTip = hand.point(.indexTip)?.location,
              let wrist = hand.point(.wrist)?.location,
              let middleMcp = hand.point(.middleMCP)?.location else { return nil }
        let angle = GeometryHelpers.angleAtVertex(thumbCmc, vertex: thumbIp, thumbTip)
        let handScale = GeometryHelpers.distance(wrist, middleMcp)
        let pinch = handScale > 0 ? GeometryHelpers.distance(thumbTip, indexTip) / handScale : 1
        return HandDebugInfo(thumbAngle: angle, thumbExtended: angle > thumbExtendAngle, pinch: pinch)
    }

    public static func classify(_ hand: HandLandmarks) -> DetectedGesture {
        let fingers: [(tip: HandLandmarks.Joint, pip: HandLandmarks.Joint, mcp: HandLandmarks.Joint)] = [
            (.thumbTip, .thumbIP, .thumbCMC),
            (.indexTip, .indexPIP, .indexMCP),
            (.middleTip, .middlePIP, .middleMCP),
            (.ringTip, .ringPIP, .ringMCP),
            (.littleTip, .littlePIP, .littleMCP),
        ]
        // nil when Vision didn't track one of the finger's joints: such a
        // finger is neither extended nor folded.
        let angles: [CGFloat?] = fingers.map { finger in
            guard let tip = hand.point(finger.tip)?.location,
                  let pip = hand.point(finger.pip)?.location,
                  let mcp = hand.point(finger.mcp)?.location else { return nil }
            return GeometryHelpers.angleAtVertex(mcp, vertex: pip, tip)
        }
        let thumbAngle = angles[0] ?? 0
        let thumbExtended = thumbAngle > thumbExtendAngle
        let extended = angles.map { ($0 ?? 0) > fingerExtendAngle }
        let curled = angles.map { $0.map { $0 < fingerCurledAngle } ?? false }
        let (indexExtended, middleExtended, ringExtended, pinkyExtended) = (extended[1], extended[2], extended[3], extended[4])
        let (indexCurled, middleCurled, ringCurled, pinkyCurled) = (curled[1], curled[2], curled[3], curled[4])
        let nonThumbExtendedCount = extended[1...].filter { $0 }.count
        let nonThumbCurledCount = curled[1...].filter { $0 }.count
        let othersCurled = middleCurled && ringCurled && pinkyCurled

        // Hand scale (wrist to middle-MCP) so the distances below stay
        // correct regardless of how close the hand is to the camera.
        let handScale: CGFloat = {
            guard let wrist = hand.point(.wrist)?.location,
                  let middleMcp = hand.point(.middleMCP)?.location else { return 0 }
            return GeometryHelpers.distance(wrist, middleMcp)
        }()
        func relative(_ a: HandLandmarks.Joint, _ b: HandLandmarks.Joint) -> CGFloat? {
            guard handScale > 0, let pa = hand.point(a)?.location, let pb = hand.point(b)?.location else { return nil }
            return GeometryHelpers.distance(pa, pb) / handScale
        }

        // ASL/LGP "O": thumb and index tips pinched into a circle, the
        // others folded. A fist also rests the thumb near the index tip
        // (0.19 on MediaPipe's fist photo), but that index lies folded flat
        // (tip 0.32 from its knuckle); an "O" index arcs out in front.
        if let pinch = relative(.thumbTip, .indexTip), pinch < 0.22,
           let arc = relative(.indexTip, .indexMCP), arc > 0.45,
           indexCurled, othersCurled {
            return .letterO
        }

        // ASL/LGP "F" (also the 👌 "OK" sign): pinched like "O", the other
        // three straight out.
        if let pinch = relative(.thumbTip, .indexTip), pinch < 0.22,
           middleExtended, ringExtended, pinkyExtended {
            return .letterF
        }

        // ASL/LGP "D": index up, thumb tip pressed against the middle
        // fingertip. A plain pointing hand rests the thumb on the folded
        // middle finger too (0.20-0.35 on MediaPipe's pointing photos), so
        // only actual tip contact counts.
        if let pinch = relative(.thumbTip, .middleTip), pinch < 0.15, indexExtended, othersCurled {
            return .letterD
        }

        if thumbAngle > thumbStraightAngle, indexExtended, othersCurled {
            return .letterL
        }

        if pinkyExtended, !thumbExtended, indexCurled, middleCurled, ringCurled {
            return .letterI
        }

        if thumbExtended, nonThumbCurledCount == 4,
           let thumbTip = hand.point(.thumbTip)?.location,
           let thumbMcp = hand.point(.thumbCMC)?.location {
            // Vision's coordinate space is bottom-left origin, so "up" means a larger y.
            if thumbTip.y > thumbMcp.y + 0.02 { return .thumbsUp }
            if thumbTip.y < thumbMcp.y - 0.02 { return .thumbsDown }
            // ASL/LGP "A": the same fist-with-thumb-out shape held sideways.
            return .letterA
        }

        // Shaka / ASL-LGP "Y": thumb and pinky out, the middle three folded.
        if thumbExtended, pinkyExtended, indexCurled, middleCurled, ringCurled {
            return .shaka
        }

        if thumbExtended, indexExtended, pinkyExtended, middleCurled, ringCurled {
            return .iLoveYou
        }

        // "Rock on" / horns: index and pinky out with the thumb tucked.
        if !thumbExtended, indexExtended, pinkyExtended, middleCurled, ringCurled {
            return .rockOn
        }

        // Index and middle only: crossed (🤞, ASL "R"), held together (ASL
        // "U") or spread (peace sign / V). Compared along the knuckle line
        // so it works whichever way the hand is turned.
        if indexExtended, middleExtended, ringCurled, pinkyCurled {
            if let shape = twoFingerShape(hand, handScale: handScale) { return shape }
            return .peaceSign
        }

        if indexExtended, middleExtended, ringExtended, pinkyCurled {
            return .threeFingers
        }

        if indexExtended, othersCurled {
            return .pointing
        }

        // ASL "B" / number 4: four fingers up, thumb folded across the palm.
        if nonThumbExtendedCount == 4, !thumbExtended {
            return .letterB
        }

        // Tolerate one misdetected finger (commonly the pinky, which is
        // easiest to lose track of at an angle).
        if nonThumbExtendedCount >= 3 {
            return .openPalm
        }

        // A fist: at least three fingers clearly folded and the thumb in.
        if nonThumbCurledCount >= 3, nonThumbExtendedCount == 0, !thumbExtended {
            return .closedFist
        }

        return .none
    }

    private static func twoFingerShape(_ hand: HandLandmarks, handScale: CGFloat) -> DetectedGesture? {
        guard handScale > 0,
              let from = hand.point(.indexMCP)?.location,
              let to = hand.point(.littleMCP)?.location,
              let indexTip = hand.point(.indexTip)?.location,
              let middleTip = hand.point(.middleTip)?.location,
              let middleKnuckle = hand.point(.middleMCP)?.location else { return nil }
        let axis = CGPoint(x: to.x - from.x, y: to.y - from.y)
        let length = max(hypot(axis.x, axis.y), 0.0001)
        func across(_ p: CGPoint) -> CGFloat { ((p.x - from.x) * axis.x + (p.y - from.y) * axis.y) / length }
        let gap = across(middleTip) - across(indexTip)
        // At the knuckles the middle finger sits on the pinky side of the
        // index; when the tips swap sides, the fingers are crossed.
        if (gap < 0) != (across(middleKnuckle) < 0), abs(gap) / handScale > 0.05 {
            return .fingersCrossed
        }
        return abs(gap) / handScale < fingersTogetherGap ? .letterU : nil
    }
}
