import Foundation

/// Tracks a short rolling window of head pitch/yaw (radians, from Vision's
/// `VNFaceObservation.pitch`/`yaw`) to detect nodding, shaking or tilting —
/// the same oscillation heuristic used by the web app's HeadMovementTracker.
public final class HeadMovementTracker {
    private static let historySize = 20
    private static let oscillationThreshold = 0.09 // radians, ~5 degrees
    private static let tiltThreshold = 0.2 // radians, ~11 degrees

    private var pitchHistory: [Double] = []
    private var yawHistory: [Double] = []

    public init() {}

    public func push(pitch: Double, yaw: Double, roll: Double) -> HeadMovement {
        pitchHistory.append(pitch)
        yawHistory.append(yaw)
        if pitchHistory.count > Self.historySize { pitchHistory.removeFirst() }
        if yawHistory.count > Self.historySize { yawHistory.removeFirst() }

        guard pitchHistory.count == Self.historySize else { return .none }

        let pitchOscillations = Self.countSignChanges(pitchHistory, threshold: Self.oscillationThreshold)
        let yawOscillations = Self.countSignChanges(yawHistory, threshold: Self.oscillationThreshold)

        if pitchOscillations >= 2 && pitchOscillations >= yawOscillations {
            return .nodYes
        }
        if yawOscillations >= 2 {
            return .shakeNo
        }
        if abs(roll) > Self.tiltThreshold {
            return .tilt
        }
        return .none
    }

    public func reset() {
        pitchHistory.removeAll()
        yawHistory.removeAll()
    }

    private static func countSignChanges(_ values: [Double], threshold: Double) -> Int {
        let mean = values.reduce(0, +) / Double(values.count)
        let deviations = values.map { $0 - mean }.filter { abs($0) > threshold }
        var changes = 0
        for i in 1..<max(deviations.count, 1) where i < deviations.count {
            let prevSign = deviations[i - 1] < 0 ? -1 : (deviations[i - 1] > 0 ? 1 : 0)
            let currSign = deviations[i] < 0 ? -1 : (deviations[i] > 0 ? 1 : 0)
            if prevSign != currSign && currSign != 0 {
                changes += 1
            }
        }
        return changes
    }
}
