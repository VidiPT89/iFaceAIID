@preconcurrency import AVFoundation
import Vision
import SharedKit
import Combine

@MainActor
final class CameraCaptureService: NSObject, ObservableObject {
    @Published var gesture: DetectedGesture = .none
    @Published var currentHand: HandLandmarks?
    @Published private(set) var status: CaptureStatus = .idle

    // Configuration and delegate callbacks for these three run entirely on
    // `queue`, a dedicated serial queue — never touched concurrently, just
    // not provably so to the compiler across the MainActor boundary.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let handRequest = VNDetectHumanHandPoseRequest()
    private let queue = DispatchQueue(label: "faceaiid.camera.queue")

    override init() {
        super.init()
        handRequest.maximumHandCount = 1
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

            guard let device = AVCaptureDevice.default(for: .video),
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
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([handRequest])
            guard let observation = handRequest.results?.first else {
                Task { @MainActor in
                    self.currentHand = nil
                    self.gesture = .none
                }
                return
            }

            let hand = VisionHandMapping.landmarks(from: observation)
            let gesture = HandGestureClassifier.classify(hand)

            Task { @MainActor in
                self.currentHand = hand
                self.gesture = gesture
            }
        } catch {
            // Best-effort per-frame detection; a single failed frame is not fatal.
        }
    }
}
