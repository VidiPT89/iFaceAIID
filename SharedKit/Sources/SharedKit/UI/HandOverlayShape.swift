import SwiftUI

/// Draws the skeleton of a detected hand over the camera preview.
public struct HandOverlayShape: Shape {
    public let hand: HandLandmarks
    /// The pixel dimensions of the actual camera frame the landmarks were
    /// computed from — required to correctly map normalized points onto a
    /// view showing that video with `.resizeAspectFill` gravity. See
    /// `GeometryHelpers.mapNormalizedPoint`.
    public let videoSize: CGSize

    private static let connections: [(HandLandmarks.Joint, HandLandmarks.Joint)] = [
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
    ]

    public init(hand: HandLandmarks, videoSize: CGSize) {
        self.hand = hand
        self.videoSize = videoSize
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let viewSize = rect.size
        for (a, b) in Self.connections {
            guard let pa = hand.point(a), let pb = hand.point(b) else { continue }
            let start = GeometryHelpers.mapNormalizedPoint(pa.location, videoSize: videoSize, viewSize: viewSize)
            let end = GeometryHelpers.mapNormalizedPoint(pb.location, videoSize: videoSize, viewSize: viewSize)
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }
}
