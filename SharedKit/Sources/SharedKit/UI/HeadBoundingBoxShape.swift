import SwiftUI
import CoreGraphics

/// Draws the whole detected head/face region as a rectangle, from
/// `VNFaceObservation.boundingBox`. Vision's landmark regions (eyes,
/// eyebrows, nose, lips, jaw contour) never include the forehead or
/// hairline — Vision simply doesn't expose points up there — so a mesh
/// alone under-represents how much of the head is actually detected. This
/// rectangle closes that gap by showing the full detected head area
/// (forehead down to chin), independent of which fine-grained landmarks
/// Vision happens to expose.
public struct HeadBoundingBoxShape: Shape {
    public let boundingBox: CGRect
    public let videoSize: CGSize

    public init(boundingBox: CGRect, videoSize: CGSize) {
        self.boundingBox = boundingBox
        self.videoSize = videoSize
    }

    public func path(in rect: CGRect) -> Path {
        let viewSize = rect.size
        let corners = [
            CGPoint(x: boundingBox.minX, y: boundingBox.minY),
            CGPoint(x: boundingBox.maxX, y: boundingBox.minY),
            CGPoint(x: boundingBox.maxX, y: boundingBox.maxY),
            CGPoint(x: boundingBox.minX, y: boundingBox.maxY),
        ].map { GeometryHelpers.mapNormalizedPoint($0, videoSize: videoSize, viewSize: viewSize) }

        var path = Path()
        guard let first = corners.first else { return path }
        path.move(to: first)
        for point in corners.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
