import AVFoundation
import Vision
import SharedKit
import Combine

@MainActor
final class CameraCaptureService: NSObject, ObservableObject {
    @Published var gesture: DetectedGesture = .none
    @Published var currentHand: HandLandmarks?
    @Published var didFailToStart = false

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "faceaiid.camera.queue")
    private let handRequest = VNDetectHumanHandPoseRequest()

    override init() {
        super.init()
        handRequest.maximumHandCount = 1
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            Task { @MainActor in
                guard granted else {
                    self.didFailToStart = true
                    return
                }
                self.configureSession()
            }
        }
    }

    func stop() {
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
                Task { @MainActor in self.didFailToStart = true }
                return
            }
            self.session.addInput(input)

            self.output.setSampleBufferDelegate(self, queue: self.queue)
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
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

            let hand = Self.landmarks(from: observation)
            let gesture = HandGestureClassifier.classify(hand)

            Task { @MainActor in
                self.currentHand = hand
                self.gesture = gesture
            }
        } catch {
            // Best-effort per-frame detection; a single failed frame is not fatal.
        }
    }

    nonisolated private static func landmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks {
        let mapping: [(HandLandmarks.Joint, VNHumanHandPoseObservation.JointName)] = [
            (.wrist, .wrist),
            (.thumbCMC, .thumbCMC), (.thumbMP, .thumbMP), (.thumbIP, .thumbIP), (.thumbTip, .thumbTip),
            (.indexMCP, .indexMCP), (.indexPIP, .indexPIP), (.indexDIP, .indexDIP), (.indexTip, .indexTip),
            (.middleMCP, .middleMCP), (.middlePIP, .middlePIP), (.middleDIP, .middleDIP), (.middleTip, .middleTip),
            (.ringMCP, .ringMCP), (.ringPIP, .ringPIP), (.ringDIP, .ringDIP), (.ringTip, .ringTip),
            (.littleMCP, .littleMCP), (.littlePIP, .littlePIP), (.littleDIP, .littleDIP), (.littleTip, .littleTip),
        ]

        var points: [HandLandmarks.Joint: HandPoint] = [:]
        for (joint, visionJoint) in mapping {
            if let point = try? observation.recognizedPoint(visionJoint), point.confidence > 0.3 {
                points[joint] = HandPoint(x: point.location.x, y: point.location.y, confidence: CGFloat(point.confidence))
            }
        }
        return HandLandmarks(points: points)
    }
}
