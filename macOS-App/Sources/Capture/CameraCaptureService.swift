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
    nonisolated(unsafe) private var gestureStabilizers: [HandGestureStabilizer] = []
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
        queue.async { [session, weak self] in
            if session.isRunning { session.stopRunning() }
            self?.gestureStabilizers.removeAll()
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
                // This path was completely silent before — if no camera
                // device can be found or claimed (e.g. already held
                // exclusively by another app), the user just saw the same
                // "permission needed" text as before ever clicking, with
                // no way to tell the click did anything at all.
                print("[FaceAIID] could not open a camera device (device=\(String(describing: AVCaptureDevice.default(for: .video))))")
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
        let videoSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

        do {
            try handler.perform([handRequest])
            let observations = handRequest.results ?? []

            if gestureStabilizers.count > observations.count {
                gestureStabilizers.removeLast(gestureStabilizers.count - observations.count)
            }
            let detectedHands: [DetectedHand] = observations.enumerated().map { index, observation in
                let landmarks = VisionHandMapping.landmarks(from: observation)
                let rawGesture = HandGestureClassifier.classify(landmarks)
                if index >= gestureStabilizers.count { gestureStabilizers.append(HandGestureStabilizer()) }
                let gesture = gestureStabilizers[index].push(rawGesture)
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
