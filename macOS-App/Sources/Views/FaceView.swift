import SwiftUI
import SharedKit

struct FaceView: View {
    @StateObject private var capture = FaceCaptureService()
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var identityStore = FaceIdentityStore.shared
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
                    CameraPreviewView(session: capture.session)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                if isRunning {
                    VStack {
                        HStack {
                            Text("face: \(capture.faceDetected ? "yes" : "no")")
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
                    ForEach(identityStore.knownFaces, id: \.name) { face in
                        HStack(spacing: 4) {
                            Text(face.name).font(.caption)
                            Button {
                                identityStore.remove(name: face.name)
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
        case .denied: return localization.string(.cameraPermission)
        case .failed: return localization.string(.cameraError)
        case .idle, .running: return localization.string(.cameraPermission)
        }
    }
}
