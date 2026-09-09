@preconcurrency import AVFoundation
import Vision
import SharedKit
import Combine

@MainActor
final class CameraCaptureService: NSObject, ObservableObject {
    @Published var hands: [DetectedHand] = []
    @Published private(set) var status: CaptureStatus = .idle
    @Published private(set) var videoSize: CGSize = .zero

    // Configuration and delegate callbacks for these three run entirely on
    // `queue`, a dedicated serial queue — never touched concurrently, just
    // not provably so to the compiler across the MainActor boundary.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let handRequest = VNDetectHumanHandPoseRequest()
    private let queue = DispatchQueue(label: "faceaiid.camera.queue")

    override init() {
        super.init()
        // Detect up to 2 hands — the request previously capped at 1, so a
        // second hand in frame was silently ignored no matter how clearly
        // it was visible.
        handRequest.maximumHandCount = 2
    }

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
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
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

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
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

        // Vision reports landmark coordinates relative to the image *after*
        // applying the given orientation — a 90° rotation, here — so the
        // width/height used to map those normalized points back onto the
        // (also-rotated) preview must be swapped relative to the raw buffer.
        let rawWidth = CVPixelBufferGetWidth(pixelBuffer)
        let rawHeight = CVPixelBufferGetHeight(pixelBuffer)
        let videoSize = CGSize(width: rawHeight, height: rawWidth)

        do {
            try handler.perform([handRequest])
            let observations = handRequest.results ?? []

            let detectedHands: [DetectedHand] = observations.enumerated().map { index, observation in
                let landmarks = VisionHandMapping.landmarks(from: observation)
                let gesture = HandGestureClassifier.classify(landmarks)
                let handedness = VisionHandMapping.handedness(from: observation)
                return DetectedHand(id: index, landmarks: landmarks, gesture: gesture, handedness: handedness)
            }

            Task { @MainActor in
                self.hands = detectedHands
                self.videoSize = videoSize
            }
        } catch {
            // Best-effort per-frame detection; a single failed frame is not fatal.
            print("[FaceAIID] detection frame failed: \(error)")
        }
    }
}
