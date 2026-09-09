@preconcurrency import AVFoundation
import Vision
import SharedKit
import Combine

@MainActor
final class FaceCaptureService: NSObject, ObservableObject {
    @Published var expression: FacialExpression = .none
    @Published var headMovement: HeadMovement = .none
    @Published private(set) var status: CaptureStatus = .idle
    @Published var identityMatch: (name: String, distance: Float)?
    @Published var registrationFeedback: String?

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let faceRequest = VNDetectFaceLandmarksRequest()
    private let queue = DispatchQueue(label: "faceaiid.face.queue")
    nonisolated(unsafe) private let tracker = HeadMovementTracker()
    nonisolated(unsafe) private var latestPixelBuffer: CVPixelBuffer?
    nonisolated(unsafe) private var latestFaceBoundingBox: CGRect?
    /// Feature-print extraction is comparatively expensive; recomputing it
    /// every frame at ~30fps buys no real accuracy for identification, so it
    /// only runs every Nth frame.
    nonisolated(unsafe) private var frameCounter = 0
    nonisolated private static let identityFrameInterval = 10

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            Task { @MainActor in
                guard granted else {
                    self.status = .denied
                    return
                }
                self.configureSession()
            }
        }
    }

    func stop() {
        status = .idle
        tracker.reset()
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func registerCurrentFace(name: String) {
        guard let pixelBuffer = latestPixelBuffer, let box = latestFaceBoundingBox else {
            registrationFeedback = LocalizationManager.shared.string(.faceIdNoFaceDetected)
            return
        }
        let snapshot = PixelBufferSnapshot(buffer: pixelBuffer, boundingBox: box)
        queue.async { [weak self] in
            guard let observation = try? FaceIdentification.featurePrint(from: snapshot.buffer, faceBoundingBox: snapshot.boundingBox) else { return }
            Task { @MainActor in
                FaceIdentityStore.shared.register(name: name, observation: observation)
                self?.registrationFeedback = nil
            }
        }
    }

    private func configureSession() {
        queue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                Task { @MainActor in self.status = .failed }
                return
            }
            self.session.addInput(input)

            self.output.setSampleBufferDelegate(self, queue: self.queue)
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            Task { @MainActor in self.status = .running }
        }
    }
}

/// CVPixelBuffer isn't Sendable, but it's only ever read (never mutated)
/// after being handed off here, so it's safe to cross the queue boundary.
private struct PixelBufferSnapshot: @unchecked Sendable {
    let buffer: CVPixelBuffer
    let boundingBox: CGRect
}

extension FaceCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Front camera buffers on a portrait-locked iPhone arrive in the
        // sensor's native landscape orientation; .leftMirrored is the
        // correct mapping so Vision sees an upright, correctly mirrored
        // frame instead of a hand/face rotated 90° (which badly hurts
        // detection confidence).
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])

        do {
            try handler.perform([faceRequest])
            guard let face = faceRequest.results?.first, let landmarks2D = face.landmarks else {
                Task { @MainActor in
                    self.expression = .none
                }
                return
            }

            let expression = FacialExpressionClassifier.classify(landmarks2D)
            let pitch = face.pitch?.doubleValue ?? 0
            let yaw = face.yaw?.doubleValue ?? 0
            let roll = face.roll?.doubleValue ?? 0
            let movement = tracker.push(pitch: pitch, yaw: yaw, roll: roll)

            latestPixelBuffer = pixelBuffer
            latestFaceBoundingBox = face.boundingBox

            frameCounter += 1
            let shouldCheckIdentity = frameCounter % Self.identityFrameInterval == 0
            let identityObservation = shouldCheckIdentity
                ? try? FaceIdentification.featurePrint(from: pixelBuffer, faceBoundingBox: face.boundingBox)
                : nil

            Task { @MainActor in
                self.expression = expression
                self.headMovement = movement
                if shouldCheckIdentity {
                    self.identityMatch = identityObservation.flatMap { FaceIdentityStore.shared.match($0) }
                }
            }
        } catch {
            // Best-effort per-frame detection; a single failed frame is not fatal.
        }
    }
}
