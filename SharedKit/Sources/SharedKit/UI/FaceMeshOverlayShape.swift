import SwiftUI
@preconcurrency import Vision

/// Draws every tracked face region (contour, eyes, eyebrows, nose, lips,
/// pupils) as connected polylines, so the whole set of detected points is
/// visible — not just a rough face outline.
public struct FaceMeshOverlayShape: Shape {
    public let landmarks: VNFaceLandmarks2D

    public init(landmarks: VNFaceLandmarks2D) {
        self.landmarks = landmarks
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

        func addPolyline(_ points: [CGPoint], closed: Bool) {
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x * rect.width, y: (1 - first.y) * rect.height))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * rect.width, y: (1 - point.y) * rect.height))
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

    /// Every point across all regions, for drawing landmark dots alongside
    /// the connecting lines (mirrors `HandLandmarks.allLocations`).
    public var allPoints: [CGPoint] {
        (openRegions + closedRegions + [landmarks.leftPupil, landmarks.rightPupil])
            .compactMap { $0?.normalizedPoints }
            .flatMap { $0 }
    }
}
