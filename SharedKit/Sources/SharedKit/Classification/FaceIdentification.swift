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
    /// Extra context around Vision's tight face box. Measured on MediaPipe's
    /// public portraits, a 25% margin pushed different people further apart
    /// (1.02-1.09 → 1.10-1.17) while the same person stayed as close or closer.
    static let cropMargin: CGFloat = 0.25

    public static func featurePrint(
        from pixelBuffer: CVPixelBuffer,
        faceBoundingBox: CGRect,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> VNFeaturePrintObservation? {
        // Crop in the same (oriented) space Vision reported the box in.
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let extent = ciImage.extent
        let box = faceBoundingBox
            .insetBy(dx: -faceBoundingBox.width * cropMargin, dy: -faceBoundingBox.height * cropMargin)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let cropRect = VNImageRectForNormalizedRect(box, Int(extent.width), Int(extent.height))
            .offsetBy(dx: extent.minX, dy: extent.minY)
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

/// One stored sample. A person accumulates several of these across repeated
/// "Register face" presses (different angle/lighting each time) rather than
/// a single registration overwriting the rest — matching against the best
/// of several samples per person is meaningfully more robust than a single
/// snapshot, given how sensitive a single Vision feature print is to pose
/// and lighting.
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
    /// Distance below which two feature prints count as the same person.
    ///
    /// The scale depends on the feature-print revision. Revision 2 (macOS
    /// 14 / iOS 17 and later) measured 0.12-0.72 for the same person and
    /// 1.02-1.17 for different people on MediaPipe's public portraits. The
    /// previous single cutoff of 18 was meant for revision 1's much larger
    /// scale and, on revision 2, accepted *every* face as the closest
    /// registered person. Revision 1 keeps that older, unmeasured cutoff.
    static func matchThreshold(for observation: VNFeaturePrintObservation) -> Float {
        observation.requestRevision == 1 ? 18 : 0.85
    }
    /// A name is only given when the next-closest *other* person is at
    /// least this much further away (as a fraction of the threshold).
    static let minMarginToNextPerson: Float = 0.1
    /// Capped so a person re-registering many times doesn't grow the stored
    /// data unboundedly; the oldest sample is dropped once the cap is hit.
    private static let maxSamplesPerPerson = 5

    @Published public private(set) var allPrints: [KnownFacePrint] = [] {
        didSet { decodedPrints = Self.decode(allPrints) }
    }
    /// `allPrints` unarchived once per change instead of on every identity
    /// check (which runs several times per second while the camera is on).
    private var decodedPrints: [(name: String, observation: VNFeaturePrintObservation)] = []
    /// One row per distinct registered person, for UI lists — collapses the
    /// (possibly several) samples behind each name into one entry.
    public var knownFaces: [String] {
        var seen = Set<String>()
        return allPrints.map(\.name).filter { seen.insert($0).inserted }
    }

    private init() {
        load()
        // Property observers don't fire reliably for sets made during init.
        decodedPrints = Self.decode(allPrints)
    }

    public func register(name: String, observation: VNFeaturePrintObservation) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true) else { return }
        var samplesForName = allPrints.filter { $0.name == name }
        samplesForName.append(KnownFacePrint(name: name, data: data))
        if samplesForName.count > Self.maxSamplesPerPerson {
            samplesForName.removeFirst(samplesForName.count - Self.maxSamplesPerPerson)
        }
        allPrints.removeAll { $0.name == name }
        allPrints.append(contentsOf: samplesForName)
        save()
    }

    public func remove(name: String) {
        allPrints.removeAll { $0.name == name }
        save()
    }

    public func sampleCount(for name: String) -> Int {
        allPrints.filter { $0.name == name }.count
    }

    public static var maxSamples: Int { maxSamplesPerPerson }

    public func match(_ observation: VNFeaturePrintObservation) -> (name: String, distance: Float)? {
        // Closest sample per person, then compare the two closest people.
        var closest: [String: Float] = [:]
        for known in decodedPrints {
            let distance = FaceIdentification.distance(observation, known.observation)
            closest[known.name] = min(closest[known.name] ?? .greatestFiniteMagnitude, distance)
        }
        let ranked = closest.sorted { $0.value < $1.value }
        let threshold = Self.matchThreshold(for: observation)
        guard let best = ranked.first, best.value <= threshold else { return nil }
        if ranked.count > 1, ranked[1].value - best.value < threshold * Self.minMarginToNextPerson { return nil }
        return (best.key, best.value)
    }

    private static func decode(_ prints: [KnownFacePrint]) -> [(name: String, observation: VNFeaturePrintObservation)] {
        prints.compactMap { known in
            guard let observation = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self, from: known.data
            ) else { return nil }
            return (known.name, observation)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([KnownFacePrint].self, from: data) else { return }
        allPrints = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(allPrints) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

/// Shows a name only once it wins most of the last few decisions, so one
/// off frame doesn't flash "not recognized" or someone else's name.
public struct IdentityStabilizer: Sendable {
    private var recent: [String?] = []
    private let windowSize = 5
    private let requiredVotes = 3
    public private(set) var shown: String?

    public init() {}

    public mutating func push(_ name: String?) -> String? {
        recent.append(name)
        if recent.count > windowSize { recent.removeFirst(recent.count - windowSize) }
        var votes: [String?: Int] = [:]
        for vote in recent { votes[vote, default: 0] += 1 }
        if let winner = votes.first(where: { $0.value >= requiredVotes }) { shown = winner.key }
        return shown
    }

    public mutating func reset() {
        recent = []
        shown = nil
    }
}
