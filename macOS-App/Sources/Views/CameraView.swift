import SwiftUI
import SharedKit

struct CameraView: View {
    @StateObject private var capture = CameraCaptureService()
    @ObservedObject private var localization = LocalizationManager.shared

    private var isRunning: Bool { capture.status == .running }

    var body: some View {
        VStack(spacing: 20) {
            Text(localization.string(.heroSubtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .underPageBackgroundColor))

                if isRunning {
                    // Flipped as one unit so the preview and the overlay
                    // stay pixel-aligned with each other. macOS cameras
                    // don't report a "front" position, so — unlike iOS,
                    // whose preview auto-mirrors for a front camera — this
                    // app would otherwise show a "video call" view instead
                    // of the natural "mirror" view most self-facing camera
                    // apps use, and the user's own left/right hand would
                    // never match what they intuitively expect.
                    ZStack {
                        CameraPreviewView(session: capture.session)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        ForEach(capture.hands) { hand in
                            HandOverlayShape(hand: hand.landmarks, videoSize: capture.videoSize)
                                .stroke(BrandColor.accent, lineWidth: 3)
                            LandmarkPointsShape(points: hand.landmarks.allLocations, videoSize: capture.videoSize)
                                .fill(BrandColor.accentSecondary)
                        }
                    }
                    .scaleEffect(x: -1, y: 1)
                } else {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                if isRunning {
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
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(minWidth: 480, minHeight: 360)

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
                    .padding(.vertical, 12)
                    .background(BrandColor.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var placeholderText: String {
        switch capture.status {
        case .denied: return localization.string(.cameraPermission)
        case .failed: return localization.string(.cameraError)
        case .idle, .running: return localization.string(.cameraPermission)
        }
    }
}
