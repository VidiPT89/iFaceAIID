import SwiftUI
import SharedKit

struct CameraView: View {
    @StateObject private var capture = CameraCaptureService()
    @ObservedObject private var localization = LocalizationManager.shared

    private var isRunning: Bool { capture.status == .running }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(localization.string(.appTitle))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                ControlsBar()
            }
            .padding(.horizontal)

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

                    if let hand = capture.currentHand {
                        HandOverlayShape(hand: hand)
                            .stroke(BrandColor.accent, lineWidth: 3)
                    }
                } else {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                VStack {
                    Spacer()
                    if isRunning, capture.gesture != .none {
                        Text(gestureLabel(capture.gesture))
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(BrandColor.gradient, in: Capsule())
                            .foregroundStyle(.black)
                            .padding(.bottom, 16)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: capture.gesture)
                    }
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

    private func gestureLabel(_ gesture: DetectedGesture) -> String {
        switch gesture {
        case .thumbsUp: return localization.string(.gestureThumbsUp)
        case .openPalm: return localization.string(.gestureOpenPalm)
        case .closedFist: return localization.string(.gestureClosedFist)
        case .none: return localization.string(.gestureNone)
        }
    }
}
