import SwiftUI

/// Draws a small filled circle at each normalized point — used to mark every
/// tracked landmark (hand joints, face mesh points), not just the
/// connecting lines between them.
public struct LandmarkPointsShape: Shape {
    public let points: [CGPoint]
    public let radius: CGFloat

    public init(points: [CGPoint], radius: CGFloat = 3) {
        self.points = points
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        for point in points {
            let center = CGPoint(x: point.x * rect.width, y: (1 - point.y) * rect.height)
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}
