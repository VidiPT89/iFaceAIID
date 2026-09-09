import SwiftUI
import SharedKit

struct RootView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var mode: AppMode = .hands

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(localization.string(.appTitle))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                ControlsBar()
            }

            Picker("", selection: $mode) {
                Text(localization.string(.modeHands)).tag(AppMode.hands)
                Text(localization.string(.modeFace)).tag(AppMode.face)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            switch mode {
            case .hands: CameraView()
            case .face: FaceView()
            }

            Spacer()

            VStack(spacing: 4) {
                Text(localization.string(.footerPrivacy))
                Text(localization.string(.footerDevelopedBy) + " David Arsénio Martins")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 700)
    }
}
