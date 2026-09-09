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

    /// Maps a Vision-normalized point (0...1, origin bottom-left) into the
    /// coordinates of a SwiftUI view of `viewSize` showing a video of
    /// `videoSize` with `.resizeAspectFill` gravity (the same gravity
    /// `AVCaptureVideoPreviewLayer` is configured with here) — i.e. the video
    /// is uniformly scaled up until it fully covers the view, then centered,
    /// cropping whatever overflows on one axis.
    ///
    /// Landmark overlays must replicate this exact transform, or their
    /// points drift away from the visible video whenever the camera's native
    /// aspect ratio doesn't match the view's aspect ratio (the previous,
    /// naive `point.x * viewSize.width` mapping assumed a 1:1 stretch, which
    /// only happens to be correct when both aspect ratios match by chance).
    public static func mapNormalizedPoint(_ point: CGPoint, videoSize: CGSize, viewSize: CGSize) -> CGPoint {
        guard videoSize.width > 0, videoSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return CGPoint(x: point.x * viewSize.width, y: (1 - point.y) * viewSize.height)
        }

        let scale = max(viewSize.width / videoSize.width, viewSize.height / videoSize.height)
        let scaledWidth = videoSize.width * scale
        let scaledHeight = videoSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Vision's normalized space has its origin at the bottom-left; flip
        // to top-left before scaling into view space.
        let videoX = point.x * videoSize.width
        let videoY = (1 - point.y) * videoSize.height

        return CGPoint(x: videoX * scale + offsetX, y: videoY * scale + offsetY)
    }
}
