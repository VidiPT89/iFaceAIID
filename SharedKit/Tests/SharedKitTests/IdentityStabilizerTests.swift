import XCTest
@testable import SharedKit

final class IdentityStabilizerTests: XCTestCase {
    func testSwitchesOnlyAfterANameWinsMostRecentChecks() {
        var stabilizer = IdentityStabilizer()
        XCTAssertNil(stabilizer.push("Ana"))
        XCTAssertNil(stabilizer.push("Ana"))
        XCTAssertEqual(stabilizer.push("Ana"), "Ana")
        // A single stray check doesn't flip the answer.
        XCTAssertEqual(stabilizer.push("Rui"), "Ana")
        XCTAssertEqual(stabilizer.push(nil), "Ana")
        stabilizer.reset()
        XCTAssertNil(stabilizer.shown)
    }
}
