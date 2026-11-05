import XCTest
@testable import SharedKit

final class HeadMovementTrackerTests: XCTestCase {
    private let degree = Double.pi / 180

    private func hold(pitch: Double = 0, yaw: Double = 0, roll: Double = 0, frames: Int = 1) -> HeadMovement {
        let tracker = HeadMovementTracker()
        var result: HeadMovement = .none
        for _ in 0..<frames { result = tracker.push(pitch: pitch, yaw: yaw, roll: roll) }
        return result
    }

    func testHeldPoses() {
        XCTAssertEqual(hold(), .none)
        XCTAssertEqual(hold(yaw: 30 * degree), .turnLeft)
        XCTAssertEqual(hold(yaw: -30 * degree), .turnRight)
        XCTAssertEqual(hold(pitch: 30 * degree), .lookDown)
        XCTAssertEqual(hold(pitch: -25 * degree), .lookUp)
        XCTAssertEqual(hold(roll: 20 * degree), .tilt)
    }

    func testIgnoresTheSlightDownwardAngleOfReadingAScreen() {
        XCTAssertEqual(hold(pitch: 12 * degree, frames: 25), .none)
    }

    func testNodAndShake() {
        func oscillate(pitchAxis: Bool) -> HeadMovement {
            let tracker = HeadMovementTracker()
            var result: HeadMovement = .none
            for i in 0..<24 {
                let swing = (i % 6 < 3 ? 1.0 : -1.0) * 12 * degree
                result = tracker.push(pitch: pitchAxis ? swing : 0, yaw: pitchAxis ? 0 : swing, roll: 0)
            }
            return result
        }
        XCTAssertEqual(oscillate(pitchAxis: true), .nodYes)
        XCTAssertEqual(oscillate(pitchAxis: false), .shakeNo)
    }
}
