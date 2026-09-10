import SwiftUI
import SharedKit

struct FaceView: View {
    @StateObject private var capture = FaceCaptureService()
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var identityStore = FaceIdentityStore.shared
    @ObservedObject private var debugMode = DebugModeStore.shared
    @State private var nameInput = ""

    private var isRunning: Bool { capture.status == .running }

    var body: some View {
        VStack(spacing: 16) {
            Text(localization.string(.heroSubtitleFace))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                if isRunning {
                    CameraPreviewView(session: capture.session)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if let faceLandmarks = capture.currentFaceLandmarks {
                        // Vision's landmark regions never reach the forehead
                        // or hairline, so the full head box is drawn first
                        // to show the whole detected head area (chin to
                        // forehead), then the fine mesh on top of it.
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
                } else {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                if isRunning, debugMode.isEnabled {
                    VStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("face: \(capture.faceDetected ? "yes" : "no")")
                            if let s = capture.expressionScores {
                                Text(String(format: "lift %.3f · open %.3f · eye %.2f · brow %.3f", s.mouthCornerLift, s.mouthOpenAmount, s.eyeOpenRatio, s.browRaise))
                            }
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .padding(4)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        HStack { Spacer() }
                        Spacer()
                    }
                    .padding(8)
                }

                VStack {
                    Spacer()
                    if isRunning {
                        HStack(spacing: 8) {
                            if capture.expression != .none {
                                badge(localization.string(capture.expression.localizedKey))
                            }
                            if capture.headMovement != .none {
                                badge(localization.string(capture.headMovement.localizedKey))
                            }
                        }
                        if let match = capture.identityMatch {
                            badge(match.name)
                        } else {
                            badge(localization.string(.faceIdUnknown), muted: true)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .padding(.horizontal)

            Button {
                if isRunning { capture.stop() } else { capture.start() }
            } label: {
                Text(isRunning ? localization.string(.cameraStop) : localization.string(.cameraStart))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(BrandColor.gradient, in: Capsule())
            }

            if isRunning {
                HStack {
                    TextField(localization.string(.faceIdNamePlaceholder), text: $nameInput)
                        .textFieldStyle(.roundedBorder)
                    Button(localization.string(.faceIdRegister)) {
                        capture.registerCurrentFace(name: nameInput)
                        nameInput = ""
                    }
                    .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

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
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Text(localization.string(.faceIdPrivacyNote))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
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
        switch capture.status {
        case .denied: return localization.string(.cameraPermission)
        case .failed: return localization.string(.cameraError)
        case .idle, .running: return localization.string(.cameraPermission)
        }
    }
}
