import SwiftUI

/// Live camera preview with hand, face and identity results drawn over it,
/// plus the start/stop and face-registration controls. Shared by both apps
/// so a fix lands on iOS and macOS at once.
struct DetectionView: View {
    @StateObject private var capture = CaptureService()
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var identityStore = FaceIdentityStore.shared
    @ObservedObject private var debugMode = DebugModeStore.shared
    @Environment(\.openURL) private var openURL
    @State private var nameInput = ""

    private var isRunning: Bool { capture.status == .running }

    var body: some View {
        VStack(spacing: 16) {
            Text(localization.string(.heroSubtitleUnified))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Self.stageBackground)

                if isRunning {
                    overlays
                } else {
                    placeholder
                }

                if debugMode.isEnabled {
                    debugPanel
                }

                badges
            }
            .aspectRatio(Self.stageAspectRatio, contentMode: .fit)
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 360)
            #endif

            Button {
                if isRunning || capture.isStarting { capture.stop() } else { capture.start() }
            } label: {
                Text(localization.string(capture.isStarting ? .cameraCancel : (isRunning ? .cameraStop : .cameraStart)))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(BrandColor.gradient, in: Capsule())
            }
            .buttonStyle(.plain)

            if isRunning {
                HStack {
                    TextField(localization.string(.faceIdNamePlaceholder), text: $nameInput)
                        .textFieldStyle(.roundedBorder)
                    Button(localization.string(.faceIdRegister)) {
                        // The name stays filled so several samples (different
                        // angles/lighting) can be saved in a row.
                        capture.registerCurrentFace(name: nameInput)
                    }
                    .disabled(nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !capture.faceDetected)
                }

                if let feedback = capture.registrationFeedback {
                    Text(feedback).font(.caption).foregroundStyle(.secondary)
                }
            }

            if !identityStore.knownFaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(identityStore.knownFaces, id: \.self) { name in
                            HStack(spacing: 4) {
                                Text(name).font(.caption)
                                Button {
                                    identityStore.remove(name: name)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(localization.string(.faceIdRemove)) \(name)")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2), in: Capsule())
                        }
                    }
                }
            }

            Text(localization.string(.faceIdPrivacyNote))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .onDisappear {
            // Defer observable changes until SwiftUI has finished removing the view.
            Task { @MainActor in capture.stop() }
        }
    }

    // MARK: - Stage layers

    /// Preview and every overlay are flipped as one unit on macOS so they
    /// stay pixel-aligned: Mac cameras don't auto-mirror like the iPhone's
    /// front camera preview does.
    private var overlays: some View {
        ZStack {
            CameraPreviewView(session: capture.session)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            ForEach(capture.hands) { hand in
                HandOverlayShape(hand: hand.landmarks, videoSize: capture.videoSize)
                    .stroke(BrandColor.accent, lineWidth: 3)
                LandmarkPointsShape(points: hand.landmarks.allLocations, videoSize: capture.videoSize)
                    .fill(BrandColor.accentSecondary)
            }

            if let faceLandmarks = capture.currentFaceLandmarks {
                // Vision's landmark regions never reach the forehead or
                // hairline, so the full head box is drawn first to show the
                // whole detected head area, then the fine mesh on top.
                HeadBoundingBoxShape(boundingBox: capture.currentFaceBoundingBox, videoSize: capture.videoSize)
                    .stroke(BrandColor.accent.opacity(0.5), lineWidth: 1.5)
                let mesh = FaceMeshOverlayShape(
                    landmarks: faceLandmarks,
                    boundingBox: capture.currentFaceBoundingBox,
                    videoSize: capture.videoSize
                )
                mesh.stroke(BrandColor.accent, lineWidth: 1.5)
                LandmarkPointsShape(points: mesh.allPoints, videoSize: capture.videoSize, radius: 1.5)
                    .fill(BrandColor.accentSecondary)
            }
        }
        #if os(macOS)
        .scaleEffect(x: -1, y: 1)
        #endif
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            if capture.isStarting {
                ProgressView()
            } else {
                Image(systemName: capture.status == .denied ? "camera.fill.badge.ellipsis" : "camera")
                    .font(.system(size: 36))
                    .foregroundStyle(BrandColor.accent)
            }
            Text(placeholderText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if capture.status == .denied, let url = Self.cameraSettingsURL {
                Button(localization.string(.cameraOpenSettings)) { openURL(url) }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private var debugPanel: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    // Shown unconditionally (not just while running): if the
                    // camera never starts, this is the only way to see *why*.
                    Text("status: \(capture.isStarting ? "starting" : String(describing: capture.status))")
                    if isRunning {
                        Text("hands: \(capture.hands.count) · face: \(capture.faceDetected ? "yes" : "no")")
                        if let debug = capture.hands.first.flatMap({ HandGestureClassifier.debugInfo($0.landmarks) }) {
                            Text("thumb \(Int(debug.thumbAngle))° (\(debug.thumbExtended ? "out" : "in")) · pinch \(String(format: "%.2f", debug.pinch))")
                        }
                        if let s = capture.expressionScores {
                            Text(String(format: "lift %.3f · open %.3f · eye %.2f · brow %.3f", s.mouthCornerLift, s.mouthOpenAmount, s.eyeOpenRatio, s.browRaise))
                        }
                    }
                }
                .font(.system(.caption2, design: .monospaced))
                .padding(4)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.white)
                Spacer()
            }
            Spacer()
        }
        .padding(8)
    }

    private var badges: some View {
        VStack {
            Spacer()
            if isRunning {
                HStack(spacing: 8) {
                    ForEach(capture.hands.filter { $0.gesture != .none }) { hand in
                        badge(hand.localizedLabel(using: localization))
                    }
                    if capture.expression != .none {
                        badge(localization.string(capture.expression.localizedKey))
                    }
                    if capture.headMovement != .none {
                        badge(localization.string(capture.headMovement.localizedKey))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: capture.hands.map(\.gesture))
                if capture.faceDetected {
                    if let match = capture.identityMatch {
                        badge(match.name)
                    } else {
                        badge(localization.string(.faceIdUnknown), muted: true)
                    }
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func badge(_ text: String, muted: Bool = false) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(muted ? AnyShapeStyle(Color.black.opacity(0.6)) : AnyShapeStyle(BrandColor.gradient), in: Capsule())
            .foregroundStyle(muted ? .white : .black)
    }

    private var placeholderText: String {
        if capture.isStarting { return localization.string(.cameraStarting) }
        switch capture.status {
        case .denied: return localization.string(.cameraDenied)
        case .failed: return localization.string(capture.failureMessage)
        case .idle, .running: return localization.string(.cameraReady)
        }
    }

    // MARK: - Platform differences

    #if os(iOS)
    private static let stageBackground = Color(uiColor: .secondarySystemBackground)
    /// Portrait-locked iPhone: the oriented frame is taller than wide.
    private static let stageAspectRatio: CGFloat = 3 / 4
    private static let cameraSettingsURL = URL(string: UIApplication.openSettingsURLString)
    #else
    private static let stageBackground = Color(nsColor: .underPageBackgroundColor)
    private static let stageAspectRatio: CGFloat = 4 / 3
    private static let cameraSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    #endif
}
