import CoreGraphics

/// A single tracked point of a hand, in normalized image coordinates (0...1).
public struct HandPoint: Sendable {
    public let x: CGFloat
    public let y: CGFloat
    public let confidence: CGFloat

    public init(x: CGFloat, y: CGFloat, confidence: CGFloat) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }

    public var location: CGPoint { CGPoint(x: x, y: y) }
}

/// The joints of one hand, keyed by a platform-agnostic name so both
/// Vision (macOS/iOS) and any future backend can populate the same model.
public struct HandLandmarks: Sendable {
    public enum Joint: String, CaseIterable, Sendable {
        case wrist
        case thumbCMC, thumbMP, thumbIP, thumbTip
        case indexMCP, indexPIP, indexDIP, indexTip
        case middleMCP, middlePIP, middleDIP, middleTip
        case ringMCP, ringPIP, ringDIP, ringTip
        case littleMCP, littlePIP, littleDIP, littleTip
    }

    public var points: [Joint: HandPoint]

    public init(points: [Joint: HandPoint]) {
        self.points = points
    }

    public func point(_ joint: Joint) -> HandPoint? { points[joint] }
}
