import XCTest
import Vision
@testable import SharedKit

/// Hand points Vision produced on MediaPipe's public test photos (see the
/// fixture's `source`). Synthetic hands only check that the rules do what
/// they say; these check them against real hands.
final class RealHandsTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Hand: Decodable {
            let image: String
            let width: CGFloat
            let height: CGFloat
            let joints: [String: [Double]]
        }
        let hands: [Hand]
    }

    /// Acceptable answers per photo. "none" is accepted for the relaxed,
    /// half-open hands: no answer is fine, a wrong gesture is not.
    private let expected: [String: Set<DetectedGesture>] = [
        "fist.jpg": [.closedFist],
        "pointing_up.jpg": [.pointing],
        "pointing_up_mirror.jpg": [.pointing],
        "pointing_up_rotated.jpg": [.pointing],
        "left_hands.jpg": [.openPalm],
        "male_full_height_hands.jpg": [.openPalm, .none],
        "hand-woman-man.jpg": [.openPalm, .none],
        "portrait_small.jpg": [.openPalm, .none],
        "portrait_mirror.jpg": [.openPalm, .none],
    ]

    func testClassifierOnRealVisionHands() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "vision-hands-real", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertFalse(fixture.hands.isEmpty)
        for hand in fixture.hands {
            var recognized: [VNHumanHandPoseObservation.JointName: (location: CGPoint, confidence: Float)] = [:]
            for (key, value) in hand.joints {
                let name = VNHumanHandPoseObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: key))
                recognized[name] = (CGPoint(x: value[0], y: value[1]), Float(value[2]))
            }
            let landmarks = VisionHandMapping.landmarks(from: recognized).aspectCorrected(hand.width / hand.height)
            let gesture = HandGestureClassifier.classify(landmarks)
            XCTAssertTrue(expected[hand.image]?.contains(gesture) ?? false, "\(hand.image): got \(gesture)")
        }
    }
}
