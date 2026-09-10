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

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .underPageBackgroundColor))

                if isRunning {
                    // See the matching comment in CameraView.swift: macOS
                    // cameras don't auto-mirror like iOS's front camera
                    // preview does, so the preview+overlay are flipped
                    // together here for a natural "mirror" view.
                    ZStack {
                        CameraPreviewView(session: capture.session)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        if let faceLandmarks = capture.currentFaceLandmarks {
                            // Vision's landmark regions never reach the
                            // forehead or hairline, so the full head box is
                            // drawn first to show the whole detected head
                            // area (chin to forehead), then the fine mesh.
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
                    .scaleEffect(x: -1, y: 1)
                } else {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                if debugMode.isEnabled {
                    VStack {
                        VStack(alignment: .leading, spacing: 2) {
                            // Shown unconditionally (not just while
                            // running): if the camera never starts, this is
                            // the only way to see *why* — previously the
                            // whole debug panel was gated behind isRunning,
                            // so a stuck idle/denied/failed status gave zero
                            // visible information even with debug mode on.
                            Text("status: \(String(describing: capture.status))")
                            if isRunning {
                                Text("face: \(capture.faceDetected ? "yes" : "no")")
                                if let s = capture.expressionScores {
                                    Text(String(format: "lift %.3f · open %.3f · eye %.2f · brow %.3f", s.mouthCornerLift, s.mouthOpenAmount, s.eyeOpenRatio, s.browRaise))
                                }
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
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(minWidth: 480, minHeight: 320)

            Button {
                if isRunning { capture.stop() } else { capture.start() }
            } label: {
                Text(isRunning ? localization.string(.cameraStop) : localization.string(.cameraStart))
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
                        capture.registerCurrentFace(name: nameInput)
                        nameInput = ""
                    }
                    .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let feedback = capture.registrationFeedback {
                    Text(feedback).font(.caption).foregroundStyle(.secondary)
                }
            }

            if !identityStore.knownFaces.isEmpty {
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
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2), in: Capsule())
                    }
                }
            }

            Text(localization.string(.faceIdPrivacyNote))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
        case .denied: return localization.string(.cameraDenied)
        case .failed: return localization.string(.cameraError)
        case .idle, .running: return localization.string(.cameraPermission)
        }
    }
}
