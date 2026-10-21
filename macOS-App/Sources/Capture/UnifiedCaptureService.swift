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
    @Published private(set) var isStarting = false
    @Published private(set) var failureMessage: LocalizedKey = .cameraError
    private let authorizationStatus: () -> AVAuthorizationStatus
    private let requestAccess: (@escaping @Sendable (Bool) -> Void) -> Void
    private var generation = UUID()
    nonisolated(unsafe) private var activeGeneration: UUID?
    nonisolated(unsafe) private var isConfigured = false

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

    override convenience init() {
        self.init(
            authorizationStatus: { AVCaptureDevice.authorizationStatus(for: .video) },
            requestAccess: { AVCaptureDevice.requestAccess(for: .video, completionHandler: $0) }
        )
    }

    init(
        authorizationStatus: @escaping () -> AVAuthorizationStatus,
        requestAccess: @escaping (@escaping @Sendable (Bool) -> Void) -> Void
    ) {
        self.authorizationStatus = authorizationStatus
        self.requestAccess = requestAccess
        super.init()
        handRequest.maximumHandCount = 2
    }

    func start() {
        guard !isStarting, status != .running else { return }
        generation = UUID()
        let token = generation
        isStarting = true
        status = .idle
        registrationFeedback = nil
        switch authorizationStatus() {
        case .authorized:
            configureSession(token: token)
        case .notDetermined:
            requestAccess { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if granted {
                        self.configureSession(token: token)
                    } else {
                        self.isStarting = false
                        self.status = .denied
                    }
                }
            }
        default:
            isStarting = false
            status = .denied
        }
    }

    func stop() {
        generation = UUID() // Ignore permission responses and queued frames from the old run.
        isStarting = false
        status = .idle
        hands = []
        expression = .none
        expressionScores = nil
        headMovement = .none
        identityMatch = nil
        faceDetected = false
        currentFaceLandmarks = nil
        currentFaceBoundingBox = .zero
        registrationFeedback = nil
        queue.async { [self] in
            activeGeneration = nil
            if session.isRunning { session.stopRunning() }
            tracker.reset()
            expressionTracker.reset()
            gestureStabilizers.removeAll()
            latestPixelBuffer = nil
            latestFaceBoundingBox = nil
            frameCounter = 0
        }
    }

    func registerCurrentFace(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, status == .running, faceDetected else { return }
        let token = generation
        queue.async { [weak self] in
            guard let self, self.activeGeneration == token else { return }
            // Read the frame on the same queue that writes it, never on MainActor.
            guard let buffer = self.latestPixelBuffer, let box = self.latestFaceBoundingBox else {
                Task { @MainActor in
                    guard self.generation == token else { return }
                    self.registrationFeedback = LocalizationManager.shared.string(.faceIdNoFaceDetected)
                }
                return
            }
            let observation = try? FaceIdentification.featurePrint(from: buffer, faceBoundingBox: box)
            Task { @MainActor in
                guard self.generation == token else { return }
                guard let observation else {
                    self.registrationFeedback = LocalizationManager.shared.string(.faceIdRegistrationFailed)
                    return
                }
                FaceIdentityStore.shared.register(name: name, observation: observation)
                let count = FaceIdentityStore.shared.sampleCount(for: name)
                self.registrationFeedback = "\(LocalizationManager.shared.string(.faceIdSampleSaved)) (\(count)/\(FaceIdentityStore.maxSamples))"
            }
        }
    }

    private func configureSession(token: UUID) {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                guard let device = AVCaptureDevice.default(for: .video) else {
                    self.session.commitConfiguration()
                    self.reportFailure(.cameraUnavailable, token: token)
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    guard self.session.canAddInput(input) else {
                        self.session.commitConfiguration()
                        self.reportFailure(.cameraError, token: token)
                        return
                    }
                    self.session.addInput(input)
                    guard self.session.canAddOutput(self.output) else {
                        self.session.removeInput(input)
                        self.session.commitConfiguration()
                        self.reportFailure(.cameraError, token: token)
                        return
                    }
                    self.output.alwaysDiscardsLateVideoFrames = true
                    self.output.setSampleBufferDelegate(self, queue: self.queue)
                    self.session.addOutput(self.output)
                    self.session.commitConfiguration()
                    self.isConfigured = true
                } catch {
                    self.session.commitConfiguration()
                    self.reportFailure(.cameraError, token: token)
                    return
                }
            }
            self.activeGeneration = token
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            Task { @MainActor in
                guard self.generation == token else { return }
                self.isStarting = false
                self.status = running ? .running : .failed
                self.failureMessage = .cameraError
            }
        }
    }

    nonisolated private func reportFailure(_ message: LocalizedKey, token: UUID) {
        Task { @MainActor in
            guard self.generation == token else { return }
            self.failureMessage = message
            self.isStarting = false
            self.status = .failed
        }
    }

}

extension UnifiedCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let token = activeGeneration,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let videoSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

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
                expressionTracker.reset()
                latestPixelBuffer = nil
                latestFaceBoundingBox = nil
                Task { @MainActor in
                    guard self.generation == token, self.status == .running else { return }
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
                guard self.generation == token, self.status == .running else { return }
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
            latestPixelBuffer = nil
            latestFaceBoundingBox = nil
            // Best-effort per-frame detection; a single failed frame is not fatal.
            print("[FaceAIID] detection frame failed: \(error)")
        }
    }
}
