/// Smooths the classified gesture over the last few frames via a majority
/// vote, the same fix applied to `ExpressionBaselineTracker` this session:
/// showing the raw per-frame classification directly meant a single frame
/// where the hand's angle relative to the camera briefly pushed one finger
/// across a threshold (very possible even while holding a shape steady)
/// flashed the wrong gesture, or "none", before correcting itself a frame
/// later. One instance of this per tracked hand slot (by array position,
/// since Vision doesn't give hands a stable identity across frames).
public final class HandGestureStabilizer {
    private var recentWindow: [DetectedGesture] = []
    private let windowSize = 5
    private let requiredVotes = 3

    public init() {}

    public func push(_ gesture: DetectedGesture) -> DetectedGesture {
        recentWindow.append(gesture)
        if recentWindow.count > windowSize {
            recentWindow.removeFirst(recentWindow.count - windowSize)
        }

        var voteCounts: [DetectedGesture: Int] = [:]
        for vote in recentWindow { voteCounts[vote, default: 0] += 1 }
        let winner = voteCounts
            .filter { $0.key != .none && $0.value >= requiredVotes }
            .max { $0.value < $1.value }?.key

        return winner ?? .none
    }
}
