import SwiftUI

/// Draws the skeleton of a detected hand over the camera preview.
public struct HandOverlayShape: Shape {
    public let hand: HandLandmarks

    private static let connections: [(HandLandmarks.Joint, HandLandmarks.Joint)] = [
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
    ]

    public init(hand: HandLandmarks) {
        self.hand = hand
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        for (a, b) in Self.connections {
            guard let pa = hand.point(a), let pb = hand.point(b) else { continue }
            let start = CGPoint(x: pa.x * rect.width, y: (1 - pa.y) * rect.height)
            let end = CGPoint(x: pb.x * rect.width, y: (1 - pb.y) * rect.height)
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }
}
