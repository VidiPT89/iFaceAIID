import XCTest
import AVFoundation
@testable import MacCapture

final class CameraLifecycleTests: XCTestCase {
    @MainActor
    func testDeniedPermissionDoesNotRequestAgain() {
        let capture = UnifiedCaptureService(authorizationStatus: { .denied }, requestAccess: { _ in
            XCTFail("Denied access must be resolved in Settings")
        })
        capture.start()
        XCTAssertEqual(capture.status, .denied)
        XCTAssertFalse(capture.isStarting)
    }

    @MainActor
    func testRepeatedStartOnlyRequestsPermissionOnce() {
        var requests = 0
        let capture = UnifiedCaptureService(authorizationStatus: { .notDetermined }, requestAccess: { _ in requests += 1 })
        capture.start()
        capture.start()
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(capture.isStarting)
        capture.stop()
        XCTAssertFalse(capture.isStarting)
        XCTAssertEqual(capture.status, .idle)
    }

    @MainActor
    func testLatePermissionResponseDoesNotOverwriteNewStart() async {
        var completions: [@Sendable (Bool) -> Void] = []
        let capture = UnifiedCaptureService(authorizationStatus: { .notDetermined }, requestAccess: { completions.append($0) })
        capture.start()
        capture.stop()
        capture.start()
        completions[0](false)
        // Drain the permission callback's MainActor task before asserting.
        await Task { @MainActor in }.value
        XCTAssertTrue(capture.isStarting)
        XCTAssertEqual(capture.status, .idle)
        completions[1](false)
        await Task { @MainActor in }.value
        XCTAssertFalse(capture.isStarting)
        XCTAssertEqual(capture.status, .denied)
        capture.stop()
    }

    @MainActor
    func testStopClearsResultsAndFeedback() {
        let capture = UnifiedCaptureService(authorizationStatus: { .denied }, requestAccess: { _ in })
        capture.registrationFeedback = "Saved"
        capture.identityMatch = ("Test", 1)
        capture.stop()
        XCTAssertNil(capture.registrationFeedback)
        XCTAssertNil(capture.identityMatch)
        XCTAssertTrue(capture.hands.isEmpty)
        XCTAssertFalse(capture.faceDetected)
    }
}
