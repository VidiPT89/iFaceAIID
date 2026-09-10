import SwiftUI
import SharedKit

struct CameraView: View {
    @StateObject private var capture = CameraCaptureService()
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var debugMode = DebugModeStore.shared

    private var isRunning: Bool { capture.status == .running }

    var body: some View {
        VStack(spacing: 20) {
            Text(localization.string(.heroSubtitle))
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

                    ForEach(capture.hands) { hand in
                        HandOverlayShape(hand: hand.landmarks, videoSize: capture.videoSize)
                            .stroke(BrandColor.accent, lineWidth: 3)
                        LandmarkPointsShape(points: hand.landmarks.allLocations, videoSize: capture.videoSize)
                            .fill(BrandColor.accentSecondary)
                    }
                } else {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                if isRunning, debugMode.isEnabled {
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("hands: \(capture.hands.count)")
                                if let debug = capture.hands.first.flatMap({ HandGestureClassifier.debugInfo($0.landmarks) }) {
                                    Text("thumb \(Int(debug.thumbAngle))° (\(debug.thumbExtended ? "out" : "in")) · pinch \(String(format: "%.2f", debug.pinch))")
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

                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(capture.hands.filter { $0.gesture != .none }) { hand in
                            Text(hand.localizedLabel(using: localization))
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(BrandColor.gradient, in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.bottom, 16)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: capture.hands.map(\.gesture))
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .padding(.horizontal)

            Button {
                if isRunning {
                    capture.stop()
                } else {
                    capture.start()
                }
            } label: {
                Text(isRunning ? localization.string(.cameraStop) : localization.string(.cameraStart))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(BrandColor.gradient, in: Capsule())
            }

            Spacer()

            VStack(spacing: 4) {
                Text(localization.string(.footerPrivacy))
                Text(localization.string(.footerDevelopedBy) + " David Arsénio Martins")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 12)
        }
        .padding(.top)
    }

    private var placeholderText: String {
        switch capture.status {
        case .denied: return localization.string(.cameraPermission)
        case .failed: return localization.string(.cameraError)
        case .idle, .running: return localization.string(.cameraPermission)
        }
    }
}
