import CoreGraphics

public enum GeometryHelpers {
    public static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// The angle (in degrees) at `vertex` between the rays toward `a` and `b`.
    /// A value near 180° means the three points are roughly collinear (a
    /// straight line through vertex); a small value means a sharp bend.
    public static func angleAtVertex(_ a: CGPoint, vertex: CGPoint, _ b: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: a.x - vertex.x, y: a.y - vertex.y)
        let v2 = CGPoint(x: b.x - vertex.x, y: b.y - vertex.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = hypot(v1.x, v1.y)
        let mag2 = hypot(v2.x, v2.y)
        guard mag1 > 0, mag2 > 0 else { return 180 }
        let cosAngle = min(1, max(-1, dot / (mag1 * mag2)))
        return acos(cosAngle) * 180 / .pi
    }
}
