import SwiftUI
@preconcurrency import Vision

/// Draws every tracked face region (contour, eyes, eyebrows, nose, lips,
/// pupils) as connected polylines, so the whole set of detected points is
/// visible — not just a rough face outline.
public struct FaceMeshOverlayShape: Shape {
    public let landmarks: VNFaceLandmarks2D
    /// The face's bounding box (`VNFaceObservation.boundingBox`), normalized
    /// to the *full image* (origin bottom-left). Every point inside
    /// `landmarks` is itself normalized to *this box*, not the full image —
    /// drawing them as if they were full-image-normalized is what produced
    /// a face mesh floating at the wrong scale/position, disconnected from
    /// the actual face.
    public let boundingBox: CGRect
    /// The pixel dimensions of the actual camera frame the landmarks were
    /// computed from — see `GeometryHelpers.mapNormalizedPoint`.
    public let videoSize: CGSize

    public init(landmarks: VNFaceLandmarks2D, boundingBox: CGRect, videoSize: CGSize) {
        self.landmarks = landmarks
        self.boundingBox = boundingBox
        self.videoSize = videoSize
    }

    /// Converts a point normalized to the face bounding box into a point
    /// normalized to the full image, so it can be fed into
    /// `GeometryHelpers.mapNormalizedPoint` alongside every other landmark
    /// type (which are already full-image-normalized).
    private func toImageSpace(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: boundingBox.origin.x + point.x * boundingBox.width,
            y: boundingBox.origin.y + point.y * boundingBox.height
        )
    }

    private var openRegions: [VNFaceLandmarkRegion2D?] {
        [
            landmarks.faceContour,
            landmarks.leftEyebrow,
            landmarks.rightEyebrow,
            landmarks.noseCrest,
            landmarks.medianLine,
        ]
    }

    private var closedRegions: [VNFaceLandmarkRegion2D?] {
        [
            landmarks.leftEye,
            landmarks.rightEye,
            landmarks.outerLips,
            landmarks.innerLips,
            landmarks.nose,
        ]
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let viewSize = rect.size

        func addPolyline(_ points: [CGPoint], closed: Bool) {
            guard let first = points.first else { return }
            path.move(to: GeometryHelpers.mapNormalizedPoint(toImageSpace(first), videoSize: videoSize, viewSize: viewSize))
            for point in points.dropFirst() {
                path.addLine(to: GeometryHelpers.mapNormalizedPoint(toImageSpace(point), videoSize: videoSize, viewSize: viewSize))
            }
            if closed { path.closeSubpath() }
        }

        for region in openRegions {
            if let points = region?.normalizedPoints { addPolyline(points, closed: false) }
        }
        for region in closedRegions {
            if let points = region?.normalizedPoints { addPolyline(points, closed: true) }
        }

        return path
    }

    /// Every point across all regions, already converted to full-image
    /// normalized space, for drawing landmark dots alongside the connecting
    /// lines (mirrors `HandLandmarks.allLocations`).
    public var allPoints: [CGPoint] {
        (openRegions + closedRegions + [landmarks.leftPupil, landmarks.rightPupil])
            .compactMap { $0?.normalizedPoints }
            .flatMap { $0 }
            .map(toImageSpace)
    }
}
