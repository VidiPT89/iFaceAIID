@preconcurrency import AVFoundation
@preconcurrency import Vision
import Combine

/// Runs hand and face detection off one shared camera session — both are
/// independent Vision requests over the same frame, so a single session
/// shows every result at once.
///
/// Shared by the iOS and macOS apps: the two used to keep separate copies,
/// and the iOS copy silently missed every lifecycle fix made on macOS (it
/// re-added the camera input on each start, so stopping and starting again
/// failed). Only camera selection and frame orientation differ per platform.
@MainActor
public final class CaptureService: NSObject, ObservableObject {
    @Published public private(set) var hands: [DetectedHand] = []
    @Published public private(set) var expression: FacialExpression = .none
    @Published public private(set) var expressionScores: ExpressionScores?
    @Published public private(set) var faceDetected = false
    @Published public private(set) var currentFaceLandmarks: VNFaceLandmarks2D?
    @Published public private(set) var currentFaceBoundingBox: CGRect = .zero
    @Published public private(set) var videoSize: CGSize = .zero
    @Published public private(set) var headMovement: HeadMovement = .none
    @Published public private(set) var status: CaptureStatus = .idle
    /// The recognized person, only once they've won most recent checks.
    @Published public internal(set) var identityName: String?
    @Published public internal(set) var registrationFeedback: String?
    @Published public private(set) var isStarting = false
    @Published public private(set) var failureMessage: LocalizedKey = .cameraError

    private let authorizationStatus: () -> AVAuthorizationStatus
    private let requestAccess: (@escaping @Sendable (Bool) -> Void) -> Void
    /// A fresh token per start/stop, so late permission callbacks and queued
    /// frames from an earlier run can't overwrite the current state.
    private var generation = UUID()

    // Everything below is only touched on `queue`, a dedicated serial
    // queue — never concurrently, just not provably so to the compiler
    // across the MainActor boundary.
    nonisolated(unsafe) private var activeGeneration: UUID?
    nonisolated(unsafe) private var isConfigured = false
    nonisolated(unsafe) public let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let handRequest = VNDetectHumanHandPoseRequest()
    /// Run alongside the landmarks request so the face observation carries
    /// continuous yaw *and pitch*: the landmarks request on its own reports
    /// no pitch at all (so nodding could never be detected) and a yaw stuck
    /// at 0 on MediaPipe's test portraits.
    nonisolated(unsafe) private let faceRectanglesRequest: VNDetectFaceRectanglesRequest = {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        return request
    }()
    nonisolated(unsafe) private let faceRequest = VNDetectFaceLandmarksRequest()
    private var identityStabilizer = IdentityStabilizer()
    /// Whether the latest face is seen clearly enough to register: frontal,
    /// upright and not too far away.
    nonisolated(unsafe) private var latestFaceIsRegistrable = false
    nonisolated(unsafe) private var gestureStabilizers: [HandGestureStabilizer] = []
    nonisolated(unsafe) private let tracker = HeadMovementTracker()
    nonisolated(unsafe) private let expressionTracker = ExpressionBaselineTracker()
    nonisolated(unsafe) private var latestPixelBuffer: CVPixelBuffer?
    nonisolated(unsafe) private var latestFaceBoundingBox: CGRect?
    /// Feature-print extraction is comparatively expensive; recomputing it
    /// every frame at ~30fps buys no real accuracy for identification, so it
    /// only runs every Nth frame.
    nonisolated(unsafe) private var frameCounter = 0
    nonisolated private static let identityFrameInterval = 10
    private let queue = DispatchQueue(label: "faceaiid.capture.queue")

    public override convenience init() {
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

    public func start() {
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

    public func stop() {
        generation = UUID()
        isStarting = false
        status = .idle
        hands = []
        expression = .none
        expressionScores = nil
        headMovement = .none
        identityName = nil
        faceDetected = false
        currentFaceLandmarks = nil
        currentFaceBoundingBox = .zero
        registrationFeedback = nil
        identityStabilizer.reset()
        queue.async { [self] in
            latestFaceIsRegistrable = false
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

    public func registerCurrentFace(name: String) {
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
            guard self.latestFaceIsRegistrable else {
                Task { @MainActor in
                    guard self.generation == token else { return }
                    self.registrationFeedback = LocalizationManager.shared.string(.faceIdLowQuality)
                }
                return
            }
            let observation = try? FaceIdentification.featurePrint(
                from: buffer, faceBoundingBox: box, orientation: Self.frameOrientation
            )
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
                guard let device = Self.captureDevice() else {
                    self.session.commitConfiguration()
                    self.reportFailure(.cameraUnavailable, token: token, reason: "no video capture device")
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    guard self.session.canAddInput(input) else {
                        self.session.commitConfiguration()
                        self.reportFailure(.cameraError, token: token, reason: "cannot add input for \(device.localizedName)")
                        return
                    }
                    self.session.addInput(input)
                    guard self.session.canAddOutput(self.output) else {
                        self.session.removeInput(input)
                        self.session.commitConfiguration()
                        self.reportFailure(.cameraError, token: token, reason: "cannot add video output")
                        return
                    }
                    self.output.alwaysDiscardsLateVideoFrames = true
                    self.output.setSampleBufferDelegate(self, queue: self.queue)
                    self.session.addOutput(self.output)
                    self.session.commitConfiguration()
                    self.isConfigured = true
                } catch {
                    self.session.commitConfiguration()
                    self.reportFailure(.cameraError, token: token, reason: "\(error)")
                    return
                }
            }
            self.activeGeneration = token
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            if !running { print("[FaceAIID] capture session did not start running") }
            Task { @MainActor in
                guard self.generation == token else { return }
                self.isStarting = false
                self.status = running ? .running : .failed
                self.failureMessage = .cameraError
            }
        }
    }

    nonisolated private func reportFailure(_ message: LocalizedKey, token: UUID, reason: String) {
        print("[FaceAIID] could not open the camera: \(reason)")
        Task { @MainActor in
            guard self.generation == token else { return }
            self.failureMessage = message
            self.isStarting = false
            self.status = .failed
        }
    }

    // MARK: - Platform differences

    nonisolated private static func captureDevice() -> AVCaptureDevice? {
        #if os(iOS)
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        #else
        AVCaptureDevice.default(for: .video)
        #endif
    }

    /// Front camera buffers on a portrait-locked iPhone arrive in the
    /// sensor's native landscape orientation; `.leftMirrored` makes Vision
    /// see an upright, mirrored frame (a 90°-rotated face badly hurts
    /// detection). A Mac camera delivers frames upright and un-mirrored.
    /// Vision's yaw is positive when the nose moves toward the image's
    /// right (measured on MediaPipe's portrait and its mirror image). In
    /// the Mac's un-mirrored frame that's the person turning to their own
    /// left; the iPhone's frame is mirrored, so the sign flips there.
    nonisolated private static let yawTowardOwnLeft: Double = {
        #if os(iOS)
        -1
        #else
        1
        #endif
    }()

    nonisolated private static let frameOrientation: CGImagePropertyOrientation = {
        #if os(iOS)
        .leftMirrored
        #else
        .up
        #endif
    }()

    /// Vision reports landmarks relative to the image *after* applying the
    /// orientation above — rotated 90° on iOS — so the size used to map them
    /// back onto the preview must be swapped relative to the raw buffer there.
    nonisolated private static func orientedSize(of pixelBuffer: CVPixelBuffer) -> CGSize {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        #if os(iOS)
        return CGSize(width: height, height: width)
        #else
        return CGSize(width: width, height: height)
        #endif
    }
}

extension CaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let token = activeGeneration,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: Self.frameOrientation, options: [:])
        let videoSize = Self.orientedSize(of: pixelBuffer)

        do {
            try handler.perform([handRequest, faceRectanglesRequest, faceRequest])

            let observations = handRequest.results ?? []
            if gestureStabilizers.count > observations.count {
                gestureStabilizers.removeLast(gestureStabilizers.count - observations.count)
            }
            let detectedHands: [DetectedHand] = observations.enumerated().map { index, observation in
                let landmarks = VisionHandMapping.landmarks(from: observation)
                let aspect = videoSize.height > 0 ? videoSize.width / videoSize.height : 1
                let rawGesture = HandGestureClassifier.classify(landmarks.aspectCorrected(aspect))
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
                latestFaceIsRegistrable = false
                Task { @MainActor in
                    self.identityStabilizer.reset()
                    guard self.generation == token, self.status == .running else { return }
                    self.hands = detectedHands
                    self.videoSize = videoSize
                    self.expression = .none
                    self.expressionScores = nil
                    self.headMovement = .none
                    self.identityName = nil
                    self.faceDetected = false
                    self.currentFaceLandmarks = nil
                }
                return
            }

            let scores = FacialExpressionClassifier.scores(landmarks2D)
            let expression = scores.map { expressionTracker.classify($0) } ?? .none
            let yaw = (face.yaw?.doubleValue ?? 0) * Self.yawTowardOwnLeft
            let pitch = face.pitch?.doubleValue ?? 0
            let roll = face.roll?.doubleValue ?? 0
            let movement = tracker.push(pitch: pitch, yaw: yaw, roll: roll)

            latestPixelBuffer = pixelBuffer
            latestFaceBoundingBox = face.boundingBox
            // A turned or tilted face gives an unreliable feature print (a
            // 90°-rotated portrait scored 0.71-0.94 against the same person).
            let faceIsClear = abs(yaw) < 0.35 && abs(roll) < 0.3
            latestFaceIsRegistrable = faceIsClear && face.boundingBox.width >= 0.1

            frameCounter += 1
            let shouldCheckIdentity = faceIsClear && frameCounter % Self.identityFrameInterval == 0
            let identityObservation = shouldCheckIdentity
                ? try? FaceIdentification.featurePrint(
                    from: pixelBuffer, faceBoundingBox: face.boundingBox, orientation: Self.frameOrientation
                )
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
                    let name = identityObservation.flatMap { FaceIdentityStore.shared.match($0) }?.name
                    self.identityName = self.identityStabilizer.push(name)
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
