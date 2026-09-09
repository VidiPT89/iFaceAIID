import CoreGraphics
import CoreImage
import Foundation
import Vision

/// Approximate, on-device-only face identification using Vision's
/// general-purpose `VNGenerateImageFeaturePrintRequest` on the cropped face
/// region. This is **not** a dedicated face-recognition model (Apple doesn't
/// expose one publicly) — it's a reasonable approximation using only Apple
/// frameworks, no bundled third-party model. Expect it to be less precise
/// than the web app's face-api.js-based identification, especially across
/// very different lighting or angles.
public enum FaceIdentification {
    public static func featurePrint(from pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) throws -> VNFeaturePrintObservation? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        let cropRect = VNImageRectForNormalizedRect(faceBoundingBox, Int(extent.width), Int(extent.height))
        let cropped = ciImage.cropped(to: cropRect)

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(ciImage: cropped, options: [:])
        try handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    public static func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float {
        var distance: Float = .greatestFiniteMagnitude
        try? a.computeDistance(&distance, to: b)
        return distance
    }
}

public struct KnownFacePrint: Codable, Sendable {
    public let name: String
    public let data: Data

    public init(name: String, data: Data) {
        self.name = name
        self.data = data
    }
}

@MainActor
public final class FaceIdentityStore: ObservableObject {
    public static let shared = FaceIdentityStore()

    private static let storageKey = "faceaiid.knownFacePrints"
    /// Distance threshold below which two feature prints are considered the
    /// same person. Vision's feature prints aren't calibrated the same way a
    /// dedicated face embedding is, so this is a looser, empirically chosen
    /// cutoff — tune per use case if false matches/misses are frequent.
    public static let matchThreshold: Float = 18

    @Published public private(set) var knownFaces: [KnownFacePrint] = []

    private init() {
        load()
    }

    public func register(name: String, observation: VNFeaturePrintObservation) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true) else { return }
        knownFaces.append(KnownFacePrint(name: name, data: data))
        save()
    }

    public func remove(name: String) {
        knownFaces.removeAll { $0.name == name }
        save()
    }

    public func match(_ observation: VNFeaturePrintObservation) -> (name: String, distance: Float)? {
        var best: (name: String, distance: Float)?
        for known in knownFaces {
            guard let storedObservation = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self, from: known.data
            ) else { continue }
            let distance = FaceIdentification.distance(observation, storedObservation)
            if best == nil || distance < best!.distance {
                best = (known.name, distance)
            }
        }
        guard let best, best.distance <= Self.matchThreshold else { return nil }
        return best
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([KnownFacePrint].self, from: data) else { return }
        knownFaces = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(knownFaces) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
