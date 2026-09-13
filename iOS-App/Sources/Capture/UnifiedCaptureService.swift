@preconcurrency import AVFoundation
@preconcurrency import Vision
import SharedKit
import Combine

/// Runs hand and face detection off a single shared camera session instead
/// of two separate `AVCaptureSession`s (one per mode). Two independent
/// sessions meant the camera had to stop and restart when switching between
/// the Hands and Face tabs, and neither mode could show the other's results
/// at the same time even though both are just different Vision requests
/// over the same frame.
@MainActor
final class UnifiedCaptureService: NSObject, ObservableObject {
    @Published var hands: [DetectedHand] = []
    @Published var expression: FacialExpression = .none
    @Published private(set) var expressionScores: ExpressionScores?
    @Published private(set) var faceDetected = false
    @Published var currentFaceLandmarks: VNFaceLandmarks2D?
    @Published private(set) var currentFaceBoundingBox: CGRect = .zero
    @Published private(set) var videoSize: CGSize = .zero
    @Published var headMovement: HeadMovement = .none
    @Published private(set) var status: CaptureStatus = .idle
    @Published var identityMatch: (name: String, distance: Float)?
    @Published var registrationFeedback: String?

    // Configuration and delegate callbacks for these run entirely on `queue`,
    // a dedicated serial queue — never touched concurrently, just not
    // provably so to the compiler across the MainActor boundary.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let handRequest = VNDetectHumanHandPoseRequest()
    nonisolated(unsafe) private let faceRequest = VNDetectFaceLandmarksRequest()
    nonisolated(unsafe) private var gestureStabilizers: [HandGestureStabilizer] = []
    private let queue = DispatchQueue(label: "faceaiid.capture.queue")
    nonisolated(unsafe) private let tracker = HeadMovementTracker()
    nonisolated(unsafe) private let expressionTracker = ExpressionBaselineTracker()
    nonisolated(unsafe) private var latestPixelBuffer: CVPixelBuffer?
    nonisolated(unsafe) private var latestFaceBoundingBox: CGRect?
    /// Feature-print extraction is comparatively expensive; recomputing it
    /// every frame at ~30fps buys no real accuracy for identification, so it
    /// only runs every Nth frame.
    nonisolated(unsafe) private var frameCounter = 0
    nonisolated private static let identityFrameInterval = 10

    override init() {
        super.init()
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
        tracker.reset()
        expressionTracker.reset()
        queue.async { [session, weak self] in
            if session.isRunning { session.stopRunning() }
            self?.gestureStabilizers.removeAll()
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
                let count = FaceIdentityStore.shared.sampleCount(for: name)
                self?.registrationFeedback = "\(LocalizationManager.shared.string(.faceIdSampleSaved)) (\(count)/\(FaceIdentityStore.maxSamples))"
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
                print("[FaceAIID] could not open a camera device (device=\(String(describing: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front))))")
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

extension UnifiedCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
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
            // Both requests run against the same frame/handler — this is
            // the whole point of unifying the two capture services: hands
            // and face were always independent Vision requests, they just
            // used to run on two separate camera sessions that couldn't be
            // active at the same time.
            try handler.perform([handRequest, faceRequest])

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

            guard let face = faceRequest.results?.first, let landmarks2D = face.landmarks else {
                tracker.reset()
                Task { @MainActor in
                    self.hands = detectedHands
                    self.videoSize = videoSize
                    self.expression = .none
                    self.expressionScores = nil
                    self.headMovement = .none
                    self.identityMatch = nil
                    self.faceDetected = false
                    self.currentFaceLandmarks = nil
                }
                return
            }

            let scores = FacialExpressionClassifier.scores(landmarks2D)
            let expression = scores.map { expressionTracker.classify($0) } ?? .none
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
                self.hands = detectedHands
                self.videoSize = videoSize
                self.expression = expression
                self.expressionScores = scores
                self.headMovement = movement
                self.faceDetected = true
                self.currentFaceLandmarks = landmarks2D
                self.currentFaceBoundingBox = face.boundingBox
                if shouldCheckIdentity {
                    self.identityMatch = identityObservation.flatMap { FaceIdentityStore.shared.match($0) }
                }
            }
        } catch {
            // Best-effort per-frame detection; a single failed frame is not fatal.
            print("[FaceAIID] detection frame failed: \(error)")
        }
    }
}
