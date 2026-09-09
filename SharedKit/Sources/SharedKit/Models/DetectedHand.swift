/// One tracked hand and its classified gesture — a capture service can
/// report more than one of these per frame (up to the Vision request's
/// `maximumHandCount`).
public struct DetectedHand: Identifiable, Sendable {
    public let id: Int
    public let landmarks: HandLandmarks
    public let gesture: DetectedGesture

    public init(id: Int, landmarks: HandLandmarks, gesture: DetectedGesture) {
        self.id = id
        self.landmarks = landmarks
        self.gesture = gesture
    }
}
