import Foundation

/// Detects nodding, shaking, tilting and where the head is pointing from a
/// short rolling window of head angles (radians).
///
/// Callers pass `yaw` positive when the person turns toward *their own*
/// left, and `pitch` positive when looking down. Nod and shake are
/// back-and-forth movements; tilt, turn and look are held poses, and
/// movements win so a nod isn't reported as "looking down" halfway through.
public final class HeadMovementTracker {
    private static let historySize = 20
    private static let oscillationThreshold = 0.09 // ~5°
    /// A slight lean is normal posture; ~15° is a deliberate tilt.
    private static let tiltThreshold = 0.26
    /// ~20°: well past where people hold their head while reading a screen.
    private static let turnThreshold = 0.35
    /// Cameras sit above the screen, so a resting head already reads a
    /// little "down"; the down bar is set further out than the up one.
    private static let lookDownThreshold = 0.4
    private static let lookUpThreshold = 0.3

    private var pitchHistory: [Double] = []
    private var yawHistory: [Double] = []

    public init() {}

    public func push(pitch: Double, yaw: Double, roll: Double) -> HeadMovement {
        pitchHistory.append(pitch)
        yawHistory.append(yaw)
        if pitchHistory.count > Self.historySize { pitchHistory.removeFirst() }
        if yawHistory.count > Self.historySize { yawHistory.removeFirst() }

        if pitchHistory.count == Self.historySize {
            let pitchOscillations = Self.countSignChanges(pitchHistory, threshold: Self.oscillationThreshold)
            let yawOscillations = Self.countSignChanges(yawHistory, threshold: Self.oscillationThreshold)
            if pitchOscillations >= 2 && pitchOscillations >= yawOscillations { return .nodYes }
            if yawOscillations >= 2 { return .shakeNo }
        }

        if abs(roll) > Self.tiltThreshold { return .tilt }
        if yaw > Self.turnThreshold { return .turnLeft }
        if yaw < -Self.turnThreshold { return .turnRight }
        if pitch > Self.lookDownThreshold { return .lookDown }
        if pitch < -Self.lookUpThreshold { return .lookUp }
        return .none
    }

    public func reset() {
        pitchHistory.removeAll()
        yawHistory.removeAll()
    }

    private static func countSignChanges(_ values: [Double], threshold: Double) -> Int {
        let mean = values.reduce(0, +) / Double(values.count)
        let deviations = values.map { $0 - mean }.filter { abs($0) > threshold }
        return zip(deviations, deviations.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
    }
}
