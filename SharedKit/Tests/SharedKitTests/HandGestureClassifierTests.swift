import XCTest
@testable import SharedKit

/// Vision's coordinate space has its origin at the bottom-left, so "up" on
/// screen means a *larger* y — the opposite of the web app's canvas-style
/// top-left origin. Every direction below is expressed in that convention.
private let up = CGPoint(x: 0, y: 1)
private let down = CGPoint(x: 0, y: -1)
private let side = CGPoint(x: -1, y: 0)

private let wrist = CGPoint(x: 0.5, y: 0.1)
private let mcps: [String: CGPoint] = [
    "thumb": CGPoint(x: 0.35, y: 0.32),
    "index": CGPoint(x: 0.45, y: 0.4),
    "middle": CGPoint(x: 0.5, y: 0.4),
    "ring": CGPoint(x: 0.55, y: 0.4),
    "pinky": CGPoint(x: 0.6, y: 0.38),
]

private func normalize(_ v: CGPoint) -> CGPoint {
    let m = max(hypot(v.x, v.y), 0.0001)
    return CGPoint(x: v.x / m, y: v.y / m)
}

private func addv(_ a: CGPoint, _ dir: CGPoint, _ s: CGFloat) -> CGPoint {
    CGPoint(x: a.x + dir.x * s, y: a.y + dir.y * s)
}

/// A straight line from mcp through pip to tip reads as fully "extended"
/// (180° at pip) regardless of direction.
private func extendedJoints(_ base: CGPoint, _ dir: CGPoint, len: CGFloat = 0.12) -> (pip: CGPoint, tip: CGPoint) {
    let u = normalize(dir)
    return (addv(base, u, len), addv(base, u, len * 2))
}

/// A sharp ~90° bend at pip reads as "curled" (well under both the 140°
/// and the thumb's own 120° extension thresholds) regardless of orientation.
private func curledJoints(_ base: CGPoint, _ dir: CGPoint, len: CGFloat = 0.1) -> (pip: CGPoint, tip: CGPoint) {
    let u = normalize(dir)
    let perp = CGPoint(x: -u.y, y: u.x)
    let pip = addv(base, u, len * 0.4)
    return (pip, addv(pip, perp, len * 0.9))
}

private struct FingerSpec {
    var extended: Bool
    var dir: CGPoint = up
}

private let allCurled: [String: FingerSpec] = [
    "thumb": FingerSpec(extended: false),
    "index": FingerSpec(extended: false),
    "middle": FingerSpec(extended: false),
    "ring": FingerSpec(extended: false),
    "pinky": FingerSpec(extended: false),
]

/// Builds a full hand from a simple per-finger spec, so each test case
/// reads as "which fingers are out and which way" instead of a wall of
/// magic coordinates.
private func buildHand(_ fingers: [String: FingerSpec]) -> HandLandmarks {
    let jointNames: [String: (mcp: HandLandmarks.Joint, pip: HandLandmarks.Joint, tip: HandLandmarks.Joint)] = [
        "thumb": (.thumbCMC, .thumbIP, .thumbTip),
        "index": (.indexMCP, .indexPIP, .indexTip),
        "middle": (.middleMCP, .middlePIP, .middleTip),
        "ring": (.ringMCP, .ringPIP, .ringTip),
        "pinky": (.littleMCP, .littlePIP, .littleTip),
    ]

    var points: [HandLandmarks.Joint: HandPoint] = [
        .wrist: HandPoint(x: wrist.x, y: wrist.y, confidence: 1),
    ]

    for (name, joints) in jointNames {
        let base = mcps[name]!
        let spec = fingers[name] ?? FingerSpec(extended: false)
        let (pip, tip) = spec.extended ? extendedJoints(base, spec.dir) : curledJoints(base, spec.dir)
        points[joints.mcp] = HandPoint(x: base.x, y: base.y, confidence: 1)
        points[joints.pip] = HandPoint(x: pip.x, y: pip.y, confidence: 1)
        points[joints.tip] = HandPoint(x: tip.x, y: tip.y, confidence: 1)
    }

    return HandLandmarks(points: points)
}

final class HandGestureClassifierTests: XCTestCase {
    func testOpenPalm() {
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: CGPoint(x: -1, y: 0.3))
        fingers["index"] = FingerSpec(extended: true)
        fingers["middle"] = FingerSpec(extended: true)
        fingers["ring"] = FingerSpec(extended: true)
        fingers["pinky"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .openPalm)
    }

    func testClosedFist() {
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(allCurled)), .closedFist)
    }

    func testThumbsUp() {
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: up)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .thumbsUp)
    }

    func testThumbsDown() {
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: down)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .thumbsDown)
    }

    func testLetterI() {
        var fingers = allCurled
        fingers["pinky"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .letterI)
    }

    func testPeaceSign() {
        var fingers = allCurled
        fingers["index"] = FingerSpec(extended: true, dir: CGPoint(x: -0.5, y: 1))
        fingers["middle"] = FingerSpec(extended: true, dir: CGPoint(x: 0.5, y: 1))
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .peaceSign)
    }

    func testLetterUFingersTogether() {
        var fingers = allCurled
        fingers["index"] = FingerSpec(extended: true)
        fingers["middle"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .letterU)
    }

    func testFingersCrossed() {
        var fingers = allCurled
        fingers["index"] = FingerSpec(extended: true, dir: CGPoint(x: 0.6, y: 1))
        fingers["middle"] = FingerSpec(extended: true, dir: CGPoint(x: -0.6, y: 1))
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .fingersCrossed)
    }

    func testLetterBFourFingersThumbFolded() {
        var fingers = allCurled
        for name in ["index", "middle", "ring", "pinky"] { fingers[name] = FingerSpec(extended: true) }
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .letterB)
    }

    func testHalfOpenFingersMatchNothing() {
        // A relaxed hand: thumb and index out, the other three bent ~130°
        // (between extended and folded). This used to read as "L".
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: side)
        fingers["index"] = FingerSpec(extended: true)
        var points = buildHand(fingers).points
        for (mcp, pip, tip) in [(HandLandmarks.Joint.middleMCP, HandLandmarks.Joint.middlePIP, HandLandmarks.Joint.middleTip),
                                (.ringMCP, .ringPIP, .ringTip), (.littleMCP, .littlePIP, .littleTip)] {
            let base = points[mcp]!
            points[pip] = HandPoint(x: base.x, y: base.y + 0.1, confidence: 1)
            points[tip] = HandPoint(x: base.x + 0.06, y: base.y + 0.17, confidence: 1)
        }
        XCTAssertEqual(HandGestureClassifier.classify(HandLandmarks(points: points)), .none)
    }

    func testThreeFingers() {
        var fingers = allCurled
        fingers["index"] = FingerSpec(extended: true)
        fingers["middle"] = FingerSpec(extended: true)
        fingers["ring"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .threeFingers)
    }

    func testPointing() {
        var fingers = allCurled
        fingers["index"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .pointing)
    }

    func testShaka() {
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: side)
        fingers["pinky"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .shaka)
    }

    func testRockOn() {
        var fingers = allCurled
        fingers["index"] = FingerSpec(extended: true)
        fingers["pinky"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .rockOn)
    }

    func testILoveYou() {
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: side)
        fingers["index"] = FingerSpec(extended: true)
        fingers["pinky"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .iLoveYou)
    }

    func testLetterL() {
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: side)
        fingers["index"] = FingerSpec(extended: true)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .letterL)
    }

    func testLetterO() {
        // Hand-placed rather than built from the generic helper: the "O"
        // shape needs the thumb and index tips pinched to the same point,
        // easier to state directly than to derive from curl/extend.
        var points: [HandLandmarks.Joint: HandPoint] = [
            .wrist: HandPoint(x: wrist.x, y: wrist.y, confidence: 1),
            .thumbCMC: HandPoint(x: mcps["thumb"]!.x, y: mcps["thumb"]!.y, confidence: 1),
            // The index arcs up and forward, then back to meet the thumb —
            // its tip ends well away from its own knuckle, unlike a fist's.
            .thumbIP: HandPoint(x: 0.36, y: 0.42, confidence: 1),
            .thumbTip: HandPoint(x: 0.36, y: 0.53, confidence: 1),
            .indexMCP: HandPoint(x: mcps["index"]!.x, y: mcps["index"]!.y, confidence: 1),
            .indexPIP: HandPoint(x: 0.43, y: 0.52, confidence: 1),
            .indexTip: HandPoint(x: 0.37, y: 0.53, confidence: 1),
        ]
        let middle = curledJoints(mcps["middle"]!, up)
        points[.middleMCP] = HandPoint(x: mcps["middle"]!.x, y: mcps["middle"]!.y, confidence: 1)
        points[.middlePIP] = HandPoint(x: middle.pip.x, y: middle.pip.y, confidence: 1)
        points[.middleTip] = HandPoint(x: middle.tip.x, y: middle.tip.y, confidence: 1)
        let ring = curledJoints(mcps["ring"]!, up)
        points[.ringMCP] = HandPoint(x: mcps["ring"]!.x, y: mcps["ring"]!.y, confidence: 1)
        points[.ringPIP] = HandPoint(x: ring.pip.x, y: ring.pip.y, confidence: 1)
        points[.ringTip] = HandPoint(x: ring.tip.x, y: ring.tip.y, confidence: 1)
        let pinky = curledJoints(mcps["pinky"]!, up)
        points[.littleMCP] = HandPoint(x: mcps["pinky"]!.x, y: mcps["pinky"]!.y, confidence: 1)
        points[.littlePIP] = HandPoint(x: pinky.pip.x, y: pinky.pip.y, confidence: 1)
        points[.littleTip] = HandPoint(x: pinky.tip.x, y: pinky.tip.y, confidence: 1)

        XCTAssertEqual(HandGestureClassifier.classify(HandLandmarks(points: points)), .letterO)
    }

    func testLetterF() {
        // Same thumb-index pinch as "O" above, but middle/ring/pinky
        // extended instead of curled — the pinch alone is what separates F
        // from O, so this is built the same hand-placed way as testLetterO.
        var points: [HandLandmarks.Joint: HandPoint] = [
            .wrist: HandPoint(x: wrist.x, y: wrist.y, confidence: 1),
            .thumbCMC: HandPoint(x: mcps["thumb"]!.x, y: mcps["thumb"]!.y, confidence: 1),
            // The index arcs up and forward, then back to meet the thumb —
            // its tip ends well away from its own knuckle, unlike a fist's.
            .thumbIP: HandPoint(x: 0.36, y: 0.42, confidence: 1),
            .thumbTip: HandPoint(x: 0.36, y: 0.53, confidence: 1),
            .indexMCP: HandPoint(x: mcps["index"]!.x, y: mcps["index"]!.y, confidence: 1),
            .indexPIP: HandPoint(x: 0.43, y: 0.52, confidence: 1),
            .indexTip: HandPoint(x: 0.37, y: 0.53, confidence: 1),
        ]
        let middle = extendedJoints(mcps["middle"]!, up)
        points[.middleMCP] = HandPoint(x: mcps["middle"]!.x, y: mcps["middle"]!.y, confidence: 1)
        points[.middlePIP] = HandPoint(x: middle.pip.x, y: middle.pip.y, confidence: 1)
        points[.middleTip] = HandPoint(x: middle.tip.x, y: middle.tip.y, confidence: 1)
        let ring = extendedJoints(mcps["ring"]!, up)
        points[.ringMCP] = HandPoint(x: mcps["ring"]!.x, y: mcps["ring"]!.y, confidence: 1)
        points[.ringPIP] = HandPoint(x: ring.pip.x, y: ring.pip.y, confidence: 1)
        points[.ringTip] = HandPoint(x: ring.tip.x, y: ring.tip.y, confidence: 1)
        let pinky = extendedJoints(mcps["pinky"]!, up)
        points[.littleMCP] = HandPoint(x: mcps["pinky"]!.x, y: mcps["pinky"]!.y, confidence: 1)
        points[.littlePIP] = HandPoint(x: pinky.pip.x, y: pinky.pip.y, confidence: 1)
        points[.littleTip] = HandPoint(x: pinky.tip.x, y: pinky.tip.y, confidence: 1)

        XCTAssertEqual(HandGestureClassifier.classify(HandLandmarks(points: points)), .letterF)
    }

    func testLetterD() {
        // Index extended straight up; thumb curled in to touch the middle
        // fingertip (not the index tip, which would otherwise read as
        // "pointing"); ring and pinky curled down.
        let index = extendedJoints(mcps["index"]!, up)
        var points: [HandLandmarks.Joint: HandPoint] = [
            .wrist: HandPoint(x: wrist.x, y: wrist.y, confidence: 1),
            .indexMCP: HandPoint(x: mcps["index"]!.x, y: mcps["index"]!.y, confidence: 1),
            .indexPIP: HandPoint(x: index.pip.x, y: index.pip.y, confidence: 1),
            .indexTip: HandPoint(x: index.tip.x, y: index.tip.y, confidence: 1),
        ]
        let middle = curledJoints(mcps["middle"]!, up)
        points[.middleMCP] = HandPoint(x: mcps["middle"]!.x, y: mcps["middle"]!.y, confidence: 1)
        points[.middlePIP] = HandPoint(x: middle.pip.x, y: middle.pip.y, confidence: 1)
        points[.middleTip] = HandPoint(x: middle.tip.x, y: middle.tip.y, confidence: 1)
        // Thumb bent in to touch the middle fingertip directly.
        points[.thumbCMC] = HandPoint(x: mcps["thumb"]!.x, y: mcps["thumb"]!.y, confidence: 1)
        points[.thumbIP] = HandPoint(x: (mcps["thumb"]!.x + middle.tip.x) / 2, y: (mcps["thumb"]!.y + middle.tip.y) / 2, confidence: 1)
        points[.thumbTip] = HandPoint(x: middle.tip.x, y: middle.tip.y, confidence: 1)
        let ring = curledJoints(mcps["ring"]!, up)
        points[.ringMCP] = HandPoint(x: mcps["ring"]!.x, y: mcps["ring"]!.y, confidence: 1)
        points[.ringPIP] = HandPoint(x: ring.pip.x, y: ring.pip.y, confidence: 1)
        points[.ringTip] = HandPoint(x: ring.tip.x, y: ring.tip.y, confidence: 1)
        let pinky = curledJoints(mcps["pinky"]!, up)
        points[.littleMCP] = HandPoint(x: mcps["pinky"]!.x, y: mcps["pinky"]!.y, confidence: 1)
        points[.littlePIP] = HandPoint(x: pinky.pip.x, y: pinky.pip.y, confidence: 1)
        points[.littleTip] = HandPoint(x: pinky.tip.x, y: pinky.tip.y, confidence: 1)

        XCTAssertEqual(HandGestureClassifier.classify(HandLandmarks(points: points)), .letterD)
    }

    func testLetterA() {
        var fingers = allCurled
        fingers["thumb"] = FingerSpec(extended: true, dir: side)
        XCTAssertEqual(HandGestureClassifier.classify(buildHand(fingers)), .letterA)
    }
}
